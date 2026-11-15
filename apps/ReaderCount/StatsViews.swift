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
            #if os(macOS)
            // A Menu with its own label, so the Mac toolbar always shows the name and not just the icon.
            Menu {
                ForEach(model.sites, id: \.self) { site in
                    Button { model.site = site } label: {
                        Label { Text(site) } icon: { favicon(site) }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    favicon(model.current)
                    Text(model.current).lineLimit(1)
                }
            }
            .menuStyle(.button)
            .fixedSize()
            #else
            Picker("Website", selection: Binding(get: { model.current }, set: { model.site = $0 })) {
                ForEach(model.sites, id: \.self) { site in
                    Label { Text(site) } icon: { favicon(site) }.tag(site)
                }
            }
            .pickerStyle(.menu)
            .labelStyle(.titleAndIcon)
            #endif
        } else if let s = model.sites.first {
            Label { Text(s) } icon: { favicon(s) }.labelStyle(.titleAndIcon).font(.rcHeadline)
        }
    }

    private func favicon(_ site: String) -> Image {
        model.favicons[site] ?? Image(systemName: "globe")
    }
}

struct PeriodPicker: View {
    @Environment(Model.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 12) {
            Picker("Dates", selection: $model.period) {
                ForEach(Period.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            if model.period == .custom { CustomRange() }
        }
    }
}

/// The custom dates box: a clear summary, two big date buttons that open a calendar, and quick picks.
struct CustomRange: View {
    @Environment(Model.self) private var model
    @State private var editing: Which?
    enum Which: String, Identifiable { case from, to; var id: String { rawValue } }

    private var days: Int {
        let c = Calendar.current
        return (c.dateComponents([.day], from: c.startOfDay(for: model.customFrom), to: c.startOfDay(for: model.customTo)).day ?? 0) + 1
    }

    private func set(_ from: Date, _ to: Date) {
        model.customFrom = from
        model.customTo = min(to, .now)
    }

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 12) {
            Label("\(model.customFrom.formatted(date: .abbreviated, time: .omitted)) to \(model.customTo.formatted(date: .abbreviated, time: .omitted)) · \(days) day\(days == 1 ? "" : "s")", systemImage: "calendar")
                .font(.rcHeadline)
            HStack(spacing: 12) {
                dateButton("From", model.customFrom, .from)
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                dateButton("To", model.customTo, .to)
            }
            HStack(spacing: 8) {
                quick("This month", "calendar.badge.clock") {
                    let c = Calendar.current
                    set(c.date(from: c.dateComponents([.year, .month], from: .now)) ?? .now, .now)
                }
                quick("Last month", "calendar.badge.minus") {
                    let c = Calendar.current
                    let start = c.date(from: c.dateComponents([.year, .month], from: .now)) ?? .now
                    let prev = c.date(byAdding: .month, value: -1, to: start) ?? start
                    set(prev, c.date(byAdding: .day, value: -1, to: start) ?? start)
                }
                quick("Last 90 days", "calendar") {
                    set(Calendar.current.date(byAdding: .day, value: -89, to: .now) ?? .now, .now)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.accentColor.opacity(0.35)))
    }

    private func dateButton(_ title: String, _ date: Date, _ which: Which) -> some View {
        Button { editing = which } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.rcCaption).foregroundStyle(.secondary)
                Label(date.formatted(date: .long, time: .omitted), systemImage: "calendar").font(.rcBody.bold())
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(minWidth: 180, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(item: Binding(get: { editing == which ? which : nil }, set: { editing = $0 })) { w in
            @Bindable var model = model
            Group {
                if w == .from {
                    DatePicker(title, selection: $model.customFrom, in: ...model.customTo, displayedComponents: .date)
                } else {
                    DatePicker(title, selection: $model.customTo, in: model.customFrom...Date.now, displayedComponents: .date)
                }
            }
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding()
            .frame(minWidth: 300)
            .presentationCompactAdaptation(.popover)
        }
    }

    private func quick(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: icon) }
            .buttonStyle(.bordered)
            .controlSize(.small)
    }
}

/// The look every card shares: a soft panel with a hairline edge.
extension View {
    func card(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.primary.opacity(0.06)))
    }
}

