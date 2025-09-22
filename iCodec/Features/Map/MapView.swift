import SwiftUI
import MapKit
import CoreLocation

struct MapView: View {
    @ObservedObject private var viewModel = SharedDataManager.shared.mapViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        ZStack {
            mapSurface
            hudOverlay
        }
        .onAppear {
            viewModel.requestLocationPermission()
        }
        .sheet(isPresented: $viewModel.showWaypointEditor) {
            WaypointEditorSheet(viewModel: viewModel)
        }
    }

    private var mapSurface: some View {
        Map(position: $viewModel.cameraPosition) {
            ForEach(viewModel.waypoints) { waypoint in
                Annotation(waypoint.name.isEmpty ? waypoint.id : waypoint.name, coordinate: waypoint.coordinate) {
                    WaypointMarker(waypoint: waypoint, themeManager: themeManager)
                        .onTapGesture {
                            viewModel.selectWaypoint(waypoint)
                        }
                }
                .annotationTitles(.hidden)
            }

            if let userLocation = viewModel.userLocation {
                Annotation("Agent", coordinate: userLocation) {
                    UserLocationMarker(primaryColor: themeManager.successColor, accentColor: themeManager.primaryColor)
                }
                .annotationTitles(.hidden)
            }

        }
        .mapStyle(viewModel.currentMapStyle)
        .onMapCameraChange { context in
            viewModel.updateCameraRegion(context.region)
        }
        .mapControlVisibility(.hidden)
        .ignoresSafeArea()
        .colorScheme(viewModel.currentMode == .dark ? .dark : .light)
        .overlay(
            TacticalGridOverlay()
                .opacity(viewModel.currentMode == .tactical || viewModel.currentMode == .dark ? 0.1 : 0)
                .allowsHitTesting(false)
        )
    }

    private var hudOverlay: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                infoOverlay
                Spacer()
            }

            Spacer()

            controlBar
        }
        .padding(.horizontal, isCompactLayout ? 12 : 24)
        .padding(.vertical, isCompactLayout ? 16 : 28)
    }

    private var infoOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            infoLine(label: "MODE", value: viewModel.currentMode.rawValue)
            infoLine(label: "WPTS", value: "\(viewModel.waypoints.count)")
            infoLine(label: "SCALE", value: viewModel.scaleText)
            infoLine(label: "LAT", value: formattedCoordinate(viewModel.userLocation?.latitude, axis: .latitude))
            infoLine(label: "LON", value: formattedCoordinate(viewModel.userLocation?.longitude, axis: .longitude))
            infoLine(label: "ALT", value: formattedAltitude())
            infoLine(label: "ACC", value: formattedAccuracy())
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundColor(themeManager.textColor)
        .shadow(color: Color.black.opacity(0.7), radius: 3, x: 0, y: 1)
    }

    private var controlBar: some View {
        HStack(spacing: 10) {
            CodecButton(title: "MODE", action: {
                TacticalSoundPlayer.shared.playNavigation()
                viewModel.cycleMode()
            }, style: .primary, size: .small)

            MapIconButton(systemName: "location.fill") {
                TacticalSoundPlayer.shared.playNavigation()
                viewModel.centerOnUser()
            }

            CodecButton(title: "MARK", action: {
                TacticalSoundPlayer.shared.playAction()
                viewModel.addWaypoint()
            }, style: .primary, size: .small)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                MapZoomButton(symbol: "minus") {
                    TacticalSoundPlayer.shared.playNavigation()
                    viewModel.zoomOut()
                }

                MapZoomButton(symbol: "plus") {
                    TacticalSoundPlayer.shared.playNavigation()
                    viewModel.zoomIn()
                }
            }

            Menu {
                Button(role: .destructive) {
                    viewModel.deleteAllWaypoints()
                } label: {
                    Label("Clear all waypoints", systemImage: "trash")
                }
            } label: {
                ControlMenuLabel(text: "MORE")
            }
            .menuStyle(.borderlessButton)
            .disabled(viewModel.waypoints.isEmpty)
        }
    }

    private func infoLine(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundColor(themeManager.accentColor.opacity(0.85))
                .fontWeight(.semibold)

            Text(value)
                .foregroundColor(themeManager.textColor)
        }
    }

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact || verticalSizeClass == .compact
    }

    private enum CoordinateAxis {
        case latitude
        case longitude
    }

    private func formattedCoordinate(_ value: CLLocationDegrees?, axis: CoordinateAxis) -> String {
        guard let value = value else { return "—" }

        let direction: String
        switch axis {
        case .latitude:
            direction = value >= 0 ? "N" : "S"
        case .longitude:
            direction = value >= 0 ? "E" : "W"
        }

        return String(format: "%.4f° %@", abs(value), direction)
    }

    private func formattedAltitude() -> String {
        guard let altitude = viewModel.lastKnownLocation?.altitude else { return "—" }
        return String(format: "%.0f m", altitude)
    }

    private func formattedAccuracy() -> String {
        guard let accuracy = viewModel.lastKnownLocation?.horizontalAccuracy else { return "—" }
        if accuracy < 0 {
            return "—"
        }
        return String(format: "±%.0f m", accuracy)
    }
}

