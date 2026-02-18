//
//  NextViewController.swift
//  BrailleBlockRecognition_iOS
//
//  Created by 松井研究室 on 2023/09/13.
//  Copyright © 2023 matuilab. All rights reserved.
//

import UIKit
import SafariServices
import CoreLocation
import CoreMotion
import AVFoundation//変更箇所



class NextViewController: UIViewController,UIGestureRecognizerDelegate,CLLocationManagerDelegate,UITextViewDelegate{
//    @IBOutlet weak var cameraImageView: UIImageView!
//    @IBOutlet weak var code: UITextField!
//    @IBOutlet weak var angle: UITextField!
    @IBOutlet weak var genres: UIButton!
//    @IBOutlet weak var guidance: UITextView!
    
    var infoBarButtonItem: UIBarButtonItem!
    
    let guideVoice = AudioPlayerModel()
    let codeBlock = CodeBlockController()
    let codeBlock2 = CodeBlockController2()
    let videoCapture = VideoCaptureModel()
    let captureSession = AVCaptureSession()//変更箇所
    let locationManager = CLLocationManager()
    
    
    
   
    
    var safariVC: SFSafariViewController?//Safariアプリに飛ばす
    var coupons: [[String: Any]] = []
    var guideText = NSLocalizedString("Verification", comment: "")
    var guideTextClone = NSLocalizedString("Verification", comment: "")
    var voiceGuidance = String()
    var urlMessage = String()
    var tapCount : Int = 0
    var genre = String()
    var genreName = NSLocalizedString("normal", comment: "")
    var fontsize = NSLocalizedString("Large", comment: "")
   
    
    var Latitude: String = ""///
    var Longitude: String = ""///
    
    
    //加速度センサで利用する変数
    let motionManager = CMMotionManager()
    var acceleX: Double = 0.0
    var acceleY: Double = 0.0
    var acceleZ: Double = 0.0
    let Alpha = 0.4
    var flg: Bool = false
    
    
    //ジャンル(messagecategory)選択ボタン及び切り替え
    /* ジャンル(messgecategory)対応表
        一般(normal) : "0"
        詳細(detail) : "1"
        避難(evacuation) : "2"
        専用(exclusive) : "3"
     */
    @IBAction func genres(_ sender: UIButton) {
        if tapCount == 0{
            sender.setTitle(NSLocalizedString("normal", comment: ""), for: .normal)
            genre = "0"
            tapCount += 1
        }
        else if tapCount == 1{
            sender.setTitle(NSLocalizedString("detail", comment: ""), for: .normal)
            genre = "1"
            //genre = "detail"
            tapCount += 1
        }
        else if tapCount == 2{
            sender.setTitle(NSLocalizedString("evacuation", comment: ""), for: .normal)
            genre = "2"
            //genre = "evacuation"
            tapCount += 1
        }
        else if tapCount == 3{
            sender.setTitle(NSLocalizedString("exclusive", comment: ""), for: .normal)
            genre = "3"
            //genre = "exclusive"
            tapCount = 0
        }
        genreName = genres.currentTitle ?? "error"
    }
   
    
    func stopmotion() {
        // 音声を停止させる処理を追加
        guideVoice.stop()
        codeBlock2.stopAudio()
        
        guideText = ""
        urlMessage = ""
        genres.setTitle(NSLocalizedString(genreName, comment: ""), for: .normal)
        
        // 音声が止まったらセンサも止める（無駄な動作防止）
        stopAccelerometer()
    }
    
    
    //自動スリープを無効化
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        //変更 2024/07/28
        self.setupCameraSession()// カメラセッションのセットアップ専用メソッドを呼び出す
        
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.hidesBackButton = true
        //サーバーからデータ取得
        //codeBlock.fetchGuideInformation()
        //省電力モードによるカメラの起動の処理
        
        //変更 2024/07/28
        DispatchQueue.main.async {
            self.videoCapture.startCapturing()
        }
        
        videoCapture.delegate = self
        //インスタンスアクセス許可
        codeBlock2.nextViewController = self
        
        guideVoice.delegate = self
        
