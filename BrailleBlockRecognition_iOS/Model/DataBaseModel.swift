import UIKit
import CoreData

class DataBaseModel {
    public static let persistentContainer = (UIApplication.shared.delegate as! AppDelegate).persistentContainer
    public let managedContext = persistentContainer.viewContext
    
    public func responseCodeBlockServer(request: URL, completion: @escaping (CodeDict,CodeDict) -> Void) {
        var dstMessage:CodeDict = [:]
        var dstReading:CodeDict = [:]
        
        let task: URLSessionTask = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
            do{
                let responseAllData = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableLeaves) as! [NSDictionary]
    
                for data in responseAllData {
                    let srcCode = data.value(forKey: "code") as! Int
                    let srcAngle = data.value(forKey: "angle") as! Int
                    let srcMessage = data.value(forKey: "message") as! String
                    let srcReading = data.value(forKey: "reading") as? String
                    var srcMessagecategory = data.value(forKey: "messagecategory") as! String
                    
                    //messagecategoryを数字に整形
                    /* ジャンル(messgecategory)対応表
                        一般(normal) : "0"
                        詳細(detail) : "1"
                        避難(evacuation) : "2"
                        専用(exclusive) : "3"
                     */
                    if srcMessagecategory == "normal"{
                        srcMessagecategory = "0"
                    }
                    else if srcMessagecategory == "detail"{
                        srcMessagecategory = "1"
                    }
                    else if srcMessagecategory == "evacuation"{
                        srcMessagecategory = "2"
                    }
                    else if srcMessagecategory == "exclusive"{
                        srcMessagecategory = "3"
                    }
                    else{
                        print("error")
                    }
                    
                    let dataKey = String(srcCode) + String(srcAngle) + srcMessagecategory
                    /*コード＋アングル+メッセージカテゴリーをキーにサーバーからJSON形式で取得したデータをバリューに設定した辞書を作成
                     （オンライン用）*/
                    dstMessage[dataKey] = srcMessage
                    dstReading[dataKey] = srcReading
            
                }
            } catch {
                print(error)
            }
            // CodeBlockControllorのfetchGuideInformation()のguidanceMessage,callMessageに対応
            completion(dstMessage ,dstReading)
            print("オンライン用辞書作成")
        })
        task.resume()
        
    }
    //ここより下オフライン用のプログラム
    public func fetchAllData() -> (CodeDict, CodeDict) {
        var code: [NSInteger] = []
        var angle: [NSInteger] = []
        var message: [NSString] = []
        var reading: [NSString] = []
        var messagecategory: [NSString] = []
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CodeBlock")
        do {
            let myResults = try managedContext.fetch(fetchRequest)

            for myData in myResults {
                code.append(myData.value(forKey: "code") as! NSInteger)
                angle.append(myData.value(forKey: "angle") as! NSInteger)
                message.append(myData.value(forKey: "message") as! NSString)
                reading.append(myData.value(forKey: "reading") as! NSString)
                messagecategory.append(myData.value(forKey: "messagecategory") as! NSString)
            }

        } catch let error as NSError {
            print("\(error), \(error.userInfo)")
        }
        
        return replaceValueInfo(data: (code, angle, message, reading, messagecategory))
    }
    
    private func replaceValueInfo(data: (Array<Int>, Array<Int>, Array<NSString>, Array<NSString>, Array<NSString>))  -> (CodeDict, CodeDict) {
        var argGuidance: CodeDict = [:]
        var argCall: CodeDict = [:]
        
        for i in 0..<data.0.count {
            let key = "\(data.0[i])" + "\(data.1[i])" + "\(data.4[i])"
            argGuidance.updateValue(String(data.2[i]), forKey: key)
            argCall.updateValue(String(data.3[i]), forKey: key)
        }
        //コード＋アングル+メッセージカテゴリーをキーにCoreDataから配列形式で取得したデータをバリューに設定した辞書を作成（オフライン用）
        print("オフライン用辞書作成")
        return (argGuidance, argCall)
    }
    
        
    public func saveAllData(guidace:CodeDict, call:CodeDict) {
        clearAllData()
        for (key, value) in guidace {
            let code = key.prefix(key.count - 2)
            let preangle = key.suffix(2)
            let angle = preangle.prefix(1)
            let messagecategory = key.suffix(1)
            let message = value
            let reading = call[key] ?? ""
            
            let setData = CodeBlock(context: managedContext)
            setData.code = Int32(code) ?? 0
            setData.angle = Int16(angle) ?? 0
            setData.message = message
            setData.reading = reading
            setData.messagecategory = String(messagecategory)
            (UIApplication.shared.delegate as! AppDelegate).saveContext()
        }
    }
    
    private func clearAllData() {
        let entities = DataBaseModel.persistentContainer.managedObjectModel.entities
        entities.compactMap({ $0.name }).forEach(clearDeepObjectEntity)
    }

    private func clearDeepObjectEntity(_ entity: String) {
        let deleteFetch = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: deleteFetch)

        do {
            try managedContext.execute(deleteRequest)
            try managedContext.save()
        } catch {
            print ("There was an error")
        }
    }
}
