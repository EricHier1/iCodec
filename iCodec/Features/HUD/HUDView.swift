import SwiftUI
import CoreLocation
import CoreMotion

struct HUDView: View {
    @StateObject private var viewModel = HUDViewModel()
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            themeManager.backgroundColor
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    headerSection
                    radarSection
                    locationSection
                    missionSection
                    statusSection
                }
                .padding(.vertical, 20)
            }
            .overlay(
                ScanlineOverlay()
                    .opacity(0.1)
            )
        }
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }

    private var headerSection: some View {
        HUDPanel(title: "iCodec Terminal") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("CODEC LINK ESTABLISHED")
                        .font(.system(size: 14, family: .monospaced))
                        .foregroundColor(themeManager.successColor)

                    Spacer()

                    Text(DateFormatter.hudFormatter.string(from: Date()))
                        .font(.system(size: 12, family: .monospaced))
                        .foregroundColor(themeManager.textColor)
                }

                Text("Tactical Espionage Terminal Active")
                    .font(.system(size: 10, family: .monospaced))
                    .foregroundColor(themeManager.textColor.opacity(0.7))
            }
        }
    }

    private var radarSection: some View {
        HUDPanel(title: "Tactical Radar") {
            HStack {
                RadarSweep()

                VStack(alignment: .leading, spacing: 4) {
                    Text("SWEEP: ACTIVE")
                        .font(.system(size: 10, family: .monospaced))
                        .foregroundColor(themeManager.successColor)

                    Text("RANGE: 100M")
                        .font(.system(size: 10, family: .monospaced))
                        .foregroundColor(themeManager.textColor)

                    Text("CONTACTS: \(viewModel.detectedContacts)")
                        .font(.system(size: 10, family: .monospaced))
                        .foregroundColor(themeManager.accentColor)
                }

                Spacer()
            }
        }
    }

    private var locationSection: some View {
        HUDPanel(title: "Position Data") {
            VStack(alignment: .leading, spacing: 8) {
                if let location = viewModel.currentLocation {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("LAT: \(String(format: "%.6f", location.coordinate.latitude))")
                                .font(.system(size: 12, family: .monospaced))
                                .foregroundColor(themeManager.textColor)

                            Text("LON: \(String(format: "%.6f", location.coordinate.longitude))")
                                .font(.system(size: 12, family: .monospaced))
                                .foregroundColor(themeManager.textColor)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("ALT: \(String(format: "%.1f", location.altitude))M")
                                .font(.system(size: 12, family: .monospaced))
                                .foregroundColor(themeManager.textColor)

                            Text("ACC: ±\(String(format: "%.1f", location.horizontalAccuracy))M")
                                .font(.system(size: 12, family: .monospaced))
                                .foregroundColor(themeManager.textColor)
                        }
                    }

                    HStack {
                        Text("HEADING: \(String(format: "%.0f", viewModel.heading))°")
                            .font(.system(size: 12, family: .monospaced))
                            .foregroundColor(themeManager.accentColor)

                        Spacer()

                        Text("SPEED: \(String(format: "%.1f", location.speed))M/S")
                            .font(.system(size: 12, family: .monospaced))
                            .foregroundColor(themeManager.textColor)
                    }
                } else {
                    Text("ACQUIRING GPS SIGNAL...")
                        .font(.system(size: 12, family: .monospaced))
                        .foregroundColor(themeManager.warningColor)
                }
            }
        }
    }

    private var missionSection: some View {
        HUDPanel(title: "Active Mission") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Operation: Silent Eagle")
                    .font(.system(size: 14, family: .monospaced))
                    .foregroundColor(themeManager.primaryColor)

                Text("Status: In Progress")
                    .font(.system(size: 12, family: .monospaced))
                    .foregroundColor(themeManager.successColor)

                Text("Objective: Infiltrate facility without detection")
                    .font(.system(size: 10, family: .monospaced))
                    .foregroundColor(themeManager.textColor.opacity(0.8))
            }
        }
    }

    private var statusSection: some View {
        HUDPanel(title: "System Status") {
            VStack(spacing: 12) {
                statusRow("CAMERA", status: "READY", color: themeManager.successColor)
                statusRow("AUDIO", status: "STANDBY", color: themeManager.warningColor)
                statusRow("NETWORK", status: "ONLINE", color: themeManager.successColor)
                statusRow("SENSORS", status: "ACTIVE", color: themeManager.successColor)
            }
        }
    }

    private func statusRow(_ system: String, status: String, color: Color) -> some View {
        HStack {
            Text(system)
                .font(.system(size: 10, family: .monospaced))
                .foregroundColor(themeManager.textColor)

            Spacer()

            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(status)
                .font(.system(size: 10, family: .monospaced))
                .foregroundColor(color)
        }
    }
}

extension DateFormatter {
    static let hudFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}