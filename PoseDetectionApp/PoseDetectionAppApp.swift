//
//  PoseDetectionAppApp.swift
//  PoseDetectionApp
//
//  Created by Syeda Arisha Shamim on 21/09/2024.
//

import SwiftUI

@main
struct PoseDetectionAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = PoseDetectionViewModel()

     var body: some View {
         VStack {
             CameraView(viewModel: viewModel)
                 .edgesIgnoringSafeArea(.all)
             Text(viewModel.detectedPose)
                 .font(.largeTitle)
                 .padding()
                 .foregroundColor(.white)
                 .background(viewModel.detectedPose == "No Pose Detected" ? Color.black : Color.green.opacity(1))
                 .cornerRadius(10)
                 .padding()
         }
     }
 }


