import Network

enum TypeInfo {
    case guidance
    case call
}

typealias CodeDict = [String: String]

class CodeBlockController {
    private var guidanceMessage:CodeDict = [:]
    private var callMessage:CodeDict = [:]
    
    private let networkMonitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.networkconfig")
    
    private let database = DataBaseModel()
    
    public  let language = NSLocale.preferredLanguages.first?.components(separatedBy: "-").first 
    
    //変更 2024/07/15
    public func fetchGuideInformation(completion: @escaping () -> Void) {
        networkMonitor.pathUpdateHandler = {[weak self] path in
            if path.status == .satisfied {
                print("Connected")
                
                guard let url = self?.checkDeviceLocation() else{
                    return
                }
                self?.database.responseCodeBlockServer(request: url, completion: { guide, call in
                    self?.guidanceMessage = guide
                    self?.callMessage = call
                    DispatchQueue.main.async{
                        completion()
                    }
                })
            } else {
                print("Not Connected")
                self?.setLocalData(data: self?.database.fetchAllData() ?? ([:], [:]))
                DispatchQueue.main.async{
                    completion()
                }
            }
        }
        networkMonitor.start(queue: queue)
    }
    
    private func checkDeviceLocation() -> URL {
        //AWS
        let standard = "https://codedbb.com/tenji/get_db2json.py?data=blockmessage"
        //let standard = "http://18.224.144.136/tenji/get_db2json.py?data=blockmessage"
        //研究室サーバー
            //let standard = "http://202.13.160.89:50003/tenji/get_db2json.py?data=blockmessage"

        switch language {
        case "ja":
            return URL(string: standard)!
        case "en":
            return URL(string: standard + "_en")!
        case "ko":
            return URL(string: standard + "_ko")!
        case "zh":
            return URL(string: standard + "_zh")!
        default:
            return URL(string: standard)!
        }
    }
    // 用はargGuidanceとargCallのこと
    private func setLocalData(data: (CodeDict, CodeDict)){
        guidanceMessage = data.0
        callMessage = data.1
    }
    
    public func saveLocalDataBase() {
        database.saveAllData(guidace: guidanceMessage, call: callMessage)
    }
    
    public func resultValue(key: String, type: TypeInfo) -> (key: String, String?) {
        switch type {
        case .guidance:
            if guidanceMessage.keys.contains(key){
                return (key, guidanceMessage[key])
            }
            else{
                let codeAngle = key.prefix(key.count - 1)
                let key = codeAngle + "0"
                return (String(key), guidanceMessage[String(key)])
            }
        case .call:
            if callMessage.keys.contains(key){
                return (key, callMessage[key])
            }
            else{
                let codeAngle = key.prefix(key.count - 1)
                let key = codeAngle + "0"
                return (String(key), callMessage[String(key)])
            }
        }
    }
    
    public func resultAllInfomation(type: TypeInfo) ->CodeDict {
        switch type {
        case .guidance:
            return guidanceMessage
        case .call:
            return callMessage
        }
    }
}
