import XCTest
@testable import Selfiegram
import UIKit
import CoreLocation

final class SelfieStoreTests: XCTestCase {
    
    // create an Image with text printing on that
    func createImage(text: String) -> UIImage {
        // Start image Context
        UIGraphicsBeginImageContext(CGSize(width: 100, height: 100))
        // Close at the end
        defer {
            UIGraphicsEndImageContext()
        }
        
        // Create a label
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        label.font = UIFont.systemFont(ofSize: 50)
        label.text = text
        label.drawHierarchy(in: label.frame, afterScreenUpdates: true)
        
        // the ! means we either successfully get an image, or we crash
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
    
    func testCreatingSelfie() {
        // Create a Selfie without Image
        let selfieTitle = "Creation Test Selfie"
        let newSelfie = Selfie(title: selfieTitle)
        try? SelfieStore.shared.save(selfie: newSelfie)
        
        // load all current Selfies on disk => must contain out newly created Selfie
        let allSelfies = try! SelfieStore.shared.listSelfies()
        guard let theSelfie = allSelfies.first(where: {$0.id == newSelfie.id}) else {
            XCTFail("Selfies should contain the one we just created")
            return
        }
        XCTAssertEqual(selfieTitle, newSelfie.title)
    }

    func testSavingImages() throws {
        // Create a Selfie WITH image
        let newSelfie = Selfie(title: "Selfie with image test")
        newSelfie.image = createImage(text: "💯")
        try SelfieStore.shared.save(selfie: newSelfie)
        
        // load Image with ImageID and check if exists
        let loadedImage = SelfieStore.shared.getImage(id: newSelfie.id)
        XCTAssertNotNil(loadedImage, "The image should be loaded.")
    }
    
    func testLoadingSelfie() throws {
        // Create a new Selfie without Image
        let selfieTitle = "Test loading selfie"
        let newSelfie = Selfie(title: selfieTitle)
        try SelfieStore.shared.save(selfie: newSelfie)
        
        // Load that newly created Selfie
        let id = newSelfie.id
        let loadedSelfie = SelfieStore.shared.load(id: id)
        
        // Assert
        XCTAssertNotNil(loadedSelfie, "The selfie should be loaded")
        XCTAssertEqual(loadedSelfie?.id, newSelfie.id, "The loaded selfie should have the same ID")
        XCTAssertEqual(loadedSelfie?.created, newSelfie.created, "The loaded selfie should have the same creation date")
        XCTAssertEqual(loadedSelfie?.title, selfieTitle, "The loaded selfie should have the same title")
    }
    
    func testDeletingSelfie() throws {
        // Create a new Selfie without Image
        let newSelfie = Selfie(title: "Test deleting a selfie")
        try SelfieStore.shared.save(selfie: newSelfie)
        
        // Load all Selfies on disk
        let id = newSelfie.id
        let allSelfies = try SelfieStore.shared.listSelfies()
        // delete the new Selfie and check if it's still there
        try SelfieStore.shared.delete(id: id)
        let selfieList = try SelfieStore.shared.listSelfies()
        let loadedSelfie = SelfieStore.shared.load(id: id)
        
        // Assert
        XCTAssertEqual(allSelfies.count-1, selfieList.count, "There should be one less selfie after deletion")
        XCTAssertNil(loadedSelfie, "deleted Selfie should be nil")
    }
    
    func testLocationSelfie() {
        // location of taking selfie
        let location = CLLocation(latitude: -42.8819, longitude: 147.3238)
        // new selfie with image and location
        let newSelfie = Selfie(title: "Location Selfie")
        let newImage = createImage(text: "😘")
        newSelfie.image = newImage
        newSelfie.position = Selfie.Coordinate(location: location)
        // saving selfie with image and location
        do {
            try SelfieStore.shared.save(selfie: newSelfie)
        } catch {
            XCTFail("failed to save the location selfie")
        }
        // load the selfie back from store
        let loadedSelfie = SelfieStore.shared.load(id: newSelfie.id)
        
        // Assert
        XCTAssertNotNil(loadedSelfie?.position)
        XCTAssertEqual(newSelfie.position, loadedSelfie?.position)
    }

}
