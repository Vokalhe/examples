//
//  Hall.swift
//  Profit
//
//  Created by Andrii Rolyk on 02.07.2020.
//  Copyright © 2020 Profit. All rights reserved.
//

import Foundation
import RealmSwift
import SwiftyJSON
import PromiseKit

class Hall: Object {
    
    private static let kBorder = "border"
    private static let kObjects = "objects"

    @objc dynamic public var id: Int = 0
    @objc dynamic public var name: String?
    @objc dynamic public var type_name: String?
    @objc dynamic public var scheme: String?
    @objc dynamic public var pos: Int = 0
    @objc dynamic public var schemeSizeW: Float = 0
    @objc dynamic public var schemeSizeH: Float = 0
    public var parseScheme: [String : Any]?

    override static func ignoredProperties() -> [String] {
        return ["parseScheme"]
    }
    
    static func ==(lhs: Hall, rhs: Hall) -> Bool {
        return lhs.id == rhs.id
    }
    
    class func sync () -> Promise<Void> {
        return HTTPData.getHalls().done { json in
            if  json["result"].exists(),
                let halls = json["result"].array?.first?.array,
                halls.count > 0 {
                for hallJson in halls {
                    var hall = realmDB.objects(Hall.self).filter("id == \(hallJson["id"].intValue)").first
                    
                    if hall == nil {
                        hall = Hall()
                        if  let hall = hall {
                            try! realmDB.safeWrite {
                                realmDB.add(hall)
                            }
                        }
                    }
                    if  let hall = hall {
                        try! realmDB.safeWrite {
                            hall.id = hallJson["id"].intValue
                            hall.name = hallJson["name"].stringValue
                            hall.type_name = hallJson["type_name"].stringValue
                            hall.pos = hallJson["pos"].intValue
                            hall.scheme = ""
                            if let dictionaryObject: [String : Any] = hallJson["scheme"].dictionaryObject {
                                let data =  try JSONSerialization.data(withJSONObject: dictionaryObject,
                                                                       options: JSONSerialization.WritingOptions.prettyPrinted)
                                let convertedString = String(data: data, encoding: String.Encoding.utf8)
                                hall.scheme = convertedString
                            }
                        }
                        
                        if let jsonDict = hallJson["scheme"].dictionary {
                            hall.parseScheme = Hall.parseScheme(dict: jsonDict, hallID: hall.id)
                        }
                    }
                }
            }
        }
    }
    
    //MARK: - Scheme
    public func changeScheme(borderObjects: [BorderObject], isDeleteObject: Bool) {
        self.parseScheme = self.getScheme()
        
        guard var parseScheme = self.parseScheme else {return}
        
        if var borderArrayArray = parseScheme[Hall.kBorder] as? [[BorderObject]] {
            if isDeleteObject {
                var dict = [Int : [BorderObject]]()
                
                for borderArray in borderArrayArray {
                    for border in borderArray {
                        if var array = dict[border.id] {
                            array.append(border)
                            dict.updateValue(array, forKey: border.id)
                        } else {
                            dict.updateValue([border], forKey: border.id)
                        }
                    }
                }
                
                for changeObject in borderObjects {
                    if var array = dict[changeObject.id] {
                        for removeObject in array.filter({ $0.id == changeObject.id && $0.hallModelID == changeObject.hallModelID && $0.x == changeObject.x && $0.y == changeObject.y }) {
                            array.remove(removeObject)
                            dict.updateValue(array, forKey: changeObject.id)
                            
                            try! realmDB.safeWrite {
                                realmDB.delete(removeObject)
                            }
                        }
                    }
                }
                
                var tempArrayArray = [[BorderObject]]()
                for value in dict.values {
                    if value.count > 0 {
                        tempArrayArray.append(value)
                    }
                }
                
                parseScheme.updateValue(tempArrayArray, forKey: Hall.kBorder)
            } else {
                borderArrayArray.append(borderObjects)
                parseScheme.updateValue(borderArrayArray, forKey: Hall.kBorder)
            }
        } else {
            parseScheme.updateValue([borderObjects], forKey: Hall.kBorder)
        }
        
        
        if let hallObjects = parseScheme[Hall.kObjects] as? [HallObject] {
            parseScheme.updateValue(hallObjects, forKey: Hall.kObjects)
        }
        
        let schemeStr = СonstructorManager.shared.convertSchemeToString(scheme: parseScheme)
        
        try! realmDB.safeWrite {
            self.parseScheme = parseScheme
            self.scheme = schemeStr
        }
        
        HTTPData.setHall(lock: false, hall: self)
    }
    //нельзя удалять HallObject с БД так как он необходим для отображения в TableView
    public func changeScheme(changeObject: HallObject, isDeleteObject: Bool) {
        self.parseScheme = self.getScheme()
        
        guard var parseScheme = self.parseScheme else {return}
        
        if var hallObjects = parseScheme[Hall.kObjects] as? [HallObject] {
            for removeObject in hallObjects.filter({ $0.id == changeObject.id }) {
                hallObjects.remove(removeObject)
            }
            if !isDeleteObject {
                hallObjects.append(changeObject)
            }
            
            parseScheme.updateValue(hallObjects, forKey: Hall.kObjects)
        } else {
            parseScheme.updateValue([changeObject], forKey: Hall.kObjects)
        }
        
        
        if let borderObjects = parseScheme["borders"] as? [[BorderObject]] {
            parseScheme.updateValue(borderObjects, forKey: Hall.kBorder)
        }
        
        let schemeStr = СonstructorManager.shared.convertSchemeToString(scheme: parseScheme)
        
        try! realmDB.safeWrite {
            self.parseScheme = parseScheme
            self.scheme = schemeStr
        }
        
        HTTPData.setHall(lock: false, hall: self)
    }
    //MARK: - Getter
    public func getSizeOfScheme() -> CGSize {
        return CGSize.init(width: CGFloat(self.schemeSizeW), height: CGFloat(self.schemeSizeH))
    }
    
