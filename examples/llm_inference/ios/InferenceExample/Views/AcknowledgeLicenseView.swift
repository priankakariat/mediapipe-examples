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
import SafariServices

struct SafariView: UIViewControllerRepresentable {
  let url: URL
  
  func makeUIViewController(context: Context) -> SFSafariViewController {
    SFSafariViewController(url: url)
  }
  
  func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct AcknowledgeLicenseView: View {
//  @EnvironmentObject var huggingFaceFlowViewModel: HuggingFaceFlowViewModel // Access the ParentViewModel
  @Environment(\.webAuthenticationSession) private var webAuthenticationSession

  @State private var showingWebView = false
  @ObservedObject var viewModel: AcknowledgeLicenseViewModel
  
  @Environment(\.openURL) private var openURL
  @Environment(\.scenePhase) private var scenePhase

  let onLicenseViewed: () -> Void
  
  var body: some View {
    VStack {
      let _ = print("license view")
      RoundedRectButton(title: "Acknowledge License") {
//        Task {
//          do {
//            let urlWithToken = try await webAuthenticationSession.authenticate(
//              using: viewModel.url,
//              callback: ASWebAuthenticationSession.Callback.customScheme("com.google.mediapipe.examples.inf"),
//              preferredBrowserSession: nil,
//              additionalHeaderFields: [:]
//            )
//            print(urlWithToken)
////            _ = await viewModel.handleCallback(urlWithToken)
//          } catch ASWebAuthenticationSessionError.canceledLogin {
//            // User dismissed the session without authenticating
//            print("Authentication canceled by user")
//            // isAuthenticating is already set to false by defer
//          }
//          catch {
//            
//          }
//        }
        showingWebView = true
////        openURL(viewModel.url)
////        viewModel.handleLicenseViewed()
      }
      
      RoundedRectButton(title: "Continue", action: {
        onLicenseViewed()
      }, disabled: viewModel.isLicenseViewed)
    }
    .sheet(isPresented: $showingWebView, onDismiss: onDismiss, content: {
      SafariView(url: viewModel.url)
    })
  }
           
//      WebView(url: viewModel.url)
//        .edgesIgnoringSafeArea(.all)
//    })
//    .sheet(isPresented: $showingWebView, ond) {
//      WebView(url: webURL)
//        .edgesIgnoringSafeArea(.all)
//    }
  
  func onDismiss() {
    showingWebView = false
  }
}
