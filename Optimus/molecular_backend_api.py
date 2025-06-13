"""
Molecular Structure API Backend
Production-ready FastAPI server for molecular structure search, visualization, and conversion
"""

import os
import io
import base64
import asyncio
import logging
from typing import List, Optional, Dict, Any
from datetime import datetime
from pathlib import Path

import uvicorn
from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, StreamingResponse
from pydantic import BaseModel, Field
from sqlalchemy import create_engine, Column, String, Integer, Float, DateTime, Boolean, Text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.dialects.postgresql import UUID
import uuid

# Chemistry libraries
try:
    from rdkit import Chem
    from rdkit.Chem import Descriptors, Crippen, rdMolDescriptors
    from rdkit.Chem import AllChem, Draw
    from rdkit.Chem.rdMolAlign import AlignMol
    from rdkit.Chem import rdDepictor
    rdDepictor.SetPreferCoordGen(True)
except ImportError:
    raise ImportError("RDKit is required. Install with: conda install -c conda-forge rdkit")

# External API clients
import httpx
import pubchempy as pcp
from chembl_webresource_client.new_client import new_client

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Database configuration
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://user:password@localhost/moldb")
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# FastAPI app
app = FastAPI(
    title="Molecular Structure API",
    description="Production API for molecular structure search, visualization, and conversion",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ==================== DATABASE MODELS ====================

class MoleculeDB(Base):
    __tablename__ = "molecules"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String, nullable=False, index=True)
    smiles = Column(Text, nullable=False, index=True)
    inchi = Column(Text, nullable=False)
    inchi_key = Column(String, nullable=False, index=True)
    cas_number = Column(String, index=True)
    molecular_weight = Column(Float)
    molecular_formula = Column(String)
    pubchem_cid = Column(String, index=True)
    drugbank_id = Column(String, index=True)
    chembl_id = Column(String, index=True)
    
    # Calculated properties
    logp = Column(Float)
    tpsa = Column(Float)
    hbd = Column(Integer)  # H-bond donors
    hba = Column(Integer)  # H-bond acceptors
    rotatable_bonds = Column(Integer)
    lipinski_pass = Column(Boolean)
    
    # Structure data
    structure_2d = Column(Text)  # SVG or base64 encoded image
    structure_3d = Column(Text)  # SDF format
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class SearchHistoryDB(Base):
    __tablename__ = "search_history"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    query = Column(String, nullable=False)
    search_type = Column(String, nullable=False)
    result_count = Column(Integer, default=0)
    user_id = Column(String, index=True)  # For future user management
    timestamp = Column(DateTime, default=datetime.utcnow)

# Create tables
Base.metadata.create_all(bind=engine)

# ==================== PYDANTIC MODELS ====================

class SearchRequest(BaseModel):
    query: str = Field(..., min_length=1, max_length=1000)
    type: str = Field(..., regex="^(name|cas|smiles|inchi|inchi_key)$")
    limit: int = Field(default=20, ge=1, le=100)

class ExportRequest(BaseModel):
    smiles: str = Field(..., min_length=1)
    format: str = Field(..., regex="^(sdf|mol2|pdb|pdbqt|png|svg)$")
    add_hydrogens: bool = Field(default=True)
    minimize: bool = Field(default=True)

class MoleculeProperties(BaseModel):
    logP: Optional[float] = None
    tpsa: Optional[float] = None
    hbondDonors: Optional[int] = None
    hbondAcceptors: Optional[int] = None
    rotatablebonds: Optional[int] = None
    lipinski: Optional[bool] = None

class MoleculeResponse(BaseModel):
    name: str
    smiles: str
    inchi: str
    inchiKey: str
    casNumber: Optional[str] = None
    molecularWeight: Optional[float] = None
    molecularFormula: Optional[str] = None
    pubchemCID: Optional[str] = None
    drugbankID: Optional[str] = None
    chemblID: Optional[str] = None
    structure2D: Optional[str] = None
    structure3D: Optional[str] = None
    properties: Optional[MoleculeProperties] = None

class SearchResponse(BaseModel):
    molecules: List[MoleculeResponse]
    total: int
    query: str
    search_type: str