private struct ControlMenuLabel: View {
    let text: String

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let borderColor = themeManager.primaryColor
        let foreground = isEnabled ? borderColor : borderColor.opacity(0.4)
        let background = borderColor.opacity(isEnabled ? 0.2 : 0.08)

        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .fontWeight(.semibold)
            .foregroundColor(foreground)
            .padding(.horizontal, 16)
            .frame(height: 32)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(foreground, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .contentShape(RoundedRectangle(cornerRadius: 4))
    }
}

private struct MapIconButton: View {
    let systemName: String
    let action: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(themeManager.primaryColor)
                .frame(width: 36, height: 36)
                .background(themeManager.surfaceColor.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(themeManager.primaryColor, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

private struct MapZoomButton: View {
    let symbol: String
    let action: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(themeManager.primaryColor)
                .frame(width: 32, height: 32)
                .background(themeManager.surfaceColor.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(themeManager.primaryColor, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

private struct UserLocationMarker: View {
    let primaryColor: Color
    let accentColor: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(accentColor.opacity(0.4), lineWidth: 2)
                .frame(width: 36, height: 36)

            Circle()
                .stroke(accentColor.opacity(0.2), lineWidth: 2)
                .frame(width: 52, height: 52)

            Circle()
                .fill(primaryColor)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(accentColor, lineWidth: 2)
                )
        }
    }
}

struct WaypointMarker: View {
    let waypoint: Waypoint
    let themeManager: ThemeManager

    var body: some View {
        ZStack {
            Circle()
                .fill(markerColor)
                .frame(width: 16, height: 16)

            Circle()
                .stroke(themeManager.primaryColor, lineWidth: 2)
                .frame(width: 20, height: 20)

            Text(waypoint.id)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.black)
                .fontWeight(.bold)
        }
    }

    private var markerColor: Color {
        switch waypoint.type {
        case .objective:
            return themeManager.errorColor
        case .checkpoint:
            return themeManager.warningColor
        case .intel:
            return themeManager.accentColor
        case .extraction:
            return themeManager.successColor
        }
    }
}

@MainActor
class MapViewModel: BaseViewModel {
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    @Published var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    )

    @Published var waypoints: [Waypoint] = []
    @Published var currentMode: MapMode = .tactical
    @Published var scaleText = "≈1.1 km"
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var mapCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    @Published var hasInitialLocation = false
    @Published var selectedWaypoint: Waypoint?
    @Published var showWaypointEditor = false
    @Published var lastKnownLocation: CLLocation?

    private let locationManager = CLLocationManager()
    private var locationDelegate: MapLocationDelegate?

    enum MapMode: String, CaseIterable {
        case tactical = "TACTICAL"
        case dark = "DARK"
        case satellite = "SATELLITE"
        case infrared = "INFRARED"
    }

    var currentMapStyle: MapStyle {
        switch currentMode {
        case .tactical:
            return .standard(elevation: .flat, pointsOfInterest: .excludingAll)
        case .dark:
            return .standard(elevation: .flat, pointsOfInterest: .excludingAll)
        case .satellite:
            return .imagery(elevation: .flat)
        case .infrared:
            return .hybrid(elevation: .flat, pointsOfInterest: .excludingAll)
        }
    }

    override init() {
        super.init()
        setupLocationManager()
        generateSampleWaypoints()
        updateScaleText(for: region)
        requestLocationPermission()
    }

    private func setupLocationManager() {
        locationDelegate = MapLocationDelegate { [weak self] location in
            self?.updateRegion(with: location)
        }
        locationManager.delegate = locationDelegate
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    func requestLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            locationManager.requestLocation()
        default:
            break
        }
    }

