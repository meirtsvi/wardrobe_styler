// Wear window from WeatherKit on device (PLAN §5.7, ADR 0001), with manual entry when the entitlement or location is missing.
import CoreLocation
import Domain
import SwiftUI
import WeatherKit

struct WeatherState {
    var minC: Double = 16
    var maxC: Double = 22
    var precip: Double = 10
    var city: String? = nil
    var source: String = "manual"
    var weekWindows: [WearWindow] = []
    var window: WearWindow { WearWindow(minFeelsLikeC: minC, maxFeelsLikeC: maxC, precipProbMax: precip) }
}

struct WeatherControls: View {
    @Binding var state: WeatherState
    @State private var fetching = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(state.source == "manual" ? "Weather (manual)" : "Weather · \(state.city ?? "here")").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Button(fetching ? "Fetching…" : "Use my location") { Task { await fetch() } }.font(.caption).disabled(fetching)
            }
            HStack {
                Text("Low \(Int(state.minC))°").frame(width: 70, alignment: .leading)
                Slider(value: $state.minC, in: -15...40, step: 1) { _ in if state.maxC < state.minC { state.maxC = state.minC } }
            }
            HStack {
                Text("High \(Int(state.maxC))°").frame(width: 70, alignment: .leading)
                Slider(value: $state.maxC, in: -15...45, step: 1) { _ in if state.minC > state.maxC { state.minC = state.maxC } }
            }
            HStack {
                Text("Rain \(Int(state.precip))%").frame(width: 70, alignment: .leading)
                Slider(value: $state.precip, in: 0...100, step: 5)
            }
            if let error { Text(error).font(.caption2).foregroundStyle(.orange) }
        }
    }

    private func fetch() async {
        fetching = true
        defer { fetching = false }
        do {
            let loc = try await LocationOnce().location()
            let window = try await WearWindowProvider.window(at: loc)
            state.minC = window.minFeelsLikeC.rounded(); state.maxC = window.maxFeelsLikeC.rounded(); state.precip = window.precipProbMax
            state.city = await WearWindowProvider.city(at: loc)
            state.weekWindows = (try? await WearWindowProvider.weekWindows(at: loc)) ?? []
            state.source = "weatherkit"
            error = nil
        } catch {
            self.error = "WeatherKit unavailable (needs the capability + a signed build): \(error.localizedDescription)"
        }
    }
}

enum WearWindowProvider {
    /// Wear window 07:00–20:00 local from the hourly forecast: min/max apparent temperature, max precipitation chance.
    static func window(at location: CLLocation, start: Int = 7, end: Int = 20) async throws -> WearWindow {
        let weather = try await WeatherService.shared.weather(for: location, including: .hourly)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let hours = weather.forecast.filter { h in
            let hour = cal.component(.hour, from: h.date)
            return cal.isDate(h.date, inSameDayAs: today) && hour >= start && hour <= end
        }
        guard !hours.isEmpty else { throw NSError(domain: "weather", code: 1, userInfo: [NSLocalizedDescriptionKey: "no hours in the wear window"]) }
        let temps = hours.map { $0.apparentTemperature.converted(to: .celsius).value }
        let precip = hours.map { $0.precipitationChance * 100 }.max() ?? 0
        let wind = hours.map { $0.wind.speed.converted(to: .kilometersPerHour).value }.max()
        return WearWindow(minFeelsLikeC: temps.min()!, maxFeelsLikeC: temps.max()!, precipProbMax: precip, windMax: wind)
    }

    /// Daily high/low + precipitation chance for the next 7 days (WeatherKit daily forecast has no apparent temperature; use actual).
    static func weekWindows(at location: CLLocation) async throws -> [WearWindow] {
        let weather = try await WeatherService.shared.weather(for: location, including: .daily)
        return weather.forecast.prefix(7).map { d in
            WearWindow(minFeelsLikeC: d.lowTemperature.converted(to: .celsius).value, maxFeelsLikeC: d.highTemperature.converted(to: .celsius).value, precipProbMax: d.precipitationChance * 100)
        }
    }

    static func city(at location: CLLocation) async -> String? {
        (try? await CLGeocoder().reverseGeocodeLocation(location))?.first?.locality
    }
}

/// One-shot when-in-use location (PLAN §4.14: manual city stays available when denied).
final class LocationOnce: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    func location() async throws -> CLLocation {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        return try await withCheckedThrowingContinuation { c in
            continuation = c
            manager.requestLocation()
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let l = locations.last { continuation?.resume(returning: l); continuation = nil }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(throwing: error); continuation = nil
    }
}