        setDefaultButtonName()
    }
    //避難所情報取得機能で使う関数　↓
    @objc func tapped(_ sender: UITapGestureRecognizer){
        //ダブルタップした時の処理
        if genre == "2" {
            locationManager.requestLocation()   //現在地取得のやつ
            let nextViewController = self.storyboard?.instantiateViewController(withIdentifier: "toEvaVC") as! EvacuationViewController
            self.present(nextViewController, animated: true, completion: nil)
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        
        CLGeocoder().reverseGeocodeLocation(loc, completionHandler: {(placemarks, error) in
            
            if let error = error {
                print("reverseGeocodeLocation Failed: \(error.localizedDescription)")
                return
            }
            
            if let placemark = placemarks?[0] {
                let Latitude = loc.coordinate.latitude
                let Longitude = loc.coordinate.longitude
                //print(Latitude, Longitude)
                UserDefaults.standard.set(Latitude, forKey: "str0")
                UserDefaults.standard.set(Longitude, forKey: "str1")
            }
        })
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("error: \(error.localizedDescription)")
    }
    //周辺の避難所情報取得機能　↑
    
    //文字の大きさ設定
//    func setFontsize() {
//        fontsize = UserDefaults.standard.string(forKey: "fontsize") ?? "nil"
//        print(fontsize)
//        if fontsize == "Small"{
//            guidance.font = UIFont.systemFont(ofSize: 15)
//        }
//        else if fontsize == "Large"{
//            guidance.font = UIFont.systemFont(ofSize: 25)
//        }
//        else{
//            guidance.font = UIFont.systemFont(ofSize: 20)
//        }
//    }
    
    func lowpassFilter(acceleration: CMAcceleration){
        acceleX = Alpha * acceleration.x + acceleX * (1.0 - Alpha);
        acceleY = Alpha * acceleration.y + acceleY * (1.0 - Alpha);
        acceleZ = Alpha * acceleration.z + acceleZ * (1.0 - Alpha);
        //加速度の絶対値が1.3を超えた時の処理（音声停止）
        
        let threshold: Double = 1.4

            if acceleX > threshold || acceleY > threshold || acceleZ > threshold ||
               acceleX < -threshold || acceleY < -threshold || acceleZ < -threshold {
                print("シェイクを検知しました！")
                stopmotion()
            }
    }
    
    //加速度の測定を停止する
    func stopAccelerometer(){
        if (motionManager.isAccelerometerActive) {
            motionManager.stopAccelerometerUpdates()
        }
    }
    // ボタンの初期設定
    func setDefaultButtonName(){
        genres.setTitle(NSLocalizedString("normal", comment: ""), for: .normal)
        print("aaaaaaaaaa")
        genre = "0"
        tapCount += 1
    }
    
    //変更 2024/11/13
    //ジャンルにデータが無い場合、ボタンを自動切り替え
    func setSwitchButtonName(){
        genre = "0"
        genres.setTitle(NSLocalizedString("normal", comment: ""), for: .normal)
        genreName = NSLocalizedString("normal", comment: "")
    }
    
    // 認識中　赤枠線表示
//    func changeColorFrame(){
//        cameraImageView.layer.borderColor = UIColor.red.cgColor
//        cameraImageView.layer.borderWidth = 5
//    }
    //画面から移動した時に呼ばれる
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        videoCapture.stopCapturing()
        stopAccelerometer() // 追加
    }
    
    //変更 2024/07/28
    // カメラセッションの設定を行う新しいメソッド
    private func setupCameraSession() {
        videoCapture.setupSession()  // カメラ設定を行うメソッド。VideoCaptureModel内に定義が必要。
    }
    
}

