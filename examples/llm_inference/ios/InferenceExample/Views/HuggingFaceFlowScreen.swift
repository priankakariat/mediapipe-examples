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

struct HuggingFaceFlowScreen: View {
  @ObservedObject var viewModel: HuggingFaceFlowViewModel
  @Environment(\.dismiss) var dismiss

  var body: some View {
    VStack {
      switch viewModel.action {
        case .login:
          let _ = print("Rendering login view")
          LoginView {
            print("Login success callback")
            viewModel.handleLoginSuccess()
//            print("Action after login: \(viewModel.action)")
          }
        case .acknowledgeLicense(let url, let key):
          let _ = print("Rendering license view")
          AcknowledgeLicenseView(viewModel: AcknowledgeLicenseViewModel(url: url, licenseAcknowledgedKey: key)) {
            print("License acknowledged callback")
            viewModel.updateState()
          }
        case .download:
          let _ = print("Rendering download view")
          DownloadView(viewModel: DownloadViewModel(url: viewModel.modelCategory.downloadUrl, licenseAcknowledgedKey: viewModel.modelCategory.licenseAcnowledgedKey)) {
            if viewModel.shouldDismiss() {
              dismiss()
            }
          }
      }
    }
    }
    
//    switch viewModel.action {
//      case .login:
//        let _ = print("logged in")
//        LoginView {
//          print("Done alright")
//          viewModel.handleLoginSuccess()
//          print(viewModel.action)
//        }
//      case .acknowledgeLicense(let url, let key):
//        let _ = print("Presenting license view")
//        AcknowledgeLicenseView(viewModel: AcknowledgeLicenseViewModel(url: url, licenseAcknowledgedKey: key)) {
//          let _ = print("license viewed flow")
//          viewModel.updateState()
//        }
//      case .download:
//        let _ = print("Present Download view")
//        DownloadView(viewModel: DownloadViewModel(url: viewModel.modelCategory.downloadUrl, licenseAcknowledgedKey: viewModel.modelCategory.licenseAcnowledgedKey)) {
//          if viewModel.shouldDismiss() {
//            dismiss()
//          }
//        }
//    }
  }
  
//  @ViewBuilder
//  private var content: some View {
//    switch action {
//      case .login:
//        let _ = print("Rendering login view")
//        LoginView {
//          print("Login success callback")
//          viewModel.handleLoginSuccess()
//          print("Action after login: \(viewModel.action)")
//        }
//      case .acknowledgeLicense(let url, let key):
//        let _ = print("Rendering license view")
//        AcknowledgeLicenseView(viewModel: AcknowledgeLicenseViewModel(url: url, licenseAcknowledgedKey: key)) {
//          print("License acknowledged callback")
//          viewModel.updateState()
//        }
//      case .download:
//        let _ = print("Rendering download view")
//        DownloadView(viewModel: DownloadViewModel(url: viewModel.modelCategory.downloadUrl, licenseAcknowledgedKey: viewModel.modelCategory.licenseAcnowledgedKey)) {
//          if viewModel.shouldDismiss() {
//            dismiss()
//          }
//        }
//    }
//  }
//}
