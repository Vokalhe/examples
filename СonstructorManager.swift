//
//  СonstructorManager.swift
//  Profit
//
//  Created by Viktor on 09.06.2020.
//  Copyright © 2020 Profit. All rights reserved.
//

import Foundation
import UIKit
import RealmSwift

class СonstructorManager {
    static let shared : СonstructorManager = {
        let instance = СonstructorManager()
        return instance
    }()
    
    public func removeObjectHallFromDB(object: HallObject, currentHall: Hall) {
        try! realmDB.safeWrite {
            object.isInstalled = false
        }
        
        currentHall.changeScheme(changeObject: object, isDeleteObject: true)
    }
    
    public func getCurrentLineID(currentHallID: Int) -> Int {
        let array = self.getBordersData(currentHallID: currentHallID)
        let ids = array.map { $0.id }
        
        return ids.max() ?? 0
    }
    
    public func getHallsData() -> [Hall] {
        return Array(realmDB.objects(Hall.self)).filter{ $0.id != 0 && $0.name != nil && $0.pos != 0 && $0.type_name != nil }
    }
    
    public func getBordersData(currentHallID: Int) -> [BorderObject] {
        return Array(realmDB.objects(BorderObject.self)).filter{ $0.hallModelID == currentHallID }
    }
    
    public func getInstalledHallObjectsData(currentHallID: Int) -> [HallObject] {
        return realmDB.objects(HallObject.self).filter{ $0.isInstalled == true && $0.hallModelID == currentHallID }
    }
    
    public func getHallObjectsData(currentHallID: Int) -> [HallObject] {
        return realmDB.objects(HallObject.self).filter{ $0.hallModelID == currentHallID && $0.isInstalled == true }
    }
    
    public func getAllHallObjectsData(currentHallID: Int) -> [HallObject] {
           return realmDB.objects(HallObject.self).filter{ $0.hallModelID == currentHallID }
    }
    
    public func convertToSchemeBordersArray(borders: [[BorderObject]]) -> [[[String : Any]]] {
        var bordersForSend = [[[String : Any]]]()

        for bordersArray in borders {//массив массивов Points
            var lineArray = [[String : Any]]()
            for border in bordersArray {//массив Points
                let pointArray: [String : Any] = ["x": border.x,
                                                  "y": border.y,
                                                  "id": border.id,
                                                  "widthBorder": border.widthBorder == 0 ? 1 : border.widthBorder]
                
                lineArray.append(pointArray)
            }
            
            bordersForSend.append(lineArray)
        }

        return bordersForSend
    }
    
    public func convertToSchemeObjectsArray(objects: [HallObject]) -> [[String : Any]] {
        var objectsForSend = [[String : Any]]()
        
        for object in objects {
            var objectArray = [String : Any]()
            
            if object.id != 999 {
                objectArray = ["id": object.id,
                               "type": object.type,
                               "label": object.label,
                               "frame": ["x": object.x,
                                         "y": object.y,
                                         "width": object.width,
                                         "height": object.height],
                               "angle": object.angle]
                
                objectsForSend.append(objectArray)
            }
        }
        
        return objectsForSend
    }
    
    public func convertSchemeToString(scheme: [String : Any]) -> String {
        var params = [String : [Any]]()
        var borders = [[[String : Any]]]()
        var objectsForSend = [[String : Any]]()
        
        if let hallObjects = scheme["objects"] as? [HallObject] {
            objectsForSend = self.convertToSchemeObjectsArray(objects: hallObjects)
        }
        if let borderObjects = scheme["border"] as? [[BorderObject]] {
            borders = self.convertToSchemeBordersArray(borders: borderObjects)
        }
        
        params.updateValue(borders, forKey: "border")
        params.updateValue(objectsForSend, forKey: "objects")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: params,
                                                      options: .prettyPrinted)
            let str = String(decoding: jsonData, as: UTF8.self)
            
            return str
        } catch {
            print(error.localizedDescription)
        }
        
        return ""
    }
    
    public func getHallObjects(hallID: Int) {
        RestClient.shared.getHallObjects(hallID: hallID) { (objectModels, error) in
            if let objectModels = objectModels {
                var hallObjectsArray = [HallObject]()

                for objectModel in objectModels {
                    var object = realmDB.objects(HallObject.self).filter{ $0.id == objectModel.id && $0.hallModelID == hallID }.first
                    
                    if object == nil {
                        object = HallObject()
                        if let object = object {
                            try! realmDB.safeWrite {
                                realmDB.add(object)
                            }
                        }
                    }
                    
                    if  let object = object {
                        try! realmDB.safeWrite {
                            object.id = objectModel.id
                            object.name = objectModel.name
                            object.type = objectModel.type.raw
                            object.s_type = objectModel.s_type
                            object.seats = objectModel.seats
                            object.hallModelID = hallID

                            if let s_type = object.s_type {
                                let trimmedString = s_type.trimmingCharacters(in: .whitespaces)
                                guard let tempImage = UIImage(named: trimmedString) else {return}
                                object.imageData = tempImage.pngData()
                            }
                        }
                        
                        hallObjectsArray.append(object)
                    }
                }
            } else {
                APPDelegate.showAlert(error: error)
            }
        }
    }
}
