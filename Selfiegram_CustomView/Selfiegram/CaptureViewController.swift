import UIKit
import AVKit

// the smaller Camera-esque part
class PreviewView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    // set size of <previewLayer> = size of parent <previewView>
    override func layoutSubviews() {
        previewLayer?.frame = self.bounds
    }
    // embed session of streaming inside <layer> of <cameraPreview>
    func setSession(_ session: AVCaptureSession) {
        // we only do this embedding ONCE
        guard self.previewLayer == nil else {
            NSLog("Warning: \(self.description) attempted to set its preview layer more than once. This is not allowed.")
            return
        }
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        // preserve aspect ratio
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        // add <previewLayer> to list of layers in <previewView>
        self.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
        // ensure all layers are laid out
        self.setNeedsLayout()
    }
    // set cameraPreview orientation
    func setCameraRotation(_ angle: CGFloat) {
        guard let connection = previewLayer?.connection, connection
            .isVideoRotationAngleSupported(angle) else {
            return
        }
        connection.videoRotationAngle = angle
    }
}

// The whole Capturing screen
class CaptureViewController: UIViewController {
    // Inform the rest of app that we successfully grabbed an Image
    // - pass Image: successful
    // - pass "nil": user presses "Cancel"
    typealias CompletionHandler = (UIImage?) -> Void
    var completion: CompletionHandler?
    
    @IBOutlet weak var cameraPreview: PreviewView!
    
    let captureSession = AVCaptureSession() // streaming what the camera sees
    let photoOutput = AVCapturePhotoOutput() // yielding selfie image
    // Use rotation system instead of video orientation
    var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    
    // when "Cancel" button was pressed
    @IBAction func close(_ sender: Any) {
        self.completion?(nil)
    }

    @IBAction func takeSelfie(_ sender: Any) {
        guard let videoConnection = photoOutput.connection(with: AVMediaType.video) else {
            NSLog("Failed to get camera connection")
            return
        }
        // use <rotationCoordinator> instead of video orientation
        if let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelCapture, videoConnection
            .isVideoRotationAngleSupported(angle) {
            videoConnection.videoRotationAngle = angle
        }
        // setting .jpeg format
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        // begin capturing photo
        photoOutput.capturePhoto(with: settings, delegate: self) // => will call CaptureViewController::photoOutput(...) in "extension" part
    }
   
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // which device we are seeking => front-side wide-angle-camera
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera],
            mediaType: AVMediaType.video,
            position: AVCaptureDevice.Position.front
        )
        guard let captureDevice = discovery.devices.first else {
            NSLog("No capture devices available.")
            self.completion?(nil)
            return
        }
        // add this device to session
        do {
            try captureSession.addInput(AVCaptureDeviceInput(device: captureDevice))
        } catch let error {
            NSLog("Failed to add camera to capture session: \(error)")
            self.completion?(nil)
        }
        // session captures HD photo
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        captureSession.startRunning()
        // link capture session to Photo output
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
        cameraPreview.setSession(captureSession)
        
        // init rotation coordinator
        rotationCoordinator = AVCaptureDevice.RotationCoordinator(
            device: captureDevice,
            previewLayer: cameraPreview.previewLayer
        )
    }
    
    // when device orientation changes
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelPreview {
            cameraPreview.setCameraRotation(angle)
        }
    }
}

extension CaptureViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            NSLog("Failed to get the photo: \(error)")
            return
        }
        guard let jpegData = photo.fileDataRepresentation(),
              let image = UIImage(data: jpegData) else {
            NSLog("Failed to get image from encoded data")
            return
        }
//        self.completion?(image) // if "self.completion" is "nil", do nothing
        
        // NEW: after capturing photo we move to Edit screen
        self.captureSession.stopRunning()
        self.performSegue(withIdentifier: "showEditing", sender: image)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // get the EditingViewController
        guard let destination = segue.destination as? EditingViewController else {
            fatalError("The destination view controller is not configured correctly.")
        }
        // image to be sent to the next screen
        guard let image = sender as? UIImage else {
            fatalError("Expected to receive an image.")
        }
        // setup the EditingViewController
        destination.image = image
        destination.completion = self.completion 
    }
    
    // purpose: when we move back from EditingViewController we start our camera again
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !self.captureSession.isRunning {
            // .userInitiated: flagging "high level of importance"
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }
}
