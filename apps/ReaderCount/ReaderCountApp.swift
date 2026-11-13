// ReaderCount for iPhone, iPad and Mac. One app: tabs on the phone, a sidebar on the iPad, and on the Mac a window
// with the website's left menu plus a live count in the menu bar.

import SwiftUI
import UserNotifications

@main
struct ReaderCountApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    #else
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    #endif
    @State private var model = Model.shared
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
                .environment(model)
                #if os(macOS)
                .frame(minWidth: model.signedIn ? 900 : 420, minHeight: model.signedIn ? 620 : 520)
                #endif
        }
        .onChange(of: phase) { _, now in
            if now == .active { Task { await model.refresh(); await model.checkPushAllowed() } }
        }
        #if os(macOS)
        .defaultSize(width: 1160, height: 760)
        .commands {
            CommandGroup(replacing: .help) {
                Link(destination: URL(string: "https://readercount.com/help/")!) { Label("ReaderCount help", systemImage: "book") }
                Link(destination: URL(string: "mailto:hello@readercount.com")!) { Label("Email us", systemImage: "envelope") }
                Divider()
                Link(destination: URL(string: "https://readercount.com/privacy/")!) { Label("Privacy", systemImage: "hand.raised") }
                Link(destination: URL(string: "https://readercount.com/terms/")!) { Label("Terms", systemImage: "doc.text") }
            }
        }
        #endif

        #if os(macOS)
        MenuBarExtra {
            MenuBarView().environment(model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}

struct RootView: View {
    @Environment(Model.self) private var model

    var body: some View {
        if model.signedIn {
            #if os(macOS)
            MacRoot()
            #else
            PhoneRoot()
            #endif
        } else {
            SignInView()
        }
    }
}

#if os(iOS)
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        if Tokens.load() != nil {
            Task { @MainActor in
                await Model.shared.checkPushAllowed()
                if Model.shared.pushAllowed == true { application.registerForRemoteNotifications() }
            }
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in await Model.shared.gotDeviceToken(deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {}

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let site = response.notification.request.content.userInfo["site"] as? String
        await MainActor.run {
            if let site { Model.shared.site = site }
            Task { await Model.shared.refresh() }
        }
    }
}
#else
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        // The menu bar count and the open window stay up to date every 30 seconds, window or not.
        Task { @MainActor in
            while true {
                await Model.shared.refresh()
                try? await Task.sleep(for: .seconds(30))
            }
        }
        if Tokens.load() != nil {
            Task { @MainActor in
                await Model.shared.checkPushAllowed()
                if Model.shared.pushAllowed == true { NSApplication.shared.registerForRemoteNotifications() }
            }
        }
    }

    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in await Model.shared.gotDeviceToken(deviceToken) }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let site = response.notification.request.content.userInfo["site"] as? String
        await MainActor.run {
            if let site { Model.shared.site = site }
            Task { await Model.shared.refresh() }
        }
    }
}
#endif
