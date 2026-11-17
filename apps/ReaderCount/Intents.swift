// Siri and Shortcuts: "How many readers today in ReaderCount?", "Who's on my website in ReaderCount?" and
// "What's my top post in ReaderCount?". Each answers from the same /app/v1/ the app uses.

import AppIntents

struct ReadersToday: AppIntent {
    static var title: LocalizedStringResource = "Readers today"
    static var description = IntentDescription("How many people have visited your websites today.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let s = try await API.shared.get(SitesSummary.self, "app/v1/sites")
        s.save()
        guard !s.sites.isEmpty else { return .result(dialog: "You haven't added a website to ReaderCount yet.") }
        if s.sites.count == 1, let one = s.sites.first {
            return .result(dialog: "\(one.today) visitors on \(one.site) today, and \(one.on_site_now) reading now.")
        }
        return .result(dialog: "\(s.totalToday) visitors today across your \(s.sites.count) websites, and \(s.totalNow) reading now.")
    }
}

struct ReadingNow: AppIntent {
    static var title: LocalizedStringResource = "Reading now"
    static var description = IntentDescription("How many people are on your websites right now.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let s = try await API.shared.get(SitesSummary.self, "app/v1/sites")
        s.save()
        return .result(dialog: s.totalNow == 1 ? "1 person is reading right now." : "\(s.totalNow) people are reading right now.")
    }
}

struct TopPost: AppIntent {
    static var title: LocalizedStringResource = "Top post this week"
    static var description = IntentDescription("Your most read page over the last 7 days.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let me = try await API.shared.get(Me.self, "app/v1/me")
        let saved = Shared.defaults.string(forKey: "site") ?? ""
        guard let site = me.sites.contains(saved) ? saved : me.sites.first else { return .result(dialog: "You haven't added a website to ReaderCount yet.") }
        let o = try await API.shared.get(Overview.self, "app/v1/overview", ["site": site, "period": "7d"])
        guard let top = o.top_pages.first else { return .result(dialog: "No visits on \(site) in the last 7 days yet.") }
        return .result(dialog: "Your top page on \(site) this week is \(top.page), with \(top.visitors) visitors.")
    }
}

struct ReaderCountShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ReadersToday(), phrases: ["How many readers today in \(.applicationName)", "Readers today in \(.applicationName)"], shortTitle: "Readers today", systemImageName: "person.2")
        AppShortcut(intent: ReadingNow(), phrases: ["Who's reading now in \(.applicationName)", "Who's on my website in \(.applicationName)"], shortTitle: "Reading now", systemImageName: "dot.radiowaves.left.and.right")
        AppShortcut(intent: TopPost(), phrases: ["What's my top post in \(.applicationName)", "Top post this week in \(.applicationName)"], shortTitle: "Top post", systemImageName: "doc.richtext")
    }
}
