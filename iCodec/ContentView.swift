import SwiftUI
import CoreData

struct ContentView: View {
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var themeManager = ThemeManager()
    @State private var showBootScreen = true
    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            if showBootScreen {
                BootScreen()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation(.easeInOut(duration: 1)) {
                                showBootScreen = false
                            }
                        }
                    }
            } else {
                mainInterface
            }
        }
        .environmentObject(coordinator)
        .environmentObject(themeManager)
        .preferredColorScheme(.dark)
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }

    private var mainInterface: some View {
        ZStack {
            // Background
            themeManager.backgroundColor
                .ignoresSafeArea()

            // Scanlines overlay
            ScanlineOverlay()
                .opacity(0.15)

            // Main content
            VStack(spacing: 16) {
                // Header
                header

                // Navigation
                navigationMenu

                // Content area
                contentArea

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            // Status bar with time
            HStack {
                Text(DateFormatter.timeFormatter.string(from: currentTime))
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(themeManager.primaryColor)
                    .fontWeight(.bold)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(themeManager.successColor)
                        .frame(width: 6, height: 6)

                    Text("ONLINE")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(themeManager.successColor)
                }
            }

            // App title
            Text("iCODEC")
                .font(.system(size: 24, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(themeManager.primaryColor)
                .textCase(.uppercase)
                .shadow(color: themeManager.primaryColor.opacity(0.5), radius: 5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(themeManager.primaryColor.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(themeManager.primaryColor, lineWidth: 1)
        )
        .cornerRadius(8)
    }

    private var navigationMenu: some View {
        HStack(spacing: 8) {
            ForEach(AppModule.allCases, id: \.self) { module in
                NavigationItem(
                    module: module,
                    isActive: coordinator.currentModule == module
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        coordinator.currentModule = module
                    }
                }
            }
        }
        .padding(.horizontal, 8)
    }

    private var contentArea: some View {
        VStack {
            switch coordinator.currentModule {
            case .mission:
                MissionView()
            case .map:
                MapView()
            case .intel:
                IntelView()
            case .alerts:
                AlertsView()
            case .audio:
                AudioView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.3), value: coordinator.currentModule)
    }
}

struct NavigationItem: View {
    let module: AppModule
    let isActive: Bool
    let action: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // Icon/Glyph
                Text(module.glyph)
                    .font(.system(size: 12, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(isActive ? themeManager.backgroundColor : themeManager.primaryColor)
                    .frame(width: 32, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isActive ? themeManager.primaryColor : Color.clear)
                    )

                // Label
                Text(module.rawValue)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(isActive ? themeManager.accentColor : themeManager.textColor)
                    .fontWeight(isActive ? .bold : .regular)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? themeManager.primaryColor.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isActive ? themeManager.primaryColor : themeManager.primaryColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct BootScreen: View {
    @State private var loadingProgress: CGFloat = 0
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                // Logo
                VStack(spacing: 16) {
                    // Diamond logo placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeManager.primaryColor, lineWidth: 2)
                            .frame(width: 60, height: 60)

                        Text("◆")
                            .font(.system(size: 32))
                            .foregroundColor(themeManager.primaryColor)
                    }

                    Text("iCODEC")
                        .font(.system(size: 28, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.primaryColor)
                        .shadow(color: themeManager.primaryColor.opacity(0.5), radius: 10)
                }

                // Loading section
                VStack(spacing: 16) {
                    // Loading bar
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(themeManager.primaryColor, lineWidth: 1)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(themeManager.primaryColor)
                            .frame(width: 200 * loadingProgress, height: 8)
                    }
                    .frame(width: 200)

                    Text("Initializing tactical interface...")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(themeManager.textColor.opacity(0.8))
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.5)) {
                    loadingProgress = 1.0
                }
            }
        }
    }
}

extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}