
//
//  InfoViewController.swift
//  BrailleBlockRecognition_iOS
//
//  Created by RyoNishimura on 2021/10/06.
//  Copyright © 2021 matuilab. All rights reserved.
//

import UIKit

protocol InfoViewDelegate: AnyObject{
    func swtichCamera(ecomode: String)
    func setFontsize()
    
    //変更 2024/07/07
    func updatePlaybackSpeed(_ speed: Float) //再生速度メソッド
}

class InfoViewController: UIViewController,UIGestureRecognizerDelegate {
    
    var previousVCButton: UIBarButtonItem!

    @IBOutlet weak var versionItemLabel: UILabel!
    @IBOutlet weak var speedItemLabel: UILabel!
    @IBOutlet weak var appVersionLabel: UILabel!
    @IBOutlet weak var fontItemLabel: UILabel!
    @IBOutlet weak var fontLabel: UILabel!
    @IBOutlet weak var smallButton: UIButton!
    @IBOutlet weak var mediumButton: UIButton!
    @IBOutlet weak var LargeButton: UIButton!
    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var decelerateButton: UIButton!
    @IBOutlet weak var accelerationButton: UIButton!
    @IBOutlet weak var ecomodeItemLabel: UILabel!
    @IBOutlet weak var ecomodeLabel: UILabel!
    @IBOutlet weak var ecomodeOn: UIButton!
    @IBOutlet weak var ecomodeOff: UIButton!

    var fontsize: String = "Medium"
    //var loadSpeed: Float = 0.5 /*UserDefaults.standard.float(forKey: "reproductionSpeed")*/
    
