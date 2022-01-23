//
//  CameraModel.swift
//  videotest1
//
//  Created by cladendas on 23.01.2022.
//

import SwiftUI
import AVFoundation
import Photos

class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate {
    
    private var backgroundRecordingID: UIBackgroundTaskIdentifier?
    
    @Published var isTaken = false
    @Published var session = AVCaptureSession()
    @Published var alert = false
    @Published var output = AVCaptureMovieFileOutput()
    @Published var preview: AVCaptureVideoPreviewLayer!

    ///проверка доступности камеры
    func check() {
        //есть ли у приложения разрешение на запись указанного типа носителя
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        //Пользователь явно предоставил разрешение на захват мультимедиа, или явное разрешение пользователя не требуется для рассматриваемого типа мультимедиа
        case .authorized:
            setup()
            return
        //Для захвата мультимедиа требуется явное разрешение пользователя, но пользователь еще не предоставил или не отклонил такое разрешение
        case .notDetermined:
            //requesting for permission
            AVCaptureDevice.requestAccess(for: .video) { status in
                if status {
                    self.setup()
                }
            }
        //пользователь отказал в разрешении на захват мультимедиа
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
            
            ///выбор устройства захвата: тип устройства, тип данных, положение устройства
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            
            ///устройство, с которого необходимо захватить ввод
            let input = try AVCaptureDeviceInput(device: device!)
            
            //checking and adding to session
            if self.session.canAddInput(input) {
                self.session.addInput(input)
            }

            if self.session.canAddOutput(output) {
                self.session.addOutput(output)
            }
            
            self.session.commitConfiguration()
            
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func startRecording() {
        DispatchQueue.global(qos: .background).async {
            // Start recording video to a temporary file.
            let outputFileName = NSUUID().uuidString
            let outputFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((outputFileName as NSString).appendingPathExtension("mov")!)
            self.output.startRecording(to: URL(fileURLWithPath: outputFilePath), recordingDelegate: self)
            
            DispatchQueue.main.async {
                withAnimation {
                    self.isTaken.toggle()
                }
            }
        }
    }
    
    func stopRecording() {
        self.output.stopRecording()
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        //т.к. используется уникальный путь к файлу для каждой записи, новая запись не перезапишет запись в процессе сохранения
        func cleanup() {
            let path = outputFileURL.path
            if FileManager.default.fileExists(atPath: path) {
                do {
                    try FileManager.default.removeItem(atPath: path)
                } catch {
                    print("Could not remove file at url: \(outputFileURL)")
                }
            }
            
            if let currentBackgroundRecordingID = backgroundRecordingID {
                backgroundRecordingID = UIBackgroundTaskIdentifier.invalid
                
                if currentBackgroundRecordingID != UIBackgroundTaskIdentifier.invalid {
                    UIApplication.shared.endBackgroundTask(currentBackgroundRecordingID)
                }
            }
        }
        
        var success = true
        
        if error != nil {
            print("Movie file finishing error: \(String(describing: error))")
            success = (((error! as NSError).userInfo[AVErrorRecordingSuccessfullyFinishedKey] as AnyObject).boolValue)!
        }
        
        if success {
            // Check the authorization status
            PHPhotoLibrary.requestAuthorization { status in
                if status == .authorized {
                    // Save the movie file to the photo library and cleanup
                    PHPhotoLibrary.shared().performChanges({
                        let options = PHAssetResourceCreationOptions()
                        options.shouldMoveFile = true
                        
                        let creationRequest = PHAssetCreationRequest.forAsset()
                        creationRequest.addResource(with: .video, fileURL: outputFileURL, options: options)
                    }, completionHandler: { success, error in
                        if !success {
                            print("AVCam couldn't save the movie to your photo library: \(String(describing: error))")
                        }
                        cleanup()
                    }
                    )
                } else {
                    cleanup()
                }
            }
        } else {
            cleanup()
        }
        
        print("видео записано !!!!!", outputFileURL)
    }
}