    private func updateRegion(with location: CLLocation) {
        userLocation = location.coordinate
        lastKnownLocation = location

        // Always center the map on the user's location when we first get it
        if !hasInitialLocation {
            DispatchQueue.main.async {
                let newRegion = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
                self.region = newRegion
                self.cameraPosition = .region(newRegion)
                self.updateMapCenter()
                self.updateScaleText(for: newRegion)
                self.hasInitialLocation = true
            }
        }
    }

    func centerOnUser() {
        if let location = lastKnownLocation ?? locationManager.location {
            withAnimation(.easeInOut(duration: 0.5)) {
                let newRegion = MKCoordinateRegion(
                    center: location.coordinate,
                    span: region.span
                )
                region = newRegion
                cameraPosition = .region(newRegion)
                updateMapCenter()
                updateScaleText(for: newRegion)
            }
        } else if let userLoc = userLocation {
            withAnimation(.easeInOut(duration: 0.5)) {
                let newRegion = MKCoordinateRegion(
                    center: userLoc,
                    span: region.span
                )
                region = newRegion
                cameraPosition = .region(newRegion)
                updateMapCenter()
                updateScaleText(for: newRegion)
            }
        } else {
            // Request location again if we don't have it
            requestLocationPermission()
        }
    }

    func updateCameraRegion(_ region: MKCoordinateRegion) {
        self.region = region
        mapCenter = region.center
        cameraPosition = .region(region)
        updateScaleText(for: region)
    }

    private func updateMapCenter() {
        mapCenter = region.center
    }

    func zoomIn() {
        withAnimation(.easeInOut(duration: 0.3)) {
            region.span.latitudeDelta = max(region.span.latitudeDelta * 0.5, 0.0005)
            region.span.longitudeDelta = max(region.span.longitudeDelta * 0.5, 0.0005)
            cameraPosition = .region(region)
            updateScaleText(for: region)
            updateMapCenter()
        }
    }

    func zoomOut() {
        withAnimation(.easeInOut(duration: 0.3)) {
            region.span.latitudeDelta = min(region.span.latitudeDelta * 2.0, 10)
            region.span.longitudeDelta = min(region.span.longitudeDelta * 2.0, 10)
            cameraPosition = .region(region)
            updateScaleText(for: region)
            updateMapCenter()
        }
    }

    func cycleMode() {
        let modes = MapMode.allCases
        if let currentIndex = modes.firstIndex(of: currentMode) {
            let nextIndex = (currentIndex + 1) % modes.count
            currentMode = modes[nextIndex]
        }
    }

    func addWaypoint() {
        let newWaypoint = Waypoint(
            id: String(waypoints.count + 1),
            name: "Waypoint \(waypoints.count + 1)",
            coordinate: mapCenter,
            type: .checkpoint
        )
        waypoints.append(newWaypoint)
    }

    func selectWaypoint(_ waypoint: Waypoint) {
        selectedWaypoint = waypoint
        showWaypointEditor = true
    }

    func updateWaypoint(_ waypoint: Waypoint, name: String, type: Waypoint.WaypointType) {
        if let index = waypoints.firstIndex(where: { $0.id == waypoint.id }) {
            waypoints[index].name = name
            waypoints[index] = Waypoint(id: waypoint.id, name: name, coordinate: waypoint.coordinate, type: type)
        }
    }

    func deleteWaypoint(_ waypoint: Waypoint) {
        waypoints.removeAll { $0.id == waypoint.id }
    }

    func deleteAllWaypoints() {
        waypoints.removeAll()
    }

    private func updateScaleText(for region: MKCoordinateRegion? = nil) {
        let referenceRegion = region ?? self.region
        let meters = referenceRegion.span.latitudeDelta * 111_139

        if meters >= 1000 {
            scaleText = String(format: "≈%.1f km", meters / 1000)
        } else {
            scaleText = String(format: "≈%.0f m", meters)
        }
    }

