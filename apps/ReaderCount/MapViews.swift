// Where your readers are: a map with a circle on each town, bigger where more people read from.
// ReaderCount keeps only town, region and country names (never an IP address or exact place), so the app looks each
// town up once with Apple's geocoder and remembers where it is on this device.

import SwiftUI
import MapKit
import CoreLocation

struct Place: Codable, Hashable {
    let town: String
    let region: String
    let country: String
    let visitors: Int
    var key: String { "\(town)|\(region)|\(country)" }
}

struct Places: Codable {
    let places: [Place]
}

/// Town positions, looked up once and kept on this device.
@MainActor
final class PlaceFinder {
    static let shared = PlaceFinder()
    private var known: [String: [Double]] = (UserDefaults.standard.dictionary(forKey: "places") as? [String: [Double]]) ?? [:]
    private var missing: Set<String> = []
    private let geocoder = CLGeocoder()

    func cached(_ p: Place) -> CLLocationCoordinate2D? {
        known[p.key].flatMap { $0.count == 2 ? CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) : nil }
    }

    /// Looks up the towns not seen before, one at a time (Apple asks apps not to send many at once).
    func find(_ places: [Place]) async -> Bool {
        var found = false
        for p in places where known[p.key] == nil && !missing.contains(p.key) {
            let query = [p.town, p.region, Locale.current.localizedString(forRegionCode: p.country) ?? p.country].filter { !$0.isEmpty }.joined(separator: ", ")
            if let c = try? await geocoder.geocodeAddressString(query).first?.location?.coordinate {
                known[p.key] = [c.latitude, c.longitude]
                found = true
            } else {
                missing.insert(p.key)
            }
        }
        if found { UserDefaults.standard.set(known, forKey: "places") }
        return found
    }
}

struct ReaderMap: View {
    @Environment(Model.self) private var model
    var height: CGFloat = 320
    @State private var places: [Place] = []
    @State private var version = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Where your readers are", systemImage: "map").font(.rcHeadline)
                Spacer()
                if let top = places.first { Text("Most from \(top.town)").font(.rcCaption).foregroundStyle(.secondary) }
            }
            let top = Double(max(1, places.first?.visitors ?? 1))
            Map(initialPosition: .automatic, interactionModes: [.zoom, .pan]) {
                ForEach(places, id: \.key) { p in
                    if let c = PlaceFinder.shared.cached(p) {
                        Annotation(p.town, coordinate: c, anchor: .center) {
                            let size = 12 + 34 * sqrt(Double(p.visitors) / top)
                            Circle()
                                .fill(Color.accentColor.opacity(0.35))
                                .overlay(Circle().stroke(Color.accentColor, lineWidth: 1.5))
                                .frame(width: size, height: size)
                                .help("\(p.town): \(p.visitors) visitors")
                        }
                        .annotationTitles(.hidden)
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .id(version)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            if places.isEmpty {
                Text("Towns show here once readers arrive.").font(.rcCallout).foregroundStyle(.secondary)
            }
        }
        .card()
        .task(id: model.current + model.period.rawValue) {
            places = await model.places()
            version += 1
            if await PlaceFinder.shared.find(Array(places.prefix(40))) { version += 1 }
        }
    }
}