struct Tile: View {
    let title: String
    let value: String
    var change: Int? = nil
    var icon: String
    var tint: Color = .accentColor
    /// A small line of the last days (or hours), drawn under the number.
    var trend: [Int] = []
    /// For bounce rate a fall is good news.
    var lowerIsBetter = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.rcCallout.weight(.semibold)).foregroundStyle(tint)
                    .frame(width: 30, height: 30).background(tint.opacity(0.14), in: Circle())
                Text(title).font(.rcCallout.weight(.semibold)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(value).font(.rcTitle2.bold()).monospacedDigit().contentTransition(.numericText())
                Spacer(minLength: 4)
                if let change {
                    let good = lowerIsBetter ? change <= 0 : change >= 0
                    Label("\(abs(change))%", systemImage: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.rcCaption.bold()).foregroundStyle(good ? .green : .orange)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background((good ? Color.green : Color.orange).opacity(0.12), in: Capsule())
                }
            }
            if trend.count > 1 {
                Chart(Array(trend.enumerated()), id: \.offset) { p in
                    AreaMark(x: .value("i", p.offset), y: .value("n", p.element))
                        .foregroundStyle(LinearGradient(colors: [tint.opacity(0.3), tint.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("i", p.offset), y: .value("n", p.element)).foregroundStyle(tint).interpolationMethod(.monotone)
                }
                .chartXAxis(.hidden).chartYAxis(.hidden)
                .frame(height: 34)
            } else {
                Spacer(minLength: 0).frame(height: 34)
            }
        }
        .card(padding: 14)
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
        let points = (o.per_hour?.count ?? 0) > 1 ? o.per_hour! : o.per_day
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columns), spacing: 12) {
            Tile(title: "Visitors", value: Num.short(o.totals.visitors), change: percentChange(o.totals.visitors, o.previous_period.visitors), icon: "person.2.fill", tint: .blue, trend: points.map(\.visitors))
            Tile(title: "Page views", value: Num.short(o.totals.views), change: percentChange(o.totals.views, o.previous_period.views), icon: "doc.text.fill", tint: .purple, trend: points.map(\.views))
            Tile(title: "Time on page", value: Num.time(o.totals.avg_seconds), icon: "clock.fill", tint: .teal)
            Tile(title: "Bounce rate", value: "\(o.totals.bounce_percent ?? 0)%", icon: "arrow.uturn.left", tint: .orange, lowerIsBetter: true)
        }
    }
}

struct VisitorsChart: View {
    let o: Overview
    @State private var selected: Int?
    /// Today draws one point per hour; other dates one per day.
    private var points: [Overview.Day] { (o.per_hour?.count ?? 0) > 1 ? o.per_hour! : o.per_day }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 16) {
            Label("Visitors and page views", systemImage: "chart.xyaxis.line").font(.rcHeadline)
            Spacer()
            HStack(spacing: 4) { Circle().fill(Color.accentColor).frame(width: 8, height: 8); Text("Visitors") }.font(.rcCaption)
            HStack(spacing: 4) { Circle().fill(Color.purple.opacity(0.7)).frame(width: 8, height: 8); Text("Page views") }.font(.rcCaption)
        }
        Chart(Array(points.enumerated()), id: \.offset) { item in
            LineMark(x: .value("Day", item.offset), y: .value("Count", item.element.views), series: .value("What", "Page views"))
                .foregroundStyle(Color.purple.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                .interpolationMethod(.monotone)
            AreaMark(x: .value("Day", item.offset), y: .value("Visitors", item.element.visitors))
                .foregroundStyle(LinearGradient(colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.monotone)
            LineMark(x: .value("Day", item.offset), y: .value("Count", item.element.visitors), series: .value("What", "Visitors"))
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.monotone)
            if points.count <= 31 {
                PointMark(x: .value("Day", item.offset), y: .value("Count", item.element.visitors))
                    .foregroundStyle(Color.accentColor).symbolSize(18)
            }
            if let selected, selected == item.offset {
                RuleMark(x: .value("Day", selected))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(label(item.element)).font(.rcCaption.bold())
                            Text("\(item.element.visitors.formatted()) visitors").font(.rcCaption)
                            Text("\(item.element.views.formatted()) page views").font(.rcCaption).foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
            }
        }
        .chartXSelection(value: $selected)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { v in
                AxisValueLabel {
                    if let i = v.as(Int.self), i >= 0, i < points.count { Text(label(points[i])) }
                }
            }
        }
        .frame(height: 200)
        .accessibilityLabel("Visitors chart")
        }
    }

    private func label(_ d: Overview.Day) -> String {
        if let h = d.hour { return "\(h):00" }
        let p = d.day.split(separator: "-"); return p.count == 3 ? "\(p[2])/\(p[1])" : d.day  // UK order: 07/11
    }
}

