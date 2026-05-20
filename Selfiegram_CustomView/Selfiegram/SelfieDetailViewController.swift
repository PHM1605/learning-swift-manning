import UIKit
import MapKit

class SelfieDetailViewController: UIViewController {
    var selfie: Selfie? {
        didSet {
            // update the view
            configureView()
        }
    }
    
    @IBOutlet weak var selfieNameField: UITextField!
    @IBOutlet weak var dateCreatedLabel: UILabel!
    @IBOutlet weak var selfieImageView: UIImageView!
    @IBOutlet weak var mapview: MKMapView!
    
    @IBAction func sharedSelfie(_ sender: Any) {
        guard let image = self.selfie?.image else {
            // if load image failed
            let alert = UIAlertController(
                title: "Error",
                message: "Unable to share selfie without an image",
                preferredStyle: .alert
            )
            let action = UIAlertAction(title: "OK", style: .default, handler: nil)
            alert.addAction(action)
            self.present(alert, animated: true, completion: nil)
            return
        }
        // share activity
        let activity = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil)
        self.present(activity, animated: true, completion: nil)
    }
    
    // closure; to show when the selfie is taken
    let dateFormatter = { () -> DateFormatter in
        let d = DateFormatter()
        d.dateStyle = .short
        d.timeStyle = .short
        return d
    }()
    
    @IBAction func doneButtonTapped(_ sender: Any) {
        self.selfieNameField.resignFirstResponder() // to tell event not flowing through component tree
        guard let selfie = selfie else { return }
        // ensure that we have text in the field
        guard let text = selfieNameField?.text else { return }
        // update <selfie> and save
        selfie.title = text
        try? SelfieStore.shared.save(selfie: selfie)
    }
    
    @IBAction func expandMap(_ sender: Any) {
        if let coordinate = self.selfie?.position?.location {
            let options = [
                MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: coordinate.coordinate),
                MKLaunchOptionsMapTypeKey: NSNumber(value: MKMapType.mutedStandard.rawValue)
            ]
            let placemark = MKPlacemark(coordinate: coordinate.coordinate, addressDictionary: nil)
            let item = MKMapItem(placemark: placemark)
            item.name = selfie?.title
            item.openInMaps(launchOptions: options)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
    }
    
    func configureView() {
        // make sure we have the selfie
        guard let selfie = selfie else { return }
        // make sure we have all <outlet>s
        guard let selfieNameField = selfieNameField, let selfieImageView = selfieImageView, let dateCreatedLabel = dateCreatedLabel, let mapview = mapview else {
            return
        }
        // start setup
        selfieNameField.text = selfie.title
        dateCreatedLabel.text = dateFormatter.string(from: selfie.created)
        selfieImageView.image = selfie.image
        
        // show map
        if let position = selfie.position {
            print("Has position: \(position)")
            mapview.setCenter(position.location.coordinate, animated: false)
            mapview.isHidden = false
        } else {
            print("No position found")  // ← or this?
        }
    }
    
}
