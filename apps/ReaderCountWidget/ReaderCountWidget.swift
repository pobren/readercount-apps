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
            case .systemSmall:
                VStack(alignment: .leading, spacing: 4) {
                    Label("ReaderCount", systemImage: "chart.bar.fill").font(.caption.bold()).foregroundStyle(Color.accentColor)
                    Spacer()
                    Text(Num.short(first.today)).font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit()
                    Text("visitors today").font(.caption).foregroundStyle(.secondary)
                    Text("\(first.on_site_now) on now").font(.caption.bold()).foregroundStyle(.green)
                    Text(first.site).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            default:
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("ReaderCount", systemImage: "chart.bar.fill").font(.caption.bold()).foregroundStyle(Color.accentColor)
                        Spacer()
                        Text("\(s.totalNow) on now").font(.caption.bold()).foregroundStyle(.green)
                    }
                    ForEach(s.sites.prefix(family == .systemLarge ? 8 : 3)) { site in
                        HStack {
                            Text(site.site).font(.callout).lineLimit(1)
                            Spacer()
                            Text(Num.short(site.today)).font(.callout.bold()).monospacedDigit()
                            if let c = site.change {
                                Text(c >= 0 ? "▲\(c)%" : "▼\(-c)%").font(.caption2.bold()).foregroundStyle(c >= 0 ? .green : .orange)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    Text("Visitors today, change on the week before").font(.caption2).foregroundStyle(.secondary)
                }
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "chart.bar.fill").font(.title).foregroundStyle(Color.accentColor)
                Text("Open ReaderCount to sign in").font(.caption).multilineTextAlignment(.center)
            }
        }
    }
}

@main
struct ReaderCountWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ReaderCountToday", provider: Provider()) { entry in
            WidgetView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
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
