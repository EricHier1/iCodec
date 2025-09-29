import SwiftUI
import MapKit
import CoreLocation

struct MapView: View {
    @ObservedObject private var viewModel = SharedDataManager.shared.mapViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var showMapActions = false

    var body: some View {
        ZStack {
            mapSurface
            hudOverlay
        }
        .onAppear {
            if !viewModel.hasInitialLocation {
                viewModel.requestLocationPermission()
            }
        }
        .sheet(isPresented: $viewModel.showWaypointEditor) {
            WaypointEditorSheet(viewModel: viewModel)
        }
        .confirmationDialog("Map Actions", isPresented: $showMapActions, titleVisibility: .visible) {
            Button("Clear all waypoints", role: .destructive) {
                TacticalSoundPlayer.playAction()
                viewModel.deleteAllWaypoints()
            }

            Button("Cancel", role: .cancel) {
                TacticalSoundPlayer.playNavigation()
            }
        }
    }

    private var mapSurface: some View {
        Group {
            if viewModel.hasInitialLocation {
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
                .overlay(alignment: .center) {
                    CenterTargetView(color: themeManager.primaryColor)
                        .allowsHitTesting(false)
                }
            } else {
                // Show loading state until we have location
                ZStack {
                    Rectangle()
                        .fill(themeManager.backgroundColor)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: themeManager.primaryColor))
                            .scaleEffect(1.5)

                        Text("ACQUIRING LOCATION...")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(themeManager.primaryColor)
                            .fontWeight(.bold)
                    }
                }
            }
        }
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
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
    }

    private var infoOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            infoLine(label: "MODE", value: viewModel.currentMode.rawValue)
            infoLine(label: "WPTS", value: "\(viewModel.waypoints.count)")
            infoLine(label: "FOLLOW", value: viewModel.isFollowingUser ? "ON" : "OFF")
            infoLine(label: "SCALE", value: viewModel.scaleText)
            infoLine(label: "LAT", value: formattedCoordinate(viewModel.mapCenter.latitude, axis: .latitude))
            infoLine(label: "LON", value: formattedCoordinate(viewModel.mapCenter.longitude, axis: .longitude))
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
                TacticalSoundPlayer.playNavigation()
                viewModel.cycleMode()
            }, style: .primary, size: .small)

            MapIconButton(systemName: viewModel.isFollowingUser ? "location.fill" : "location") {
                TacticalSoundPlayer.playNavigation()
                viewModel.toggleFollowUser()
            }

            CodecButton(title: "MARK", action: {
                TacticalSoundPlayer.playAction()
                viewModel.addWaypoint()
            }, style: .primary, size: .small)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                MapZoomButton(symbol: "-") {
                    TacticalSoundPlayer.playNavigation()
                    viewModel.zoomOut()
                }

                MapZoomButton(symbol: "+") {
                    TacticalSoundPlayer.playNavigation()
                    viewModel.zoomIn()
                }
            }

            CodecButton(title: "MORE", action: {
                TacticalSoundPlayer.playNavigation()
                showMapActions = true
            }, style: .primary, size: .small)
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

    private func formattedCoordinate(_ value: CLLocationDegrees, axis: CoordinateAxis) -> String {
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
        // Only show altitude if we're at or very close to user location
        guard let userLoc = viewModel.userLocation,
              let altitude = viewModel.lastKnownLocation?.altitude else {
            return "—"
        }

        // Check if map center is close to user location (within ~100m)
        let distance = CLLocation(latitude: viewModel.mapCenter.latitude, longitude: viewModel.mapCenter.longitude)
            .distance(from: CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude))

        if distance < 100 {
            return String(format: "%.0f m", altitude)
        } else {
            return "—"
        }
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

