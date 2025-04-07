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


struct DownloadView: View {
  
  @EnvironmentObject var huggingFaceFlowViewModel: HuggingFaceFlowViewModel // Access the ParentViewModel
  
  @ObservedObject var viewModel: DownloadViewModel
  let onDownloadCompletion: () -> Void

  var body: some View {
    
    ZStack {
      RoundedRectButton(title: "Download") {
        viewModel.download()
      }
      if viewModel.state == .progress {
        VStack {
          ProgressView(value: viewModel.progress, total: 100.0) {
            Text("Processing..")
          } currentValueLabel: {
            Text("Current progress: \(Int(viewModel.progress))%")
          }
          .padding()
          RoundedRectButton(title: "Cancel") {
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill the frame
        .alert(
          error: viewModel.state.error,
          action: { [weak viewModel] in
            if viewModel?.handleDownloadErrorDismissed() == true {
              onDownloadCompletion()
            }
          })
//        .alert(item: $viewModel.state) { error in
//          Alert(
//            title: Text(error.errorDescription!),
//            message: Text(error.failureReason),
//            dismissButton: .default(Text("OK")) {
//              // Optional: Perform actions on dismiss
//              viewModel.error = nil //Clear the error after showing the alert
//            }
//          )
      }
    }
    .onChange(of: viewModel.state) {_, newState in
      if newState == .completed {
        onDownloadCompletion()
      }
    }
  }
}

  
