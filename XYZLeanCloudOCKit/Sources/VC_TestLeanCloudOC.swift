  
import UIKit
import LeanCloudObjc

class VC_TestLeanCloudOC: UIViewController {
    
    let userObjectId = "5ef1c5fba9a0420008346509"//赵晶爽 
    let userObjectId2 = "6029e1de379658208361e806"// 刘达
    let userObjectId3 = "58611bae1b69e675fcd01faa"//子豪
    
    
    @IBAction func BTN_Accept(_ sender: Any) {
        AcceptFriendRequest()
    }
    
    @IBAction func BTN_RequestFriends(_ sender: Any) {
        requestFriend(userObjectId: userObjectId2)
    }
    
    @IBAction func BTN_FriendList(_ sender: Any) {
        FindAllFriendLists()
    }
     
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
 
    }
    
   
    //    删除好友
    func unfollow(id:String){
        LCUser.current()?.unfollow(id) { (succeeded, error) in
            // 处理结果
            print("unfollow succeeded",succeeded,"unfollow error",error as Any)
        }
    }
    
    //    修改好友属性
    func ChangeFriendType(){
        let followee = LCObject(className: "_Followee", objectId: "followee objectId")
        followee["remark"] = "丐帮帮主"// 添加新属性
        followee["group"] = "friend" // 更新已有属性
        followee.remove(forKey: "nickname") // 删除已有属性
        followee.saveInBackground { (succeeded, error) in
           
        }
    }
    
    //    -- 查询好友列表  直接使用 Query 查询好友列表，设定 friendStatus=true 即可以查询双向好友。同时还可以使用 skip、limit、include 等，非常方便。
    func FindAllFriendLists()  {
        
        if let query = LCUser.current()?.followeeObjectsQuery() {
            query.whereKey("friendStatus", equalTo: true)
            query.findObjectsInBackground { (objects, error) in
                // 处理结果
                if let FriendX = (objects?.first) as? LCObject{
                    print("objects -------- FriendX  ",FriendX,"error",error as Any)
                     
                    var dict             = [String: Any]()
                    dict["objectId"]     = FriendX.objectId
                    dict["createdAt"]    = FriendX.createdAt
                    dict["updatedAt"]    = FriendX.updatedAt
                    dict["group"]        = FriendX["group"]
                    dict["followee"]     = FriendX["followee"] as? LCUser
                    dict["friendStatus"] = FriendX["friendStatus"] as? Int ?? 0
                    
                    
                    if let user = FriendX["user"] as? LCObject {
                        dict["userID"] = user.objectId
                        dict["user"] = user
                    }
                    print("dict",dict)
                    
                    if let user = dict["user"] as? LCUser{
                        print("Wozai_User1_Original",user)
                    }
                    if let followee = dict["followee"] as? LCUser{
                        //                        print("followee",followee)
                        let WozaiLCUserX = WozaiLCUser(user: followee)
                        print("WozaiLCUserX.objectId",WozaiLCUserX.objectId as Any)
                        print("WozaiLCUser",WozaiLCUserX)
                    }
                }
            }
        }
    }
    
    func DeclineFriendRequest(){
        let query = LCFriendshipRequest.query()
        query.findObjectsInBackground { (objects, error) in
            if let requests = objects as? [LCFriendshipRequest], error == nil {
                for request in requests {
                    // 拒绝
                    LCFriendship.declineRequest(request) { (succeeded, error) in
                        // 处理结果
                    }
                }
            }
        }
    }
    
    
    //      --  接受好友申请
    func AcceptFriendRequest(){
        let query = LCFriendshipRequest.query()
        query.findObjectsInBackground { (objects, error) in
            if let requests = objects as? [LCFriendshipRequest], error == nil {
                for request in requests {
                    
                   
                    print("request------",request)
                    // 接受
//                    LCFriendship.accept(request) { succeeded, error in
//                        // 处理结果
//                        print("succeeded",succeeded,"error",error)
//                    }
                    
                    let attributes = ["group": "sport"]
                    LCFriendship.accept(request, attributes: attributes) { succeeded, error in
                        // 处理结果
                        print("succeeded",succeeded,"error",error as Any)
                    }
                }
            }
        }
    }
    
    //----  查询好友申请 -- 用户上线登录后，可以立刻查询有谁向自己发起了好友申请：
    func LCFriendshipRequestxx(){
        let query = LCFriendshipRequest.query()
        query.findObjectsInBackground { (objects, error) in
            // 处理结果
            print("objects",objects as Any,error as Any)
        }
    }

    func requestFriend(userObjectId:String)  {
        let attributes = ["group": "sport"]
        LCFriendship.request(withUserId: userObjectId, attributes: attributes) { (succeeded, error) in
            if succeeded {
                // 好友请求发送成功
                print("succeeded",succeeded)
            } else {
                // 好友请求发送失败
                print(error as Any)
            }
        }
    }
    
    //---- 一次性获取粉丝和关注列表
    func follower_And_ee(){
        LCUser.current()?.getFollowersAndFollowees({ backdata, error in
            print("getFollowersAndFollowees",backdata as Any)
            print("error",error as Any)
        })
    }
    
    //---- 查询我的粉丝
    func followerQuery(){
        let query = LCUser.followerQuery(LCUser.current()?.objectId ?? "")
        query.includeKey("follower")
        query.findObjectsInBackground { backdata, error in
            print("follower",backdata as Any)
            print("error",error as Any)
        }
    }
    
    //----  查询我关注的人
    func followeeQuery(){
        let query = LCUser.followeeQuery(LCUser.current()?.objectId ?? "")
        query.includeKey("followee")
        query.findObjectsInBackground { backdata, error in
            print("followee",backdata as Any)
            print("error",error as Any)
        }
    }
    
    //---- 取消关注的人
    func unfollow(userObjectId:String)  {
        LCUser.current()?.unfollow(userObjectId, andCallback: { succeeded, error in
            print("succeeded",succeeded)
            print("error",error as Any)
        })
    }
    
    //---- 关注人
    func follow(userObjectId:String)  {
        LCUser.current()?.follow(userObjectId, andCallback: { succeeded, error in
            print("succeeded",succeeded)
            print("error",error as Any)
        })
    }
    
    //并不成功
    func LiveQueryForFriends(){
        
        
//        let query = AVQuery(className: "_FriendshipRequest")
//        query.whereKey("user", equalTo: AVUser.current())
//        query.subscribe().then { subscription in
//            subscription.on("update") { request in
//                if let status = request["status"] as? String,
//                   let friendId = request["friend"].id as? String {
//                    if status == "accepted" {
//                        print("\(friendId) 通过了我的好友申请")
//                    } else if status == "declined" {
//                        print("\(friendId) 拒绝了我的好友申请")
//                    }
//                }
//            }
//        }
//
//
//        do {
//            let query = LCQuery(className: "_FriendshipRequest")
//            self.liveQuery = try LiveQuery(query: query, eventHandler: { (liveQuery, event) in })
//            self.liveQuery.subscribe { (result) in
//                switch result {
//                case .success:
//                    break
//                case .failure(error: let error):
//                    print(error)
//                }
//            }
//        } catch {
//            print(error)
//        }
        
         

//        const query = new AV.Query('_FriendshipRequest');
//        query.equalTo('friend', AV.User.current());
//        query.equalTo('status', 'pending');
//        query.subscribe().then((subscription) => {
//          subscription.on('create', (request) => {
//            console.log(`${request.get('user').id} 申请添加我为好友`);
//          });
//        });
        
//        let query = LCQuery(className: "_FriendshipRequest")
//        query.whereKey("friend", equalTo: LCUser.current())
////        query.whereKey("status", equalTo: "pending")
//
//        let liveQuery = LCLiveQuery(query: query)
//
//        liveQuery.subscribe { succeeded, error in
//            print("_FriendshipRequest succeeded",succeeded,"error",error)
//        }
//        let liveQuery = try LiveQuery(query: query, eventHandler: { (liveQuery, event) in })
        
        
    }
    
    
}