    private func generateSampleWaypoints() {
        waypoints = [
            Waypoint(id: "A", name: "Primary Target", coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), type: .objective),
            Waypoint(id: "B", name: "Checkpoint Alpha", coordinate: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094), type: .checkpoint),
            Waypoint(id: "C", name: "Intel Point", coordinate: CLLocationCoordinate2D(latitude: 37.7649, longitude: -122.4294), type: .intel),
            Waypoint(id: "E", name: "Extraction Zone", coordinate: CLLocationCoordinate2D(latitude: 37.7949, longitude: -122.3994), type: .extraction)
        ]
    }
}

struct Waypoint: Identifiable {
    let id: String
    var name: String
    let coordinate: CLLocationCoordinate2D
    let type: WaypointType

    enum WaypointType {
        case objective, checkpoint, intel, extraction
    }
}

private class MapLocationDelegate: NSObject, CLLocationManagerDelegate {
    let locationUpdate: (CLLocation) -> Void

    init(locationUpdate: @escaping (CLLocation) -> Void) {
        self.locationUpdate = locationUpdate
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        locationUpdate(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // CLLocationManager requires delegates to handle failures even if we ignore them.
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            manager.requestLocation()
        default:
            break
        }
    }
}

struct WaypointEditorSheet: View {
    @ObservedObject var viewModel: MapViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var waypointType: Waypoint.WaypointType = .checkpoint

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("EDIT WAYPOINT")
                    .font(.system(size: 18, design: .monospaced))
                    .foregroundColor(themeManager.primaryColor)
                    .fontWeight(.bold)

                VStack(spacing: 16) {
                    TextField("Waypoint name...", text: $name)
                        .textFieldStyle(CodecTextFieldStyle())

                    HStack {
                        Text("Type:")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(themeManager.textColor)

                        Picker("Type", selection: $waypointType) {
                            Text("OBJECTIVE").tag(Waypoint.WaypointType.objective)
                            Text("CHECKPOINT").tag(Waypoint.WaypointType.checkpoint)
                            Text("INTEL").tag(Waypoint.WaypointType.intel)
                            Text("EXTRACTION").tag(Waypoint.WaypointType.extraction)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }

                Spacer()

                HStack(spacing: 16) {
                    CodecButton(title: "DELETE", action: {
                        if let waypoint = viewModel.selectedWaypoint {
                            viewModel.deleteWaypoint(waypoint)
                        }
                        dismiss()
                    }, style: .secondary, size: .fullWidth)

                    CodecButton(title: "UPDATE", action: {
                        if let waypoint = viewModel.selectedWaypoint {
                            viewModel.updateWaypoint(waypoint, name: name, type: waypointType)
                        }
                        dismiss()
                    }, style: .primary, size: .fullWidth)
                }
            }
            .padding(20)
            .background(themeManager.backgroundColor)
        }
        .onAppear {
            if let waypoint = viewModel.selectedWaypoint {
                name = waypoint.name
                waypointType = waypoint.type
            }
        }
    }
}

struct TacticalGridOverlay: View {
    var body: some View {
        Canvas { context, size in
            let gridSpacing: CGFloat = 50

            // Draw vertical lines
            for x in stride(from: 0, through: size.width, by: gridSpacing) {
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    },
                    with: .color(.green.opacity(0.3)),
                    lineWidth: 0.5
                )
            }

            // Draw horizontal lines
            for y in stride(from: 0, through: size.height, by: gridSpacing) {
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    },
                    with: .color(.green.opacity(0.3)),
                    lineWidth: 0.5
                )
            }

            // Draw crosshair at center
            let centerX = size.width / 2
            let centerY = size.height / 2
            let crosshairSize: CGFloat = 20

            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: centerX - crosshairSize, y: centerY))
                    path.addLine(to: CGPoint(x: centerX + crosshairSize, y: centerY))
                    path.move(to: CGPoint(x: centerX, y: centerY - crosshairSize))
                    path.addLine(to: CGPoint(x: centerX, y: centerY + crosshairSize))
                },
                with: .color(.green.opacity(0.8)),
                lineWidth: 2
            )
        }
    }
}
