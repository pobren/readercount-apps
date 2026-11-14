// Signing in with a passkey: the same passkeys as app.readercount.com, shared with the app through Apple's
// webcredentials (apple-app-site-association on app.readercount.com and the associated domains entitlement).

import AuthenticationServices
import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

@MainActor
final class PasskeySignIn: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var waiting: CheckedContinuation<ASAuthorizationPlatformPublicKeyCredentialAssertion, Error>?

    /// Asks the device for a passkey for app.readercount.com and returns the signed challenge in the shape the server reads.
    func sign(challenge: String) async throws -> [String: Any] {
        guard let data = Data(base64URL: challenge) else { throw APIError(message: "Passkeys aren't working just now.", status: 0) }
        let request = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: "app.readercount.com").createCredentialAssertionRequest(challenge: data)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        let a = try await withCheckedThrowingContinuation { (c: CheckedContinuation<ASAuthorizationPlatformPublicKeyCredentialAssertion, Error>) in
            waiting = c
            controller.performRequests()
        }
        let id = a.credentialID.base64URL
        var response: [String: Any] = [
            "clientDataJSON": a.rawClientDataJSON.base64URL,
            "authenticatorData": a.rawAuthenticatorData.base64URL,
            "signature": a.signature.base64URL,
        ]
        if let user = a.userID, !user.isEmpty { response["userHandle"] = user.base64URL }
        return ["id": id, "rawId": id, "type": "public-key", "response": response, "clientExtensionResults": [String: Any](), "authenticatorAttachment": "platform"]
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion
        MainActor.assumeIsolated {
            if let credential { waiting?.resume(returning: credential) } else { waiting?.resume(throwing: APIError(message: "That wasn't a passkey. Please try again.", status: 0)) }
            waiting = nil
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let cancelled = (error as? ASAuthorizationError)?.code == .canceled
        MainActor.assumeIsolated {
            waiting?.resume(throwing: cancelled ? CancellationError() : APIError(message: "No passkey for ReaderCount was found on this device. Add one on the website under Secure your account, or sign in with an emailed code.", status: 0))
            waiting = nil
        }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            #if os(iOS)
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            return scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first ?? ASPresentationAnchor()
            #else
            return NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? ASPresentationAnchor()
            #endif
        }
    }
}

extension Data {
    init?(base64URL s: String) {
        var b = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b.count % 4 != 0 { b += "=" }
        self.init(base64Encoded: b)
    }

}