private struct CenterTargetView: View {
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.6), lineWidth: 1)
                .frame(width: 32, height: 32)

            Rectangle()
                .fill(color.opacity(0.8))
                .frame(width: 24, height: 1)

            Rectangle()
                .fill(color.opacity(0.8))
                .frame(width: 1, height: 24)

            Circle()
                .fill(color)
                .frame(width: 4, height: 4)
        }
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
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    @Published var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    )

    @Published var waypoints: [Waypoint] = [] {
        didSet {
            saveWaypoints()
        }
    }
    @Published var currentMode: MapMode = .dark
    @Published var scaleText = "≈1.1 km"
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var mapCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    @Published var hasInitialLocation = false
    @Published var selectedWaypoint: Waypoint?
    @Published var showWaypointEditor = false
    @Published var lastKnownLocation: CLLocation?
    @Published var locationError: String?
    @Published var isFollowingUser = false

    private let locationManager = CLLocationManager()
    private var locationDelegate: MapLocationDelegate?
    private var locationTimeout: Timer?
    private var isProgrammaticUpdate = false
    private let waypointsKey = "savedWaypoints"

    enum MapMode: String, CaseIterable {
        case tactical = "TACTICAL"
        case dark = "DARK"
        case satellite = "SATELLITE"
    }

    var currentMapStyle: MapStyle {
        switch currentMode {
        case .tactical:
            return .standard(elevation: .flat, pointsOfInterest: .excludingAll)
        case .dark:
            return .standard(elevation: .flat, pointsOfInterest: .excludingAll)
        case .satellite:
            return .imagery(elevation: .flat)
        }
    }

    override init() {
        super.init()
        setupLocationManager()
        loadWaypoints()
        updateScaleText(for: region)
        requestLocationPermission()
    }

    private func setupLocationManager() {
        locationDelegate = MapLocationDelegate { [weak self] location in
            Task { @MainActor in
                self?.updateRegion(with: location)
            }
        }
        locationManager.delegate = locationDelegate
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    func requestLocationPermission() {
        print("MapViewModel: Requesting location permission, current status: \(locationManager.authorizationStatus.rawValue)")
        locationError = nil

        switch locationManager.authorizationStatus {
        case .notDetermined:
            print("MapViewModel: Requesting authorization...")
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            print("MapViewModel: Permission granted, starting location services...")
            startLocationServices()
        case .denied, .restricted:
            print("MapViewModel: Location permission denied")
            locationError = "Location access denied"
            useDefaultLocation()
        default:
            print("MapViewModel: Unknown authorization status")
            break
        }
    }

    private func startLocationServices() {
        // Always request fresh location, don't use cached
        print("MapViewModel: Requesting fresh location...")
        locationManager.startUpdatingLocation()

        // Start a timeout timer in case location services are slow
        startLocationTimeout()
    }

    private func startLocationTimeout() {
        locationTimeout?.invalidate()
        locationTimeout = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if !self.hasInitialLocation {
                    self.locationError = "Location timeout"
                    self.useDefaultLocation()
                }
            }
        }
    }

    private func useDefaultLocation() {
        // Use a default location if we can't get user location
        let defaultLocation = CLLocation(latitude: 37.7749, longitude: -122.4194) // San Francisco as fallback
        updateRegion(with: defaultLocation)
    }

    private func updateRegion(with location: CLLocation) {
        print("MapViewModel: Updating region with location: \(location.coordinate)")
        locationTimeout?.invalidate() // Cancel timeout since we got location
        userLocation = location.coordinate
        lastKnownLocation = location

        // Always center the map on the user's location when we first get it
        if !hasInitialLocation {
            print("MapViewModel: Setting initial location to: \(location.coordinate)")
            let newRegion = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            self.region = newRegion
            self.cameraPosition = .region(newRegion)
            self.updateMapCenter()
            self.updateScaleText(for: newRegion)
            self.hasInitialLocation = true

            // Create sample waypoints relative to user location if we don't have any
            if self.waypoints.isEmpty {
                self.createSampleWaypointsNearLocation(location.coordinate)
            }
        } else if isFollowingUser {
            // Continue following user location updates
            isProgrammaticUpdate = true
            withAnimation(.easeInOut(duration: 0.3)) {
                let newRegion = MKCoordinateRegion(
                    center: location.coordinate,
                    span: region.span
                )
                self.region = newRegion
                self.cameraPosition = .region(newRegion)
                self.updateMapCenter()
                self.updateScaleText(for: newRegion)
            }
        }
    }

    func centerOnUser() {
        if let location = lastKnownLocation ?? locationManager.location {
            isProgrammaticUpdate = true
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
            isProgrammaticUpdate = true
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

    func centerOnCoordinate(_ coordinate: CLLocationCoordinate2D) {
        isProgrammaticUpdate = true
        withAnimation(.easeInOut(duration: 0.5)) {
            let newRegion = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            region = newRegion
            cameraPosition = .region(newRegion)
            updateMapCenter()
            updateScaleText(for: newRegion)
        }
    }

    func toggleFollowUser() {
        isFollowingUser.toggle()
        if isFollowingUser {
            centerOnUser()
        }
    }

    func updateCameraRegion(_ region: MKCoordinateRegion) {
        // Only disable following when user manually moves the map, not when we programmatically update it
        if isFollowingUser && !isProgrammaticUpdate {
            isFollowingUser = false
        }
        isProgrammaticUpdate = false
        self.region = region
        self.mapCenter = region.center
        self.cameraPosition = .region(region)
        self.updateScaleText(for: region)
    }

    private func updateMapCenter() {
        mapCenter = region.center
    }

    func zoomIn() {
        isProgrammaticUpdate = true
        withAnimation(.easeInOut(duration: 0.3)) {
            region.span.latitudeDelta = max(region.span.latitudeDelta * 0.5, 0.0005)
            region.span.longitudeDelta = max(region.span.longitudeDelta * 0.5, 0.0005)
            cameraPosition = .region(region)
            updateScaleText(for: region)
            updateMapCenter()
        }
    }

    func zoomOut() {
        isProgrammaticUpdate = true
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
        // Start with empty waypoints - will be populated relative to user location
        waypoints = []
    }

    private func createSampleWaypointsNearLocation(_ location: CLLocationCoordinate2D) {
        // No sample waypoints - user will create their own
    }

    private func saveWaypoints() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(waypoints)
            UserDefaults.standard.set(data, forKey: waypointsKey)
            print("MapViewModel: Saved \(waypoints.count) waypoints")
        } catch {
            print("MapViewModel: Failed to save waypoints: \(error)")
        }
    }

    private func loadWaypoints() {
        guard let data = UserDefaults.standard.data(forKey: waypointsKey) else {
            print("MapViewModel: No saved waypoints found")
            return
        }

        do {
            let decoder = JSONDecoder()
            waypoints = try decoder.decode([Waypoint].self, from: data)
            print("MapViewModel: Loaded \(waypoints.count) waypoints")
        } catch {
            print("MapViewModel: Failed to load waypoints: \(error)")
        }
    }
}

struct Waypoint: Identifiable, Codable {
    let id: String
    var name: String
    let latitude: Double
    let longitude: Double
    let type: WaypointType

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(id: String, name: String, coordinate: CLLocationCoordinate2D, type: WaypointType) {
        self.id = id
        self.name = name
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.type = type
    }

    enum WaypointType: String, Codable {
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
        print("MapLocationDelegate: Received location update: \(location.coordinate)")
        locationUpdate(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
        // Try to use cached location as fallback
        if let cachedLocation = manager.location {
            locationUpdate(cachedLocation)
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("MapLocationDelegate: Authorization changed to: \(status.rawValue)")
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("MapLocationDelegate: Starting location updates for fresh location")
            manager.startUpdatingLocation()
        default:
            print("MapLocationDelegate: Location not authorized")
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