/// A ranked list with bars, like the website's cards. With drill set, each row opens that page, source, country and so on,
/// with every other report narrowed to it.
struct RankList: View {
    struct Row: Identifiable, Hashable {
        let name: String
        let value: Int
        var detail: String? = nil
        /// The value to narrow reports by, when it differs from the name shown (a country without its flag).
        var key: String? = nil
        var id: String { name }
    }
    let title: String
    let icon: String
    let rows: [Row]
    var limit = 8
    /// The report this list breaks down by (page, source, country, town, device, browser, campaign), to click through.
    var drill: String? = nil
    /// Reports already narrowed to (when clicking through more than once).
    var filters: [String: String] = [:]

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
                if let drill, r.name != "(none)" {
                    NavigationLink {
                        DrillView(filters: filters.merging([drill: r.key ?? r.name]) { _, new in new })
                    } label: {
                        line(r, top: top, chevron: true)
                    }
                    .buttonStyle(.plain)
                } else {
                    line(r, top: top, chevron: false)
                }
            }
        }
        .card()
    }

    private func line(_ r: Row, top: Int, chevron: Bool) -> some View {
        HStack(spacing: 8) {
            if drill == "source" { SourceIcon(name: r.key ?? r.name) }
            if drill == "browser" { SourceIcon(name: r.key ?? r.name, browser: true) }
            if drill == "device" { DeviceIcon(name: r.key ?? r.name) }
            let link = r.name.hasPrefix("http") ? URL(string: r.name) : nil
            if let host = link?.host() { SourceIcon(name: host) }
            VStack(alignment: .leading, spacing: 2) {
                Text(link == nil ? r.name : r.name.replacingOccurrences(of: #"^https?://(www\.)?"#, with: "", options: .regularExpression))
                    .lineLimit(1).truncationMode(.middle)
                if let d = r.detail { Text(d).font(.rcCaption).foregroundStyle(.secondary) }
            }
            Spacer()
            Text(Num.short(r.value)).monospacedDigit().bold()
            if chevron { Image(systemName: "chevron.right").font(.rcCaption).foregroundStyle(.tertiary) }
        }
        .padding(.vertical, 4).padding(.horizontal, 8)
        .contentShape(Rectangle())
        .background(alignment: .leading) {
            GeometryReader { g in
                RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.12))
                    .frame(width: g.size.width * min(1, CGFloat(r.value) / CGFloat(top)))
            }
        }
        .clipped()
    }
}

/// Share the overview as a picture: the numbers, the chart and the top pages, ready for a message, a post or a client.
struct ShareReportButton: View {
    let o: Overview
    @Environment(\.displayScale) private var scale

    @MainActor private var picture: Image {
        let r = ImageRenderer(content: ShareCard(o: o).environment(\.colorScheme, .light))
        r.scale = max(2, scale)
        #if os(macOS)
        return r.nsImage.map { Image(nsImage: $0) } ?? Image(systemName: "chart.xyaxis.line")
        #else
        return r.uiImage.map { Image(uiImage: $0) } ?? Image(systemName: "chart.xyaxis.line")
        #endif
    }

    @State private var saving = false

    /// The overview's days, pages and sources as a spreadsheet.
    private var sheet: CSVExport {
        func q(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        var lines = ["\(q("Website")),\(q(o.site))", "\(q("From")),\(o.from)", "\(q("To")),\(o.to)", "", "Day,Visitors,Page views"]
        lines += o.per_day.map { "\($0.day)\($0.hour.map { " \($0):00" } ?? ""),\($0.visitors),\($0.views)" }
        lines += ["", "Page,Visitors,Page views,Time on page (seconds)"]
        lines += o.top_pages.map { "\(q($0.page)),\($0.visitors),\($0.views),\($0.avg_seconds ?? 0)" }
        lines += ["", "Source,Visitors"]
        lines += o.sources.map { "\(q($0.source)),\($0.visitors)" }
        return CSVExport(name: "\(o.site) \(o.from) to \(o.to).csv", text: lines.joined(separator: "\n") + "\n")
    }

    var body: some View {
        let name = "\(o.site) \(o.from) to \(o.to)"
        let file = sheet
        Menu {
            ShareLink(item: picture, subject: Text(name), message: Text("\(o.site): \(o.totals.visitors.formatted()) visitors and \(o.totals.views.formatted()) page views, \(o.from) to \(o.to). From ReaderCount."), preview: SharePreview(name, image: picture)) {
                Label("Share as a picture", systemImage: "photo")
            }
            ShareLink(item: file, preview: SharePreview(file.name)) {
                Label("Share as a spreadsheet", systemImage: "tablecells")
            }
            #if os(macOS)
            Button { saving = true } label: { Label("Save as a spreadsheet", systemImage: "square.and.arrow.down") }
            #endif
        } label: {
            Label("Share report", systemImage: "square.and.arrow.up")
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .fixedSize()
        #if os(macOS)
        .fileExporter(isPresented: $saving, item: file, contentTypes: [.commaSeparatedText], defaultFilename: file.name) { _ in }
        #endif
    }
}

/// The picture shared from the overview.
struct ShareCard: View {
    let o: Overview

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(o.site).font(.system(size: 24, weight: .bold))
                    Text("\(o.from) to \(o.to)").font(.system(size: 14)).foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Image("LogoMark").resizable().frame(width: 22, height: 22).clipShape(RoundedRectangle(cornerRadius: 5))
                    Text("ReaderCount").font(.system(size: 14, weight: .semibold))
                }
            }
            HStack(spacing: 10) {
                stat("Visitors", Num.short(o.totals.visitors), .blue)
                stat("Page views", Num.short(o.totals.views), .purple)
                stat("Time on page", Num.time(o.totals.avg_seconds), .teal)
                stat("Bounce rate", "\(o.totals.bounce_percent ?? 0)%", .orange)
            }
            VisitorsChart(o: o).padding(12).background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 6) {
                Text("Top pages").font(.system(size: 15, weight: .semibold))
                ForEach(o.top_pages.prefix(5), id: \.page) { p in
                    HStack { Text(p.page).lineLimit(1).truncationMode(.middle); Spacer(); Text(p.visitors.formatted()).bold().monospacedDigit() }
                        .font(.system(size: 13))
                }
            }
        }
        .padding(24)
        .frame(width: 640)
        .background(.white)
        .foregroundStyle(.black)
    }

    private func stat(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 22, weight: .bold)).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Account: who's signed in, the plan, websites, alerts, help and sign out. The same on iPhone, iPad and Mac.
