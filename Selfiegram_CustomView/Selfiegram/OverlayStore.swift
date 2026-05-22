import UIKit.UIImage

// contains names of parts of an Overlay
struct OverlayInformation: Codable {
    let icon: String
    let leftImage: String
    let rightImage: String
}

enum OverlayManagerError: Error {
    case noDataLoaded // cannot download Overlay
    case cannotParseData(underlyingError: Error) // downloaded Overlay but cannot "parse"
}

// Singleton to manage Overlays
final class OverlayManager {
    static let shared = OverlayManager()
    typealias OverlayList = [OverlayInformation]
    private var overlayInfo: OverlayList
    
//     example of overlayList:
//     [{
//         "icon":"eyebrow1-preview.png",
//         "leftImage": "eyebrow1-left.png",
//         "rightImage": "eyebrow1-right.png"
//     }]
    static let downloadURLBase = URL(
        string: "https://raw.githubusercontent.com/thesecretlab/learning-swift-3rd-ed/master/Data/"
    )!
    static let overlayListURL = URL(string: "overlays.json", relativeTo: downloadURLBase)!
//    // to override <overlayListURL> in subclass => use "computed property"
//    class var overlayListURL: URL {
//        return URL(xxx)!
//    }
//    class CustomOverlayManager: OverlayManager {
//        override class var overlayListURL : URL {
//            return URL(yyy)!
//        }
//    }
    
    // Computed properties - where caches of "overlays.json" are stored in local dir
    // .userDomainMask: ~/
    static var cacheDirectoryURL: URL {
        guard let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            fatalError("Cache directory not found! This should not happen!")
        }
        return cacheDirectory
    }
    // "~/cached/overlays.json"
    static var cachedOverlayListURL: URL {
        return cacheDirectoryURL.appendingPathComponent("overlays.json", isDirectory: false)
    }
    // for simultaneous downloads
    private let loadingDispatchGroup = DispatchGroup()
    
    // function to find ONLINE image
    // "https://raw.githubusercontent.com/thesecretlab/learning-swift-3rd-ed/master/Data/eyebrow1-left.png"
    func urlForAsset(named assetName: String) -> URL? {
        return URL(string: assetName, relativeTo: OverlayManager.downloadURLBase)
    }
    // Function to find CACHED image
    // "~/cached/eyebrow1-left.png"
    func cachedURLForAsset(named assetName: String) -> URL? {
        return URL(string: assetName, relativeTo: OverlayManager.cacheDirectoryURL)
    }
    
    init() {
        do {
            // contents of "~/cached/overlays.json" i.e. [{"icon":xxx.jpg, "left":yyy.jpg, "right":zzz.jpg}]
            let overlayListData = try Data(contentsOf: OverlayManager.cachedOverlayListURL)
            self.overlayInfo = try JSONDecoder().decode(OverlayList.self, from: overlayListData) // json format
        } catch {
            self.overlayInfo = [] // when overlays.json hasn't been cached yet
        }
    }
    
    // Overlays that are already in cache
    func availableOverlays() -> [Overlay] {
        // $0 is {"icon":..., "left":..., "right":...}
        return overlayInfo.compactMap { Overlay(info: $0) }
    }
    
    // Download list of OverlayInformation from server
    // @escaping: enclosure ()->Void runs AFTER refreshOverlays() has returned
    func refreshOverlays(
        completion: @escaping (OverlayList?, Error?) -> Void
    ) {
        // call a closure
        URLSession.shared.dataTask(with: OverlayManager.overlayListURL) {
            (data, response, error) in
            // check error first
            if let error = error {
                NSLog("Failed to download \(OverlayManager.overlayListURL): \(error)")
                completion(nil, error)
                return
            }
            // check data OverlayInformation available
            guard let data = data else {
                completion(nil, OverlayManagerError.noDataLoaded)
                return
            }
            // start caching data OverlayInformation
            do {
                try data.write(to: OverlayManager.cachedOverlayListURL)
            } catch let error {
                NSLog("Failed to write data to \(OverlayManager.cachedOverlayListURL); reason: \(error)")
                completion(nil, error)
            }
            // parse OverlayInformation data to JSON
            do {
                let overlayList = try JSONDecoder().decode(OverlayList.self, from: data) // .json of OverlayInformation
                self.overlayInfo = overlayList
                completion(self.overlayInfo, nil)
                return
            } catch let decodeError {
                completion(nil, OverlayManagerError.cannotParseData(underlyingError: decodeError))
            }
        }.resume() // dataTask starts download
    }
    
    // download OverlayImages. If "refresh"=true, update list of Overlays first
    func loadOverlayAssets(
        refresh: Bool = false,
        completion: @escaping () -> Void
    ) {
        if (refresh) {
            self.refreshOverlays(
                // after refresh OverlayInformation, call itself again
                completion: {
                    (overlays, error) in
                    self.loadOverlayAssets(refresh: false, completion: completion)
                }
            )
            return
        }
        // Download OverlayImages from OverlayInfo
        for info in overlayInfo {
            let names = [info.icon, info.leftImage, info.rightImage]
            // 1. where we download image from
            // 2. where we put the image
            typealias TaskURL = (source: URL, destination: URL)
            let taskURLs: [TaskURL] = names.compactMap {
                guard let sourceURL = URL(string: $0, relativeTo: OverlayManager.downloadURLBase) else { return nil }
                guard let destinationURL = URL(string: $0, relativeTo: OverlayManager.cacheDirectoryURL) else {return nil}
                // return TaskURL
                return (source: sourceURL, destination: destinationURL)
            }
            // start downloading images
            for taskURL in taskURLs {
                loadingDispatchGroup.enter()
                URLSession.shared.dataTask(
                    with: taskURL.source,
                    completionHandler: {
                        (data, response, error) in
                        // defer cleaning this task later - just to make sure we don't forget
                        defer { self.loadingDispatchGroup.leave() }
                        // now that we have some data from download
                        guard let data = data else {
                            NSLog("Failed tto download \(taskURL.source): \(error!)")
                            return
                        }
                        // cache that downloaded data
                        do {
                            try data.write(to: taskURL.destination)
                        } catch let error {
                            NSLog("Failed to write to \(taskURL.destination): \(error)")
                        }
                    }
                ).resume() // start downloading session
            }
        }
        // Wait for all downloads to finish then run the completion block
        loadingDispatchGroup.notify(queue: .main) {
            completion()
        }
    }
}

// Container for images of 3 parts of eyebrows
struct Overlay {
    let previewIcon: UIImage
    let leftImage: UIImage
    let rightImage: UIImage
    
    init?(info: OverlayInformation) {
        guard let previewURL = OverlayManager.shared.cachedURLForAsset(named: info.icon), // "~/cached/eyebrow1-preview.png"
              let leftURL = OverlayManager.shared.cachedURLForAsset(named: info.leftImage),
              let rightURL = OverlayManager.shared.cachedURLForAsset(named: info.rightImage)
        else { return nil }
        // load list images from cached paths
        guard let previewImage = UIImage(contentsOfFile: previewURL.path),
              let leftImage = UIImage(contentsOfFile: leftURL.path),
              let rightImage = UIImage(contentsOfFile: rightURL.path)
        else { return nil}
        // init internal vars
        self.previewIcon = previewImage
        self.leftImage = leftImage
        self.rightImage = rightImage
    }
}