extension NextViewController: VideoCaptureDelegate {
    func didCaptureFrame(display: UIImage, code: String, angle: String) {
        //コードか点字ブロック読み込み時の処理の記載
        // 画像表示
//        cameraImageView.image = display
        // 案内文表示
        //guidance.text = guideText
        // ある点字ブロックのキー作成
        let guidanceKey = code + angle + genre
        // 引数がSting型のためint型に変換
        let code = Int(code) ?? 0
        let angle = Int(angle) ?? -1
        
        // このifないと効果音だけが鳴り響く
        /* ifのパターン
         パターン　　　　　　　　　　　　　　　　｜　コード＆アングルの値 |
         カメラ常時起動(認識待ち)　　　　　　　 ｜　0　 　　  -1      |
         点字ブロックを認識したが、未登録だった　｜　1〜　　　  0〜     |　nil＝未登録として処理
         点字ブロックを認識し、登録があった　　　｜　1〜　　　  0〜     |
        */
        
        //変更 2024/06/19
        if code > 0 && angle > -1{
//            changeColorFrame()
          
           
            // 読み方を取得
            let resultCalls = codeBlock.resultValue(key: guidanceKey, type: .call)
            let resultCall = resultCalls.1 ?? NSLocalizedString("Unregistered", comment: "")
            
            // 案内文を取得
            let resultMessages = codeBlock.resultValue(key: guidanceKey, type: .guidance)
            let key = resultMessages.0
            
            
            //データベースのキーと取得したキーを照合し、違ったら、ジャンルボタンを一般に変更
            if guidanceKey != key {
                setSwitchButtonName()
            }
            
            let resultMessage = resultMessages.1 ?? NSLocalizedString("Unregistered", comment: "")
            
            
            if guideVoice.process { return }
            guideVoice.process = true
            
            //変更 2024/06/28
            /*guideText = resultMessage
            guidance.text = guideText
            guideTextClone = guideText*/
            
            // 読み方を取得
            codeBlock2.checkDeviceLocation(Code: code, Angle: angle, Genre: genre)
            //resultCallsの２番目（type）の値がnilであればUnregisteredが入る
        
            // 案内文にURLが入っている場合、読み方を表示し、読み方をアナウンスする
            /*if resultMessage.prefix(4) == "http"{
                guideText = resultCall
                voiceGuidance = resultCall
                urlMessage = resultMessage
            }
            //　読み方が無い場合、案内文を表示し、案内文をアナウンスする
            else if resultCall == "" {
                guideText = resultMessage
                voiceGuidance = resultMessage
            }
            /*else if resultCall == NSLocalizedString("Unregistered", comment: "") || resultCall == ""{
                guideText = resultMessage
                voiceGuidance = resultMessage
            }*/
            //通常(案内文も読み方もある場合、案内文を表示し、読み方をアナウンスする)
            else{
                guideText = resultMessage
                voiceGuidance = resultCall
            }*/
            
            //変更 2024/06/28
            //guidance.text = guideText
            //guideTextClone = guideText
            guideVoice.readGuide(manuscript: voiceGuidance, genre: genre, lang: codeBlock.language!)
            
            if urlMessage != ""{
                guard let web = NSURL(string: urlMessage) else { return }
                let config = SFSafariViewController.Configuration()
                config.entersReaderIfAvailable = true
                self.safariVC = SFSafariViewController(url: web as URL, configuration: config)
            }
//            self.code.text = "\(code)"
//            self.angle.text = "\(angle)"
            
            //変更 2024/07/21
            codeBlock2.stopAudio()
            codeBlock2.playAudio()
            //codeBlock2.updatePlaybckSpeed(playbackSpeed)
            
        }
    }
}



extension NextViewController: AudioPlayerDelegate {
    // ストリーミング再生が読み終えたら呼び出される
    func playerDidFinishPlaying(notification: Notification) {
        print("ONplayerDidFinishPlaying")
        
        //変更 2024/06/28
        guideVoice.process = false
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: notification.object)
        
        videoCapture.startCapturing()
        //加速度センサの読み取り停止
        self.stopAccelerometer()
        
        guideVoice.process = false
        //現在のジャンルに設定
        genres.setTitle(NSLocalizedString(genreName, comment: ""), for: .normal)
        //カメラ画面の枠色をクリア
//        cameraImageView.layer.borderColor = UIColor.clear.cgColor
        //videoCapture.startCapturing()
        
        //URLの処理
        if urlMessage != ""{
            videoCapture.stopCapturing()
            guard let webView = safariVC else { return }
            webView.delegate = self
            present(webView, animated: false, completion: nil)
            urlMessage = ""
          
        }
    }
    
    // 読み取り音が鳴り終わったら呼び出される
    func didFinishPlaying() {
        print("didFinishPlaying")
        // シェイク検知を開始
            if motionManager.isAccelerometerAvailable {
                motionManager.accelerometerUpdateInterval = 0.1
                motionManager.startAccelerometerUpdates(
                    to: OperationQueue.current!,
                    withHandler: { (accelData: CMAccelerometerData?, error: Error?) in
                        guard let data = accelData else { return }
                        self.lowpassFilter(acceleration: data.acceleration)
                    }
                )
            }
        videoCapture.startCapturing()
       
        guard let webView = safariVC else { return }
        webView.delegate = self
        present(webView,animated: false,completion: nil)
    }
    
    // 文字を読み終えたら呼び出される
     func didFinishReading() {
        print("playerDidFinishPlaying")
        videoCapture.startCapturing()
        //加速度センサの読み取り停止
        self.stopAccelerometer()
        
        guideVoice.process = false
        //現在のジャンルに設定
        genres.setTitle(NSLocalizedString(genreName, comment: ""), for: .normal)
        //カメラ画面の枠色をクリア
//        cameraImageView.layer.borderColor = UIColor.clear.cgColor
        //videoCapture.startCapturing()
        
        //URLの処理
        if urlMessage != ""{
            videoCapture.stopCapturing()
            guard let webView = safariVC else { return }
            webView.delegate = self
            present(webView, animated: false, completion: nil)
            urlMessage = ""
          
        }
    }
}

extension NextViewController: SFSafariViewControllerDelegate {
    // 画面の読み込み完了時に呼び出される
    //アクションボタンタップ時
    func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
        safariVC = nil
    }
}


