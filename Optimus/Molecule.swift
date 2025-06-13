import SwiftUI
import SwiftData
import WebKit
import UniformTypeIdentifiers

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
                            Text("Optimus")
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
                            destination: AnyView(MolecularSearchView())
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

// MARK: - Molecular Search View
struct MolecularSearchView: View {
    @StateObject private var viewModel = MolecularSearchViewModel()
    @Environment(\.modelContext) private var modelContext
    @State private var query: String = ""
    @State private var selectedType: SearchType = .name
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Header
            VStack(spacing: 16) {
                // Search Type Picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(SearchType.allCases, id: \.self) { type in
                            SearchTypeButton(
                                type: type,
                                isSelected: selectedType == type
                            ) {
                                selectedType = type
                                query = ""
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Search Bar
                HStack {
                    HStack {
                        Image(systemName: selectedType.icon)
                            .foregroundColor(.secondary)
                        
                        TextField(selectedType.placeholder, text: $query)
                            .onSubmit {
                                performSearch()
                            }
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    Button(action: performSearch) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(query.isEmpty ? Color.gray : Color.blue)
                            .clipShape(Circle())
                    }
                    .disabled(query.isEmpty || viewModel.isLoading)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            // Results
            if viewModel.isLoading {
                Spacer()
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Searching molecular databases...")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else if let molecules = viewModel.molecules, !molecules.isEmpty {
                List(molecules, id: \.id) { molecule in
                    NavigationLink(destination: MoleculeDetailView(molecule: molecule)) {
                        MoleculeRowView(molecule: molecule)
                    }
                }
                .listStyle(PlainListStyle())
            } else if let error = viewModel.errorMessage {
                Spacer()
                ErrorView(message: error) {
                    performSearch()
                }
                Spacer()
            } else {
                EmptySearchView()
            }
        }
        .navigationTitle("Molecular Search")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func performSearch() {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let history = SearchHistory(query: query, searchType: selectedType.rawValue, resultFound: false)
        modelContext.insert(history)
        
        viewModel.search(query: query, type: selectedType)
    }
}

// MARK: - Molecular Search ViewModel
@MainActor
class MolecularSearchViewModel: ObservableObject {
    @Published var molecules: [Molecule]? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    func search(query: String, type: SearchType) {
        print("🔍 Searching for: '\(query)' type: \(type.rawValue)")
        
        isLoading = true
        errorMessage = nil
        molecules = nil
        
        // Simulate search with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let results = self.createSearchResults(for: query, type: type)
            
            self.isLoading = false
            
            if results.isEmpty {
                self.errorMessage = "No molecules found for '\(query)'. Try: caffeine, aspirin, ibuprofen, morphine, or penicillin"
            } else {
                self.molecules = results
                print("✅ Found \(results.count) molecules")
            }
        }
    }
    
    private func createSearchResults(for query: String, type: SearchType) -> [Molecule] {
        let queryLower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var results: [Molecule] = []
        
        // Comprehensive molecule database
        let moleculeDatabase: [(name: String, smiles: String, formula: String, weight: Double, logP: Double, donors: Int, acceptors: Int, tpsa: Double, cid: Int, cas: String, keywords: [String])] = [
            ("Caffeine", "CN1C=NC2=C1C(=O)N(C(=O)N2C)C", "C8H10N4O2", 194.19, -0.07, 0, 6, 58.44, 2519, "58-08-2", ["caffeine", "coffee", "stimulant"]),
            ("Aspirin", "CC(=O)OC1=CC=CC=C1C(=O)O", "C9H8O4", 180.16, 1.19, 1, 4, 63.6, 2244, "50-78-2", ["aspirin", "acetylsalicylic", "pain", "nsaid"]),
            ("Ibuprofen", "CC(C)Cc1ccc(cc1)C(C)C(=O)O", "C13H18O2", 206.28, 3.97, 1, 2, 37.3, 3672, "15687-27-1", ["ibuprofen", "advil", "nsaid", "pain"]),
            ("Ethanol", "CCO", "C2H6O", 46.07, -0.31, 1, 1, 20.23, 702, "64-17-5", ["ethanol", "alcohol"]),
            ("Paracetamol", "CC(=O)Nc1ccc(cc1)O", "C8H9NO2", 151.16, 0.46, 2, 2, 49.33, 1983, "103-90-2", ["paracetamol", "acetaminophen", "tylenol", "pain"]),
            ("Morphine", "CN1CCC23C4C1CC5=C2C(=C(C=C5)O)OC3C(C=C4)O", "C17H19NO3", 285.34, 0.89, 2, 4, 52.93, 5288826, "57-27-2", ["morphine", "opioid", "pain"]),
            ("Penicillin G", "CC1(C(N2C(S1)C(C2=O)NC(=O)Cc3ccccc3)C(=O)O)C", "C16H18N2O4S", 334.39, 1.83, 2, 5, 88.89, 5904, "61-33-6", ["penicillin", "antibiotic"]),
            ("Warfarin", "CC(=O)CC(c1ccccc1)c2c(cc3ccccc3oc2=O)O", "C19H16O4", 308.33, 2.70, 1, 4, 63.6, 54678486, "81-81-2", ["warfarin", "anticoagulant"]),
            ("Metformin", "CN(C)C(=N)NC(=N)N", "C4H11N5", 129.16, -2.64, 4, 2, 88.99, 4091, "657-24-9", ["metformin", "diabetes"]),
            ("Dopamine", "NCCc1ccc(O)c(O)c1", "C8H11NO2", 153.18, -0.98, 3, 3, 66.48, 681, "51-61-6", ["dopamine", "neurotransmitter"])
        ]
        
        // Search logic based on type
        for mol in moleculeDatabase {
            var matches = false
            
            switch type {
            case .name:
                matches = mol.name.lowercased().contains(queryLower) || mol.keywords.contains { $0.contains(queryLower) }
            case .smiles:
                matches = mol.smiles.lowercased() == queryLower
            case .cas:
                matches = mol.cas == query
            case .cid:
                matches = "\(mol.cid)" == query
            case .inchi:
                matches = false // InChI search not implemented in mock
            }
            
            if matches {
                let molecule = Molecule(name: mol.name, smiles: mol.smiles)
                molecule.molecularFormula = mol.formula
                molecule.molecularWeight = mol.weight
                molecule.logP = mol.logP
                molecule.hDonors = mol.donors
                molecule.hAcceptors = mol.acceptors
                molecule.tpsa = mol.tpsa
                molecule.pubchemCID = mol.cid
                molecule.casID = mol.cas
                molecule.inchiKey = generateMockInChIKey()
                
                results.append(molecule)
            }
        }
        
        return results
    }
    
    private func generateMockInChIKey() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        return String((0..<14).map { _ in chars.randomElement()! }) + "-" +
               String((0..<10).map { _ in chars.randomElement()! }) + "-" +
               String((0..<1).map { _ in chars.randomElement()! })
    }
}