# ==================== DATABASE DEPENDENCY ====================

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ==================== CHEMISTRY UTILITIES ====================

class ChemistryService:
    """Core chemistry operations using RDKit"""
    
    @staticmethod
    def smiles_to_mol(smiles: str) -> Optional[Chem.Mol]:
        """Convert SMILES to RDKit molecule object"""
        try:
            mol = Chem.MolFromSmiles(smiles)
            return mol if mol is not None else None
        except Exception as e:
            logger.error(f"Error parsing SMILES {smiles}: {e}")
            return None
    
    @staticmethod
    def mol_to_smiles(mol: Chem.Mol) -> str:
        """Convert RDKit molecule to canonical SMILES"""
        try:
            return Chem.MolToSmiles(mol, canonical=True)
        except Exception as e:
            logger.error(f"Error generating SMILES: {e}")
            return ""
    
    @staticmethod
    def calculate_properties(mol: Chem.Mol) -> MoleculeProperties:
        """Calculate molecular properties"""
        try:
            props = MoleculeProperties(
                logP=round(Descriptors.MolLogP(mol), 2),
                tpsa=round(Descriptors.TPSA(mol), 2),
                hbondDonors=Descriptors.NumHDonors(mol),
                hbondAcceptors=Descriptors.NumHAcceptors(mol),
                rotatablebonds=Descriptors.NumRotatableBonds(mol),
            )
            
            # Lipinski Rule of Five
            props.lipinski = (
                props.logP <= 5 and
                props.hbondDonors <= 5 and
                props.hbondAcceptors <= 10 and
                Descriptors.MolWt(mol) <= 500
            )
            
            return props
        except Exception as e:
            logger.error(f"Error calculating properties: {e}")
            return MoleculeProperties()
    
    @staticmethod
    def generate_2d_structure(mol: Chem.Mol, format: str = "svg") -> Optional[str]:
        """Generate 2D structure image"""
        try:
            # Ensure molecule has 2D coordinates
            AllChem.Compute2DCoords(mol)
            
            if format.lower() == "svg":
                drawer = Draw.rdMolDraw2D.MolDraw2DSVG(300, 300)
                drawer.DrawMolecule(mol)
                drawer.FinishDrawing()
                return drawer.GetDrawingText()
            
            elif format.lower() == "png":
                img = Draw.MolToImage(mol, size=(300, 300))
                img_buffer = io.BytesIO()
                img.save(img_buffer, format='PNG')
                img_str = base64.b64encode(img_buffer.getvalue()).decode()
                return f"data:image/png;base64,{img_str}"
            
        except Exception as e:
            logger.error(f"Error generating 2D structure: {e}")
            return None
    
    @staticmethod
    def generate_3d_structure(mol: Chem.Mol, minimize: bool = True) -> Optional[str]:
        """Generate 3D structure in SDF format"""
        try:
            mol_copy = Chem.Mol(mol)
            
            # Add hydrogens if needed
            mol_copy = Chem.AddHs(mol_copy)
            
            # Generate 3D coordinates
            AllChem.EmbedMolecule(mol_copy, randomSeed=42)
            
            if minimize:
                AllChem.MMFFOptimizeMolecule(mol_copy, maxIters=500)
            
            # Convert to SDF
            sdf_block = Chem.MolToMolBlock(mol_copy)
            return sdf_block
            
        except Exception as e:
            logger.error(f"Error generating 3D structure: {e}")
            return None
    
    @staticmethod
    def convert_format(mol: Chem.Mol, target_format: str, add_hydrogens: bool = True, minimize: bool = True) -> bytes:
        """Convert molecule to various formats"""
        try:
            mol_copy = Chem.Mol(mol)
            
            if add_hydrogens:
                mol_copy = Chem.AddHs(mol_copy)
            
            # Generate 3D coordinates if needed
            if target_format.lower() in ['sdf', 'mol2', 'pdb', 'pdbqt']:
                AllChem.EmbedMolecule(mol_copy, randomSeed=42)
                if minimize:
                    AllChem.MMFFOptimizeMolecule(mol_copy, maxIters=500)
            
            if target_format.lower() == 'sdf':
                return Chem.MolToMolBlock(mol_copy).encode()
            
            elif target_format.lower() == 'pdb':
                return Chem.MolToPDBBlock(mol_copy).encode()
            
            elif target_format.lower() == 'mol2':
                # Note: RDKit doesn't natively support MOL2, would need external tool
                # For now, return SDF with warning
                logger.warning("MOL2 format not fully supported, returning SDF")
                return Chem.MolToMolBlock(mol_copy).encode()
            
            elif target_format.lower() == 'pdbqt':
                # PDBQT requires additional processing (partial charges, etc.)
                # For now, return PDB with warning
                logger.warning("PDBQT format requires additional processing, returning PDB")
                return Chem.MolToPDBBlock(mol_copy).encode()
            
            elif target_format.lower() == 'png':
                AllChem.Compute2DCoords(mol_copy)
                img = Draw.MolToImage(mol_copy, size=(800, 600))
                img_buffer = io.BytesIO()
                img.save(img_buffer, format='PNG')
                return img_buffer.getvalue()
            
            elif target_format.lower() == 'svg':
                AllChem.Compute2DCoords(mol_copy)
                drawer = Draw.rdMolDraw2D.MolDraw2DSVG(800, 600)
                drawer.DrawMolecule(mol_copy)
                drawer.FinishDrawing()
                return drawer.GetDrawingText().encode()
            
            else:
                raise ValueError(f"Unsupported format: {target_format}")
                
        except Exception as e:
            logger.error(f"Error converting to {target_format}: {e}")
            raise HTTPException(status_code=400, detail=f"Conversion error: {str(e)}")

