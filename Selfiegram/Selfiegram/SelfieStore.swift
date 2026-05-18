import Foundation
import UIKit.UIImage
import CoreLocation.CLLocation

// represent a single selfie image
class Selfie: Codable {
    let created: Date
    let id: UUID
    var title = "New Selfie!"
    
    struct Coordinate: Codable, Equatable {
        var latitude: Double
        var longitude: Double
        
        var location: CLLocation {
            get {
                return CLLocation(latitude: self.latitude, longitude: self.longitude)
            }
            set {
                self.latitude = newValue.coordinate.latitude
                self.longitude = newValue.coordinate.longitude
            }
        }
        
        init(location: CLLocation) {
            self.latitude = location.coordinate.latitude
            self.longitude = location.coordinate.longitude
        }
        
        // Operator==
        public static func == (lhs: Selfie.Coordinate, rhs: Selfie.Coordinate) -> Bool {
            return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
        }
    }
    
    var image: UIImage? {
        get {
            return SelfieStore.shared.getImage(id: self.id)
        }
        set {
            try? SelfieStore.shared.setImage(id: self.id, image: newValue)
        }
    }
    
    // Location where image was taken
    var position: Coordinate?
    
    init(title: String) {
        self.title = title
        self.created = Date()
        self.id = UUID()
    }
}

enum SelfieStoreError: Error {
    case cannotSaveImage(UIImage?)
}

// NOTE: Singleton design
final class SelfieStore {
    static let shared = SelfieStore() // this is ONE OBJECT to be Singleton
    
    // dictionary mapping <image id> => <image>
    private var imageCache: [UUID:UIImage] = [:]
    // computed property; where our app stores data (i.e. its "Documents" folder)
    var documentsFolder: URL {
        return FileManager.default.urls(
            for: .documentDirectory, // an enum in class <FileManager>
            in: .allDomainsMask
        ).first!
    }
    
    // Get image by ID; will cached for future search
    // (nil if fails)
    func getImage(id: UUID) -> UIImage? {
        // if requested image is already on cache
        if let image = imageCache[id] {
             return image
        }
        // get that image and image
        let imageURL = documentsFolder.appendingPathComponent("\(id.uuidString)-image.jpg")
        guard let imageData = try? Data(contentsOf: imageURL) else {
            return nil
        }
        guard let image = UIImage(data: imageData) else {
            return nil
        }
        // store image in cache
        imageCache[id] = image
        return image
    }
    
    // Save image to disk
    func setImage(id: UUID, image: UIImage?) throws {
        let fileName = "\(id.uuidString)-image.jpg"
        let destinationURL = self.documentsFolder.appendingPathComponent(fileName)
        
        // we have <UIImage> to work with
        if let image = image {
            // <UIImage> => binary data
            guard let data = image.jpegData(compressionQuality: 0.9) else {
                throw SelfieStoreError.cannotSaveImage(image)
            }
            // binary data => file 123-image.jpg
            try data.write(to: destinationURL)
        } else {
            // set <image>=<nil> means we want to remove image
            try FileManager.default.removeItem(at: destinationURL)
        }
        // cache in memory OR remove from cache (by setting to <nil>)
        imageCache[id] = image
    }
    
    // Return a list of Selfie objects loaded from disk
    // (throw error if fails)
    func listSelfies() throws -> [Selfie] {
        // list of files; in binary form
        let contents = try FileManager.default.contentsOfDirectory(
            at: self.documentsFolder,
            includingPropertiesForKeys: nil
        )
        
        return try contents.filter { $0.pathExtension == "json" } // closure; filters .json files (binary)
            .map { try Data(contentsOf: $0) } // each .json (binary) is converted to .json <Data>
            .map { try JSONDecoder().decode(Selfie.self, from: $0) } // convert .json <Data> to <Selfie> object
    }
    
    // Delete a selfie and its image (forward to delete(ID) function)
    func delete(selfie: Selfie) throws {
        try delete(id: selfie.id)
    }
    
    // Delete a selfie and its image (with ID)
    func delete(id: UUID) throws {
        let selfieDataFileName = "\(id.uuidString).json"
        let imageFileName = "\(id.uuidString)-image.jpg"
        
        let selfieDataURL = self.documentsFolder.appendingPathComponent(selfieDataFileName)
        let imageURL = self.documentsFolder.appendingPathComponent(imageFileName)
        
        // Remove both <json> and <jpg>
        if FileManager.default.fileExists(atPath: selfieDataURL.path) {
            try FileManager.default.removeItem(at: selfieDataURL)
        }
        if FileManager.default.fileExists(atPath: imageURL.path) {
            try FileManager.default.removeItem(at: imageURL)
        }
        // Wipe that ID from cache if it's there
        imageCache[id] = nil
    }
    
    // Load Selfie with ID, from disk (nil if Selfie not exists)
    func load(id: UUID) -> Selfie? {
        let dataFileName = "\(id.uuidString).json" // Selfie (json binary)
        let dataURL = self.documentsFolder.appendingPathComponent(dataFileName)
        
        // convert <json binary> to <json Data>
        // then <json Data> to <Selfie>
        if let data = try? Data(contentsOf: dataURL),
            let selfie = try? JSONDecoder().decode(Selfie.self, from: data) {
            return selfie
        } else {
            return nil
        }
    }
    
    // Save Selfie to disk (throw if not success)
    func save(selfie: Selfie) throws {
        // convert <Selfie> to <json Data>
        let selfieData = try JSONEncoder().encode(selfie)
        let fileName = "\(selfie.id.uuidString).json"
        let destinationURL = self.documentsFolder.appendingPathComponent(fileName)
        
        try selfieData.write(to: destinationURL)
    }
}
