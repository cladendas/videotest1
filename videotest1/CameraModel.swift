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
    private var selectedMovieMode1: AVCaptureDevice.Format?
    ///необходимая частота кадров
    private var frameRate: Double = 120.0
    
    @Published var isTaken: Bool = false
    @Published var session = AVCaptureSession()
    @Published var alert: Bool = false
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
    
    ///настройки камеры: устройство, тип данных, частота кадров
    func setup() {
        do {
            ///выбор устройства захвата: тип устройства, тип данных, положение устройства
            guard let device = AVCaptureDevice.default( .builtInWideAngleCamera, for: .video, position: .back) else { return }
            
            ///блокировка устройства для его найстройки
            try device.lockForConfiguration()
            
            ///используется для группировки нескольких операций найстроки сессии
            self.session.beginConfiguration()
            
            ///устройство, с которого необходимо захватить ввод
            let input = try AVCaptureDeviceInput(device: device)
            
            ///определение допустимости входа для данной сессии и его добавление
            if self.session.canAddInput(input) {
                self.session.addInput(input)
            }

            ///определение допустимости вывода для данной сессии и его добавление
            if self.session.canAddOutput(output) {
                self.session.addOutput(output)
            }
            
            ///получаем доступные форматы и ищем среди них с частотой кадров >= 120, затем найденный формат назначаем устройству
            for (_, format) in device.formats.enumerated() {
 
                guard let test = format.videoSupportedFrameRateRanges.last else { return }
                
                if test.maxFrameRate >= frameRate {
                    device.activeFormat = format
                }
            }

            self.session.commitConfiguration()
            device.unlockForConfiguration()
            
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func startRecording() {
        DispatchQueue.global(qos: .background).async {
            // Start recording video to a temporary file.
            let outputFileName = NSUUID().uuidString
            let outputFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((outputFileName as NSString).appendingPathExtension("mov")!)
            
            //ограничение длительности видео
//            self.output.maxRecordedDuration = CMTime(seconds: 3.0, preferredTimescale: .max)
            
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
