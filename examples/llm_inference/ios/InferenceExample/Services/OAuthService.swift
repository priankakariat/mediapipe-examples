//
//  OAuthService.swift
//  InferenceExample
//
//  Created by Prianka Kariat on 20/03/25.
//

import Foundation
import AuthenticationServices
import CryptoKit
import Security
import Foundation


struct AuthConfig {
  static let clientId = "19943f22-042c-43f8-96bd-6522ffa8bdfe"
  static var redirectUri = "com.google.mediapipe.examples.llminference://oauth2callback"
  static let authEndpoint = "https://huggingface.co/oauth/authorize"
  static var tokenEndpoint = "https://huggingface.co/oauth/token"
  
  static func generateState() -> String {
    var bytes = [UInt8](repeating: 0, count: 32) // 16 bytes for a decent random string
    _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    return Data(bytes).base64URLEncodedString()
  }
  
  static func authUrl(codeChallenge: String, scope: String) throws -> URL {
    var components = URLComponents(string: AuthConfig.authEndpoint)
    
    let queryItems = [
      URLQueryItem(name: "client_id", value: AuthConfig.clientId),
      URLQueryItem(name: "redirect_uri", value: AuthConfig.redirectUri),
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "scope", value: scope),
      URLQueryItem(name: "code_challenge", value: codeChallenge),
      URLQueryItem(name: "code_challenge_method", value: "S256"),
      URLQueryItem(name: "state", value: AuthConfig.generateState())
    ]
    
    components?.queryItems = queryItems
    
    guard let authUrl = components?.url else {
      throw OAuthService.OAuthError.internalError
    }
    return authUrl
  }
  
  
}

class OAuthService: NSObject {
  
  static let accessTokenKey = "access-token"
  private var authSession: ASWebAuthenticationSession?
  private var codeVerifier: String = ""
  
  
  enum OAuthError: LocalizedError, Identifiable {
    /// Wraps an error thrown by MediaPipe.
  case invalidUrl(url: String)
  case invalidCallback
  case invalidResponse
  case invalidToken
  case internalError
  case badServerResponse
    
    var id: String { // Unique identifier based on enum case
      return self.name
    }

    
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
    
    private var name: String {
      switch self {
        case .invalidUrl(let url):
          return "invalidUrl"
        case .invalidCallback:
          return "invalidCallback"
        case .invalidResponse:
          return "invalidResponse"
        case .invalidToken:
          return "invalidToken"
        case .internalError:
          return "internalError"
        case .badServerResponse:
          return "badServerResponse"
      }
    }
  }
  
  func exchangeCodeForToken(code: String) async throws {
    
    guard let url = URL(string: AuthConfig.tokenEndpoint) else {
      throw OAuthError.invalidUrl(url: AuthConfig.tokenEndpoint)
    }
    
    guard let codeVerifier = KeyChainHelper.load(key: "code-verifier") else {
      throw OAuthError.internalError
    }
    
    let postString = "grant_type=authorization_code&code=\(code)&redirect_uri=\(AuthConfig.redirectUri)&client_id=\(AuthConfig.clientId)&code_verifier=\(codeVerifier)"
    
    
    guard let postData = postString.data(using: .utf8) else {
      throw OAuthError.invalidResponse
    }
    
    let response = try await NetworkService.shared.postRequest(url: url, body: postData, headers: ["Content-Type": "application/x-www-form-urlencoded"])
    
    guard let accessToken = response["access_token"] as? String else {
      throw OAuthError.badServerResponse
    }
    
    guard KeyChainHelper.save(key: OAuthService.accessTokenKey, value: accessToken) else {
      throw OAuthError.internalError
    }
    print("saved")
    print(accessToken)
  }
  
  static func clearAccessToken() {
    _ = KeyChainHelper.delete(key: OAuthService.accessTokenKey)
  }

  private func generatePKCE() throws -> (verifier: String, challenge: String) {
    var bytes = [UInt8](repeating: 0, count: 32)
    let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    guard result == errSecSuccess else {
      throw OAuthError.internalError
    }
    
    let verifier = Data(bytes).base64URLEncodedString()
    
    guard let verifierData = verifier.data(using: .utf8) else {
      throw OAuthError.internalError
    }
    
    let challengeData = SHA256.hash(data: verifierData)
    let challenge = Data(challengeData).base64URLEncodedString()
    
    
    return (verifier, challenge)
  }
  
  func getAuthorizationURL() throws -> URL? {
    let (codeVerifier, codeChallenge) = try generatePKCE()
    guard KeyChainHelper.save(key: "code-verifier", value: codeVerifier) else {
      throw OAuthError.internalError
    }
    
    return try AuthConfig.authUrl(codeChallenge: codeChallenge, scope: "read-repos")
  }
}

import Security
import Foundation

struct KeyChainHelper {
  
  static func save(key: String, value: String) -> Bool {
    guard let data = value.data(using: .utf8) else {
      return false
    }
    
    /// Don't care about the status here. It maybe not found.
    _ = KeyChainHelper.delete(key: key)
    
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
      kSecValueData as String: data
    ]
    
    
    guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else {
      return false
    }
    
    return true
  }
  
  static func load(key: String) -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
      kSecReturnData as String: kCFBooleanTrue!,
      kSecMatchLimit as String: kSecMatchLimitOne
    ]
    
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    
    guard status == errSecSuccess, let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
      return nil
    }
    
    return value
  }
  
  static func delete(key: String) -> OSStatus {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key
    ]
    
    return SecItemDelete(query as CFDictionary)
  }
  
  static func checkAndClearKeys(_ keys: [String]) {
    //Example of conditional deletion. You would want to adjust this logic to your specific needs.
    guard !UserDefaults.standard.bool(forKey: "shouldClearKeychain") else {
      return
    }
    
    print("clear")
    for key in keys {
      _ = KeyChainHelper.delete(key: key)
    }
    
    UserDefaults.standard.set(true, forKey: "shouldClearKeychain")
  }
}
extension Data {
  func base64URLEncodedString() -> String {
    return self.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}

extension String {
  func validatedURL() throws -> URL {
    guard let url = URL(string: self) else {
      throw OAuthService.OAuthError.invalidUrl(url: self) // Convert here
    }
    
    return url
  }
}
