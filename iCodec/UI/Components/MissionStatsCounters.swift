import SwiftUI

struct MissionStatsCounters: View {
    @ObservedObject private var sharedData = SharedDataManager.shared
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            // Active missions counter
            StatCounter(
                label: "ACTIVE",
                value: sharedData.activeMissionCount,
                color: themeManager.accentColor
            )

            Divider()
                .frame(height: 20)
                .background(themeManager.primaryColor.opacity(0.3))

            // Today's completed missions counter
            StatCounter(
                label: "TODAY",
                value: sharedData.todayCompletedCount,
                color: themeManager.successColor
            )

            Divider()
                .frame(height: 20)
                .background(themeManager.primaryColor.opacity(0.3))

            // Total completed missions counter
            StatCounter(
                label: "TOTAL",
                value: sharedData.totalCompletedCount,
                color: themeManager.primaryColor
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(themeManager.primaryColor.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(themeManager.primaryColor.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(6)
    }
}

struct StatCounter: View {
    let label: String
    let value: Int
    let color: Color
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 14, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(themeManager.textColor.opacity(0.7))
        }
        .frame(minWidth: 44)
    }
}

#Preview {
    MissionStatsCounters()
        .environmentObject(ThemeManager())
        .background(Color.black)
}