# ==================== DATABASE SERVICES ====================

class DatabaseService:
    """Database operations for molecules"""
    
    @staticmethod
    def search_molecules(db: Session, query: str, search_type: str, limit: int = 20) -> List[MoleculeDB]:
        """Search molecules in database"""
        try:
            if search_type == "name":
                return db.query(MoleculeDB).filter(
                    MoleculeDB.name.ilike(f"%{query}%")
                ).limit(limit).all()
            
            elif search_type == "cas":
                return db.query(MoleculeDB).filter(
                    MoleculeDB.cas_number == query
                ).limit(limit).all()
            
            elif search_type == "smiles":
                return db.query(MoleculeDB).filter(
                    MoleculeDB.smiles == query
                ).limit(limit).all()
            
            elif search_type == "inchi_key":
                return db.query(MoleculeDB).filter(
                    MoleculeDB.inchi_key == query
                ).limit(limit).all()
            
            else:
                return []
                
        except Exception as e:
            logger.error(f"Database search error: {e}")
            return []
    
    @staticmethod
    def save_molecule(db: Session, molecule_data: Dict[str, Any]) -> MoleculeDB:
        """Save molecule to database"""
        try:
            molecule = MoleculeDB(**molecule_data)
            db.add(molecule)
            db.commit()
            db.refresh(molecule)
            return molecule
        except Exception as e:
            logger.error(f"Error saving molecule: {e}")
            db.rollback()
            raise

# ==================== EXTERNAL API SERVICES ====================

