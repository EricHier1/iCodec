import SwiftUI

struct IntelView: View {
    @StateObject private var viewModel = IntelViewModel()
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("INTEL DATABASE")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(themeManager.primaryColor)
                    .fontWeight(.bold)

                Spacer()

                CodecButton(title: "NEW INTEL", action: {
                    viewModel.showNewIntelDialog = true
                }, style: .primary, size: .medium)
            }
            .padding(.horizontal, 16)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(viewModel.intelEntries) { entry in
                        IntelCard(entry: entry)
                            .contextMenu {
                                Button("Edit Intel", systemImage: "pencil") {
                                    viewModel.editIntel(entry)
                                }
                                Button("Delete Intel", systemImage: "trash", role: .destructive) {
                                    viewModel.deleteIntel(entry)
                                }
                            }
                    }

                    if viewModel.intelEntries.isEmpty {
                        VStack(spacing: 8) {
                            Text("No intel entries")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(themeManager.textColor)

                            Text("Create new intelligence reports")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(themeManager.textColor.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(32)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .background(themeManager.backgroundColor)
        .sheet(isPresented: $viewModel.showNewIntelDialog) {
            NewIntelSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showEditIntelDialog) {
            EditIntelSheet(viewModel: viewModel)
        }
    }
}

struct IntelCard: View {
    let entry: IntelEntry
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(themeManager.primaryColor)
                        .fontWeight(.bold)

                    Text(entry.timestamp, style: .date)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(themeManager.textColor.opacity(0.7))
                }

                Spacer()

                classificationBadge
            }

            // Content
            Text(isExpanded ? entry.content : String(entry.content.prefix(100) + (entry.content.count > 100 ? "..." : "")))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(themeManager.textColor.opacity(0.9))
                .lineLimit(isExpanded ? nil : 3)
                .animation(.easeInOut(duration: 0.2), value: isExpanded)

            if entry.content.count > 100 {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    Text(isExpanded ? "COLLAPSE" : "EXPAND")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(themeManager.accentColor)
                        .fontWeight(.bold)
                }
            }
        }
        .padding(12)
        .background(themeManager.surfaceColor.opacity(0.2))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(themeManager.primaryColor.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(8)
    }

    private var classificationBadge: some View {
        Text(entry.classification.rawValue.uppercased())
            .font(.system(size: 8, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(entry.classification.color.opacity(0.2))
            .foregroundColor(entry.classification.color)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(entry.classification.color, lineWidth: 1)
            )
            .cornerRadius(4)
    }
}

struct NewIntelSheet: View {
    @ObservedObject var viewModel: IntelViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var content = ""
    @State private var classification: Classification = .confidential

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("NEW INTEL ENTRY")
                    .font(.system(size: 18, design: .monospaced))
                    .foregroundColor(themeManager.primaryColor)
                    .fontWeight(.bold)

                VStack(spacing: 16) {
                    TextField("Entry title...", text: $title)
                        .textFieldStyle(CodecTextFieldStyle())

                    TextField("Intel details...", text: $content, axis: .vertical)
                        .textFieldStyle(CodecTextFieldStyle())
                        .lineLimit(6...12)

                    HStack {
                        Text("Classification:")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(themeManager.textColor)

                        Picker("Classification", selection: $classification) {
                            ForEach(Classification.allCases, id: \.self) { level in
                                Text(level.rawValue.uppercased())
                                    .tag(level)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }

                Spacer()

                HStack(spacing: 16) {
                    CodecButton(title: "CANCEL", action: {
                        dismiss()
                    }, style: .secondary, size: .fullWidth)

                    CodecButton(title: "SAVE", action: {
                        viewModel.createIntelEntry(
                            title: title,
                            content: content,
                            classification: classification
                        )
                        dismiss()
                    }, style: .primary, size: .fullWidth)
                }
            }
            .padding(20)
            .background(themeManager.backgroundColor)
        }
    }
}