    //変更 2024/07/21
    var loadSpeed: Float {
        get {
            let speed = UserDefaults.standard.float(forKey: "reproductionSpeed")
            return speed == 0.0 ? 0.5 : speed
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "reproductionSpeed")
            delegate?.updatePlaybackSpeed(newValue)
        }
    }
    
    var ecomode:String = "OFF"

    var infoCodeData: CodeBlockController?
    weak var delegate:InfoViewDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        
        previousVCButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(previousVCButtonTapped(_:)))
        self.navigationItem.rightBarButtonItem = previousVCButton
        
        //変更 2024/07/07
        var loadSpeed = UserDefaults.standard.float(forKey: "reproductionSpeed")
        /*if loadSpeed == 0.5{
            loadSpeed = 0.5
            UserDefaults.standard.setValue(loadSpeed, forKey: "reproductionSpeed")
        }*/
        speedLabel.text = "\(round(loadSpeed*100)/100)"
        
        /*if UserDefaults.standard.float(forKey: "reproductionSpeed") != 0.0 {
            loadSpeed = UserDefaults.standard.float(forKey: "reproductionSpeed")
        }*/
        
        fontItemLabel.text = NSLocalizedString("Fontsize", comment: "")
        fontsize = UserDefaults.standard.string(forKey: "fontsize") ?? ""
        fontLabel.text = NSLocalizedString(fontsize, comment: "")
        
        smallButton.setTitle("S", for: .normal)
        smallButton.titleLabel?.font = UIFont.systemFont(ofSize: 25)
        smallButton.titleLabel?.textAlignment = NSTextAlignment.left
        smallButton.titleLabel?.contentMode = .scaleAspectFit
        smallButton.setTitleColor(.black, for: .normal)
        smallButton.backgroundColor = .secondarySystemFill
        smallButton.layer.borderWidth = 1
        smallButton.layer.cornerRadius = 5
        smallButton.layer.masksToBounds = true
        smallButton.layer.borderColor = UIColor.secondarySystemFill.cgColor
        smallButton.addTarget(self, action: #selector(smallDidTapped), for: .touchDown)
        
        mediumButton.setTitle("M", for: .normal)
        mediumButton.titleLabel?.font = UIFont.systemFont(ofSize: 25)
        mediumButton.titleLabel?.textAlignment = NSTextAlignment.left
        mediumButton.titleLabel?.contentMode = .scaleAspectFit
        mediumButton.setTitleColor(.black, for: .normal)
        mediumButton.backgroundColor = .secondarySystemFill
        mediumButton.layer.borderWidth = 1
        mediumButton.layer.cornerRadius = 5
        mediumButton.layer.masksToBounds = true
        mediumButton.layer.borderColor = UIColor.secondarySystemFill.cgColor
        mediumButton.addTarget(self, action: #selector(mediumDidTapped), for: .touchDown)
        
        LargeButton.setTitle("L", for: .normal)
        LargeButton.titleLabel?.font = UIFont.systemFont(ofSize: 25)
        LargeButton.titleLabel?.textAlignment = NSTextAlignment.left
        LargeButton.titleLabel?.contentMode = .scaleAspectFit
        LargeButton.setTitleColor(.black, for: .normal)
        LargeButton.backgroundColor = .secondarySystemFill
        LargeButton.layer.borderWidth = 1
        LargeButton.layer.cornerRadius = 5
        LargeButton.layer.masksToBounds = true
        LargeButton.layer.borderColor = UIColor.secondarySystemFill.cgColor
        LargeButton.addTarget(self, action: #selector(largeDidTapped), for: .touchDown)
        
        speedLabel.text = String(loadSpeed)
        speedLabel.accessibilityValue = NSLocalizedString("Playback Speed", comment: "")
       
        decelerateButton.setTitle("−", for: .normal)
        decelerateButton.titleLabel?.font = UIFont.systemFont(ofSize: 25)
        decelerateButton.titleLabel?.textAlignment = NSTextAlignment.center
        decelerateButton.titleLabel?.contentMode = .scaleAspectFit
        decelerateButton.setTitleColor(.black, for: .normal)
        decelerateButton.backgroundColor = .secondarySystemFill
        decelerateButton.layer.borderWidth = 1
        decelerateButton.layer.cornerRadius = 5
        decelerateButton.layer.masksToBounds = true
        decelerateButton.layer.borderColor = UIColor.secondarySystemFill.cgColor
        decelerateButton.addTarget(self, action: #selector(decelerateDidTapped), for: .touchDown)
        
        accelerationButton.setTitle("+", for: .normal)
        accelerationButton.titleLabel?.font = UIFont.systemFont(ofSize: 25)
        accelerationButton.titleLabel?.textAlignment = NSTextAlignment.center
        accelerationButton.titleLabel?.contentMode = .scaleAspectFit
        accelerationButton.setTitleColor(.black, for: .normal)
        accelerationButton.backgroundColor = .secondarySystemFill
        accelerationButton.layer.borderWidth = 1
        accelerationButton.layer.cornerRadius = 5
        accelerationButton.layer.masksToBounds = true
        accelerationButton.layer.borderColor = UIColor.secondarySystemFill.cgColor
        accelerationButton.addTarget(self, action: #selector(accelerationDidTapped), for: .touchDown)
        
        appVersionLabel.text = "\(version)"
        appVersionLabel.accessibilityHint = "version"
        
        versionItemLabel.accessibilityHint = "\(version)"
        
        
        speedItemLabel.text = NSLocalizedString("Playback Speed", comment: "")
        speedItemLabel.accessibilityHint = "\(loadSpeed)"
        
        ecomodeItemLabel.text = NSLocalizedString("省電力モード", comment: "")
        ecomode = UserDefaults.standard.string(forKey: "ecomode") ?? ""
       // ecomodeLabel.text = NSLocalizedString(ecomode, comment: "")
        //ecomodeLabel.isHidden = true;//現在の
 
        ecomodeOn.setTitle("ON", for: .normal)
        ecomodeOn.titleLabel?.font = UIFont.systemFont(ofSize: 25)
        ecomodeOn.titleLabel?.textAlignment = NSTextAlignment.left
        ecomodeOn.titleLabel?.contentMode = .scaleAspectFit
        ecomodeOn.setTitleColor(.black, for: .normal)
        ecomodeOn.backgroundColor = .secondarySystemFill
        ecomodeOn.layer.borderWidth = 1
        ecomodeOn.layer.cornerRadius = 5
        ecomodeOn.layer.masksToBounds = true
        ecomodeOn.layer.borderColor = UIColor.secondarySystemFill.cgColor
        ecomodeOn.addTarget(self, action: #selector(ecomodeOnDidTapped), for: .touchDown)
        
        ecomodeOff.setTitle("OFF", for: .normal)
        ecomodeOff.titleLabel?.font = UIFont.systemFont(ofSize: 25)
        ecomodeOff.titleLabel?.textAlignment = NSTextAlignment.left
        ecomodeOff.titleLabel?.contentMode = .scaleAspectFit
        ecomodeOff.setTitleColor(.black, for: .normal)
        ecomodeOff.backgroundColor = .secondarySystemFill
        ecomodeOff.layer.borderWidth = 1
        ecomodeOff.layer.cornerRadius = 5
        ecomodeOff.layer.masksToBounds = true
        ecomodeOff.layer.borderColor = UIColor.secondarySystemFill.cgColor
        ecomodeOff.addTarget(self, action: #selector(ecomodeOffDidTapped), for: .touchDown)
    }
   
    @objc func previousVCButtonTapped(_ sender: UIBarButtonItem) {
        UserDefaults.standard.set(round(loadSpeed*100)/100, forKey: "reproductionSpeed")
        UserDefaults.standard.set(fontsize, forKey: "fontsize")
        UserDefaults.standard.set(ecomode,forKey: "ecomode")
        
        delegate?.setFontsize()
        delegate?.swtichCamera(ecomode: ecomode)
        
        //変更 2024/07/21
        delegate?.updatePlaybackSpeed(loadSpeed)
        
        dismiss(animated: true, completion: nil)
    }
    //小ボタンを押した時の処理
    @objc func smallDidTapped(_ sender : Any) {
        fontsize = "Small"
        fontLabel.text = NSLocalizedString(fontsize, comment: "")
    }
    //中ボタンを押した時の処理
    @objc func mediumDidTapped(_ sender : Any) {
        fontsize = "Medium"
        fontLabel.text = NSLocalizedString(fontsize, comment: "")
    }
    //大ボタンを押した時の処理
    @objc func largeDidTapped(_ sender : Any) {
        fontsize = "Large"
        fontLabel.text = NSLocalizedString(fontsize, comment: "")
    }
    
    //マイナスボタンを押した時の処理
    @objc func decelerateDidTapped(_ sender : Any) {
        
        //変更 2024/07/07
        var loadSpeed = UserDefaults.standard.float(forKey: "reproductionSpeed")
        if loadSpeed > 0.1{
            loadSpeed -= 0.10
            loadSpeed = max(0.1, loadSpeed) //最低値を0.1に制限
            speedLabel.text = "\(round(loadSpeed*100)/100)"
            UserDefaults.standard.setValue(loadSpeed, forKey: "reproductionSpeed") //再生速度を保存
            delegate?.updatePlaybackSpeed(loadSpeed) //変更を通知
        }
        
        /*if loadSpeed > 0.1{
            loadSpeed -= 0.10
            speedLabel.text = "\(round(loadSpeed*100)/100)"
        }*/
    }
    //プラスボタンを押した時の処理
    @objc func accelerationDidTapped(_ sender : Any) {
        
        //変更 2024/07/07
        var loadSpeed = UserDefaults.standard.float(forKey: "reproductionSpeed")
        if loadSpeed < 1.5{
            loadSpeed += 0.10
            loadSpeed = min(1.5, loadSpeed) //最大値を1.5に制限 //変更 2024/07/28 速度の最大値を1.5に変更
            speedLabel.text = "\(round(loadSpeed*100)/100)"
            UserDefaults.standard.setValue(loadSpeed, forKey: "reproductionSpeed") //再生速度を保存
            delegate?.updatePlaybackSpeed(loadSpeed) //変更を通知
        }
        
        /*if loadSpeed < 1.0{
            loadSpeed += 0.10
            speedLabel.text = "\(round(loadSpeed*100)/100)"
        }*/
    }
    
    //ONボタンを押した時の処理
    @objc func ecomodeOnDidTapped(_ sender: Any) {
        ecomode = "ON"
        ecomodeLabel.text = NSLocalizedString(ecomode, comment: "")
        
        alertEcomodeOn(title: NSLocalizedString("Power saving mode is turned on.", comment: ""), message: NSLocalizedString("After pressing the done button, press and hold the screen.", comment: ""))
    }
    //省電力モードをONの説明文をポップアップ
    func alertEcomodeOn(title:String, message:String) {
        var alertController: UIAlertController!
        
        alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true)
    }
    
    //OFFボタンを押した時の処理
    @objc func ecomodeOffDidTapped(_ sender: Any) {
        ecomode = "OFF"
        ecomodeLabel.text = NSLocalizedString(ecomode, comment: "")
    }
    //ダウンロードボタンを押した時の処理
    @IBAction func saveDidTapped(_ sender: Any) {
        guard let setData = infoCodeData else { return }
        setData.saveLocalDataBase() //案内文だけダウンロード
        
        alertDownloadCompleted(title: NSLocalizedString("Latest data", comment: ""),
              message: NSLocalizedString("The latest data could be installed.", comment: ""))
    }
    //ダウンロード完了のポップアップ
    func alertDownloadCompleted(title:String, message:String) {
        var alertController: UIAlertController!
        
        alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true)
    }

}
