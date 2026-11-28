// Widgets: visitors today and who's on now, for the home screen, lock screen, iPad and Mac desktop.
// The app saves a summary in the App Group after each refresh; on iPhone and iPad the widget also fetches a fresh
// one itself with the shared sign in.

import WidgetKit
import SwiftUI

struct Entry: TimelineEntry {
    let date: Date
    let summary: SitesSummary?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: Date(), summary: .sample) }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: Date(), summary: context.isPreview ? .sample : SitesSummary.load() ?? .sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        Task {
            var summary = SitesSummary.load()
            if Tokens.load() != nil, let fresh = try? await API.shared.get(SitesSummary.self, "app/v1/sites") {
                fresh.save()
                summary = fresh
            }
            completion(Timeline(entries: [Entry(date: Date(), summary: summary)], policy: .after(Date().addingTimeInterval(15 * 60))))
        }
    }
}

/// A small line of numbers, scaled to fit its box: the shape of the last days.
struct Sparkline: Shape {
    let values: [Int]
    var closed = false

    func path(in r: CGRect) -> Path {
        var p = Path()
        guard values.count > 1 else { return p }
        let top = Double(values.max() ?? 0), low = Double(min(values.min() ?? 0, 0))
        let span = max(top - low, 1)
        let pts = values.enumerated().map { i, v in
            CGPoint(x: r.minX + r.width * Double(i) / Double(values.count - 1), y: r.maxY - 1 - (r.height - 2) * (Double(v) - low) / span)
        }
        p.move(to: pts[0])
        for pt in pts.dropFirst() { p.addLine(to: pt) }
        if closed {
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.closeSubpath()
        }
        return p
    }
}

/// The line with a soft fill under it.
struct Trend: View {
    let values: [Int]
    var tint: Color = .blue
    var fill = true

    var body: some View {
        ZStack {
            if fill { Sparkline(values: values, closed: true).fill(tint.opacity(0.16)) }
            Sparkline(values: values).stroke(tint, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        }
    }
}

extension Color {
    static let wUp = Color(red: 0.08, green: 0.50, blue: 0.24)
    static let wDown = Color(red: 0.76, green: 0.25, blue: 0.05)
    static let wLive = Color(red: 0.13, green: 0.70, blue: 0.33)

    /// Each website keeps the same colour, from its name.
    static func site(_ name: String) -> Color {
        let palette: [Color] = [.blue, .purple, .teal, .orange, .green, .pink, .indigo, .cyan, .brown, .mint]
        let n = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return palette[n % palette.count]
    }
}

/// "↑21%" in green or "↓8%" in orange, as a small pill.
struct ChangePill: View {
    let change: Int?
    var plain = false

    var body: some View {
        if let c = change {
            let colour: Color = c >= 0 ? .wUp : .wDown
            Text("\(c >= 0 ? "↑" : "↓")\(abs(c))%")
                .font(.system(size: 11, weight: .bold, design: .rounded)).monospacedDigit()
                .foregroundStyle(colour)
                .padding(.horizontal, plain ? 0 : 6).padding(.vertical, plain ? 0 : 2)
                .background(plain ? Color.clear : colour.opacity(0.14), in: Capsule())
        }
    }
}

struct LiveDot: View {
    let count: Int
    var short = false

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(count > 0 ? Color.wLive : Color.secondary.opacity(0.5)).frame(width: 7, height: 7)
            Text(short ? "\(count) now" : "\(count) reading now")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(count > 0 ? Color.wLive : Color.secondary)
    }
}

struct Brand: View {
    let title: String
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "chart.bar.fill").font(.caption2.bold()).foregroundStyle(Color.accentColor)
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1)
        }
    }
}