@MainActor
class IntelViewModel: BaseViewModel {
    @Published var intelEntries: [IntelEntry] = []
    @Published var showNewIntelDialog = false
    @Published var showEditIntelDialog = false
    @Published var intelToEdit: IntelEntry?

    override init() {
        super.init()
        generateSampleIntel()
    }

    func createIntelEntry(title: String, content: String, classification: Classification) {
        let newEntry = IntelEntry(
            id: UUID(),
            title: title,
            content: content,
            timestamp: Date(),
            classification: classification
        )
        intelEntries.insert(newEntry, at: 0)
    }

    func editIntel(_ entry: IntelEntry) {
        intelToEdit = entry
        showEditIntelDialog = true
    }

    func updateIntel(_ entry: IntelEntry, title: String, content: String, classification: Classification) {
        if let index = intelEntries.firstIndex(where: { $0.id == entry.id }) {
            intelEntries[index] = IntelEntry(
                id: entry.id,
                title: title,
                content: content,
                timestamp: entry.timestamp,
                classification: classification
            )
        }
    }

    func deleteIntel(_ entry: IntelEntry) {
        intelEntries.removeAll { $0.id == entry.id }
    }

    private func generateSampleIntel() {
        intelEntries = [
            IntelEntry(
                id: UUID(),
                title: "Infiltration Route Analysis",
                content: "Primary access point identified through service tunnels. Security patrol rotates every 45 minutes with 3-minute gap window. Recommend approach from north entrance during shift change.",
                timestamp: Date().addingTimeInterval(-3600),
                classification: .secret
            ),
            IntelEntry(
                id: UUID(),
                title: "Guard Pattern Recognition",
                content: "Security personnel follow predictable patterns. Night shift has reduced alertness after 0200 hours.",
                timestamp: Date().addingTimeInterval(-7200),
                classification: .confidential
            )
        ]
    }
}

struct EditIntelSheet: View {
    @ObservedObject var viewModel: IntelViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var content = ""
    @State private var classification: Classification = .confidential

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("EDIT INTEL ENTRY")
                    .font(.system(size: 18, design: .monospaced))
                    .foregroundColor(themeManager.primaryColor)
                    .fontWeight(.bold)

                VStack(spacing: 16) {
                    TextField("Entry title...", text: $title)
                        .textFieldStyle(CodecTextFieldStyle())

                    TextField("Intel details...", text: $content, axis: .vertical)
                        .textFieldStyle(CodecTextFieldStyle())
                        .lineLimit(6...12)

                    HStack {
                        Text("Classification:")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(themeManager.textColor)

                        Picker("Classification", selection: $classification) {
                            ForEach(Classification.allCases, id: \.self) { level in
                                Text(level.rawValue.uppercased())
                                    .tag(level)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }

                Spacer()

                HStack(spacing: 16) {
                    CodecButton(title: "CANCEL", action: {
                        dismiss()
                    }, style: .secondary, size: .fullWidth)

                    CodecButton(title: "UPDATE", action: {
                        if let entry = viewModel.intelToEdit {
                            viewModel.updateIntel(
                                entry,
                                title: title,
                                content: content,
                                classification: classification
                            )
                        }
                        dismiss()
                    }, style: .primary, size: .fullWidth)
                }
            }
            .padding(20)
            .background(themeManager.backgroundColor)
        }
        .onAppear {
            if let entry = viewModel.intelToEdit {
                title = entry.title
                content = entry.content
                classification = entry.classification
            }
        }
    }
}

struct IntelEntry: Identifiable {
    let id: UUID
    let title: String
    let content: String
    let timestamp: Date
    let classification: Classification
}

enum Classification: String, CaseIterable {
    case unclassified = "unclassified"
    case confidential = "confidential"
    case secret = "secret"
    case topSecret = "top secret"

    var color: Color {
        switch self {
        case .unclassified: return .gray
        case .confidential: return .blue
        case .secret: return .orange
        case .topSecret: return .red
        }
    }
}