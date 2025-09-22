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
                    Marker(waypoint.id, coordinate: waypoint.coordinate)
                        .tint(markerColor(for: waypoint))
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
            .ignoresSafeArea()
            .colorScheme(.dark)

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
        HStack(spacing: 20) {
            // Mode toggle
            CodecButton(title: "MODE", action: {
                viewModel.cycleMode()
            }, style: .secondary, size: .medium)

            // Center on user
            CodecButton(title: "CENTER", action: {
                viewModel.centerOnUser()
            }, style: .primary, size: .medium)

            // Add waypoint
            CodecButton(title: viewModel.showPreviewMarker ? "PLACE" : "MARK", action: {
                if viewModel.showPreviewMarker {
                    viewModel.addWaypoint()
                } else {
                    viewModel.togglePreviewMarker()
                }
            }, style: viewModel.showPreviewMarker ? .primary : .secondary, size: .medium)

            // Zoom controls
            VStack(spacing: 10) {
                Button(action: { viewModel.zoomIn() }) {
                    Image(systemName: "plus")
                        .foregroundColor(themeManager.primaryColor)
                        .font(.system(size: 16, weight: .bold))
                }

                Button(action: { viewModel.zoomOut() }) {
                    Image(systemName: "minus")
                        .foregroundColor(themeManager.primaryColor)
                        .font(.system(size: 16, weight: .bold))
                }
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

    private let locationManager = CLLocationManager()
    private var locationDelegate: MapLocationDelegate?

    enum MapMode: String, CaseIterable {
        case tactical = "TACTICAL"
        case satellite = "SATELLITE"
        case infrared = "INFRARED"
        case topographic = "TOPO"
    }

    var currentMapStyle: MapStyle {
        switch currentMode {
        case .tactical:
            return .standard(elevation: .flat)
        case .satellite:
            return .imagery(elevation: .flat)
        case .infrared:
            return .hybrid(elevation: .flat)
        case .topographic:
            return .standard(elevation: .realistic)
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

        // Only center the map on the user's location when we first get it
        if !hasInitialLocation {
            let newRegion = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            region = newRegion
            cameraPosition = .region(newRegion)
            updateMapCenter()
            hasInitialLocation = true
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
            coordinate: mapCenter,
            type: .checkpoint
        )
        waypoints.append(newWaypoint)
        showPreviewMarker = false
    }

    func togglePreviewMarker() {
        showPreviewMarker.toggle()
    }

    private func updateScaleText() {
        let scale = Int(region.span.latitudeDelta * 100000)
        scaleText = "1:\(scale)"
    }

    private func generateSampleWaypoints() {
        waypoints = [
            Waypoint(id: "A", coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), type: .objective),
            Waypoint(id: "B", coordinate: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094), type: .checkpoint),
            Waypoint(id: "C", coordinate: CLLocationCoordinate2D(latitude: 37.7649, longitude: -122.4294), type: .intel),
            Waypoint(id: "E", coordinate: CLLocationCoordinate2D(latitude: 37.7949, longitude: -122.3994), type: .extraction)
        ]
    }
}

struct Waypoint: Identifiable {
    let id: String
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