struct WidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: Entry

    var body: some View {
        if let s = entry.summary, let first = s.sites.first {
            switch family {
            #if os(iOS)
            case .accessoryCircular:
                VStack(spacing: 0) {
                    Text("\(s.totalNow)").font(.title2.bold()).monospacedDigit()
                    Text("now").font(.caption2)
                }
            case .accessoryRectangular:
                VStack(alignment: .leading) {
                    Label("\(s.totalNow) reading now", systemImage: "chart.bar.fill").font(.headline)
                    Text("\(s.totalToday.formatted()) visitors today")
                }
            case .accessoryInline:
                Text("\(s.totalNow) now · \(s.totalToday) today")
            #endif
            case .systemSmall: small(first)
            case .systemMedium: medium(s)
            default: large(s)
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "chart.bar.fill").font(.title).foregroundStyle(Color.accentColor)
                Text("Open ReaderCount to sign in").font(.caption).multilineTextAlignment(.center)
            }
        }
    }

    /// Every site's days added together, for the all sites line.
    private func totals(_ s: SitesSummary) -> [Int] {
        let n = s.sites.map(\.days.count).max() ?? 0
        return (0..<n).map { i in s.sites.reduce(0) { t, site in t + (i < site.days.count ? site.days[i] : 0) } }
    }

    private func big(_ n: Int, size: CGFloat) -> some View {
        Text(Num.short(n)).font(.system(size: size, weight: .heavy, design: .rounded)).monospacedDigit()
            .minimumScaleFactor(0.6).lineLimit(1).contentTransition(.numericText())
    }

    // One site: today's visitors, the change on last week, its last two weeks and who's on now.
    private func small(_ site: SitesSummary.Site) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Brand(title: site.site)
            Spacer(minLength: 4)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                big(site.today, size: 38)
                ChangePill(change: site.change)
            }
            Text("visitors today").font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Trend(values: site.days, tint: .accentColor).frame(height: 26)
            Spacer(minLength: 4)
            LiveDot(count: site.on_site_now)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // All sites: the total on the left, the top three with a bar each on the right.
    private func medium(_ s: SitesSummary) -> some View {
        let top = Array(s.sites.prefix(3)), most = max(top.map(\.today).max() ?? 1, 1)
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Brand(title: s.sites.count > 1 ? "All sites today" : "Today")
                Spacer(minLength: 4)
                big(s.totalToday, size: 36)
                Text("visitors").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Trend(values: totals(s), tint: .accentColor).frame(height: 22)
                Spacer(minLength: 4)
                LiveDot(count: s.totalNow)
            }
            .frame(width: 118, alignment: .leading)
            Rectangle().fill(.quaternary).frame(width: 1)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(top.enumerated()), id: \.element.id) { i, site in
                    if i > 0 { Spacer(minLength: 6) }
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(site.site).font(.caption.weight(.semibold)).lineLimit(1).truncationMode(.middle)
                            Spacer(minLength: 2)
                            Text(Num.short(site.today)).font(.subheadline.bold()).monospacedDigit()
                            ChangePill(change: site.change, plain: true).frame(minWidth: 34, alignment: .trailing)
                        }
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.quaternary)
                                Capsule().fill(Color.site(site.site)).frame(width: max(5, g.size.width * Double(site.today) / Double(most)))
                            }
                        }
                        .frame(height: 5)
                    }
                }
                if top.count < 3 { Spacer(minLength: 0) }
            }
            .padding(.vertical, 2)
        }
    }

    // Every site (up to 8): its own colour, a line of its last week, today and the change.
    private func large(_ s: SitesSummary) -> some View {
        let rows = Array(s.sites.prefix(8))
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Brand(title: "ReaderCount · Today")
                Spacer()
                LiveDot(count: s.totalNow, short: true)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background((s.totalNow > 0 ? Color.wLive : Color.secondary).opacity(0.14), in: Capsule())
            }
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    big(s.totalToday, size: 34)
                    Text(s.sites.count == 1 ? "visitors" : "visitors across \(s.sites.count) sites").font(.caption).foregroundStyle(.secondary)
                }
                Trend(values: totals(s), tint: .accentColor).frame(height: 38)
            }
            Rectangle().fill(.quaternary).frame(height: 1)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { i, site in
                    if i > 0 { Spacer(minLength: 2) }
                    HStack(spacing: 8) {
                        Text(site.site.prefix(1).uppercased())
                            .font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Color.site(site.site), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        Text(site.site).font(.footnote.weight(.medium)).lineLimit(1).truncationMode(.middle)
                        Spacer(minLength: 4)
                        Trend(values: Array(site.days.suffix(7)), tint: Color.site(site.site), fill: false).frame(width: 50, height: 16)
                        Text(Num.short(site.today)).font(.subheadline.bold()).monospacedDigit().frame(minWidth: 26, alignment: .trailing)
                        ChangePill(change: site.change, plain: true).frame(width: 40, alignment: .trailing)
                    }
                }
                if rows.count < 8 { Spacer(minLength: 0) }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            Text("Updated \((s.updated ?? entry.date).formatted(date: .omitted, time: .shortened)) · change is this week on last week")
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
    }
}

@main
struct ReaderCountWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ReaderCountToday", provider: Provider()) { entry in
            WidgetView(entry: entry).containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Visitors today")
        .description("Visitors today and who's reading now.")
        .supportedFamilies(families)
    }

    private var families: [WidgetFamily] {
        #if os(iOS)
        [.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        #else
        [.systemSmall, .systemMedium, .systemLarge]
        #endif
    }
}
