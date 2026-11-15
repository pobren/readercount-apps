// Alerts: rules the owner sets up (checked every hour on the server, sent as notifications to their devices),
// plus the built in alerts (spikes, website down, broken links, triggers, the monthly review). See src/rules.ts.

import SwiftUI

struct AlertRule: Codable, Identifiable, Hashable {
    var id: Int
    var site: String
    var kind: String
    var scope: String
    var target: String
    var period: String
    var threshold: Double
    var enabled: Bool
    var last_sent: Double
    var summary: String?
}

struct AlertList: Codable {
    let alerts: [AlertRule]
    let devices: Int
}

enum AlertKind: String, CaseIterable, Identifiable {
    case above, below, stopped, bounce, health, source
    var id: String { rawValue }
    var title: String {
        switch self {
        case .above: "Visitors go over a number"
        case .below: "Visitors drop under a number"
        case .stopped: "Visits stop"
        case .bounce: "Bounce rate is high"
        case .health: "Something new to fix in Site Health"
        case .source: "A new website sends readers"
        }
    }
    var icon: String {
        switch self {
        case .above: "arrow.up.right.circle"
        case .below: "arrow.down.right.circle"
        case .stopped: "pause.circle"
        case .bounce: "arrow.uturn.left.circle"
        case .health: "stethoscope"
        case .source: "sparkles"
        }
    }
    var tint: Color {
        switch self {
        case .above: .green
        case .below, .stopped: .orange
        case .bounce: .pink
        case .health: .red
        case .source: .purple
        }
    }
    var defaultThreshold: Double {
        switch self {
        case .above: 100
        case .below: 50
        case .stopped: 6
        case .bounce: 80
        case .health: 0
        case .source: 3
        }
    }
}

struct AlertsContent: View {
    @Environment(Model.self) private var model
    @State private var list: [AlertRule] = []
    @State private var loaded = false
    @State private var editing: AlertRule?
    @State private var message: String?

    private var mine: [AlertRule] { list.filter { $0.site == model.current } }

    private func load() async {
        if Demo.on {
            list = [AlertRule(id: 1, site: model.current, kind: "above", scope: "site", target: "", period: "hour", threshold: 100, enabled: true, last_sent: 0, summary: "Visitors in an hour goes over 100"),
                    AlertRule(id: 2, site: model.current, kind: "stopped", scope: "site", target: "", period: "day", threshold: 6, enabled: true, last_sent: 0, summary: "No visits for 6 hours"),
                    AlertRule(id: 3, site: model.current, kind: "source", scope: "site", target: "", period: "day", threshold: 3, enabled: true, last_sent: 0, summary: "A new website sends 3 or more readers")]
            loaded = true
            return
        }
        do {
            list = try await API.shared.get(AlertList.self, "app/v1/alerts").alerts
        } catch { message = error.localizedDescription }
        loaded = true
    }

    private func blank(_ kind: AlertKind) -> AlertRule {
        AlertRule(id: 0, site: model.current, kind: kind.rawValue, scope: "site", target: "", period: kind == .above ? "hour" : "day", threshold: kind.defaultThreshold, enabled: true, last_sent: 0)
    }

    private func toggle(_ r: AlertRule, _ on: Bool) async {
        var r = r
        r.enabled = on
        if let i = list.firstIndex(where: { $0.id == r.id }) { list[i].enabled = on }
        if Demo.on { return }
        do { try await API.shared.send("app/v1/alerts", alertBody(r)) } catch { message = error.localizedDescription; await load() }
    }

    private func remove(_ r: AlertRule) async {
        list.removeAll { $0.id == r.id }
        if Demo.on { return }
        do { try await API.shared.send("app/v1/alerts", method: "DELETE", ["id": r.id]) } catch { message = error.localizedDescription; await load() }
    }

