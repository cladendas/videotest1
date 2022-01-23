//
//  CameraView.swift
//  videotest1
//
//  Created by cladendas on 23.01.2022.
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    
    @StateObject var camera = CameraModel()
    
    var body: some View {
        ZStack {
            
            //Going to be camera preview...
            CameraPreview(camera: camera)
                .ignoresSafeArea(.all, edges: .all)
            
            VStack {
                Spacer()
                HStack {
                    
                    if camera.isTaken {
                        Button {
                            camera.stopRecording()
                            camera.isTaken.toggle()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 65, height: 65)

                                Circle()
                                    .stroke(Color.red)
                                    .frame(width: 75, height: 75)
                            }
                        }
                    } else {
                        Button {
                            camera.startRecording()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 65, height: 65)
                                
                                Circle()
                                    .stroke(Color.white)
                                    .frame(width: 75, height: 75)
                            }
                        }
                    }
                }.frame(height: 75)
            }
        }
        .onAppear {
            camera.check()
        }
    }
}
