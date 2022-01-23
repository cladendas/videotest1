//
//  ContentView.swift
//  videotest1
//
//  Created by cladendas on 23.01.2022.
//

import SwiftUI
import AVFoundation

//setting view for preview
struct CameraPreview: UIViewRepresentable {
    
    @ObservedObject var camera: CameraModel
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        camera.preview = AVCaptureVideoPreviewLayer(session: camera.session)
        camera.preview.frame = view.frame
        
        camera.preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(camera.preview)
        
        //starting session
        camera.session.startRunning()
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        
    }
}

///Camera Model
class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var isTaken = false
    @Published var session = AVCaptureSession()
    @Published var alert = false
    
    //since were going to read pic data
    @Published var output = AVCapturePhotoOutput()
    
    //preview
    @Published var preview: AVCaptureVideoPreviewLayer!
    
    @Published var isSaved = false
    @Published var picData = Data(count: 0)
    
    func check() {
        //first checking camera has got permission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setup()
            return
            //Setting Up Session
        case .notDetermined:
            //requesting for permission
            AVCaptureDevice.requestAccess(for: .video) { status in
                if status {
                    self.setup()
                }
            }
        case .denied:
            self.alert.toggle()
            return
        default:
            return
        }
    }
    
    func setup() {
        //setting up camera
        
        do {
            self.session.beginConfiguration()
            
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            
            let input = try AVCaptureDeviceInput(device: device!)
            
            //checking and adding to session
            if self.session.canAddInput(input) {
                self.session.addInput(input)
            }
            
            //same for output
            if self.session.canAddOutput(output) {
                self.session.addOutput(output)
            }
            
            self.session.commitConfiguration()
            
        } catch {
            print(error.localizedDescription)
        }
    }
    
    //take and retake functions
    func takePic() {
        DispatchQueue.global(qos: .background).async {
            self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            self.session.stopRunning()
            
            DispatchQueue.main.async {
                withAnimation {
                    self.isTaken.toggle()
                }
            }
        }
    }
    
    func reTake() {
        DispatchQueue.global(qos: .background).async {
            self.session.startRunning()
            
            DispatchQueue.main.async {
                withAnimation {
                    self.isTaken.toggle()
                }
                
                //clearing
                self.isSaved = false
            }
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if error != nil {
            return
        }
        
        print("pic taken...")
        
        guard let imageData = photo.fileDataRepresentation() else { return }
        
        self.picData = imageData
    }
    
    func savePic() {
        let image = UIImage(data: self.picData)!
        
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        
        self.isSaved = true
        
        print("saved Successfully...")
    }
}

struct CameraView: View {
    
    @StateObject var camera = CameraModel()
    
    var body: some View {
        ZStack {
            
            //Going to be camera preview...
            CameraPreview(camera: camera)
                .ignoresSafeArea(.all, edges: .all)
            
            VStack {
                
                if camera.isTaken {
                    
                    HStack {
                        
                        Spacer()
                        
                        Button {
                            camera.reTake()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .foregroundColor(.black)
                                .padding()
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 10)
                    }
                }
                
                Spacer()
                
                HStack {
                    
                    //if taken showing save and again take button
                    
                    if camera.isTaken {
                        
                        Button {
                            if !camera.isSaved {
                                camera.savePic()
                            }
                        } label: {
                            Text(camera.isSaved ? "Saved" : "Save")
                                .foregroundColor(.black)
                                .fontWeight(.semibold)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                        .padding(.leading)

                        Spacer()
                    } else {
                        
                        Button {
                            camera.takePic()
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

struct ContentView: View {
    var body: some View {
        CameraView()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

