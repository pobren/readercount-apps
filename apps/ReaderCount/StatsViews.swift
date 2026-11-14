// The pieces every screen is built from, on iPhone, iPad and Mac: the website and date pickers, the tiles, the chart,
// ranked lists, the live view, Site Health and the breakdowns. Headings match the website's.

import SwiftUI
import Charts
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Text sizes. On iPhone and iPad these are the usual sizes, which follow the reader's text size setting.
/// On the Mac the standard sizes are small for reading stats, so the Mac app uses larger ones.
extension Font {
    #if os(macOS)
    static let rcBody = Font.system(size: 16)
    static let rcCallout = Font.system(size: 15)
    static let rcSubheadline = Font.system(size: 14)
    static let rcCaption = Font.system(size: 13)
    static let rcCaption2 = Font.system(size: 12)
    static let rcHeadline = Font.system(size: 17, weight: .semibold)
    static let rcTitle3 = Font.system(size: 19)
    static let rcTitle2 = Font.system(size: 22)
    static let rcLargeTitle = Font.system(size: 30)
    #else
    static let rcBody = Font.body
    static let rcCallout = Font.callout
    static let rcSubheadline = Font.subheadline
    static let rcCaption = Font.caption
    static let rcCaption2 = Font.caption2
    static let rcHeadline = Font.headline
    static let rcTitle3 = Font.title3
    static let rcTitle2 = Font.title2
    static let rcLargeTitle = Font.largeTitle
    #endif
}

struct SitePicker: View {
    @Environment(Model.self) private var model

