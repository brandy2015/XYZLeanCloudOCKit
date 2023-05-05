 
import UIKit
import LeanCloudObjc

class WozaiLCUser :NSObject{
    var objectId: String?
    var username: String?
    var trueName: String?
    var friendLists: [String]?
    var avatarId: String?
    var createdAt: Date?
    var updatedAt: Date?
    var emailVerified: Bool?
    var mobilePhoneVerified: Bool?
    var importFromParse: Bool?
    var isBanned: Bool?
    
    
    init(user:LCUser) {
        self.objectId = user["objectId"] as? String
        self.username = user["username"] as? String
        self.trueName = user["TrueName"] as? String
        self.friendLists = user["FriendLists"] as? [String]
//        self.avatarId = user["avatar"]?["id"] as? String
//
//        if let dateString = user["createdAt"]?["iso"] as? String {
//            self.createdAt = ISO8601DateFormatter().date(from: dateString)
//        }

//        if let dateString = user["updatedAt"]?["iso"] as? String {
//            self.updatedAt = ISO8601DateFormatter().date(from: dateString)
//        }

        self.emailVerified = user["emailVerified"] as? Bool
        self.mobilePhoneVerified = user["mobilePhoneVerified"] as? Bool
        self.importFromParse = user["importFromParse"] as? Bool
        self.isBanned = user["isBanned"] as? Bool
    }
    
//    override var descri
    
    override var description: String {
        var str = "WozaiLCUser {"
        str += " objectId: \(objectId ?? "nil"),"
        str += " username: \(username ?? "nil"),"
        str += " trueName: \(trueName ?? "nil"),"
        str += " friendLists: \(friendLists ?? []),"
        str += " avatarId: \(avatarId ?? "nil"),"
        str += " createdAt: \(createdAt?.description ?? "nil"),"
        str += " updatedAt: \(updatedAt?.description ?? "nil"),"
        str += " emailVerified: \(emailVerified?.description ?? "nil"),"
        str += " mobilePhoneVerified: \(mobilePhoneVerified?.description ?? "nil"),"
        str += " importFromParse: \(importFromParse?.description ?? "nil"),"
        str += " isBanned: \(isBanned?.description ?? "nil") }"
        return str
    }
}
//let currentUser = LCUser.current()?.username
//print("currentUser",currentUser)
