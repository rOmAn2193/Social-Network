import UIKit
import Firebase
import Alamofire

class FeedVC: UIViewController, UITableViewDelegate, UITableViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate
{

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var postField: MaterialTextField!
    @IBOutlet weak var imageSelectorImage: UIImageView!
    

    var posts = [Post]()
    var imageSeleted = false

    var imagePicker: UIImagePickerController!

    static var imageCache = NSCache()

    override func viewDidLoad()
    {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self

        tableView.estimatedRowHeight = 350
        imageSelectorImage.layer.cornerRadius = 2.0
        imageSelectorImage.clipsToBounds = true

        imagePicker = UIImagePickerController()
        imagePicker.delegate = self

        initObservers()
    }

        func initObservers() {

            DataService.ds.REF_POSTS.observeEventType(.Value, withBlock: { snapshot in

                if let snapshots = snapshot.children.allObjects as? [FDataSnapshot] {
                    self.posts = []
                    for snap in snapshots {
                        print("SNAP:\(snap)")

                        //Clear the array because we are going to add all the objects again

                        if let postDict = snap.value as? Dictionary<String, AnyObject> {
                            let key = snap.key

                            let post = Post(postKey: key, dictionary: postDict)
                            self.posts.append(post)
                        }
                    }

                    self.tableView.reloadData()
                }
            })
            
        }

    func numberOfSectionsInTableView(tableView: UITableView) -> Int
    {
        return 1
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return self.posts.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        let post = posts[indexPath.row]

        if let cell = tableView.dequeueReusableCellWithIdentifier("PostCell") as? PostCell
        {
            cell.request?.cancel()

            var img: UIImage?

            if let url = post.imageUrl
            {
                img = FeedVC.imageCache.objectForKey(url) as? UIImage

            }

            cell.configureCell(post, img:  img)
            return cell
        }
        else
        {
            return PostCell()
        }
    }

    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat
    {

        let post = self.posts[indexPath.row]

        if post.imageUrl == nil
        {
            return 150
        }
        else
        {
            return tableView.estimatedRowHeight
        }
    }

    func imagePickerController(picker: UIImagePickerController, didFinishPickingImage image: UIImage, editingInfo: [String : AnyObject]?)
    {
        imagePicker.dismissViewControllerAnimated(true, completion: nil)
        imageSelectorImage.image = image
        imageSeleted = true
    }


    @IBAction func selectImage(sender: UITapGestureRecognizer)
    {
        presentViewController(imagePicker, animated: true, completion: nil)
    }

    @IBAction func makePost(sender: AnyObject)
    {
        if let txt = postField.text where txt != ""
        {
            if let img = imageSelectorImage.image where imageSeleted == true
            {
                let urlStr = "https://post.imageshack.us/upload_api.php"
                let url = NSURL(string: urlStr)!
                let imgData = UIImageJPEGRepresentation(img, 0.2)!
                let keyData = "37JKPRSWb3a89433e98f03d94537a671e7f938eb".dataUsingEncoding(NSUTF8StringEncoding)!
                let keyJSON = "json".dataUsingEncoding(NSUTF8StringEncoding)!

                Alamofire.upload(.POST, url, multipartFormData: { multipartFormData in

                    multipartFormData.appendBodyPart(data: imgData, name: "fileupload", fileName: "image", mimeType: "image/jpg")
                    multipartFormData.appendBodyPart(data: keyData, name: "key")
                    multipartFormData.appendBodyPart(data: keyJSON, name: "format")

                    }) { encodingResult in

                        switch encodingResult
                        {
                        case .Success(let upload, _, _):
                            upload.responseJSON(completionHandler: { response in
                                if let info = response.result.value as? Dictionary<String, AnyObject>
                                {
                                    if let links = info["links"] as? Dictionary<String, AnyObject>
                                    {
                                        if let imageLink = links["image_link"] as? String
                                        {
                                            print("LINK:\(imageLink)")
                                            self.postToFirebase(imageLink)
                                        }
                                    }
                                }

                            })
                        case .Failure(let error):
                            print(error)
                        }
                }

            }
            else
            {
                self.postToFirebase(nil)
            }
        }
    }

    func postToFirebase(imgUrl: String?)
    {
        var post: Dictionary<String, AnyObject> = [
            "description": postField.text!,
            "likes": 0
        ]
        if imgUrl != nil
        {
            post["imageUrl"] = imgUrl!
        }

        let firebasePost = DataService.ds.REF_POSTS.childByAutoId()
        firebasePost.setValue(post)

        self.postField.text = ""
        imageSelectorImage.image = UIImage(named: "camera")
        imageSeleted = false

        tableView.reloadData()
    }
}

