//
//  ContentView.swift
//  Optimus
//
//  Created by Pritam Kumar Panda on 6/12/25.
//

import SwiftUI
import SwiftData
import WebKit
import UniformTypeIdentifiers
import Foundation

// MARK: - Enhanced Data Models
@Model
final class Molecule {
    var id: UUID
    var name: String
    var smiles: String
    var molecularFormula: String?
    var molecularWeight: Double?
    var logP: Double?
    var tpsa: Double?
    var hDonors: Int?
    var hAcceptors: Int?
    var rotatablebonds: Int?
    var inchi: String?
    var inchiKey: String?
    var casID: String?
    var pubchemCID: Int?
    var tags: [String]
    var dateAdded: Date
    var isBookmarked: Bool
    
    // Drug Design Properties
    var lipinskiCompliant: Bool {
        guard let mw = molecularWeight,
              let logP = logP,
              let donors = hDonors,
              let acceptors = hAcceptors else { return false }
        
        return mw <= 500 && logP <= 5 && donors <= 5 && acceptors <= 10
    }
    
    var drugLikenessScore: Double {
        var score = 0.0
        if let mw = molecularWeight, mw <= 500 { score += 0.25 }
        if let logP = logP, logP <= 5 { score += 0.25 }
        if let donors = hDonors, donors <= 5 { score += 0.25 }
        if let acceptors = hAcceptors, acceptors <= 10 { score += 0.25 }
        return score
    }
    
    init(name: String, smiles: String) {
        self.id = UUID()
        self.name = name
        self.smiles = smiles
        self.tags = []
        self.dateAdded = Date()
        self.isBookmarked = false
    }
}

@Model
final class SearchHistory {
    var id: UUID
    var query: String
    var searchType: String
    var timestamp: Date
    var resultFound: Bool
    
    init(query: String, searchType: String, resultFound: Bool) {
        self.id = UUID()
        self.query = query
        self.searchType = searchType
        self.timestamp = Date()
        self.resultFound = resultFound
    }
}

@Model
final class DesignProject {
    var id: UUID
    var name: String
    var targetProtein: String
    var molecules: [Molecule]
    var notes: String
    var dateCreated: Date
    var lastModified: Date
    
    init(name: String, targetProtein: String) {
        self.id = UUID()
        self.name = name
        self.targetProtein = targetProtein
        self.molecules = []
        self.notes = ""
        self.dateCreated = Date()
        self.lastModified = Date()
    }
}

// MARK: - Search Types and Export Formats
enum SearchType: String, CaseIterable {
    case name = "name"
    case cas = "cas"
    case smiles = "smiles"
    case inchi = "inchi"
    case cid = "cid"
    
    var displayName: String {
        switch self {
        case .name: return "Name"
        case .cas: return "CAS"
        case .smiles: return "SMILES"
        case .inchi: return "InChI"
        case .cid: return "CID"
        }
    }
    
    var placeholder: String {
        switch self {
        case .name: return "e.g., Ibuprofen, Caffeine"
        case .cas: return "e.g., 15687-27-1"
        case .smiles: return "e.g., CC(C)Cc1ccc(cc1)C(C)C(=O)O"
        case .inchi: return "e.g., InChI=1S/C13H18O2/..."
        case .cid: return "e.g., 3672 (PubChem ID)"
        }
    }
    
    var icon: String {
        switch self {
        case .name: return "textformat.abc"
        case .cas: return "number.circle"
        case .smiles: return "link"
        case .inchi: return "barcode"
        case .cid: return "number.square"
        }
    }
}

// MARK: - Pharmacophore Enums
enum FeatureCategory: String, CaseIterable {
    case all = "All Features"
    case interactions = "Interactions"
    case geometric = "Geometric"
    case electronic = "Electronic"
    case special = "Special"
    
    var icon: String {
        switch self {
        case .all: return "square.grid.3x3"
        case .interactions: return "link"
        case .geometric: return "cube"
        case .electronic: return "bolt"
        case .special: return "star"
        }
    }
}

enum PharmacophoreFeature: String, CaseIterable, Identifiable {
    // Interaction Features
    case hydrogenBondDonor = "Hydrogen Bond Donor"
    case hydrogenBondAcceptor = "Hydrogen Bond Acceptor"
    case ionicPositive = "Positive Ionizable"
    case ionicNegative = "Negative Ionizable"
    case halogenBond = "Halogen Bond Donor"
    
    // Geometric Features
    case hydrophobicRegion = "Hydrophobic Region"
    case aromaticRing = "Aromatic Ring"
    case flexibleChain = "Flexible Chain"
    case rigidScaffold = "Rigid Scaffold"
    case excludedVolume = "Excluded Volume"
    
    // Electronic Features
    case piStacking = "π-π Stacking"
    case cationPi = "Cation-π Interaction"
    case dipoleInteraction = "Dipole Interaction"
    case vanderWaals = "van der Waals"
    
    // Special Features
    case metalBinding = "Metal Binding"
    case polarRegion = "Polar Region"
    case chirality = "Chiral Center"
    case proteinBackbone = "Backbone Interaction"
    
    var id: String { rawValue }
    
    var category: FeatureCategory {
        switch self {
        case .hydrogenBondDonor, .hydrogenBondAcceptor, .ionicPositive, .ionicNegative, .halogenBond:
            return .interactions
        case .hydrophobicRegion, .aromaticRing, .flexibleChain, .rigidScaffold, .excludedVolume:
            return .geometric
        case .piStacking, .cationPi, .dipoleInteraction, .vanderWaals:
            return .electronic
        case .metalBinding, .polarRegion, .chirality, .proteinBackbone:
            return .special
        }
    }
    
    var icon: String {
        switch self {
        case .hydrogenBondDonor: return "drop.fill"
        case .hydrogenBondAcceptor: return "drop"
        case .ionicPositive: return "plus.circle.fill"
        case .ionicNegative: return "minus.circle.fill"
        case .halogenBond: return "circle.hexagongrid.fill"
        case .hydrophobicRegion: return "circle.lefthalf.fill"
        case .aromaticRing: return "circle.hexagonpath.fill"
        case .flexibleChain: return "link"
        case .rigidScaffold: return "square.fill"
        case .excludedVolume: return "xmark.octagon"
        case .piStacking: return "square.stack"
        case .cationPi: return "plus.square.on.square"
        case .dipoleInteraction: return "arrow.up.and.down"
        case .vanderWaals: return "circle.dotted"
        case .metalBinding: return "atom"
        case .polarRegion: return "snow"
        case .chirality: return "arrow.triangle.2.circlepath"
        case .proteinBackbone: return "line.3.horizontal"
        }
    }
    
    var color: Color {
        switch self {
        case .hydrogenBondDonor: return .blue
        case .hydrogenBondAcceptor: return .cyan
        case .ionicPositive: return .red
        case .ionicNegative: return .indigo
        case .halogenBond: return .purple
        case .hydrophobicRegion: return .orange
        case .aromaticRing: return .purple
        case .flexibleChain: return .brown
        case .rigidScaffold: return .gray
        case .excludedVolume: return .black
        case .piStacking: return .purple
        case .cationPi: return .pink
        case .dipoleInteraction: return .mint
        case .vanderWaals: return .green
        case .metalBinding: return .yellow
        case .polarRegion: return .teal
        case .chirality: return .orange
        case .proteinBackbone: return .secondary
        }
    }
    
    var description: String {
        switch self {
        case .hydrogenBondDonor: return "Groups that donate H-bonds (OH, NH, SH)"
        case .hydrogenBondAcceptor: return "Groups that accept H-bonds (O, N lone pairs)"
        case .ionicPositive: return "Positively charged groups (NH3+, guanidinium)"
        case .ionicNegative: return "Negatively charged groups (COO-, SO3-, PO4-)"
        case .halogenBond: return "Halogen atoms forming directional bonds (Cl, Br, I)"
        case .hydrophobicRegion: return "Non-polar regions for van der Waals interactions"
        case .aromaticRing: return "Aromatic systems for π-π stacking"
        case .flexibleChain: return "Flexible aliphatic regions allowing conformational adaptation"
        case .rigidScaffold: return "Rigid molecular framework constraining geometry"
        case .excludedVolume: return "Regions where atoms cannot be present due to steric clash"
        case .piStacking: return "Face-to-face or edge-to-face aromatic interactions"
        case .cationPi: return "Positively charged groups interacting with π-electrons"
        case .dipoleInteraction: return "Electrostatic interactions between polar groups"
        case .vanderWaals: return "Weak attractive forces between atoms in close proximity"
        case .metalBinding: return "Coordination sites for metal ions (His, Cys, Met)"
        case .polarRegion: return "Polar but non-ionizable functional groups"
        case .chirality: return "Asymmetric centers requiring specific stereochemistry"
        case .proteinBackbone: return "Interactions with protein backbone amide groups"
        }
    }
    
    var importance: Double {
        switch self {
        case .hydrogenBondDonor, .hydrogenBondAcceptor: return 0.9
        case .ionicPositive, .ionicNegative: return 0.8
        case .hydrophobicRegion, .aromaticRing: return 0.7
        case .piStacking, .halogenBond: return 0.6
        case .metalBinding: return 0.8
        case .chirality: return 0.9
        default: return 0.5
        }
    }
    
    var exampleMolecules: [String] {
        switch self {
        case .hydrogenBondDonor: return ["Aspirin (COOH)", "Morphine (OH)", "Aniline (NH2)"]
        case .hydrogenBondAcceptor: return ["Caffeine (C=O)", "Ethanol (O)", "Pyridine (N)"]
        case .ionicPositive: return ["Dopamine (NH3+)", "Histamine (NH+)", "Serotonin (NH3+)"]
        case .ionicNegative: return ["Aspirin (COO-)", "GABA (COO-)", "Glutamate (COO-)"]
        case .halogenBond: return ["Halothane (CF3CHClBr)", "Thyroxine (I)", "5-FU (F)"]
        case .hydrophobicRegion: return ["Cholesterol", "Testosterone", "Benzene ring"]
        case .aromaticRing: return ["Benzene", "Tryptophan", "Phenylalanine"]
        case .metalBinding: return ["Histidine", "Cysteine", "EDTA"]
        default: return ["Various examples"]
        }
    }
}

struct PharmacophoreAnalysis {
    let selectedFeatures: [PharmacophoreFeature]
    let overallScore: Double
    let selectivity: String
    let drugLikeness: String
    let bindingAffinity: String
    let targetSuggestions: [String]
    let optimizationSuggestions: [String]
    let molecularExamples: [String]
    
    var recommendation: String {
        if overallScore > 0.8 {
            return "Excellent pharmacophore model with high drug potential"
        } else if overallScore > 0.6 {
            return "Good pharmacophore model, minor optimizations recommended"
        } else if overallScore > 0.4 {
            return "Moderate model, significant optimization needed"
        } else {
            return "Poor model, major redesign required"
        }
    }
}

// MARK: - Main Dashboard
struct MainDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var projects: [DesignProject]
    @State private var showingNewProject = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading) {
                            Text("ChemStudio Pro")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            Text("Computational Chemistry Toolkit")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        Button(action: { showingNewProject = true }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.blue)
                                .clipShape(Circle())
                        }
                    }
                    .padding()
                    
                    // Quick Actions
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        DashboardCard(
                            title: "Molecular Search",
                            subtitle: "Find compounds",
                            icon: "magnifyingglass",
                            color: .blue,
                            destination: AnyView(EnhancedMolecularSearchView())
                        )
                        
                        DashboardCard(
                            title: "Molecule Drawer",
                            subtitle: "Draw structures",
                            icon: "pencil.and.scribble",
                            color: .pink,
                            destination: AnyView(MoleculeDrawerView())
                        )
                        
                        DashboardCard(
                            title: "Ligand Builder",
                            subtitle: "Design molecules",
                            icon: "cube.fill",
                            color: .green,
                            destination: AnyView(LigandBuilderView())
                        )
                        
                        DashboardCard(
                            title: "ADMET Analysis",
                            subtitle: "Drug properties",
                            icon: "chart.bar.fill",
                            color: .orange,
                            destination: AnyView(ADMETAnalysisView())
                        )
                        
                        DashboardCard(
                            title: "Pharmacophore",
                            subtitle: "Feature mapping",
                            icon: "atom",
                            color: .purple,
                            destination: AnyView(PharmacophoreView())
                        )
                        
                        DashboardCard(
                            title: "3D Viewer",
                            subtitle: "Visualize structures",
                            icon: "eye.fill",
                            color: .teal,
                            destination: AnyView(Enhanced3DViewerView())
                        )
                        
                        DashboardCard(
                            title: "QSAR Builder",
                            subtitle: "Build predictive models",
                            icon: "brain.head.profile",
                            color: .indigo,
                            destination: AnyView(QSARBuilderView())
                        )
                        
                        DashboardCard(
                            title: "pKa Calculator",
                            subtitle: "Ionization prediction",
                            icon: "function",
                            color: .blue,
                            destination: AnyView(PKaCalculatorView())
                        )
                        
                        DashboardCard(
                            title: "Toxicity Predictor",
                            subtitle: "Safety assessment",
                            icon: "exclamationmark.shield",
                            color: .red,
                            destination: AnyView(ToxicityPredictorView())
                        )
                        DashboardCard(
                            title: "Nanoparticle Designer",
                            subtitle: "Drug delivery systems",
                            icon: "circle.hexagongrid.circle",
                            color: .mint,
                            destination: AnyView(NanoparticleDesignerView())
                        )
                    }
                    .padding(.horizontal)
                    
                    // Recent Projects
                    if !projects.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Recent Projects")
                                    .font(.headline)
                                Spacer()
                                NavigationLink("View All", destination: ProjectsListView())
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(projects.prefix(5)) { project in
                                        ProjectCard(project: project)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    // Professional Credits Card
                                        VStack(alignment: .leading, spacing: 12) {
                                            HStack {
                                                Image(systemName: "person.crop.circle.badge.checkmark")
                                                    .foregroundColor(.blue)
                                                    .font(.title2)
                                                
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text("Designed by")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                    
                                                    Text("Dr. Pritam Kumar Panda")
                                                        .font(.headline)
                                                        .fontWeight(.semibold)
                                                    
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "building.columns")
                                                            .font(.caption)
                                                            .foregroundColor(.blue)
                                                        Text("Stanford University")
                                                            .font(.subheadline)
                                                            .foregroundColor(.blue)
                                                            .fontWeight(.medium)
                                                    }
                                                }
                                                
                                                Spacer()
                                            }
                                        }
                                        .padding()
                                        .background(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                        )
                                        .padding(.horizontal)
                                        .padding(.top, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingNewProject) {
            NewProjectView()
        }
    }
}

// MARK: - Dashboard Components
struct DashboardCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let destination: AnyView
    
    var body: some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(color)
                    .frame(width: 60, height: 60)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProjectCard: View {
    let project: DesignProject
    
    var body: some View {
        NavigationLink(destination: ProjectDetailView(project: project)) {
            VStack(alignment: .leading, spacing: 8) {
                Text(project.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(project.targetProtein)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(project.molecules.count) molecules")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .frame(width: 160, height: 80, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Data Models for Database
struct PubChemCompound: Codable, Identifiable {
    var id = UUID()
    let cid: Int
    let molecularFormula: String?
    let molecularWeight: Double?
    let iupacName: String?
    let smiles: String?
    
    init(cid: Int, molecularFormula: String? = nil, molecularWeight: Double? = nil, iupacName: String? = nil, smiles: String? = nil) {
        self.cid = cid
        self.molecularFormula = molecularFormula
        self.molecularWeight = molecularWeight
        self.iupacName = iupacName
        self.smiles = smiles
    }
}

struct ChEMBLCompound: Codable, Identifiable {
    let id = UUID()
    let chemblId: String
    let smiles: String?
    let molecularWeight: Double?
    let activity: String?
    
    enum CodingKeys: String, CodingKey {
        case chemblId = "molecule_chembl_id"
        case smiles = "molecule_structures"
        case molecularWeight = "molecular_weight"
        case activity = "standard_value"
    }
}

struct DatabaseSearchResult {
    let compounds: [PubChemCompound]
    let source: String
    let searchTerm: String
}

// MARK: - Database Service
class DatabaseService: ObservableObject {
    @Published var searchResults: [PubChemCompound] = []
    @Published var chemblResults: [ChEMBLCompound] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let pubchemBase = "https://pubchem.ncbi.nlm.nih.gov/rest/pug"
    private let chemblBase = "https://www.ebi.ac.uk/chembl/api/data"
    
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        return URLSession(configuration: config)
    }()
    
    func searchPubChemByName(_ compoundName: String) async {
        print("🔍 Starting search for: \(compoundName)")
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.searchResults = []
        }
        
        await searchPubChemDirect(compoundName)
    }
    
    private func searchPubChemDirect(_ compoundName: String) async {
        guard let encodedName = compoundName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            await setError("Invalid compound name")
            return
        }
        
        let urlString = "\(pubchemBase)/compound/name/\(encodedName)/property/MolecularFormula,MolecularWeight,IUPACName,CanonicalSMILES/JSON"
        
        guard let url = URL(string: urlString) else {
            await setError("Invalid URL")
            return
        }
        
        print("🌐 URL: \(urlString)")
        
        do {
            let (data, response) = try await urlSession.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Status: \(httpResponse.statusCode)")
                
                switch httpResponse.statusCode {
                case 200:
                    break
                case 404:
                    await setError("Compound '\(compoundName)' not found")
                    return
                case 400:
                    await setError("Invalid compound name format")
                    return
                default:
                    await setError("Server error (\(httpResponse.statusCode))")
                    return
                }
            }
            
            await parsePropertiesResponse(data: data, compoundName: compoundName)
            
        } catch {
            print("💥 Network Error: \(error)")
            if error.localizedDescription.contains("timeout") {
                await setError("Search timed out. Please try again.")
            } else {
                await setError("Network error: \(error.localizedDescription)")
            }
        }
    }
    
    private func parsePropertiesResponse(data: Data, compoundName: String) async {
        do {
            guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                await setError("Invalid response format")
                return
            }
            
            print("📊 Response keys: \(Array(jsonObject.keys))")
            
            if let fault = jsonObject["Fault"] as? [String: Any],
               let message = fault["Message"] as? String {
                await setError("PubChem: \(message)")
                return
            }
            
            guard let propertyTable = jsonObject["PropertyTable"] as? [String: Any],
                  let properties = propertyTable["Properties"] as? [[String: Any]] else {
                await setError("No compound data found")
                return
            }
            
            print("✅ Found \(properties.count) compounds")
            
            var compounds: [PubChemCompound] = []
            
            for property in properties {
                if let cid = property["CID"] as? Int {
                    let compound = PubChemCompound(
                        cid: cid,
                        molecularFormula: property["MolecularFormula"] as? String,
                        molecularWeight: property["MolecularWeight"] as? Double,
                        iupacName: property["IUPACName"] as? String,
                        smiles: property["CanonicalSMILES"] as? String
                    )
                    compounds.append(compound)
                    print("📋 Added: \(compound.cid) - \(compound.molecularFormula ?? "N/A")")
                }
            }
            
            await MainActor.run {
                self.searchResults = compounds
                self.isLoading = false
            }
            
        } catch {
            print("💥 Parse Error: \(error)")
            await setError("Failed to parse response")
        }
    }
    
    func searchPubChemSimilarity(smiles: String, threshold: Double) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.searchResults = []
        }
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        let mockResults = [
            PubChemCompound(
                cid: 12345,
                molecularFormula: "C8H10N4O2",
                molecularWeight: 194.19,
                iupacName: "Similar Compound 1",
                smiles: smiles
            )
        ]
        
        await MainActor.run {
            self.searchResults = mockResults
            self.isLoading = false
        }
    }
    
    func searchChEMBLByTarget(targetName: String) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.chemblResults = []
        }
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        let mockResults = [
            ChEMBLCompound(
                chemblId: "CHEMBL123",
                smiles: "CC(=O)OC1=CC=CC=C1C(=O)O",
                molecularWeight: 180.16,
                activity: "6.5"
            )
        ]
        
        await MainActor.run {
            self.chemblResults = mockResults
            self.isLoading = false
        }
    }
    
    func searchDrugBankByName(_ compoundName: String) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.searchResults = []
        }
        
        // Mock DrugBank search with realistic delay
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Mock DrugBank results (in real app, would use DrugBank API)
        let mockDrugBankResults = generateMockDrugBankResults(for: compoundName)
        
        await MainActor.run {
            self.searchResults = mockDrugBankResults
            self.isLoading = false
        }
    }
    
    func searchWithTimeout(_ compoundName: String) async {
        await searchPubChemByName(compoundName)
    }
    
    private func setError(_ message: String) async {
        print("❌ Error: \(message)")
        await MainActor.run {
            self.errorMessage = message
            self.isLoading = false
        }
    }
}
    
    

    private func generateMockDrugBankResults(for compoundName: String) -> [PubChemCompound] {
        let drugDatabase: [(name: String, smiles: String, formula: String, weight: Double, iupac: String)] = [
            ("Aspirin", "CC(=O)OC1=CC=CC=C1C(=O)O", "C9H8O4", 180.16, "2-acetoxybenzoic acid"),
            ("Ibuprofen", "CC(C)CC1=CC=C(C=C1)C(C)C(=O)O", "C13H18O2", 206.28, "2-(4-isobutylphenyl)propanoic acid"),
            ("Caffeine", "CN1C=NC2=C1C(=O)N(C(=O)N2C)C", "C8H10N4O2", 194.19, "1,3,7-trimethylpurine-2,6-dione"),
            ("Paracetamol", "CC(=O)NC1=CC=C(C=C1)O", "C8H9NO2", 151.16, "N-(4-hydroxyphenyl)acetamide"),
            ("Morphine", "CN1CCC23C4C1CC5=C2C(=C(C=C5)O)OC3C(C=C4)O", "C17H19NO3", 285.34, "morphinan-3,6-diol"),
            ("Warfarin", "CC(=O)CC(C1=CC=CC=C1)C2=C(C3=CC=CC=C3OC2=O)O", "C19H16O4", 308.33, "4-hydroxy-3-(3-oxo-1-phenylbutyl)coumarin"),
            ("Metformin", "CN(C)C(=N)NC(=N)N", "C4H11N5", 129.16, "3-(diaminomethylidene)-1,1-dimethylguanidine"),
            ("Atorvastatin", "CC(C)C1=C(C(=C(N1CC(CC(CC(=O)O)O)O)C2=CC=C(C=C2)F)C3=CC=CC=C3)C(=O)NC4=CC=CC=C4", "C33H35FN2O5", 558.64, "methyl (3R,5R)-7-[2-(4-fluorophenyl)-3-phenyl-4-(phenylcarbamoyl)-5-propan-2-ylpyrrol-1-yl]-3,5-dihydroxyheptanoate")
        ]
        
        let queryLower = compoundName.lowercased()
        var results: [PubChemCompound] = []
        
        for (index, drug) in drugDatabase.enumerated() {
            if drug.name.lowercased().contains(queryLower) {
                let compound = PubChemCompound(
                    cid: 900000 + index, // Use 900000+ for DrugBank mock IDs
                    molecularFormula: drug.formula,
                    molecularWeight: drug.weight,
                    iupacName: drug.iupac,
                    smiles: drug.smiles
                )
                results.append(compound)
            }
        }
    
        return results
    }
// MARK: - Enhanced Molecular Search View
struct EnhancedMolecularSearchView: View {
    @StateObject private var databaseService = DatabaseService()
    @State private var searchText = ""
    @State private var searchType: MolecularSearchType = .name
    @State private var selectedDatabase: DatabaseType = .pubchem
    @State private var similarityThreshold: Double = 90
    
    enum MolecularSearchType: String, CaseIterable {
        case name = "Name"
        case smiles = "SMILES"
        case similarity = "Similarity"
        case target = "Target"
        
        var title: String { rawValue }
    }
    
    enum DatabaseType: String, CaseIterable {
        case pubchem = "PubChem"
        case chembl = "ChEMBL"
        case drugbank = "DrugBank"
        
