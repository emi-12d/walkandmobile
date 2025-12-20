//
//  EvacuationViewController.swift
//  BrailleBlockRecognition_iOS
//
//  Created by Matuiken on R 5/02/01.
//  Copyright © Reiwa 5 matuilab. All rights reserved.
//

import UIKit
import CoreLocation

struct Test1: Codable {
    var latitude: Double
    var longitude: Double
    var name: String
    var capacity: String
    var type: String
    var url: String
}

var Point_distList: [(String, String, Double)] = []

class EvacuationViewController: UIViewController, UIGestureRecognizerDelegate {

    //@IBOutlet weak var label: UILabel!
    @IBOutlet weak var label: UILabel!
    //var str = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setDoubleTapGesture()  //ダブルタップの用意
    
        /// ①プロジェクト内にある"test1.json"ファイルのパス取得
        guard let url = Bundle.main.url(forResource: "test1", withExtension: "json")
        else {
            fatalError("ファイルが見つからない")
        }
        /// ②test1.jsonの内容をData型プロパティに読み込み
        guard let data = try? Data(contentsOf: url) else {
            fatalError("ファイル読み込みエラー")
        }
        /// ③JSONデコード処理
        guard let test1 = try? JSONDecoder().decode([Test1].self, from: data) else{fatalError("JSON読み込みエラー")}
        print(test1[0].latitude)
        print(test1[0].url)
        
        
        let number = test1.count
        
        let LATITUIDE = UserDefaults.standard.double(forKey: "str0")
        let LONGITUDE = UserDefaults.standard.double(forKey: "str1")
        let currentLocation = CLLocation(latitude: LATITUIDE, longitude: LONGITUDE)
        
        for i in (0 ..< number){
            let P1 = CLLocation(latitude: test1[i].latitude, longitude: test1[i].longitude)
            let Distance = P1.distance(from: currentLocation)
            Point_distList.append((test1[i].name, test1[i].capacity, Distance))
            Point_distList.sort(by: {$0.2 < $1.2})
        }
        
        //print(Point_distList)
        
        self.setDoubleTapGesture()      //ダブルタップの設定
        //labelの表示内容
        let distance1 = String(round(Point_distList[0].2))
        let distance2 = String(round(Point_distList[1].2))
        let distance3 = String(round(Point_distList[2].2))
        let distance4 = String(round(Point_distList[3].2))
        let distance5 = String(round(Point_distList[4].2))
        
        let dist1 = "1:  " + Point_distList[0].0 + "     " + Point_distList[0].1 + "\n" + "    距離 " + distance1 + " m \n\n"
        let dist2 = "2:  " + Point_distList[1].0 + "     " + Point_distList[1].1 + "\n" + "    距離 " + distance2 + " m \n\n"
        let dist3 = "3:  " + Point_distList[2].0 + "     " + Point_distList[2].1 + "\n" + "    距離 " + distance3 + " m \n\n"
        let dist4 = "4:  " + Point_distList[3].0 + "     " + Point_distList[3].1 + "\n" + "    距離 " + distance4 + " m \n\n"
        let dist5 = "5:  " + Point_distList[4].0 + "     " + Point_distList[4].1 + "\n" + "    距離 " + distance5 + " m \n\n"
        
        let distInfo = dist1 + dist2 + dist3 + dist4 + dist5
        
        self.label.text = distInfo
    }   //override func viewDidLoad()の最後のカッコ
        
    //ダブルタップの設定
    func setDoubleTapGesture() {
        let tapGesture: UITapGestureRecognizer = UITapGestureRecognizer(target:self,action: #selector(tapped(_:)))
            tapGesture.delegate = self
            tapGesture.numberOfTapsRequired = 2  // ダブルタップで反応
            self.view.addGestureRecognizer(tapGesture)
        }
    @objc func tapped(_ sender: UITapGestureRecognizer){
        
        Point_distList = []     //配列の中身を空にする
        
        //画面遷移の設定
        self.dismiss(animated: true)
        /*let returnViewController = self.storyboard?.instantiateViewController(withIdentifier: "toVC") as! ViewController
        self.present(returnViewController, animated: true, completion: nil)
         */
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

