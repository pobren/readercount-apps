// Signing in inside the app, like Site Patrol: your email, then the six-digit code ReaderCount emails you.
// No password and no browser window. Accounts are made on the website.

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct SignInView: View {
    @Environment(Model.self) private var model
    @State private var email = ""
    @State private var code = ""
    @State private var codeSent = false
    @FocusState private var focus: Field?
    @Environment(\.scenePhase) private var phase

    private enum Field { case email, code }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image("LogoMark").resizable().frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous)).accessibilityHidden(true)
                    Text("ReaderCount").font(.rcLargeTitle.bold())
                    Text("Your website's readers, live, wherever you are.")
                        .font(.rcTitle3).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                if codeSent {
                    codeStep
                } else {
                    emailStep
                }

                if let error = model.error {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.rcCallout.bold())
                        .multilineTextAlignment(.center)
                }

                Divider()

                VStack(spacing: 8) {
                    Text("New to ReaderCount?").font(.rcHeadline)
                    Text("Make your account and add your website at readercount.com, then sign in here.")
                        .font(.rcCallout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Link(destination: Shared.website) {
                        Label("Go to readercount.com", systemImage: "safari")
                    }
                    .font(.rcCallout.bold())
                }
            }
            .padding(24)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
        }
        .onAppear { focus = .email }
        .onChange(of: model.codeLink) { _, link in
            guard let link else { return }
            if !link.email.isEmpty { email = link.email }
            code = link.code
            codeSent = true
            model.codeLink = nil
            Task { await finish() }
        }
        // Apple Mail's code AutoFill is offered when the box gains focus, so coming back from Mail gives it a fresh focus.
        .onChange(of: phase) { _, now in if now == .active { refocus() } }
        #if os(macOS)
        // On the Mac the window stays "active" while you look at Mail, so listen for the app itself coming back.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refocus() }
        #endif
    }

    private func refocus() {
        guard codeSent, code.isEmpty else { return }
        focus = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            focus = .code
        }
    }

    private var emailStep: some View {
        VStack(spacing: 14) {
            TextField("Email address", text: $email)
                .textContentType(.username)
                #if os(iOS)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
                .focused($focus, equals: .email)
                .submitLabel(.continue)
                .onSubmit { Task { await send() } }
                .padding(12)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))

            Button {
                Task { await send() }
            } label: {
                if model.busy {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Label("Email me a code", systemImage: "envelope").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(model.busy || !email.contains("@"))

            Text("We'll email you a six-digit code. No password needed.")
                .font(.rcCallout).foregroundStyle(.secondary).multilineTextAlignment(.center)

            HStack { VStack { Divider() }; Text("or").font(.rcCaption).foregroundStyle(.secondary); VStack { Divider() } }

            Button {
                Task { await model.signInWithPasskey() }
            } label: {
                Label("Sign in with a passkey", systemImage: "person.badge.key").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered).controlSize(.large)
            .disabled(model.busy)
        }
    }

    private var codeStep: some View {
        VStack(spacing: 14) {
            Text("We've emailed a six-digit code to \(email). Click Sign in to the app in the email, or type the code here.")
                .font(.rcCallout).multilineTextAlignment(.center)

            TextField("Six-digit code", text: $code)
                .textContentType(.oneTimeCode)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .font(.rcTitle2.monospacedDigit())
                .multilineTextAlignment(.center)
                .focused($focus, equals: .code)
                .onSubmit { Task { await finish() } }
                .onChange(of: code) { _, now in
                    if now.filter(\.isNumber).count == 6 { Task { await finish() } }
                }
                .padding(12)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))

            Button {
                Task { await finish() }
            } label: {
                if model.busy {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Label("Sign in", systemImage: "person.crop.circle.badge.checkmark").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(model.busy || code.filter(\.isNumber).count != 6)

            // Apple Mail fills the code in by itself (above the keyboard, or in the field on the Mac). From Gmail or
            // anywhere else, copy the code and paste it here.
            HStack(spacing: 10) {
                Text("Copied the code from your email?").font(.rcCaption).foregroundStyle(.secondary)
                PasteButton(payloadType: String.self) { strings in
                    let digits = (strings.first ?? "").components(separatedBy: CharacterSet.decimalDigits.inverted).first { $0.count == 6 } ?? ""
                    Task { @MainActor in if !digits.isEmpty { code = digits } }
                }
                .buttonBorderShape(.capsule)
                .labelStyle(.titleAndIcon)
            }

            HStack(spacing: 20) {
                Button {
                    code = ""
                    Task { await send() }
                } label: {
                    Label("Send a new code", systemImage: "arrow.clockwise")
                }
                Button {
                    codeSent = false
                    code = ""
                    model.error = nil
                    focus = .email
                } label: {
                    Label("Use another email", systemImage: "pencil")
                }
            }
            .font(.rcCallout)
            .buttonStyle(.borderless)
            .disabled(model.busy)
        }
    }

    private func send() async {
        guard email.contains("@"), !model.busy else { return }
        if await model.requestCode(email: email) {
            codeSent = true
            focus = .code
        }
    }

    private func finish() async {
        guard code.filter(\.isNumber).count == 6, !model.busy else { return }
        await model.signIn(email: email, code: code)
    }
}
