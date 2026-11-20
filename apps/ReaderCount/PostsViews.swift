// Post performance, Click Rate and the small ups and downs on lists: the website's 20 Nov 2026 additions, in the apps.

import SwiftUI
import Charts

extension Color {
    /// The website's second line colour (page views), --alt.
    static let rcMagenta = Color(red: 0xC0 / 255, green: 0x26 / 255, blue: 0xD3 / 255)
    static let rcUp = Color(red: 0x1A / 255, green: 0x7F / 255, blue: 0x37 / 255)
    static let rcDown = Color(red: 0xC2 / 255, green: 0x41 / 255, blue: 0x0C / 255)
}

extension Overview {
    /// Visitors against the period before, for one row of a list. Nil when the server didn't send the period before.
    func change(_ by: String, _ name: String, _ now: Int) -> Int? {
        guard let was = before?.list(by) else { return nil }
        return now - (was[name] ?? 0)
    }
}

/// +12 in green or −8 in orange, small, beside a number.
struct ChangeText: View {
    let change: Int
    var body: some View {
        Text(change > 0 ? "+\(Num.short(change))" : "−\(Num.short(-change))")
            .font(.rcCaption2).monospacedDigit()
            .foregroundStyle(change > 0 ? Color.rcUp : Color.rcDown)
            .accessibilityLabel(change > 0 ? "up \(change)" : "down \(-change)")
    }
}

/// "How to set up DMARC" from "/how-to-set-up-dmarc/", when a page has no title.
func pageName(_ path: String, _ title: String?) -> String {
    if let title, !title.isEmpty { return title }
    if path == "/" { return "Home page" }
    let slug = path.split(separator: "/").last.map(String.init) ?? path
    let words = slug.replacingOccurrences(of: "-", with: " ")
    return words.prefix(1).uppercased() + words.dropFirst()
}

// MARK: - Clicks and Click Rate

/// Clicks: the links readers clicked, or each page's click rate.
struct ClicksContent: View {
    @State private var rates = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Show", selection: $rates) {
                Label("Links", systemImage: "link").tag(false)
                Label("Click Rate", systemImage: "percent").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)
            if rates {
                ClickRateContent()
            } else {
                BreakdownContent(title: "Clicks", icon: "cursorarrow.click.2", by: "link", clicks: true)
            }
        }
    }
}

/// Of the people who viewed a page, how often they clicked a link on it. Pages with under 10 views come last,
/// so one lucky click doesn't top the list (as on the website).
struct ClickRateContent: View {
    @Environment(Model.self) private var model

    private static func pct(_ c: Int, _ v: Int) -> String { v > 0 ? String(format: "%.1f%%", 100 * Double(c) / Double(v)) : "–" }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PeriodPicker()
            if let o = model.overview {
                let list = (o.click_rates ?? []).sorted { a, b in
                    let ra = Double(a.clicks) / Double(max(1, a.views)), rb = Double(b.clicks) / Double(max(1, b.views))
                    if (a.views >= 10) != (b.views >= 10) { return a.views >= 10 }
                    return ra != rb ? ra > rb : a.clicks > b.clicks
                }
                RankList(title: "Click Rate", icon: "percent",
                         rows: list.map { c in
                             .init(name: c.page, value: c.views > 0 ? 1000 * c.clicks / c.views : 0,
                                   detail: "\(c.clicks.formatted()) \(c.clicks == 1 ? "click" : "clicks") · \(c.views.formatted()) \(c.views == 1 ? "view" : "views")",
                                   shown: Self.pct(c.clicks, c.views))
                         },
                         limit: 50, drill: "page", empty: "No link clicks for these dates.", keepOrder: true)
                if let clicks = o.totals.clicks, o.totals.views > 0 {
                    Text("Overall: \(clicks.formatted()) \(clicks == 1 ? "click" : "clicks") from \(o.totals.views.formatted()) page views, \(Self.pct(clicks, o.totals.views)) click rate. Downloads count as clicks.")
                        .font(.rcCaption).foregroundStyle(.secondary)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .task(id: model.current + model.datesKey) { if model.overview == nil { await model.loadOverview() } }
    }
}

// MARK: - Post performance

struct PostsContent: View {
    @Environment(Model.self) private var model
    @State private var report: PostsReport?
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ErrorBanner()
            if let r = report, r.ready {
                LaunchesCard(r: r)
                if let m = r.movers { MoversCard(m: m) }
                if let ridges = r.ridges, !ridges.rows.isEmpty { RidgesCard(ridges: ridges) }
                if let months = r.months, !months.isEmpty { MonthsCard(months: months) }
            } else if loaded {
                ContentUnavailableView("Not enough yet", systemImage: "chart.line.uptrend.xyaxis",
                                       description: Text("Post performance fills in as ReaderCount counts your posts. Pull down to refresh."))
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .task(id: model.current + "#\(model.reloadTick)") {
            report = await model.posts()
            loaded = true
        }
    }
}

/// Each new post's page views over its first 30 days, newest first, against the median.
struct LaunchesCard: View {
    let r: PostsReport

