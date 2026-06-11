import UIKit
import SafariServices
import CoreLocation
import CoreMotion
import AVFoundation//変更箇所

class ViewController: UIViewController, UIGestureRecognizerDelegate,CLLocationManagerDelegate{
    @IBOutlet weak var cameraImageView: UIImageView!
    @IBOutlet weak var code: UITextField!
    @IBOutlet weak var angle: UITextField!
    @IBOutlet weak var genres: UIButton!
    @IBOutlet weak var guidance: UITextView!
    
    
    // 編集ボタン
    var infoBarButtonItem: UIBarButtonItem!
    
    let guideVoice = AudioPlayerModel()
    let codeBlock = CodeBlockController()
    var codeBlock2 = CodeBlockController2()
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
    var fontsize = NSLocalizedString("Medium", comment: "")
    var ecomode = UserDefaults.standard.string(forKey: "ecomode") ?? "nil"
    var Latitude: String = ""///
    var Longitude: String = ""///
    
    //加速度センサで利用する変数
    let motionManager = CMMotionManager()
    var acceleX: Double = 0.0
    var acceleY: Double = 0.0
    var acceleZ: Double = 0.0
    let Alpha = 0.4
    var flg: Bool = false
    
    //2025/11/23 検証用
    // デバッグ用のラベルをコードで作成
    //private let tempDebugLabel = UILabel()
    