    var body: some View {
        if model.sites.count > 1 {
            Picker("Website", selection: Binding(get: { model.current }, set: { model.site = $0 })) {
                ForEach(model.sites, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
        } else if let s = model.sites.first {
            Label(s, systemImage: "globe").font(.rcHeadline)
        }
    }
}

struct PeriodPicker: View {
    @Environment(Model.self) private var model

    var body: some View {
        @Bindable var model = model
        Picker("Dates", selection: $model.period) {
            ForEach(Period.allCases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
    }
}

struct Tile: View {
    let title: String
    let value: String
    var change: Int? = nil
    var icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon).font(.rcCaption.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.rcTitle2.bold()).monospacedDigit().contentTransition(.numericText())
            if let change {
                Text(change >= 0 ? "▲ \(change)%" : "▼ \(-change)%")
                    .font(.rcCaption.bold()).foregroundStyle(change >= 0 ? .green : .orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

func percentChange(_ now: Int, _ before: Int) -> Int? {
    guard before > 0 else { return nil }
    return Int(((Double(now) - Double(before)) / Double(before) * 100).rounded())
}

struct TilesView: View {
    let o: Overview
    var columns = 2

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columns), spacing: 12) {
            Tile(title: "Visitors", value: Num.short(o.totals.visitors), change: percentChange(o.totals.visitors, o.previous_period.visitors), icon: "person.2")
            Tile(title: "Page views", value: Num.short(o.totals.views), change: percentChange(o.totals.views, o.previous_period.views), icon: "doc.text")
            Tile(title: "Time on page", value: Num.time(o.totals.avg_seconds), icon: "clock")
            Tile(title: "Bounce rate", value: "\(o.totals.bounce_percent ?? 0)%", icon: "arrow.uturn.left")
        }
    }
}

struct VisitorsChart: View {
    let o: Overview

    var body: some View {
        Chart(Array(o.per_day.enumerated()), id: \.offset) { item in
            AreaMark(x: .value("Day", item.offset), y: .value("Visitors", item.element.visitors))
                .foregroundStyle(LinearGradient(colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.monotone)
            LineMark(x: .value("Day", item.offset), y: .value("Visitors", item.element.visitors))
                .foregroundStyle(Color.accentColor)
                .interpolationMethod(.monotone)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { v in
                AxisValueLabel {
                    if let i = v.as(Int.self), i >= 0, i < o.per_day.count { Text(label(o.per_day[i])) }
                }
            }
        }
        .frame(height: 180)
        .accessibilityLabel("Visitors chart")
    }

    private func label(_ d: Overview.Day) -> String {
        if let h = d.hour { return "\(h):00" }
        let p = d.day.split(separator: "-"); return p.count == 3 ? "\(p[2])/\(p[1])" : d.day  // UK order: 07/11
    }
}

/// A ranked list with bars, like the website's cards.
struct RankList: View {
    struct Row: Identifiable, Hashable {
        let name: String
        let value: Int
        var detail: String? = nil
        var id: String { name }
    }
    let title: String
    let icon: String
    let rows: [Row]
    var limit = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: icon).font(.rcHeadline)
                Spacer()
                if !rows.isEmpty { ExportButton(title: title, rows: rows) }
            }
            if rows.isEmpty {
                Text("Nothing yet for these dates.").font(.rcCallout).foregroundStyle(.secondary)
            }
            let sorted = rows.sorted { $0.value > $1.value }
            let top = max(1, sorted.first?.value ?? 1)
            ForEach(sorted.prefix(limit)) { r in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.name).lineLimit(1).truncationMode(.middle)
                        if let d = r.detail { Text(d).font(.rcCaption).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    Text(Num.short(r.value)).monospacedDigit().bold()
                }
                .padding(.vertical, 4).padding(.horizontal, 8)
                .background(alignment: .leading) {
                    GeometryReader { g in
                        RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.12))
                            .frame(width: g.size.width * CGFloat(r.value) / CGFloat(top))
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct ErrorBanner: View {
    @Environment(Model.self) private var model

    var body: some View {
        if let e = model.error {
            Label(e, systemImage: "exclamationmark.triangle.fill")
                .font(.rcCallout).foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

/// Overview: the tiles, the chart, top pages and sources.
struct TodayContent: View {
    @Environment(Model.self) private var model
    var columns = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ErrorBanner()
            PeriodPicker()
            if model.sites.isEmpty {
                ContentUnavailableView("No websites yet", systemImage: "globe", description: Text("Add your website at readercount.com, then pull down to refresh."))
            } else if let o = model.overview {
                if let now = o.totals.on_site_now {
                    Label("\(now) Real-Time Active Visitors", systemImage: "dot.radiowaves.left.and.right")
                        .font(.rcSubheadline.bold()).foregroundStyle(.green)
                }
                TilesView(o: o, columns: columns)
                VisitorsChart(o: o)
                    .padding(14)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                RankList(title: "Top pages", icon: "doc.richtext", rows: o.top_pages.map { .init(name: $0.page, value: $0.visitors) })
                RankList(title: "Sources", icon: "arrow.down.right.circle", rows: o.sources.map { .init(name: $0.source, value: $0.visitors) })
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .task(id: model.current + model.period.rawValue) { if model.overview == nil { await model.loadOverview() } }
    }
}

/// Live: who's on the site now, the pages they're on and where they came from.
struct LiveContent: View {
    @Environment(Model.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ErrorBanner()
            if let l = model.live {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(l.total)").font(.system(size: 56, weight: .bold, design: .rounded)).monospacedDigit().contentTransition(.numericText())
                    Text("Real-Time Active Visitors").font(.rcHeadline).foregroundStyle(.secondary)
                }
                RankList(title: "Pages being read now", icon: "doc.text.magnifyingglass", rows: l.pages.map { .init(name: $0.path, value: $0.n) })
                RankList(title: "Where they came from", icon: "arrow.down.right.circle", rows: l.sources.map { .init(name: $0.name, value: $0.n) })
                VStack(alignment: .leading, spacing: 10) {
                    Label("Visitor trails", systemImage: "point.topleft.down.to.point.bottomright.curvepath").font(.rcHeadline)
                    ForEach(Array(l.visitors.enumerated()), id: \.offset) { item in VisitorRow(v: item.element) }
                    if l.visitors.isEmpty { Text("Nobody on the site right now.").foregroundStyle(.secondary) }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        // Every 5 seconds while it's open, as on the website.
        .task(id: model.current) {
            while !Task.isCancelled {
                await model.loadLive()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }
}

struct VisitorRow: View {
    let v: LiveVisitor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(Num.flag(v.country))
                Text([v.town, v.region].filter { !$0.isEmpty }.joined(separator: ", ").ifEmpty(v.country)).bold()
                Spacer()
                Text(v.away > 0 ? "Away" : "Reading").font(.rcCaption.bold()).foregroundStyle(v.away > 0 ? Color.secondary : Color.green)
            }
            Text("\(v.source.ifEmpty("Direct")) · \(v.device) · \(v.browser)").font(.rcCaption).foregroundStyle(.secondary)
            ForEach(Array(v.steps.suffix(4).enumerated()), id: \.offset) { item in
                let s = item.element
                Label(s.kind == "click" ? (s.target ?? s.path) : s.path, systemImage: s.kind == "click" ? "cursorarrow.click" : "doc")
                    .font(.rcCaption).lineLimit(1).truncationMode(.middle)
            }
        }
        .padding(.vertical, 6)
    }
}

extension String {
    func ifEmpty(_ other: String) -> String { isEmpty ? other : self }
}

/// Site Health and What to fix, with Mark as fixed.
struct HealthContent: View {
    @Environment(Model.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ErrorBanner()
            if let h = model.health {
                if h.health.isEmpty {
                    Label("Nothing needs fixing. Your website looks healthy.", systemImage: "checkmark.seal.fill")
                        .font(.rcHeadline).foregroundStyle(.green)
                }
                ForEach(h.health) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Label(item.title, systemImage: item.level == "fix" ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                            .font(.rcHeadline).foregroundStyle(item.level == "fix" ? .red : .orange)
                        Text(item.detail).font(.rcCallout)
                        ForEach(item.links, id: \.self) { l in
                            if let u = URL(string: l) { Link(destination: u) { Label(l, systemImage: "link").font(.rcCaption).lineLimit(1) } }
                        }
                        HStack(spacing: 10) {
                            if item.key != nil {
                                Button {
                                    Task { await model.markFixed(item) }
                                } label: {
                                    Label("Mark as fixed", systemImage: "checkmark.circle")
                                }
                                .buttonStyle(.bordered)
                            }
                            CopyIssueButton(text: ([item.title, item.detail] + item.links).joined(separator: "\n"))
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                if !h.marked.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Marked as fixed", systemImage: "checkmark.circle").font(.rcHeadline)
                        ForEach(h.marked, id: \.key) { m in
                            HStack {
                                Text(m.title).font(.rcCallout)
                                Spacer()
                                Button {
                                    Task { await model.markFixed(.init(level: "", title: m.title, detail: "", links: [], key: m.key), undo: true) }
                                } label: {
                                    Label("Undo", systemImage: "arrow.uturn.backward")
                                }
                                .buttonStyle(.borderless).font(.rcCaption)
                            }
                        }
                    }
                }
                if !h.what_to_fix.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("What to fix", systemImage: "wrench.and.screwdriver").font(.rcHeadline)
                        ForEach(h.what_to_fix) { f in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(f.page).bold().lineLimit(1).truncationMode(.middle)
                                Text(f.what).font(.rcCallout)
                                Label(f.todo, systemImage: "lightbulb").font(.rcCallout).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .task(id: model.current) { await model.loadHealth() }
    }
}

/// A report's rows as a CSV file, named after the report, the website and the dates.
struct CSVExport: Transferable {
    let name: String
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { file in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(file.name)
            try Data(file.text.utf8).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

/// Export on every report: Save as a CSV file on the Mac, or share it (Save to Files, Mail, Numbers) on iPhone and iPad.
struct ExportButton: View {
    @Environment(Model.self) private var model
    let title: String
    let rows: [RankList.Row]
    @State private var saving = false

    private var file: CSVExport {
        func cell(_ s: String) -> String {
            // Drop flag emoji and quote each value so commas in page names are safe.
            let plain = String(String.UnicodeScalarView(s.unicodeScalars.filter { !(0x1F1E6...0x1F1FF).contains($0.value) }))
                .trimmingCharacters(in: .whitespaces)
            return "\"" + plain.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        let detail = rows.contains { $0.detail != nil }
        var lines = [detail ? "Name,Count,Detail" : "Name,Count"]
        for r in rows.sorted(by: { $0.value > $1.value }) {
            lines.append([cell(r.name), String(r.value)] .joined(separator: ",") + (detail ? "," + cell(r.detail ?? "") : ""))
        }
        let site = model.site.isEmpty ? "ReaderCount" : model.site
        let name = "\(title) \(site) \(model.period.label).csv".replacingOccurrences(of: "/", with: "-")
        return CSVExport(name: name, text: lines.joined(separator: "\n") + "\n")
    }

    var body: some View {
        #if os(macOS)
        Button { saving = true } label: { Label("Export", systemImage: "square.and.arrow.up") }
            .buttonStyle(.bordered)
            .fileExporter(isPresented: $saving, item: file, contentTypes: [.commaSeparatedText], defaultFilename: file.name) { _ in }
        #else
        ShareLink(item: file, preview: SharePreview(file.name)) { Label("Export", systemImage: "square.and.arrow.up") }
            .buttonStyle(.bordered).font(.rcCallout)
        #endif
    }
}

/// Copies a live issue (title, detail and links) so it can be pasted into an email, a note or a chat.
struct CopyIssueButton: View {
    let text: String
    @State private var copied = false

    var body: some View {
        Button {
            #if os(iOS)
            UIPasteboard.general.string = text
            #else
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            #endif
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                copied = false
            }
        } label: {
            Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
        }
        .buttonStyle(.bordered)
        .accessibilityHint("Copies this issue")
    }
}

/// One breakdown (countries, towns, devices, browsers, campaigns, clicks) for the More screens.
struct BreakdownContent: View {
    @Environment(Model.self) private var model
    let title: String
    let icon: String
    let by: String
    var clicks = false
    @State private var data: Breakdown?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PeriodPicker()
            if let data {
                RankList(title: title, icon: icon, rows: data.rows.map { .init(name: by == "country" ? "\(Num.flag($0.name)) \($0.name)" : $0.name, value: $0.count) }, limit: 50)
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .task(id: model.current + model.period.rawValue + by) { data = await model.breakdown(by, clicks: clicks) }
    }
}

/// Google search: the searches that showed the website, from Search Console when it's connected.
struct SearchesContent: View {
    @Environment(Model.self) private var model
    @State private var data: Searches?
    @State private var problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PeriodPicker()
            if let problem {
                Label(problem, systemImage: "info.circle").foregroundStyle(.secondary)
            } else if let data {
                RankList(title: "Google searches", icon: "magnifyingglass", rows: data.rows.map { .init(name: $0.name, value: $0.clicks, detail: "\($0.impressions.formatted()) seen · place \(String(format: "%.1f", $0.position ?? 0))") }, limit: 50)
                Text("Google's figures arrive two or three days late.").font(.rcCaption).foregroundStyle(.secondary)
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .task(id: model.current + model.period.rawValue) {
            let r = await model.searches()
            data = r.0
            problem = r.1
        }
    }
}

/// The More list: each breakdown the website has, opened on its own screen.
enum MoreItem: String, CaseIterable, Identifiable {
    case google, sources, clicks, countries, towns, devices, browsers, campaigns
    var id: String { rawValue }
    var title: String {
        switch self {
        case .google: "Google search"
        case .sources: "Sources"
        case .clicks: "Clicks"
        case .countries: "Countries"
        case .towns: "Towns"
        case .devices: "Devices"
        case .browsers: "Browsers"
        case .campaigns: "Campaigns"
        }
    }
    var icon: String {
        switch self {
        case .google: "magnifyingglass"
        case .sources: "arrow.down.right.circle"
        case .clicks: "cursorarrow.click.2"
        case .countries: "globe.europe.africa"
        case .towns: "building.2"
        case .devices: "ipad.and.iphone"
        case .browsers: "safari"
        case .campaigns: "megaphone"
        }
    }

    @ViewBuilder var content: some View {
        switch self {
        case .google: SearchesContent()
        case .sources: BreakdownContent(title: title, icon: icon, by: "source")
        case .clicks: BreakdownContent(title: title, icon: icon, by: "link", clicks: true)
        case .countries: BreakdownContent(title: title, icon: icon, by: "country")
        case .towns: BreakdownContent(title: title, icon: icon, by: "town")
        case .devices: BreakdownContent(title: title, icon: icon, by: "device")
        case .browsers: BreakdownContent(title: title, icon: icon, by: "browser")
        case .campaigns: BreakdownContent(title: title, icon: icon, by: "campaign")
        }
    }
}

/// Which alerts this device gets as a push.
struct AlertsSettings: View {
    @Environment(Model.self) private var model
    static let kinds: [(String, String, String)] = [
        ("spike", "Traffic spikes", "chart.line.uptrend.xyaxis"),
        ("down", "Website down", "exclamationmark.icloud"),
        ("triggers", "Goals and triggers", "target"),
        ("monthly", "Monthly review", "calendar"),
    ]

    var body: some View {
        if model.pushAllowed == false {
            Label("Alerts are switched off for ReaderCount in Settings.", systemImage: "bell.slash").foregroundStyle(.secondary)
        }
        ForEach(Self.kinds, id: \.0) { k in
            Toggle(isOn: Binding(get: { model.alerts[k.0] ?? false }, set: { on in Task { await model.setAlert(k.0, on) } })) {
                Label(k.1, systemImage: k.2)
            }
        }
    }
}
