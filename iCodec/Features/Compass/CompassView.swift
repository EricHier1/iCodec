import SwiftUI
import CoreLocation
import CoreMotion

struct CompassView: View {
    @StateObject private var viewModel = CompassViewModel()
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("NAVIGATION COMPASS")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(themeManager.primaryColor)
                    .fontWeight(.bold)

                Spacer()

                Text("MAG: \(viewModel.magneticVariation, specifier: "%.1f")°")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(themeManager.textColor.opacity(0.7))
            }
            .padding(.horizontal, 16)

            // Main compass display
            compassDisplay

            // Navigation data
            navigationDataPanel

            // Coordinates display
            coordinatesPanel

            Spacer()
        }
        .background(themeManager.backgroundColor)
        .onAppear {
            viewModel.startLocationServices()
        }
        .onDisappear {
            viewModel.stopLocationServices()
        }
    }

    private var compassDisplay: some View {
        VStack(spacing: 12) {
            // Digital heading display
            VStack(spacing: 4) {
                Text("\(Int(viewModel.heading))°")
                    .font(.system(size: 32, design: .monospaced))
                    .foregroundColor(themeManager.primaryColor)
                    .fontWeight(.bold)

                Text(viewModel.cardinalDirection)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(themeManager.accentColor)
                    .fontWeight(.bold)
            }

            // Compass rose
            ZStack {
                // Outer ring
                Circle()
                    .stroke(themeManager.primaryColor.opacity(0.3), lineWidth: 2)
                    .frame(width: 200, height: 200)

                // Cardinal directions
                ForEach(0..<4) { index in
                    let angle = Double(index) * 90
                    let direction = ["N", "E", "S", "W"][index]

                    Text(direction)
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(direction == "N" ? .red : themeManager.primaryColor)
                        .fontWeight(.bold)
                        .position(
                            x: 100 + 85 * cos((angle - 90) * .pi / 180),
                            y: 100 + 85 * sin((angle - 90) * .pi / 180)
                        )
                }

                // Degree markings
                ForEach(0..<36) { index in
                    let angle = Double(index) * 10
                    Rectangle()
                        .fill(themeManager.primaryColor.opacity(index % 9 == 0 ? 0.8 : 0.3))
                        .frame(width: 1, height: index % 9 == 0 ? 12 : 6)
                        .offset(y: -90)
                        .rotationEffect(.degrees(angle))
                }

                // Compass needle
                CompassNeedle(heading: viewModel.heading, themeManager: themeManager)
            }
            .frame(width: 200, height: 200)
        }
        .padding(16)
        .background(themeManager.surfaceColor.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(themeManager.primaryColor.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(8)
        .padding(.horizontal, 16)
    }

    private var navigationDataPanel: some View {
        HStack(spacing: 16) {
            VStack(spacing: 8) {
                VStack(spacing: 2) {
                    Text("ACCURACY")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(themeManager.textColor.opacity(0.7))
                        .fontWeight(.bold)

                    Text(viewModel.accuracyText)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(viewModel.accuracyColor(themeManager: themeManager))
                }

                VStack(spacing: 2) {
                    Text("ALTITUDE")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(themeManager.textColor.opacity(0.7))
                        .fontWeight(.bold)

                    Text("\(Int(viewModel.altitude))m")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(themeManager.primaryColor)
                }
            }

            Spacer()

            VStack(spacing: 8) {
                VStack(spacing: 2) {
                    Text("SPEED")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(themeManager.textColor.opacity(0.7))
                        .fontWeight(.bold)

                    Text("\(viewModel.speed, specifier: "%.1f") km/h")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(themeManager.primaryColor)
                }

                VStack(spacing: 2) {
                    Text("COURSE")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(themeManager.textColor.opacity(0.7))
                        .fontWeight(.bold)

                    Text("\(Int(viewModel.course))°")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(themeManager.accentColor)
                }
            }
        }
        .padding(12)
        .background(themeManager.surfaceColor.opacity(0.2))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(themeManager.primaryColor.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(6)
        .padding(.horizontal, 16)
    }

    private var coordinatesPanel: some View {
        VStack(spacing: 8) {
            HStack {
                Text("COORDINATES")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(themeManager.accentColor)
                    .fontWeight(.bold)

                Spacer()

                Button(action: {
                    viewModel.copyCoordinates()
                }) {
                    Text("COPY")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(themeManager.primaryColor)
                        .fontWeight(.bold)
                }
            }

            VStack(spacing: 4) {
                HStack {
                    Text("LAT:")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(themeManager.textColor.opacity(0.7))
                        .fontWeight(.bold)

                    Text(viewModel.latitudeString)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(themeManager.primaryColor)

                    Spacer()
                }

                HStack {
                    Text("LON:")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(themeManager.textColor.opacity(0.7))
                        .fontWeight(.bold)

                    Text(viewModel.longitudeString)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(themeManager.primaryColor)

                    Spacer()
                }

                if !viewModel.mgrsString.isEmpty {
                    HStack {
                        Text("MGRS:")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(themeManager.textColor.opacity(0.7))
                            .fontWeight(.bold)

                        Text(viewModel.mgrsString)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(themeManager.accentColor)

                        Spacer()
                    }
                }
            }
        }
        .padding(12)
        .background(themeManager.surfaceColor.opacity(0.2))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(themeManager.primaryColor.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(6)
        .padding(.horizontal, 16)
    }
}

struct CompassNeedle: View {
    let heading: Double
    let themeManager: ThemeManager

    var body: some View {
        ZStack {
            // North pointer (red)
            Path { path in
                path.move(to: CGPoint(x: 100, y: 20))
                path.addLine(to: CGPoint(x: 95, y: 100))
                path.addLine(to: CGPoint(x: 105, y: 100))
                path.closeSubpath()
            }
            .fill(.red)

            // South pointer (white)
            Path { path in
                path.move(to: CGPoint(x: 100, y: 180))
                path.addLine(to: CGPoint(x: 95, y: 100))
                path.addLine(to: CGPoint(x: 105, y: 100))
                path.closeSubpath()
            }
            .fill(.white)

            // Center dot
            Circle()
                .fill(themeManager.primaryColor)
                .frame(width: 8, height: 8)
        }
        .rotationEffect(.degrees(-heading), anchor: .center)
        .animation(.easeInOut(duration: 0.5), value: heading)
    }
}

@MainActor
class CompassViewModel: NSObject, ObservableObject {
    @Published var heading: Double = 0
    @Published var magneticVariation: Double = 0
    @Published var accuracy: Double = 0
    @Published var latitude: Double = 0
    @Published var longitude: Double = 0
    @Published var altitude: Double = 0
    @Published var speed: Double = 0
    @Published var course: Double = 0

    private let locationManager = CLLocationManager()
    private let motionManager = CMMotionManager()

    override init() {
        super.init()
        setupLocationManager()
        setupMotionManager()
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }

    private func setupMotionManager() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.1
        }
    }

    func startLocationServices() {
        guard CLLocationManager.locationServicesEnabled() else { return }

        locationManager.startUpdatingLocation()

        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }

        if motionManager.isDeviceMotionAvailable {
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
                guard let motion = motion else { return }
                // Use device motion for additional compass stabilization if needed
            }
        }
    }

    func stopLocationServices() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        motionManager.stopDeviceMotionUpdates()
    }

    var cardinalDirection: String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                         "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((heading + 11.25) / 22.5) % 16
        return directions[index]
    }

    var accuracyText: String {
        if accuracy < 0 {
            return "INVALID"
        } else if accuracy < 5 {
            return "HIGH"
        } else if accuracy < 15 {
            return "MEDIUM"
        } else {
            return "LOW"
        }
    }

    func accuracyColor(themeManager: ThemeManager) -> Color {
        if accuracy < 0 {
            return .red
        } else if accuracy < 5 {
            return .green
        } else if accuracy < 15 {
            return .orange
        } else {
            return .red
        }
    }

    var latitudeString: String {
        let degrees = Int(abs(latitude))
        let minutes = (abs(latitude) - Double(degrees)) * 60
        let direction = latitude >= 0 ? "N" : "S"
        return String(format: "%d°%06.3f'%@", degrees, minutes, direction)
    }

    var longitudeString: String {
        let degrees = Int(abs(longitude))
        let minutes = (abs(longitude) - Double(degrees)) * 60
        let direction = longitude >= 0 ? "E" : "W"
        return String(format: "%d°%06.3f'%@", degrees, minutes, direction)
    }

    var mgrsString: String {
        // Simplified MGRS representation
        // In a real app, you'd use a proper MGRS conversion library
        if latitude != 0 && longitude != 0 {
            return "31T DM \(String(format: "%05d", Int((longitude + 180) * 1000) % 100000)) \(String(format: "%05d", Int((latitude + 90) * 1000) % 100000))"
        }
        return ""
    }

    func copyCoordinates() {
        let coordinates = "LAT: \(latitudeString)\nLON: \(longitudeString)"
        #if os(iOS)
        UIPasteboard.general.string = coordinates
        #endif
        print("📋 Coordinates copied to clipboard")
    }
}

extension CompassViewModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy > 0 else { return }

        heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        magneticVariation = newHeading.trueHeading - newHeading.magneticHeading
        accuracy = newHeading.headingAccuracy
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        altitude = location.altitude
        speed = max(0, location.speed * 3.6) // Convert m/s to km/h
        course = location.course >= 0 ? location.course : 0
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationServices()
        case .denied, .restricted:
            print("Location access denied")
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
}