    public func getSizeOfSchemeForScale() -> CGSize? {
        var maxW: CGFloat = 400
        var maxH: CGFloat = 400
        let minSize = CGSize.init(width: 400, height: 400)
        
        guard let jsonString = self.scheme else {return minSize}
        guard let dict = JSON.init(parseJSON: jsonString).dictionary else {return minSize}
        
        self.parseScheme = Hall.parseSchemeWithoutCreate(dict: dict, hallID: self.id)
        
        guard let parseScheme = self.parseScheme else {return nil}
        if let borderObjects = parseScheme[Hall.kBorder] as? [[BorderObject]] {
            for borders in borderObjects {
                for border in borders {
                    if CGFloat(border.x) > maxW {
                        maxW = CGFloat(border.x)
                    }
                    if CGFloat(border.y) > maxH {
                        maxH = CGFloat(border.y)
                    }
                }
            }
            
            maxW = maxW < 300 ? maxW + 400 : maxW + 200
            maxH = maxH < 300 ? maxH + 400 : maxH + 200
        }
        
        if let hallObjects = parseScheme[Hall.kObjects] as? [HallObject] {
            for object in hallObjects {
                if CGFloat(object.x) > maxW {
                    maxW = CGFloat(object.x)
                }
                if CGFloat(object.y) > maxH {
                    maxH = CGFloat(object.y)
                }
            }
            
            maxW = maxW < 300 ? maxW + 400 : maxW + 200
            maxH = maxH < 300 ? maxH + 400 : maxH + 200

        }
        
        return CGSize.init(width: maxW, height: maxH)
    }
    
    private func getScheme() -> [String : Any]? {
        guard let jsonString = self.scheme else {return [:]}
        guard let dict = JSON.init(parseJSON: jsonString).dictionary else {return [:]}
        
        return Hall.parseSchemeWithoutCreate(dict: dict, hallID: self.id)
    }
    
    //MARK: - Private Methods
    class private func parseScheme(dict: [String : JSON], hallID: Int) -> [String : Any] {
        var globalDict = [String : Any]()
        
        if let arrayObjects = dict[Hall.kBorder] {
            var borderArraysArray = [[BorderObject]]()
                            
            for borderDict in arrayObjects {
                var borderArray = [BorderObject]()
                
                for borderJSON in borderDict.1.arrayValue {
                    guard let borderJSONDict = borderJSON.dictionary else {continue}
                    guard let lineID = borderJSONDict["id"]?.intValue, let x = borderJSONDict["x"]?.floatValue, let y = borderJSONDict["y"]?.floatValue else {continue}
                    
                    var border = realmDB.objects(BorderObject.self).filter{ $0.id == lineID && $0.hallModelID == hallID && $0.x == x && $0.y == y }.first
                    
                    try! realmDB.safeWrite {
                        if border == nil {
                            border = BorderObject()
                            if  let border = border {
                                realmDB.add(border)
                            }
                        }
                        if let border = border {
                            border.hallModelID = hallID
                            border.id = lineID
                            border.x = borderJSONDict["x"]!.floatValue
                            border.y = borderJSONDict["y"]!.floatValue
                            
                            if borderJSONDict["widthBorder"] == nil {
                                border.widthBorder = 1.0
                            } else {
                                border.widthBorder = borderJSONDict["widthBorder"]?.floatValue == 0 ? 1 : borderJSONDict["widthBorder"]!.floatValue
                            }
                            
                            borderArray.append(border)
                        }
                    }
                }
                
                if borderArray.count > 0 {
                    borderArraysArray.append(borderArray)
                }
            }
            
            if borderArraysArray.count > 0 {
                globalDict.updateValue(borderArraysArray, forKey: Hall.kBorder)
            }
        }
        
