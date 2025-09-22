import SwiftUI
import MapKit
import CoreLocation

struct MapView: View {
    @StateObject private var viewModel = MapViewModel()
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            // Map background
            Map(position: $viewModel.cameraPosition) {
                ForEach(viewModel.waypoints) { waypoint in
                    Annotation(waypoint.name.isEmpty ? waypoint.id : waypoint.name, coordinate: waypoint.coordinate) {
                        WaypointMarker(waypoint: waypoint, themeManager: themeManager)
                            .onTapGesture {
                                viewModel.selectWaypoint(waypoint)
                            }
                    }
                }

                // User location marker
                if let userLocation = viewModel.userLocation {
                    Marker("YOU", coordinate: userLocation)
                        .tint(themeManager.successColor)
                }

                // Preview marker for where next waypoint will be placed
                if viewModel.showPreviewMarker {
                    Marker("?", coordinate: viewModel.mapCenter)
                        .tint(themeManager.primaryColor.opacity(0.6))
                }
            }
            .mapStyle(viewModel.currentMapStyle)
            .onMapCameraChange { context in
                viewModel.updateMapCenter(context.region.center)
            }
            .mapControlVisibility(.hidden)
            .ignoresSafeArea()
            .colorScheme(viewModel.currentMode == .dark ? .dark : .light)
            .overlay(
                // Tactical grid overlay
                TacticalGridOverlay()
                    .opacity(viewModel.currentMode == .tactical || viewModel.currentMode == .dark ? 0.1 : 0)
                    .allowsHitTesting(false)
            )

            // HUD Overlay
            VStack {
                // Top status bar
                topStatusBar

                Spacer()

                // Bottom controls
                bottomControls
            }
            .overlay(
                ScanlineOverlay()
                    .opacity(0.2)
            )
        }
        .onAppear {
            viewModel.requestLocationPermission()
        }
        .sheet(isPresented: $viewModel.showWaypointEditor) {
            WaypointEditorSheet(viewModel: viewModel)
        }
    }

    private func markerColor(for waypoint: Waypoint) -> Color {
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

    private var topStatusBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("TACTICAL MAP")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(themeManager.primaryColor)

                Text("SCALE: \(viewModel.scaleText)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(themeManager.textColor)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("WAYPOINTS: \(viewModel.waypoints.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(themeManager.accentColor)

                Text("MODE: \(viewModel.currentMode.rawValue)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(themeManager.successColor)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .background(themeManager.backgroundColor.opacity(0.7))
    }

    private var bottomControls: some View {
        VStack(spacing: 12) {
            // Top row of controls
            HStack(spacing: 16) {
                // Mode toggle
                CodecButton(title: "MODE", action: {
                    viewModel.cycleMode()
                }, style: .secondary, size: .small)

                // Center on user
                CodecButton(title: "MY POS", action: {
                    viewModel.centerOnUser()
                }, style: .primary, size: .small)

                // Add waypoint
                CodecButton(title: viewModel.showPreviewMarker ? "PLACE" : "MARK", action: {
                    if viewModel.showPreviewMarker {
                        viewModel.addWaypoint()
                    } else {
                        viewModel.togglePreviewMarker()
                    }
                }, style: viewModel.showPreviewMarker ? .primary : .secondary, size: .small)

                // Clear all waypoints
                CodecButton(title: "CLEAR", action: {
                    viewModel.deleteAllWaypoints()
                }, style: .secondary, size: .small)
            }

            // Bottom row with zoom controls
            HStack(spacing: 20) {
                // Zoom controls
                HStack(spacing: 12) {
                    Button(action: { viewModel.zoomOut() }) {
                        Text("−")
                            .foregroundColor(themeManager.primaryColor)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .frame(width: 32, height: 32)
                            .background(themeManager.surfaceColor.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(themeManager.primaryColor, lineWidth: 1)
                            )
                    }

                    Button(action: { viewModel.zoomIn() }) {
                        Text("+")
                            .foregroundColor(themeManager.primaryColor)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .frame(width: 32, height: 32)
                            .background(themeManager.surfaceColor.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(themeManager.primaryColor, lineWidth: 1)
                            )
                    }
                }

                Spacer()

                // Map type indicator
                Text(viewModel.currentMode.rawValue)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(themeManager.primaryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(themeManager.surfaceColor.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(themeManager.primaryColor, lineWidth: 1)
                    )
            }
        }
        .padding(.bottom, 30)
        .padding(.horizontal, 20)
        .background(themeManager.backgroundColor.opacity(0.7))
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
    @Published var scaleText = "1:1000"
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var showPreviewMarker = false
    @Published var mapCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    @Published var hasInitialLocation = false
    @Published var selectedWaypoint: Waypoint?
    @Published var showWaypointEditor = false

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
        requestLocationPermission()
    }

    private func setupLocationManager() {
        locationDelegate = MapLocationDelegate { [weak self] location in
            self?.updateRegion(with: location)
        }
        locationManager.delegate = locationDelegate
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        default:
            break
        }
    }

    private func updateRegion(with location: CLLocation) {
        userLocation = location.coordinate

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
                self.hasInitialLocation = true
            }
        }
    }

    func centerOnUser() {
        if let location = locationManager.location {
            withAnimation(.easeInOut(duration: 0.5)) {
                let newRegion = MKCoordinateRegion(
                    center: location.coordinate,
                    span: region.span
                )
                region = newRegion
                cameraPosition = .region(newRegion)
                updateMapCenter()
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
            }
        } else {
            // Request location again if we don't have it
            requestLocationPermission()
        }
    }

    private func updateMapCenter() {
        mapCenter = region.center
    }

    func updateMapCenter(_ coordinate: CLLocationCoordinate2D) {
        mapCenter = coordinate
    }

    func zoomIn() {
        withAnimation(.easeInOut(duration: 0.3)) {
            region.span.latitudeDelta *= 0.5
            region.span.longitudeDelta *= 0.5
            cameraPosition = .region(region)
            updateScaleText()
            updateMapCenter()
        }
    }

    func zoomOut() {
        withAnimation(.easeInOut(duration: 0.3)) {
            region.span.latitudeDelta *= 2.0
            region.span.longitudeDelta *= 2.0
            cameraPosition = .region(region)
            updateScaleText()
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
        showPreviewMarker = false
    }

    func togglePreviewMarker() {
        showPreviewMarker.toggle()
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

    private func updateScaleText() {
        let scale = Int(region.span.latitudeDelta * 100000)
        scaleText = "1:\(scale)"
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

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
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