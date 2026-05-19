import UIKit
import CoreLocation

class SelfieListViewController: UITableViewController {
    var selfies: [Selfie] = []
    var pendingImage: UIImage?
    var isWaitingForLocation = false
    var loadingAlert: UIAlertController?
    
    var lastLocation: CLLocation?
    let locationManager = CLLocationManager()
    
    let timeIntervalFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .spellOut
        formatter.maximumUnitCount = 1 // "1 minute", "2 days" etc.
        return formatter
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // load the list of Selfies from the SelfieStore
        // sorted by date (newer first
        do {
            selfies = try SelfieStore.shared.listSelfies()
                .sorted(by: { $0.created > $1.created } )
        } catch let error {
            showError(message: "Failed to load selfies: \(error.localizedDescription)")
        }
        // Button in NavigationBar
        let addSelfieButton = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self, // current ViewController will perform the <action>
            action: #selector(createNewSelfie)) // Objective-C style
        navigationItem.rightBarButtonItem = addSelfieButton
        
        // Location manager
        self.locationManager.delegate = self // locationManager will call "SelfieListViewController" to handle <location>
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }
    
    // number of rows in each section
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return selfies.count
    }
    
    // IndexPath: <Section> number and row number
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let selfie = selfies[indexPath.row]
        // Setup cell label
        cell.textLabel?.text = selfie.title
        // Setup cell "time-ago" label
        if let interval = timeIntervalFormatter.string(from: selfie.created, to: Date()) {
            cell.detailTextLabel?.text = "\(interval) ago"
        } else {
            cell.detailTextLabel?.text = nil
        }
        cell.imageView?.image = selfie.image
        
        return cell
    }
    
    // can a cell at <indexPath> be edited?
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    // choose which style we are allowed to edit
    override func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        if editingStyle == .delete {
            let selfieToRemove = selfies[indexPath.row]
            do {
                try SelfieStore.shared.delete(selfie: selfieToRemove)
                selfies.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .fade)
            } catch {
                let title = selfieToRemove.title
                showError(message: "Failed to delete \(title)")
            }
        }
    }
    
    // pop another ViewController when user taps a row
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedSelfie = selfies[indexPath.row]
        // Create and link to the next ViewController
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let detailVC = storyboard.instantiateViewController(
            withIdentifier: "SelfieDetailViewController"
        ) as? SelfieDetailViewController else {
            return
        }
        // set data in next ViewController
        detailVC.selfie = selectedSelfie
        // push next ViewController
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }
    
    func showError(message: String) {
        // Create alert controller, with the message we receive
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        // Create a button for dismiss action by pressing "OK" => no handler (nil)
        let action = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(action)
        self.present(alert, animated: true, completion: nil)
    }
    
    // location helper
    func requestCurrentLocation() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // request location update
            locationManager.requestLocation()
        case .notDetermined:
            // ask user for permission when unclear we are allowed or not
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            print("Location not allowed")
        @unknown default:
            break
        }
    }
    
    func presentCamera() {
        let imagePicker = UIImagePickerController()
        // if a camera is available, use it; else choose Photo Library
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            imagePicker.sourceType = .camera
            // if front camera is available
            if UIImagePickerController.isCameraDeviceAvailable(.front) {
                imagePicker.cameraDevice = .front
            }
        } else {
            imagePicker.sourceType = .photoLibrary
        }
        // notify to this ViewController when finish
        imagePicker.delegate = self
        // Present image picker
        self.present(imagePicker, animated: true, completion: nil)
    }
    
    @objc func createNewSelfie() {
        // about location authorization
        lastLocation = nil // remove outdated location
        
        let shouldGetLocation = UserDefaults.standard.bool(forKey: SettingsKey.saveLocation.rawValue)
        if shouldGetLocation {
            requestCurrentLocation()
        }
        
        presentCamera()
    }
}

// make TableViewController conform to Protocols (for ImagePicker AND NavigationController)
extension SelfieListViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    // when user presses "Cancel" to dismiss image taking request
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil) // close ImagePicker
    }
    // when user chooses an image
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        // User chooses original image taken OR edits image before confirm
        guard let image = (
            info[.editedImage] as? UIImage ??
            info[.originalImage] as? UIImage
        ) else {
            let message = "Couldn't get a picture from the image picker!"
            showError(message: message)
            return
        }
        // if finish capturing image but <location> information hasn't arrived
        let shouldGetLocation = UserDefaults.standard.bool(forKey: SettingsKey.saveLocation.rawValue)
        if lastLocation != nil || !shouldGetLocation {
            // close image picker (NOTE: dismiss() is async)
            self.dismiss(animated: true) {
                self.newSelfieTaken(image: image)
            }
        } else { // wait for location
            pendingImage = image
            isWaitingForLocation = true
            self.dismiss(animated: true) {
                // close image picker (NOTE: dismiss() is async)
                self.showLoading()
            }
            // timeout after 10s
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                if self.isWaitingForLocation {
                    self.finishWaiting()
                }
            }
        }
    }
    
    // called when user select a photo
    func newSelfieTaken(image: UIImage) {
        let newSelfie = Selfie(title: "New Selfie")
        newSelfie.image = image
        
        if let location = self.lastLocation {
            newSelfie.position = Selfie.Coordinate(location: location)
        }
        
        // Save photo
        do {
            try SelfieStore.shared.save(selfie : newSelfie)
        } catch let error {
            showError(message: "Can't save photo: \(error)")
            return
        }
        // Insert saved photo to cached list
        selfies.insert(newSelfie, at: 0)
        // Update TableView
        tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
    }
    
    // some functions for loading manage
    func showLoading() {
        let alert = UIAlertController(title: nil, message: "Getting location..\n\n", preferredStyle: .alert)
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        alert.view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            spinner.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -20)
        ])
        self.present(alert, animated: true)
        loadingAlert = alert
    }
    
    func hideLoading() {
        loadingAlert?.dismiss(animated: true)
        loadingAlert = nil
    }
    
    func finishWaiting() {
        isWaitingForLocation = false
        hideLoading()
        if let image = pendingImage {
            newSelfieTaken(image: image)
            pendingImage = nil
        }
    }
}

// Make TableViewController to conform to location delegate => can handle <location>
extension SelfieListViewController: CLLocationManagerDelegate {
    // when location information arrives
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.lastLocation = locations.last
        if isWaitingForLocation {
            finishWaiting()
        }
    }
    // what happen when location is faulty
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        showError(message: error.localizedDescription)
    }
    // when user clicks "Allow"
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("Authorized")
            manager.requestLocation() // update location info
        case .denied, .restricted:
            print("Denied")
        case .notDetermined:
            break
        @unknown default: break
        }
    }
}
