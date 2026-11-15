// Housekeeping: the files search engines and others read on the website (robots.txt, the sitemap, ads.txt,
// llms.txt, security.txt, the favicon), as they are, with plain notes on anything wrong. From /app/v1/housekeeping.

import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct HouseNote: Codable, Hashable { let level: String; let text: String }
struct HouseFile: Codable, Hashable, Identifiable {
    let key: String
    let name: String
    let url: String
    let status: Int?
    let found: Bool
    let size: Int
    let text: String
    let notes: [HouseNote]
    var id: String { key }
}
struct Housekeeping: Codable { let site: String; let checked: Double; let files: [HouseFile] }

struct HousekeepingContent: View {
    @Environment(Model.self) private var model
    @State private var data: Housekeeping?
    @State private var error: String?
    @State private var loading = false

    private func load() async {
        loading = true
        defer { loading = false }
        if Demo.on {
            data = Housekeeping(site: model.current, checked: Date.now.timeIntervalSince1970 * 1000, files: [
                HouseFile(key: "robots", name: "robots.txt", url: "https://\(model.current)/robots.txt", status: 200, found: true, size: 120, text: "User-agent: *\nAllow: /\n\nSitemap: https://\(model.current)/sitemap.xml\n", notes: [HouseNote(level: "good", text: "Search engines can read your website."), HouseNote(level: "info", text: "AI crawlers such as GPTBot and ClaudeBot are allowed.")]),
                HouseFile(key: "sitemap", name: "Sitemap", url: "https://\(model.current)/sitemap.xml", status: 200, found: true, size: 9000, text: "<?xml version=\"1.0\"?>\n<urlset>…</urlset>", notes: [HouseNote(level: "good", text: "84 pages listed."), HouseNote(level: "good", text: "Updated in the last day.")]),
                HouseFile(key: "llms", name: "llms.txt", url: "https://\(model.current)/llms.txt", status: 404, found: false, size: 0, text: "", notes: [HouseNote(level: "info", text: "No llms.txt. It's a new, optional file that gives AI tools a short guide to your website.")]),
            ])
            return
        }
        do {
            data = try await API.shared.get(Housekeeping.self, "app/v1/housekeeping", ["site": model.current])
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Housekeeping for \(model.current)", systemImage: "checklist").font(.rcHeadline)
                    Text("The files search engines, ad networks and AI tools read on your website.").font(.rcCaption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { Task { await load() } } label: { Label("Check again", systemImage: "arrow.clockwise") }
                    .buttonStyle(.bordered)
                    .disabled(loading)
            }
            if loading && data == nil { ProgressView("Reading your website…").frame(maxWidth: .infinity).padding() }
            if let error { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
            if let data {
                let fixes = data.files.flatMap(\.notes).filter { $0.level == "fix" }.count
                Label(fixes == 0 ? "All looks fine" : "\(fixes) thing\(fixes == 1 ? "" : "s") to fix", systemImage: fixes == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.rcHeadline)
                    .foregroundStyle(fixes == 0 ? .green : .orange)
                ForEach(data.files) { f in HouseCard(file: f) }
            }
        }
        .task(id: model.current) { await load() }
    }
}

struct HouseCard: View {
    let file: HouseFile
    @State private var open = false

    private func icon(_ level: String) -> (String, Color) {
        switch level {
        case "fix": ("exclamationmark.triangle.fill", .orange)
        case "good": ("checkmark.circle.fill", .green)
        default: ("info.circle.fill", .blue)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: file.found ? "doc.text.fill" : "doc.badge.ellipsis").font(.rcTitle3).foregroundStyle(file.found ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name).font(.rcHeadline)
                    Text(file.found ? "\(file.url) · \(ByteCountFormatter.string(fromByteCount: Int64(file.size), countStyle: .file))" : "Not found\(file.status.map { " (\($0))" } ?? "")")
                        .font(.rcCaption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                if file.found, let u = URL(string: file.url) {
                    Link(destination: u) { Label("Open", systemImage: "safari") }.buttonStyle(.bordered).controlSize(.small)
                }
            }
            ForEach(file.notes, id: \.self) { n in
                let (img, tint) = icon(n.level)
                Label { Text(n.text).font(.rcCallout) } icon: { Image(systemName: img).foregroundStyle(tint) }
            }
            if file.found && !file.text.isEmpty {
                DisclosureGroup(isExpanded: $open) {
                    ScrollView([.vertical, .horizontal]) {
                        Text(file.text)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(maxHeight: 320)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                    HStack {
                        Button { copy(file.text) } label: { Label("Copy", systemImage: "doc.on.doc") }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                } label: {
                    Label(open ? "Hide the file" : "View the file", systemImage: "eye").font(.rcCallout.bold())
                }
            }
        }
        .card()
    }

    private func copy(_ s: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
        #else
        UIPasteboard.general.string = s
        #endif
    }
}
