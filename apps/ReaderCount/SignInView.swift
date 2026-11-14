// Signing in inside the app, like Site Patrol: your email, then the six-digit code ReaderCount emails you.
// No password and no browser window. Accounts are made on the website.

import SwiftUI

struct SignInView: View {
    @Environment(Model.self) private var model
    @State private var email = ""
    @State private var code = ""
    @State private var codeSent = false
    @FocusState private var focus: Field?

    private enum Field { case email, code }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image("LogoMark").resizable().frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous)).accessibilityHidden(true)
                    Text("ReaderCount").font(.largeTitle.bold())
                    Text("Your website's readers, live, wherever you are.")
                        .font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                if codeSent {
                    codeStep
                } else {
                    emailStep
                }

                if let error = model.error {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.callout.bold())
                        .multilineTextAlignment(.center)
                }

                Divider()

                VStack(spacing: 8) {
                    Text("New to ReaderCount?").font(.headline)
                    Text("Make your account and add your website at readercount.com, then sign in here.")
                        .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Link(destination: Shared.website) {
                        Label("Go to readercount.com", systemImage: "safari")
                    }
                    .font(.callout.bold())
                }
            }
            .padding(24)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
        }
        .onAppear { focus = .email }
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
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }

    private var codeStep: some View {
        VStack(spacing: 14) {
            Text("We've emailed a six-digit code to \(email). Type it here.")
                .font(.callout).multilineTextAlignment(.center)

            TextField("Six-digit code", text: $code)
                .textContentType(.oneTimeCode)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .font(.title2.monospacedDigit())
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
            .font(.callout)
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
