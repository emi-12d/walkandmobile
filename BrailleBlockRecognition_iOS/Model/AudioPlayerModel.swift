import AVFoundation

protocol AudioPlayerDelegate: AnyObject {
    func didFinishReading()
    // どこで呼んでいるかわからない、
    func didFinishPlaying()
    func playerDidFinishPlaying(notification: Notification)
}

class AudioPlayerModel: NSObject {
    weak var delegate: AudioPlayerDelegate?
    private var audioPlayer = AVAudioPlayer()
    private let textToSpeech = AVSpeechSynthesizer()
   // private let initMessage = NSLocalizedString("Verification", comment: "")
    public var process = false

    //var alreadyread = ""
    //var fulltext = ""
    
    private var playbackSpeed: Float = 0.0
    private var delayStartTime: Double = 0.0
    
    public func readGuide(manuscript: String, genre: String, lang: String) {
        //全文取得
        //fulltext = manuscript
        //開始効果音の関数
        beginSoundEffect(genre: genre)

        textToSpeech.delegate = self
        //iPhoneの読み上げ機能を指定している
        let read = AVSpeechUtterance(string: manuscript)
        read.voice = AVSpeechSynthesisVoice(language: lang)
        
        //最新の保存された速度を読み込む
        let savedSpeed = UserDefaults.standard.float(forKey: "reproductionSpeed")
        self.playbackSpeed = (savedSpeed == 0) ? 0.5 : savedSpeed
        
        //読み上げ速度：Min0.1~Max1.0 標準0.5
        read.rate = self.playbackSpeed
        // 案内文を読み上げ
        if UIAccessibility.isVoiceOverRunning{
            DispatchQueue.main.asyncAfter(deadline: .now() + delayStartTime / Double(playbackSpeed)) {
                //self.textToSpeech.speak(read)//ここをコメントアウトすると音声案内が停止する
            }
        }
        else{
            DispatchQueue.main.asyncAfter(deadline: .now() + delayStartTime / Double(playbackSpeed)) {
                //self.textToSpeech.speak(read)//ここをコメントアウトすると音声案内が停止する
            }
        }
        
    }
    
    // 途中で案内文を終了する
    public func stop(){
        textToSpeech.stopSpeaking(at: .immediate)
        process = false
    }
    
    // 再生を一時停止する
    public func pause(){
        if textToSpeech.isSpeaking{
            textToSpeech.pauseSpeaking(at: .immediate)
        }
    }
    
    // 再生を再開する
    public func playback(){
        if textToSpeech.isPaused{
            textToSpeech.continueSpeaking()
        }
    }
    
    // 再生をリピートする(関数名repeat使えんかった)
    public func echo(manuscript: String, lang: String) {
        //fulltext = manuscript
        //alreadyread = ""
        
        let read = AVSpeechUtterance(string: manuscript)
        read.voice = AVSpeechSynthesisVoice(language: lang)
        playbackSpeed = UserDefaults.standard.float(forKey: "reproductionSpeed")
        read.rate = playbackSpeed
        
        textToSpeech.speak(read)
        process = false
    }
    
    // 認識開始の効果音再生
    private func beginSoundEffect(genre: String) {
        var openStartFile = "generalStart"
        // ジャンル別で効果音を変更
        switch genre {
        case "1":
            openStartFile = "detailStart"
        case "2":
            openStartFile = "evacuationStart"
        case "3":
            openStartFile = "exclusiveStart"
        default:
            openStartFile = "generalStart"
        }
        
        if UserDefaults.standard.float(forKey: "reproductionSpeed") != 0.0 {
            playbackSpeed = UserDefaults.standard.float(forKey: "reproductionSpeed")
        } else {
            playbackSpeed = 0.5
        }
        
        delayStartTime = durationEffectSound(fileName: openStartFile)
        playSoundEffect(url: fetchMP3File(file: openStartFile))
    }

    // ローカル内のファイルを取得
    private func fetchMP3File(file: String) -> URL {
        guard let startedPath = Bundle.main.path(forResource: file, ofType: "mp3") else {
            fatalError("Cannot find mp3 file: GuidanceTextHasStartedPlaying")
        }
        return URL(fileURLWithPath: startedPath)
    }
    
    // 効果音(MP3)の再生時間を取得
    private func durationEffectSound(fileName: String) -> Double {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: fetchMP3File(file: fileName))
        } catch {
            fatalError("Error \(error.localizedDescription)")
        }
    
        let effectDuration = Int(audioPlayer.duration)
        // 時間と分を計算
        let min = effectDuration / 60
        let sec = effectDuration % 60
        // 誤差
        let timeError = 0.1
        return Double(min * 60 + sec) + timeError
    }
}

extension AudioPlayerModel: AVAudioPlayerDelegate {
    func playSoundEffect(url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url as URL)
            audioPlayer.delegate = self
            audioPlayer.volume = 1.0
            audioPlayer.play()
        } catch let error as NSError {
            print(error.localizedDescription)
        } catch {
            print("AVAudioPlayer init failed")
        }
    }
    
    //変更 2024/06/28
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        delegate?.didFinishPlaying()
    }
    
}

extension AudioPlayerModel: AVSpeechSynthesizerDelegate {
    // 読み上げ終了時呼ばれる
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        delegate?.didFinishReading()
    }
    
    
    
    
    
    
    /*
     // 一時停止→音声速度ボタン→再開で再生速度変化
     // 文章の切れ目問題が解消できないため不採用？
     // 読み上げ中に呼ばれる
     func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
     // 既読を抽出
     let reading = (utterance.speechString as NSString).substring(with: characterRange)
     alreadyread = alreadyread + reading
     //print(alreadyread)
     }
     // 再開時に呼ばれる
     func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
     //　未読 = 全文　- 既読 (たまにエラー)
     let unread: String = String(fulltext.suffix(fulltext.count - alreadyread.count))
     //読み上げ文差し替え
     stop()
     let read = AVSpeechUtterance(string: unread)
     //再生速度変化
     playbackSpeed = UserDefaults.standard.float(forKey: "reproductionSpeed")
     read.rate = playbackSpeed
     //読み上げ
     textToSpeech.speak(read)
     }
     */
    
    
}