class ExternalAPIService:
    """Integration with external chemical databases"""
    
    @staticmethod
    async def search_pubchem(query: str, search_type: str) -> List[Dict[str, Any]]:
        """Search PubChem database"""
        try:
            results = []
            
            if search_type == "name":
                compounds = pcp.get_compounds(query, 'name', listkey_count=10)
            elif search_type == "cas":
                compounds = pcp.get_compounds(query, 'cas')
            elif search_type == "smiles":
                compounds = pcp.get_compounds(query, 'smiles')
            else:
                return results
            
            for compound in compounds[:10]:  # Limit results
                try:
                    mol_data = {
                        'name': compound.iupac_name or compound.synonyms[0] if compound.synonyms else f"CID_{compound.cid}",
                        'smiles': compound.canonical_smiles,
                        'inchi': compound.inchi,
                        'inchi_key': compound.inchikey,
                        'molecular_weight': compound.molecular_weight,
                        'molecular_formula': compound.molecular_formula,
                        'pubchem_cid': str(compound.cid),
                        'cas_number': None  # Would need additional lookup
                    }
                    results.append(mol_data)
                except Exception as e:
                    logger.warning(f"Error processing PubChem compound {compound.cid}: {e}")
                    continue
            
            return results
            
        except Exception as e:
            logger.error(f"PubChem search error: {e}")
            return []
    
    @staticmethod
    async def search_chembl(query: str, search_type: str) -> List[Dict[str, Any]]:
        """Search ChEMBL database"""
        try:
            results = []
            molecule = new_client.molecule
            
            if search_type == "name":
                compounds = molecule.filter(pref_name__icontains=query)[:10]
            elif search_type == "smiles":
                compounds = molecule.filter(molecule_structures__canonical_smiles=query)[:10]
            else:
                return results
            
            for compound in compounds:
                try:
                    mol_data = {
                        'name': compound['pref_name'] or compound['chembl_id'],
                        'smiles': compound['molecule_structures']['canonical_smiles'] if compound.get('molecule_structures') else None,
                        'inchi': compound['molecule_structures']['standard_inchi'] if compound.get('molecule_structures') else None,
                        'inchi_key': compound['molecule_structures']['standard_inchi_key'] if compound.get('molecule_structures') else None,
                        'molecular_weight': compound['molecule_properties']['full_mwt'] if compound.get('molecule_properties') else None,
                        'molecular_formula': compound['molecule_properties']['full_molformula'] if compound.get('molecule_properties') else None,
                        'chembl_id': compound['chembl_id']
                    }
                    
                    # Only add if we have essential data
                    if mol_data['smiles'] and mol_data['inchi_key']:
                        results.append(mol_data)
                        
                except Exception as e:
                    logger.warning(f"Error processing ChEMBL compound: {e}")
                    continue
            
            return results
            
        except Exception as e:
            logger.error(f"ChEMBL search error: {e}")
            return []

# ==================== API ENDPOINTS ====================

@app.get("/")
async def root():
    return {"message": "Molecular Structure API", "version": "1.0.0", "status": "running"}

@app.get("/health")
async def health_check():
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}

