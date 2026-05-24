import UIKit
import Vision 

class EditingViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var optionsStackView: UIStackView!
    
    enum EyebrowType { case left, right; }
    typealias EyebrowPosition = (type: EyebrowType, position: CGPoint)
    enum DetectionResult {
        case error(Error)
        case success([EyebrowPosition])
    }
    enum DetectionError: Error { case noResults }
    // type of closure that "consumes" a DetectionResult
    typealias DetectionCompletion = (DetectionResult) -> Void
    
    // Original image
    var image: UIImage?
    // Image that has been drawn on
    var renderedImage: UIImage?
    // both eyebrows
    var eyebrows: [EyebrowPosition] = []
    var overlays: [Overlay] = []
    // SAME completion handler that our original CaptureViewController uses
    var completion: CaptureViewController.CompletionHandler?
    
    var currentOverlay: Overlay? = nil {
        didSet {
            redrawImage()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // load captured image
        guard let image = image else {
            self.completion?(nil)
            return
        }
        self.image = image
        self.imageView.image = image
        overlays = OverlayManager.shared.availableOverlays()
        for overlay in overlays {
            // create UIView from Overlay images
            let overlayView = OverlaySelectionView(overlay: overlay) {
                print("TAPPED")
                self.currentOverlay = overlay
            }

            optionsStackView.addArrangedSubview(overlayView)
        }
        // add a "Done" button on top right bar
        let addSelfieButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        navigationItem.rightBarButtonItem = addSelfieButton
        
        self.detectEyebrows(image: image, completion: {
            (eyebrows) in
            self.eyebrows = eyebrows // store results of eyebrows at the end
        })
    }
    // when user clicks "done"; return either original OR edited image
    
    // function to check image size before showing on screen (avoid memory crash)
    func printImageMemory(_ image: UIImage?, name: String) {
        // convert UIImage to "metal" image for low-level programming
        guard let cg = image?.cgImage else {
            print("\(name): nil")
            return
        }
        let bytes = cg.bytesPerRow * cg.height
        let mb = Double(bytes) / (1024*1024)
        print("\(name): \(String(format: "%.2f", mb)) MB")
    }
    
    @objc func done() {
        printImageMemory(self.image, name: "Original")
        printImageMemory(self.renderedImage, name: "Rendered")

        let imageToReturn = self.renderedImage ?? self.image
        self.completion?(imageToReturn)
    }
    
    // take image and draw eyebrows over it
    func redrawImage() {
        // ensure we have BOTH image AND overlay
        guard let overlay = self.currentOverlay, let image = self.image else {
            return
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let renderedImage = renderer.image {
            context in
            // draw base image
            image.draw(at: .zero)
            for eyebrow in self.eyebrows {
                let eyebrowImage: UIImage
                switch eyebrow.type {
                case .left:
                    eyebrowImage = overlay.leftImage
                case .right:
                    eyebrowImage = overlay.rightImage
                }
                // "eyebrow-coordinate" is at bottom-right=(0,0), we must convert to normal top-left=(0,0)
                // eyebrow position is given at bottom-right-closed
                var position = CGPoint(x: image.size.width-eyebrow.position.x, y: image.size.height-eyebrow.position.y)
                position.x -= eyebrowImage.size.width / 2.0
                position.y -= eyebrowImage.size.height / 2.0
                // draw
                eyebrowImage.draw(at: position)
            }
        }
        self.renderedImage = renderedImage
        self.imageView.image = renderedImage
    }

    // STEPS: locate landmarks => locate eyebrows from landmarks
    private func locateEyebrowsHandler(
        _ request: VNRequest, // result from "landmark-detection-request"
        imageSize: CGSize,
        completion: DetectionCompletion // take "ResultFlag" and save result OR inform Error
    ) {
        // check if "face" exists or not
        guard let firstFace = request.results?.first as? VNFaceObservation else {
            completion(.error(DetectionError.noResults))
            return
        }
        // average point of ALL landmark points
        func averagePosition(for landmark: VNFaceLandmarkRegion2D) -> CGPoint {
            // landmark points
            let points = landmark.pointsInImage(imageSize: imageSize)
            // add up all points => calculate average point
            var averagePoint = points.reduce(CGPoint.zero, {
                return CGPoint(x: $0.x+$1.x, y: $0.y+$1.y)
            })
            averagePoint.x /= CGFloat(points.count)
            averagePoint.y /= CGFloat(points.count)
            return averagePoint
        }
        // calculate list of eyebrows
        var results: [EyebrowPosition] = []
        // landmark points of left eyebrow
        if let leftEyebrow = firstFace.landmarks?.leftEyebrow {
            let position = averagePosition(for: leftEyebrow)
            results.append((type: .left, position: position))
        }
        if let rightEyebrow = firstFace.landmarks?.rightEyebrow {
            let position = averagePosition(for: rightEyebrow)
            results.append((type: .right, position: position))
        }
        
        completion(.success(results))
    }
    // STEP: detect landmarks from image then call the "completion"
    // => take "ResultFlag" and save result OR inform Error
    func detectFaceLandmarks(image: UIImage, completion: @escaping DetectionCompletion) {
        // result of landmarks detection
        let request = VNDetectFaceLandmarksRequest {
            [unowned self] request, error in
            if let error = error {
                completion(.error(error))
                return
            }
            self.locateEyebrowsHandler(request, imageSize: image.size, completion: completion)
        }
        // Side note: for many images, use "VNSequenceRequestHandler"
        let handler = VNImageRequestHandler(
            cgImage: image.cgImage!,
            orientation: .leftMirrored,
            options: [:]
        )
        do {
            // NOTE: this will call closure with "locateEyebrowsHandler" above as "request" DOES HAVE a closure
            // 1/ fill "request" with landmarks
            // 2/ call "locateEyebrowsHandler" to calculate eyebrows and store in "results"
            // 3/ call "completion(results)"
            try handler.perform([request])
        } catch {
            completion(.error(error))
        }
    }
    
    // completion: save result
    func detectEyebrows(image: UIImage, completion: @escaping ([EyebrowPosition])-> Void) {
        detectFaceLandmarks(image: image) {
            (result) in
            switch result {
            case .error(let error):
                NSLog("Error detecting eyebrows: \(error)")
                completion([])
            case .success(let results):
                completion(results) // save results
            }
        }
    }
}

// what we will add to StackView
class OverlaySelectionView: UIImageView {
    let overlay: Overlay
    
    typealias TapHandler = () -> Void
    let tapHandler: TapHandler
    
    init(overlay: Overlay, tapHandler: @escaping TapHandler) {
        self.overlay = overlay
        self.tapHandler = tapHandler
        super.init(image: overlay.previewIcon)
        // Prepare to add user-interaction-handler
        self.isUserInteractionEnabled = true
        
        // Set user-interaction-handler for this UIView
        let tappedMethod = #selector(OverlaySelectionView.tapped(tap:))
        let tapRecoginizer = UITapGestureRecognizer(target: self, action: tappedMethod)
        self.addGestureRecognizer(tapRecoginizer)
    }
    
    // handler of what happens when user taps
    @objc func tapped(tap: UITapGestureRecognizer) {
        self.tapHandler() // draw eyebrows on image
    }
    
    // this init only requires when this class is initialized from Storyboard
    // => we don't need this as we will add (small) UIView in code
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
