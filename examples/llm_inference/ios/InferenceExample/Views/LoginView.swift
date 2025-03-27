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

struct LoginView: View {
  let logoName: String = "HfLogo"
  let text = "Sign In with Hugging Face"
  
  var body: some View {
    Button(action: {
      // Your action logic goes here
      // Add your specific action code
    }){
      HStack {
        Image(logoName)
          .resizable()
          .scaledToFit()
          .frame(width: 30, height: 30) // Adjust icon size as needed
        Text(text)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 12)
      .background(Color.black)
      .foregroundColor(.white)
      .cornerRadius(30) // Adjust corner radius for roundness
      .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
    }
  }
}
  
  //  private struct Constants {
  //    static let scrollDelayInSeconds = 0.05
  //    static let alertBackgroundColor = Color.black.opacity(0.3)
  //    static let newChatSystemSymbolName = "square.and.pencil"
  //    static let navigationTitle = "Chat with your LLM here"
  //    static let modelInitializationAlertText = "Model initialization in progress."
  //  }

