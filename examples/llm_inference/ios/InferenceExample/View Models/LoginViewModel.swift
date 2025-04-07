// Copyright 2024 The MediaPipe Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import SwiftUI
import CryptoKit

@MainActor
class LoginViewModel: ObservableObject {
  private let oauthService = OAuthService()
  
  @Published var isAuthenticating = false
  @Published var error: OAuthService.OAuthError? = nil
  
  private var codeVerifier: String = ""
  
  func getAuthorizationUrl() -> URL? {
    isAuthenticating = true
    do {
      let url = try oauthService.getAuthorizationURL()
      return url
    }
    catch let error as OAuthService.OAuthError {
      self.error = error
    }
    catch {
      
    }
    return nil
  }
  
  func handleCallback(_ callbackURL: URL?) async -> Bool {
    defer {
      isAuthenticating = false
    }
    guard let callbackURL = callbackURL,
       let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
      .queryItems?
      .first(where: { $0.name == "code" })?.value else {
      self.error = OAuthService.OAuthError.internalError
      return false
    }
      do {
          try await oauthService.exchangeCodeForToken(code: code)
          return true
        } catch let error as OAuthService.OAuthError {
          self.error = error
        }
      catch {
      }
    
    return false
    
  }
}
