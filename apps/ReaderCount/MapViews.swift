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
            do {
                if let c = try await geocoder.geocodeAddressString(query).first?.location?.coordinate {
                    known[p.key] = [c.latitude, c.longitude]
                    found = true
                } else {
                    missing.insert(p.key)
                }
            } catch {
                let code = (error as? CLError)?.code
                if code == .geocodeFoundNoResult || code == .geocodeFoundPartialResult { missing.insert(p.key); continue }
                break // Apple is asking us to slow down, or there's no network: try the rest next time.
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
    @State private var camera: MapCameraPosition = .automatic
    @State private var focus: String?

    struct Located: Identifiable {
        let place: Place
        let coord: CLLocationCoordinate2D
        var id: String { place.key }
    }

    private var located: [Located] {
        places.compactMap { p in PlaceFinder.shared.cached(p).map { Located(place: p, coord: $0) } }
    }

    /// Opens on the busiest area: the top town and the towns near it, not the whole world.
    private func busiest() -> MapCameraPosition {
        let pts = located
        guard let first = pts.first?.coord else { return .automatic }
        let near = pts.prefix(15).map(\.coord).filter { abs($0.latitude - first.latitude) < 12 && abs($0.longitude - first.longitude) < 18 }
        let lats = near.map(\.latitude), lons = near.map(\.longitude)
        let span = MKCoordinateSpan(latitudeDelta: max(4, (lats.max()! - lats.min()!) * 1.5), longitudeDelta: max(5, (lons.max()! - lons.min()!) * 1.5))
        let centre = CLLocationCoordinate2D(latitude: (lats.max()! + lats.min()!) / 2, longitude: (lons.max()! + lons.min()!) / 2)
        return .region(MKCoordinateRegion(center: centre, span: span))
    }

    private func zoom(to p: Place) {
        guard let c = PlaceFinder.shared.cached(p) else { return }
        focus = p.key
        withAnimation { camera = .region(MKCoordinateRegion(center: c, span: MKCoordinateSpan(latitudeDelta: 1.2, longitudeDelta: 1.6))) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Where your readers are", systemImage: "map").font(.rcHeadline)
                Spacer()
                Button { focus = nil; withAnimation { camera = busiest() } } label: { Label("Busiest area", systemImage: "scope") }
                    .buttonStyle(.bordered).controlSize(.small)
                Button { focus = nil; withAnimation { camera = .automatic } } label: { Label("Whole world", systemImage: "globe.europe.africa") }
                    .buttonStyle(.bordered).controlSize(.small)
            }
            Text("Each circle is a town your readers came from. The bigger the circle, the more readers. Pick a town to zoom in.")
                .font(.rcCaption).foregroundStyle(.secondary)
            let top = Double(max(1, places.first?.visitors ?? 1))
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    map(top).frame(minWidth: 420)
                    townList.frame(width: 240)
                }
                VStack(alignment: .leading, spacing: 12) {
                    map(top)
                    townList
                }
            }
            if places.isEmpty {
                Text("Towns show here once readers arrive.").font(.rcCallout).foregroundStyle(.secondary)
            }
        }
        .card()
        .task(id: model.current + model.datesKey) {
            places = await model.places()
            version += 1
            camera = busiest()
            if await PlaceFinder.shared.find(Array(places.prefix(40))) {
                version += 1
                if focus == nil { camera = busiest() }
            }
        }
    }

    private func map(_ top: Double) -> some View {
        Map(position: $camera, interactionModes: [.zoom, .pan]) {
            ForEach(located) { item in
                let p = item.place, c = item.coord
                Annotation(p.town, coordinate: c, anchor: .center) {
                    let share = sqrt(Double(p.visitors) / top)
                    let size = 16 + 38 * share
                    ZStack {
                        Circle().fill(Color.orange.opacity(0.25 + 0.5 * share))
                        Circle().strokeBorder(.white, lineWidth: 1.5)
                        if size >= 30 { Text(Num.short(p.visitors)).font(.caption2.bold()).foregroundStyle(.white) }
                    }
                    .frame(width: size, height: size)
                    .scaleEffect(focus == p.key ? 1.25 : 1)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    .help("\(p.town): \(p.visitors) visitors")
                    .onTapGesture { zoom(to: p) }
                }
                .annotationTitles(focus == p.key ? .visible : .hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .id(version)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var townList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Top towns").font(.rcCaption.bold()).foregroundStyle(.secondary)
            ForEach(places.prefix(8), id: \.key) { p in
                Button { zoom(to: p) } label: {
                    HStack(spacing: 8) {
                        Text(Num.flag(p.country))
                        Text(p.town.ifEmpty(p.country)).lineLimit(1)
                        Spacer(minLength: 4)
                        Text(Num.short(p.visitors)).monospacedDigit().foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                    }
                    .font(.rcCallout)
                    .padding(.vertical, 5).padding(.horizontal, 8)
                    .background(focus == p.key ? Color.orange.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
