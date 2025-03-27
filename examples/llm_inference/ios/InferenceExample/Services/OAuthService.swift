//
//  OAuthService.swift
//  InferenceExample
//
//  Created by Prianka Kariat on 20/03/25.
//

import Foundation
import AuthenticationServices
import CryptoKit


struct AuthConfig {
  static let clientId = "19943f22-042c-43f8-96bd-6522ffa8bdfe"
  static let redirectUri = "com.google.mediapipe.examples.llminference://oauth2callback"
  static let authEndpoint = "https://huggingface.co/oauth/authorize"
  static let tokenEndpoint = "https://huggingface.co/oauth/token"
  
  static func authUrl(codeChallenge: String, scope: String) throws -> URL {
    var components = URLComponents(string: AuthConfig.authEndpoint)
    
    var queryItems = [
      URLQueryItem(name: "client_id", value: AuthConfig.clientId),
      URLQueryItem(name: "redirect_uri", value: AuthConfig.redirectUri),
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "scope", value: scope),
      URLQueryItem(name: "code_challenge", value: codeChallenge),
      URLQueryItem(name: "code_challenge_method", value: "S256")
    ]
    
    components?.queryItems = queryItems
    
    guard let authUrl = components?.url else {
      throw OAuthService.OAuthError.internalError
    }
    
    return authUrl
  }
}

class OAuthService: NSObject {
  private var authSession: ASWebAuthenticationSession?
  private var codeVerifier: String = ""
  
  

  
  private func generatePKCE() {
    
}
  
  enum OAuthError: LocalizedError {
    /// Wraps an error thrown by MediaPipe.
  case invalidUrl(url: String)
  case invalidCallback
  case invalidResponse
  case invalidToken
  case internalError


    
    public var errorDescription: String? {
      switch self {
        case .invalidUrl:
          return "Invalid url"
        default:
          return "Error"
      }
    }
    
    public var failureReason: String {
      switch self {
        case .invalidUrl(let url):
          return "Invalid url \(url)."
        default:
          return "Invalid credentials"
      }
    }
  }

  
  func authenticate() async throws -> String {
    guard var components = URLComponents(string: AuthConfig.authEndpoint) else {
      throw OAuthError.invalidUrl(url: AuthConfig.authEndpoint)
    }
    
    let (verifier, challenge) = generatePKCE()
    self.codeVerifier = verifier
    components.queryItems = [
      URLQueryItem(name: "client_id", value: AuthConfig.clientId),
      URLQueryItem(name: "redirect_uri", value: AuthConfig.redirectUri),
      URLQueryItem(name: "scope", value: "read-repos"),
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "code_challenge", value: challenge),
      URLQueryItem(name: "code_challenge_method", value: "S256")
    ]
    
    let authURL = components.url!
    let callbackScheme = "llminference://callback"
    
    // Use continuation to await the ASWebAuthenticationSession callback
    let code = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
      authSession = ASWebAuthenticationSession(url: authURL, callbackURLScheme: callbackScheme) { callbackURL, error in
        if let error = error {
          continuation.resume(throwing: error)
          return
        }
        guard let callbackURL = callbackURL,
              let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
          .queryItems?.first(where: { $0.name == "code" })?.value else {
          continuation.resume(throwing: OAuthError.invalidCallback)
          return
        }
        continuation.resume(returning: code)
      }
      authSession?.start()
    }
    
    // Exchange code for token
    return try await exchangeCodeForToken(code: code, verifier: verifier)
  }
  
  func authenticate() throws {
    
    guard var components = URLComponents(string: AuthConfig.authEndpoint) else {
      throw OAuthError.invalidUrl(url: AuthConfig.authEndpoint)
    }
    
    let (verifier, challenge) = generatePKCE()
    self.codeVerifier = verifier
    
    let authURL = try AuthConfig.authUrl(codeChallenge: challenge, scope: "read-repos")
    
    let callbackScheme = "llminference://callback"
        
    let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "myapp") { callbackUrl, error in
      guard let callbackUrl = callbackUrl, error == nil else { return }
      handleOAuthCallback(url: callbackUrl)
    }
    session.presentationContextProvider = self
    session.start()
  }

  
  func handleOAuthCallback(url: URL) {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let queryItems = components.queryItems else { return }
    
    if let codeItem = queryItems.first(where: { $0.name == "code" }),
       let code = codeItem.value {
      exchangeCodeForToken(code: code)
    }
  }
  
  func exchangeCodeForToken(code: String) {
    let tokenUrlString = "https://huggingface.co/oauth/token"
    guard let tokenUrl = URL(string: tokenUrlString), let codeVerifier = codeVerifier else { return }
    
    var request = URLRequest(url: tokenUrl)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let body: [String: String] = [
      "grant_type": "authorization_code",
      "code": code,
      "client_id": clientId,
      "redirect_uri": redirectUri,
      "code_verifier": codeVerifier
    ]
    
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    
    URLSession.shared.dataTask(with: request) { data, response, error in
      guard let data = data, error == nil else { return }
      if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
         let accessToken = json["access_token"] as? String {
        DispatchQueue.main.async {
          self.accessToken = accessToken
        }
      }
    }.resume()
  }
  
  private func exchangeCodeForToken(code: String, verifier: String) async throws -> String {
    let tokenURL = URL(string: "https://huggingface.co/oauth/token")!
    var request = URLRequest(url: tokenURL)
    request.httpMethod = "POST"
    
    let body = "client_id=YOUR_CLIENT_ID&client_secret=YOUR_CLIENT_SECRET&code=\(code)&redirect_uri=YOUR_REDIRECT_URI&code_verifier=\(verifier)"
    request.httpBody = body.data(using: .utf8)
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
      throw OAuthError.invalidResponse
    }
    
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let token = json["access_token"] as? String else {
      throw OAuthError.invalidToken
    }
    
    return token
  }
  
  private func generatePKCE() -> (verifier: String, challenge: String) {
    var bytes = [UInt8](repeating: 0, count: 32)
    let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    guard result == errSecSuccess else {
      fatalError("Failed to generate random bytes")
    }
    
    let verifier = Data(bytes).base64URLEncodedString()
    
    guard let verifierData = verifier.data(using: .utf8) else {
      fatalError("Failed to convert verifier to data")
    }
    
    let challengeData = SHA256.hash(data: verifierData)
    let challenge = Data(challengeData).base64URLEncodedString()
    
    
    return (verifier, challenge)
  }
//  
//  private func generateCodeChallenge(codeVerifier: String) -> String {
//  
//    let challengeData = SHA256.hash(data: codeVerifier)
//    let challenge = challengeData.base64URLEncodedString()
//    
//    return challenge
//  }
  
//  private func generatePKCE() -> (verifier: String, challenge: String) {
//    var bytes = [UInt8](repeating: 0, count: 32)
//    let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
//    guard result == errSecSuccess else { fatalError("Failed to generate random bytes") }
//    let verifier = Data(bytes).base64EncodedString()
//    
//    let challenge = SHA256.hash(data: verifier.data(using: .utf8)!)
//      .map { String(format: "%02x", $0) }
//      .joined()
//      .data(using: .utf8)!
//      .base64EncodedString()
//    
//    return (verifier, challenge)
//  }
  
}

extension Data {
  func base64URLEncodedString() -> String {
    return self.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}