/// Plans and billing are changed on the website; the app never shows prices or upgrade links.
struct AccountSections: View {
    @Environment(Model.self) private var model

    var body: some View {
        Section("Signed in as") {
            Label(model.me?.email ?? "…", systemImage: "person.crop.circle")
            if let p = model.me?.plan { Label("\(p.name) plan", systemImage: "star") }
            if let n = model.me?.devices, n > 0 { Label("Alerts on \(n) device\(n == 1 ? "" : "s")", systemImage: "bell") }
        }
        Section {
            ForEach(model.summary?.sites ?? []) { s in
                HStack(spacing: 10) {
                    SourceIcon(name: s.site)
                    Text(s.site)
                    Spacer()
                    Text("\(s.today.formatted()) today").foregroundStyle(.secondary).monospacedDigit()
                }
            }
        } header: {
            Text("Your websites")
        }
        Section {
            Link(destination: Shared.app) { Label("Manage your account on the website", systemImage: "person.badge.key") }
        } footer: {
            Text("Adding websites, your plan, team logins, earnings and API keys are on the website.")
        }
        Section {
            Link(destination: URL(string: "https://readercount.com/help/")!) { Label("Help", systemImage: "book") }
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
}

/// Phones, tablets and computers as a ring, with the share of each.
struct DevicesDonut: View {
    let o: Overview
    private static let colours: [String: Color] = ["mobile": .blue, "desktop": .purple, "tablet": .teal]

    var body: some View {
        let total = max(1, o.devices.reduce(0) { $0 + $1.visitors })
        VStack(alignment: .leading, spacing: 10) {
            Label("Devices", systemImage: "ipad.and.iphone").font(.rcHeadline)
            if o.devices.isEmpty {
                Text("Nothing yet for these dates.").font(.rcCallout).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 20) {
                    Chart(o.devices, id: \.device) { d in
                        SectorMark(angle: .value("Visitors", d.visitors), innerRadius: .ratio(0.62), angularInset: 1.5)
                            .foregroundStyle(Self.colours[d.device.lowercased()] ?? .gray)
                            .cornerRadius(3)
                    }
                    .frame(width: 130, height: 130)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(o.devices, id: \.device) { d in
                            HStack(spacing: 8) {
                                Circle().fill(Self.colours[d.device.lowercased()] ?? .gray).frame(width: 10, height: 10)
                                Text(d.device.capitalized)
                                Spacer()
                                Text("\(Int((100 * Double(d.visitors) / Double(total)).rounded()))%").bold().monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
        .card()
    }
}

/// The top few as a ring with each one's share, and the rest as Other. Shown above each breakdown list.
struct ShareChart: View {
    let title: String
    let rows: [(String, Int)]
    private static let colours: [Color] = [.blue, .purple, .teal, .orange, .pink, .green]

    private var slices: [(name: String, value: Int, colour: Color)] {
        let top = rows.prefix(6).enumerated().map { ($0.element.0, $0.element.1, Self.colours[$0.offset]) }
        let rest = rows.dropFirst(6).reduce(0) { $0 + $1.1 }
        return rest > 0 ? top + [("Other", rest, Color.gray)] : top
    }

    var body: some View {
        let parts = slices
        let total = max(1, parts.reduce(0) { $0 + $1.value })
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: "chart.pie").font(.rcHeadline)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 28) { ring(parts); legend(parts, total).frame(maxWidth: 420) }
                VStack(alignment: .leading, spacing: 16) { ring(parts).frame(maxWidth: .infinity); legend(parts, total) }
            }
        }
        .card()
    }

    private func ring(_ parts: [(name: String, value: Int, colour: Color)]) -> some View {
        Chart(parts, id: \.name) { p in
            SectorMark(angle: .value("Count", p.value), innerRadius: .ratio(0.6), angularInset: 1.5)
                .foregroundStyle(p.colour)
                .cornerRadius(3)
        }
        .frame(width: 160, height: 160)
    }

    private func legend(_ parts: [(name: String, value: Int, colour: Color)], _ total: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(parts, id: \.name) { p in
                HStack(spacing: 8) {
                    Circle().fill(p.colour).frame(width: 10, height: 10)
                    Text(p.name).lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 12)
                    Text("\(Int((100 * Double(p.value) / Double(total)).rounded()))%").bold().monospacedDigit()
                }
            }
        }
    }
}