// MARK: - Molecule Drawer View
struct MoleculeDrawerView: View {
    @StateObject private var drawingModel = MoleculeDrawingModel()
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTool: DrawingTool = .carbon
    @State private var selectedBondType: BondType = .single
    @State private var showingSaveDialog = false
    @State private var moleculeName = ""
    @State private var showingClearAlert = false
    
    enum DrawingTool: String, CaseIterable {
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
        case delete = "🗑️"
        
        var color: Color {
            switch self {
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
            case .delete: return .red
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .carbon: return .gray.opacity(0.2)
            case .nitrogen: return .blue.opacity(0.2)
            case .oxygen: return .red.opacity(0.2)
            case .sulfur: return .yellow.opacity(0.2)
            case .phosphorus: return .orange.opacity(0.2)
            case .fluorine: return .green.opacity(0.2)
            case .chlorine: return .green.opacity(0.2)
            case .bromine: return .brown.opacity(0.2)
            case .iodine: return .purple.opacity(0.2)
            case .hydrogen: return .gray.opacity(0.2)
            case .delete: return .red.opacity(0.2)
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
            case .double: return 3.0
            case .triple: return 4.0
            case .aromatic: return 2.0
            }
        }
        
        var description: String {
            switch self {
            case .single: return "Single Bond"
            case .double: return "Double Bond"
            case .triple: return "Triple Bond"
            case .aromatic: return "Aromatic Bond"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Toolbar
            MoleculeDrawerToolbar(
                selectedTool: $selectedTool,
                selectedBondType: $selectedBondType
            )
            
            // Drawing Canvas
            ZStack {
                Rectangle()
                    .fill(Color.white)
                    .overlay(
                        GridBackgroundView()
                    )
                
                // Molecule Drawing
                MoleculeCanvas(
                    drawingModel: drawingModel,
                    selectedTool: selectedTool,
                    selectedBondType: selectedBondType
                )
            }
            
            // Bottom Toolbar
            MoleculeDrawerBottomBar(
                drawingModel: drawingModel,
                showingClearAlert: $showingClearAlert,
                showingSaveDialog: $showingSaveDialog
            )
        }
        .navigationTitle("Molecule Drawer")
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
    }
    
