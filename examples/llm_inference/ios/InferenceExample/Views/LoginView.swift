// Copyright 2024 The Mediapipe Authors.
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

import SwiftUI
import AuthenticationServices
import CryptoKit

struct LoginView: View {
//  @EnvironmentObject var huggingFaceFlowViewModel: HuggingFaceFlowViewModel // Access the ParentViewModel

  let logoName: String = "HfLogo"
  let text = "Sign In with Hugging Face"
  let onLoginSuccess: () -> Void
  @Environment(\.webAuthenticationSession) private var webAuthenticationSession
  @StateObject private var viewModel = LoginViewModel()
  @Environment(\.dismiss) var dismiss

  
  let authService = OAuthService()
  
  var body: some View {
    ZStack {
      VStack {
        Button(action: {
          Task {
            await performAuthentication()
            DispatchQueue.main.async {
              onLoginSuccess()
            }

//            guard let url = viewModel.getAuthorizationUrl() else {
//              return
//            }
//            let urlWithToken = try await webAuthenticationSession.authenticate(using: url, callback: ASWebAuthenticationSession.Callback.customScheme("com.google.mediapipe.examples.llminference"), preferredBrowserSession: .ephemeral, additionalHeaderFields:[:])
//            guard await viewModel.handleCallback(urlWithToken) else {
//              return
//            }
//            onLoginSuccess()
          }
        }){
          HStack {
            Image(logoName)
              .resizable()
              .scaledToFit()
              .frame(width: 30, height: 30) // Adjust icon size as needed
            Text(text)
          }
          .buttonStyle(RoundedRectButtonStyle(backgroundColor: Color.black))
          .disabled(viewModel.isAuthenticating)
        }
      }
      if viewModel.isAuthenticating {
        ProgressView("Authenticating...")
      }
    }
    .alert(item: $viewModel.error) { error in
      Alert(
        title: Text(error.errorDescription!),
        message: Text(error.failureReason),
        dismissButton: .default(Text("OK")) {
          // Optional: Perform actions on dismiss
          viewModel.error = nil //Clear the error after showing the alert
        }
      )
    }
  }
  
  private func performAuthentication() async {
    viewModel.isAuthenticating = true // Set to true when starting
    defer { viewModel.isAuthenticating = false } // Ensure it’s reset even on unexpected exits
    
    guard let url = viewModel.getAuthorizationUrl() else {
      return
    }
    
    do {
      let urlWithToken = try await webAuthenticationSession.authenticate(
        using: url,
        callback: ASWebAuthenticationSession.Callback.customScheme("com.google.mediapipe.examples.llminference"),
        preferredBrowserSession: nil,
        additionalHeaderFields: [:]
      )
     _ = await viewModel.handleCallback(urlWithToken)
    } catch ASWebAuthenticationSessionError.canceledLogin {
      // User dismissed the session without authenticating
      print("Authentication canceled by user")
      // isAuthenticating is already set to false by defer
    }
    catch {
      
    }
  }
}

extension View {
  /// Displays error alert based on the value of the binding error. This function is invoked when the value of the binding error changes.
  /// - Parameters:
  ///   - error: Binding error based on which the alert is displayed.
  /// - Returns: The error alert.
  func alert(
    error: Binding<OAuthService.OAuthError?>, buttonTitle: String = "OK"
  ) -> some View {
    
    let authError = error.wrappedValue
    
    return alert(isPresented: .constant(authError != nil), error: authError) { _ in
    } message: { error in
      Text(error.failureReason)
    }
  }
}