/// A phone, tablet or computer, for the Devices report.
struct DeviceIcon: View {
    let name: String
    var body: some View {
        let symbol = switch name.lowercased() {
        case "mobile": "iphone"
        case "tablet": "ipad"
        case "desktop": "desktopcomputer"
        default: "questionmark.square.dashed"
        }
        Image(systemName: symbol).font(.system(size: 14)).foregroundStyle(.tint).frame(width: 20, height: 20).accessibilityHidden(true)
    }
}

/// The logo of a search engine, social network, AI tool or website that sent readers, as on the website. Logos come
/// through ReaderCount (app.readercount.com/logo/), so nobody else sees which sites you look at. A letter shows if there's none.
struct SourceIcon: View {
    let name: String
    var browser = false

    /// Browsers show the logo of the company that makes them.
    private static let browsers: [String: String] = [
        "Safari": "apple.com", "Chrome": "google.com", "Firefox": "firefox.com", "Edge": "microsoft.com", "Opera": "opera.com",
        "Samsung Internet": "samsung.com", "DuckDuckGo": "duckduckgo.com", "Ecosia": "ecosia.org", "Yandex": "yandex.com",
        "Facebook": "facebook.com", "Instagram": "instagram.com", "Brave": "brave.com", "Vivaldi": "vivaldi.com", "Arc": "arc.net",
    ]

    private static let hosts: [String: String] = [
        "Google": "google.com", "Google News": "news.google.com", "Bing": "bing.com", "DuckDuckGo": "duckduckgo.com", "Duck.ai": "duckduckgo.com", "duck.ai": "duckduckgo.com",
        "Yahoo": "yahoo.com", "Ecosia": "ecosia.org", "Brave Search": "search.brave.com", "Baidu": "baidu.com", "Yandex": "yandex.com",
        "Reddit": "reddit.com", "X (Twitter)": "x.com", "Facebook": "facebook.com", "Instagram": "instagram.com", "LinkedIn": "linkedin.com", "Threads": "threads.net",
        "Bluesky": "bsky.app", "Mastodon": "joinmastodon.org", "Pinterest": "pinterest.com", "Flipboard": "flipboard.com", "YouTube": "youtube.com", "Hacker News": "news.ycombinator.com",
        "ChatGPT": "chatgpt.com", "Gemini": "gemini.google.com", "Perplexity": "perplexity.ai", "Claude": "claude.ai", "Copilot": "copilot.microsoft.com", "DeepSeek": "deepseek.com",
        "Meta AI": "meta.ai", "Grok": "grok.com", "Le Chat (Mistral)": "mistral.ai", "You.com": "you.com", "Phind": "phind.com",
    ]

    private var host: String? {
        if browser { return Self.browsers[name] }
        if let h = Self.hosts[name] { return h }
        let plain = name.lowercased().replacingOccurrences(of: "www.", with: "")
        return plain.range(of: #"^[a-z0-9-]+(\.[a-z0-9-]+)+$"#, options: .regularExpression) != nil ? plain : nil
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5).fill(name == "Direct" ? Color.gray : Color.accentColor.opacity(0.8))
            if name == "Direct" {
                Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
            } else {
                Text(String(name.first ?? "?").uppercased()).font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
            }
            if let host, let url = URL(string: "https://app.readercount.com/logo/\(host)") {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().interpolation(.high).background(.white) }
                }
            }
        }
        .frame(width: 20, height: 20)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .accessibilityHidden(true)
    }
}

/// Clicked through from a row: the chart for just that page, source, country and so on, and every other report narrowed to it.
struct DrillView: View {
    @Environment(Model.self) private var model
    let filters: [String: String]
    @State private var days: Breakdown?
    @State private var lists: [String: Breakdown] = [:]

    private static let reports: [(by: String, title: String, icon: String)] = [
        ("page", "Pages", "doc.richtext"), ("source", "Sources", "arrow.down.right.circle"), ("country", "Countries", "globe.europe.africa"),
        ("town", "Towns", "building.2"), ("device", "Devices", "ipad.and.iphone"), ("browser", "Browsers", "safari"), ("campaign", "Campaigns", "megaphone"),
    ]
    private static let names = ["page": "Page", "source": "Source", "country": "Country", "town": "Town", "device": "Device", "browser": "Browser", "campaign": "Campaign"]

