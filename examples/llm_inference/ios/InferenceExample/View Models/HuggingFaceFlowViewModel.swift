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

enum Action: CaseIterable, Equatable {
  case login
  case acknowledgeLicense(url: URL, key: String)
  case download
  
  static func == (lhs: Action, rhs: Action) -> Bool {
    switch (lhs, rhs) {
      case (.login, .login), (.download, .download):
        return true
      case (.acknowledgeLicense(let lhsUrl, let lhsKey), .acknowledgeLicense(let rhsUrl, let rhsKey)):
        let equalt = lhsUrl == rhsUrl && lhsKey == rhsKey
        return equalt
      default:
        print("detect false")
        return false
    }
  }
    
  static var allCases: [Action] {
    /// Just a dummy url here.
    return [.login, .acknowledgeLicense(url: URL(string: "https://ai.google.dev/edge/mediapipe/solutions/guide")!, key: "dummy"), .download]
  }
  
}

@MainActor
class HuggingFaceFlowViewModel: ObservableObject {
  @Published var action: Action
  let modelCategory: Model
  
  init(modelCategory: Model) {
    self.modelCategory = modelCategory
    self.action = HuggingFaceFlowViewModel.newAction(modelCategory: modelCategory)
  }
  
  func handleLoginSuccess() {
    print("Login success")
    guard let licenseUrl = modelCategory.licenseUrl else {
      action = .download
      return
    }
    action = .acknowledgeLicense(url: licenseUrl, key: modelCategory.licenseAcnowledgedKey)
  }
  
  func handleLicenseViewed() {
    action = .download
  }
  
  func updateState() {
    action = HuggingFaceFlowViewModel.newAction(modelCategory: self.modelCategory)
    print(action)
  }
  
  func shouldDismiss() -> Bool {
    do {
      _ = try modelCategory.modelPath
      return true
    }
    catch {
      updateState()
    }
    return false
  }
  
  static func newAction(modelCategory: Model) -> Action {
    if KeyChainHelper.load(key: OAuthService.accessTokenKey) == nil {
      return .login
    }
    else if KeyChainHelper.load(key: modelCategory.licenseAcnowledgedKey) == nil, let licenseUrl = modelCategory.licenseUrl {
      print("Go to ack")
      return .acknowledgeLicense(url: licenseUrl, key: modelCategory.licenseAcnowledgedKey)
    }
    else {
      return .download
    }
  }
  
}
  
