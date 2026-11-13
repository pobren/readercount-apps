// The pieces every screen is built from, on iPhone, iPad and Mac: the website and date pickers, the tiles, the chart,
// ranked lists, the live view, Site Health and the breakdowns. Headings match the website's.

import SwiftUI
import Charts

struct SitePicker: View {
    @Environment(Model.self) private var model

    var body: some View {
        if model.sites.count > 1 {
            Picker("Website", selection: Binding(get: { model.current }, set: { model.site = $0 })) {
                ForEach(model.sites, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
        } else if let s = model.sites.first {
            Label(s, systemImage: "globe").font(.headline)
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
            Label(title, systemImage: icon).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.title2.bold()).monospacedDigit().contentTransition(.numericText())
            if let change {
                Text(change >= 0 ? "▲ \(change)%" : "▼ \(-change)%")
                    .font(.caption.bold()).foregroundStyle(change >= 0 ? .green : .orange)
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
        return String(d.day.suffix(5)).replacingOccurrences(of: "-", with: "/")
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
            Label(title, systemImage: icon).font(.headline)
            if rows.isEmpty {
                Text("Nothing yet for these dates.").font(.callout).foregroundStyle(.secondary)
            }
            let top = max(1, rows.first?.value ?? 1)
            ForEach(rows.prefix(limit)) { r in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.name).lineLimit(1).truncationMode(.middle)
                        if let d = r.detail { Text(d).font(.caption).foregroundStyle(.secondary) }
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
                .font(.callout).foregroundStyle(.orange)
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
                        .font(.subheadline.bold()).foregroundStyle(.green)
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
                    Text("Real-Time Active Visitors").font(.headline).foregroundStyle(.secondary)
                }
                RankList(title: "Pages being read now", icon: "doc.text.magnifyingglass", rows: l.pages.map { .init(name: $0.path, value: $0.n) })
                RankList(title: "Where they came from", icon: "arrow.down.right.circle", rows: l.sources.map { .init(name: $0.name, value: $0.n) })
                VStack(alignment: .leading, spacing: 10) {
                    Label("Visitor trails", systemImage: "point.topleft.down.to.point.bottomright.curvepath").font(.headline)
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
                Text(v.away > 0 ? "Away" : "Reading").font(.caption.bold()).foregroundStyle(v.away > 0 ? Color.secondary : Color.green)
            }
            Text("\(v.source.ifEmpty("Direct")) · \(v.device) · \(v.browser)").font(.caption).foregroundStyle(.secondary)
            ForEach(Array(v.steps.suffix(4).enumerated()), id: \.offset) { item in
                let s = item.element
                Label(s.kind == "click" ? (s.target ?? s.path) : s.path, systemImage: s.kind == "click" ? "cursorarrow.click" : "doc")
                    .font(.caption).lineLimit(1).truncationMode(.middle)
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
                        .font(.headline).foregroundStyle(.green)
                }
                ForEach(h.health) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Label(item.title, systemImage: item.level == "fix" ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                            .font(.headline).foregroundStyle(item.level == "fix" ? .red : .orange)
                        Text(item.detail).font(.callout)
                        ForEach(item.links, id: \.self) { l in
                            if let u = URL(string: l) { Link(destination: u) { Label(l, systemImage: "link").font(.caption).lineLimit(1) } }
                        }
                        if item.key != nil {
                            Button {
                                Task { await model.markFixed(item) }
                            } label: {
                                Label("Mark as fixed", systemImage: "checkmark.circle")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                if !h.marked.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Marked as fixed", systemImage: "checkmark.circle").font(.headline)
                        ForEach(h.marked, id: \.key) { m in
                            HStack {
                                Text(m.title).font(.callout)
                                Spacer()
                                Button {
                                    Task { await model.markFixed(.init(level: "", title: m.title, detail: "", links: [], key: m.key), undo: true) }
                                } label: {
                                    Label("Undo", systemImage: "arrow.uturn.backward")
                                }
                                .buttonStyle(.borderless).font(.caption)
                            }
                        }
                    }
                }
                if !h.what_to_fix.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("What to fix", systemImage: "wrench.and.screwdriver").font(.headline)
                        ForEach(h.what_to_fix) { f in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(f.page).bold().lineLimit(1).truncationMode(.middle)
                                Text(f.what).font(.callout)
                                Label(f.todo, systemImage: "lightbulb").font(.callout).foregroundStyle(.secondary)
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
                Text("Google's figures arrive two or three days late.").font(.caption).foregroundStyle(.secondary)
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
        case .devices: "iphone.and.ipad"
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