    //変更 2024/07/21
    var playbackSpeed: Float {
        get {
            let speed = UserDefaults.standard.float(forKey: "reproductionSpeed")
            return speed == 0.0 ? 0.5 : speed
        }
        set{
            UserDefaults.standard.setValue(newValue, forKey: "reproductionSpeed")//newValueとはなんだ、怪しい
            //codeBlock2.updatePlaybckSpeed(newValue)
        }
    }
    
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
            tapCount += 1
            
        }
        else if tapCount == 2{
            sender.setTitle(NSLocalizedString("evacuation", comment: ""), for: .normal)
            genre = "2"
            tapCount += 1
           
        }
        else if tapCount == 3{
            sender.setTitle(NSLocalizedString("exclusive", comment: ""), for: .normal)
            genre = "3"
            tapCount = 0
            
        }
        genreName = genres.currentTitle ?? "error"
    }
    
    func stopmotion() {
        guideVoice.stop()
        
        //変更 2024/06/19
        codeBlock2.stopAudio()
        videoCapture.stopCapturing()
        videoCapture.startCapturing()
        
        guideText = ""
        urlMessage = ""
        code.text = "\(0)"
        angle.text = "\(0)"
        genres.setTitle(NSLocalizedString(genreName, comment: ""), for: .normal)
        cameraImageView.layer.borderColor = UIColor.clear.cgColor
        
        if tapCount == 1 {
            genre = "0"
            genres.setTitle(NSLocalizedString("normal", comment: ""), for: .normal)
            genreName = NSLocalizedString("normal", comment: "")
        } else if tapCount == 2 {
            genre = "1"
            genres.setTitle(NSLocalizedString("detail", comment: ""), for: .normal)
            genreName = NSLocalizedString("detail", comment: "")
        } else if tapCount == 3 {
            genre = "2"
            genres.setTitle(NSLocalizedString("evacuation", comment: ""), for: .normal)
            genreName = NSLocalizedString("evacuation", comment: "")
        } else if tapCount == 0 {
            genre = "3"
            genres.setTitle(NSLocalizedString("exclusive", comment: ""), for: .normal)
            genreName = NSLocalizedString("exclusive", comment: "")
        }
        genreName = genres.currentTitle ?? "error"
        
        //変更 2024/07/21
        //codeBlock2.updatePlaybckSpeed(playbackSpeed)
    
    }
    
    func finishmotion(){
        guideVoice.stop()
        
        //変更 2024/06/19
        codeBlock2.stopAudio()
        videoCapture.stopCapturing()
        videoCapture.startCapturing()
        
        //guideText = ""
        //urlMessage = ""
        //code.text = "\(0)"
        //angle.text = "\(0)"
        genres.setTitle(NSLocalizedString(genreName, comment: ""), for: .normal)
        cameraImageView.layer.borderColor = UIColor.clear.cgColor
        
        //変更 2024/11/20
        //一般以外のジャンルに情報がない場合、一般のデータが表示されるが再度、元のジャンルに戻すリセット処理
        if tapCount == 1 {
            genre = "0"
            genres.setTitle(NSLocalizedString("normal", comment: ""), for: .normal)
            genreName = NSLocalizedString("normal", comment: "")
        } else if tapCount == 2 {
            genre = "1"
            genres.setTitle(NSLocalizedString("detail", comment: ""), for: .normal)
            genreName = NSLocalizedString("detail", comment: "")
        } else if tapCount == 3 {
            genre = "2"
            genres.setTitle(NSLocalizedString("evacuation", comment: ""), for: .normal)
            genreName = NSLocalizedString("evacuation", comment: "")
        } else if tapCount == 0 {
            genre = "3"
            genres.setTitle(NSLocalizedString("exclusive", comment: ""), for: .normal)
            genreName = NSLocalizedString("exclusive", comment: "")
        }
        genreName = genres.currentTitle ?? "error"
        //変更 2024/07/21
        //codeBlock2.updatePlaybckSpeed(playbackSpeed)
        
    }
    
    //音声停止ボタン 現在の再生、同code、angleでの連続再生を停止させる。
    @IBAction func stop(_ sender: UIButton) {
        stopmotion()
        
        //変更 2024/07/21
        //codeBlock2.updatePlaybckSpeed(playbackSpeed)
        
    }
    /*@IBAction func pause(_ sender: UIButton) {
        changeColorFrame()
        guideVoice.pause()
        
    }
    @IBAction func resume(_ sender: Any) {
        changeColorFrame()
        guideVoice.playback()
    }*/
    //リピートボタン
    @IBAction func echo(_ sender: UIButton) {
        
        changeColorFrame()
        guideText = guideTextClone
        
        //変更 2024/06/19
        codeBlock2.stopAudio()
        codeBlock2.playAudio()
        
        //変更 2024/07/21
        //codeBlock2.updatePlaybckSpeed(playbackSpeed)
        
        //guideVoice.echo(manuscript: voiceGuidance, lang: codeBlock.language!)
    }
    //自動スリープを無効化
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func viewDidLoad() {//Viewが読みこれまれた時の処理
        super.viewDidLoad()//ライフサイクルメソッドによる記述。
        
        //サーバーからデータ取得
        //変更 2024/07/15
        codeBlock.fetchGuideInformation{
            self.videoCapture.startCapturing()
        }
        //省電力モードによるカメラの起動の処理
        if ecomode == "ON"{
            videoCapture.stopCapturing()
        }
        videoCapture.delegate = self//全てのselfはViewControllerを示している？
        guideVoice.delegate = self
        
        //変更 2024/06/28
        codeBlock2.viewController = self
        
        
        //InfoVC(設定画面)へのボタン設置
        infoBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "info.circle"), style: .done, target: self, action: #selector(infoBarButtonTapped(_:)))
        self.navigationItem.leftBarButtonItem = infoBarButtonItem
        //ダブルタップ設定
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        //ダブルタップイベントを登録
        let tapGesture: UITapGestureRecognizer = UITapGestureRecognizer(
                        target: self,
                        action: #selector(tapped(_:)))
        tapGesture.delegate = self
        tapGesture.numberOfTapsRequired = 2//ダブルタップで反応
        self.view.addGestureRecognizer(tapGesture)
        //長押しイベントを登録
        let longpressGesture = UILongPressGestureRecognizer(target: self, action: #selector(ViewController.longPress(_:)))
        
        longpressGesture.delegate = self
        self.view.addGestureRecognizer(longpressGesture)
        guidance.text = guideText
        setDefaultButtonName()
        
        
        
        if UIAccessibility.isVoiceOverRunning {//ボイスオーバーON、OFFを判別して返す
            let nextViewController = NextViewController()
            // 画面遷移
            self.performSegue(withIdentifier: "NextView", sender: self)
        } else {
            
            //変更 2024/07/28
            self.setupCameraSession()// カメラセッションのセットアップ専用メソッドを呼び出す
            
            print("VoiceOver is not running.")
        }
        
        //変更 2024/07/21
        if playbackSpeed == 0.0 {
            playbackSpeed = 0.5
        }
        
        //変更 2024/09/17
        //codeBlock2.updatePlaybckSpeed(playbackSpeed)//これがあるとアプリを再起動したときに速度が変わってしまう
        //2025/11/23 検証用
        // 画面の最前面にデバッグ用ラベルを配置
//        tempDebugLabel.frame = CGRect(x: 20, y: 100, width: 300, height: 100) // 画面上部に配置
//        tempDebugLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7) // 背景を半透明の黒に
//        tempDebugLabel.textColor = .red // 文字は赤
//        tempDebugLabel.numberOfLines = 0 // 複数行表示
//        tempDebugLabel.font = UIFont.boldSystemFont(ofSize: 20)
//        tempDebugLabel.text = "デバッグ準備完了"
//        self.view.addSubview(tempDebugLabel)
//        self.view.bringSubviewToFront(tempDebugLabel)
        
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
    
    //長押しした時の処理
    @objc func longPress(_ sender: UILongPressGestureRecognizer) {
        ecomode = UserDefaults.standard.string(forKey: "ecomode") ?? "nil"
        if ecomode == "ON"{
            if sender.state == .began{
                print("長押し開始")
                //カメラ開始(同じインスタンスを使い回すために、他とは書き方が異なる)
                videoCapture.startCapturing()
            }
            else if sender.state == .ended{
                print("長押し終了")
                //カメラ停止
                videoCapture.stopCapturing()
            }
        }
    }
    //文字の大きさ設定
    func setFontsize() {
        fontsize = UserDefaults.standard.string(forKey: "fontsize") ?? "nil"
        print(fontsize)
        if fontsize == "Small"{
            guidance.font = UIFont.systemFont(ofSize: 15)
        }
        else if fontsize == "Large"{
            guidance.font = UIFont.systemFont(ofSize: 25)
        }
        else{
            guidance.font = UIFont.systemFont(ofSize: 20)
        }
    }
    
    //一応ローパスフィルターを入れた（シェイク）
    func lowpassFilter(acceleration: CMAcceleration){
        acceleX = Alpha * acceleration.x + acceleX * (1.0 - Alpha);
        acceleY = Alpha * acceleration.y + acceleY * (1.0 - Alpha);
        acceleZ = Alpha * acceleration.z + acceleZ * (1.0 - Alpha);
        //加速度の絶対値が1.3を超えた時の処理（音声停止）
        if acceleX > 1.3 || acceleY > 1.3 || acceleZ > 1.3 || acceleX < -1.3 || acceleY < -1.3 || acceleZ < -1.3 {
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
    func changeColorFrame(){
        cameraImageView.layer.borderColor = UIColor.red.cgColor
        cameraImageView.layer.borderWidth = 5
    }
    //画面から移動した時に呼ばれる
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        videoCapture.stopCapturing()
    }
    
    //変更 2024/07/28
    // カメラセッションの設定を行う新しいメソッド
    private func setupCameraSession() {
        videoCapture.setupSession()  // カメラ設定を行うメソッド。VideoCaptureModel内に定義が必要。
    }
    
    //infoVCへのボタンを押した時の画面遷移設定とデリゲートを登録
    @objc func infoBarButtonTapped(_ sender: UIBarButtonItem) {
        let infoVC = self.storyboard?.instantiateViewController(withIdentifier: "infoVC") as! InfoViewController
        infoVC.infoCodeData = codeBlock
        infoVC.delegate = self
        let nav = UINavigationController(rootViewController: infoVC)
        self.present(nav, animated: true, completion: nil)
        
    }
}

extension ViewController: VideoCaptureDelegate {
    func didCaptureFrame(display: UIImage, code: String, angle: String) {
        //2025/11/23 検証用
        // 画像の更新
        //self.imageView.image = display
        
        // 【追加】デバッグ用：画面上のラベルに値を無理やり表示する
        // これで実機単独でも、codeが空なのか、変な値が入っているのか確認できます
        //self.tempDebugLabel.text = "Code: [\(code)]\nAngle: [\(angle)]"
        
        
        //コードか点字ブロック読み込み時の処理の記載
        // 画像表示
        cameraImageView.image = display
        // 案内文表示
        guidance.text = guideText
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
            changeColorFrame()
          
           
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
            guideText = resultMessage
            guidance.text = guideText
            guideTextClone = guideText
            
            // 読み方を取得
            codeBlock2.checkDeviceLocation(Code: code, Angle: angle, Genre: genre)
            //resultCallsの２番目（type）の値がnilであればUnregisteredが入る
            
            // 登録されていないコードを読み取った時の処理
            if resultMessage == "" {
                guideText = "未登録"
            }
            // 案内文にURLが入っている場合、読み方を表示し、読み方をアナウンスする
            else if resultMessage.prefix(4) == "http"{
                guideText = resultCall
                voiceGuidance = resultCall
                urlMessage = resultMessage
                
                //変更 2024/10/31
                //presentSafariViewController(with:)メソッドの呼び出し
                if let url = URL(string: urlMessage){
                    presentSafariViewController(with: url)
                }
                
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
            }
            
            //変更 2024/06/28
            guidance.text = guideText
            guideTextClone = guideText
            guideVoice.readGuide(manuscript: voiceGuidance, genre: genre, lang: codeBlock.language!)
            
            if urlMessage != ""{
                guard let web = NSURL(string: urlMessage) else { return }
                let config = SFSafariViewController.Configuration()
                config.entersReaderIfAvailable = true
                self.safariVC = SFSafariViewController(url: web as URL, configuration: config)
            }
            self.code.text = "\(code)"
            self.angle.text = "\(angle)"
            
            //変更 2024/07/21
            codeBlock2.stopAudio()
            codeBlock2.playAudio()
            //codeBlock2.updatePlaybckSpeed(playbackSpeed)
            
        }
    }
}

extension ViewController: AudioPlayerDelegate {
    func playerDidFinishPlaying(notification: Notification) {
        
        //変更 2024/06/27
        guideVoice.process = false
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: notification.object)
        
        //変更 2024/06/28
        videoCapture.startCapturing()
        //加速度センサの読み取り停止
        self.stopAccelerometer()
        
        //現在のジャンルに設定
        genres.setTitle(NSLocalizedString(genreName, comment: ""), for: .normal)
        //カメラ画面の枠色をクリア
        cameraImageView.layer.borderColor = UIColor.clear.cgColor
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
        //シェイクの設定↓
        if motionManager.isAccelerometerAvailable {
            // intervalの設定 [sec]
            motionManager.accelerometerUpdateInterval = 0.2
            // センサー値の取得開始
            motionManager.startAccelerometerUpdates(
                to: OperationQueue.current!,
                withHandler: {(accelData: CMAccelerometerData?, errorOC: Error?) in
                    self.lowpassFilter(acceleration: accelData!.acceleration)
            })
        }
        //videoCapture.startCapturing()
       
        guard let webView = safariVC else { return }
        webView.delegate = self
        present(webView,animated: false,completion: nil)
    }
    
    // 文字を読み終えたら呼び出される
    func didFinishReading() {
        print(genre)
        //省電力モードの処理
        if ecomode == "OFF"{
            videoCapture.startCapturing()
        }
        //加速度センサの読み取り停止
        self.stopAccelerometer()
        
        guideVoice.process = false
        //現在のジャンルに設定
        genres.setTitle(NSLocalizedString(genreName, comment: ""), for: .normal)
        //カメラ画面の枠色をクリア
        cameraImageView.layer.borderColor = UIColor.clear.cgColor
       
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

extension ViewController: SFSafariViewControllerDelegate {
    
    //変更 2024/10/31
    //safariViewControllerの重複を防ぐ
    func presentSafariViewController(with url: URL){
        //safariVCがすでに表示されているかをチェック
        if safariVC != nil{
            return
        }
        //SafariViewControllerのインスタンスを作成
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true
        safariVC = SFSafariViewController(url: url, configuration: config)
        safariVC?.delegate = self
        
        //SafariViewControllerを表示
        present(safariVC!, animated: true, completion: nil)
    }
    
    // 画面の読み込み完了時に呼び出される
    //アクションボタンタップ時
    func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
        safariVC = nil
    }
    
    // 画面が閉じる時に呼び出される
    //完了ボタンタップ時
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        
        safariVC = nil//safariVCをリセット
        
        if ecomode == "OFF"{
            videoCapture.startCapturing()
        }
        //videoCapture.startCapturing()
        guideVoice.process = false
        urlMessage = ""
        print("完了する")
    }
}

extension ViewController: InfoViewDelegate{
    //infoVCで完了ボタン押し時に呼ばれる
    func swtichCamera(ecomode: String) {
        videoCapture.startCapturing()
        if ecomode == "ON"{
            videoCapture.stopCapturing()
        }
    }
    
    //変更 2024/07/07
    func updatePlaybackSpeed(_ speed: Float) {
        codeBlock2.updatePlaybckSpeed(speed)
    }
    
}