    private static func day(_ d: String) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_GB_POSIX"); f.dateFormat = "yyyy-MM-dd"; f.timeZone = TimeZone(identifier: "UTC")
        guard let date = f.date(from: d) else { return d }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    var body: some View {
        let days = r.launch_days ?? 30
        let list = Array((r.launches ?? []).prefix(12))
        VStack(alignment: .leading, spacing: 10) {
            Label("New posts: first \(days) days", systemImage: "sparkles").font(.rcHeadline)
            Text(r.median.map { "Page views in each post's first \(days) days. The line is the median, \($0.formatted()) views." } ?? "Page views in each post's first \(days) days.")
                .font(.rcCaption).foregroundStyle(.secondary)
            if list.isEmpty {
                Text("No new posts since ReaderCount started counting.").font(.rcCallout).foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(list, id: \.page) { l in
                        BarMark(x: .value("Views", l.views), y: .value("Post", pageName(l.page, l.title)))
                            .foregroundStyle(l.inside ? Color.accentColor.opacity(0.45) : Color.accentColor)
                            .cornerRadius(4)
                            .annotation(position: .trailing) {
                                Text(l.views.formatted()).font(.rcCaption2).monospacedDigit().foregroundStyle(.secondary)
                            }
                    }
                    if let m = r.median {
                        RuleMark(x: .value("Median", m))
                            .foregroundStyle(Color.rcMagenta)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                }
                .chartYAxis {
                    AxisMarks { v in
                        AxisValueLabel { if let s = v.as(String.self) { Text(s).lineLimit(1).truncationMode(.tail).frame(maxWidth: 150, alignment: .leading) } }
                    }
                }
                .frame(height: CGFloat(list.count) * 34 + 24)
                .accessibilityLabel("New posts chart")
                ForEach(list.filter(\.inside), id: \.page) { l in
                    Label("\(pageName(l.page, l.title)): first seen \(Self.day(l.first)), still in its first \(days) days", systemImage: "clock")
                        .font(.rcCaption).foregroundStyle(.secondary)
                }
            }
        }
        .card()
    }
}

/// Pages gaining and losing readers: the last few weeks against the weeks before.
struct MoversCard: View {
    let m: PostsReport.Movers

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Risers and fallers", systemImage: "arrow.up.arrow.down").font(.rcHeadline)
            Text("Page views in the last \(m.days) days against the \(m.days) days before.").font(.rcCaption).foregroundStyle(.secondary)
            if m.up.isEmpty && m.down.isEmpty {
                Text("No big changes.").font(.rcCallout).foregroundStyle(.secondary)
            }
            ForEach(m.up, id: \.page) { row($0, up: true) }
            if !m.up.isEmpty && !m.down.isEmpty { Divider() }
            ForEach(m.down, id: \.page) { row($0, up: false) }
        }
        .card()
    }

    private func row(_ x: PostsReport.Mover, up: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: up ? "arrow.up.right" : "arrow.down.right").foregroundStyle(up ? Color.rcUp : Color.rcDown)
            VStack(alignment: .leading, spacing: 2) {
                Text(pageName(x.page, x.title)).lineLimit(1)
                Text("\(x.before.formatted()) to \(x.now.formatted()) views").font(.rcCaption).foregroundStyle(.secondary)
            }
            Spacer()
            ChangeText(change: x.now - x.before)
        }
        .padding(.vertical, 2)
    }
}

/// The most read pages over time, each with its own small line.
struct RidgesCard: View {
    let ridges: PostsReport.Ridges

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Top posts over time", systemImage: "chart.xyaxis.line").font(.rcHeadline)
            Text(ridges.bucket == "week" ? "Page views each week." : "Page views each day.").font(.rcCaption).foregroundStyle(.secondary)
            let top = max(1, ridges.rows.flatMap(\.values).max() ?? 1)
            ForEach(ridges.rows.prefix(10), id: \.page) { r in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pageName(r.page, r.title)).lineLimit(1)
                        Text("\(r.total.formatted()) views").font(.rcCaption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Chart(Array(r.values.enumerated()), id: \.offset) { p in
                        AreaMark(x: .value("When", p.offset), y: .value("Views", p.element))
                            .foregroundStyle(LinearGradient(colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.03)], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.monotone)
                        LineMark(x: .value("When", p.offset), y: .value("Views", p.element))
                            .foregroundStyle(Color.accentColor)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.monotone)
                    }
                    .chartYScale(domain: 0...top)
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(width: 120, height: 36)
                    .accessibilityHidden(true)
                }
            }
        }
        .card()
    }
}

/// Month by month: views, visitors and how many pages were read.
struct MonthsCard: View {
    let months: [PostsReport.Month]

    private static func name(_ m: String) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_GB_POSIX"); f.dateFormat = "yyyy-MM"; f.timeZone = TimeZone(identifier: "UTC")
        guard let d = f.date(from: m) else { return m }
        return d.formatted(.dateTime.month(.abbreviated).year())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Month by month", systemImage: "calendar").font(.rcHeadline)
            Grid(alignment: .trailing, horizontalSpacing: 14, verticalSpacing: 8) {
                GridRow {
                    Text("Month").gridColumnAlignment(.leading)
                    Text("Views")
                    Text("Visitors")
                    Text("Pages")
                }
                .font(.rcCaption.bold()).foregroundStyle(.secondary)
                ForEach(months.prefix(24), id: \.month) { m in
                    GridRow {
                        Text(Self.name(m.month) + (m.imported == true ? " *" : ""))
                        Text(m.views.formatted()).monospacedDigit()
                        Text(m.visitors.formatted()).monospacedDigit()
                        Text(m.pages.map { $0.formatted() } ?? "–").monospacedDigit()
                    }
                    .font(.rcCallout)
                }
            }
            if months.contains(where: { $0.imported == true }) {
                Text("* Imported from your old stats.").font(.rcCaption).foregroundStyle(.secondary)
            }
        }
        .card()
    }
}