        let tablesArrayDB = Tables.get(hall: hallID)
        var objectsArrayDB = [HallObject]()
        
        for table in tablesArrayDB {
            var object = realmDB.objects(HallObject.self).filter{ $0.id == table.id && $0.hallModelID == hallID }.first
            
            try! realmDB.safeWrite {
                if object == nil {
                    object = HallObject()
                    if  let object = object {
                        realmDB.add(object)
                    }
                }
                if  let object = object {
                    object.id = table.id
                    object.type = table.type
                    object.s_type = table.s_type
                    object.seats = table.seats
                    object.name = table.name
                    object.label = table.name
                    object.hallModelID = hallID
                    object.isInstalled = false
                    object.tableId = "\(table.id)"

                    objectsArrayDB.append(object)
                }
            }
        }
        
        if let arrayObjects = dict[Hall.kObjects] {//массив dict для каждого объекта
            for objectDict in arrayObjects {
                let object = objectsArrayDB.filter{ $0.id == objectDict.1["id"].intValue && $0.hallModelID == hallID }.first
                
                if object == nil { continue }
                try! realmDB.safeWrite {
                    if  let object = object {
                        object.angle = objectDict.1["angle"].floatValue
                        object.isInstalled = true
                        object.x = objectDict.1["frame"]["x"].floatValue
                        object.y = objectDict.1["frame"]["y"].floatValue
                        object.width = objectDict.1["frame"]["width"].floatValue
                        object.height = objectDict.1["frame"]["height"].floatValue
                    }
                }
            }
            
            if objectsArrayDB.count > 0 {
                globalDict.updateValue(objectsArrayDB, forKey: Hall.kObjects)
            }
        }
        
        return globalDict
    }
    
    class private func parseSchemeWithoutCreate(dict: [String : JSON], hallID: Int) -> [String : [Any]] {
        var globalDict = [String : [Any]]()
        
        if let arrayArrayObjects = dict[Hall.kBorder] {
            var bordersArrayArray = [[BorderObject]]()
            
            for arrayObjects in arrayArrayObjects {
                var bordersArray = [BorderObject]()
                
                for borderDict in arrayObjects.1.arrayValue {
                    guard let borderJSONDict = borderDict.dictionary else {continue}
                    guard let lineID = borderJSONDict["id"]?.intValue, let x = borderJSONDict["x"]?.floatValue, let y = borderJSONDict["y"]?.floatValue else {continue}
                    
                    let border = realmDB.objects(BorderObject.self).filter{ $0.id == lineID && $0.hallModelID == hallID && $0.x == x && $0.y == y }.first
                    
                    if  let border = border {
                        bordersArray.append(border)
                    }
                }
                
                if bordersArray.count > 0 {
                    bordersArrayArray.append(bordersArray)
                }
            }
            
            if bordersArrayArray.count > 0 {
                globalDict.updateValue(bordersArrayArray, forKey: Hall.kBorder)
            }
        }
        
        if let arrayObjects = dict[Hall.kObjects] {
            var objectsArray = [HallObject]()
            
            for objectDict in arrayObjects {
                let object = realmDB.objects(HallObject.self).filter{ $0.id == objectDict.1["id"].intValue && $0.hallModelID == hallID}.first
                
                if  let object = object {
                    objectsArray.append(object)
                }
            }
            
            if objectsArray.count > 0 {
                globalDict.updateValue(objectsArray, forKey: Hall.kObjects)
            }
        }
        
        return globalDict
    }    
}

class BorderObject: Object {
    @objc dynamic public var id: Int = 0
    @objc dynamic public var x: Float = 0
    @objc dynamic public var y: Float = 0
    @objc dynamic public var hallModelID: Int = 0
    @objc dynamic public var widthBorder: Float = 1
}

class HallObject: Object {
    @objc dynamic public var id: Int = 0
    @objc dynamic public var label: String = ""
    @objc dynamic public var type: String = ""
    @objc dynamic public var x: Float = 0
    @objc dynamic public var y: Float = 0
    @objc dynamic public var width: Float = 0
    @objc dynamic public var height: Float = 0
    @objc dynamic public var angle: Float = 0
    @objc dynamic public var hallModelID: Int = 0
    
    @objc dynamic public var imageData: Data?
    @objc dynamic public var isInstalled: Bool = false
    @objc dynamic public var seats: Int = 0
    @objc dynamic public var name: String?
    @objc dynamic public var s_type: String?
    @objc dynamic public var tableId: String?

    public weak var order: Order?
    public var isShowObject: Bool {
        get {
            return self.tableId == nil ? false : true
        }
    }
    
    override static func ignoredProperties() -> [String] {
        return ["order", "isShowObject"]
    }
    
    public func getImage() -> UIImage? {
        guard let data = self.imageData else {return UIImage(named: "Table4")}
        
        return UIImage(data:data, scale:1.0)
    }
}