    private var title: String { filters.sorted { $0.key < $1.key }.map(\.value).joined(separator: " · ") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(filters.sorted { $0.key < $1.key }, id: \.key) { f in
                        HStack(spacing: 8) {
                            if f.key == "source" { SourceIcon(name: f.value) }
                            Text(Self.names[f.key] ?? f.key).foregroundStyle(.secondary)
                            Text(f.key == "country" ? "\(Num.flag(f.value)) \(f.value)" : f.value).bold().lineLimit(2)
                        }
                        .font(.rcHeadline)
                    }
                }
                PeriodPicker()
                if let days {
                    let total = days.rows.reduce(0) { $0 + $1.visitors }
                    VStack(alignment: .leading, spacing: 8) {
                        Label("\(total.formatted()) visitors", systemImage: "person.2").font(.rcHeadline)
                        Chart(days.rows.sorted { $0.name < $1.name }, id: \.name) { r in
                            BarMark(x: .value("Day", Self.short(r.name)), y: .value("Visitors", r.visitors))
                                .foregroundStyle(Color.accentColor)
                        }
                        .frame(height: 160)
                    }
                    .padding(14)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 160)
                }
                ForEach(Self.reports.filter { filters[$0.by] == nil }, id: \.by) { r in
                    if let data = lists[r.by] {
                        RankList(title: r.title, icon: r.icon,
                                 rows: data.rows.map { .init(name: r.by == "country" ? "\(Num.flag($0.name)) \($0.name)" : $0.name, value: $0.visitors, key: $0.name) },
                                 limit: 10, drill: r.by, filters: filters)
                    }
                }
            }
            .padding()
            .frame(maxWidth: 1040)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(title)
        .task(id: model.current + model.datesKey) {
            days = await model.breakdown("day", filters: filters)
            for r in Self.reports where filters[r.by] == nil {
                if let data = await model.breakdown(r.by, filters: filters) { lists[r.by] = data }
            }
        }
    }

    /// 2026-11-07 shows as 07/11.
    private static func short(_ day: String) -> String {
        let p = day.split(separator: "-"); return p.count == 3 ? "\(p[2])/\(p[1])" : day
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
                HStack {
                    if let now = o.totals.on_site_now {
                        Label("\(now) Real-Time Active Visitors", systemImage: "dot.radiowaves.left.and.right")
                            .font(.rcSubheadline.bold()).foregroundStyle(.green)
                    }
                    Spacer()
                    ShareReportButton(o: o)
                }
                TilesView(o: o, columns: columns)
                VisitorsChart(o: o).card()
                let pages = RankList(title: "Top pages", icon: "doc.richtext", rows: o.top_pages.map { .init(name: $0.page, value: $0.visitors) }, drill: "page")
                let sources = RankList(title: "Sources", icon: "arrow.down.right.circle", rows: o.sources.map { .init(name: $0.source, value: $0.visitors) }, drill: "source")
                let countries = RankList(title: "Countries", icon: "globe.europe.africa", rows: o.countries.map { .init(name: "\(Num.flag($0.country)) \($0.country)", value: $0.visitors, key: $0.country) }, drill: "country")
                if columns >= 4 {
                    HStack(alignment: .top, spacing: 16) { pages; sources }
                    ReaderMap()
                    HStack(alignment: .top, spacing: 16) { countries; DevicesDonut(o: o) }
                } else {
                    pages
                    sources
                    ReaderMap(height: 240)
                    countries
                    DevicesDonut(o: o)
                }
                if let goals = o.goals {
                    if goals.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Goals and sign-ups", systemImage: "target").font(.rcHeadline)
                            Text("No goals yet. Count newsletter sign-ups, enquiries and sales, and see which pages and sources bring them in.")
                                .font(.rcCallout).foregroundStyle(.secondary)
                            Link(destination: URL(string: "https://readercount.com/help/goals/")!) { Label("Read the goals guide", systemImage: "book") }
                                .font(.rcCallout)
                        }
                        .card()
                    } else {
                        RankList(title: "Goals and sign-ups", icon: "target", rows: goals.map { .init(name: $0.goal, value: $0.visitors, detail: "\($0.completions.formatted()) completions") })
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .task(id: model.current + model.datesKey) { if model.overview == nil { await model.loadOverview() } }
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
                // The menu bar counts every website, so say where the others are when this one has fewer.
                let elsewhere = (model.summary?.sites ?? []).filter { $0.site != model.current && $0.on_site_now > 0 }
                if !elsewhere.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "dot.radiowaves.left.and.right").foregroundStyle(.green)
                        Text("Also on your other websites now:").foregroundStyle(.secondary)
                        ForEach(elsewhere, id: \.site) { o in
                            Button { model.site = o.site } label: { Label("\(o.site) (\(o.on_site_now))", systemImage: "arrow.right.circle") }
                                .buttonStyle(.bordered).controlSize(.small)
                        }
                    }
                    .font(.rcCallout)
                }
                RankList(title: "Pages being read now", icon: "doc.text.magnifyingglass", rows: l.pages.map { .init(name: $0.path, value: $0.n) })
                RankList(title: "Where they came from", icon: "arrow.down.right.circle", rows: l.sources.map { .init(name: $0.name, value: $0.n) })
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("On the site now", systemImage: "point.topleft.down.to.point.bottomright.curvepath").font(.rcHeadline)
                        Spacer()
                        NavigationLink {
                            ScrollView { TrailsContent().padding().frame(maxWidth: 1040).frame(maxWidth: .infinity) }.navigationTitle("Visitor trails")
                        } label: {
                            Label("All of today's trails", systemImage: "list.bullet.below.rectangle")
                        }
                        .buttonStyle(.bordered)
                    }
                    ForEach(Array(l.visitors.enumerated()), id: \.offset) { item in VisitorRow(v: item.element) }
                    if l.visitors.isEmpty { Text("Nobody on the site right now.").foregroundStyle(.secondary) }
                }
                .card()
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

