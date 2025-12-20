//
//  CurrentViewController.swift
//  BrailleBlockRecognition_iOS
//
//  Created by Matuiken on R 5/02/01.
//  Copyright © Reiwa 5 matuilab. All rights reserved.
//

import UIKit
import CoreLocation

class CurrentViewController: UIViewController, UIGestureRecognizerDelegate{
    @IBOutlet weak var label2: UILabel!
   
    var str = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setDoubleTapGesture()      //ダブルタップの設定

        // Do any additional setup after loading the view.
        
        self.label2.text = UserDefaults.standard.string(forKey: "str")
        //self.locationInfoLabel.text = locInfo
        
    }   //override func viewDidLoad()の最後のカッコ
        
    //ダブルタップの設定
    func setDoubleTapGesture() {
        let tapGesture: UITapGestureRecognizer = UITapGestureRecognizer(target:self,action: #selector(tapped(_:)))
            tapGesture.delegate = self
            tapGesture.numberOfTapsRequired = 2  // ダブルタップで反応
            self.view.addGestureRecognizer(tapGesture)
        }
    @objc func tapped(_ sender: UITapGestureRecognizer){
        //画面遷移の設定
        let returnViewController = self.storyboard?.instantiateViewController(withIdentifier: "toVC") as! ViewController
                self.present(returnViewController, animated: true, completion: nil)
    }
    
}

