// The app's state: who is signed in, the websites, the chosen website and dates, and what each screen shows.

import SwiftUI
import UserNotifications
import WidgetKit
import AuthenticationServices

enum Period: String, CaseIterable, Identifiable {
    case today, week = "7d", month = "30d", year = "12m"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .today: "Today"
        case .week: "7 days"
        case .month: "30 days"
        case .year: "12 months"
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
    var overview: Overview?
    var live: Live?
    var health: Health?
    var error: String?
    var busy = false
    /// Push alerts: what the person allowed in Settings, and which alerts this device gets.
    var pushAllowed: Bool?
    var alerts: [String: Bool] = (Shared.defaults.dictionary(forKey: "alerts") as? [String: Bool]) ?? ["spike": true, "down": true, "triggers": true, "links": true, "daily": false, "monthly": true]
    private var deviceToken: String?

    var sites: [String] { me?.sites ?? summary?.sites.map(\.site) ?? [] }
    var current: String { sites.contains(site) ? site : (sites.first ?? "") }
    var liveCount: Int { summary?.totalNow ?? 0 }

    // MARK: Signing in and out

    /// Opens ReaderCount's own sign in page in Apple's secure sheet (email code or passkey), then saves the tokens.
    func signIn(using session: WebAuthenticationSession) async {
        let pkce = PKCE()
        busy = true
        defer { busy = false }
        do {
            let back = try await session.authenticate(using: pkce.authorizeURL, callbackURLScheme: "readercount", preferredBrowserSession: .ephemeral)
            try await API.shared.finishSignIn(callback: back, pkce: pkce)
            signedIn = true
            error = nil
            await refresh()
            await askForPush()
        } catch let e as ASWebAuthenticationSessionError where e.code == .canceledLogin {
            // They closed the sheet.
        } catch {
            self.error = error.localizedDescription
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
        if let a = e as? APIError, a.signedOut {
            Tokens.clear()
            signedIn = false
        }
        error = e.localizedDescription
    }

    // MARK: Loading

    /// Everything the open screen needs. Called on opening, pull to refresh and every 30 seconds.
    func refresh() async {
        guard signedIn else { return }
        do {
            async let m = API.shared.get(Me.self, "app/v1/me")
            async let s = API.shared.get(SitesSummary.self, "app/v1/sites")
            me = try await m
            let sum = try await s
            summary = sum
            sum.save()
            WidgetCenter.shared.reloadAllTimelines()
            error = nil
            if !current.isEmpty { await loadOverview() }
        } catch {
            handle(error)
        }
    }

    func loadOverview() async {
        guard !current.isEmpty else { return }
        do { overview = try await API.shared.get(Overview.self, "app/v1/overview", ["site": current, "period": period.rawValue]) } catch { handle(error) }
    }

    func loadLive() async {
        guard !current.isEmpty else { return }
        do { live = try await API.shared.get(Live.self, "app/v1/live", ["site": current]) } catch { handle(error) }
    }

    func loadHealth() async {
        guard !current.isEmpty else { return }
        do { health = try await API.shared.get(Health.self, "app/v1/health", ["site": current, "period": period.rawValue]) } catch { handle(error) }
    }

    func breakdown(_ by: String, clicks: Bool = false) async -> Breakdown? {
        guard !current.isEmpty else { return nil }
        var q = ["site": current, "by": by, "period": period.rawValue, "limit": "50"]
        if clicks { q["of"] = "clicks" }
        do { return try await API.shared.get(Breakdown.self, "app/v1/breakdown", q) } catch { handle(error); return nil }
    }

    func searches(by: String = "query") async -> (Searches?, String?) {
        guard !current.isEmpty else { return (nil, nil) }
        do { return (try await API.shared.get(Searches.self, "app/v1/google-searches", ["site": current, "by": by, "period": period.rawValue]), nil) } catch { return (nil, error.localizedDescription) }
    }

    func trails(day: String? = nil) async -> Trails? {
        guard !current.isEmpty else { return nil }
        var q = ["site": current]
        if let day { q["day"] = day }
        do { return try await API.shared.get(Trails.self, "app/v1/trails", q) } catch { handle(error); return nil }
    }

    func markFixed(_ item: Health.Item, undo: Bool = false) async {
        guard let key = item.key else { return }
        do {
            try await API.shared.send("app/v1/health/fixed", ["site": current, "key": key, "title": item.title, "undo": undo])
            await loadHealth()
        } catch { handle(error) }
    }

    // MARK: Push alerts

    func askForPush() async {
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
