// The Mac app: a window with the same foldable left menu as the website, and a live count in the menu bar.
// Mac design rules (as Site Patrol): one content width, flat cards, soft icons, one brand blue.
// Everything here is inside #if os(macOS), or the iPhone build fails.

#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

enum MacPane: String, CaseIterable, Identifiable, Hashable {
    case overview, live, health, google, sources, clicks, countries, towns, devices, browsers, campaigns, alerts
    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: "Overview"
        case .live: "Live"
        case .health: "Site Health"
        case .alerts: "Alerts"
        default: MoreItem(rawValue: rawValue)?.title ?? rawValue
        }
    }
    var icon: String {
        switch self {
        case .overview: "chart.xyaxis.line"
        case .live: "dot.radiowaves.left.and.right"
        case .health: "stethoscope"
        case .alerts: "bell.badge"
        default: MoreItem(rawValue: rawValue)?.icon ?? "circle"
        }
    }
}

struct MacRoot: View {
    @Environment(Model.self) private var model
    @State private var pane: MacPane? = Demo.tab.flatMap { MacPane(rawValue: $0 == "today" ? "overview" : $0) } ?? .overview
    @State private var exporting = false

    var body: some View {
        NavigationSplitView {
            List(selection: $pane) {
                Section("Stats") {
                    ForEach([MacPane.overview, .live, .health]) { p in Label(p.title, systemImage: p.icon).tag(p) }
                }
                Section("More") {
                    ForEach([MacPane.google, .sources, .clicks, .countries, .towns, .devices, .browsers, .campaigns]) { p in Label(p.title, systemImage: p.icon).tag(p) }
                }
                Section("Account") {
                    Label(MacPane.alerts.title, systemImage: MacPane.alerts.icon).tag(MacPane.alerts)
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
            .safeAreaInset(edge: .bottom) { AccountFooter() }
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    detail
                }
                .padding(24)
                .frame(maxWidth: 1040)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(pane?.title ?? "ReaderCount")
            .toolbar {
                ToolbarItem { SitePicker() }
                if pane == .overview {
                    ToolbarItem {
                        Button {
                            exporting = true
                        } label: {
                            Label("Export to CSV", systemImage: "square.and.arrow.down")
                        }
                        .disabled(model.overview == nil)
                    }
                }
                ToolbarItem {
                    Button {
                        Task { await model.refresh(); await model.loadLive(); await model.loadHealth() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .keyboardShortcut("r")
                }
            }
        }
        .fileExporter(isPresented: $exporting, document: CSVFile(text: csv()), contentType: .commaSeparatedText, defaultFilename: "\(model.current) \(model.period.label).csv") { _ in }
        .task { await model.refresh() }
    }

    @ViewBuilder private var detail: some View {
        switch pane ?? .overview {
        case .overview: TodayContent(columns: 4)
        case .live: LiveContent()
        case .health: HealthContent()
        case .alerts:
            Form { AlertsSettings() }.formStyle(.grouped)
            Text("Alerts come as a notification on this Mac, as well as any emails you've chosen on the website.").font(.callout).foregroundStyle(.secondary)
        default:
            if let item = MoreItem(rawValue: (pane ?? .overview).rawValue) { item.content }
        }
    }

    /// The overview's pages and sources as a spreadsheet.
    private func csv() -> String {
        guard let o = model.overview else { return "" }
        func q(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        var lines = ["\(q("Website")),\(q(o.site))", "\(q("From")),\(o.from)", "\(q("To")),\(o.to)", "", "Day,Visitors,Page views"]
        lines += o.per_day.map { "\($0.day)\($0.hour.map { " \($0):00" } ?? ""),\($0.visitors),\($0.views)" }
        lines += ["", "Page,Visitors,Page views,Time on page (seconds)"]
        lines += o.top_pages.map { "\(q($0.page)),\($0.visitors),\($0.views),\($0.avg_seconds ?? 0)" }
        lines += ["", "Source,Visitors"]
        lines += o.sources.map { "\(q($0.source)),\($0.visitors)" }
        return lines.joined(separator: "\n") + "\n"
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
            Text(model.me?.email ?? "").font(.caption).lineLimit(1)
            if let p = model.me?.plan { Text("\(p.name) plan").font(.caption2).foregroundStyle(.secondary) }
            HStack {
                Link(destination: Shared.app) { Label("Website", systemImage: "safari") }
                Spacer()
                Button {
                    Task { await model.signOut() }
                } label: {
                    Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
            .buttonStyle(.borderless).font(.caption)
        }
        .padding(12)
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
                Text("Sign in to see your readers.").font(.callout)
            } else if let s = model.summary {
                Text("\(s.totalNow) Real-Time Active Visitors").font(.headline)
                ForEach(s.sites) { site in
                    HStack {
                        Text(site.site).lineLimit(1)
                        Spacer()
                        Text("\(site.on_site_now) now · \(site.today) today").monospacedDigit().foregroundStyle(.secondary)
                    }
                    .font(.callout)
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
