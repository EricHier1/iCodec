import SwiftUI

struct IntelView: View {
    @ObservedObject private var viewModel = SharedDataManager.shared.intelViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var selectedIntel: IntelEntry?

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
                            .onTapGesture {
                                selectedIntel = entry
                            }
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
        .fullScreenCover(item: $selectedIntel) { intel in
            IntelDetailView(intel: intel)
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
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Compact header
                HStack {
                    CodecButton(title: "CANCEL", action: {
                        dismiss()
                    }, style: .secondary, size: .small)

                    Spacer()

                    Text("NEW INTEL ENTRY")
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(themeManager.primaryColor)
                        .fontWeight(.bold)

                    Spacer()

                    CodecButton(title: "SAVE", action: {
                        viewModel.createIntelEntry(
                            title: title,
                            content: content,
                            classification: classification
                        )
                        dismiss()
                    }, style: .primary, size: .small)
                }
                .padding(16)
                .background(themeManager.surfaceColor.opacity(0.1))
                .overlay(
                    Rectangle()
                        .fill(themeManager.primaryColor.opacity(0.3))
                        .frame(height: 1),
                    alignment: .bottom
                )

                // Full screen content area
                VStack(spacing: 16) {
                    // Title input
                    VStack(alignment: .leading, spacing: 4) {
                        Text("REPORT TITLE")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(themeManager.textColor.opacity(0.7))
                            .fontWeight(.bold)

                        TextField("Enter intel report title...", text: $title)
                            .textFieldStyle(CodecTextFieldStyle())
                    }

                    // Classification picker
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CLASSIFICATION LEVEL")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(themeManager.textColor.opacity(0.7))
                            .fontWeight(.bold)

                        Picker("Classification", selection: $classification) {
                            ForEach(Classification.allCases, id: \.self) { level in
                                Text(level.rawValue.uppercased())
                                    .tag(level)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }

                    // Main intel content area (takes most of the screen)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("INTELLIGENCE REPORT")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(themeManager.textColor.opacity(0.7))
                            .fontWeight(.bold)

                        TextField("Enter detailed intelligence report...\n\nInclude all relevant information:\n• Personnel observations\n• Equipment details\n• Tactical assessments\n• Threat analysis\n• Recommendations", text: $content, axis: .vertical)
                            .textFieldStyle(CodecTextFieldStyle())
                            .lineLimit(15...50)
                            .frame(minHeight: geometry.size.height * 0.6)
                    }

                    Spacer(minLength: 0)
                }
                .padding(16)
            }
            .background(themeManager.backgroundColor)
            .navigationBarHidden(true)
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
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Compact header
                HStack {
                    CodecButton(title: "CANCEL", action: {
                        dismiss()
                    }, style: .secondary, size: .small)

                    Spacer()

                    Text("EDIT INTEL ENTRY")
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(themeManager.primaryColor)
                        .fontWeight(.bold)

                    Spacer()

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
                    }, style: .primary, size: .small)
                }
                .padding(16)
                .background(themeManager.surfaceColor.opacity(0.1))
                .overlay(
                    Rectangle()
                        .fill(themeManager.primaryColor.opacity(0.3))
                        .frame(height: 1),
                    alignment: .bottom
                )

                // Full screen content area
                VStack(spacing: 16) {
                    // Title input
                    VStack(alignment: .leading, spacing: 4) {
                        Text("REPORT TITLE")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(themeManager.textColor.opacity(0.7))
                            .fontWeight(.bold)

                        TextField("Enter intel report title...", text: $title)
                            .textFieldStyle(CodecTextFieldStyle())
                    }

                    // Classification picker
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CLASSIFICATION LEVEL")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(themeManager.textColor.opacity(0.7))
                            .fontWeight(.bold)

                        Picker("Classification", selection: $classification) {
                            ForEach(Classification.allCases, id: \.self) { level in
                                Text(level.rawValue.uppercased())
                                    .tag(level)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }

                    // Main intel content area (takes most of the screen)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("INTELLIGENCE REPORT")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(themeManager.textColor.opacity(0.7))
                            .fontWeight(.bold)

                        TextField("Enter detailed intelligence report...\n\nInclude all relevant information:\n• Personnel observations\n• Equipment details\n• Tactical assessments\n• Threat analysis\n• Recommendations", text: $content, axis: .vertical)
                            .textFieldStyle(CodecTextFieldStyle())
                            .lineLimit(15...50)
                            .frame(minHeight: geometry.size.height * 0.6)
                    }

                    Spacer(minLength: 0)
                }
                .padding(16)
            }
            .background(themeManager.backgroundColor)
            .navigationBarHidden(true)
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

struct IntelDetailView: View {
    let intel: IntelEntry
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                CodecButton(title: "BACK", action: {
                    dismiss()
                }, style: .secondary, size: .medium)

                Spacer()

                Text("INTEL REPORT")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(themeManager.primaryColor)
                    .fontWeight(.bold)

                Spacer()

                classificationBadge
            }
            .padding(16)
            .background(themeManager.surfaceColor.opacity(0.1))
            .overlay(
                Rectangle()
                    .fill(themeManager.primaryColor.opacity(0.3))
                    .frame(height: 1),
                alignment: .bottom
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title and metadata
                    VStack(alignment: .leading, spacing: 8) {
                        Text(intel.title)
                            .font(.system(size: 24, design: .monospaced))
                            .foregroundColor(themeManager.primaryColor)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.leading)

                        HStack {
                            Text("TIMESTAMP:")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(themeManager.textColor.opacity(0.7))
                                .fontWeight(.bold)

                            Text(intel.timestamp, style: .date)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(themeManager.textColor.opacity(0.7))

                            Spacer()

                            Text("TIME:")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(themeManager.textColor.opacity(0.7))
                                .fontWeight(.bold)

                            Text(intel.timestamp, style: .time)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(themeManager.textColor.opacity(0.7))
                        }
                    }

                    // Divider
                    Rectangle()
                        .fill(themeManager.primaryColor.opacity(0.3))
                        .frame(height: 1)

                    // Content
                    VStack(alignment: .leading, spacing: 12) {
                        Text("INTELLIGENCE BRIEFING")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(themeManager.accentColor)
                            .fontWeight(.bold)

                        Text(intel.content)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(themeManager.textColor)
                            .lineSpacing(4)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 100)
                }
                .padding(20)
            }
        }
        .background(themeManager.backgroundColor)
        .navigationBarHidden(true)
    }

    private var classificationBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(intel.classification.color)
                .frame(width: 6, height: 6)

            Text(intel.classification.rawValue.uppercased())
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(intel.classification.color)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(intel.classification.color.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(intel.classification.color, lineWidth: 1)
        )
        .cornerRadius(4)
    }
}