@app.post("/api/v1/search", response_model=SearchResponse)
async def search_molecules(
    request: SearchRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    """Search for molecules across multiple databases"""
    try:
        all_results = []
        
        # Search local database first
        local_results = DatabaseService.search_molecules(db, request.query, request.type, request.limit)
        
        for mol_db in local_results:
            mol_response = MoleculeResponse(
                name=mol_db.name,
                smiles=mol_db.smiles,
                inchi=mol_db.inchi,
                inchiKey=mol_db.inchi_key,
                casNumber=mol_db.cas_number,
                molecularWeight=mol_db.molecular_weight,
                molecularFormula=mol_db.molecular_formula,
                pubchemCID=mol_db.pubchem_cid,
                drugbankID=mol_db.drugbank_id,
                chemblID=mol_db.chembl_id,
                structure2D=mol_db.structure_2d,
                structure3D=mol_db.structure_3d,
                properties=MoleculeProperties(
                    logP=mol_db.logp,
                    tpsa=mol_db.tpsa,
                    hbondDonors=mol_db.hbd,
                    hbondAcceptors=mol_db.hba,
                    rotatablebonds=mol_db.rotatable_bonds,
                    lipinski=mol_db.lipinski_pass
                ) if mol_db.logp is not None else None
            )
            all_results.append(mol_response)
        
        # If not enough local results, search external APIs
        remaining_limit = max(0, request.limit - len(all_results))
        
        if remaining_limit > 0:
            # Search PubChem
            pubchem_results = await ExternalAPIService.search_pubchem(request.query, request.type)
            
            for mol_data in pubchem_results[:remaining_limit]:
                # Calculate properties if we have SMILES
                properties = None
                structure_2d = None
                
                if mol_data.get('smiles'):
                    mol = ChemistryService.smiles_to_mol(mol_data['smiles'])
                    if mol:
                        properties = ChemistryService.calculate_properties(mol)
                        structure_2d = ChemistryService.generate_2d_structure(mol, "svg")
                
                mol_response = MoleculeResponse(
                    name=mol_data['name'],
                    smiles=mol_data['smiles'],
                    inchi=mol_data['inchi'],
                    inchiKey=mol_data['inchi_key'],
                    casNumber=mol_data.get('cas_number'),
                    molecularWeight=mol_data.get('molecular_weight'),
                    molecularFormula=mol_data.get('molecular_formula'),
                    pubchemCID=mol_data.get('pubchem_cid'),
                    structure2D=structure_2d,
                    properties=properties
                )
                all_results.append(mol_response)
        
        # Save search history
        background_tasks.add_task(
            save_search_history,
            db, request.query, request.type, len(all_results)
        )
        
        return SearchResponse(
            molecules=all_results[:request.limit],
            total=len(all_results),
            query=request.query,
            search_type=request.type
        )
        
    except Exception as e:
        logger.error(f"Search error: {e}")
        raise HTTPException(status_code=500, detail=f"Search failed: {str(e)}")

@app.post("/api/v1/export")
async def export_molecule(request: ExportRequest):
    """Export molecule in various formats"""
    try:
        mol = ChemistryService.smiles_to_mol(request.smiles)
        if not mol:
            raise HTTPException(status_code=400, detail="Invalid SMILES string")
        
        file_data = ChemistryService.convert_format(
            mol, request.format, request.add_hydrogens, request.minimize
        )
        
        # Determine content type
        content_types = {
            'sdf': 'chemical/x-mdl-sdfile',
            'mol2': 'chemical/x-mol2',
            'pdb': 'chemical/x-pdb',
            'pdbqt': 'text/plain',
            'png': 'image/png',
            'svg': 'image/svg+xml'
        }
        
        content_type = content_types.get(request.format.lower(), 'application/octet-stream')
        
        return StreamingResponse(
            io.BytesIO(file_data),
            media_type=content_type,
            headers={
                "Content-Disposition": f"attachment; filename=molecule.{request.format}",
                "Content-Length": str(len(file_data))
            }
        )
        
    except Exception as e:
        logger.error(f"Export error: {e}")
        raise HTTPException(status_code=500, detail=f"Export failed: {str(e)}")

@app.post("/api/v1/validate")
async def validate_structure(smiles: str):
    """Validate and standardize a SMILES string"""
    try:
        mol = ChemistryService.smiles_to_mol(smiles)
        if not mol:
            return {"valid": False, "error": "Invalid SMILES string"}
        
        canonical_smiles = ChemistryService.mol_to_smiles(mol)
        properties = ChemistryService.calculate_properties(mol)
        structure_2d = ChemistryService.generate_2d_structure(mol, "svg")
        
        return {
            "valid": True,
            "canonical_smiles": canonical_smiles,
            "molecular_formula": Chem.rdMolDescriptors.CalcMolFormula(mol),
            "molecular_weight": round(Descriptors.MolWt(mol), 2),
            "properties": properties.dict(),
            "structure_2d": structure_2d
        }
        
    except Exception as e:
        logger.error(f"Validation error: {e}")
        return {"valid": False, "error": str(e)}

@app.get("/api/v1/history")
async def get_search_history(db: Session = Depends(get_db), limit: int = 50):
    """Get recent search history"""
    try:
        history = db.query(SearchHistoryDB).order_by(
            SearchHistoryDB.timestamp.desc()
        ).limit(limit).all()
        
        return [
            {
                "query": h.query,
                "search_type": h.search_type,
                "result_count": h.result_count,
                "timestamp": h.timestamp.isoformat()
            }
            for h in history
        ]
        
    except Exception as e:
        logger.error(f"History retrieval error: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve history")

# ==================== BACKGROUND TASKS ====================

def save_search_history(db: Session, query: str, search_type: str, result_count: int):
    """Save search history to database"""
    try:
        history = SearchHistoryDB(
            query=query,
            search_type=search_type,
            result_count=result_count
        )
        db.add(history)
        db.commit()
    except Exception as e:
        logger.error(f"Error saving search history: {e}")
        db.rollback()

# ==================== MAIN ====================

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )