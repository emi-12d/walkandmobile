import Network
import AVFAudio
import AVKit
import AVFoundation
import UIKit
//import AlamofireImage



typealias CodeDict2 = [String: String]

class CodeBlockController2 : UIViewController{
    private var audio:CodeDict2 = [:]
    private var currentURL: URL?//現在のURLを保持
    private var isFetchingURL = false
    var player: AVPlayer!
    var playerLayer: AVPlayerLayer!
    private var statusObserver: NSKeyValueObservation?
    private var networkMonitor: NWPathMonitor!
    private let queue = DispatchQueue(label: "com.networkconfig")
    private var isMonitoringStarted = false
    
    private var isPlayingAudio = false
    
    //変更 2024/07/07
    private var playbackSpeed: Float {
        
        //変更 2024/07/21
        get {
            let speed = UserDefaults.standard.float(forKey: "reproductionSpeed")
            return speed == 0.0 ? 0.5 : speed
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "reproductionSpeed")
        }
        
    }
    
    let guideVoice = AudioPlayerModel()
    
    weak var viewController: ViewController?
    
    //nextviewへアクセスするためのインスタンス作成
    weak var nextViewController: NextViewController?
    
    private let database = DataBaseModel()
    
    public  let language = NSLocale.preferredLanguages.first?.components(separatedBy: "-").first
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        networkMonitor = NWPathMonitor()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func fetchGuideInformation(url: URL) {
        print("Connected")
        guard !isMonitoringStarted else { return }
        
        guard !isFetchingURL else{
            return
        }
        
        // URLの取得が開始されたら記録する
        isFetchingURL = true
        
        // 与えられたURLでAVPlayerItemを作成
        let playerItem = AVPlayerItem(url: url)
        
        // AVPlayerItemを使用してAVPlayerを作成
        self.player = AVPlayer(playerItem: playerItem)
        
        // AVPlayerLayerを作成し、ビューに追加
        self.playerLayer = AVPlayerLayer(player: self.player)
        playerLayer.frame = view.bounds
        view.layer.addSublayer(playerLayer)
        
        // コンテンツを再生
        //player.play()
        //setPlayerRate()
        print("ストリーミング")
        
        // 再生が終了した際の通知を設定
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinish), name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
    }
    
    // ストリーミング再生が終了した時に呼ばれるメソッド
    @objc public func playerDidFinish(notification: Notification) {

        viewController?.videoCapture.startCapturing()
        // 💡 VoiceOver ON時（nextViewController）のカメラも再開させる
        nextViewController?.videoCapture.startCapturing()
        
        isFetchingURL = false
        
        viewController?.finishmotion()
        // 💡 nextViewController側の finishmotion は削除済みのため呼ばない！
        // nextViewController?.finishmotion()
        
        viewController?.playerDidFinishPlaying(notification: notification)
        nextViewController?.playerDidFinishPlaying(notification: notification)
        print("ストリーミング再生が終了しました")
        
        setPlayerRate()
    }
    public func checkDeviceLocation(Code:Int, Angle:Int, Genre:String){
        //AWS
        var standard = "https://codedbb.com/tenji/message"
        //var standard = "http://18.224.144.136/tenji/message"
        //研究室サーバー
        //let standard = "http://202.13.160.89:50003/tenji/get_db2json.py?data=blockmessage"
        
        switch language {
        case "ja":
            if Genre == "0"{
                standard = standard + "/wm" + String(format:"%05d", Code) + "_" + String(Angle)  + ".mp3"
            }
            
            //変更 2024/07/18
            else if Genre == "1"{
                standard = standard + "/wm" + String(format:"%05d", Code) + "_" + String(Angle)  + "_detail.mp3"
            }else if Genre == "2"{
                standard = standard + "/wm" + String(format:"%05d", Code) + "_" + String(Angle)  + "_evacuation.mp3"
            }else if Genre == "3"{
                standard = standard + "/wm" + String(format:"%05d", Code) + "_" + String(Angle)  + "_exclusive.mp3"
            }
            
            /*else {
                standard = standard + "/wm" + String(format:"%05d", Code) + "_" + String(Angle)  + "_" + Genre + ".mp3"
            }*/
            /* case "ja":
             standard = standard + "/wm" + String(format:"%05d", Code) + "_" + String(Angle)  + ".mp3"*/
        case "en":
            if Genre == "0"{
                standard = standard + "_en/wm" + String(format:"%05d", Code) + "_" + String(Angle)  + ".mp3"
            }else if Genre == "1"{
                standard = standard + "_en/wm" + String(format:"%05d", Code) + "_" + String(Angle)  + "_detail.mp3"
            }else if Genre == "2"{
                standard = standard + "_en/wm" + String(format:"%05d", Code) + "_" + String(Angle)  + "_evacuation.mp3"
            }else if Genre == "3"{
                standard = standard + "_en/wm" + String(format:"%05d", Code) + "_" + String(Angle)  + "_exclusive.mp3"
            }
            /*standard = standard + "_en/wm" + String(format:"%05d", Code) + "_" + String(Angle) + "_" + Genre + ".mp3"*/
        case "ko":
            if Genre == "0"{
                standard = standard + "_ko/wm" + String(format:"%05d", Code) + "_" + String(Angle)  + ".mp3"
            }else if Genre == "1"{
                standard = standard + "_ko/wm" + String(format:"%05d", Code) + "_" + String(Angle)  + "_detail.mp3"
            }else if Genre == "2"{
                standard = standard + "_ko/wm" + String(format:"%05d", Code) + "_" + String(Angle)  + "_evacuation.mp3"
            }else if Genre == "3"{
                standard = standard + "_ko/wm" + String(format:"%05d", Code) + "_" + String(Angle)  + "_exclusive.mp3"
            }
            /*standard = standard + "_ko/wm" + String(format:"%05d", Code) + "_" + String(Angle) + "_" + Genre + ".mp3"*/
        case "zh":
            if Genre == "0"{
                standard = standard + "_zh/wm" + String(format:"%05d", Code) + "_" + String(Angle)  + ".mp3"
            }else if Genre == "1"{
                standard = standard + "_zh/wm" + String(format:"%05d", Code) + "_" + String(Angle)  + "_detail.mp3"
            }else if Genre == "2"{
                standard = standard + "_zh/wm" + String(format:"%05d", Code) + "_" + String(Angle)  + "_evacuation.mp3"
            }else if Genre == "3"{
                standard = standard + "_zh/wm" + String(format:"%05d", Code) + "_" + String(Angle)  + "_exclusive.mp3"
            }
            /*standard = standard + "_zh/wm" + String(format:"%05d", Code) + "_" + String(Angle) + "_" + Genre + ".mp3"*/
        default:
            if Genre == "0"{
                standard = standard + "/wm" + String(format:"%05d", Code) + "_" + String(Angle)  + ".mp3"
            }else if Genre == "1"{
                standard = standard + "/wm" + String(format:"%05d", Code) + "_" + String(Angle)  + "_detail.mp3"
            }else if Genre == "2"{
                standard = standard + "/wm" + String(format:"%05d", Code) + "_" + String(Angle)  + "_evacuation.mp3"
            }else if Genre == "3"{
                standard = standard + "/wm" + String(format:"%05d", Code) + "_" + String(Angle)  + "_exclusive.mp3"
            }
            /*standard = standard + "/wm" + String(format:"%05d", Code) + "_" + String(Angle) + "_" + Genre + ".mp3"*/
        }
        // 新しいURLを取得して再生
        if let yourURL = URL(string: standard) {
            currentURL = yourURL
            //fetchGuideInformation(url: yourURL)
            
            //変更 2024/06/27
            //stopAudio()
            //playAudio()
            
            print(Genre)
            print(standard)
            
        }
    }
    // 用はargGuidanceとargCallのこと
    private func setLocalData(data: (CodeDict2)){
        audio = data
        
    }
    public func resultAllInfomation() ->CodeDict2 {
        return audio
    }
    
    //変更 2026/9/16
    @objc func playAudio() {
        guideVoice.process = true

        let setupTask = {
            self.viewController?.videoCapture.stopCapturing()
            guard let url = self.currentURL else {
                print("URL is return")
                return
            }
            
            let playerItem = AVPlayerItem(url: url)
            
            // サーバー上にファイルが存在しない場合を検知
            self.statusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
                guard let self = self else { return }
                
                if item.status == .failed {
                    print("サーバーに音声ファイルが見つかりません。未登録として処理します。")
                    if UIAccessibility.isVoiceOverRunning {
                        self.guideVoice.echo(manuscript: "もう一度読み取ってください", lang: "ja")
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        guard self.player != nil else { return }
                        self.playerDidFinish(notification: Notification(name: .AVPlayerItemDidPlayToEndTime))
                    }
                }
            }
            
            self.player = AVPlayer(playerItem: playerItem)
            self.playerLayer = AVPlayerLayer(player: self.player)
            self.playerLayer?.frame = self.view.bounds
            if let safeLayer = self.playerLayer {
                self.view.layer.addSublayer(safeLayer)
            }
            
            self.player?.play()
            self.setPlayerRate()
            
            NotificationCenter.default.addObserver(self, selector: #selector(self.playerDidFinish), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            
            self.updatePlaybckSpeed(self.playbackSpeed)
        }

        if UIAccessibility.isVoiceOverRunning {
            // VoiceOver ON：メインを指定して実行
            DispatchQueue.main.async {
                setupTask()
            }
        } else {
            // VoiceOver OFF：即座に実行する
            setupTask()
        }
    }
    
    @objc func stopAudio() {

        self.player?.pause()
        self.player?.seek(to: .zero)

        let cleanupTask = {

            
            self.statusObserver?.invalidate()
            self.statusObserver = nil
            self.player?.replaceCurrentItem(with: nil)
            self.player = nil
            self.playerLayer?.removeFromSuperlayer()
            self.playerLayer = nil
            self.guideVoice.process = false
        }

        if UIAccessibility.isVoiceOverRunning {
            // VoiceOver ON：メインを指定して実行
            DispatchQueue.main.async {
                cleanupTask()
            }
        } else {
            // VoiceOver OFF：即座に実行する
            cleanupTask()
        }
    }
    //変更2024/07/07
    //再生速度を設定するメソッド
    func setPlayerRate(){
        //let playbackSpeed = UserDefaults.standard.float(forKey: "reproductionSpeed")
        let adjustedSpeed = (playbackSpeed == 0.0) ? 0.5 : playbackSpeed //初期値を0.5に設定
        player?.rate = adjustedSpeed * 2 //0.5を通常速度とするために2倍
    }
    //InfoViewControllerから呼び出される再生速度変更メソッド
    func updatePlaybckSpeed(_ speed: Float){
        playbackSpeed = speed
        let adjustedSpeed = (speed == 0.0) ? 0.5 : speed //初期値を0.5に設定
        //UserDefaults.standard.setValue(speed, forKey: "reproductionSpeed")
        if let player = player, player.rate != 0{
            player.rate = adjustedSpeed * 2 //0.5を通常速度とするために2倍
        }
    }
        
}