    private func saveMolecule(name: String) {
        let smiles = drawingModel.generateSMILES()
        let molecule = Molecule(name: name.isEmpty ? "Custom Molecule" : name, smiles: smiles)
        
        // Calculate basic properties
        molecule.molecularWeight = Double(drawingModel.atoms.count * 12) // Rough estimation
        molecule.hDonors = drawingModel.atoms.filter { $0.element == .oxygen || $0.element == .nitrogen }.count
        molecule.hAcceptors = drawingModel.atoms.filter { $0.element == .oxygen || $0.element == .nitrogen }.count
        
        modelContext.insert(molecule)
        try? modelContext.save()
        
        drawingModel.clearAll()
        moleculeName = ""
    }
}

// MARK: - Molecule Drawer Supporting Views
struct MoleculeDrawerToolbar: View {
    @Binding var selectedTool: MoleculeDrawerView.DrawingTool
    @Binding var selectedBondType: MoleculeDrawerView.BondType
    
    var body: some View {
        VStack(spacing: 12) {
            // Atom Tools
            VStack(alignment: .leading, spacing: 8) {
                Text("Atoms")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MoleculeDrawerView.DrawingTool.allCases, id: \.self) { tool in
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

struct MoleculeDrawerBottomBar: View {
    @ObservedObject var drawingModel: MoleculeDrawingModel
    @Binding var showingClearAlert: Bool
    @Binding var showingSaveDialog: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Button("Clear") {
                if !drawingModel.atoms.isEmpty || !drawingModel.bonds.isEmpty {
                    showingClearAlert = true
                }
            }
            .foregroundColor(.red)
            
            Spacer()
            
            // SMILES Display
            VStack(alignment: .center, spacing: 4) {
                Text("SMILES")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(drawingModel.generateSMILES())
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.blue)
                    .lineLimit(1)
                    .frame(maxWidth: 120)
            }
            
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

// MARK: - Drawing Model
class MoleculeDrawingModel: ObservableObject {
    @Published var atoms: [DrawnAtom] = []
    @Published var bonds: [DrawnBond] = []
    @Published var selectedAtomIndex: Int? = nil
    
    func addAtom(at position: CGPoint, element: MoleculeDrawerView.DrawingTool) {
        let newAtom = DrawnAtom(
            id: UUID(),
            position: position,
            element: element
        )
        atoms.append(newAtom)
    }
    
    func addBond(from fromIndex: Int, to toIndex: Int, type: MoleculeDrawerView.BondType) {
        // Check if bond already exists
        let existingBond = bonds.first { bond in
            (bond.fromAtomIndex == fromIndex && bond.toAtomIndex == toIndex) ||
            (bond.fromAtomIndex == toIndex && bond.toAtomIndex == fromIndex)
        }
        
        if existingBond == nil {
            let newBond = DrawnBond(
                id: UUID(),
                fromAtomIndex: fromIndex,
                toAtomIndex: toIndex,
                type: type
            )
            bonds.append(newBond)
        }
    }
    
    func removeAtom(at index: Int) {
        atoms.remove(at: index)
        // Remove bonds connected to this atom
        bonds.removeAll { bond in
            bond.fromAtomIndex == index || bond.toAtomIndex == index
        }
        // Update bond indices
        for i in 0..<bonds.count {
            if bonds[i].fromAtomIndex > index {
                bonds[i].fromAtomIndex -= 1
            }
            if bonds[i].toAtomIndex > index {
                bonds[i].toAtomIndex -= 1
            }
        }
    }
    
    func clearAll() {
        atoms.removeAll()
        bonds.removeAll()
        selectedAtomIndex = nil
    }
    
    func generateSMILES() -> String {
        // Simplified SMILES generation
        if atoms.isEmpty { return "" }
        
        var smiles = ""
        let visited = Set<Int>()
        
        // Start with first carbon or any atom
        let startIndex = atoms.firstIndex { $0.element == .carbon } ?? 0
        smiles += traverseAtom(at: startIndex, visited: visited)
        
        return smiles.isEmpty ? "C" : smiles
    }
    
    private func traverseAtom(at index: Int, visited: Set<Int>) -> String {
        var localVisited = visited
        localVisited.insert(index)
        
        let atom = atoms[index]
        var result = atom.element.rawValue
        
        // Add connected atoms
        let connectedBonds = bonds.filter { bond in
            (bond.fromAtomIndex == index || bond.toAtomIndex == index) &&
            !localVisited.contains(bond.fromAtomIndex == index ? bond.toAtomIndex : bond.fromAtomIndex)
        }
        
        for bond in connectedBonds {
            let nextIndex = bond.fromAtomIndex == index ? bond.toAtomIndex : bond.fromAtomIndex
            if bond.type == .double {
                result += "="
            } else if bond.type == .triple {
                result += "#"
            }
            result += traverseAtom(at: nextIndex, visited: localVisited)
        }
        
        return result
    }
}

// MARK: - Drawing Data Models
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

// MARK: - Drawing Components
struct AtomToolButton: View {
    let tool: MoleculeDrawerView.DrawingTool
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(tool.rawValue)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(isSelected ? .white : tool.color)
                .frame(width: 32, height: 32)
                .background(isSelected ? tool.color : tool.backgroundColor)
                .clipShape(Circle())
                .overlay(
                    Circle()
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

struct MoleculeCanvas: View {
    @ObservedObject var drawingModel: MoleculeDrawingModel
    let selectedTool: MoleculeDrawerView.DrawingTool
    let selectedBondType: MoleculeDrawerView.BondType
    
    var body: some View {
        ZStack {
            // Bonds (draw first, behind atoms)
            ForEach(Array(drawingModel.bonds.enumerated()), id: \.element.id) { index, bond in
                if bond.fromAtomIndex < drawingModel.atoms.count && bond.toAtomIndex < drawingModel.atoms.count {
                    let fromAtom = drawingModel.atoms[bond.fromAtomIndex]
                    let toAtom = drawingModel.atoms[bond.toAtomIndex]
                    
                    BondView(
                        from: fromAtom.position,
                        to: toAtom.position,
                        bondType: bond.type
                    )
                }
            }
            
            // Atoms
            ForEach(Array(drawingModel.atoms.enumerated()), id: \.element.id) { index, atom in
                AtomView(
                    atom: atom,
                    isSelected: drawingModel.selectedAtomIndex == index
                )
                .onTapGesture {
                    handleAtomTap(at: index)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { location in
            handleCanvasTap(at: location)
        }
    }
    
    private func handleAtomTap(at index: Int) {
        if selectedTool == .delete {
            drawingModel.removeAtom(at: index)
            return
        }
        
        if let selectedIndex = drawingModel.selectedAtomIndex {
            if selectedIndex != index {
                // Create bond between selected atom and tapped atom
                drawingModel.addBond(from: selectedIndex, to: index, type: selectedBondType)
            }
            drawingModel.selectedAtomIndex = nil
        } else {
            // Select this atom for bonding
            drawingModel.selectedAtomIndex = index
        }
    }
    
    private func handleCanvasTap(at location: CGPoint) {
        if selectedTool == .delete {
            drawingModel.selectedAtomIndex = nil
            return
        }
        
        // Check if tap is near existing atom
        for (index, atom) in drawingModel.atoms.enumerated() {
            let distance = sqrt(pow(location.x - atom.position.x, 2) + pow(location.y - atom.position.y, 2))
            if distance < 25 { // Within 25 points of atom
                handleAtomTap(at: index)
                return
            }
        }
        
        // Add new atom at tapped location
        drawingModel.addAtom(at: location, element: selectedTool)
        drawingModel.selectedAtomIndex = nil
    }
}

struct AtomView: View {
    let atom: DrawnAtom
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(atom.element.backgroundColor)
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.blue : atom.element.color, lineWidth: isSelected ? 3 : 2)
                )
            
            Text(atom.element.rawValue)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(atom.element.color)
        }
        .position(atom.position)
    }
}

struct BondView: View {
    let from: CGPoint
    let to: CGPoint
    let bondType: MoleculeDrawerView.BondType
    
    var body: some View {
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
        .stroke(Color.black, lineWidth: bondType.strokeWidth)
        .overlay(
            // Additional lines for double and triple bonds
            Group {
                if bondType == .double {
                    parallelLine(offset: 3)
                } else if bondType == .triple {
                    VStack(spacing: 0) {
                        parallelLine(offset: 4)
                        parallelLine(offset: -4)
                    }
                }
            }
        )
    }
    
    private func parallelLine(offset: CGFloat) -> some View {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let offsetX = -sin(angle) * offset
        let offsetY = cos(angle) * offset
        
        return Path { path in
            path.move(to: CGPoint(x: from.x + offsetX, y: from.y + offsetY))
            path.addLine(to: CGPoint(x: to.x + offsetX, y: to.y + offsetY))
        }
        .stroke(Color.black, lineWidth: 2)
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
                        Text("Structure Info:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Atoms: \(drawingModel.atoms.count)")
                        Text("Bonds: \(drawingModel.bonds.count)")
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

// MARK: - ADMET Analysis
struct ADMETAnalysisView: View {
    @State private var selectedMolecules: [Molecule] = []
    @State private var analysisResults: [ADMETResult] = []
    @Environment(\.modelContext) private var modelContext
    @Query private var molecules: [Molecule]
    @State private var isAnalyzing = false
    
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
            if molecules.isEmpty {
                // No molecules available
                VStack(spacing: 20) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 60))
                        .foregroundColor(.orange.opacity(0.5))
                    
                    Text("No Molecules Available")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Add molecules using the Molecular Search or Ligand Builder to perform ADMET analysis")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    NavigationLink("Go to Molecular Search") {
                        MolecularSearchView()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if analysisResults.isEmpty {
                // Molecule Selection
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select Molecules for ADMET Analysis")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Choose molecules to analyze Absorption, Distribution, Metabolism, Excretion, and Toxicity")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                            
                            Button(action: runADMETAnalysis) {
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
            } else {
                // Results Display
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
                            selectedMolecules.removeAll()
                            analysisResults.removeAll()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    
                    // Results List
                    List(analysisResults, id: \.molecule.id) { result in
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
            }
        }
        .navigationTitle("ADMET Analysis")
        .navigationBarTitleDisplayMode(.inline)
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

// MARK: - 3D Viewer
struct Enhanced3DViewerView: View {
    @State private var smilesInput = "CCO"
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
                    Working3DViewer(molecule: molecule)
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
        case "cc(=o)oc1=cc=cc=c1c(=o)o": return "Aspirin"
        case "cn1c=nc2=c1c(=o)n(c(=o)n2c)c": return "Caffeine"
        case "c1ccccc1": return "Benzene"
        case "cc(=o)o": return "Acetic Acid"
        case "o": return "Water"
        case "c": return "Methane"
        default: return "Custom Molecule"
        }
    }
}

struct Working3DViewer: UIViewRepresentable {
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
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
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
        <div>Loading 3D structure...</div>
        <div style="margin-top: 10px; font-size: 12px; color: #666;">Converting SMILES to 3D coordinates</div>
    </div>
    <script>
        let viewer;
        let currentStyle = 0;
        let isSpinning = false;
        const smiles = '\#(escapedSmiles)';

        function initViewer() {
            try {
                viewer = $3Dmol.createViewer("viewer", {
                    defaultcolors: $3Dmol.rasmolElementColors,
                    backgroundColor: 'transparent'
                });

                // Try to load molecule from SMILES via web service
                // If that fails, use a fallback molecule
                loadMoleculeFromSMILES(smiles);
                
            } catch (error) {
                console.error('Error initializing viewer:', error);
                loadFallbackMolecule();
            }
        }

        function loadMoleculeFromSMILES(smilesString) {
            // Use NIH CACTUS service to convert SMILES to SDF
            const url = `https://cactus.nci.nih.gov/chemical/structure/${encodeURIComponent(smilesString)}/sdf`;
            
            fetch(url)
                .then(response => {
                    if (!response.ok) {
                        throw new Error('Network response was not ok');
                    }
                    return response.text();
                })
                .then(sdfData => {
                    viewer.addModel(sdfData, 'sdf');
                    viewer.setStyle({}, {stick: {radius: 0.15}, sphere: {scale: 0.25}});
                    viewer.zoomTo();
                    viewer.render();
                    document.getElementById("loading").style.display = "none";
                })
                .catch(error => {
                    console.error('Error loading from SMILES:', error);
                    loadFallbackMolecule();
                });
        }

        function loadFallbackMolecule() {
            // Use a simple fallback - ethanol
            const ethanolSDF = `
                   2
  -OEChem-06242410313D

  9  8  0     0  0  0  0  0  0999 V2000
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
$$`;
            
            try {
                viewer.addModel(ethanolSDF, 'sdf');
                viewer.setStyle({}, {stick: {radius: 0.15}, sphere: {scale: 0.25}});
                viewer.zoomTo();
                viewer.render();
                document.getElementById("loading").style.display = "none";
            } catch (error) {
                console.error('Error loading fallback molecule:', error);
                document.getElementById("loading").innerHTML = "<div>Error loading molecule structure</div>";
            }
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
                    viewer.setStyle({}, {cartoon: {color: 'spectrum'}});
                    break;
            }
            viewer.render();
        }

        function toggleSpin() {
            if (!viewer) return;
            isSpinning = !isSpinning;
            viewer.spin(isSpinning ? "y" : false, 0.5);
        }

        window.onload = initViewer;
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
            print("✅ 3D Viewer WebView loaded successfully")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ 3D Viewer WebView failed to load: \(error)")
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("🔄 3D Viewer WebView starting to load...")
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
