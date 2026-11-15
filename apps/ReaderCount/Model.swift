// The app's state: who is signed in, the websites, the chosen website and dates, and what each screen shows.

import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif
import UserNotifications
import WidgetKit

enum Period: String, CaseIterable, Identifiable {
    case today, week = "7d", month = "30d", year = "12m", custom
    var id: String { rawValue }
    var label: String {
        switch self {
        case .today: "Today"
        case .week: "7 days"
        case .month: "30 days"
        case .year: "12 months"
        case .custom: "Custom"
        }
    }
}

@MainActor @Observable
final class Model {
    static let shared = Model()

    var signedIn = Tokens.load() != nil
    var me: Me?
    var summary: SitesSummary? = SitesSummary.load()
    var site: String = Shared.defaults.string(forKey: "site") ?? "" {
        didSet { Shared.defaults.set(site, forKey: "site"); overview = nil; live = nil; health = nil }
    }
    var period: Period = Period(rawValue: Shared.defaults.string(forKey: "period") ?? "") ?? .week {
        didSet { Shared.defaults.set(period.rawValue, forKey: "period"); overview = nil }
    }
    /// Custom dates, kept on this device.
    var customFrom: Date = (Shared.defaults.object(forKey: "customFrom") as? Date) ?? Calendar.current.date(byAdding: .day, value: -13, to: .now)! {
        didSet { Shared.defaults.set(customFrom, forKey: "customFrom"); if period == .custom { overview = nil } }
    }
    var customTo: Date = (Shared.defaults.object(forKey: "customTo") as? Date) ?? .now {
        didSet { Shared.defaults.set(customTo, forKey: "customTo"); if period == .custom { overview = nil } }
    }
    /// The dates to ask the server for: a period, or from and to.
    var dates: [String: String] {
        guard period == .custom else { return ["period": period.rawValue] }
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_GB_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return ["period": "30d", "from": f.string(from: min(customFrom, customTo)), "to": f.string(from: max(customFrom, customTo))]
    }
    /// Changes whenever the dates do, so screens reload.
    var datesKey: String { dates.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "&") }
    /// Each website's favicon, for the website picker.
    var favicons: [String: Image] = [:]
    var overview: Overview?
    var live: Live?
    var health: Health?
    var error: String?
    var busy = false
    /// A sign-in code from the link in the code email, for the sign in screen to use.
    var codeLink: CodeLink?

    struct CodeLink: Equatable { let email: String; let code: String }

    func openLink(_ url: URL) {
        let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let isCode = (url.scheme == "readercount" && url.host == "code") || url.path == "/app/open/code"
        guard isCode, !signedIn else { return }
        let code = (q.first { $0.name == "c" }?.value ?? "").filter(\.isNumber)
        let email = q.first { $0.name == "e" }?.value ?? ""
        if code.count == 6 { codeLink = CodeLink(email: email, code: code) }
    }
    /// Push alerts: what the person allowed in Settings, and which alerts this device gets.
    var pushAllowed: Bool?
    var alerts: [String: Bool] = (Shared.defaults.dictionary(forKey: "alerts") as? [String: Bool]) ?? ["spike": true, "down": true, "triggers": true, "monthly": true]
    private var deviceToken: String?

    private init() {
        // Demo mode (screenshots, App Review): sample stats, no sign in, nothing sent anywhere.
        if Demo.on {
            signedIn = true
            me = Demo.me
            summary = .sample
            site = "myblog.com"
            overview = Demo.overview
            live = Demo.live
            health = Demo.health
            pushAllowed = true
        }
    }

    var sites: [String] { me?.sites ?? summary?.sites.map(\.site) ?? [] }
    var current: String { sites.contains(site) ? site : (sites.first ?? "") }
    var liveCount: Int { summary?.totalNow ?? 0 }

    // MARK: Signing in and out

    /// Signing in inside the app: the email gets a six-digit code (true when it was sent).
    func requestCode(email: String) async -> Bool {
        busy = true
        defer { busy = false }
        do {
            _ = try await API.shared.requestCode(email: email.trimmingCharacters(in: .whitespaces))
            error = nil
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    /// Then the code from the email, which saves the tokens.
    func signIn(email: String, code: String) async {
        busy = true
        defer { busy = false }
        do {
            try await API.shared.signIn(email: email.trimmingCharacters(in: .whitespaces), code: code.filter(\.isNumber))
            signedIn = true
            error = nil
            await refresh()
            await askForPush()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Or a passkey, as on the website.
    func signInWithPasskey() async {
        busy = true
        defer { busy = false }
        do {
            let c = try await API.shared.passkeyChallenge()
            let signed = try await PasskeySignIn().sign(challenge: c.challenge)
            try await API.shared.passkeySignIn(challengeId: c.id, response: signed)
            signedIn = true
            error = nil
            await refresh()
            await askForPush()
        } catch is CancellationError {
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Fetches each website's favicon once (through ReaderCount's own logo address).
    func loadFavicons() async {
        for site in sites where favicons[site] == nil {
            guard let url = URL(string: "https://app.readercount.com/logo/\(site)"),
                  let (data, response) = try? await URLSession.shared.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200 else { continue }
            #if os(macOS)
            if let img = NSImage(data: data) { img.size = NSSize(width: 16, height: 16); favicons[site] = Image(nsImage: img) }
            #else
            if let img = UIImage(data: data) {
                let small = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { _ in img.draw(in: CGRect(x: 0, y: 0, width: 20, height: 20)) }
                favicons[site] = Image(uiImage: small.withRenderingMode(.alwaysOriginal))
            }
            #endif
        }
    }

    func signOut() async {
        if let t = deviceToken { try? await API.shared.send("app/v1/devices", method: "DELETE", ["token": t]) }
        Tokens.clear()
        SitesSummary.clear()
        WidgetCenter.shared.reloadAllTimelines()
        signedIn = false
        me = nil
        summary = nil
        overview = nil
        live = nil
        health = nil
    }

    private func handle(_ e: Error) {
        // A request stopped because the screen changed isn't a problem worth showing.
        if e is CancellationError || Task.isCancelled { return }
        if let a = e as? APIError, a.signedOut {
            Tokens.clear()
            signedIn = false
        }
        error = e.localizedDescription
    }

    // MARK: Loading

    /// Everything the open screen needs. Called on opening, pull to refresh and every 30 seconds.
    func refresh() async {
        guard signedIn, !Demo.on else { return }
        do {
            async let m = API.shared.get(Me.self, "app/v1/me")
            async let s = API.shared.get(SitesSummary.self, "app/v1/sites")
            me = try await m
            let sum = try await s
            summary = sum
            sum.save()
            WidgetCenter.shared.reloadAllTimelines()
            error = nil
            Task { await loadFavicons() }
            if !current.isEmpty { await loadOverview() }
        } catch {
            handle(error)
        }
    }

    func loadOverview() async {
        if Demo.on { overview = Demo.overview; return }
        guard !current.isEmpty else { return }
        do { overview = try await API.shared.get(Overview.self, "app/v1/overview", ["site": current].merging(dates) { _, new in new }) } catch { handle(error) }
    }

    /// Towns with their region and country, for the map.
    func places() async -> [Place] {
        if Demo.on {
            return [Place(town: "London", region: "England", country: "GB", visitors: 402), Place(town: "Leeds", region: "England", country: "GB", visitors: 188),
                    Place(town: "Manchester", region: "England", country: "GB", visitors: 161), Place(town: "Dublin", region: "Leinster", country: "IE", visitors: 140),
                    Place(town: "New York City", region: "New York", country: "US", visitors: 120), Place(town: "Berlin", region: "Berlin", country: "DE", visitors: 64)]
        }
        guard !current.isEmpty else { return [] }
        return (try? await API.shared.get(Places.self, "app/v1/places", ["site": current].merging(dates) { _, new in new }))?.places ?? []
    }

    func loadLive() async {
        if Demo.on { live = Demo.live; return }
        guard !current.isEmpty else { return }
        do {
            live = try await API.shared.get(Live.self, "app/v1/live", ["site": current])
            error = nil
        } catch { handle(error) }
    }

    /// fresh skips the server's 30 second copy, so a change (such as Mark as fixed) shows at once.
    func loadHealth(fresh: Bool = false) async {
        if Demo.on { health = Demo.health; return }
        guard !current.isEmpty else { return }
        var q = ["site": current].merging(dates) { _, new in new }
        if fresh { q["fresh"] = String(Int(Date.now.timeIntervalSince1970 * 1000)) }
        do { health = try await API.shared.get(Health.self, "app/v1/health", q) } catch { handle(error) }
    }

    func breakdown(_ by: String, clicks: Bool = false, filters: [String: String] = [:]) async -> Breakdown? {
        if Demo.on, let o = Demo.overview {
            let rows: [(String, Int)] = switch by {
            case "country": o.countries.map { ($0.country, $0.visitors) }
            case "device": o.devices.map { ($0.device, $0.visitors) }
            case "browser": o.browsers.map { ($0.browser, $0.visitors) }
            case "campaign": o.campaigns.map { ($0.campaign, $0.visitors) }
            case "link": o.clicks.map { ($0.link, $0.clicks) }
            case "town": [("London", 402), ("Leeds", 188), ("Manchester", 161), ("Dublin", 140), ("Bristol", 97)]
            case "page": o.top_pages.map { ($0.page, $0.visitors) }
            case "day": o.per_day.map { ($0.day, $0.visitors) }
            default: o.sources.map { ($0.source, $0.visitors) }
            }
            let json = try? JSONSerialization.data(withJSONObject: ["by": by, "rows": rows.map { [by: $0.0, "visitors": $0.1] }])
            return json.flatMap { try? JSONDecoder().decode(Breakdown.self, from: $0) }
        }
        guard !current.isEmpty else { return nil }
        var q = ["site": current, "by": by, "limit": "50"].merging(dates) { _, new in new }
        if clicks { q["of"] = "clicks" }
        q.merge(filters) { _, new in new }
        do { return try await API.shared.get(Breakdown.self, "app/v1/breakdown", q) } catch { handle(error); return nil }
    }

    func searches(by: String = "query") async -> (Searches?, String?) {
        if Demo.on {
            let rows: [[String: Any]] = [["query": "best email hosting uk", "clicks": 61, "impressions": 4120, "position": 6.2], ["query": "proton mail review", "clicks": 48, "impressions": 1980, "position": 4.1], ["query": "how to set up dmarc", "clicks": 37, "impressions": 2210, "position": 7.8], ["query": "fastmail vs gmail", "clicks": 12, "impressions": 1460, "position": 11.3]]
            let json = try? JSONSerialization.data(withJSONObject: ["rows": rows])
            return (json.flatMap { try? JSONDecoder().decode(Searches.self, from: $0) }, nil)
        }
        guard !current.isEmpty else { return (nil, nil) }
        do { return (try await API.shared.get(Searches.self, "app/v1/google-searches", ["site": current, "by": by].merging(dates) { _, new in new }), nil) } catch { return (nil, error.localizedDescription) }
    }

    func trails(day: String? = nil, page: Int = 1) async -> Trails? {
        if Demo.on, let l = Demo.live { return Trails(site: current, day: day ?? "", page: 1, total: l.visitors.count, visitors: l.visitors) }
        guard !current.isEmpty else { return nil }
        var q = ["site": current, "page": String(page)]
        if let day { q["day"] = day }
        do { return try await API.shared.get(Trails.self, "app/v1/trails", q) } catch { handle(error); return nil }
    }

    func markFixed(_ item: Health.Item, undo: Bool = false) async {
        if Demo.on { return }
        guard let key = item.key else { return }
        do {
            try await API.shared.send("app/v1/health/fixed", ["site": current, "key": key, "title": item.title, "undo": undo])
            await loadHealth(fresh: true)
        } catch { handle(error) }
    }

    // MARK: Push alerts

    func askForPush() async {
        if Demo.on { return }
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        pushAllowed = granted
        guard granted else { return }
        #if os(iOS)
        UIApplication.shared.registerForRemoteNotifications()
        #else
        NSApplication.shared.registerForRemoteNotifications()
        #endif
    }

    func checkPushAllowed() async {
        if Demo.on { pushAllowed = true; return }
        let s = await UNUserNotificationCenter.current().notificationSettings()
        pushAllowed = s.authorizationStatus == .authorized || s.authorizationStatus == .provisional
    }

    func gotDeviceToken(_ data: Data) async {
        deviceToken = data.map { String(format: "%02x", $0) }.joined()
        await sendDevice()
    }

    func setAlert(_ key: String, _ on: Bool) async {
        alerts[key] = on
        Shared.defaults.set(alerts, forKey: "alerts")
        await sendDevice()
    }

    private func sendDevice() async {
        guard signedIn, let t = deviceToken else { return }
        #if os(iOS)
        let platform = "ios", name = UIDevice.current.name
        #else
        let platform = "macos", name = Host.current().localizedName ?? "Mac"
        #endif
        #if DEBUG
        let sandbox = true
        #else
        let sandbox = false
        #endif
        let body: [String: Any] = ["token": t, "platform": platform, "name": name, "sandbox": sandbox, "alerts": alerts.mapValues { $0 ? 1 : 0 }]
        try? await API.shared.send("app/v1/devices", body)
    }
}
