import CoreLocation

@MainActor
protocol LocationService: Sendable {
    var isAuthorized: Bool { get }
    func requestAuthorization() async -> Bool
    func getCurrentLocation() async throws -> CLLocation
    func reverseGeocode(_ location: CLLocation) async throws -> String
}

@MainActor
final class DefaultLocationService: NSObject, LocationService {
    static let shared = DefaultLocationService()

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    private var authorizationContinuation: CheckedContinuation<Bool, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    var isAuthorized: Bool {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestAuthorization() async -> Bool {
        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                authorizationContinuation = continuation
                locationManager.requestWhenInUseAuthorization()
            }
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    func getCurrentLocation() async throws -> CLLocation {
        if !isAuthorized {
            let authorized = await requestAuthorization()
            if !authorized {
                throw LocationError.notAuthorized
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    func reverseGeocode(_ location: CLLocation) async throws -> String {
        let placemarks = try await geocoder.reverseGeocodeLocation(location)

        guard let placemark = placemarks.first else {
            throw LocationError.geocodingFailed
        }

        var addressComponents: [String] = []

        if let thoroughfare = placemark.thoroughfare {
            addressComponents.append(thoroughfare)
        }

        if let subThoroughfare = placemark.subThoroughfare {
            if !addressComponents.isEmpty {
                addressComponents[0] = "\(addressComponents[0]) \(subThoroughfare)"
            } else {
                addressComponents.append(subThoroughfare)
            }
        }

        if let subLocality = placemark.subLocality {
            addressComponents.append(subLocality)
        }

        if let locality = placemark.locality {
            addressComponents.append(locality)
        }

        return addressComponents.joined(separator: ", ")
    }
}

// MARK: - CLLocationManagerDelegate

extension DefaultLocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            let authorized = status == .authorizedWhenInUse || status == .authorizedAlways
            authorizationContinuation?.resume(returning: authorized)
            authorizationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            if let location = locations.first {
                locationContinuation?.resume(returning: location)
                locationContinuation = nil
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationContinuation?.resume(throwing: error)
            locationContinuation = nil
        }
    }
}

// MARK: - Location Error

enum LocationError: LocalizedError {
    case notAuthorized
    case locationUnavailable
    case geocodingFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Location access not authorized"
        case .locationUnavailable:
            return "Unable to get current location"
        case .geocodingFailed:
            return "Unable to get address for location"
        }
    }
}
