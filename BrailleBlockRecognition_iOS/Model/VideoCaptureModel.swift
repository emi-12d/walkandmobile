import AVFoundation


protocol VideoCaptureDelegate: AnyObject {
    func didCaptureFrame(display: UIImage, code: String, angle: String)
}

class VideoCaptureModel: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    weak var delegate: VideoCaptureDelegate?
    
    private var captureSession: AVCaptureSession! //セッション
    private var device: AVCaptureDevice! //カメラ
    private var output: AVCaptureVideoDataOutput! //出力先
    
    var isCameraRunning = false
    
    //変更 2024/07/28
    // VideoCaptureModel内に新しいセッションセットアップメソッドを追加
    public func setupSession() {
        // セッションの作成.
        captureSession = AVCaptureSession()
        // 解像度の指定.
        captureSession.sessionPreset = .photo
        // デバイス取得.
        device = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera,
                                         for: .video,
                                         position: .back)

        // VideoInputを取得.
        var input: AVCaptureDeviceInput! = nil
        do {
            input = try AVCaptureDeviceInput(device: device) as AVCaptureDeviceInput
        } catch let error {
            print(error)
            return
        }

        // セッションに追加.
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        } else {
            return
        }

        // 出力先を設定
        output = AVCaptureVideoDataOutput()

        //ピクセルフォーマットを設定
        output.videoSettings =
            [ kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String : Int(kCVPixelFormatType_32BGRA) ]
        //2025 6月28日　修正
        if UIAccessibility.isVoiceOverRunning {
            // VoiceOver が ON のときの処理
            let videoQueue = DispatchQueue(label: "videoQueue")
            output.setSampleBufferDelegate(self, queue: videoQueue)
        } else {
            // VoiceOver が OFF のときの処理
            //サブスレッド用のシリアルキューを用意
            output.setSampleBufferDelegate(self, queue: DispatchQueue.main)
        }


        // 遅れてきたフレームは無視する
        //怪しい
        output.alwaysDiscardsLateVideoFrames = true

        // FPSを設定
        do {
            try device.lockForConfiguration()

            device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 20) //フレームレート
            device.unlockForConfiguration()
        } catch {
            return
        }

        // セッションに追加.
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        } else {
            return
        }

        // カメラの向きを合わせる
        for connection in output.connections {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = AVCaptureVideoOrientation.portrait
            }
        }
        
        //変更 2024/10/11
        //captureSession.startRunning()
    }
    
    public func startCapturing() {
        
        //変更 2024/07/28
        //captureSessionがnilでないことを確認し、その上でセッションの開始
        DispatchQueue.main.async {
                if let session = self.captureSession, !session.isRunning {
                    session.startRunning()
                } else {
                    print("Camera session is not set up or already running")
                }
            }
        isCameraRunning = true
        
    }
    
    
    public func stopCapturing() {
        if let session = captureSession, session.isRunning{
            captureSession.stopRunning()
            isCameraRunning = false
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //2025 6月28日　修正
        if UIAccessibility.isVoiceOverRunning {
            // VoiceOver が ON のときの処理
            let img = self.captureImage(sampleBuffer)
            self.openCVImageProcessing(image: img)
        } else {
            // VoiceOver が OFF のときの処理
            DispatchQueue.main.async {
                let img = self.captureImage(sampleBuffer) //UIImageへ変換
                self.openCVImageProcessing(image: img)
            }
        }
    }
    
    private func openCVImageProcessing(image: UIImage) {
        let openCV = OpenCV()
        let result = openCV.reader(image)! as NSArray
        
        let codeResult = result[0]
        let angleResult = result[1]
        let ImageResult = result[2]
        
        delegate?.didCaptureFrame(display: ImageResult as! UIImage, code: "\(codeResult)", angle: "\(angleResult)")
        //↓は緑枠なしの時
        //delegate?.didCaptureFrame(display: image, code: "\(codeResult)", angle: "\(angleResult)")
    }
    
    // sampleBufferからUIImageを作成
    // 安全性重視の「完全データコピー」版
        private func captureImage(_ sampleBuffer: CMSampleBuffer) -> UIImage {
            // 画像バッファを取得
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return UIImage()
            }
            
            // 1. バッファをロック（読み取り中に消されないようにする）
            CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
            
            // 2. 画像情報を取得
            let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
            let width = CVPixelBufferGetWidth(imageBuffer)
            let height = CVPixelBufferGetHeight(imageBuffer)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
            
            // 3. カラースペースの設定（RGB）
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            
            // 4. ビットマップ情報の定義 (32bit BGRA形式)
            // ここが少し複雑ですが、OpenCVが好む形式に合わせています
            let bitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) as UInt32)
            
            // 5. 新しい描画コンテキストを作成（ここでメモリが確保されます）
            guard let context = CGContext(data: baseAddress,
                                          width: width,
                                          height: height,
                                          bitsPerComponent: 8,
                                          bytesPerRow: bytesPerRow,
                                          space: colorSpace,
                                          bitmapInfo: bitmapInfo.rawValue) else {
                CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
                return UIImage()
            }
            
            // 6. 画像を作成（ディープコピー）
            guard let cgImage = context.makeImage() else {
                CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
                return UIImage()
            }
            
            // 7. バッファのロック解除（もうcgImageにコピーされたので解除してOK）
            CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
            
            // 8. UIImageに変換（向きは .up に戻しました）
            let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
            
            return image
        }
}

