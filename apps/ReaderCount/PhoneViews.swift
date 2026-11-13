// iPhone and iPad: five tabs (Today, Live, Health, More, Account). On iPad from iPadOS 18 the tabs become a sidebar,
// like the website's left menu.

#if os(iOS)
import SwiftUI

struct PhoneRoot: View {
    @Environment(Model.self) private var model
    @State private var tab = Demo.tab ?? "today"

    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                TabView(selection: $tab) {
                    Tab("Today", systemImage: "chart.xyaxis.line", value: "today") { screen("Today") { TodayContent(columns: 2) } }
                    Tab("Live", systemImage: "dot.radiowaves.left.and.right", value: "live") { screen("Live") { LiveContent() } }
                    Tab("Health", systemImage: "stethoscope", value: "health") { screen("Site Health") { HealthContent() } }
                    Tab("More", systemImage: "square.grid.2x2", value: "more") { MoreView() }
                    Tab("Account", systemImage: "person.crop.circle", value: "account") { AccountView() }
                }
                .tabViewStyle(.sidebarAdaptable)
            } else {
                TabView(selection: $tab) {
                    screen("Today") { TodayContent(columns: 2) }.tabItem { Label("Today", systemImage: "chart.xyaxis.line") }.tag("today")
                    screen("Live") { LiveContent() }.tabItem { Label("Live", systemImage: "dot.radiowaves.left.and.right") }.tag("live")
                    screen("Site Health") { HealthContent() }.tabItem { Label("Health", systemImage: "stethoscope") }.tag("health")
                    MoreView().tabItem { Label("More", systemImage: "square.grid.2x2") }.tag("more")
                    AccountView().tabItem { Label("Account", systemImage: "person.crop.circle") }.tag("account")
                }
            }
        }
        .task {
            await model.refresh()
            // The numbers refresh by themselves every 30 seconds while the app is open, as on the website.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                await model.refresh()
            }
        }
    }

    private func screen<C: View>(_ title: String, @ViewBuilder _ content: @escaping () -> C) -> some View {
        NavigationStack {
            ScrollView {
                content().padding()
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
            }
            .refreshable { await model.refresh(); await model.loadLive(); await model.loadHealth() }
            .navigationTitle(title)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { SitePicker() } }
        }
    }
}

struct MoreView: View {
    @Environment(Model.self) private var model

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(MoreItem.allCases) { item in
                        NavigationLink {
                            ScrollView { item.content.padding().frame(maxWidth: 760).frame(maxWidth: .infinity) }
                                .navigationTitle(item.title)
                                .toolbar { ToolbarItem(placement: .topBarTrailing) { SitePicker() } }
                        } label: {
                            Label(item.title, systemImage: item.icon)
                        }
                    }
                }
                Section {
                    Link(destination: Shared.app) { Label("Open your stats on the website", systemImage: "safari") }
                } footer: {
                    Text("Adding a website, the tracking code, earnings and API keys are on the website.")
                }
            }
            .navigationTitle("More")
        }
    }
}

struct AccountView: View {
    @Environment(Model.self) private var model

    var body: some View {
        NavigationStack {
            List {
                Section("Signed in as") {
                    Label(model.me?.email ?? "…", systemImage: "person.crop.circle")
                    if let p = model.me?.plan { Label("\(p.name) plan", systemImage: "star") }
                }
                Section {
                    ForEach(model.summary?.sites ?? []) { s in
                        HStack {
                            Text(s.site)
                            Spacer()
                            Text("\(s.today) today").foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                } header: {
                    Text("Your websites")
                }
                Section {
                    AlertsSettings()
                } header: {
                    Text("Alerts on this device")
                } footer: {
                    Text("Alerts come as a notification on this device, as well as any emails you've chosen on the website.")
                }
                Section {
                    Link(destination: URL(string: "https://readercount.com/help/")!) { Label("Help guides", systemImage: "book") }
                    Link(destination: URL(string: "mailto:hello@readercount.com")!) { Label("Email us", systemImage: "envelope") }
                    Link(destination: URL(string: "https://readercount.com/privacy/")!) { Label("Privacy", systemImage: "hand.raised") }
                }
                Section {
                    Button(role: .destructive) {
                        Task { await model.signOut() }
                    } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Account")
        }
    }
}
#endif