/// Visitor trails: every visitor on one day, newest first, with each page they read and link they clicked.
struct TrailsContent: View {
    @Environment(Model.self) private var model
    @State private var day = Date.now
    @State private var trails: Trails?
    @State private var visitors: [LiveVisitor] = []
    @State private var page = 1
    @State private var loading = false

    private static let iso: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_GB_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ErrorBanner()
            HStack(spacing: 10) {
                Button { shift(-1) } label: { Label("Day before", systemImage: "chevron.left") }
                    .labelStyle(.iconOnly).buttonStyle(.bordered)
                DatePicker("Day", selection: $day, in: ...Date.now, displayedComponents: .date)
                    .labelsHidden().datePickerStyle(.compact)
                Button { shift(1) } label: { Label("Day after", systemImage: "chevron.right") }
                    .labelStyle(.iconOnly).buttonStyle(.bordered)
                    .disabled(Calendar.current.isDateInToday(day))
                Spacer()
                if let t = trails { Text("\(t.total.formatted()) visitor\(t.total == 1 ? "" : "s")").font(.rcHeadline).foregroundStyle(.secondary) }
            }
            if trails == nil {
                ProgressView().frame(maxWidth: .infinity, minHeight: 200)
            } else if visitors.isEmpty {
                ContentUnavailableView("No visitors on this day", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
            } else {
                ForEach(Array(visitors.enumerated()), id: \.offset) { item in TrailCard(v: item.element) }
                if let t = trails, visitors.count < t.total {
                    Button {
                        Task { await more() }
                    } label: {
                        if loading { ProgressView().frame(maxWidth: .infinity) } else { Label("Show more visitors", systemImage: "arrow.down.circle").frame(maxWidth: .infinity) }
                    }
                    .buttonStyle(.bordered).controlSize(.large).disabled(loading)
                }
            }
        }
        .task(id: model.current + Self.iso.string(from: day)) {
            trails = nil
            visitors = []
            page = 1
            trails = await model.trails(day: Self.iso.string(from: day))
            visitors = trails?.visitors ?? []
        }
    }

    private func shift(_ by: Int) {
        if let d = Calendar.current.date(byAdding: .day, value: by, to: day), d <= .now { day = d }
    }

    private func more() async {
        loading = true
        defer { loading = false }
        if let next = await model.trails(day: Self.iso.string(from: day), page: page + 1) {
            page += 1
            visitors += next.visitors
        }
    }
}

/// One visitor's trail: where they're from, how they arrived, and every step with its time.
struct TrailCard: View {
    let v: LiveVisitor
    @State private var showAll = false

    /// One line per page visit: refreshes and repeat views of the same page in a row are folded together.
    struct Stop: Hashable {
        let kind: String
        let label: String
        let first: Double
        var last: Double
        var seconds: Double
        var times: Int
    }

    private var stops: [Stop] {
        var out: [Stop] = []
        for s in v.steps {
            let label = s.kind == "view" ? s.path : (s.target ?? s.path)
            if var prev = out.last, prev.kind == s.kind, prev.label == label {
                prev.last = s.ts; prev.seconds += s.seconds; prev.times += 1
                out[out.count - 1] = prev
            } else {
                out.append(Stop(kind: s.kind, label: label, first: s.ts, last: s.ts, seconds: s.seconds, times: 1))
            }
        }
        return out
    }

    private func time(_ ms: Double) -> String { Date(timeIntervalSince1970: ms / 1000).formatted(date: .omitted, time: .shortened) }

    private func detail(_ s: Stop) -> String {
        var parts: [String] = []
        let a = time(s.first), b = time(s.last)
        parts.append(a == b ? a : "\(a) to \(b)")
        if s.times > 1 { parts.append(s.kind == "view" ? "opened \(s.times) times" : "\(s.times) clicks") }
        if s.seconds > 0 { parts.append("read for \(Num.time(Int(s.seconds)))") }
        return parts.joined(separator: " · ")
    }

    private var summary: String {
        let pages = Set(v.steps.filter { $0.kind == "view" }.map(\.path)).count
        let p = "\(pages) page\(pages == 1 ? "" : "s")"
        return v.views > pages ? "\(p), \(v.views) views" : p
    }

