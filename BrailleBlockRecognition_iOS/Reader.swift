import Foundation
import CoreData

class Reader{
    var userDefaults = UserDefaults.standard
    
    var block:[BBlock] = []
    weak var context = (UIApplication.shared.delegate as! AppDelegate)
    weak var ManagedObjectContext = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    let blockFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "BBlock")
    let blockFetch_en = NSFetchRequest<NSFetchRequestResult>(entityName: "BBlock_en")

    let fetchRequest:NSFetchRequest<BBlock> = BBlock.fetchRequest()
    
    /*事前ダウンロード部(出力)
     true   :両方取得
     false  :案内情報のみ取得
     */
    func httpGet(GuideVoice :Bool,language :Bool) {
 
        let url: URL
//        self.resetAllRecords(in:"BBlock")
        if language {
            //日本語データjson
            url = URL(string: "http://18.224.144.136/tenji/get_db2json.py?data=blockmessage")!
        } else {
            //英語データjson
            url = URL(string: "http://18.224.144.136/tenji/get_db2json.py?data=blockmessage_en")!
        }
        
        
        let task: URLSessionTask = URLSession.shared.dataTask(with: url, completionHandler: {(data, response, error) in
            do{
                let Data_I = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableLeaves) as! [NSDictionary]
                let appDelegate: AppDelegate = UIApplication.shared.delegate as! AppDelegate
                
                for data in Data_I{
                    let newBlock = BBlock(context: self.ManagedObjectContext!)
                    newBlock.id = data["id"] as! Int16
                    newBlock.code = data["code"] as! Int32
                    newBlock.angle = data["angle"] as! Int16
                    newBlock.message = (data["message"] as! String)
                    newBlock.messagecategory = (data["messagecategory"] as! String)
                    newBlock.reading = data["reading"] as? String
                    newBlock.mp3 = data["wav"] as? String

        
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                        self.context!.saveContext()
                    })
                }
            } catch {
                print(error)
            }
        })
        
        task.resume()
        
        
        if(GuideVoice){
            //マルチスレッド開始
            OperationQueue().addOperation({ [self] () -> Void in
                
                let predicate = NSPredicate(format: "mp3.length > 0")
                fetchRequest.predicate = predicate
                let fetchData = try! ManagedObjectContext!.fetch(fetchRequest)
                let maxdata = Int(fetchData.count)
                

                for i in 0..<fetchData.count{
                    let mp3 = (fetchData[i] as AnyObject).mp3! as String
                    Audio().writeAudio(mp3: mp3)
                    print(mp3)
                    
                    self.userDefaults.set(i+1, forKey: "nowdata")
                    
                    print(String(i+1) + "/" + String(fetchData.count))
                }
                
                print("end_local")
                self.userDefaults.set(false, forKey: "dlwait")
            })
        }
        else{
            // ここ走る
            self.userDefaults.set(false, forKey: "dlwait")
        }
        return
    }
    
    
    
}