    private func test() async {
        do {
            try await API.shared.send("app/v1/alerts/test", [:])
            message = "Test sent. It should arrive in a few seconds."
        } catch { message = error.localizedDescription }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if model.pushAllowed != true {
                HStack(spacing: 12) {
                    Image(systemName: "bell.badge").font(.rcTitle3).foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Allow notifications").bold()
                        Text("Alerts arrive as notifications, so ReaderCount needs your OK first.").font(.rcCaption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { Task { await model.askForPush() } } label: { Label("Allow", systemImage: "checkmark.circle") }
                        .buttonStyle(.borderedProminent)
                }
                .card()
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Your alerts for \(model.current)", systemImage: "bell.badge").font(.rcHeadline)
                    Spacer()
                    Menu {
                        ForEach(AlertKind.allCases) { k in
                            Button { editing = blank(k) } label: { Label(k.title, systemImage: k.icon) }
                        }
                    } label: {
                        Label("New alert", systemImage: "plus")
                    }
                    .menuStyle(.button)
                    .buttonStyle(.borderedProminent)
                    .fixedSize()
                }
                Text("We check every hour and send a notification to your devices. Each alert sends at most once an hour or once a day, so it won't flood you.")
                    .font(.rcCaption).foregroundStyle(.secondary)
                if loaded && mine.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No alerts yet. Some good ones to start with:").font(.rcCallout)
                        ForEach([AlertKind.stopped, .above, .source, .health]) { k in
                            Button { editing = blank(k) } label: { Label(k.title, systemImage: k.icon) }
                                .buttonStyle(.bordered)
                        }
                    }
                }
                ForEach(mine) { r in
                    let k = AlertKind(rawValue: r.kind) ?? .above
                    HStack(spacing: 12) {
                        Image(systemName: k.icon).font(.rcTitle3).foregroundStyle(k.tint).frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.summary ?? k.title).font(.rcBody).foregroundStyle(r.enabled ? .primary : .secondary)
                            if r.last_sent > 0 {
                                Text("Last sent \(Date(timeIntervalSince1970: r.last_sent / 1000).formatted(.relative(presentation: .named)))").font(.rcCaption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Toggle("On", isOn: Binding(get: { r.enabled }, set: { on in Task { await toggle(r, on) } })).labelsHidden()
                        Menu {
                            Button { editing = r } label: { Label("Change", systemImage: "pencil") }
                            Button(role: .destructive) { Task { await remove(r) } } label: { Label("Remove", systemImage: "trash") }
                        } label: {
                            Image(systemName: "ellipsis.circle").font(.rcTitle3)
                        }
                        .menuStyle(.button)
                        .buttonStyle(.borderless)
                        .fixedSize()
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .onTapGesture { editing = r }
                    Divider()
                }
                if model.pushAllowed == true {
                    Button { Task { await test() } } label: { Label("Send a test notification", systemImage: "paperplane") }
                        .buttonStyle(.bordered)
                }
                if let message { Text(message).font(.rcCaption).foregroundStyle(.secondary) }
            }
            .card()

            VStack(alignment: .leading, spacing: 10) {
                Label("Always on alerts", systemImage: "bell").font(.rcHeadline)
                Text("These cover all your websites. Switch off any you don't want on this device.").font(.rcCaption).foregroundStyle(.secondary)
                AlertsSettings()
            }
            .card()
        }
        .task(id: model.current) { await load() }
        .refreshable { await load() }
        .sheet(item: $editing) { r in
            AlertEditor(rule: r) { await load() }
                .environment(model)
        }
    }
}

func alertBody(_ r: AlertRule) -> [String: Any] {
    var b: [String: Any] = ["site": r.site, "kind": r.kind, "scope": r.scope, "target": r.target, "period": r.period, "threshold": r.threshold, "enabled": r.enabled]
    if r.id > 0 { b["id"] = r.id }
    return b
}

