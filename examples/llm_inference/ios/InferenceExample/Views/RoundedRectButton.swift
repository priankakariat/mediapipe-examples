// Copyright 2025 The Mediapipe Authors.
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

struct RoundedRectButtonStyle: ButtonStyle {
  var backgroundColor: Color = .purple
  var foregroundColor: Color = .white
  var cornerRadius: CGFloat = 10
  var shadowRadius: CGFloat = 3
  private let horizontalPadding: CGFloat = 20
  private let verticalPadding: CGFloat = 10
  
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(.horizontal, horizontalPadding)
      .padding(.vertical, verticalPadding)
      .background(backgroundColor)
      .foregroundColor(foregroundColor)
      .cornerRadius(cornerRadius)
      .shadow(color: Color.black.opacity(0.2), radius: shadowRadius, x: 0, y: 2)
      .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
      .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
  }
}

struct RoundedRectButton: View {
  var title: String
  var action: () -> Void
  var cornerRadius: CGFloat = 30
  var shadowRadius: CGFloat = 3
  var disabled: Bool = false
  
  var body: some View {
    Button(action: action) {
      Text(title)
    }
    .buttonStyle(RoundedRectButtonStyle(cornerRadius: cornerRadius, shadowRadius: shadowRadius))
    .disabled(disabled)
  }
}

