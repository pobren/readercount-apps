// What app.readercount.com/app/v1/ answers, decoded. Field names follow the JSON (snake_case).

import Foundation

struct Me: Codable {
    struct Plan: Codable { let name: String; let pro: Bool; let agency: Bool; let sites: Int; let views: Int }
    let email: String
    let plan: Plan
    let sites: [String]
    let devices: Int
}

/// Every website's headline numbers: the widgets, the Mac menu bar and the site list.
struct SitesSummary: Codable {
    struct Site: Codable, Hashable, Identifiable {
        let site: String
        let on_site_now: Int
        let today: Int
        let week: Int
        let last_week: Int
        let views_week: Int
        let days: [Int]
        let top_source: String
        var id: String { site }

        /// "+12%" against the week before, or nil when there's nothing to compare.
        var change: Int? {
            guard last_week > 0 else { return nil }
            return Int(((Double(week) - Double(last_week)) / Double(last_week) * 100).rounded())
        }
    }
    let sites: [Site]
    let month_views: Int?
    var updated: Date?

    var totalNow: Int { sites.reduce(0) { $0 + $1.on_site_now } }
    var totalToday: Int { sites.reduce(0) { $0 + $1.today } }

    static let sample = SitesSummary(sites: [
        Site(site: "myblog.com", on_site_now: 7, today: 412, week: 2_981, last_week: 2_604, views_week: 4_420, days: [310, 298, 402, 388, 451, 377, 412, 395, 420, 386, 444, 470, 433, 412], top_source: "Google"),
        Site(site: "recipes.example", on_site_now: 2, today: 96, week: 701, last_week: 744, views_week: 1_030, days: [90, 101, 99, 120, 88, 92, 96, 97, 110, 91, 104, 99, 105, 96], top_source: "Pinterest"),
    ], month_views: 18_204, updated: Date())

    func save() {
        var s = self
        s.updated = Date()
        if let d = try? JSONEncoder().encode(s) { Shared.defaults.set(d, forKey: "summary") }
    }

    static func load() -> SitesSummary? {
        guard let d = Shared.defaults.data(forKey: "summary") else { return nil }
        return try? JSONDecoder().decode(SitesSummary.self, from: d)
    }

    static func clear() { Shared.defaults.removeObject(forKey: "summary") }
}

struct Overview: Codable {
    struct Totals: Codable { let visitors: Int; let views: Int; let avg_seconds: Int?; let bounce_percent: Int?; let on_site_now: Int? }
    struct Previous: Codable { let visitors: Int; let views: Int }
    struct Day: Codable, Hashable { let day: String; let views: Int; let visitors: Int; let hour: Int? }
    struct Page: Codable, Hashable { let page: String; let visitors: Int; let views: Int; let avg_seconds: Int? }
    struct Source: Codable, Hashable { let source: String; let visitors: Int }
    struct Country: Codable, Hashable { let country: String; let visitors: Int }
    struct Device: Codable, Hashable { let device: String; let visitors: Int }
    struct Browser: Codable, Hashable { let browser: String; let visitors: Int }
    struct Campaign: Codable, Hashable { let campaign: String; let visitors: Int }
    struct Click: Codable, Hashable { let link: String; let type: String?; let page: String?; let clicks: Int }

    let site: String
    let period: String
    let from: String
    let to: String
    let totals: Totals
    let previous_period: Previous
    let per_day: [Day]
    let top_pages: [Page]
    let sources: [Source]
    let campaigns: [Campaign]
    let countries: [Country]
    let devices: [Device]
    let browsers: [Browser]
    let clicks: [Click]
}

struct LiveVisitor: Codable, Hashable {
    struct Step: Codable, Hashable { let ts: Double; let kind: String; let path: String; let target: String?; let seconds: Double }
    let country: String
    let town: String
    let region: String
    let device: String
    let browser: String
    let os: String
    let source: String
    let first: Double
    let last: Double
    let views: Int
    let page: String
    let away: Double
    let steps: [Step]
}

struct Live: Codable {
    struct Count: Codable, Hashable { let n: Int }
    struct PageNow: Codable, Hashable { let path: String; let n: Int }
    struct SourceNow: Codable, Hashable { let name: String; let n: Int }
    let site: String
    let total: Int
    let pages: [PageNow]
    let sources: [SourceNow]
    let visitors: [LiveVisitor]
}

struct Trails: Codable {
    let site: String
    let day: String
    let page: Int
    let total: Int
    let visitors: [LiveVisitor]
}

struct Health: Codable {
    struct Item: Codable, Hashable, Identifiable {
        let level: String
        let title: String
        let detail: String
        let links: [String]
        let key: String?
        var id: String { (key ?? "") + title }
    }
    struct Marked: Codable, Hashable { let key: String; let title: String; let marked_at: Double }
    struct Fix: Codable, Hashable, Identifiable {
        let kind: String
        let page: String
        let query: String?
        let what: String
        let todo: String
        var id: String { kind + page + (query ?? "") }
    }
    let site: String
    let health: [Item]
    let marked: [Marked]
    let what_to_fix: [Fix]
}

/// /app/v1/breakdown: each row is named by the thing it's grouped by ("town": "Leeds", "visitors": 12).
struct Breakdown: Decodable {
    struct Row: Hashable {
        let name: String
        let visitors: Int
        let views: Int?
        let clicks: Int?
        var count: Int { clicks ?? visitors }
    }
    let by: String
    let rows: [Row]

    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(_ s: String) { stringValue = s }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        by = try c.decode(String.self, forKey: Key("by"))
        var list = try c.nestedUnkeyedContainer(forKey: Key("rows"))
        var out: [Row] = []
        while !list.isAtEnd {
            let r = try list.nestedContainer(keyedBy: Key.self)
            let name = (try? r.decode(String.self, forKey: Key(by))) ?? (try? r.decode(Int.self, forKey: Key(by))).map(String.init) ?? ""
            out.append(Row(name: name.isEmpty ? "(none)" : name, visitors: (try? r.decode(Int.self, forKey: Key("visitors"))) ?? 0, views: try? r.decode(Int.self, forKey: Key("views")), clicks: try? r.decode(Int.self, forKey: Key("clicks"))))
        }
        rows = out
    }
}

struct Searches: Codable {
    struct Row: Codable, Hashable {
        let query: String?
        let page: String?
        let day: String?
        let clicks: Int
        let impressions: Int
        let position: Double?
        var name: String { query ?? page ?? day ?? "" }
    }
    let rows: [Row]
}

/// Plain numbers the way the website writes them: 1,234 and 12.3k.
enum Num {
    static func short(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fm", Double(n) / 1_000_000) }
        if n >= 10_000 { return String(format: "%.1fk", Double(n) / 1_000) }
        return n.formatted(.number)
    }

    static func time(_ seconds: Int?) -> String {
        guard let s = seconds, s > 0 else { return "0s" }
        return s >= 60 ? "\(s / 60)m \(s % 60)s" : "\(s)s"
    }

    static func flag(_ country: String) -> String {
        guard country.count == 2 else { return "🌍" }
        return country.uppercased().unicodeScalars.compactMap { UnicodeScalar(127_397 + $0.value) }.map(String.init).joined()
    }
}