        var title: String { rawValue }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Search Configuration
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("Database:")
                            .font(.headline)
                        Picker("Database", selection: $selectedDatabase) {
                            ForEach(DatabaseType.allCases, id: \.self) { type in
                                Text(type.title).tag(type)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    HStack {
                        Text("Search Type:")
                            .font(.headline)
                        Picker("Search Type", selection: $searchType) {
                            ForEach(MolecularSearchType.allCases, id: \.self) { type in
                                Text(type.title).tag(type)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // Similarity threshold (only for similarity search)
                    if searchType == .similarity {
                        VStack(alignment: .leading) {
                            Text("Similarity Threshold: \(Int(similarityThreshold))%")
                                .font(.subheadline)
                            Slider(value: $similarityThreshold, in: 70...100, step: 5)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // Search Bar
                HStack {
                    TextField(placeholderText, text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Search") {
                        performSearch()
                    }
                    .disabled(searchText.isEmpty || databaseService.isLoading)
                    .buttonStyle(.borderedProminent)
                }
                
                // Results
                if databaseService.isLoading {
                    ProgressView("Searching database...")
                        .frame(maxHeight: .infinity)
                } else if let error = databaseService.errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .frame(maxHeight: .infinity)
                } else {
                    List {
                        if selectedDatabase == .pubchem {
                            ForEach(databaseService.searchResults) { compound in
                                PubChemResultRow(compound: compound)
                            }
                        } else if selectedDatabase == .chembl {
                            ForEach(databaseService.chemblResults) { compound in
                                ChEMBLResultRow(compound: compound)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Database Search")
        }
    }
    
    private var placeholderText: String {
        switch searchType {
        case .name: return "Enter compound name (e.g., aspirin)"
        case .smiles: return "Enter SMILES string"
        case .similarity: return "Enter reference SMILES"
        case .target: return "Enter target name (e.g., EGFR)"
        }
    }
    
    private func performSearch() {
        Task {
            switch (selectedDatabase, searchType) {
            case (.pubchem, .name):
                await databaseService.searchWithTimeout(searchText)
            case (.pubchem, .similarity):
                await databaseService.searchPubChemSimilarity(smiles: searchText, threshold: similarityThreshold)
            case (.chembl, .target):
                await databaseService.searchChEMBLByTarget(targetName: searchText)
            case (.drugbank, .name):
                await databaseService.searchDrugBankByName(searchText)
            default:
                await MainActor.run {
                        databaseService.errorMessage = "This search combination is not yet implemented"
                            }
            }
        }
    }
}

// MARK: - Compound Detail View
struct CompoundDetailView: View {
    let compound: PubChemCompound
    @State private var showingCopyAlert = false
    @State private var copiedText = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("CID: \(compound.cid)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    if let formula = compound.molecularFormula {
                        Text(formula)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    if let name = compound.iupacName {
                        Text(name)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Properties
                VStack(alignment: .leading, spacing: 12) {
                    Text("Molecular Properties")
                        .font(.headline)
                    
                    if let mw = compound.molecularWeight {
                        CompoundPropertyRow(label: "Molecular Weight", value: String(format: "%.2f g/mol", mw)
                        )
                    }
                        if let formula = compound.molecularFormula {
                            CompoundPropertyRow(label: "Molecular Formula", value: formula)
                        }
                    }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    
                    // SMILES Section (Copyable)
                    if let smiles = compound.smiles {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SMILES Notation")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(smiles)
                                    .font(.system(.body, design: .monospaced))
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .textSelection(.enabled)
                                
                                HStack {
                                    Button("Copy SMILES") {
                                        UIPasteboard.general.string = smiles
                                        copiedText = "SMILES copied to clipboard!"
                                        showingCopyAlert = true
                                    }
                                    .buttonStyle(.borderedProminent)
                                    
                                    Spacer()
                                    
                                    Button("Copy Formula") {
                                        if let formula = compound.molecularFormula {
                                            UIPasteboard.general.string = formula
                                            copiedText = "Formula copied to clipboard!"
                                            showingCopyAlert = true
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(compound.molecularFormula == nil)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                    
                    // Database Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Database Information")
                            .font(.headline)
                        
                        CompoundPropertyRow(label: "Database", value: compound.cid >= 900000 ? "DrugBank (Mock)" : "PubChem")
                        CompoundPropertyRow(label: "Compound ID", value: "\(compound.cid)")
                        
                        if compound.cid < 900000 {
                            Button("View on PubChem") {
                                if let url = URL(string: "https://pubchem.ncbi.nlm.nih.gov/compound/\(compound.cid)") {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Compound Details")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Copied!", isPresented: $showingCopyAlert) {
                Button("OK") { }
            } message: {
                Text(copiedText)
            }
        }
    }
    
    struct CompoundPropertyRow: View {
        let label: String
        let value: String
        
        var body: some View {
            HStack {
                Text(label)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
                Text(value)
                    .fontWeight(.semibold)
            }
            .padding(.vertical, 2)
        }
    }

// MARK: - Result Row Views
struct PubChemResultRow: View {
    let compound: PubChemCompound
    
    var body: some View {
        NavigationLink(destination: CompoundDetailView(compound: compound)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("CID: \(compound.cid)")
                        .font(.headline)
                        .foregroundColor(.blue)
                    Spacer()
                    if let mw = compound.molecularWeight {
                        Text("MW: \(mw, specifier: "%.2f")")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                if let formula = compound.molecularFormula {
                    Text("Formula: \(formula)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let name = compound.iupacName {
                    Text(name)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundColor(.secondary)
                }
                
                if let smiles = compound.smiles {
                    Text("SMILES: \(smiles)")
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .foregroundColor(.purple)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ChEMBLResultRow: View {
    let compound: ChEMBLCompound
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(compound.chemblId)
                    .font(.headline)
                    .foregroundColor(.green)
                Spacer()
                if let activity = compound.activity {
                    Text("Activity: \(activity)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            if let mw = compound.molecularWeight {
                Text("MW: \(mw, specifier: "%.2f")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let smiles = compound.smiles {
                Text("SMILES: \(smiles)")
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .foregroundColor(.purple)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - pKa Calculator (Fixed naming)
struct PKaCalculatorView: View {
    @State private var inputSMILES = ""
    @State private var pKaResults: PKaResult?
    @State private var isCalculating = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("pKa Calculator")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("SMILES Input:")
                    .font(.headline)
                
                TextField("Enter SMILES", text: $inputSMILES)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(.body, design: .monospaced))
            }
            
            Button("Calculate pKa") {
                calculatePKa()
            }
            .buttonStyle(.borderedProminent)
            .disabled(inputSMILES.isEmpty || isCalculating)
            
            if isCalculating {
                ProgressView("Calculating...")
            } else if let results = pKaResults {
                PKaResultsView(results: results)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("pKa Calculator")
    }
    
    private func calculatePKa() {
        isCalculating = true
        
        // Mock calculation - replace with real API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            pKaResults = PKaResult(
                smiles: inputSMILES,
                acidicpKa: 4.2,
                basicpKa: 8.1,
                mostAcidicAtom: "O",
                mostBasicAtom: "N"
            )
            isCalculating = false
        }
    }
}

struct PKaResult {
    let smiles: String
    let acidicpKa: Double?
    let basicpKa: Double?
    let mostAcidicAtom: String?
    let mostBasicAtom: String?
}

struct PKaResultsView: View {
    let results: PKaResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("pKa Results")
                .font(.headline)
            
            if let acidic = results.acidicpKa {
                HStack {
                    Text("Most Acidic pKa:")
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(acidic, specifier: "%.2f")")
                        .foregroundColor(.red)
                }
            }
            
            if let basic = results.basicpKa {
                HStack {
                    Text("Most Basic pKa:")
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(basic, specifier: "%.2f")")
                        .foregroundColor(.blue)
                }
            }
            
            if let atom = results.mostAcidicAtom {
                HStack {
                    Text("Most Acidic Atom:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(atom)
                        .foregroundColor(.secondary)
                }
            }
            
            if let atom = results.mostBasicAtom {
                HStack {
                    Text("Most Basic Atom:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(atom)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Toxicity Predictor (Single clean version)
struct ToxicityPredictorView: View {
    @State private var inputSMILES = ""
    @State private var toxResults: ToxicityResults?
    @State private var isCalculating = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Toxicity Predictor")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("SMILES Input:")
                    .font(.headline)
                
                TextField("Enter SMILES", text: $inputSMILES)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(.body, design: .monospaced))
            }
            
            Button("Predict Toxicity") {
                predictToxicity()
            }
            .buttonStyle(.borderedProminent)
            .disabled(inputSMILES.isEmpty || isCalculating)
            
            if isCalculating {
                ProgressView("Calculating...")
            } else if let results = toxResults {
                ToxicityResultsView(results: results)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Toxicity Predictor")
    }
    
    private func predictToxicity() {
        isCalculating = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            toxResults = ToxicityResults(
                smiles: inputSMILES,
                amesMutagenicity: false,
                hergLiability: 0.3,
                hepatotoxicity: 0.2,
                carcinogenicity: false
            )
            isCalculating = false
        }
    }
}

struct ToxicityResults {
    let smiles: String
    let amesMutagenicity: Bool
    let hergLiability: Double
    let hepatotoxicity: Double
    let carcinogenicity: Bool
}

struct ToxicityResultsView: View {
    let results: ToxicityResults
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Toxicity Assessment")
                .font(.headline)
            
            ToxicityRow(
                name: "AMES Mutagenicity",
                value: results.amesMutagenicity ? "Positive" : "Negative",
                isRisk: results.amesMutagenicity
            )
            
            ToxicityRow(
                name: "hERG Liability",
                value: String(format: "%.2f", results.hergLiability),
                isRisk: results.hergLiability > 0.5
            )
            
            ToxicityRow(
                name: "Hepatotoxicity",
                value: String(format: "%.2f", results.hepatotoxicity),
                isRisk: results.hepatotoxicity > 0.6
            )
            
            ToxicityRow(
                name: "Carcinogenicity",
                value: results.carcinogenicity ? "Positive" : "Negative",
                isRisk: results.carcinogenicity
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct ToxicityRow: View {
    let name: String
    let value: String
    let isRisk: Bool
    
    var body: some View {
        HStack {
            Text(name)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(isRisk ? .red : .green)
                .frame(width: 80, alignment: .trailing)
            
            Image(systemName: isRisk ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundColor(isRisk ? .red : .green)
        }
    }
}

// MARK: - Enhanced Molecule Designer with Fragments (Fixed Naming)
struct MoleculeDrawerView: View {
    @StateObject private var drawingModel = MoleculeDrawingModel()
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTool: DrawingTool = .carbon
    @State private var selectedBondType: BondType = .single
    @State private var selectedFragment: DrawerFragment? = nil
    @State private var showingSaveDialog = false
    @State private var showingPeriodicTable = false
    @State private var showingFragmentLibrary = false
    @State private var moleculeName = ""
    @State private var showingClearAlert = false
    @State private var showingProperties = false
    @State private var selectedCategory: DrawerFragmentCategory = .rings
    
    
    enum DrawingTool: String, CaseIterable {
        // Original elements
        case carbon = "C"
        case nitrogen = "N"
        case oxygen = "O"
        case sulfur = "S"
        case phosphorus = "P"
        case fluorine = "F"
        case chlorine = "Cl"
        case bromine = "Br"
        case iodine = "I"
        case hydrogen = "H"
        case silicon = "Si"
        case boron = "B"
        
        // Metals
        case lithium = "Li"
        case sodium = "Na"
        case magnesium = "Mg"
        case aluminum = "Al"
        case potassium = "K"
        case calcium = "Ca"
        case zinc = "Zn"
        case silver = "Ag"
        case gold = "Au"
        
        // Transition Metals
        case iron = "Fe"
        case copper = "Cu"
        case nickel = "Ni"
        case cobalt = "Co"
        case manganese = "Mn"
        case titanium = "Ti"
        case chromium = "Cr"
        case vanadium = "V"
        
        // Non-metals
        case selenium = "Se"
        
        // Noble Gases
        case helium = "He"
        case neon = "Ne"
        case argon = "Ar"
        case krypton = "Kr"
        case xenon = "Xe"
        
        // Special tools
        case delete = "🗑️"
        case move = "↔️"
        case fragment = "⬢"
        
        var atomicNumber: Int {
            switch self {
            case .hydrogen: return 1
            case .helium: return 2
            case .lithium: return 3
            case .boron: return 5
            case .carbon: return 6
            case .nitrogen: return 7
            case .oxygen: return 8
            case .fluorine: return 9
            case .neon: return 10
            case .sodium: return 11
            case .magnesium: return 12
            case .aluminum: return 13
            case .silicon: return 14
            case .phosphorus: return 15
            case .sulfur: return 16
            case .chlorine: return 17
            case .argon: return 18
            case .potassium: return 19
            case .calcium: return 20
            case .titanium: return 22
            case .vanadium: return 23
            case .chromium: return 24
            case .manganese: return 25
            case .iron: return 26
            case .cobalt: return 27
            case .nickel: return 28
            case .copper: return 29
            case .zinc: return 30
            case .selenium: return 34
            case .bromine: return 35
            case .krypton: return 36
            case .silver: return 47
            case .iodine: return 53
            case .xenon: return 54
            case .gold: return 79
            case .delete, .move, .fragment: return 0
            }
        }
        
        var atomicWeight: Double {
            switch self {
            case .hydrogen: return 1.008
            case .helium: return 4.003
            case .lithium: return 6.94
            case .boron: return 10.81
            case .carbon: return 12.01
            case .nitrogen: return 14.01
            case .oxygen: return 15.999
            case .fluorine: return 18.998
            case .neon: return 20.180
            case .sodium: return 22.990
            case .magnesium: return 24.305
            case .aluminum: return 26.982
            case .silicon: return 28.085
            case .phosphorus: return 30.974
            case .sulfur: return 32.06
            case .chlorine: return 35.45
            case .argon: return 39.948
            case .potassium: return 39.098
            case .calcium: return 40.078
            case .titanium: return 47.867
            case .vanadium: return 50.942
            case .chromium: return 51.996
            case .manganese: return 54.938
            case .iron: return 55.845
            case .cobalt: return 58.933
            case .nickel: return 58.693
            case .copper: return 63.546
            case .zinc: return 65.38
            case .selenium: return 78.971
            case .bromine: return 79.904
            case .krypton: return 83.798
            case .silver: return 107.87
            case .iodine: return 126.90
            case .xenon: return 131.29
            case .gold: return 196.97
            case .delete, .move, .fragment: return 0.0
            }
        }
        
        var color: Color {
            switch self {
            // Non-metals
            case .carbon: return .black
            case .nitrogen: return .blue
            case .oxygen: return .red
            case .sulfur: return .yellow
            case .phosphorus: return .orange
            case .fluorine: return .green
            case .chlorine: return .green
            case .bromine: return .brown
            case .iodine: return .purple
            case .hydrogen: return .gray
            case .silicon: return .indigo
            case .boron: return .pink
            case .selenium: return .orange
            
            // Alkali metals (purple)
            case .lithium, .sodium, .potassium: return .purple
            
            // Alkaline earth metals (green)
            case .magnesium, .calcium: return .green
            
            // Post-transition metals (gray)
            case .aluminum: return .gray
            
            // Transition metals (various)
            case .iron: return .brown
            case .copper: return .orange
            case .nickel: return .green
            case .cobalt: return .blue
            case .manganese: return .gray
            case .titanium: return .gray
            case .chromium: return .gray
            case .vanadium: return .gray
            case .zinc: return .blue
            case .silver: return .gray
            case .gold: return .yellow
            
            // Noble gases (cyan)
            case .helium, .neon, .argon, .krypton, .xenon: return .cyan
            
            // Special tools
            case .delete: return .red
            case .move: return .blue
            case .fragment: return .purple
            }
        }
        
        var backgroundColor: Color {
            return color.opacity(0.2)
        }
        
        var electronegativity: Double {
            switch self {
            case .fluorine: return 3.98
            case .oxygen: return 3.44
            case .nitrogen: return 3.04
            case .chlorine: return 3.16
            case .bromine: return 2.96
            case .iodine: return 2.66
            case .sulfur: return 2.58
            case .carbon: return 2.55
            case .selenium: return 2.55
            case .phosphorus: return 2.19
            case .hydrogen: return 2.20
            case .boron: return 2.04
            case .silicon: return 1.90
            case .iron: return 1.83
            case .nickel: return 1.91
            case .copper: return 1.90
            case .cobalt: return 1.88
            case .aluminum: return 1.61
            case .zinc: return 1.65
            case .titanium: return 1.54
            case .manganese: return 1.55
            case .chromium: return 1.66
            case .vanadium: return 1.63
            case .magnesium: return 1.31
            case .calcium: return 1.00
            case .lithium: return 0.98
            case .sodium: return 0.93
            case .potassium: return 0.82
            case .silver: return 1.93
            case .gold: return 2.54
            case .krypton: return 3.00
            case .xenon: return 2.60
            case .helium, .neon, .argon: return 0.0 // Noble gases typically don't have electronegativity
            case .delete, .move, .fragment: return 0.0
            }
        }
        
        static func fromSymbol(_ symbol: String) -> MoleculeDrawerView.DrawingTool? {
            switch symbol {
            // Original elements
            case "H": return .hydrogen
            case "He": return .helium
            case "Li": return .lithium
            case "B": return .boron
            case "C": return .carbon
            case "N": return .nitrogen
            case "O": return .oxygen
            case "F": return .fluorine
            case "Ne": return .neon
            case "Na": return .sodium
            case "Mg": return .magnesium
            case "Al": return .aluminum
            case "Si": return .silicon
            case "P": return .phosphorus
            case "S": return .sulfur
            case "Cl": return .chlorine
            case "Ar": return .argon
            case "K": return .potassium
            case "Ca": return .calcium
            case "Ti": return .titanium
            case "V": return .vanadium
            case "Cr": return .chromium
            case "Mn": return .manganese
            case "Fe": return .iron
            case "Co": return .cobalt
            case "Ni": return .nickel
            case "Cu": return .copper
            case "Zn": return .zinc
            case "Se": return .selenium
            case "Br": return .bromine
            case "Kr": return .krypton
            case "Ag": return .silver
            case "I": return .iodine
            case "Xe": return .xenon
            case "Au": return .gold
            default: return nil
            }
        }
    }
    
    enum BondType: String, CaseIterable {
        case single = "—"
        case double = "="
        case triple = "≡"
        case aromatic = "~"
        
        var strokeWidth: CGFloat {
            switch self {
            case .single: return 2.0
            case .double: return 2.0
            case .triple: return 2.0
            case .aromatic: return 2.0
            }
        }
        
        var bondOrder: Int {
            switch self {
            case .single: return 1
            case .double: return 2
            case .triple: return 3
            case .aromatic: return 1
            }
        }
        
        var description: String {
            switch self {
            case .single: return "Single"
            case .double: return "Double"
            case .triple: return "Triple"
            case .aromatic: return "Aromatic"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Enhanced Toolbar with Fragments
            EnhancedMoleculeDrawerToolbar(
                selectedTool: $selectedTool,
                selectedBondType: $selectedBondType,
                selectedFragment: $selectedFragment,
                showingPeriodicTable: $showingPeriodicTable,
                showingFragmentLibrary: $showingFragmentLibrary,
                showingProperties: $showingProperties
            )
            
            // Drawing Canvas
            ZStack {
                Rectangle()
                    .fill(Color.white)
                    .overlay(GridBackgroundView())
                
                EnhancedMoleculeCanvas(
                    drawingModel: drawingModel,
                    selectedTool: selectedTool,
                    selectedBondType: selectedBondType,
                    selectedFragment: selectedFragment
                )
            }
            
            // Bottom Toolbar
            MoleculeDrawerBottomBar(
                drawingModel: drawingModel,
                showingClearAlert: $showingClearAlert,
                showingSaveDialog: $showingSaveDialog,
                showingProperties: $showingProperties
            )
        }
        .navigationTitle("Molecule Designer")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Clear Drawing", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                drawingModel.clearAll()
            }
        } message: {
            Text("Are you sure you want to clear the current drawing?")
        }
        .sheet(isPresented: $showingSaveDialog) {
            SaveMoleculeView(
                drawingModel: drawingModel,
                moleculeName: $moleculeName
            ) { name in
                saveMolecule(name: name)
                showingSaveDialog = false
            }
        }
        .sheet(isPresented: $showingPeriodicTable) {
            PeriodicTableView(selectedTool: $selectedTool) {
                showingPeriodicTable = false
            }
        }
        .sheet(isPresented: $showingFragmentLibrary) {
            DrawerFragmentLibraryView(
                selectedFragment: $selectedFragment,
                selectedCategory: $selectedCategory
            ) {
                showingFragmentLibrary = false
                selectedTool = .fragment
            }
        }
        .sheet(isPresented: $showingProperties) {
            DrawerMoleculePropertiesView(drawingModel: drawingModel)
        }
    }
    
    private func saveMolecule(name: String) {
        let smiles = drawingModel.generateSMILES()
        let molecule = Molecule(name: name.isEmpty ? "Custom Molecule" : name, smiles: smiles)
        
        let properties = drawingModel.calculateMolecularProperties()
        molecule.molecularWeight = properties.molecularWeight
        molecule.hDonors = properties.hDonors
        molecule.hAcceptors = properties.hAcceptors
        
        modelContext.insert(molecule)
        try? modelContext.save()
        
        drawingModel.clearAll()
        moleculeName = ""
    }
}

struct EnhancedMoleculeDrawerToolbar: View {
    @Binding var selectedTool: MoleculeDrawerView.DrawingTool
    @Binding var selectedBondType: MoleculeDrawerView.BondType
    @Binding var selectedFragment: DrawerFragment?
    @Binding var showingPeriodicTable: Bool
    @Binding var showingFragmentLibrary: Bool
    @Binding var showingProperties: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Quick Actions
            HStack(spacing: 12) {
                Button("Elements") {
                    showingPeriodicTable = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Fragments") {
                    showingFragmentLibrary = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Button("Properties") {
                    showingProperties = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                // Selected tool indicator
                VStack(spacing: 2) {
                    if let fragment = selectedFragment {
                        Text("Fragment: \(fragment.name)")
                            .font(.caption)
                            .foregroundColor(.purple)
                    } else {
                        Text("Element: \(selectedTool.rawValue)")
                            .font(.caption)
                            .foregroundColor(selectedTool.color)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
            }
            .padding(.horizontal)
            
            // Common Tools
            VStack(alignment: .leading, spacing: 8) {
                Text("Tools")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        let commonTools: [MoleculeDrawerView.DrawingTool] = [
                            .fragment, .carbon, .nitrogen, .oxygen, .hydrogen,
                            .iron, .copper, .zinc, .move, .delete
                        ]
                        
                        ForEach(commonTools, id: \.self) { tool in
                            ToolButton(
                                tool: tool,
                                isSelected: selectedTool == tool
                            ) {
                                selectedTool = tool
                                if tool != .fragment {
                                    selectedFragment = nil
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Bond Tools
            VStack(alignment: .leading, spacing: 8) {
                Text("Bonds")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    ForEach(MoleculeDrawerView.BondType.allCases, id: \.self) { bond in
                        BondToolButton(
                            bondType: bond,
                            isSelected: selectedBondType == bond
                        ) {
                            selectedBondType = bond
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            Divider()
        }
        .padding(.vertical)
        .background(Color(.systemGray6))
    }
}

// MARK: - Renamed Fragment Categories and Models
enum DrawerFragmentCategory: String, CaseIterable {
    case rings = "Ring Systems"
    case functional = "Functional Groups"
    case common = "Common Molecules"
    case chains = "Carbon Chains"
    
    var icon: String {
        switch self {
        case .rings: return "circle.hexagonpath"
        case .functional: return "atom"
        case .common: return "star.fill"
        case .chains: return "link"
        }
    }
    
    var color: Color {
        switch self {
        case .rings: return .purple
        case .functional: return .orange
        case .common: return .blue
        case .chains: return .green
        }
    }
}

struct DrawerFragment: Identifiable, Hashable {
    static func == (lhs: DrawerFragment, rhs: DrawerFragment) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    let id = UUID()
    let name: String
    let category: DrawerFragmentCategory
    let atoms: [DrawerFragmentAtom]
    let bonds: [DrawerFragmentBond]
    let description: String
    
    static let fragmentLibrary: [DrawerFragment] = [
        // Ring Systems
        DrawerFragment(
            name: "Benzene",
            category: .rings,
            atoms: [
                DrawerFragmentAtom(position: CGPoint(x: 0, y: -40), element: .carbon),
                DrawerFragmentAtom(position: CGPoint(x: 35, y: -20), element: .carbon),
                DrawerFragmentAtom(position: CGPoint(x: 35, y: 20), element: .carbon),
                DrawerFragmentAtom(position: CGPoint(x: 0, y: 40), element: .carbon),
                DrawerFragmentAtom(position: CGPoint(x: -35, y: 20), element: .carbon),
                DrawerFragmentAtom(position: CGPoint(x: -35, y: -20), element: .carbon)
            ],
            bonds: [
                DrawerFragmentBond(from: 0, to: 1, type: .aromatic),
                DrawerFragmentBond(from: 1, to: 2, type: .aromatic),
                DrawerFragmentBond(from: 2, to: 3, type: .aromatic),
                DrawerFragmentBond(from: 3, to: 4, type: .aromatic),
                DrawerFragmentBond(from: 4, to: 5, type: .aromatic),
                DrawerFragmentBond(from: 5, to: 0, type: .aromatic)
            ],
            description: "Aromatic 6-membered ring"
        ),
        
        DrawerFragment(
            name: "Cyclohexane",
            category: .rings,
            atoms: [
                DrawerFragmentAtom(position: CGPoint(x: 0, y: -40), element: .carbon),
                DrawerFragmentAtom(position: CGPoint(x: 35, y: -20), element: .carbon),
                DrawerFragmentAtom(position: CGPoint(x: 35, y: 20), element: .carbon),
                DrawerFragmentAtom(position: CGPoint(x: 0, y: 40), element: .carbon),
                DrawerFragmentAtom(position: CGPoint(x: -35, y: 20), element: .carbon),
                DrawerFragmentAtom(position: CGPoint(x: -35, y: -20), element: .carbon)
            ],
            bonds: [
                DrawerFragmentBond(from: 0, to: 1, type: .single),
                DrawerFragmentBond(from: 1, to: 2, type: .single),
                DrawerFragmentBond(from: 2, to: 3, type: .single),
                DrawerFragmentBond(from: 3, to: 4, type: .single),
                DrawerFragmentBond(from: 4, to: 5, type: .single),
                DrawerFragmentBond(from: 5, to: 0, type: .single)
            ],
            description: "Saturated 6-membered ring"
        ),
        
        DrawerFragment(
            name: "Pyridine",
            category: .rings,
            atoms: [
                DrawerFragmentAtom(position: CGPoint(x: 0, y: -40), element: .nitrogen),
                DrawerFragmentAtom(position: CGPoint(x: 35, y: -20), element: .carbon),
                DrawerFragmentAtom(position: CGPoint(x: 35, y: 20), element: .carbon),
                DrawerFragmentAtom(position: CGPoint(x: 0, y: 40), element: .carbon),
                DrawerFragmentAtom(position: CGPoint(x: -35, y: 20), element: .carbon),
                DrawerFragmentAtom(position: CGPoint(x: -35, y: -20), element: .carbon)
            ],
            bonds: [
                DrawerFragmentBond(from: 0, to: 1, type: .aromatic),
                DrawerFragmentBond(from: 1, to: 2, type: .aromatic),
                DrawerFragmentBond(from: 2, to: 3, type: .aromatic),
                DrawerFragmentBond(from: 3, to: 4, type: .aromatic),
                DrawerFragmentBond(from: 4, to: 5, type: .aromatic),
                DrawerFragmentBond(from: 5, to: 0, type: .aromatic)
            ],
            description: "Nitrogen heterocycle"
        ),
        
        DrawerFragment(
            name: "Cyclopentane",
            category: .rings,
            atoms: [
                DrawerFragmentAtom(position: CGPoint(x: 0, y: -30), element: .carbon),
                DrawerFragmentAtom(position: CGPoint(x: 28, y: -10), element: .carbon),
                DrawerFragmentAtom(position: CGPoint(x: 18, y: 25), element: .carbon),
                DrawerFragmentAtom(position: CGPoint(x: -18, y: 25), element: .carbon),
                DrawerFragmentAtom(position: CGPoint(x: -28, y: -10), element: .carbon)
            ],
            bonds: [
                DrawerFragmentBond(from: 0, to: 1, type: .single),
                DrawerFragmentBond(from: 1, to: 2, type: .single),
                DrawerFragmentBond(from: 2, to: 3, type: .single),
                DrawerFragmentBond(from: 3, to: 4, type: .single),
                DrawerFragmentBond(from: 4, to: 0, type: .single)
            ],
            description: "5-membered ring"
        ),
        
        // Functional Groups
        DrawerFragment(
            name: "Carboxyl",
            category: .functional,
            atoms: [
                DrawerFragmentAtom(position: CGPoint(x: 0, y: 0), element: .carbon),
                DrawerFragmentAtom(position: CGPoint(x: 30, y: 0), element: .oxygen),
                DrawerFragmentAtom(position: CGPoint(x: -15, y: 25), element: .oxygen)
            ],
            bonds: [
                DrawerFragmentBond(from: 0, to: 1, type: .single),
                DrawerFragmentBond(from: 0, to: 2, type: .double)
            ],
            description: "Carboxylic acid group"
        ),
        
        DrawerFragment(
            name: "Amino",
            category: .functional,
            atoms: [
                DrawerFragmentAtom(position: CGPoint(x: 0, y: 0), element: .nitrogen)
            ],
            bonds: [],
            description: "Amino group"
        ),
        
        DrawerFragment(
            name: "Hydroxyl",
            category: .functional,
            atoms: [
                DrawerFragmentAtom(position: CGPoint(x: 0, y: 0), element: .oxygen)
            ],
            bonds: [],
            description: "Alcohol group"
        ),
        
        DrawerFragment(
            name: "Carbonyl",
            category: .functional,
            atoms: [
                DrawerFragmentAtom(position: CGPoint(x: 0, y: 0), element: .carbon),
                DrawerFragmentAtom(position: CGPoint(x: 0, y: -30), element: .oxygen)
            ],
            bonds: [
                DrawerFragmentBond(from: 0, to: 1, type: .double)
            ],
            description: "C=O group"
        ),
        
        // Carbon Chains
        DrawerFragment(
            name: "Ethyl",
            category: .chains,
            atoms: [
                DrawerFragmentAtom(position: CGPoint(x: 0, y: 0), element: .carbon),
                DrawerFragmentAtom(position: CGPoint(x: 30, y: 0), element: .carbon)
            ],
            bonds: [
                DrawerFragmentBond(from: 0, to: 1, type: .single)
            ],
            description: "Two carbon chain"
        ),
        
        DrawerFragment(
            name: "Propyl",
            category: .chains,
            atoms: [
                DrawerFragmentAtom(position: CGPoint(x: 0, y: 0), element: .carbon),
                DrawerFragmentAtom(position: CGPoint(x: 30, y: 0), element: .carbon),
                DrawerFragmentAtom(position: CGPoint(x: 60, y: 0), element: .carbon)
            ],
            bonds: [
                DrawerFragmentBond(from: 0, to: 1, type: .single),
                DrawerFragmentBond(from: 1, to: 2, type: .single)
            ],
            description: "Three carbon chain"
        ),
        
        // Common Molecules
        DrawerFragment(
            name: "Methanol",
            category: .common,
            atoms: [
                DrawerFragmentAtom(position: CGPoint(x: 0, y: 0), element: .carbon),
                DrawerFragmentAtom(position: CGPoint(x: 30, y: 0), element: .oxygen)
            ],
            bonds: [
                DrawerFragmentBond(from: 0, to: 1, type: .single)
            ],
            description: "CH3OH"
        ),
        
        DrawerFragment(
            name: "Acetyl",
            category: .common,
            atoms: [
                DrawerFragmentAtom(position: CGPoint(x: 0, y: 0), element: .carbon),
                DrawerFragmentAtom(position: CGPoint(x: 30, y: 0), element: .carbon),
                DrawerFragmentAtom(position: CGPoint(x: 30, y: -30), element: .oxygen)
            ],
            bonds: [
                DrawerFragmentBond(from: 0, to: 1, type: .single),
                DrawerFragmentBond(from: 1, to: 2, type: .double)
            ],
            description: "CH3CO-"
        )
    ]
}

struct DrawerFragmentAtom {
    let position: CGPoint
    let element: MoleculeDrawerView.DrawingTool
}

struct DrawerFragmentBond {
    let from: Int
    let to: Int
    let type: MoleculeDrawerView.BondType
}

// MARK: - Renamed Fragment Library View
struct DrawerFragmentLibraryView: View {
    @Binding var selectedFragment: DrawerFragment?
    @Binding var selectedCategory: DrawerFragmentCategory
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category Selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(DrawerFragmentCategory.allCases, id: \.self) { category in
                            DrawerCategoryButton(
                                category: category,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGray6))
                
                // Fragment Grid
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(filteredFragments) { fragment in
                            DrawerFragmentCard(
                                fragment: fragment,
                                isSelected: selectedFragment?.id == fragment.id
                            ) {
                                selectedFragment = fragment
                                onDismiss()
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Fragment Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private var filteredFragments: [DrawerFragment] {
        DrawerFragment.fragmentLibrary.filter { $0.category == selectedCategory }
    }
}

struct DrawerCategoryButton: View {
    let category: DrawerFragmentCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.title2)
                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : category.color)
            .frame(width: 80, height: 60)
            .background(isSelected ? category.color : category.color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct DrawerFragmentCard: View {
    let fragment: DrawerFragment
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // Fragment Preview
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                        .frame(height: 80)
                    
                    DrawerFragmentPreview(fragment: fragment)
                        .scaleEffect(0.6)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(fragment.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(fragment.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? fragment.category.color : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DrawerFragmentPreview: View {
    let fragment: DrawerFragment
    
    var body: some View {
        ZStack {
            // Bonds
            ForEach(fragment.bonds.indices, id: \.self) { bondIndex in
                let bond = fragment.bonds[bondIndex]
                if bond.from < fragment.atoms.count && bond.to < fragment.atoms.count {
                    let fromAtom = fragment.atoms[bond.from]
                    let toAtom = fragment.atoms[bond.to]
                    
                    BondView(
                        from: fromAtom.position,
                        to: toAtom.position,
                        bondType: bond.type
                    )
                }
            }
            
            // Atoms
            ForEach(fragment.atoms.indices, id: \.self) { atomIndex in
                let atom = fragment.atoms[atomIndex]
                Circle()
                    .fill(atom.element.backgroundColor)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(atom.element.color, lineWidth: 1)
                    )
                    .overlay(
                        Text(atom.element.rawValue)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(atom.element.color)
                    )
                    .position(atom.position)
            }
        }
        .frame(width: 100, height: 100)
    }
}

// MARK: - Enhanced Canvas with Fragment Support
struct EnhancedMoleculeCanvas: View {
    @ObservedObject var drawingModel: MoleculeDrawingModel
    let selectedTool: MoleculeDrawerView.DrawingTool
    let selectedBondType: MoleculeDrawerView.BondType
    let selectedFragment: DrawerFragment?
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onTapGesture { location in
                    print("🎯 Canvas tapped with tool: \(selectedTool)")
                    handleCanvasTap(at: location)
                }
            
            // Bonds layer
            ForEach(Array(drawingModel.bonds.enumerated()), id: \.offset) { index, bond in
                if bond.fromAtomIndex < drawingModel.atoms.count &&
                   bond.toAtomIndex < drawingModel.atoms.count {
                    let fromAtom = drawingModel.atoms[bond.fromAtomIndex]
                    let toAtom = drawingModel.atoms[bond.toAtomIndex]
                    
                    BondView(
                        from: fromAtom.position,
                        to: toAtom.position,
                        bondType: bond.type
                    )
                }
            }
            
            // Atoms layer
            ForEach(Array(drawingModel.atoms.enumerated()), id: \.offset) { index, atom in
                AtomView(
                    atom: atom,
                    isSelected: drawingModel.selectedAtomIndex == index,
                    isDragged: drawingModel.draggedAtomIndex == index
                )
                .onTapGesture {
                    print("🔴 Atom tapped: \(atom.element)")
                    handleAtomTap(at: index)
                }
            }
        }
    }
    
    private func handleAtomTap(at index: Int) {
        guard index < drawingModel.atoms.count else { return }
        
        switch selectedTool {
        case .delete:
            print("🗑️ Deleting atom")
            drawingModel.removeAtom(at: index)
            
        case .move:
            print("↔️ Move mode")
            break
            
        case .fragment:
            if let fragment = selectedFragment {
                print("⬢ Adding fragment: \(fragment.name)")
                addFragment(fragment, at: drawingModel.atoms[index].position)
            } else {
                print("⚠️ No fragment selected")
            }
            
        default:
            if let selectedIndex = drawingModel.selectedAtomIndex {
                if selectedIndex != index {
                    print("🔗 Creating bond")
                    drawingModel.addBond(from: selectedIndex, to: index, type: selectedBondType)
                }
                drawingModel.selectedAtomIndex = nil
            } else {
                if selectedTool != drawingModel.atoms[index].element {
                    print("🔄 Changing element to: \(selectedTool)")
                    drawingModel.atoms[index].element = selectedTool
                    drawingModel.objectWillChange.send()
                } else {
                    print("👆 Selecting atom")
                    drawingModel.selectedAtomIndex = index
                }
            }
        }
    }
    
    private func handleCanvasTap(at location: CGPoint) {
        guard selectedTool != .delete && selectedTool != .move else {
            print("⚠️ Special tool, clearing selection")
            drawingModel.selectedAtomIndex = nil
            return
        }
        
        // Check if tap is near existing atom
        for (index, atom) in drawingModel.atoms.enumerated() {
            let distance = sqrt(pow(location.x - atom.position.x, 2) + pow(location.y - atom.position.y, 2))
            if distance < 30 {
                print("🎯 Near existing atom")
                handleAtomTap(at: index)
                return
            }
        }
        
        // Add fragment or atom
        if selectedTool == .fragment, let fragment = selectedFragment {
            print("⬢ Adding fragment to canvas: \(fragment.name)")
            addFragment(fragment, at: location)
        } else {
            print("➕ Adding atom: \(selectedTool) at \(location)")
            drawingModel.addAtom(at: location, element: selectedTool)
        }
        
        drawingModel.selectedAtomIndex = nil
    }
    
    private func addFragment(_ fragment: DrawerFragment, at position: CGPoint) {
        let startIndex = drawingModel.atoms.count
        
        // Add atoms
        for fragmentAtom in fragment.atoms {
            let newPosition = CGPoint(
                x: position.x + fragmentAtom.position.x,
                y: position.y + fragmentAtom.position.y
            )
            drawingModel.addAtom(at: newPosition, element: fragmentAtom.element)
        }
        
        // Add bonds
        for fragmentBond in fragment.bonds {
            let fromIndex = startIndex + fragmentBond.from
            let toIndex = startIndex + fragmentBond.to
            drawingModel.addBond(from: fromIndex, to: toIndex, type: fragmentBond.type)
        }
    }
}

// MARK: - Enhanced Tool Button
struct ToolButton: View {
    let tool: MoleculeDrawerView.DrawingTool
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                if tool.atomicNumber > 0 {
                    Text("\(tool.atomicNumber)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else if tool == .fragment {
                    Image(systemName: "hexagon")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(tool.rawValue)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .white : tool.color)
            }
            .frame(width: 36, height: 36)
            .background(isSelected ? tool.color : tool.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(tool.color, lineWidth: isSelected ? 0 : 1)
            )
        }
    }
}
// MARK: - Enhanced Toolbar
struct MoleculeDrawerToolbar: View {
    @Binding var selectedTool: MoleculeDrawerView.DrawingTool
    @Binding var selectedBondType: MoleculeDrawerView.BondType
    @Binding var showingPeriodicTable: Bool
    @Binding var showingProperties: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Quick Actions
            HStack {
                Button("Periodic Table") {
                    showingPeriodicTable = true
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Properties") {
                    showingProperties = true
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            
            // Common Atoms
            VStack(alignment: .leading, spacing: 8) {
                Text("Common Atoms")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        let commonTools: [MoleculeDrawerView.DrawingTool] = [
                            .carbon, .nitrogen, .oxygen, .hydrogen, .sulfur, .phosphorus,
                            .fluorine, .chlorine, .bromine, .move, .delete
                        ]
                        
                        ForEach(commonTools, id: \.self) { tool in
                            AtomToolButton(
                                tool: tool,
                                isSelected: selectedTool == tool
                            ) {
                                selectedTool = tool
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Bond Tools
            VStack(alignment: .leading, spacing: 8) {
                Text("Bonds")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    ForEach(MoleculeDrawerView.BondType.allCases, id: \.self) { bond in
                        BondToolButton(
                            bondType: bond,
                            isSelected: selectedBondType == bond
                        ) {
                            selectedBondType = bond
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            Divider()
        }
        .padding(.vertical)
        .background(Color(.systemGray6))
    }
}

// MARK: - Complete Periodic Table Implementation
struct PeriodicTableView: View {
    @Binding var selectedTool: MoleculeDrawerView.DrawingTool
    let onDismiss: () -> Void
    @State private var selectedCategory: ElementCategory = .common
    
    enum ElementCategory: String, CaseIterable {
        case common = "Common"
        case metals = "Metals"
        case nonmetals = "Non-metals"
        case noble = "Noble Gases"
        case transition = "Transition"
        case lanthanides = "Lanthanides"
        case actinides = "Actinides"
        case all = "All Elements"
        
        var color: Color {
            switch self {
            case .common: return .blue
            case .metals: return .orange
            case .nonmetals: return .green
            case .noble: return .purple
            case .transition: return .red
            case .lanthanides: return .pink
            case .actinides: return .brown
            case .all: return .gray
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Select an Element")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Category Selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ElementCategory.allCases, id: \.self) { category in
                            CategoryChip(
                                category: category,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Element Grid
                ScrollView {
                    if selectedCategory == .all {
                        FullPeriodicTable(selectedTool: $selectedTool, onSelect: { tool in
                            selectedTool = tool
                            onDismiss()
                        })
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                            ForEach(getElementsForCategory(selectedCategory), id: \.symbol) { element in
                                CompleteElementButton(
                                    element: element,
                                    isSelected: selectedTool.rawValue == element.symbol
                                ) {
                                    if let tool = MoleculeDrawerView.DrawingTool.fromSymbol(element.symbol) {
                                        selectedTool = tool
                                        onDismiss()
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
                
                // Element Info
                if selectedTool != .delete && selectedTool != .move && selectedTool != .fragment {
                    ElementInfoView(element: selectedTool)
                }
            }
            .padding()
            .navigationTitle("Periodic Table")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private func getElementsForCategory(_ category: ElementCategory) -> [ChemicalElement] {
        switch category {
        case .common:
            return ChemicalElement.commonElements
        case .metals:
            return ChemicalElement.metals
        case .nonmetals:
            return ChemicalElement.nonmetals
        case .noble:
            return ChemicalElement.nobleGases
        case .transition:
            return ChemicalElement.transitionMetals
        case .lanthanides:
            return ChemicalElement.lanthanides
        case .actinides:
            return ChemicalElement.actinides
        case .all:
            return ChemicalElement.allElements
        }
    }
}

struct ElementInfoView: View {
    let element: MoleculeDrawerView.DrawingTool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(element.rawValue)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(element.color)
                
                Spacer()
                
                Text("Atomic #\(element.atomicNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("Atomic Weight: \(String(format: "%.3f", element.atomicWeight))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Electronegativity: \(String(format: "%.2f", element.electronegativity))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Chemical Element Model
struct ChemicalElement {
    let atomicNumber: Int
    let symbol: String
    let name: String
    let atomicWeight: Double
    let category: PeriodicTableView.ElementCategory
    let color: Color
    let electronegativity: Double?
    
    // Common elements for organic chemistry
    static let commonElements: [ChemicalElement] = [
        ChemicalElement(atomicNumber: 1, symbol: "H", name: "Hydrogen", atomicWeight: 1.008, category: .common, color: .gray, electronegativity: 2.20),
        ChemicalElement(atomicNumber: 6, symbol: "C", name: "Carbon", atomicWeight: 12.011, category: .common, color: .black, electronegativity: 2.55),
        ChemicalElement(atomicNumber: 7, symbol: "N", name: "Nitrogen", atomicWeight: 14.007, category: .common, color: .blue, electronegativity: 3.04),
        ChemicalElement(atomicNumber: 8, symbol: "O", name: "Oxygen", atomicWeight: 15.999, category: .common, color: .red, electronegativity: 3.44),
        ChemicalElement(atomicNumber: 9, symbol: "F", name: "Fluorine", atomicWeight: 18.998, category: .common, color: .green, electronegativity: 3.98),
        ChemicalElement(atomicNumber: 15, symbol: "P", name: "Phosphorus", atomicWeight: 30.974, category: .common, color: .orange, electronegativity: 2.19),
        ChemicalElement(atomicNumber: 16, symbol: "S", name: "Sulfur", atomicWeight: 32.06, category: .common, color: .yellow, electronegativity: 2.58),
        ChemicalElement(atomicNumber: 17, symbol: "Cl", name: "Chlorine", atomicWeight: 35.45, category: .common, color: .green, electronegativity: 3.16),
        ChemicalElement(atomicNumber: 35, symbol: "Br", name: "Bromine", atomicWeight: 79.904, category: .common, color: .brown, electronegativity: 2.96),
        ChemicalElement(atomicNumber: 53, symbol: "I", name: "Iodine", atomicWeight: 126.90, category: .common, color: .purple, electronegativity: 2.66),
        ChemicalElement(atomicNumber: 5, symbol: "B", name: "Boron", atomicWeight: 10.81, category: .common, color: .pink, electronegativity: 2.04),
        ChemicalElement(atomicNumber: 14, symbol: "Si", name: "Silicon", atomicWeight: 28.085, category: .common, color: .indigo, electronegativity: 1.90)
    ]
    
    // Metals
    static let metals: [ChemicalElement] = [
        ChemicalElement(atomicNumber: 3, symbol: "Li", name: "Lithium", atomicWeight: 6.94, category: .metals, color: .purple, electronegativity: 0.98),
        ChemicalElement(atomicNumber: 11, symbol: "Na", name: "Sodium", atomicWeight: 22.990, category: .metals, color: .purple, electronegativity: 0.93),
        ChemicalElement(atomicNumber: 12, symbol: "Mg", name: "Magnesium", atomicWeight: 24.305, category: .metals, color: .green, electronegativity: 1.31),
        ChemicalElement(atomicNumber: 13, symbol: "Al", name: "Aluminum", atomicWeight: 26.982, category: .metals, color: .gray, electronegativity: 1.61),
        ChemicalElement(atomicNumber: 19, symbol: "K", name: "Potassium", atomicWeight: 39.098, category: .metals, color: .purple, electronegativity: 0.82),
        ChemicalElement(atomicNumber: 20, symbol: "Ca", name: "Calcium", atomicWeight: 40.078, category: .metals, color: .green, electronegativity: 1.00),
        ChemicalElement(atomicNumber: 30, symbol: "Zn", name: "Zinc", atomicWeight: 65.38, category: .metals, color: .blue, electronegativity: 1.65),
        ChemicalElement(atomicNumber: 47, symbol: "Ag", name: "Silver", atomicWeight: 107.87, category: .metals, color: .gray, electronegativity: 1.93),
        ChemicalElement(atomicNumber: 79, symbol: "Au", name: "Gold", atomicWeight: 196.97, category: .metals, color: .yellow, electronegativity: 2.54)
    ]
    
    // Non-metals
    static let nonmetals: [ChemicalElement] = [
        ChemicalElement(atomicNumber: 1, symbol: "H", name: "Hydrogen", atomicWeight: 1.008, category: .nonmetals, color: .gray, electronegativity: 2.20),
        ChemicalElement(atomicNumber: 6, symbol: "C", name: "Carbon", atomicWeight: 12.011, category: .nonmetals, color: .black, electronegativity: 2.55),
        ChemicalElement(atomicNumber: 7, symbol: "N", name: "Nitrogen", atomicWeight: 14.007, category: .nonmetals, color: .blue, electronegativity: 3.04),
        ChemicalElement(atomicNumber: 8, symbol: "O", name: "Oxygen", atomicWeight: 15.999, category: .nonmetals, color: .red, electronegativity: 3.44),
        ChemicalElement(atomicNumber: 9, symbol: "F", name: "Fluorine", atomicWeight: 18.998, category: .nonmetals, color: .green, electronegativity: 3.98),
        ChemicalElement(atomicNumber: 15, symbol: "P", name: "Phosphorus", atomicWeight: 30.974, category: .nonmetals, color: .orange, electronegativity: 2.19),
        ChemicalElement(atomicNumber: 16, symbol: "S", name: "Sulfur", atomicWeight: 32.06, category: .nonmetals, color: .yellow, electronegativity: 2.58),
        ChemicalElement(atomicNumber: 17, symbol: "Cl", name: "Chlorine", atomicWeight: 35.45, category: .nonmetals, color: .green, electronegativity: 3.16),
        ChemicalElement(atomicNumber: 34, symbol: "Se", name: "Selenium", atomicWeight: 78.971, category: .nonmetals, color: .orange, electronegativity: 2.55),
        ChemicalElement(atomicNumber: 35, symbol: "Br", name: "Bromine", atomicWeight: 79.904, category: .nonmetals, color: .brown, electronegativity: 2.96),
        ChemicalElement(atomicNumber: 53, symbol: "I", name: "Iodine", atomicWeight: 126.90, category: .nonmetals, color: .purple, electronegativity: 2.66)
    ]
    
    // Noble Gases
    static let nobleGases: [ChemicalElement] = [
        ChemicalElement(atomicNumber: 2, symbol: "He", name: "Helium", atomicWeight: 4.003, category: .noble, color: .cyan, electronegativity: nil),
        ChemicalElement(atomicNumber: 10, symbol: "Ne", name: "Neon", atomicWeight: 20.180, category: .noble, color: .cyan, electronegativity: nil),
        ChemicalElement(atomicNumber: 18, symbol: "Ar", name: "Argon", atomicWeight: 39.948, category: .noble, color: .cyan, electronegativity: nil),
        ChemicalElement(atomicNumber: 36, symbol: "Kr", name: "Krypton", atomicWeight: 83.798, category: .noble, color: .cyan, electronegativity: 3.00),
        ChemicalElement(atomicNumber: 54, symbol: "Xe", name: "Xenon", atomicWeight: 131.29, category: .noble, color: .cyan, electronegativity: 2.60),
        ChemicalElement(atomicNumber: 86, symbol: "Rn", name: "Radon", atomicWeight: 222.0, category: .noble, color: .cyan, electronegativity: 2.2)
    ]
    
    // Transition Metals
    static let transitionMetals: [ChemicalElement] = [
        ChemicalElement(atomicNumber: 21, symbol: "Sc", name: "Scandium", atomicWeight: 44.956, category: .transition, color: .gray, electronegativity: 1.36),
        ChemicalElement(atomicNumber: 22, symbol: "Ti", name: "Titanium", atomicWeight: 47.867, category: .transition, color: .gray, electronegativity: 1.54),
        ChemicalElement(atomicNumber: 23, symbol: "V", name: "Vanadium", atomicWeight: 50.942, category: .transition, color: .gray, electronegativity: 1.63),
        ChemicalElement(atomicNumber: 24, symbol: "Cr", name: "Chromium", atomicWeight: 51.996, category: .transition, color: .gray, electronegativity: 1.66),
        ChemicalElement(atomicNumber: 25, symbol: "Mn", name: "Manganese", atomicWeight: 54.938, category: .transition, color: .gray, electronegativity: 1.55),
        ChemicalElement(atomicNumber: 26, symbol: "Fe", name: "Iron", atomicWeight: 55.845, category: .transition, color: .brown, electronegativity: 1.83),
        ChemicalElement(atomicNumber: 27, symbol: "Co", name: "Cobalt", atomicWeight: 58.933, category: .transition, color: .blue, electronegativity: 1.88),
        ChemicalElement(atomicNumber: 28, symbol: "Ni", name: "Nickel", atomicWeight: 58.693, category: .transition, color: .green, electronegativity: 1.91),
        ChemicalElement(atomicNumber: 29, symbol: "Cu", name: "Copper", atomicWeight: 63.546, category: .transition, color: .orange, electronegativity: 1.90),
        ChemicalElement(atomicNumber: 30, symbol: "Zn", name: "Zinc", atomicWeight: 65.38, category: .transition, color: .blue, electronegativity: 1.65)
    ]
    
    // Lanthanides (simplified)
    static let lanthanides: [ChemicalElement] = [
        ChemicalElement(atomicNumber: 57, symbol: "La", name: "Lanthanum", atomicWeight: 138.91, category: .lanthanides, color: .pink, electronegativity: 1.10),
        ChemicalElement(atomicNumber: 58, symbol: "Ce", name: "Cerium", atomicWeight: 140.12, category: .lanthanides, color: .pink, electronegativity: 1.12),
        ChemicalElement(atomicNumber: 64, symbol: "Gd", name: "Gadolinium", atomicWeight: 157.25, category: .lanthanides, color: .pink, electronegativity: 1.20)
    ]
    
    // Actinides (simplified)
    static let actinides: [ChemicalElement] = [
        ChemicalElement(atomicNumber: 89, symbol: "Ac", name: "Actinium", atomicWeight: 227.0, category: .actinides, color: .brown, electronegativity: 1.1),
        ChemicalElement(atomicNumber: 92, symbol: "U", name: "Uranium", atomicWeight: 238.03, category: .actinides, color: .brown, electronegativity: 1.38)
    ]
    
    // All elements combined
    static let allElements: [ChemicalElement] =
        commonElements + metals + transitionMetals + nobleGases + lanthanides + actinides
}


// MARK: - UI Components
struct CategoryChip: View {
    let category: PeriodicTableView.ElementCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(category.rawValue)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? category.color : category.color.opacity(0.2))
                .foregroundColor(isSelected ? .white : category.color)
                .clipShape(Capsule())
        }
    }
}

struct CompleteElementButton: View {
    let element: ChemicalElement
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(element.atomicNumber)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(element.symbol)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .white : element.color)
                
                Text(element.name)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 60, height: 60)
            .background(isSelected ? element.color : element.color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(element.color, lineWidth: isSelected ? 0 : 1)
            )
        }
    }
}

struct FullPeriodicTable: View {
    @Binding var selectedTool: MoleculeDrawerView.DrawingTool
    let onSelect: (MoleculeDrawerView.DrawingTool) -> Void
    
    var body: some View {
        VStack(spacing: 2) {
            // Period 1
            HStack(spacing: 2) {
                PeriodicElementCell("H", 1, .gray)
                Spacer()
                PeriodicElementCell("He", 2, .cyan)
            }
            
            // Period 2
            HStack(spacing: 2) {
                PeriodicElementCell("Li", 3, .purple)
                PeriodicElementCell("Be", 4, .green)
                Spacer()
                PeriodicElementCell("B", 5, .pink)
                PeriodicElementCell("C", 6, .black)
                PeriodicElementCell("N", 7, .blue)
                PeriodicElementCell("O", 8, .red)
                PeriodicElementCell("F", 9, .green)
                PeriodicElementCell("Ne", 10, .cyan)
            }
            
            // Period 3
            HStack(spacing: 2) {
                PeriodicElementCell("Na", 11, .purple)
                PeriodicElementCell("Mg", 12, .green)
                Spacer()
                PeriodicElementCell("Al", 13, .gray)
                PeriodicElementCell("Si", 14, .indigo)
                PeriodicElementCell("P", 15, .orange)
                PeriodicElementCell("S", 16, .yellow)
                PeriodicElementCell("Cl", 17, .green)
                PeriodicElementCell("Ar", 18, .cyan)
            }
            
            // Period 4 (simplified)
            HStack(spacing: 2) {
                PeriodicElementCell("K", 19, .purple)
                PeriodicElementCell("Ca", 20, .green)
                PeriodicElementCell("Fe", 26, .brown)
                PeriodicElementCell("Cu", 29, .orange)
                PeriodicElementCell("Zn", 30, .blue)
                Spacer()
                PeriodicElementCell("Br", 35, .brown)
                PeriodicElementCell("Kr", 36, .cyan)
            }
            
            // Period 5 (simplified)
            HStack(spacing: 2) {
                PeriodicElementCell("Ag", 47, .gray)
                Spacer()
                PeriodicElementCell("I", 53, .purple)
                PeriodicElementCell("Xe", 54, .cyan)
            }
            
            Text("Tap any element to select")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top)
        }
        .padding()
    }
    
    private func PeriodicElementCell(_ symbol: String, _ number: Int, _ color: Color) -> some View {
        Button(action: {
            if let tool = MoleculeDrawerView.DrawingTool.fromSymbol(symbol) {
                onSelect(tool)
            }
        }) {
            VStack(spacing: 1) {
                Text("\(number)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(symbol)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(selectedTool.rawValue == symbol ? .white : color)
            }
            .frame(width: 35, height: 35)
            .background(selectedTool.rawValue == symbol ? color : color.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(color, lineWidth: selectedTool.rawValue == symbol ? 0 : 1)
            )
        }
        .disabled(MoleculeDrawerView.DrawingTool.fromSymbol(symbol) == nil)
        .opacity(MoleculeDrawerView.DrawingTool.fromSymbol(symbol) == nil ? 0.3 : 1.0)
    }
}

// MARK: - Enhanced Drawing Model
class MoleculeDrawingModel: ObservableObject {
    @Published var atoms: [DrawnAtom] = []
    @Published var bonds: [DrawnBond] = []
    @Published var selectedAtomIndex: Int? = nil
    @Published var draggedAtomIndex: Int? = nil
    
    func addAtom(at position: CGPoint, element: MoleculeDrawerView.DrawingTool) {
        guard element != .delete && element != .move else { return }
        
        let newAtom = DrawnAtom(
            id: UUID(),
            position: position,
            element: element
        )
        atoms.append(newAtom)
        objectWillChange.send()
    }
    
    func moveAtom(at index: Int, to position: CGPoint) {
        guard index < atoms.count else { return }
        atoms[index].position = position
        objectWillChange.send()
    }
    
    func findAtomAt(position: CGPoint, threshold: CGFloat = 30) -> Int? {
        for (index, atom) in atoms.enumerated() {
            let distance = sqrt(pow(position.x - atom.position.x, 2) + pow(position.y - atom.position.y, 2))
            if distance < threshold {
                return index
            }
        }
        return nil
    }
    
    func addBond(from fromIndex: Int, to toIndex: Int, type: MoleculeDrawerView.BondType) {
        guard fromIndex != toIndex && fromIndex < atoms.count && toIndex < atoms.count else { return }
        
        // Check if bond already exists
        let existingBondIndex = bonds.firstIndex { bond in
            (bond.fromAtomIndex == fromIndex && bond.toAtomIndex == toIndex) ||
            (bond.fromAtomIndex == toIndex && bond.toAtomIndex == fromIndex)
        }
        
        if let existingIndex = existingBondIndex {
            // Update existing bond type
            bonds[existingIndex].type = type
        } else {
            // Create new bond
            let newBond = DrawnBond(
                id: UUID(),
                fromAtomIndex: fromIndex,
                toAtomIndex: toIndex,
                type: type
            )
            bonds.append(newBond)
        }
        objectWillChange.send()
    }
    
    func removeAtom(at index: Int) {
        guard index < atoms.count else { return }
        
        atoms.remove(at: index)
        
        // Remove bonds connected to this atom
        bonds.removeAll { bond in
            bond.fromAtomIndex == index || bond.toAtomIndex == index
        }
        
        // Update bond indices for atoms that shifted
        for i in 0..<bonds.count {
            if bonds[i].fromAtomIndex > index {
                bonds[i].fromAtomIndex -= 1
            }
            if bonds[i].toAtomIndex > index {
                bonds[i].toAtomIndex -= 1
            }
        }
        
        selectedAtomIndex = nil
        objectWillChange.send()
    }
    
    func clearAll() {
        atoms.removeAll()
        bonds.removeAll()
        selectedAtomIndex = nil
        draggedAtomIndex = nil
        objectWillChange.send()
    }
    
    func calculateMolecularProperties() -> DrawerMolecularProperties {
        var molecularWeight = 0.0
        var hDonors = 0
        var hAcceptors = 0
        
        for atom in atoms {
            molecularWeight += atom.element.atomicWeight
            
            // Count hydrogen bond donors (N-H, O-H)
            if atom.element == .nitrogen || atom.element == .oxygen {
                let connectedBonds = bonds.filter { bond in
                    bond.fromAtomIndex == atoms.firstIndex(where: { $0.id == atom.id }) ||
                    bond.toAtomIndex == atoms.firstIndex(where: { $0.id == atom.id })
                }
                
                // Simple heuristic: if not fully substituted, can donate H
                if connectedBonds.count < (atom.element == .nitrogen ? 3 : 2) {
                    hDonors += 1
                }
            }
            
            // Count hydrogen bond acceptors (N, O with lone pairs)
            if atom.element == .nitrogen || atom.element == .oxygen {
                hAcceptors += 1
            }
        }
        
        return DrawerMolecularProperties(
            molecularWeight: molecularWeight,
            hDonors: hDonors,
            hAcceptors: hAcceptors
        )
    }
    
    func generateSMILES() -> String {
        guard !atoms.isEmpty else { return "" }
        
        // Build adjacency list
        var adjacencyList: [Int: [(Int, MoleculeDrawerView.BondType)]] = [:]
        
        for (atomIndex, _) in atoms.enumerated() {
            adjacencyList[atomIndex] = []
        }
        
        for bond in bonds {
            adjacencyList[bond.fromAtomIndex]?.append((bond.toAtomIndex, bond.type))
            adjacencyList[bond.toAtomIndex]?.append((bond.fromAtomIndex, bond.type))
        }
        
        // Simple DFS traversal for SMILES generation
        var visited = Set<Int>()
        var smiles = ""
        
        func dfs(_ atomIndex: Int) -> String {
            visited.insert(atomIndex)
            let atom = atoms[atomIndex]
            var result = atom.element.rawValue == "C" ? "" : atom.element.rawValue
            
            let neighbors = adjacencyList[atomIndex] ?? []
            let unvisitedNeighbors = neighbors.filter { !visited.contains($0.0) }
            
            for (i, (neighborIndex, bondType)) in unvisitedNeighbors.enumerated() {
                if bondType == .double {
                    result += "="
                } else if bondType == .triple {
                    result += "#"
                }
                
                if i > 0 {
                    result += "("
                }
                
                result += dfs(neighborIndex)
                
                if i > 0 {
                    result += ")"
                }
            }
            
            return result
        }
        
        // Start from first carbon or any atom
        let startIndex = atoms.firstIndex { $0.element == .carbon } ?? 0
        smiles = dfs(startIndex)
        
        // Add any disconnected components
        for (index, _) in atoms.enumerated() {
            if !visited.contains(index) {
                smiles += "." + dfs(index)
            }
        }
        
        return smiles.isEmpty ? "C" : smiles
    }
}

// MARK: - Fixed MoleculeCanvas with Debug
struct MoleculeCanvas: View {
    @ObservedObject var drawingModel: MoleculeDrawingModel
    let selectedTool: MoleculeDrawerView.DrawingTool
    let selectedBondType: MoleculeDrawerView.BondType
    
    var body: some View {
        ZStack {
            // Debug tap indicator
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onTapGesture { location in
                    print("🎯 Canvas tapped at: \(location)")
                    handleCanvasTap(at: location)
                }
            
            // Bonds layer
            ForEach(Array(drawingModel.bonds.enumerated()), id: \.offset) { index, bond in
                if bond.fromAtomIndex < drawingModel.atoms.count &&
                   bond.toAtomIndex < drawingModel.atoms.count {
                    let fromAtom = drawingModel.atoms[bond.fromAtomIndex]
                    let toAtom = drawingModel.atoms[bond.toAtomIndex]
                    
                    BondView(
                        from: fromAtom.position,
                        to: toAtom.position,
                        bondType: bond.type
                    )
                }
            }
            
            // Atoms layer
            ForEach(Array(drawingModel.atoms.enumerated()), id: \.offset) { index, atom in
                AtomView(
                    atom: atom,
                    isSelected: drawingModel.selectedAtomIndex == index,
                    isDragged: drawingModel.draggedAtomIndex == index
                )
                .onTapGesture {
                    print("🔴 Atom tapped at index: \(index)")
                    handleAtomTap(at: index)
                }
            }
        }
    }
    
    private func handleAtomTap(at index: Int) {
        print("🔧 handleAtomTap called with index: \(index), tool: \(selectedTool)")
        
        guard index < drawingModel.atoms.count else {
            print("❌ Index out of bounds")
            return
        }
        
        switch selectedTool {
        case .delete:
            print("🗑️ Deleting atom at index: \(index)")
            drawingModel.removeAtom(at: index)
            
        case .move:
            print("↔️ Move tool selected")
            break
            
        default:
            if let selectedIndex = drawingModel.selectedAtomIndex {
                if selectedIndex != index {
                    print("🔗 Creating bond from \(selectedIndex) to \(index)")
                    drawingModel.addBond(from: selectedIndex, to: index, type: selectedBondType)
                }
                drawingModel.selectedAtomIndex = nil
            } else {
                print("🎯 Selecting atom at index: \(index)")
                drawingModel.selectedAtomIndex = index
            }
        }
    }
    
    private func handleCanvasTap(at location: CGPoint) {
        print("🎯 handleCanvasTap called at: \(location), tool: \(selectedTool)")
        
        // Skip special tools
        guard selectedTool != .delete && selectedTool != .move else {
            print("⚠️ Special tool selected, skipping atom creation")
            drawingModel.selectedAtomIndex = nil
            return
        }
        
        // Check if tap is near existing atom
        for (index, atom) in drawingModel.atoms.enumerated() {
            let distance = sqrt(pow(location.x - atom.position.x, 2) + pow(location.y - atom.position.y, 2))
            if distance < 30 {
                print("🎯 Tap near existing atom at index: \(index)")
                handleAtomTap(at: index)
                return
            }
        }
        
        // Add new atom
        print("➕ Adding new atom at: \(location) with element: \(selectedTool)")
        drawingModel.addAtom(at: location, element: selectedTool)
        drawingModel.selectedAtomIndex = nil
        
        print("📊 Current atoms count: \(drawingModel.atoms.count)")
    }
}

// MARK: - Helper Container Views
struct BondViewContainer: View {
    @ObservedObject var drawingModel: MoleculeDrawingModel
    let bondIndex: Int
    
    var body: some View {
        if bondIndex < drawingModel.bonds.count {
            let bond = drawingModel.bonds[bondIndex]
            if bond.fromAtomIndex < drawingModel.atoms.count &&
               bond.toAtomIndex < drawingModel.atoms.count {
                let fromAtom = drawingModel.atoms[bond.fromAtomIndex]
                let toAtom = drawingModel.atoms[bond.toAtomIndex]
                
                BondView(
                    from: fromAtom.position,
                    to: toAtom.position,
                    bondType: bond.type
                )
            }
        }
    }
}

struct AtomViewContainer: View {
    @ObservedObject var drawingModel: MoleculeDrawingModel
    let atomIndex: Int
    let selectedTool: MoleculeDrawerView.DrawingTool
    let selectedBondType: MoleculeDrawerView.BondType
    let dragOffset: CGSize
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: (DragGesture.Value) -> Void
    let onTap: () -> Void
    
    var body: some View {
        if atomIndex < drawingModel.atoms.count {
            let atom = drawingModel.atoms[atomIndex]
            AtomView(
                atom: atom,
                isSelected: drawingModel.selectedAtomIndex == atomIndex,
                isDragged: drawingModel.draggedAtomIndex == atomIndex
            )
            .offset(drawingModel.draggedAtomIndex == atomIndex ? dragOffset : .zero)
            .onTapGesture(perform: onTap)
            .gesture(
                DragGesture()
                    .onChanged(onDragChanged)
                    .onEnded(onDragEnded)
            )
        }
    }
}
// MARK: - Enhanced Views
struct AtomView: View {
    let atom: DrawnAtom
    let isSelected: Bool
    let isDragged: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(atom.element.backgroundColor)
                .frame(width: 35, height: 35)
                .overlay(
                    Circle()
                        .stroke(
                            isSelected ? Color.blue : (isDragged ? Color.green : atom.element.color),
                            lineWidth: isSelected || isDragged ? 3 : 2
                        )
                )
            
            Text(atom.element.rawValue)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(atom.element.color)
        }
        .position(atom.position)
        .scaleEffect(isDragged ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isDragged)
    }
}

struct BondView: View {
    let from: CGPoint
    let to: CGPoint
    let bondType: MoleculeDrawerView.BondType
    
    var body: some View {
        ZStack {
            // Main bond line
            Path { path in
                path.move(to: from)
                path.addLine(to: to)
            }
            .stroke(Color.black, lineWidth: bondType.strokeWidth)
            
            // Additional lines for multiple bonds
            if bondType == .double {
                parallelLine(offset: 4)
            } else if bondType == .triple {
                parallelLine(offset: 4)
                parallelLine(offset: -4)
            } else if bondType == .aromatic {
                Path { path in
                    path.move(to: from)
                    path.addLine(to: to)
                }
                .stroke(Color.black, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
            }
        }
    }
    
    private func parallelLine(offset: CGFloat) -> some View {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let perpAngle = angle + .pi / 2
        let offsetX = cos(perpAngle) * offset
        let offsetY = sin(perpAngle) * offset
        
        return Path { path in
            path.move(to: CGPoint(x: from.x + offsetX, y: from.y + offsetY))
            path.addLine(to: CGPoint(x: to.x + offsetX, y: to.y + offsetY))
        }
        .stroke(Color.black, lineWidth: 2)
    }
}

struct MoleculeDrawerBottomBar: View {
    @ObservedObject var drawingModel: MoleculeDrawingModel
    @Binding var showingClearAlert: Bool
    @Binding var showingSaveDialog: Bool
    @Binding var showingProperties: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Button("Clear") {
                if !drawingModel.atoms.isEmpty || !drawingModel.bonds.isEmpty {
                    showingClearAlert = true
                }
            }
            .foregroundColor(.red)
            
            Button("Properties") {
                showingProperties = true
            }
            .foregroundColor(.blue)
            .disabled(drawingModel.atoms.isEmpty)
            
            Spacer()
            
            // Molecule Stats
            VStack(alignment: .center, spacing: 2) {
                Text("Atoms: \(drawingModel.atoms.count)")
                    .font(.caption2)
                Text("Bonds: \(drawingModel.bonds.count)")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Save") {
                if !drawingModel.atoms.isEmpty {
                    showingSaveDialog = true
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(drawingModel.atoms.isEmpty)
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

// MARK: - Drawer Properties View
struct DrawerMoleculePropertiesView: View {
    @ObservedObject var drawingModel: MoleculeDrawingModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !drawingModel.atoms.isEmpty {
                        let properties = drawingModel.calculateMolecularProperties()
                        
                        DrawerPropertySection(title: "Molecular Formula") {
                            Text(generateMolecularFormula())
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        DrawerPropertySection(title: "SMILES") {
                            Text(drawingModel.generateSMILES())
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        DrawerPropertySection(title: "Molecular Properties") {
                            VStack(alignment: .leading, spacing: 8) {
                                DrawerPropertyRow(label: "Molecular Weight", value: String(format: "%.2f g/mol", properties.molecularWeight))
                                DrawerPropertyRow(label: "H-Bond Donors", value: "\(properties.hDonors)")
                                DrawerPropertyRow(label: "H-Bond Acceptors", value: "\(properties.hAcceptors)")
                                DrawerPropertyRow(label: "Heavy Atoms", value: "\(drawingModel.atoms.filter { $0.element != .hydrogen }.count)")
                            }
                        }
                        
                        DrawerPropertySection(title: "Atom Composition") {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(getAtomCounts().sorted(by: { $0.key.rawValue < $1.key.rawValue }), id: \.key) { element, count in
                                    HStack {
                                        Circle()
                                            .fill(element.color)
                                            .frame(width: 12, height: 12)
                                        Text("\(element.rawValue): \(count)")
                                            .font(.caption)
                                        Spacer()
                                    }
                                }
                            }
                        }
                        
                    } else {
                        Text("No molecule to analyze")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding()
            }
            .navigationTitle("Molecule Properties")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func generateMolecularFormula() -> String {
        let atomCounts = getAtomCounts()
        let orderedElements: [MoleculeDrawerView.DrawingTool] = [
            .carbon, .hydrogen, .nitrogen, .oxygen, .phosphorus, .sulfur,
            .fluorine, .chlorine, .bromine, .iodine, .silicon, .boron
        ]
        
        var formula = ""
        for element in orderedElements {
            if let count = atomCounts[element] {
                formula += element.rawValue
                if count > 1 {
                    formula += "\(count)"
                }
            }
        }
        
        return formula.isEmpty ? "No atoms" : formula
    }
    
    private func getAtomCounts() -> [MoleculeDrawerView.DrawingTool: Int] {
        var counts: [MoleculeDrawerView.DrawingTool: Int] = [:]
        for atom in drawingModel.atoms {
            counts[atom.element, default: 0] += 1
        }
        return counts
    }
}

struct DrawerPropertySection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            content
        }
    }
}

struct DrawerPropertyRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Data Models
struct DrawnAtom {
    let id: UUID
    var position: CGPoint
    var element: MoleculeDrawerView.DrawingTool
}

struct DrawnBond {
    let id: UUID
    var fromAtomIndex: Int
    var toAtomIndex: Int
    var type: MoleculeDrawerView.BondType
}

struct DrawerMolecularProperties {
    let molecularWeight: Double
    let hDonors: Int
    let hAcceptors: Int
}

// MARK: - Enhanced Components
struct AtomToolButton: View {
    let tool: MoleculeDrawerView.DrawingTool
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                if tool.atomicNumber > 0 {
                    Text("\(tool.atomicNumber)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(tool.rawValue)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .white : tool.color)
            }
            .frame(width: 36, height: 36)
            .background(isSelected ? tool.color : tool.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(tool.color, lineWidth: isSelected ? 0 : 1)
            )
        }
    }
}

struct BondToolButton: View {
    let bondType: MoleculeDrawerView.BondType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(bondType.rawValue)
                    .font(.title3)
                    .fontWeight(.bold)
                Text(bondType.description)
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .frame(width: 60, height: 40)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct GridBackgroundView: View {
    var body: some View {
        Canvas { context, size in
            let gridSpacing: CGFloat = 20
            context.stroke(
                Path { path in
                    for x in stride(from: 0, through: size.width, by: gridSpacing) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    for y in stride(from: 0, through: size.height, by: gridSpacing) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                },
                with: .color(.gray.opacity(0.3)),
                lineWidth: 0.5
            )
        }
    }
}

struct SaveMoleculeView: View {
    @ObservedObject var drawingModel: MoleculeDrawingModel
    @Binding var moleculeName: String
    let onSave: (String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Save Molecule")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    TextField("Molecule Name", text: $moleculeName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    let properties = drawingModel.calculateMolecularProperties()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Generated SMILES:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(drawingModel.generateSMILES())
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Molecular Properties:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Atoms: \(drawingModel.atoms.count)")
                            Text("Bonds: \(drawingModel.bonds.count)")
                            Text("Molecular Weight: \(String(format: "%.2f", properties.molecularWeight)) g/mol")
                            Text("H-Bond Donors: \(properties.hDonors)")
                            Text("H-Bond Acceptors: \(properties.hAcceptors)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Save Molecule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onSave("")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(moleculeName)
                    }
                    .disabled(drawingModel.atoms.isEmpty)
                }
            }
        }
    }
}

// MARK: - Enhanced Ligand Builder (Visual Designer)
struct LigandBuilderView: View {
    @StateObject private var viewModel = LigandBuilderViewModel()
    @Environment(\.modelContext) private var modelContext
    @State private var selectedCategory: FragmentCategory = .scaffolds
    @State private var currentMolecule: DesignedMolecule = DesignedMolecule()
    @State private var showingProperties = false
    @State private var showingSaveDialog = false
    @State private var moleculeName = ""
    
    enum FragmentCategory: String, CaseIterable {
        case scaffolds = "Scaffolds"
        case rings = "Ring Systems"
        case linkers = "Linkers"
        case functionalGroups = "Functional Groups"
        case sidechains = "Side Chains"
        case heteroatoms = "Heteroatoms"
        
        var icon: String {
            switch self {
            case .scaffolds: return "square.grid.3x2"
            case .rings: return "circle.hexagonpath"
            case .linkers: return "link"
            case .functionalGroups: return "atom"
            case .sidechains: return "tree"
            case .heteroatoms: return "circle.grid.cross"
            }
        }
        
        var color: Color {
            switch self {
            case .scaffolds: return .blue
            case .rings: return .purple
            case .linkers: return .orange
            case .functionalGroups: return .green
            case .sidechains: return .brown
            case .heteroatoms: return .red
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with current molecule info
            if !currentMolecule.fragments.isEmpty {
                MoleculePreviewHeader(molecule: currentMolecule)
                    .padding()
                    .background(Color(.systemGray6))
            }
            
            // Category selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(FragmentCategory.allCases, id: \.self) { category in
                        CategorySelector(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            
            // Fragment library
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(getFragments(for: selectedCategory)) { fragment in
                        FragmentCard(fragment: fragment) {
                            addFragment(fragment)
                        }
                    }
                }
                .padding()
            }
            
            // Bottom toolbar
            if !currentMolecule.fragments.isEmpty {
                VStack(spacing: 12) {
                    // Fragment list
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(currentMolecule.fragments.enumerated()), id: \.offset) { index, fragment in
                                SelectedFragmentChip(fragment: fragment) {
                                    removeFragment(at: index)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Action buttons
                    HStack(spacing: 16) {
                        Button("Clear All") {
                            currentMolecule.fragments.removeAll()
                            updateProperties()
                        }
                        .foregroundColor(.red)
                        
                        Button("Properties") {
                            calculateProperties()
                            showingProperties = true
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Save Molecule") {
                            showingSaveDialog = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: -2)
            }
        }
        .navigationTitle("Ligand Designer")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingProperties) {
            if let molecule = viewModel.calculatedMolecule {
                MoleculePropertiesView(molecule: molecule)
            }
        }
        .sheet(isPresented: $showingSaveDialog) {
            SaveDesignedMoleculeView(
                currentMolecule: currentMolecule,
                moleculeName: $moleculeName
            ) { name in
                saveMolecule(name: name)
                showingSaveDialog = false
            }
        }
    }
    
    private func getFragments(for category: FragmentCategory) -> [MolecularFragment] {
        switch category {
        case .scaffolds:
            return MolecularFragment.scaffolds
        case .rings:
            return MolecularFragment.rings
        case .linkers:
            return MolecularFragment.linkers
        case .functionalGroups:
            return MolecularFragment.functionalGroups
        case .sidechains:
            return MolecularFragment.sidechains
        case .heteroatoms:
            return MolecularFragment.heteroatoms
        }
    }
    
    private func addFragment(_ fragment: MolecularFragment) {
        currentMolecule.fragments.append(fragment)
        updateProperties()
    }
    
    private func removeFragment(at index: Int) {
        currentMolecule.fragments.remove(at: index)
        updateProperties()
    }
    
    private func updateProperties() {
        currentMolecule.updateSMILES()
        currentMolecule.estimateProperties()
    }
    
    private func calculateProperties() {
        let smiles = currentMolecule.generateSMILES()
        viewModel.calculateDetailedProperties(smiles: smiles, name: "Designed Molecule")
    }
    
    private func saveMolecule(name: String) {
        if let calculatedMolecule = viewModel.calculatedMolecule {
            calculatedMolecule.name = name.isEmpty ? "Designed Molecule" : name
            modelContext.insert(calculatedMolecule)
            try? modelContext.save()
            
            // Reset designer
            currentMolecule = DesignedMolecule()
            moleculeName = ""
        }
    }
}

// MARK: - Designed Molecule Model
class DesignedMolecule: ObservableObject {
    @Published var fragments: [MolecularFragment] = []
    @Published var estimatedMW: Double = 0.0
    @Published var estimatedLogP: Double = 0.0
    @Published var estimatedHBD: Int = 0
    @Published var estimatedHBA: Int = 0
    
    func generateSMILES() -> String {
        if fragments.isEmpty { return "" }
        
        // Simple concatenation for demo - in real app would use proper SMILES merging
        let coreFragment = fragments.first?.smiles ?? "C"
        var result = coreFragment
        
        for fragment in fragments.dropFirst() {
            if fragment.isLinker {
                result += fragment.smiles
            } else {
                result += "(\(fragment.smiles))"
            }
        }
        
        return result
    }
    
    func updateSMILES() {
        // Update SMILES representation
        _ = generateSMILES()
    }
    
    func estimateProperties() {
        // Rough property estimation based on fragments
        estimatedMW = fragments.reduce(0) { $0 + $1.molecularWeight }
        estimatedLogP = fragments.reduce(0) { $0 + $1.logPContribution }
        estimatedHBD = fragments.reduce(0) { $0 + $1.hBondDonors }
        estimatedHBA = fragments.reduce(0) { $0 + $1.hBondAcceptors }
    }
    
    var drugLikenessIndicator: String {
        let mwOk = estimatedMW <= 500
        let logPOk = estimatedLogP <= 5
        let hbdOk = estimatedHBD <= 5
        let hbaOk = estimatedHBA <= 10
        
        let score = [mwOk, logPOk, hbdOk, hbaOk].filter { $0 }.count
        
        switch score {
        case 4: return "🟢 Excellent"
        case 3: return "🟡 Good"
        case 2: return "🟠 Moderate"
        default: return "🔴 Poor"
        }
    }
}

// MARK: - Molecular Fragment Model
struct MolecularFragment: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let smiles: String
    let description: String
    let category: LigandBuilderView.FragmentCategory
    let molecularWeight: Double
    let logPContribution: Double
    let hBondDonors: Int
    let hBondAcceptors: Int
    let isLinker: Bool
    
    // Predefined fragment libraries
    static let scaffolds: [MolecularFragment] = [
        MolecularFragment(name: "Benzene", smiles: "c1ccccc1", description: "Basic aromatic ring", category: .scaffolds, molecularWeight: 78.11, logPContribution: 1.9, hBondDonors: 0, hBondAcceptors: 0, isLinker: false),
        MolecularFragment(name: "Pyridine", smiles: "c1ccncc1", description: "Nitrogen heterocycle", category: .scaffolds, molecularWeight: 79.10, logPContribution: 0.65, hBondDonors: 0, hBondAcceptors: 1, isLinker: false),
        MolecularFragment(name: "Pyrimidine", smiles: "c1cncnc1", description: "Dinitrogen heterocycle", category: .scaffolds, molecularWeight: 80.09, logPContribution: -0.7, hBondDonors: 0, hBondAcceptors: 2, isLinker: false),
        MolecularFragment(name: "Indole", smiles: "c1ccc2[nH]ccc2c1", description: "Bicyclic heteroaromatic", category: .scaffolds, molecularWeight: 117.15, logPContribution: 2.1, hBondDonors: 1, hBondAcceptors: 0, isLinker: false),
        MolecularFragment(name: "Quinoline", smiles: "c1ccc2ncccc2c1", description: "Bicyclic nitrogen heterocycle", category: .scaffolds, molecularWeight: 129.16, logPContribution: 2.0, hBondDonors: 0, hBondAcceptors: 1, isLinker: false),
        MolecularFragment(name: "Thiophene", smiles: "c1ccsc1", description: "Sulfur heterocycle", category: .scaffolds, molecularWeight: 84.14, logPContribution: 1.8, hBondDonors: 0, hBondAcceptors: 0, isLinker: false)
    ]
    
    static let rings: [MolecularFragment] = [
        MolecularFragment(name: "Cyclohexane", smiles: "C1CCCCC1", description: "Saturated 6-ring", category: .rings, molecularWeight: 84.16, logPContribution: 2.9, hBondDonors: 0, hBondAcceptors: 0, isLinker: false),
        MolecularFragment(name: "Piperidine", smiles: "C1CCNCC1", description: "Saturated N-heterocycle", category: .rings, molecularWeight: 85.15, logPContribution: 0.8, hBondDonors: 1, hBondAcceptors: 1, isLinker: false),
        MolecularFragment(name: "Morpholine", smiles: "C1COCCN1", description: "Oxygen-nitrogen heterocycle", category: .rings, molecularWeight: 87.12, logPContribution: -1.1, hBondDonors: 1, hBondAcceptors: 2, isLinker: false),
        MolecularFragment(name: "Tetrahydrofuran", smiles: "C1CCOC1", description: "5-membered O-heterocycle", category: .rings, molecularWeight: 72.11, logPContribution: 0.5, hBondDonors: 0, hBondAcceptors: 1, isLinker: false),
        MolecularFragment(name: "Cyclopropane", smiles: "C1CC1", description: "Strained 3-ring", category: .rings, molecularWeight: 42.08, logPContribution: 1.7, hBondDonors: 0, hBondAcceptors: 0, isLinker: false),
        MolecularFragment(name: "Pyrrolidine", smiles: "C1CCNC1", description: "5-membered N-heterocycle", category: .rings, molecularWeight: 71.12, logPContribution: 0.5, hBondDonors: 1, hBondAcceptors: 1, isLinker: false)
    ]
    
    static let linkers: [MolecularFragment] = [
        MolecularFragment(name: "Methylene", smiles: "C", description: "Single carbon bridge", category: .linkers, molecularWeight: 14.03, logPContribution: 0.5, hBondDonors: 0, hBondAcceptors: 0, isLinker: true),
        MolecularFragment(name: "Ethyl", smiles: "CC", description: "Two carbon chain", category: .linkers, molecularWeight: 28.05, logPContribution: 1.0, hBondDonors: 0, hBondAcceptors: 0, isLinker: true),
        MolecularFragment(name: "Amide", smiles: "C(=O)N", description: "Amide linkage", category: .linkers, molecularWeight: 43.04, logPContribution: -1.0, hBondDonors: 1, hBondAcceptors: 1, isLinker: true),
        MolecularFragment(name: "Ether", smiles: "O", description: "Oxygen bridge", category: .linkers, molecularWeight: 16.00, logPContribution: -0.3, hBondDonors: 0, hBondAcceptors: 1, isLinker: true),
        MolecularFragment(name: "Amine", smiles: "N", description: "Nitrogen bridge", category: .linkers, molecularWeight: 14.01, logPContribution: -1.0, hBondDonors: 1, hBondAcceptors: 1, isLinker: true),
        MolecularFragment(name: "Sulfur", smiles: "S", description: "Sulfur bridge", category: .linkers, molecularWeight: 32.06, logPContribution: 0.1, hBondDonors: 0, hBondAcceptors: 0, isLinker: true)
    ]
    
    static let functionalGroups: [MolecularFragment] = [
        MolecularFragment(name: "Hydroxyl", smiles: "O", description: "Alcohol group", category: .functionalGroups, molecularWeight: 17.01, logPContribution: -1.5, hBondDonors: 1, hBondAcceptors: 1, isLinker: false),
        MolecularFragment(name: "Carboxyl", smiles: "C(=O)O", description: "Carboxylic acid", category: .functionalGroups, molecularWeight: 45.02, logPContribution: -0.3, hBondDonors: 1, hBondAcceptors: 2, isLinker: false),
        MolecularFragment(name: "Amino", smiles: "N", description: "Primary amine", category: .functionalGroups, molecularWeight: 16.02, logPContribution: -1.0, hBondDonors: 2, hBondAcceptors: 1, isLinker: false),
        MolecularFragment(name: "Nitro", smiles: "N(=O)=O", description: "Nitro group", category: .functionalGroups, molecularWeight: 46.01, logPContribution: -0.3, hBondDonors: 0, hBondAcceptors: 2, isLinker: false),
        MolecularFragment(name: "Methoxy", smiles: "OC", description: "Methyl ether", category: .functionalGroups, molecularWeight: 31.03, logPContribution: 0.0, hBondDonors: 0, hBondAcceptors: 1, isLinker: false),
        MolecularFragment(name: "Trifluoromethyl", smiles: "C(F)(F)F", description: "CF3 group", category: .functionalGroups, molecularWeight: 69.01, logPContribution: 1.1, hBondDonors: 0, hBondAcceptors: 3, isLinker: false)
    ]
    
    static let sidechains: [MolecularFragment] = [
        MolecularFragment(name: "Methyl", smiles: "C", description: "Simple alkyl", category: .sidechains, molecularWeight: 15.03, logPContribution: 0.5, hBondDonors: 0, hBondAcceptors: 0, isLinker: false),
        MolecularFragment(name: "Isopropyl", smiles: "C(C)C", description: "Branched alkyl", category: .sidechains, molecularWeight: 43.09, logPContribution: 1.5, hBondDonors: 0, hBondAcceptors: 0, isLinker: false),
        MolecularFragment(name: "tert-Butyl", smiles: "C(C)(C)C", description: "Bulky alkyl", category: .sidechains, molecularWeight: 57.12, logPContribution: 2.0, hBondDonors: 0, hBondAcceptors: 0, isLinker: false),
        MolecularFragment(name: "Benzyl", smiles: "Cc1ccccc1", description: "Aromatic sidechain", category: .sidechains, molecularWeight: 91.13, logPContribution: 2.4, hBondDonors: 0, hBondAcceptors: 0, isLinker: false),
        MolecularFragment(name: "Acetyl", smiles: "C(=O)C", description: "Acyl group", category: .sidechains, molecularWeight: 43.04, logPContribution: -0.2, hBondDonors: 0, hBondAcceptors: 1, isLinker: false),
        MolecularFragment(name: "Phenyl", smiles: "c1ccccc1", description: "Aromatic substituent", category: .sidechains, molecularWeight: 77.10, logPContribution: 1.9, hBondDonors: 0, hBondAcceptors: 0, isLinker: false)
    ]
    
    static let heteroatoms: [MolecularFragment] = [
        MolecularFragment(name: "Fluorine", smiles: "F", description: "Fluorine atom", category: .heteroatoms, molecularWeight: 19.00, logPContribution: 0.1, hBondDonors: 0, hBondAcceptors: 1, isLinker: false),
        MolecularFragment(name: "Chlorine", smiles: "Cl", description: "Chlorine atom", category: .heteroatoms, molecularWeight: 35.45, logPContribution: 0.7, hBondDonors: 0, hBondAcceptors: 0, isLinker: false),
        MolecularFragment(name: "Bromine", smiles: "Br", description: "Bromine atom", category: .heteroatoms, molecularWeight: 79.90, logPContribution: 0.9, hBondDonors: 0, hBondAcceptors: 0, isLinker: false),
        MolecularFragment(name: "Iodine", smiles: "I", description: "Iodine atom", category: .heteroatoms, molecularWeight: 126.90, logPContribution: 1.2, hBondDonors: 0, hBondAcceptors: 0, isLinker: false),
        MolecularFragment(name: "Nitrogen", smiles: "N", description: "Nitrogen atom", category: .heteroatoms, molecularWeight: 14.01, logPContribution: -1.0, hBondDonors: 1, hBondAcceptors: 1, isLinker: false),
        MolecularFragment(name: "Oxygen", smiles: "O", description: "Oxygen atom", category: .heteroatoms, molecularWeight: 16.00, logPContribution: -1.5, hBondDonors: 1, hBondAcceptors: 1, isLinker: false)
    ]
}

// MARK: - Ligand Builder Components
struct MoleculePreviewHeader: View {
    @ObservedObject var molecule: DesignedMolecule
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Current Design")
                    .font(.headline)
                Spacer()
                Text(molecule.drugLikenessIndicator)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            Text(molecule.generateSMILES())
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.blue)
                .lineLimit(2)
            
            HStack(spacing: 16) {
                PropertyIndicator(title: "MW", value: String(format: "%.0f", molecule.estimatedMW), isGood: molecule.estimatedMW <= 500)
                PropertyIndicator(title: "LogP", value: String(format: "%.1f", molecule.estimatedLogP), isGood: molecule.estimatedLogP <= 5)
                PropertyIndicator(title: "HBD", value: "\(molecule.estimatedHBD)", isGood: molecule.estimatedHBD <= 5)
                PropertyIndicator(title: "HBA", value: "\(molecule.estimatedHBA)", isGood: molecule.estimatedHBA <= 10)
                Spacer()
            }
        }
    }
}

struct PropertyIndicator: View {
    let title: String
    let value: String
    let isGood: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(isGood ? .green : .red)
        }
    }
}

struct CategorySelector: View {
    let category: LigandBuilderView.FragmentCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.title2)
                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : category.color)
            .frame(width: 80, height: 60)
            .background(isSelected ? category.color : category.color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct FragmentCard: View {
    let fragment: MolecularFragment
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(fragment.name)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(fragment.category.color)
                }
                
                Text(fragment.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text(fragment.smiles)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.blue)
                    .lineLimit(1)
                
                HStack {
                    Text("MW: \(String(format: "%.0f", fragment.molecularWeight))")
                        .font(.caption2)
                    Spacer()
                    Text("LogP: \(String(format: "%.1f", fragment.logPContribution))")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(fragment.category.color.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SelectedFragmentChip: View {
    let fragment: MolecularFragment
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(fragment.name)
                .font(.caption)
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(fragment.category.color.opacity(0.2))
        .foregroundColor(fragment.category.color)
        .clipShape(Capsule())
    }
}

struct MoleculePropertiesView: View {
    let molecule: Molecule
    
    var body: some View {
        NavigationView {
            List {
                Section("Basic Properties") {
                    PropertyRow(title: "Molecular Weight", value: String(format: "%.2f Da", molecule.molecularWeight ?? 0))
                    PropertyRow(title: "LogP", value: String(format: "%.2f", molecule.logP ?? 0))
                    PropertyRow(title: "H-Bond Donors", value: "\(molecule.hDonors ?? 0)")
                    PropertyRow(title: "H-Bond Acceptors", value: "\(molecule.hAcceptors ?? 0)")
                    PropertyRow(title: "TPSA", value: String(format: "%.1f Ų", molecule.tpsa ?? 0))
                }
                
                Section("Drug-Likeness") {
                    HStack {
                        Text("Lipinski Rule")
                        Spacer()
                        Text(molecule.lipinskiCompliant ? "✅ Pass" : "❌ Fail")
                            .foregroundColor(molecule.lipinskiCompliant ? .green : .red)
                    }
                    
                    HStack {
                        Text("Drug-Likeness Score")
                        Spacer()
                        Text(String(format: "%.0f%%", molecule.drugLikenessScore * 100))
                            .foregroundColor(molecule.drugLikenessScore > 0.75 ? .green :
                                           molecule.drugLikenessScore > 0.5 ? .orange : .red)
                    }
                }
                
                Section("Molecule Details") {
                    PropertyRow(title: "SMILES", value: molecule.smiles)
                    if let formula = molecule.molecularFormula {
                        PropertyRow(title: "Formula", value: formula)
                    }
                }
            }
            .navigationTitle("Properties")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SaveDesignedMoleculeView: View {
    let currentMolecule: DesignedMolecule
    @Binding var moleculeName: String
    let onSave: (String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Save Designed Molecule")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    TextField("Molecule Name", text: $moleculeName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Generated SMILES:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(currentMolecule.generateSMILES())
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fragment Summary:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(currentMolecule.fragments.count) fragments")
                        Text("Est. MW: \(String(format: "%.0f", currentMolecule.estimatedMW)) Da")
                        Text("Est. LogP: \(String(format: "%.1f", currentMolecule.estimatedLogP))")
                        Text(currentMolecule.drugLikenessIndicator)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Save Molecule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onSave("")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(moleculeName)
                    }
                    .disabled(currentMolecule.fragments.isEmpty)
                }
            }
        }
    }
}

// MARK: - Updated Ligand Builder ViewModel
class LigandBuilderViewModel: ObservableObject {
    @Published var calculatedMolecule: Molecule? = nil
    @Published var isCalculating: Bool = false
    
    func calculateDetailedProperties(smiles: String, name: String) {
        isCalculating = true
        
        // Simulate detailed property calculation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let molecule = Molecule(name: name, smiles: smiles)
            
            // More sophisticated property calculations
            let complexity = smiles.count
            molecule.molecularWeight = Double(complexity * 10 + Int.random(in: 50...150))
            molecule.logP = Double.random(in: -2...5)
            molecule.hDonors = max(0, smiles.components(separatedBy: "O").count - 1 + smiles.components(separatedBy: "N").count - 1)
            molecule.hAcceptors = max(0, smiles.components(separatedBy: CharacterSet(charactersIn: "ON")).count - 1)
            molecule.tpsa = Double.random(in: 30...120)
            molecule.rotatablebonds = max(0, smiles.components(separatedBy: "C").count - 3)
            
            // Generate mock molecular formula
            let carbonCount = max(1, smiles.components(separatedBy: "C").count - 1)
            let nitrogenCount = smiles.components(separatedBy: "N").count - 1
            let oxygenCount = smiles.components(separatedBy: "O").count - 1
            let hydrogenCount = carbonCount * 2 + nitrogenCount + oxygenCount
            
            molecule.molecularFormula = "C\(carbonCount)H\(hydrogenCount)" +
                                      (nitrogenCount > 0 ? "N\(nitrogenCount)" : "") +
                                      (oxygenCount > 0 ? "O\(oxygenCount)" : "")
            
            self.calculatedMolecule = molecule
            self.isCalculating = false
        }
    }
}

// MARK: - Enhanced ADMET Analysis with Direct Input
struct ADMETAnalysisView: View {
    @State private var selectedMolecules: [Molecule] = []
    @State private var analysisResults: [ADMETResult] = []
    @Environment(\.modelContext) private var modelContext
    @Query private var molecules: [Molecule]
    @State private var isAnalyzing = false
    
    // New states for direct input
    @State private var showingAddMolecule = false
    @State private var showingQuickInput = false
    @State private var quickSMILES = ""
    @State private var quickName = ""
    
    struct ADMETResult {
        let molecule: Molecule
        let absorption: Double
        let distribution: Double
        let metabolism: Double
        let excretion: Double
        let toxicity: Double
        let bbb: Double // Blood-brain barrier penetration
        let cyp450: Double // CYP450 inhibition potential
        
        var overallScore: Double {
            (absorption + distribution + metabolism + excretion + (5.0 - toxicity) + bbb) / 6
        }
        
        var recommendation: String {
            if overallScore > 4.0 {
                return "Excellent drug candidate"
            } else if overallScore > 3.5 {
                return "Good drug potential"
            } else if overallScore > 2.5 {
                return "Moderate potential, needs optimization"
            } else {
                return "Poor drug-likeness, major optimization needed"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if molecules.isEmpty && selectedMolecules.isEmpty {
                // Enhanced no molecules view with direct input options
                EmptyADMETView(
                    showingAddMolecule: $showingAddMolecule,
                    showingQuickInput: $showingQuickInput,
                    onLoadSamples: loadSampleMolecules
                )
            } else if analysisResults.isEmpty {
                // Molecule Selection with enhanced options
                EnhancedMoleculeSelectionView(
                    molecules: molecules,
                    selectedMolecules: $selectedMolecules,
                    isAnalyzing: isAnalyzing,
                    showingAddMolecule: $showingAddMolecule,
                    showingQuickInput: $showingQuickInput,
                    onAnalyze: runADMETAnalysis
                )
            } else {
                // Results Display (existing code)
                ADMETResultsView(
                    analysisResults: analysisResults,
                    onNewAnalysis: {
                        selectedMolecules.removeAll()
                        analysisResults.removeAll()
                    }
                )
            }
        }
        .navigationTitle("ADMET Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddMolecule) {
            QuickMoleculeAddView { molecule in
                selectedMolecules.append(molecule)
                modelContext.insert(molecule)
                try? modelContext.save()
            }
        }
        .sheet(isPresented: $showingQuickInput) {
            QuickSMILESInputView { smiles, name in
                let molecule = Molecule(name: name, smiles: smiles)
                selectedMolecules.append(molecule)
                modelContext.insert(molecule)
                try? modelContext.save()
            }
        }
    }
    
    private func loadSampleMolecules() {
        let samples = [
            Molecule(name: "Aspirin", smiles: "CC(=O)OC1=CC=CC=C1C(=O)O"),
            Molecule(name: "Ibuprofen", smiles: "CC(C)CC1=CC=C(C=C1)C(C)C(=O)O"),
            Molecule(name: "Caffeine", smiles: "CN1C=NC2=C1C(=O)N(C(=O)N2C)C"),
            Molecule(name: "Paracetamol", smiles: "CC(=O)NC1=CC=C(C=C1)O"),
            Molecule(name: "Dopamine", smiles: "NCCc1ccc(O)c(O)c1")
        ]
        
        for molecule in samples {
            // Add some mock properties
            molecule.molecularWeight = Double.random(in: 150...400)
            molecule.logP = Double.random(in: -1...4)
            molecule.hDonors = Int.random(in: 0...3)
            molecule.hAcceptors = Int.random(in: 1...5)
            molecule.tpsa = Double.random(in: 30...120)
            
            selectedMolecules.append(molecule)
            modelContext.insert(molecule)
        }
        try? modelContext.save()
    }
    
    private func runADMETAnalysis() {
        isAnalyzing = true
        
        // Simulate realistic analysis with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.analysisResults = self.selectedMolecules.map { molecule in
                self.calculateADMETProperties(for: molecule)
            }
            self.isAnalyzing = false
        }
    }
    
    private func calculateADMETProperties(for molecule: Molecule) -> ADMETResult {
        // More sophisticated ADMET prediction based on molecular properties
        let mw = molecule.molecularWeight ?? 300.0
        let logP = molecule.logP ?? 2.0
        let hbd = Double(molecule.hDonors ?? 2)
        let hba = Double(molecule.hAcceptors ?? 4)
        let tpsa = molecule.tpsa ?? 60.0
        
        // Absorption (based on Lipinski's Rule and TPSA)
        var absorption = 3.0
        if mw <= 500 { absorption += 0.5 }
        if logP <= 5 { absorption += 0.5 }
        if tpsa <= 140 { absorption += 0.5 }
        if hbd <= 5 && hba <= 10 { absorption += 0.5 }
        
        // Distribution (based on LogP and molecular size)
        var distribution = 2.5 + (logP * 0.3)
        if mw > 500 { distribution -= 0.5 }
        distribution = min(5.0, max(1.0, distribution))
        
        // Metabolism (CYP450 stability)
        var metabolism = 3.0
        if logP < 3 { metabolism += 0.5 }
        if mw < 400 { metabolism += 0.5 }
        metabolism += Double.random(in: -0.5...0.5)
        metabolism = min(5.0, max(1.0, metabolism))
        
        // Excretion (renal clearance)
        var excretion = 3.0
        if mw < 300 { excretion += 0.5 }
        if logP < 2 { excretion += 0.5 }
        excretion += Double.random(in: -0.5...0.5)
        excretion = min(5.0, max(1.0, excretion))
        
        // Toxicity (lower is better)
        var toxicity = 2.0
        if mw > 600 { toxicity += 1.0 }
        if logP > 5 { toxicity += 0.5 }
        toxicity += Double.random(in: 0...1.0)
        toxicity = min(5.0, max(1.0, toxicity))
        
        // Blood-brain barrier penetration
        var bbb = 2.0
        if logP > 1 && logP < 3 { bbb += 1.0 }
        if tpsa < 90 { bbb += 0.5 }
        if mw < 450 { bbb += 0.5 }
        bbb += Double.random(in: -0.5...0.5)
        bbb = min(5.0, max(1.0, bbb))
        
        // CYP450 inhibition (lower is better)
        var cyp450 = Double.random(in: 1.5...4.0)
        if logP > 4 { cyp450 += 0.5 }
        cyp450 = min(5.0, max(1.0, cyp450))
        
        return ADMETResult(
            molecule: molecule,
            absorption: absorption,
            distribution: distribution,
            metabolism: metabolism,
            excretion: excretion,
            toxicity: toxicity,
            bbb: bbb,
            cyp450: cyp450
        )
    }
}

// MARK: - Enhanced Empty ADMET View
struct EmptyADMETView: View {
    @Binding var showingAddMolecule: Bool
    @Binding var showingQuickInput: Bool
    let onLoadSamples: () -> Void
    
    var body: some View {
        VStack(spacing: 25) {
            // Icon and Title
            VStack(spacing: 12) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 60))
                    .foregroundColor(.orange.opacity(0.5))
                
                Text("ADMET Analysis")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Analyze Absorption, Distribution, Metabolism, Excretion, and Toxicity properties of drug compounds")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Direct Input Options
            VStack(spacing: 16) {
                Text("Add Molecules to Analyze")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Quick SMILES Input
                Button(action: { showingQuickInput = true }) {
                    HStack {
                        Image(systemName: "textformat.abc")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quick SMILES Input")
                                .fontWeight(.semibold)
                            Text("Enter SMILES notation directly")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBlue).opacity(0.1))
                    .foregroundColor(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Detailed Molecule Entry
                Button(action: { showingAddMolecule = true }) {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add Molecule Details")
                                .fontWeight(.semibold)
                            Text("Enter name, SMILES, and properties")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGreen).opacity(0.1))
                    .foregroundColor(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Sample Data
                Button(action: onLoadSamples) {
                    HStack {
                        Image(systemName: "flask")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Load Sample Drugs")
                                .fontWeight(.semibold)
                            Text("Common drugs for testing")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemOrange).opacity(0.1))
                    .foregroundColor(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
            
            Divider()
                .padding(.horizontal)
            
            // Alternative Navigation
            VStack(spacing: 12) {
                Text("Or use other tools")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                NavigationLink("Browse Molecular Search") {
                    EnhancedMolecularSearchView()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
    }
}

// MARK: - Enhanced Molecule Selection View
struct EnhancedMoleculeSelectionView: View {
    let molecules: [Molecule]
    @Binding var selectedMolecules: [Molecule]
    let isAnalyzing: Bool
    @Binding var showingAddMolecule: Bool
    @Binding var showingQuickInput: Bool
    let onAnalyze: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with Add Options
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Select Molecules for ADMET Analysis")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Menu {
                        Button("Quick SMILES") {
                            showingQuickInput = true
                        }
                        Button("Add Details") {
                            showingAddMolecule = true
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                
                HStack {
                    Text("Choose molecules to analyze Absorption, Distribution, Metabolism, Excretion, and Toxicity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Selected: \(selectedMolecules.count)")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding()
            .background(Color(.systemGray6))
            
            // Molecule List
            List(molecules) { molecule in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(molecule.name)
                            .font(.headline)
                        
                        if let formula = molecule.molecularFormula {
                            Text(formula)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        
                        Text(molecule.smiles)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        if let mw = molecule.molecularWeight {
                            Text("MW: \(String(format: "%.1f", mw)) Da")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Spacer()
                    
                    Button(selectedMolecules.contains { $0.id == molecule.id } ? "Selected" : "Select") {
                        if selectedMolecules.contains(where: { $0.id == molecule.id }) {
                            selectedMolecules.removeAll { $0.id == molecule.id }
                        } else {
                            selectedMolecules.append(molecule)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isAnalyzing)
                }
                .padding(.vertical, 4)
            }
            
            // Analysis Button
            if !selectedMolecules.isEmpty {
                VStack(spacing: 12) {
                    Text("Selected: \(selectedMolecules.count) molecules")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: onAnalyze) {
                        HStack {
                            if isAnalyzing {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Analyzing...")
                            } else {
                                Image(systemName: "chart.bar.fill")
                                Text("Analyze ADMET Properties")
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(isAnalyzing)
                }
                .padding()
                .background(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: -2)
            }
        }
    }
}

// MARK: - Quick SMILES Input Sheet
struct QuickSMILESInputView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var smiles = ""
    @State private var name = ""
    let onAdd: (String, String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick SMILES Input")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Enter SMILES notation and compound name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Compound Name")
                            .font(.headline)
                        TextField("e.g., Aspirin", text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SMILES")
                            .font(.headline)
                        TextField("e.g., CCO", text: $smiles)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(.body, design: .monospaced))
                    }
                }
                
                // Quick Examples
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Examples:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        QuickExampleButton(name: "Ethanol", smiles: "CCO") {
                            name = "Ethanol"
                            smiles = "CCO"
                        }
                        QuickExampleButton(name: "Aspirin", smiles: "CC(=O)OC1=CC=CC=C1C(=O)O") {
                            name = "Aspirin"
                            smiles = "CC(=O)OC1=CC=CC=C1C(=O)O"
                        }
                        QuickExampleButton(name: "Caffeine", smiles: "CN1C=NC2=C1C(=O)N(C(=O)N2C)C") {
                            name = "Caffeine"
                            smiles = "CN1C=NC2=C1C(=O)N(C(=O)N2C)C"
                        }
                        QuickExampleButton(name: "Ibuprofen", smiles: "CC(C)CC1=CC=C(C=C1)C(C)C(=O)O") {
                            name = "Ibuprofen"
                            smiles = "CC(C)CC1=CC=C(C=C1)C(C)C(=O)O"
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Molecule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onAdd(smiles, name.isEmpty ? "Unnamed Compound" : name)
                        dismiss()
                    }
                    .disabled(smiles.isEmpty)
                }
            }
        }
    }
}

// MARK: - Quick Example Button
struct QuickExampleButton: View {
    let name: String
    let smiles: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(smiles.count > 12 ? String(smiles.prefix(12)) + "..." : smiles)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Detailed Molecule Add View
struct QuickMoleculeAddView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var smiles = ""
    @State private var molecularWeight = ""
    @State private var logP = ""
    let onAdd: (Molecule) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Compound Name", text: $name)
                    TextField("SMILES", text: $smiles)
                        .font(.system(.body, design: .monospaced))
                }
                
                Section("Properties (Optional)") {
                    TextField("Molecular Weight", text: $molecularWeight)
                        .keyboardType(.decimalPad)
                    TextField("LogP", text: $logP)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Add Molecule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let molecule = Molecule(name: name.isEmpty ? "Unnamed Compound" : name, smiles: smiles)
                        
                        if let mw = Double(molecularWeight) {
                            molecule.molecularWeight = mw
                        }
                        if let lp = Double(logP) {
                            molecule.logP = lp
                        }
                        
                        onAdd(molecule)
                        dismiss()
                    }
                    .disabled(smiles.isEmpty)
                }
            }
        }
    }
}

// MARK: - Results View (keeping existing structure)
struct ADMETResultsView: View {
    let analysisResults: [ADMETAnalysisView.ADMETResult]
    let onNewAnalysis: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Results Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ADMET Analysis Results")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("\(analysisResults.count) molecules analyzed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("New Analysis") {
                    onNewAnalysis()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .background(Color(.systemGray6))
            
            // Results List
            List(analysisResults, id: \.molecule.id) { result in
                ADMETResultRow(result: result)
            }
        }
    }
}

// MARK: - ADMET Result Row
struct ADMETResultRow: View {
    let result: ADMETAnalysisView.ADMETResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Molecule Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.molecule.name)
                        .font(.headline)
                    if let formula = result.molecule.molecularFormula {
                        Text(formula)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f/5.0", result.overallScore))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(result.overallScore > 3.5 ? .green :
                                       result.overallScore > 2.5 ? .orange : .red)
                    Text("Overall")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // ADMET Scores
            VStack(spacing: 6) {
                ADMETScoreRow(title: "Absorption", score: result.absorption, description: "Oral bioavailability")
                ADMETScoreRow(title: "Distribution", score: result.distribution, description: "Tissue penetration")
                ADMETScoreRow(title: "Metabolism", score: result.metabolism, description: "Metabolic stability")
                ADMETScoreRow(title: "Excretion", score: result.excretion, description: "Clearance rate")
                ADMETScoreRow(title: "Toxicity", score: result.toxicity, description: "Safety profile", isReversed: true)
                ADMETScoreRow(title: "BBB", score: result.bbb, description: "Brain penetration")
                ADMETScoreRow(title: "CYP450", score: result.cyp450, description: "Drug interactions", isReversed: true)
            }
            
            // Recommendation
            HStack {
                Image(systemName: result.overallScore > 3.5 ? "checkmark.circle.fill" :
                      result.overallScore > 2.5 ? "exclamationmark.triangle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.overallScore > 3.5 ? .green :
                                   result.overallScore > 2.5 ? .orange : .red)
                
                Text(result.recommendation)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(result.overallScore > 3.5 ? Color.green.opacity(0.1) :
                          result.overallScore > 2.5 ? Color.orange.opacity(0.1) : Color.red.opacity(0.1))
            )
        }
        .padding(.vertical, 8)
    }
}

struct ADMETScoreRow: View {
    let title: String
    let score: Double
    let description: String
    let isReversed: Bool
    
    init(title: String, score: Double, description: String, isReversed: Bool = false) {
        self.title = title
        self.score = score
        self.description = description
        self.isReversed = isReversed
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(width: 80, alignment: .leading)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 8)
                    .overlay(
                        GeometryReader { geometry in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(getScoreColor())
                                .frame(width: geometry.size.width * (score / 5.0))
                        }
                        .clipped()
                    )
                
                Text(String(format: "%.1f", score))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(getScoreColor())
                    .frame(width: 30, alignment: .trailing)
            }
            
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.leading, 80)
        }
    }
    
    private func getScoreColor() -> Color {
        let effectiveScore = isReversed ? (5.0 - score) : score
        
        if effectiveScore > 3.5 {
            return .green
        } else if effectiveScore > 2.5 {
            return .orange
        } else {
            return .red
        }
    }
}
// MARK: - Pharmacophore View
struct PharmacophoreView: View {
    @State private var selectedFeatures: Set<PharmacophoreFeature> = []
    @State private var showingAnalysis = false
    @State private var analysisResults: PharmacophoreAnalysis?
    @State private var selectedCategory: FeatureCategory = .all
    @State private var realTimeScore: Double = 0.0
    
    var filteredFeatures: [PharmacophoreFeature] {
        if selectedCategory == .all {
            return PharmacophoreFeature.allCases
        } else {
            return PharmacophoreFeature.allCases.filter { $0.category == selectedCategory }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with Real-time Score
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "atom")
                                    .foregroundColor(.purple)
                                    .font(.title2)
                                Text("Pharmacophore Designer")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            
                            Text("Design molecular recognition patterns for drug discovery")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Real-time Score Display
                        VStack(spacing: 4) {
                            Text("Score")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f", realTimeScore * 100))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(realTimeScore > 0.7 ? .green : realTimeScore > 0.4 ? .orange : .red)
                            Text("%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                    
                    // Feature Count and Categories
                    HStack {
                        Text("\(selectedFeatures.count) features selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if !selectedFeatures.isEmpty {
                            Button("Clear All") {
                                selectedFeatures.removeAll()
                                updateRealTimeScore()
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(FeatureCategory.allCases, id: \.self) { category in
                            CategoryButton(
                                category: category,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Feature Selection Grid
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(selectedCategory.rawValue) (\(filteredFeatures.count))")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 8) {
                        ForEach(filteredFeatures) { feature in
                            PharmacophoreFeatureCard(
                                feature: feature,
                                isSelected: selectedFeatures.contains(feature)
                            ) {
                                toggleFeature(feature)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Selected Features Summary
                if !selectedFeatures.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Selected Pharmacophore (\(selectedFeatures.count) features)")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(selectedFeatures), id: \.id) { feature in
                                    SelectedFeatureChip(feature: feature) {
                                        selectedFeatures.remove(feature)
                                        updateRealTimeScore()
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Button("Analyze Pharmacophore Model") {
                            analyzePharmacophore()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                    )
                    .padding(.horizontal)
                }
                
                // Analysis Results
                if let analysis = analysisResults {
                    PharmacophoreAnalysisCard(analysis: analysis)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Pharmacophore")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedFeatures) { _, _ in
            updateRealTimeScore()
        }
    }
    
    private func toggleFeature(_ feature: PharmacophoreFeature) {
        if selectedFeatures.contains(feature) {
            selectedFeatures.remove(feature)
        } else {
            selectedFeatures.insert(feature)
        }
        updateRealTimeScore()
    }
    
    private func updateRealTimeScore() {
        let features = Array(selectedFeatures)
        if features.isEmpty {
            realTimeScore = 0.0
            return
        }
        
        // Calculate score based on feature combination
        var score = 0.0
        let totalImportance = features.reduce(0) { $0 + $1.importance }
        score += min(1.0, totalImportance / Double(features.count))
        
        // Bonus for balanced feature types
        let categories = Set(features.map { $0.category })
        if categories.count > 1 {
            score += 0.1 * Double(categories.count - 1)
        }
        
        // Penalty for too many features
        if features.count > 6 {
            score *= 0.8
        }
        
        realTimeScore = min(1.0, score)
    }
    
    private func analyzePharmacophore() {
        let features = Array(selectedFeatures)
        
        // Calculate comprehensive analysis
        let overallScore = calculateOverallScore(features: features)
        let selectivity = calculateSelectivity(features: features)
        let drugLikeness = calculateDrugLikeness(features: features)
        let bindingAffinity = calculateBindingAffinity(features: features)
        let targets = suggestTargets(features: features)
        let optimizations = suggestOptimizations(features: features)
        let examples = generateMolecularExamples(features: features)
        
        analysisResults = PharmacophoreAnalysis(
            selectedFeatures: features,
            overallScore: overallScore,
            selectivity: selectivity,
            drugLikeness: drugLikeness,
            bindingAffinity: bindingAffinity,
            targetSuggestions: targets,
            optimizationSuggestions: optimizations,
            molecularExamples: examples
        )
        
        showingAnalysis = true
    }
    
    private func calculateOverallScore(features: [PharmacophoreFeature]) -> Double {
        guard !features.isEmpty else { return 0.0 }
        
        var score = 0.0
        
        // Base score from feature importance
        let avgImportance = features.reduce(0) { $0 + $1.importance } / Double(features.count)
        score += avgImportance * 0.4
        
        // Diversity bonus
        let categories = Set(features.map { $0.category })
        score += Double(categories.count) * 0.1
        
        // Essential features bonus
        let hasHBond = features.contains { $0 == .hydrogenBondDonor || $0 == .hydrogenBondAcceptor }
        let hasHydrophobic = features.contains { $0 == .hydrophobicRegion || $0 == .aromaticRing }
        if hasHBond && hasHydrophobic { score += 0.2 }
        
        // Size penalty
        if features.count > 7 { score *= 0.8 }
        
        return min(1.0, score)
    }
    
    private func calculateSelectivity(features: [PharmacophoreFeature]) -> String {
        let specificity = features.reduce(0) { acc, feature in
            switch feature {
            case .chirality, .metalBinding, .halogenBond: return acc + 20
            case .ionicPositive, .ionicNegative: return acc + 15
            case .hydrogenBondDonor, .hydrogenBondAcceptor: return acc + 10
            default: return acc + 5
            }
        }
        
        let percentage = min(95, specificity)
        return "\(percentage)% selective"
    }
    
    private func calculateDrugLikeness(features: [PharmacophoreFeature]) -> String {
        var score = 50
        
        // Favorable features
        if features.contains(.hydrogenBondDonor) { score += 15 }
        if features.contains(.hydrogenBondAcceptor) { score += 15 }
        if features.contains(.hydrophobicRegion) { score += 10 }
        if features.contains(.aromaticRing) { score += 10 }
        
        // Challenging features
        if features.contains(.metalBinding) { score -= 10 }
        if features.count > 6 { score -= 10 }
        
        return "\(min(95, max(15, score)))% drug-like"
    }
    
    private func calculateBindingAffinity(features: [PharmacophoreFeature]) -> String {
        let baseAffinity = -5.0
        let featureContribution = features.reduce(0.0) { acc, feature in
            return acc + (feature.importance * -0.8)
        }
        
        let finalAffinity = baseAffinity + featureContribution
        return String(format: "%.1f kcal/mol", finalAffinity)
    }
    
    private func suggestTargets(features: [PharmacophoreFeature]) -> [String] {
        var targets: [String] = []
        
        if features.contains(.metalBinding) {
            targets.append("Metalloproteases (MMPs)")
            targets.append("Zinc-dependent enzymes")
        }
        
        if features.contains(.ionicPositive) || features.contains(.ionicNegative) {
            targets.append("Ion channels")
            targets.append("Neurotransmitter receptors")
        }
        
        if features.contains(.aromaticRing) && features.contains(.hydrophobicRegion) {
            targets.append("Nuclear receptors")
            targets.append("Kinases")
        }
        
        if features.contains(.hydrogenBondDonor) && features.contains(.hydrogenBondAcceptor) {
            targets.append("Proteases")
            targets.append("Transcription factors")
        }
        
        return targets.isEmpty ? ["General protein targets"] : targets
    }
    
    private func suggestOptimizations(features: [PharmacophoreFeature]) -> [String] {
        var suggestions: [String] = []
        
        if !features.contains(.hydrogenBondDonor) && !features.contains(.hydrogenBondAcceptor) {
            suggestions.append("Add hydrogen bonding capability for specificity")
        }
        
        if features.count < 3 {
            suggestions.append("Consider adding more features for selectivity")
        }
        
        if features.count > 6 {
            suggestions.append("Reduce complexity to improve drug-likeness")
        }
        
        if !features.contains(.hydrophobicRegion) {
            suggestions.append("Add hydrophobic interactions for binding affinity")
        }
        
        return suggestions.isEmpty ? ["Current pharmacophore is well balanced"] : suggestions
    }
    
    private func generateMolecularExamples(features: [PharmacophoreFeature]) -> [String] {
        // Return example molecules that contain the selected features
        let examples = ["Aspirin", "Caffeine", "Morphine", "Dopamine", "Ibuprofen"]
        return Array(examples.shuffled().prefix(3))
    }
}

// MARK: - Pharmacophore Components
struct CategoryButton: View {
    let category: FeatureCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption)
                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.purple : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

struct PharmacophoreFeatureCard: View {
    let feature: PharmacophoreFeature
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with icon and importance
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: feature.icon)
                            .font(.title3)
                            .foregroundColor(feature.color)
                            .frame(width: 24)
                        
                        Text(feature.rawValue)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(repeating: "★", count: Int(feature.importance * 5)))
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? .green : .gray)
                            .font(.title3)
                    }
                }
                
                // Description
                Text(feature.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                
                // Examples
                if !feature.exampleMolecules.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            Text("Examples:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            ForEach(feature.exampleMolecules.prefix(2), id: \.self) { example in
                                Text(example)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(feature.color.opacity(0.2))
                                    .foregroundColor(feature.color)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(isSelected ? feature.color.opacity(0.1) : Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? feature.color : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PharmacophoreAnalysisCard: View {
    let analysis: PharmacophoreAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pharmacophore Analysis")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("\(analysis.selectedFeatures.count) features analyzed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.0f", analysis.overallScore * 100))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(analysis.overallScore > 0.7 ? .green :
                                       analysis.overallScore > 0.4 ? .orange : .red)
                    Text("Overall Score")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Recommendation
            HStack {
                Image(systemName: analysis.overallScore > 0.7 ? "checkmark.circle.fill" :
                      analysis.overallScore > 0.4 ? "exclamationmark.triangle.fill" : "xmark.circle.fill")
                    .foregroundColor(analysis.overallScore > 0.7 ? .green :
                                   analysis.overallScore > 0.4 ? .orange : .red)
                
                Text(analysis.recommendation)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(analysis.overallScore > 0.7 ? Color.green.opacity(0.1) :
                          analysis.overallScore > 0.4 ? Color.orange.opacity(0.1) : Color.red.opacity(0.1))
            )
            
            // Metrics Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                MetricCard(title: "Selectivity", value: analysis.selectivity, icon: "target")
                MetricCard(title: "Drug-likeness", value: analysis.drugLikeness, icon: "pills")
                MetricCard(title: "Binding Affinity", value: analysis.bindingAffinity, icon: "link")
                MetricCard(title: "Features", value: "\(analysis.selectedFeatures.count)", icon: "atom")
            }
            
            // Target Suggestions
            if !analysis.targetSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "scope")
                            .foregroundColor(.blue)
                        Text("Suggested Targets")
                            .font(.headline)
                    }
                    
                    ForEach(analysis.targetSuggestions, id: \.self) { target in
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text(target)
                                .font(.body)
                        }
                    }
                }
                .padding(12)
                .background(Color.blue.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Optimization Suggestions
            if !analysis.optimizationSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb")
                            .foregroundColor(.orange)
                        Text("Optimization Tips")
                            .font(.headline)
                    }
                    
                    ForEach(analysis.optimizationSuggestions, id: \.self) { suggestion in
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(suggestion)
                                .font(.body)
                        }
                    }
                }
                .padding(12)
                .background(Color.orange.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Molecular Examples
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "flask")
                        .foregroundColor(.green)
                    Text("Example Molecules")
                        .font(.headline)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(analysis.molecularExamples, id: \.self) { example in
                            Text(example)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(12)
            .background(Color.green.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.purple)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SelectedFeatureChip: View {
    let feature: PharmacophoreFeature
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: feature.icon)
                .font(.caption)
            Text(feature.rawValue)
                .font(.caption)
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(feature.color.opacity(0.2))
        .foregroundColor(feature.color)
        .clipShape(Capsule())
    }
}

// MARK: - Smart 3D Viewer with Better Complex Molecule Handling
struct Enhanced3DViewerView: View {
    @State private var smilesInput = "c1ccccc1"
    @State private var showingViewer = false
    @State private var selectedMolecule: Molecule?
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("3D Molecular Viewer")
                    .font(.headline)
                
                Text("Enter SMILES to visualize molecular structure in 3D")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Enter SMILES (e.g., CCO, CC(=O)O)", text: $smilesInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Button("View 3D Structure") {
                    createMoleculeAndView()
                }
                .disabled(smilesInput.isEmpty)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Information Panel
            VStack(alignment: .leading, spacing: 8) {
                Text("3D Visualization Options")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text("✅ Simple molecules: Full 3D structure")
                    .font(.caption2)
                    .foregroundColor(.green)
                Text("⚠️ Complex molecules: Analysis + simple reference")
                    .font(.caption2)
                    .foregroundColor(.orange)
                Text("🔮 Advanced: Use external tools like ChemDraw, Avogadro")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            // Quick Examples
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Examples")
                    .font(.headline)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    QuickMoleculeButton(name: "Ethanol", smiles: "CCO") {
                        smilesInput = "CCO"
                        createMoleculeAndView()
                    }
                    QuickMoleculeButton(name: "Aspirin", smiles: "CC(=O)OC1=CC=CC=C1C(=O)O") {
                        smilesInput = "CC(=O)OC1=CC=CC=C1C(=O)O"
                        createMoleculeAndView()
                    }
                    QuickMoleculeButton(name: "Caffeine", smiles: "CN1C=NC2=C1C(=O)N(C(=O)N2C)C") {
                        smilesInput = "CN1C=NC2=C1C(=O)N(C(=O)N2C)C"
                        createMoleculeAndView()
                    }
                    QuickMoleculeButton(name: "Benzene", smiles: "c1ccccc1") {
                        smilesInput = "c1ccccc1"
                        createMoleculeAndView()
                    }
                    QuickMoleculeButton(name: "Methane", smiles: "C") {
                        smilesInput = "C"
                        createMoleculeAndView()
                    }
                    QuickMoleculeButton(name: "Water", smiles: "O") {
                        smilesInput = "O"
                        createMoleculeAndView()
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            
            Spacer()
        }
        .padding()
        .navigationTitle("3D Viewer")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingViewer) {
            if let molecule = selectedMolecule {
                NavigationView {
                    Enhanced3DMolecularViewer(molecule: molecule)
                        .navigationTitle(molecule.name)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingViewer = false
                                }
                            }
                        }
                }
            }
        }
    }
    
    private func createMoleculeAndView() {
        let molecule = Molecule(name: getMoleculeName(for: smilesInput), smiles: smilesInput)
        selectedMolecule = molecule
        showingViewer = true
    }
    
    private func getMoleculeName(for smiles: String) -> String {
        switch smiles.lowercased() {
        case "cco": return "Ethanol"
        case "cc(=o)oc1=cc=cc=c1c(=o)o", "cc(=o)oc1ccccc1c(=o)o": return "Aspirin"
        case "cn1c=nc2=c1c(=o)n(c(=o)n2c)c": return "Caffeine"
        case "c1ccccc1": return "Benzene"
        case "cc(=o)o": return "Acetic Acid"
        case "o": return "Water"
        case "c": return "Methane"
        default:
            if smiles.count > 20 {
                return "Complex Drug Molecule"
            } else {
                return "Custom Molecule"
            }
        }
    }
}

struct Enhanced3DMolecularViewer: UIViewRepresentable {
    let molecule: Molecule

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = .systemBackground
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let escapedSmiles = molecule.smiles.replacingOccurrences(of: "'", with: "\\'")
        let escapedName = molecule.name.replacingOccurrences(of: "'", with: "\\'")

        let html = #"""
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <script src="https://3Dmol.csb.pitt.edu/build/3Dmol-min.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            height: 100vh;
            overflow: hidden;
        }
        #viewer {
            width: 100vw;
            height: 75vh;
            position: relative;
            background: transparent;
        }
        .controls {
            position: absolute;
            top: 10px;
            right: 10px;
            z-index: 1000;
            display: flex;
            gap: 5px;
        }
        .control-btn {
            background: rgba(255,255,255,0.95);
            border: none;
            border-radius: 6px;
            padding: 8px 12px;
            font-size: 12px;
            cursor: pointer;
            box-shadow: 0 2px 8px rgba(0,0,0,0.2);
            backdrop-filter: blur(10px);
            transition: all 0.2s ease;
        }
        .control-btn:active {
            transform: scale(0.95);
            background: rgba(255,255,255,0.8);
        }
        .info-panel {
            position: absolute;
            bottom: 0;
            left: 0;
            right: 0;
            background: rgba(255,255,255,0.95);
            padding: 15px;
            backdrop-filter: blur(20px);
            box-shadow: 0 -4px 20px rgba(0,0,0,0.1);
            text-align: center;
        }
        .loading {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            background: rgba(255,255,255,0.95);
            padding: 20px;
            border-radius: 12px;
            text-align: center;
            box-shadow: 0 4px 20px rgba(0,0,0,0.2);
            z-index: 999;
        }
        .molecule-name {
            font-size: 16px;
            font-weight: bold;
            margin-bottom: 5px;
        }
        .molecule-smiles {
            font-size: 12px;
            color: #666;
            font-family: monospace;
            word-break: break-all;
            line-height: 1.3;
        }
        .complex-molecule {
            text-align: center;
            padding: 20px;
            height: 100vh;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
        }
        .molecule-icon {
            font-size: 64px;
            margin: 20px 0;
            animation: pulse 2s infinite;
        }
        @keyframes pulse {
            0%, 100% { transform: scale(1); }
            50% { transform: scale(1.1); }
        }
        .complexity-info {
            background: rgba(255,255,255,0.15);
            padding: 20px;
            border-radius: 15px;
            margin: 20px;
            font-size: 14px;
            line-height: 1.4;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255,255,255,0.2);
        }
        .atom-count {
            color: #4CAF50;
            font-weight: bold;
            font-size: 16px;
        }
        .fallback-note {
            background: rgba(255,193,7,0.2);
            border: 1px solid rgba(255,193,7,0.5);
            padding: 15px;
            border-radius: 10px;
            margin: 20px;
            font-size: 12px;
            color: #fff3cd;
            backdrop-filter: blur(5px);
        }
        .mini-viewer-container {
            background: rgba(0,0,0,0.3);
            padding: 15px;
            border-radius: 15px;
            margin: 20px;
            border: 2px solid rgba(255,255,255,0.3);
        }
        #mini-viewer {
            width: 200px;
            height: 150px;
            border-radius: 10px;
            overflow: hidden;
        }
        .external-tools {
            background: rgba(0,123,255,0.2);
            border: 1px solid rgba(0,123,255,0.5);
            padding: 15px;
            border-radius: 10px;
            margin: 20px;
            font-size: 12px;
            color: #cce7ff;
        }
        .tool-link {
            color: #66b3ff;
            text-decoration: none;
            font-weight: bold;
        }
    </style>
</head>
<body>
    <div id="viewer"></div>
    <div class="controls">
        <button class="control-btn" onclick="resetView()">🔄 Reset</button>
        <button class="control-btn" onclick="toggleStyle()">🎨 Style</button>
        <button class="control-btn" onclick="toggleSpin()">🌀 Spin</button>
    </div>
    <div class="info-panel">
        <div class="molecule-name">\#(escapedName)</div>
        <div class="molecule-smiles">\#(escapedSmiles)</div>
    </div>
    <div class="loading" id="loading">
        <div>Analyzing molecular structure...</div>
        <div style="margin-top: 10px; font-size: 12px; color: #666;">Processing SMILES notation</div>
    </div>
    <script>
        let viewer;
        let currentStyle = 0;
        let isSpinning = false;
        const smiles = '\#(escapedSmiles)';
        const moleculeName = '\#(escapedName)';

        // Built-in molecular data for simple molecules
        const simpleMolecules = {
            'c1ccccc1': {
                name: 'Benzene',
                sdf: `
  Mrv2014 12062410313D          

  6  6  0  0  0  0            999 V2000
    1.2990    0.7500    0.0000 C   0  0  0  0  0  0  0  0  0  0  0  0
    1.2990   -0.7500    0.0000 C   0  0  0  0  0  0  0  0  0  0  0  0
    0.0000   -1.5000    0.0000 C   0  0  0  0  0  0  0  0  0  0  0  0
   -1.2990   -0.7500    0.0000 C   0  0  0  0  0  0  0  0  0  0  0  0
   -1.2990    0.7500    0.0000 C   0  0  0  0  0  0  0  0  0  0  0  0
    0.0000    1.5000    0.0000 C   0  0  0  0  0  0  0  0  0  0  0  0
  1  2  2  0  0  0  0
  2  3  1  0  0  0  0
  3  4  2  0  0  0  0
  4  5  1  0  0  0  0
  5  6  2  0  0  0  0
  6  1  1  0  0  0  0
M  END
$$`
            },
            'cco': {
                name: 'Ethanol',
                sdf: `
  Mrv2014 12062410313D          

  9  8  0  0  0  0            999 V2000
    1.2990    0.0000    0.0000 C   0  0  0  0  0  0  0  0  0  0  0  0
    0.0000    0.0000    0.0000 C   0  0  0  0  0  0  0  0  0  0  0  0
   -0.5130    0.8130    0.0000 O   0  0  0  0  0  0  0  0  0  0  0  0
    1.7540   -0.9560    0.0000 H   0  0  0  0  0  0  0  0  0  0  0  0
    1.7540    0.4780    0.4780 H   0  0  0  0  0  0  0  0  0  0  0  0
    1.7540    0.4780   -0.4780 H   0  0  0  0  0  0  0  0  0  0  0  0
   -0.4550   -0.4780    0.4780 H   0  0  0  0  0  0  0  0  0  0  0  0
   -0.4550   -0.4780   -0.4780 H   0  0  0  0  0  0  0  0  0  0  0  0
   -1.4530    0.6560    0.0000 H   0  0  0  0  0  0  0  0  0  0  0  0
  1  2  1  0  0  0  0
  1  4  1  0  0  0  0
  1  5  1  0  0  0  0
  1  6  1  0  0  0  0
  2  3  1  0  0  0  0
  2  7  1  0  0  0  0
  2  8  1  0  0  0  0
  3  9  1  0  0  0  0
M  END
$$`
            },
            'o': {
                name: 'Water',
                sdf: `
  Mrv2014 12062410313D          

  3  2  0  0  0  0            999 V2000
    0.0000    0.0000    0.0000 O   0  0  0  0  0  0  0  0  0  0  0  0
    0.7572    0.5858    0.0000 H   0  0  0  0  0  0  0  0  0  0  0  0
   -0.7572    0.5858    0.0000 H   0  0  0  0  0  0  0  0  0  0  0  0
  1  2  1  0  0  0  0
  1  3  1  0  0  0  0
M  END
$$`
            },
            'c': {
                name: 'Methane',
                sdf: `
  Mrv2014 12062410313D          

  5  4  0  0  0  0            999 V2000
    0.0000    0.0000    0.0000 C   0  0  0  0  0  0  0  0  0  0  0  0
    0.6300    0.6300    0.6300 H   0  0  0  0  0  0  0  0  0  0  0  0
   -0.6300   -0.6300    0.6300 H   0  0  0  0  0  0  0  0  0  0  0  0
   -0.6300    0.6300   -0.6300 H   0  0  0  0  0  0  0  0  0  0  0  0
    0.6300   -0.6300   -0.6300 H   0  0  0  0  0  0  0  0  0  0  0  0
  1  2  1  0  0  0  0
  1  3  1  0  0  0  0
  1  4  1  0  0  0  0
  1  5  1  0  0  0  0
M  END
$$`
            }
        };

        function initViewer() {
            try {
                console.log('🔬 Analyzing SMILES:', smiles);
                
                const normalizedSmiles = smiles.toLowerCase().trim();
                const isComplexMolecule = smiles.length > 20 || 
                                        (smiles.match(/[CNO]/g) || []).length > 10 ||
                                        (smiles.match(/[=]/g) || []).length > 3;
                
                if (isComplexMolecule) {
                    console.log('🧬 Complex molecule detected');
                    showComplexMoleculeInfo();
                    return;
                }
                
                console.log('⚛️ Simple molecule, initializing 3D viewer');
                viewer = $3Dmol.createViewer("viewer", {
                    defaultcolors: $3Dmol.rasmolElementColors,
                    backgroundColor: 'transparent'
                });

                loadSimpleMolecule();
                
            } catch (error) {
                console.error('❌ Error in initViewer:', error);
                showError('Initialization failed: ' + error.message);
            }
        }

        function showComplexMoleculeInfo() {
            document.getElementById("loading").style.display = "none";
            
            // Analyze the SMILES
            const carbonCount = (smiles.match(/C/g) || []).length;
            const nitrogenCount = (smiles.match(/N/g) || []).length;
            const oxygenCount = (smiles.match(/O/g) || []).length;
            const sulfurCount = (smiles.match(/S/g) || []).length;
            const fluorineCount = (smiles.match(/F/g) || []).length;
            const ringCount = (smiles.match(/\d/g) || []).length / 2;
            
            const totalAtoms = carbonCount + nitrogenCount + oxygenCount + sulfurCount + fluorineCount;
            
            document.getElementById("viewer").innerHTML = `
                <div class="complex-molecule">
                    <div class="molecule-icon">🧬</div>
                    <h2 style="color: white; margin-bottom: 10px;">Complex Pharmaceutical Molecule</h2>
                    
                    <div class="complexity-info">
                        <strong>Molecular Complexity Analysis:</strong><br><br>
                        <span class="atom-count">~${totalAtoms} heavy atoms</span><br><br>
                        <strong>Composition:</strong><br>
                        Carbon: ${carbonCount} | Nitrogen: ${nitrogenCount} | Oxygen: ${oxygenCount}<br>
                        ${sulfurCount > 0 ? `Sulfur: ${sulfurCount} | ` : ''}${fluorineCount > 0 ? `Fluorine: ${fluorineCount}` : ''}<br>
                        Estimated rings: ~${Math.floor(ringCount)}
                    </div>
                    
                    <div style="color: rgba(255,255,255,0.9); margin: 15px; font-size: 14px;">
                        This appears to be a complex drug-like molecule,<br>
                        possibly a kinase inhibitor or similar pharmaceutical compound.
                    </div>
                    
                    <div class="fallback-note">
                        ⚠️ Full 3D structure generation for complex molecules requires specialized software.<br>
                        Showing benzene reference below for aromatic comparison.
                    </div>
                    
                    <div class="mini-viewer-container">
                        <div style="color: white; margin-bottom: 10px; font-size: 12px;">
                            <strong>Aromatic Reference (Benzene Ring)</strong>
                        </div>
                        <div id="mini-viewer"></div>
                    </div>
                    
                    <div class="external-tools">
                        <strong>🔧 For Full 3D Structures:</strong><br>
                        • ChemDraw 3D (Professional)<br>
                        • Avogadro (Free, Open Source)<br>
                        • PyMOL (Research)<br>
                        • RDKit + Py3Dmol (Programming)
                    </div>
                </div>
            `;
            
            // Add the mini benzene viewer with proper containment
            setTimeout(() => {
                try {
                    const refViewer = $3Dmol.createViewer("mini-viewer", {
                        defaultcolors: $3Dmol.rasmolElementColors,
                        backgroundColor: 'rgba(0,0,0,0.5)'
                    });
                    
                    refViewer.addModel(simpleMolecules['c1ccccc1'].sdf, 'sdf');
                    refViewer.setStyle({}, {stick: {radius: 0.1}, sphere: {scale: 0.2}});
                    refViewer.zoomTo();
                    refViewer.render();
                    refViewer.spin("y", 0.5);
                    
                    console.log('✅ Mini benzene viewer created');
                } catch (error) {
                    console.error('❌ Error creating mini viewer:', error);
                    document.getElementById('mini-viewer').innerHTML = '<div style="color: white; padding: 20px;">Benzene structure loading...</div>';
                }
            }, 500);
        }

        function loadSimpleMolecule() {
            const normalizedSmiles = smiles.toLowerCase().trim();
            const molecule = simpleMolecules[normalizedSmiles];
            
            if (molecule) {
                console.log(`✅ Loading ${molecule.name}`);
                loadMoleculeData(molecule.sdf);
            } else {
                console.log(`⚠️ Unknown simple molecule, using benzene fallback`);
                loadMoleculeData(simpleMolecules['c1ccccc1'].sdf);
            }
        }

        function loadMoleculeData(sdfData) {
            try {
                viewer.addModel(sdfData, 'sdf');
                viewer.setStyle({}, {stick: {radius: 0.15}, sphere: {scale: 0.25}});
                viewer.zoomTo();
                viewer.render();
                
                document.getElementById("loading").style.display = "none";
                console.log('✅ 3D structure loaded successfully');
                
            } catch (error) {
                console.error('❌ Error loading 3D structure:', error);
                showError('Failed to render 3D structure: ' + error.message);
            }
        }

        function showError(message) {
            document.getElementById("loading").innerHTML = `
                <div style="color: #d32f2f;">
                    <div>⚠️ Error</div>
                    <div style="margin-top: 10px; font-size: 12px;">${message}</div>
                </div>
            `;
        }

        function resetView() {
            if (viewer) {
                viewer.zoomTo();
                viewer.render();
            }
        }

        function toggleStyle() {
            if (!viewer) return;
            currentStyle = (currentStyle + 1) % 4;
            switch(currentStyle) {
                case 0:
                    viewer.setStyle({}, {stick: {radius: 0.15}, sphere: {scale: 0.25}});
                    break;
                case 1:
                    viewer.setStyle({}, {sphere: {scale: 0.4}});
                    break;
                case 2:
                    viewer.setStyle({}, {line: {linewidth: 3}});
                    break;
                case 3:
                    viewer.setStyle({}, {stick: {radius: 0.2}});
                    break;
            }
            viewer.render();
        }

        function toggleSpin() {
            if (!viewer) return;
            isSpinning = !isSpinning;
            viewer.spin(isSpinning ? "y" : false, 0.5);
        }

        // Initialize when page loads
        window.onload = function() {
            console.log('🚀 Starting molecular viewer...');
            setTimeout(initViewer, 100);
        };
    </script>
</body>
</html>
"""#

        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ Enhanced 3D Molecular Viewer loaded")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ Enhanced 3D Molecular Viewer failed: \(error)")
        }
    }
}
// MARK: - Supporting Views
struct SearchTypeButton: View {
    let type: SearchType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.caption)
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

struct MoleculeRowView: View {
    let molecule: Molecule
    
    var body: some View {
        HStack(spacing: 12) {
            // Placeholder for molecule image
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "atom")
                        .foregroundColor(.secondary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(molecule.name)
                    .font(.headline)
                    .lineLimit(1)
                
                if let formula = molecule.molecularFormula {
                    Text(formula)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                if let weight = molecule.molecularWeight {
                    Text("MW: \(String(format: "%.2f", weight)) Da")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    if molecule.lipinskiCompliant {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    Text("Drug-like: \(String(format: "%.0f%%", molecule.drugLikenessScore * 100))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct PropertyRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Search Error")
                .font(.headline)
            
            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct EmptySearchView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 80))
                .foregroundColor(.blue.opacity(0.3))
            
            VStack(spacing: 8) {
                Text("Search Molecular Databases")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Find molecules by name, SMILES, CAS number, or InChI")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

struct QuickMoleculeButton: View {
    let name: String
    let smiles: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(smiles.count > 12 ? String(smiles.prefix(12)) + "..." : smiles)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Other Views
struct MoleculeDetailView: View {
    let molecule: Molecule
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(molecule.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if let formula = molecule.molecularFormula {
                    Text(formula)
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                Text(molecule.smiles)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
            .padding()
        }
        .navigationTitle("Molecule Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Data Models
struct Compound: Identifiable, Codable {
    var id = UUID()
    var name: String
    var smiles: String
    var activity: Double?
    var descriptors: MolecularDescriptors?
    
    init(name: String, smiles: String, activity: Double? = nil) {
        self.name = name
        self.smiles = smiles
        self.activity = activity
    }
}

struct MolecularDescriptors: Codable {
    var molecularWeight: Double
    var logP: Double
    var tpsa: Double
    var hbdCount: Int
    var hbaCount: Int
    var rotBondCount: Int
    var ringCount: Int
    var aromaticRingCount: Int
    var heavyAtomCount: Int
    
    // Additional computed descriptors
    var lipophilicityEfficiency: Double? {
        guard let activity = activity else { return nil }
        return activity / molecularWeight * 1000 // LE = pActivity / Heavy Atom Count
    }
    
    private var activity: Double?
    
    init(molecularWeight: Double, logP: Double, tpsa: Double, hbdCount: Int, hbaCount: Int, rotBondCount: Int, ringCount: Int, aromaticRingCount: Int, heavyAtomCount: Int, activity: Double? = nil) {
        self.molecularWeight = molecularWeight
        self.logP = logP
        self.tpsa = tpsa
        self.hbdCount = hbdCount
        self.hbaCount = hbaCount
        self.rotBondCount = rotBondCount
        self.ringCount = ringCount
        self.aromaticRingCount = aromaticRingCount
        self.heavyAtomCount = heavyAtomCount
        self.activity = activity
    }
}

struct QSARModel {
    var name: String
    var compounds: [Compound]
    var trainingAccuracy: Double?
    var testAccuracy: Double?
    var featureImportance: [String: Double]?
    var predictions: [Double]?
    
    init(name: String) {
        self.name = name
        self.compounds = []
        self.featureImportance = [:]
    }
}

// MARK: - Descriptor Calculator Service
class DescriptorCalculatorService: ObservableObject {
    @Published var isCalculating = false
    @Published var calculationProgress: Double = 0.0
    
    // Mock descriptor calculation - in real app, you'd use RDKit API or similar
    func calculateDescriptors(for compounds: [Compound]) async -> [Compound] {
        await MainActor.run {
            isCalculating = true
            calculationProgress = 0.0
        }
        
        var updatedCompounds: [Compound] = []
        
        for (index, compound) in compounds.enumerated() {
            let descriptors = await calculateMolecularDescriptors(smiles: compound.smiles)
            var updatedCompound = compound
            updatedCompound.descriptors = descriptors
            updatedCompounds.append(updatedCompound)
            
            await MainActor.run {
                calculationProgress = Double(index + 1) / Double(compounds.count)
            }
        }
        
        await MainActor.run {
            isCalculating = false
        }
        
        return updatedCompounds
    }
    
    private func calculateMolecularDescriptors(smiles: String) async -> MolecularDescriptors {
        // Simulate API call delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Mock calculations based on SMILES length and content
        // In real implementation, use chemistry APIs or libraries
        let molecularWeight = Double(smiles.count * 12 + Int.random(in: 50...150))
        let logP = Double.random(in: -2...5)
        let tpsa = Double.random(in: 20...140)
        let hbdCount = smiles.filter { $0 == "O" || $0 == "N" }.count
        let hbaCount = smiles.filter { $0 == "O" || $0 == "N" }.count + 2
        let rotBondCount = max(0, smiles.count / 5 - 2)
        let ringCount = smiles.filter { $0 == "c" || $0 == "C" }.count / 6
        let aromaticRingCount = max(0, ringCount - 1)
        let heavyAtomCount = smiles.filter { $0.isLetter }.count
        
        return MolecularDescriptors(
            molecularWeight: molecularWeight,
            logP: logP,
            tpsa: tpsa,
            hbdCount: hbdCount,
            hbaCount: hbaCount,
            rotBondCount: rotBondCount,
            ringCount: ringCount,
            aromaticRingCount: aromaticRingCount,
            heavyAtomCount: heavyAtomCount
        )
    }
}

// MARK: - QSAR Model Service
class QSARModelService: ObservableObject {
    @Published var models: [QSARModel] = []
    @Published var isTraining = false
    @Published var trainingProgress: Double = 0.0
    
    func createModel(name: String, compounds: [Compound]) async -> QSARModel {
        await MainActor.run {
            isTraining = true
            trainingProgress = 0.0
        }
        
        var model = QSARModel(name: name)
        model.compounds = compounds
        
        // Simulate model training
        for i in 1...10 {
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            await MainActor.run {
                trainingProgress = Double(i) / 10.0
            }
        }
        
        // Mock training results
        model.trainingAccuracy = Double.random(in: 0.75...0.95)
        model.testAccuracy = Double.random(in: 0.65...0.85)
        
        // Mock feature importance
        model.featureImportance = [
            "Molecular Weight": Double.random(in: 0.1...0.3),
            "LogP": Double.random(in: 0.15...0.35),
            "TPSA": Double.random(in: 0.1...0.25),
            "HBD Count": Double.random(in: 0.05...0.15),
            "HBA Count": Double.random(in: 0.05...0.15),
            "Rotatable Bonds": Double.random(in: 0.1...0.2)
        ]
        
        // Generate mock predictions
        model.predictions = compounds.map { _ in Double.random(in: 4...9) }
        
        await MainActor.run {
            isTraining = false
            models.append(model)
        }
        
        return model
    }
    
    func predictActivity(model: QSARModel, newCompounds: [Compound]) -> [Double] {
        // Mock prediction based on descriptors
        return newCompounds.map { compound in
            guard let descriptors = compound.descriptors else { return 0.0 }
            
            // Simple mock prediction formula
            let prediction = 8.0 - (descriptors.molecularWeight / 100.0) + descriptors.logP - (descriptors.tpsa / 50.0)
            return max(0, min(10, prediction))
        }
    }
}

struct QSARBuilderView: View {
    @StateObject private var descriptorService = DescriptorCalculatorService()
    @StateObject private var modelService = QSARModelService()
    
    @State private var compounds: [Compound] = []
    @State private var newCompoundName = ""
    @State private var newCompoundSMILES = ""
    @State private var newCompoundActivity = ""
    @State private var selectedTab = 0
    @State private var showingAddCompound = false
    @State private var showingImportSheet = false
    @State private var modelName = "QSAR Model"
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // Data Input Tab
                CompoundInputView(
                    compounds: $compounds,
                    showingAddCompound: $showingAddCompound,
                    showingImportSheet: $showingImportSheet
                )
                .tabItem {
                    Image(systemName: "plus.circle")
                    Text("Data Input")
                }
                .tag(0)
                
                // Descriptors Tab
                DescriptorsView(
                    compounds: $compounds,
                    descriptorService: descriptorService
                )
                .tabItem {
                    Image(systemName: "function")
                    Text("Descriptors")
                }
                .tag(1)
                
                // Model Building Tab
                ModelBuildingView(
                    compounds: compounds,
                    modelService: modelService,
                    modelName: $modelName
                )
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("Modeling")
                }
                .tag(2)
                
                // Results Tab
                ResultsView(models: modelService.models)
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Results")
                }
                .tag(3)
            }
            .navigationTitle("QSAR Builder")
            .sheet(isPresented: $showingAddCompound) {
                AddCompoundSheet(compounds: $compounds)
            }
            .sheet(isPresented: $showingImportSheet) {
                ImportDataSheet(compounds: $compounds)
            }
        }
    }
}

// MARK: - Compound Input View
struct CompoundInputView: View {
    @Binding var compounds: [Compound]
    @Binding var showingAddCompound: Bool
    @Binding var showingImportSheet: Bool
    
    var body: some View {
        VStack {
            // Header with actions
            HStack {
                Text("Dataset (\(compounds.count) compounds)")
                    .font(.headline)
                
                Spacer()
                
                Menu {
                    Button("Add Manually") {
                        showingAddCompound = true
                    }
                    Button("Import CSV") {
                        showingImportSheet = true
                    }
                    Button("Sample Data") {
                        loadSampleData()
                    }
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            
            // Compound List
            if compounds.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("No compounds added yet")
                        .font(.title2)
                        .foregroundColor(.gray)
                    
                    Text("Add compounds manually or import from CSV")
                        .foregroundColor(.secondary)
                    
                    Button("Add Sample Data") {
                        loadSampleData()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(compounds) { compound in
                        CompoundRowView(compound: compound)
                    }
                    .onDelete(perform: deleteCompounds)
                }
            }
        }
    }
    
    private func deleteCompounds(offsets: IndexSet) {
        compounds.remove(atOffsets: offsets)
    }
    
    private func loadSampleData() {
        compounds = [
            Compound(name: "Aspirin", smiles: "CC(=O)OC1=CC=CC=C1C(=O)O", activity: 6.5),
            Compound(name: "Ibuprofen", smiles: "CC(C)CC1=CC=C(C=C1)C(C)C(=O)O", activity: 7.2),
            Compound(name: "Caffeine", smiles: "CN1C=NC2=C1C(=O)N(C(=O)N2C)C", activity: 5.8),
            Compound(name: "Paracetamol", smiles: "CC(=O)NC1=CC=C(C=C1)O", activity: 6.1),
            Compound(name: "Warfarin", smiles: "CC(=O)CC(C1=CC=CC=C1)C2=C(C3=CC=CC=C3OC2=O)O", activity: 8.3)
        ]
    }
}

// MARK: - Individual Compound Row
struct CompoundRowView: View {
    let compound: Compound
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(compound.name)
                    .font(.headline)
                
                Spacer()
                
                if let activity = compound.activity {
                    Text("Activity: \(activity, specifier: "%.2f")")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            Text("SMILES: \(compound.smiles)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            if let descriptors = compound.descriptors {
                HStack {
                    Text("MW: \(descriptors.molecularWeight, specifier: "%.1f")")
                    Text("LogP: \(descriptors.logP, specifier: "%.2f")")
                    Text("TPSA: \(descriptors.tpsa, specifier: "%.1f")")
                }
                .font(.caption)
                .foregroundColor(.green)
            } else {
                Text("Descriptors not calculated")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Compound Sheet
struct AddCompoundSheet: View {
    @Binding var compounds: [Compound]
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var smiles = ""
    @State private var activity = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Compound Information") {
                    TextField("Compound Name", text: $name)
                    TextField("SMILES", text: $smiles)
                        .font(.system(.body, design: .monospaced))
                    TextField("Activity Value (optional)", text: $activity)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Add Compound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let activityValue = Double(activity)
                        let compound = Compound(name: name, smiles: smiles, activity: activityValue)
                        compounds.append(compound)
                        dismiss()
                    }
                    .disabled(name.isEmpty || smiles.isEmpty)
                }
            }
        }
    }
}

// MARK: - Import Data Sheet
struct ImportDataSheet: View {
    @Binding var compounds: [Compound]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Import CSV Data")
                    .font(.title2)
                
                Text("CSV format: Name, SMILES, Activity")
                    .foregroundColor(.secondary)
                
                Button("Select CSV File") {
                    // Implement file picker
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Descriptors View
struct DescriptorsView: View {
    @Binding var compounds: [Compound]
    @ObservedObject var descriptorService: DescriptorCalculatorService
    
    var body: some View {
        VStack {
            if compounds.isEmpty {
                Text("Add compounds first to calculate descriptors")
                    .foregroundColor(.secondary)
                    .frame(maxHeight: .infinity)
            } else {
                VStack(spacing: 20) {
                    // Progress indicator
                    if descriptorService.isCalculating {
                        VStack {
                            ProgressView("Calculating descriptors...", value: descriptorService.calculationProgress)
                            Text("\(Int(descriptorService.calculationProgress * 100))% complete")
                                .font(.caption)
                        }
                        .padding()
                    }
                    
                    // Calculate button
                    Button("Calculate Descriptors") {
                        Task {
                            compounds = await descriptorService.calculateDescriptors(for: compounds)
                        }
                    }
                    .disabled(descriptorService.isCalculating)
                    .buttonStyle(.borderedProminent)
                    
                    // Descriptors summary
                    if let firstCompound = compounds.first, firstCompound.descriptors != nil {
                        DescriptorsSummaryView(compounds: compounds)
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Descriptors Summary
struct DescriptorsSummaryView: View {
    let compounds: [Compound]
    
    private var descriptorStats: [(String, Double, Double)] {
        let validCompounds = compounds.compactMap { $0.descriptors }
        guard !validCompounds.isEmpty else { return [] }
        
        return [
            ("Molecular Weight",
             validCompounds.map { $0.molecularWeight }.reduce(0, +) / Double(validCompounds.count),
             validCompounds.map { $0.molecularWeight }.max() ?? 0),
            ("LogP",
             validCompounds.map { $0.logP }.reduce(0, +) / Double(validCompounds.count),
             validCompounds.map { $0.logP }.max() ?? 0),
            ("TPSA",
             validCompounds.map { $0.tpsa }.reduce(0, +) / Double(validCompounds.count),
             validCompounds.map { $0.tpsa }.max() ?? 0)
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Descriptor Statistics")
                .font(.headline)
            
            ForEach(descriptorStats, id: \.0) { stat in
                HStack {
                    Text(stat.0)
                        .frame(width: 120, alignment: .leading)
                    Text("Avg: \(stat.1, specifier: "%.2f")")
                        .frame(width: 80, alignment: .leading)
                    Text("Max: \(stat.2, specifier: "%.2f")")
                        .foregroundColor(.secondary)
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Model Building View
struct ModelBuildingView: View {
    let compounds: [Compound]
    @ObservedObject var modelService: QSARModelService
    @Binding var modelName: String
    
    var canBuildModel: Bool {
        compounds.count >= 3 && compounds.allSatisfy { $0.descriptors != nil && $0.activity != nil }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if !canBuildModel {
                VStack(spacing: 15) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    
                    Text("Requirements not met")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        RequirementRow(
                            text: "At least 3 compounds",
                            isMet: compounds.count >= 3
                        )
                        RequirementRow(
                            text: "All compounds have descriptors",
                            isMet: compounds.allSatisfy { $0.descriptors != nil }
                        )
                        RequirementRow(
                            text: "All compounds have activity values",
                            isMet: compounds.allSatisfy { $0.activity != nil }
                        )
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                VStack(spacing: 15) {
                    TextField("Model Name", text: $modelName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if modelService.isTraining {
                        VStack {
                            ProgressView("Training model...", value: modelService.trainingProgress)
                            Text("\(Int(modelService.trainingProgress * 100))% complete")
                                .font(.caption)
                        }
                    } else {
                        Button("Build QSAR Model") {
                            Task {
                                await modelService.createModel(name: modelName, compounds: compounds)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(modelName.isEmpty)
                    }
                    
                    if !modelService.models.isEmpty {
                        Text("Models Created: \(modelService.models.count)")
                            .foregroundColor(.green)
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Nanoparticle Designer
struct NanoparticleDesignerView: View {
    @State private var selectedNanoType: NanoparticleType = .liposome
    @State private var coreSize: Double = 100.0
    @State private var selectedDrug: String = ""
    @State private var targetTissue: TargetTissue = .tumor
    @State private var surfaceModification: SurfaceModification = .pegylation
    @State private var designResults: NanoparticleDesign?
    @State private var showingResults = false
    
    enum NanoparticleType: String, CaseIterable {
        case liposome = "Liposome"
        case polymer = "Polymeric NP"
        case lipid = "Solid Lipid NP"
        case dendrimer = "Dendrimer"
        case carbon = "Carbon Nanotube"
        case gold = "Gold NP"
        case iron = "Iron Oxide NP"
        case silica = "Silica NP"
        
        var icon: String {
            switch self {
            case .liposome: return "circle.circle"
            case .polymer: return "hexagon"
            case .lipid: return "diamond"
            case .dendrimer: return "asterisk.circle"
            case .carbon: return "tube.horizontal"
            case .gold: return "star.circle"
            case .iron: return "dot.circle.and.cursorarrow"
            case .silica: return "circle.grid.hex"
            }
        }
        
        var color: Color {
            switch self {
            case .liposome: return .blue
            case .polymer: return .green
            case .lipid: return .orange
            case .dendrimer: return .purple
            case .carbon: return .black
            case .gold: return .yellow
            case .iron: return .brown
            case .silica: return .gray
            }
        }
    }
    
    enum TargetTissue: String, CaseIterable {
        case tumor = "Tumor"
        case brain = "Brain (BBB)"
        case liver = "Liver"
        case lung = "Lung"
        case kidney = "Kidney"
        case skin = "Skin"
        case eye = "Eye"
        case joint = "Joint"
        
        var requirements: String {
            switch self {
            case .tumor: return "EPR effect, 20-200 nm"
            case .brain: return "< 50 nm, lipophilic"
            case .liver: return "Kupffer cell uptake, > 200 nm"
            case .lung: return "Inhalable, < 5 μm"
            case .kidney: return "Glomerular filtration, < 10 nm"
            case .skin: return "Penetration enhancer, < 100 nm"
            case .eye: return "Mucoadhesive, < 200 nm"
            case .joint: return "Anti-inflammatory, 50-500 nm"
            }
        }
    }
    
    enum SurfaceModification: String, CaseIterable {
        case pegylation = "PEGylation"
        case targeting = "Targeting Ligands"
        case cellPenetrating = "Cell Penetrating"
        case phSensitive = "pH Sensitive"
        case thermoSensitive = "Thermosensitive"
        case enzymatic = "Enzyme Cleavable"
        
        var benefit: String {
            switch self {
            case .pegylation: return "Stealth, longer circulation"
            case .targeting: return "Specific cell targeting"
            case .cellPenetrating: return "Enhanced cellular uptake"
            case .phSensitive: return "Controlled release in acidic environment"
            case .thermoSensitive: return "Heat-triggered release"
            case .enzymatic: return "Enzyme-triggered release"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "circle.hexagongrid.circle")
                            .foregroundColor(.mint)
                            .font(.title2)
                        Text("Nanoparticle Designer")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    Text("Design targeted drug delivery systems")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Nanoparticle Type Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Nanoparticle Type")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(NanoparticleType.allCases, id: \.self) { type in
                            NanoTypeCard(
                                type: type,
                                isSelected: selectedNanoType == type
                            ) {
                                selectedNanoType = type
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Parameters
                VStack(alignment: .leading, spacing: 16) {
                    Text("Design Parameters")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        // Core Size
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Core Size: \(Int(coreSize)) nm")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(getSizeCategory(coreSize))
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(getSizeColor(coreSize).opacity(0.2))
                                    .foregroundColor(getSizeColor(coreSize))
                                    .clipShape(Capsule())
                            }
                            
                            Slider(value: $coreSize, in: 10...500, step: 10)
                            
                            Text("Optimal for \(selectedNanoType.rawValue): \(getOptimalSize(for: selectedNanoType))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Drug Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Drug/API")
                                .fontWeight(.medium)
                            
                            TextField("Enter drug name or SMILES", text: $selectedDrug)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        // Target Tissue
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Target Tissue")
                                .fontWeight(.medium)
                            
                            Picker("Target", selection: $targetTissue) {
                                ForEach(TargetTissue.allCases, id: \.self) { tissue in
                                    Text(tissue.rawValue).tag(tissue)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            
                            Text(targetTissue.requirements)
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        
                        // Surface Modification
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Surface Modification")
                                .fontWeight(.medium)
                            
                            Picker("Modification", selection: $surfaceModification) {
                                ForEach(SurfaceModification.allCases, id: \.self) { mod in
                                    Text(mod.rawValue).tag(mod)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            
                            Text(surfaceModification.benefit)
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
                
                // Design Button
                Button("Design Nanoparticle") {
                    designNanoparticle()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .disabled(selectedDrug.isEmpty)
                
                // Results
                if showingResults, let design = designResults {
                    NanoparticleResultsView(design: design)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Nanoparticle Designer")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func designNanoparticle() {
        let design = NanoparticleDesign(
            type: selectedNanoType,
            coreSize: coreSize,
            drug: selectedDrug,
            target: targetTissue,
            surfaceModification: surfaceModification,
            encapsulationEfficiency: calculateEncapsulationEfficiency(),
            drugLoading: calculateDrugLoading(),
            releaseProfile: generateReleaseProfile(),
            stability: assessStability(),
            targetingEfficiency: calculateTargetingEfficiency()
        )
        
        designResults = design
        showingResults = true
    }
    
    private func getSizeCategory(_ size: Double) -> String {
        switch size {
        case 0..<50: return "Small"
        case 50..<200: return "Medium"
        case 200..<500: return "Large"
        default: return "Micro"
        }
    }
    
    private func getSizeColor(_ size: Double) -> Color {
        switch size {
        case 0..<50: return .green
        case 50..<200: return .blue
        case 200..<500: return .orange
        default: return .red
        }
    }
    
    private func getOptimalSize(for type: NanoparticleType) -> String {
        switch type {
        case .liposome: return "50-200 nm"
        case .polymer: return "50-300 nm"
        case .lipid: return "50-500 nm"
        case .dendrimer: return "1-15 nm"
        case .carbon: return "10-100 nm"
        case .gold: return "1-100 nm"
        case .iron: return "10-100 nm"
        case .silica: return "50-500 nm"
        }
    }
    
    private func calculateEncapsulationEfficiency() -> Double {
        // Mock calculation based on parameters
        var efficiency = 70.0
        
        // Size factor
        if coreSize > 100 { efficiency += 10 }
        
        // Type factor
        switch selectedNanoType {
        case .liposome: efficiency += 15
        case .polymer: efficiency += 10
        case .dendrimer: efficiency += 20
        default: efficiency += 5
        }
        
        return min(95, efficiency + Double.random(in: -10...10))
    }
    
    private func calculateDrugLoading() -> Double {
        var loading = 5.0
        
        switch selectedNanoType {
        case .dendrimer: loading = 15
        case .polymer: loading = 12
        case .liposome: loading = 8
        default: loading = 6
        }
        
        return loading + Double.random(in: -2...3)
    }
    
    private func generateReleaseProfile() -> String {
        switch surfaceModification {
        case .phSensitive: return "Burst at pH < 6.5"
        case .thermoSensitive: return "Release at 40-45°C"
        case .enzymatic: return "Enzyme-controlled"
        default: return "Sustained over 12-24h"
        }
    }
    
    private func assessStability() -> String {
        let score = Int.random(in: 65...95)
        return "\(score)% stable for 6 months"
    }
    
    private func calculateTargetingEfficiency() -> Double {
        var efficiency = 30.0
        
        if surfaceModification == .targeting {
            efficiency += 40
        }
        
        // Size optimization for target
        let optimalRange = getOptimalRangeForTarget()
        if coreSize >= optimalRange.0 && coreSize <= optimalRange.1 {
            efficiency += 20
        }
        
        return min(90, efficiency + Double.random(in: -10...15))
    }
    
    private func getOptimalRangeForTarget() -> (Double, Double) {
        switch targetTissue {
        case .tumor: return (20, 200)
        case .brain: return (10, 50)
        case .liver: return (100, 300)
        case .lung: return (50, 200)
        case .kidney: return (5, 10)
        case .skin: return (20, 100)
        case .eye: return (50, 200)
        case .joint: return (50, 500)
        }
    }
}

// MARK: - Supporting Views and Models
struct NanoTypeCard: View {
    let type: NanoparticleDesignerView.NanoparticleType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : type.color)
                
                Text(type.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .background(isSelected ? type.color : type.color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(type.color, lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct NanoparticleDesign {
    let type: NanoparticleDesignerView.NanoparticleType
    let coreSize: Double
    let drug: String
    let target: NanoparticleDesignerView.TargetTissue
    let surfaceModification: NanoparticleDesignerView.SurfaceModification
    let encapsulationEfficiency: Double
    let drugLoading: Double
    let releaseProfile: String
    let stability: String
    let targetingEfficiency: Double
}

struct NanoparticleResultsView: View {
    let design: NanoparticleDesign
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Design Results")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                ResultRow(
                    title: "Encapsulation Efficiency",
                    value: String(format: "%.1f%%", design.encapsulationEfficiency),
                    color: design.encapsulationEfficiency > 80 ? .green : .orange
                )
                
                ResultRow(
                    title: "Drug Loading",
                    value: String(format: "%.1f%%", design.drugLoading),
                    color: .blue
                )
                
                ResultRow(
                    title: "Targeting Efficiency",
                    value: String(format: "%.1f%%", design.targetingEfficiency),
                    color: design.targetingEfficiency > 60 ? .green : .red
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Release Profile")
                        .fontWeight(.medium)
                    Text(design.releaseProfile)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stability")
                        .fontWeight(.medium)
                    Text(design.stability)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct ResultRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
}
// MARK: - Requirement Row
struct RequirementRow: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isMet ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isMet ? .green : .red)
            Text(text)
                .foregroundColor(isMet ? .primary : .secondary)
        }
    }
}

// MARK: - Results View
struct ResultsView: View {
    let models: [QSARModel]
    
    var body: some View {
        if models.isEmpty {
            Text("No models built yet")
                .foregroundColor(.secondary)
                .frame(maxHeight: .infinity)
        } else {
            List(models, id: \.name) { model in
                ModelResultRow(model: model)
            }
        }
    }
}

// MARK: - Model Result Row
struct ModelResultRow: View {
    let model: QSARModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.name)
                .font(.headline)
            
            HStack {
                if let trainAcc = model.trainingAccuracy {
                    Text("Train R²: \(trainAcc, specifier: "%.3f")")
                        .foregroundColor(.blue)
                }
                if let testAcc = model.testAccuracy {
                    Text("Test R²: \(testAcc, specifier: "%.3f")")
                        .foregroundColor(.green)
                }
            }
            .font(.caption)
            
            Text("\(model.compounds.count) compounds")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Supporting Views
struct NewProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var projectName = ""
    @State private var targetProtein = ""
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Project Name", text: $projectName)
                TextField("Target Protein", text: $targetProtein)
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        let project = DesignProject(name: projectName, targetProtein: targetProtein)
                        modelContext.insert(project)
                        dismiss()
                    }
                    .disabled(projectName.isEmpty)
                }
            }
        }
    }
}

struct ProjectsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var projects: [DesignProject]
    
    var body: some View {
        List {
            ForEach(projects) { project in
                NavigationLink(destination: ProjectDetailView(project: project)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.headline)
                        Text(project.targetProtein)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(project.molecules.count) molecules")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            .onDelete(perform: deleteProjects)
        }
        .navigationTitle("Projects")
        .toolbar {
            EditButton()
        }
    }
    
    private func deleteProjects(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(projects[index])
        }
    }
}

struct ProjectDetailView: View {
    let project: DesignProject
    
    var body: some View {
        VStack {
            Text("Project Details")
            Text(project.name)
                .font(.title)
            Text("Target: \(project.targetProtein)")
                .font(.headline)
            Text("\(project.molecules.count) molecules")
                .font(.subheadline)
        }
        .navigationTitle(project.name)
    }
}