    var body: some View {
        let all = stops
        let shown = showAll || all.count <= 8 ? all : Array(all.prefix(6))
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(Num.flag(v.country)).font(.rcTitle3)
                VStack(alignment: .leading, spacing: 2) {
                    Text([v.town, v.region].filter { !$0.isEmpty }.joined(separator: ", ").ifEmpty(v.country.ifEmpty("Somewhere"))).bold()
                    HStack(spacing: 6) {
                        SourceIcon(name: v.source.ifEmpty("Direct")).scaleEffect(0.8)
                        Text("\(v.source.ifEmpty("Direct")) · \(v.device.capitalized) · \(v.browser) on \(v.os)").font(.rcCaption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(time(v.first)) to \(time(v.last))").font(.rcCaption.bold()).monospacedDigit()
                    Text(summary).font(.rcCaption).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.offset) { item in
                    let s = item.element
                    HStack(alignment: .top, spacing: 10) {
                        VStack(spacing: 0) {
                            Circle().fill(s.kind == "view" ? Color.accentColor : Color.orange).frame(width: 9, height: 9).padding(.top, 5)
                            if item.offset < shown.count - 1 { Rectangle().fill(.quaternary).frame(width: 2).frame(maxHeight: .infinity) }
                        }
                        .frame(width: 10)
                        VStack(alignment: .leading, spacing: 1) {
                            Label(s.label == "/" && s.kind == "view" ? "Home page" : s.label, systemImage: s.kind == "view" ? "doc.text" : (s.kind == "goal" ? "target" : "arrow.up.right.square"))
                                .font(.rcCallout).lineLimit(1).truncationMode(.middle)
                            Text(detail(s)).font(.rcCaption).foregroundStyle(.secondary)
                        }
                        .padding(.bottom, 8)
                    }
                }
            }
            if all.count > shown.count || showAll && all.count > 8 {
                Button {
                    withAnimation { showAll.toggle() }
                } label: {
                    Label(showAll ? "Show less" : "Show all \(all.count) steps", systemImage: showAll ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.borderless)
                .font(.rcCaption.bold())
            }
        }
        .card()
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
                    .card()
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
                    .card()
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
        HStack(spacing: 8) {
            Button { saving = true } label: { Label("Export", systemImage: "square.and.arrow.down") }
                .buttonStyle(.bordered)
                .fileExporter(isPresented: $saving, item: file, contentTypes: [.commaSeparatedText], defaultFilename: file.name) { _ in }
            ShareLink(item: file, preview: SharePreview(file.name)) { Label("Share", systemImage: "square.and.arrow.up") }
                .buttonStyle(.bordered)
        }
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
    /// Each town's country, so towns show a flag like countries do.
    @State private var townCountry: [String: String] = [:]

    private func label(_ name: String) -> String {
        switch by {
        case "country": "\(Num.flag(name)) \(Locale.current.localizedString(forRegionCode: name) ?? name)"
        case "town": townCountry[name].map { "\(Num.flag($0)) \(name)" } ?? name
        case "device": name.capitalized
        default: name
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PeriodPicker()
            if let data {
                if data.rows.count > 1 {
                    ShareChart(title: clicks ? "Share of clicks" : "Share of visitors", rows: data.rows.map { (label($0.name), $0.count) })
                }
                RankList(title: title, icon: icon, rows: data.rows.map { .init(name: label($0.name), value: $0.count, key: $0.name) }, limit: 50, drill: clicks ? nil : by)
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .task(id: model.current + model.datesKey + by) {
            data = await model.breakdown(by, clicks: clicks)
            if by == "town" && !clicks {
                var map: [String: String] = [:]
                for p in await model.places() where map[p.town] == nil { map[p.town] = p.country }
                townCountry = map
            }
        }
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
        .task(id: model.current + model.datesKey) {
            let r = await model.searches()
            data = r.0
            problem = r.1
        }
    }
}

/// The More list: each breakdown the website has, opened on its own screen.
enum MoreItem: String, CaseIterable, Identifiable {
    case alerts, housekeeping, trails, google, sources, clicks, countries, towns, devices, browsers, campaigns
    var id: String { rawValue }
    var title: String {
        switch self {
        case .alerts: "Alerts"
        case .housekeeping: "Housekeeping"
        case .trails: "Visitor trails"
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
        case .alerts: "bell.badge"
        case .housekeeping: "checklist"
        case .trails: "point.topleft.down.to.point.bottomright.curvepath"
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
        case .alerts: AlertsContent()
        case .housekeeping: HousekeepingContent()
        case .trails: TrailsContent()
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
        ("links", "Broken links", "link"),
        ("triggers", "Goals and triggers", "target"),
        ("monthly", "Monthly review", "calendar"),
    ]

    var body: some View {
        if model.pushAllowed == false {
            Label("Alerts are switched off for ReaderCount in Settings.", systemImage: "bell.slash").foregroundStyle(.secondary)
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], alignment: .leading, spacing: 12) {
            ForEach(Self.kinds, id: \.0) { k in
                Toggle(isOn: Binding(get: { model.alerts[k.0] ?? false }, set: { on in Task { await model.setAlert(k.0, on) } })) {
                    Label(k.1, systemImage: k.2).font(.rcBody)
                }
                .toggleStyle(.switch)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}