struct AlertEditor: View {
    @Environment(Model.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State var rule: AlertRule
    var saved: () async -> Void
    @State private var error: String?
    @State private var saving = false

    private var kind: AlertKind { AlertKind(rawValue: rule.kind) ?? .above }

    private var suggestions: [String] {
        guard let o = model.overview else { return [] }
        return rule.scope == "page" ? o.top_pages.prefix(12).map(\.page) : o.sources.prefix(12).map(\.source)
    }

    private func save() async {
        saving = true
        defer { saving = false }
        if Demo.on { dismiss(); return }
        do {
            try await API.shared.send("app/v1/alerts", alertBody(rule))
            await saved()
            dismiss()
        } catch { self.error = error.localizedDescription }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Alert me when") {
                    Picker("Alert me when", selection: $rule.kind) {
                        ForEach(AlertKind.allCases) { k in Label(k.title, systemImage: k.icon).tag(k.rawValue) }
                    }
                    .labelsHidden()
                    .pickerStyle(.inline)
                    .onChange(of: rule.kind) { _, new in rule.threshold = AlertKind(rawValue: new)?.defaultThreshold ?? 0 }
                }
                switch kind {
                case .above, .below:
                    Section("Watch") {
                        Picker("Watch", selection: $rule.scope) {
                            Text("The whole website").tag("site")
                            Text("One page").tag("page")
                            Text("One source").tag("source")
                        }
                        .pickerStyle(.segmented)
                        if rule.scope != "site" {
                            HStack {
                                TextField(rule.scope == "page" ? "Page, such as /about/" : "Source, such as Google", text: $rule.target)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                                    #if os(iOS)
                                    .textInputAutocapitalization(.never)
                                    #endif
                                if !suggestions.isEmpty {
                                    Menu {
                                        ForEach(suggestions, id: \.self) { s in Button(s) { rule.target = s } }
                                    } label: { Label("Choose", systemImage: "list.bullet") }
                                    .fixedSize()
                                }
                            }
                        }
                    }
                    Section("Number of visitors") {
                        Picker("In", selection: $rule.period) {
                            Text("In an hour").tag("hour")
                            Text("In a day").tag("day")
                        }
                        .pickerStyle(.segmented)
                        Stepper(value: $rule.threshold, in: (kind == .above ? 1 : 0)...1_000_000, step: rule.threshold >= 100 ? 10 : 1) {
                            HStack {
                                Text(kind == .above ? "Over" : "Under")
                                TextField("Number", value: $rule.threshold, format: .number).textFieldStyle(.roundedBorder).frame(maxWidth: 110).monospacedDigit()
                                Text("visitors")
                            }
                        }
                    }
                case .stopped:
                    Section {
                        Stepper("No visits for \(Int(rule.threshold)) hour\(rule.threshold == 1 ? "" : "s")", value: $rule.threshold, in: 1...168)
                    } footer: { Text("We tell you once, then again only after visits have come back and stopped again.") }
                case .bounce:
                    Section {
                        Stepper("Bounce rate over \(Int(rule.threshold))%", value: $rule.threshold, in: 1...100, step: 5)
                    } footer: { Text("Over the last 24 hours, once there are at least 20 visitors. At most once a day.") }
                case .health:
                    Section {
                        Text("You'll get a notification when something new appears under Site Health as needing a fix, such as a broken page or visits stopping.")
                    }
                case .source:
                    Section {
                        Stepper("At least \(Int(rule.threshold)) reader\(rule.threshold == 1 ? "" : "s") in an hour", value: $rule.threshold, in: 1...100)
                    } footer: { Text("A website that hasn't sent you anyone in the last 90 days. Setting a minimum skips one-off visits.") }
                }
                Section {
                    Toggle(isOn: $rule.enabled) { Label("Switched on", systemImage: "bell") }
                } footer: {
                    Text("For \(rule.site). Sent as a notification to your devices with ReaderCount.")
                }
                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(rule.id == 0 ? "New alert" : "Change alert")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Label("Cancel", systemImage: "xmark") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await save() } } label: { Label("Save", systemImage: "checkmark") }
                        .disabled(saving)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 560)
        #endif
    }
}
