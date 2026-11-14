// Signing in and talking to app.readercount.com. The app signs in with the same OAuth as the Claude connector
// (PKCE, no password in the app), as the client "readercount-app" that comes back on readercount://signin.
// Tokens live in the Keychain, shared with the widget through the App Group, so the widget can refresh by itself.
// Access tokens last an hour; each refresh token works once and lasts 90 days, so whoever refreshes saves both.

import Foundation
import CryptoKit

enum Shared {
    static let group = "group.com.readercount.app"
    static let app = URL(string: "https://app.readercount.com/")!
    static let auth = URL(string: "https://mcp.readercount.com/")!
    static let website = URL(string: "https://readercount.com/")!
    static let clientID = "readercount-app"
    static let redirect = "readercount://signin"
    static var defaults: UserDefaults { UserDefaults(suiteName: group) ?? .standard }
}

struct Tokens: Codable, Equatable {
    var access: String
    var refresh: String
    var expires: Date

    static func load() -> Tokens? {
        guard let s = Keychain.read("tokens"), let d = s.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Tokens.self, from: d)
    }

    func save() {
        if let d = try? JSONEncoder().encode(self), let s = String(data: d, encoding: .utf8) { Keychain.save("tokens", s) }
    }

    static func clear() { Keychain.delete("tokens") }
}

struct APIError: LocalizedError {
    let message: String
    let status: Int
    var errorDescription: String? { message }
    var signedOut: Bool { status == 401 }
}

/// The PKCE pair for one sign in.
struct PKCE {
    let verifier: String
    let challenge: String
    let state: String

    init() {
        func random(_ n: Int) -> String {
            var bytes = [UInt8](repeating: 0, count: n)
            _ = SecRandomCopyBytes(kSecRandomDefault, n, &bytes)
            return Data(bytes).base64URL
        }
        verifier = random(32)
        challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URL
        state = random(12)
    }

    var authorizeURL: URL {
        var c = URLComponents(url: Shared.auth.appending(path: "authorize"), resolvingAgainstBaseURL: false)!
        c.queryItems = [
            .init(name: "response_type", value: "code"),
            .init(name: "client_id", value: Shared.clientID),
            .init(name: "redirect_uri", value: Shared.redirect),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "scope", value: "stats:read"),
            .init(name: "state", value: state),
        ]
        return c.url!
    }
}

extension Data {
    var base64URL: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}

/// Everything the app and widget ask app.readercount.com, refreshing the sign in when it runs out.
actor API {
    static let shared = API()

    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 30
        c.httpCookieStorage = nil
        c.httpShouldSetCookies = false
        c.urlCache = nil
        return URLSession(configuration: c)
    }()

    /// Swaps the code from the sign in sheet for tokens.
    func finishSignIn(callback: URL, pkce: PKCE) async throws {
        let q = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func item(_ n: String) -> String? { q.first(where: { $0.name == n })?.value }
        if item("error") != nil { throw APIError(message: "Sign in was cancelled.", status: 0) }
        guard item("state") == pkce.state, let code = item("code") else { throw APIError(message: "Sign in didn't finish. Please try again.", status: 0) }
        try await tokenRequest(["grant_type": "authorization_code", "code": code, "client_id": Shared.clientID, "redirect_uri": Shared.redirect, "code_verifier": pkce.verifier])
    }

    /// Signing in inside the app, like Site Patrol: step one emails a six-digit code. Answers the email it went to.
    func requestCode(email: String) async throws -> String {
        let j = try await signInPost("app/v1/signin/code", ["email": email])
        return (j["email"] as? String) ?? email
    }

    /// Step two: the code from the email, swapped for the app's tokens.
    func signIn(email: String, code: String) async throws {
        let j = try await signInPost("app/v1/signin/token", ["email": email, "code": code])
        guard let access = j["access_token"] as? String, let refresh = j["refresh_token"] as? String else {
            throw APIError(message: "Sign in didn't finish. Please try again.", status: 0)
        }
        let seconds = (j["expires_in"] as? Double) ?? 3600
        Tokens(access: access, refresh: refresh, expires: Date().addingTimeInterval(seconds - 60)).save()
    }

    private func signInPost(_ path: String, _ body: [String: String]) async throws -> [String: Any] {
        var r = URLRequest(url: Shared.app.appending(path: path))
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "content-type")
        r.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: r)
        let j = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError(message: (j["error"] as? String) ?? "ReaderCount couldn't be reached. Please try again.", status: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return j
    }

    private func tokenRequest(_ form: [String: String]) async throws {
        var r = URLRequest(url: Shared.auth.appending(path: "token"))
        r.httpMethod = "POST"
        r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "content-type")
        var c = URLComponents()
        c.queryItems = form.map { URLQueryItem(name: $0.key, value: $0.value) }
        r.httpBody = c.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").data(using: .utf8)
        let (data, response) = try await session.data(for: r)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = j["access_token"] as? String, let refresh = j["refresh_token"] as? String else {
            throw APIError(message: "Please sign in to ReaderCount again.", status: 401)
        }
        let seconds = (j["expires_in"] as? Double) ?? 3600
        Tokens(access: access, refresh: refresh, expires: Date().addingTimeInterval(seconds - 60)).save()
    }

    /// A working access token, refreshed when it has run out.
    private func accessToken() async throws -> String {
        guard let t = Tokens.load() else { throw APIError(message: "Please sign in.", status: 401) }
        if t.expires > Date() { return t.access }
        do {
            try await tokenRequest(["grant_type": "refresh_token", "refresh_token": t.refresh, "client_id": Shared.clientID])
        } catch {
            // The widget or the app may have just refreshed with the same token: use what it saved.
            if let now = Tokens.load(), now != t, now.expires > Date() { return now.access }
            throw error
        }
        return Tokens.load()?.access ?? ""
    }

    func data(_ path: String, query: [String: String] = [:], method: String = "GET", body: [String: Any]? = nil) async throws -> Data {
        var c = URLComponents(url: Shared.app.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { c.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }
        var r = URLRequest(url: c.url!)
        r.httpMethod = method
        r.setValue("application/json", forHTTPHeaderField: "accept")
        r.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "authorization")
        if let body {
            r.setValue("application/json", forHTTPHeaderField: "content-type")
            r.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: r)
        } catch {
            throw APIError(message: "We couldn't reach ReaderCount. Check you're online and try again.", status: 0)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let said = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            throw APIError(message: said?["error"] as? String ?? "Something went wrong (\(status)). Please try again.", status: status)
        }
        return data
    }

    func get<T: Decodable>(_ type: T.Type, _ path: String, _ query: [String: String] = [:]) async throws -> T {
        try JSONDecoder().decode(T.self, from: try await data(path, query: query))
    }

    func send(_ path: String, method: String = "POST", _ body: [String: Any]) async throws {
        _ = try await data(path, method: method, body: body)
    }
}
