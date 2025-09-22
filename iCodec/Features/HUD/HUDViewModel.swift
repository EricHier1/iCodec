import Foundation
import CoreLocation
import CoreMotion
import Combine

@MainActor
class HUDViewModel: BaseViewModel {
    @Published var currentLocation: CLLocation?
    @Published var heading: Double = 0.0
    @Published var detectedContacts: Int = 0

    private let locationManager = CLLocationManager()
    private let motionManager = CMMotionManager()
    private var locationDelegate: LocationDelegate?

    override init() {
        super.init()
        setupLocationManager()
        setupMotionManager()
        simulateRadarContacts()
        // Start with some initial contacts
        detectedContacts = 2
    }

    private func setupLocationManager() {
        locationDelegate = LocationDelegate { [weak self] location in
            self?.currentLocation = location
        }
        locationManager.delegate = locationDelegate
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    private func setupMotionManager() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.5
        }
    }

    func startMonitoring() {
        requestLocationPermission()
        startHeadingUpdates()
    }

    func stopMonitoring() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        motionManager.stopDeviceMotionUpdates()
    }

    private func requestLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            // Don't show error, just continue without location
            print("Location permission denied - continuing without GPS")
        @unknown default:
            break
        }
    }

    private func startHeadingUpdates() {
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }

        if motionManager.isDeviceMotionAvailable {
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
                if let motion = motion {
                    let heading = motion.attitude.yaw * 180 / .pi
                    self?.heading = heading < 0 ? heading + 360 : heading
                }
            }
        }
    }

    private func simulateRadarContacts() {
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.detectedContacts = Int.random(in: 0...5)
            }
        }
    }
}

private class LocationDelegate: NSObject, CLLocationManagerDelegate {
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

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    }
}

enum LocationError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location permission denied. Enable in Settings to use GPS features."
        }
    }
}