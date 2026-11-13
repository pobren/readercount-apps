// Signing in: ReaderCount's own sign in page opens in Apple's secure sheet (an emailed code or a passkey), so the
// app never sees a password. Accounts are made on the website.

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(Model.self) private var model
    @Environment(\.webAuthenticationSession) private var session

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

                Button {
                    Task { await model.signIn(using: session) }
                } label: {
                    if model.busy {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Label("Sign in", systemImage: "person.crop.circle.badge.checkmark").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(model.busy)

                Text("We'll email you a six-digit code, or use your passkey. No password needed.")
                    .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)

                if let error = model.error {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.callout.bold())
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
    }
}
