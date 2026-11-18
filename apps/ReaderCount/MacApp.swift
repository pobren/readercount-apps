// The Mac app: a window with the same foldable left menu as the website, and a live count in the menu bar.
// Mac design rules (as Site Patrol): one content width, flat cards, soft icons, one brand blue.
// Everything here is inside #if os(macOS), or the iPhone build fails.

#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

enum MacPane: String, CaseIterable, Identifiable, Hashable {
    case overview, live, health, trails, alerts, housekeeping, google, sources, clicks, countries, devices, browsers, campaigns, account
    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: "Overview"
        case .live: "Live"
        case .health: "Site Health"
        case .account: "Account"
        default: MoreItem(rawValue: rawValue)?.title ?? rawValue
        }
    }
    var icon: String {
        switch self {
        case .overview: "chart.xyaxis.line"
        case .live: "dot.radiowaves.left.and.right"
        case .health: "stethoscope"
        case .account: "person.crop.circle"
        default: MoreItem(rawValue: rawValue)?.icon ?? "circle"
        }
    }
}

struct MacRoot: View {
    @Environment(Model.self) private var model
    @State private var pane: MacPane? = Demo.tab.flatMap { MacPane(rawValue: $0 == "today" ? "overview" : $0) } ?? .overview

    var body: some View {
        NavigationSplitView {
            List(selection: $pane) {
                // The two "how are things right now" rows sit at the very top, each with its light:
                // Live is green when readers are on now; Site Health is green, amber or red.
                Section {
                    LiveMenuRow(count: liveHere).tag(MacPane.live)
                    HealthMenuRow(light: healthLight).tag(MacPane.health)
                }
                Section("Stats") {
                    ForEach([MacPane.overview, .trails, .sources, .google, .clicks, .countries, .devices, .browsers, .campaigns]) { p in Label(p.title, systemImage: p.icon).tag(p) }
                }
                Section("More") {
                    ForEach([MacPane.alerts, .housekeeping, .account]) { p in Label(p.title, systemImage: p.icon).tag(p) }
                    Link(destination: Shared.app) { Label("Website", systemImage: "safari") }
                        .foregroundStyle(.primary)
                    Button {
                        Task { await model.signOut() }
                    } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
            .safeAreaInset(edge: .bottom) { AccountFooter() }
        } detail: {
            NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    detail
                }
                .padding(24)
                .font(.rcBody)
                .controlSize(.large)
                .frame(maxWidth: 1040)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(pane?.title ?? "ReaderCount")
            .toolbar {
                ToolbarItem { SitePicker() }
                ToolbarItem {
                    Button {
                        Task { model.bumpReload(force: true); await model.refresh(); await model.loadLive(); await model.loadHealth() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .keyboardShortcut("r")
                }
            }
            }
            .id(pane)
        }
        .task { await model.refresh() }
        .task(id: model.current) { await model.loadHealth() }
    }

    private var liveHere: Int { model.summary?.sites.first { $0.site == model.current }?.on_site_now ?? 0 }

    /// Red if something needs fixing, amber for warnings, green when all is well (nil before it loads).
    private var healthLight: Color? {
        guard let h = model.health, h.site == model.current else { return nil }
        if h.health.contains(where: { $0.level == "fix" }) { return .red }
        return h.health.isEmpty ? .green : .orange
    }

    @ViewBuilder private var detail: some View {
        switch pane ?? .overview {
        case .overview: TodayContent(columns: 4)
        case .live: LiveContent()
        case .health: HealthContent()
        case .account:
            Form { AccountSections() }.formStyle(.grouped).scrollDisabled(true).frame(minHeight: 760)
        default:
            if let item = MoreItem(rawValue: (pane ?? .overview).rawValue) { item.content }
        }
    }

}

struct LiveMenuRow: View {
    let count: Int
    var body: some View {
        HStack(spacing: 8) {
            Label("Live", systemImage: MacPane.live.icon)
            Spacer()
            Circle().fill(count > 0 ? Color.green : Color.secondary.opacity(0.4)).frame(width: 9, height: 9)
                .shadow(color: count > 0 ? .green.opacity(0.6) : .clear, radius: 3)
            Text("\(count)").monospacedDigit().font(.rcCallout.bold()).foregroundStyle(count > 0 ? .primary : .secondary)
        }
        .accessibilityLabel("Live, \(count) reading now")
    }
}

struct HealthMenuRow: View {
    let light: Color?
    var body: some View {
        HStack(spacing: 8) {
            Label(MacPane.health.title, systemImage: MacPane.health.icon)
            Spacer()
            Circle().fill(light ?? Color.secondary.opacity(0.4)).frame(width: 9, height: 9)
                .shadow(color: (light ?? .clear).opacity(0.6), radius: 3)
        }
    }
}

struct CSVFile: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws { text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self) }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: Data(text.utf8)) }
}

struct AccountFooter: View {
    @Environment(Model.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text(model.me?.email ?? "").font(.rcCaption).lineLimit(1)
            if let p = model.me?.plan { Text("\(p.name) plan").font(.rcCaption2).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        // The menu scrolls under the footer on short windows, so it needs its own background.
        .background(.regularMaterial)
    }
}

/// The menu bar count: Real-Time Active Visitors across every website.
struct MenuBarLabel: View {
    let model: Model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "chart.bar.fill")
            if model.signedIn, model.summary != nil { Text("\(model.liveCount)").monospacedDigit() }
        }
        .task {
            // Screenshots: make sure the main window is open (macOS may not open it for a fresh app).
            guard Demo.on else { return }
            try? await Task.sleep(for: .seconds(1))
            if !NSApp.windows.contains(where: { $0.canBecomeMain && $0.isVisible }) { openWindow(id: "main") }
        }
    }
}

struct MenuBarView: View {
    @Environment(Model.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !model.signedIn {
                Text("Sign in to see your readers.").font(.rcCallout)
            } else if let s = model.summary {
                Text("\(s.totalNow) Real-Time Active Visitors").font(.rcHeadline)
                ForEach(s.sites) { site in
                    HStack {
                        Text(site.site).lineLimit(1)
                        Spacer()
                        Text("\(site.on_site_now) now · \(site.today) today").monospacedDigit().foregroundStyle(.secondary)
                    }
                    .font(.rcCallout)
                }
            } else {
                ProgressView()
            }
            Divider()
            HStack {
                Button {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("Open ReaderCount", systemImage: "macwindow")
                }
                Spacer()
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(width: 320)
        .task { await model.refresh() }
    }
}
#endif
