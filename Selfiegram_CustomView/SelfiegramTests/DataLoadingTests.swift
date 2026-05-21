import XCTest
@testable import Selfiegram

final class DataLoadingTests: XCTestCase {

    override func setUpWithError() throws {
        // Delete contents of cached directory by listdir() and delete over
        let cacheURL = OverlayManager.cacheDirectoryURL
        // listdir()
        guard let contents = try? FileManager.default.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil, options: [])
            else {
                XCTFail("Failed to list contents of directory \(cacheURL)")
                return
            }
        var complete = true
        for file in contents {
            do {
                try FileManager.default.removeItem(at: file)
            } catch let error {
                NSLog("Test setup: failed to remove item \(file); \(error)")
                complete = false
            }
        }
        if !complete {
            XCTFail("Failed to delete contents of cache")
        }
    }
    
    // test start condition => no test data
    func testNoOverlaysAvailable() {
        let availableOverlays = OverlayManager.shared.availableOverlays()
        XCTAssertEqual(availableOverlays.count, 0)
    }
    
    // Test downloading OverlayInfo from server
    func testGettingOverlayInfo() {
        // similar to "Promise" as download takes long time
        let expectation = self.expectation(description: "Done downloading")
        
        var loadedInfo: OverlayManager.OverlayList?
        var loadedError: Error?
        // parameter is "escape completion function" i.e. call after main function operates
        OverlayManager.shared.refreshOverlays{ (info, error) in
            loadedInfo = info
            loadedError = error
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5.0, handler: nil)
        // Assert
        XCTAssertNotNil(loadedInfo)
        XCTAssertNil(loadedError)
    }
    
    // Test downloading OverlayImages from server
    func testDownloadingOverlays() {
        // similar to "Promise" as download takes long time
        let loadingComplete = self.expectation(description: "Download done")
        var availableOverlays: [Overlay] = []
        OverlayManager.shared.loadOverlayAssets(refresh: true) {
            availableOverlays = OverlayManager.shared.availableOverlays()
            loadingComplete.fulfill()
        }
        waitForExpectations(timeout: 10.0, handler: nil)
        // Assert
        XCTAssertNotEqual(availableOverlays.count, 0)
    }
    // Download first, then check if loading from that cache successful
    func testDownloadedOverlaysAreCached() {
        let downloadingOverlayManager = OverlayManager()
        let downloadExpectation = self.expectation(description: "Data downloaded")
        // start downloading images
        downloadingOverlayManager.loadOverlayAssets(refresh: true) {
            downloadExpectation.fulfill()
        }
        waitForExpectations(timeout: 10.0, handler: nil)
        
        // Simulating OverlayManager starting up by creating a NEW INIT
        let cacheTestOverlayManager = OverlayManager()
        // Assert
        XCTAssertNotEqual(cacheTestOverlayManager.availableOverlays().count, 0)
        XCTAssertEqual(cacheTestOverlayManager.availableOverlays().count, downloadingOverlayManager.availableOverlays().count)
    }
}
