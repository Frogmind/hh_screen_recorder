import ReplayKit
import UIKit
import AVKit
import AVFoundation

@available(iOS 15.0, *)
class HighlightManager {
    
    static let shared = HighlightManager()
    
    // Stores when recording started.
    private var recordingStartTime: Date?
    private var lastURL : URL?
    
    // MARK: - Recording
    
    func startHighlight(completion: @escaping (Error?) -> Void) {
        RPScreenRecorder.shared().isMicrophoneEnabled = false
        recordingStartTime = Date()
        RPScreenRecorder.shared().startRecording { err in
            guard err == nil else {
                print("HHRecorder: Error starting recording: \(err.debugDescription)")
                completion(err)
                return
            }
            print("HHRecorder: Started recording.")
            completion(nil)
        }
    }
    
    func endHighlight(completion: @escaping (Error?) -> Void)
    {
        self.recordingStartTime = nil
        lastURL = nil;
        
        if(RPScreenRecorder.shared().isRecording)
        {
            RPScreenRecorder.shared().stopRecording() { preview, error in
                if let error = error {
                    print("Failed to stop recording: \(error.localizedDescription)")
                    completion(error)
                } else {
                    completion(nil)
                    print("HHRecorder: Stopped recording.")
                }
            }
        }
        else
        {
            completion(nil)
        }
    }
    
    func saveHighlight(title: String, duration: Double, timestamps: [Double], completion: @escaping (URL?, Error?) -> Void) {
        
        if(RPScreenRecorder.shared().isRecording)
        {
            let url = URL(fileURLWithPath: NSTemporaryDirectory())
                 .appendingPathComponent("highlight_\(Date().timeIntervalSince1970).mov")
            
            RPScreenRecorder.shared().stopRecording(withOutput: url) { error in
                if let error = error {
                    print("Failed to stop recording: \(error.localizedDescription)")
                    completion(nil, error)
                } else {
                    print("Recording stopped successfully and saved to \(url.path)")
                    self.recordingStartTime = nil
                    self.lastURL = url;
                }
            }
        }
        
        if(lastURL == nil || lastURL!.absoluteString.isEmpty)
        {
            completion(nil, nil)
            return;
        }
       
       
        if !timestamps.isEmpty {
            self.trimAndMerge(videoURL: lastURL!, highlights: timestamps, duration: duration) { mergedURL, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Error merging video: \(error.localizedDescription)")
                        completion(nil, error)
                    } else if let mergedURL = mergedURL {
                        completion(mergedURL, nil)
                    } else {
                        completion(nil, NSError(domain: "highlight", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error during merge"]))
                    }
                }
            }
        } else {
            completion(lastURL!, nil) // No trimming, return raw video
        }
    }
    
    // MARK: - Video Processing
    
    /// Trims segments from the input video for each highlight event and merges them together.
    /// Each highlight event defines an end time (relative to the start of recording)
    /// and a duration (how many seconds before the event time to include).
    ///
    /// For example, if an event is recorded at 15.0 seconds with a duration of 2.0 seconds,
    /// the segment from 13.0 to 15.0 seconds will be extracted.
    ///
    /// - Parameters:
    ///   - videoURL: The URL of the source video.
    ///   - highlights: Array of (time, duration) tuples.
    ///   - completion: Completion handler with the URL of the merged video or an error.
    func trimAndMerge(videoURL: URL,
                      highlights: [Double],
                      duration: Double,
                      completion: @escaping (URL?, Error?) -> Void) {
        
        let asset = AVAsset(url: videoURL)
        let composition = AVMutableComposition()
        
        // Get the video track from the asset.
        guard let assetVideoTrack = asset.tracks(withMediaType: .video).first else {
            completion(nil, NSError(domain: "trimAndMerge", code: 0,
                                    userInfo: [NSLocalizedDescriptionKey: "Video track not found"]))
            return
        }
        
        // Create a composition video track.
        guard let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video,
                                                                      preferredTrackID: kCMPersistentTrackID_Invalid) else {
            completion(nil, NSError(domain: "trimAndMerge", code: 0,
                                    userInfo: [NSLocalizedDescriptionKey: "Unable to add composition video track"]))
            return
        }
        
        // Optionally add audio if available.
        let hasAudio = asset.tracks(withMediaType: .audio).first != nil
        var compositionAudioTrack: AVMutableCompositionTrack? = nil
        if hasAudio {
            compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio,
                                                                 preferredTrackID: kCMPersistentTrackID_Invalid)
        }
        
        var currentTime = CMTime.zero
        let timeScale = asset.duration.timescale
        
        for highlight in highlights {
            let endTime = CMTime(seconds: highlight, preferredTimescale: timeScale)
            let segmentDuration = CMTime(seconds: duration, preferredTimescale: timeScale)
            let startTime = CMTimeSubtract(endTime, segmentDuration)
            let timeRange = CMTimeRange(start: startTime, duration: segmentDuration)
            
            do {
                // Insert the video segment into the composition.
                try compositionVideoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: currentTime)
                
                // Insert audio if available.
                if let audioTrack = asset.tracks(withMediaType: .audio).first,
                   let compAudioTrack = compositionAudioTrack {
                    try compAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: currentTime)
                }
            } catch {
                completion(nil, error)
                return
            }
            
            // Move the insertion point for the next segment.
            currentTime = CMTimeAdd(currentTime, segmentDuration)
        }
        
        // Prepare for export.
        let exportPath = NSTemporaryDirectory() + "mergedVideo.mp4"
        let exportURL = URL(fileURLWithPath: exportPath)
        try? FileManager.default.removeItem(at: exportURL)
        
        guard let exportSession = AVAssetExportSession(asset: composition,
                                                       presetName: AVAssetExportPresetHighestQuality) else {
            completion(nil, NSError(domain: "trimAndMerge", code: 0,
                                    userInfo: [NSLocalizedDescriptionKey: "Unable to create export session"]))
            return
        }
        
        exportSession.outputURL = exportURL
        exportSession.outputFileType = .mp4
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    completion(exportURL, nil)
                case .failed, .cancelled:
                    completion(nil, exportSession.error)
                default:
                    break
                }
            }
        }
    }
}


extension UIApplication {
    
    @available(iOS 15.0, *)
    static func topViewController(base: UIViewController? = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow }
        .first?.rootViewController) -> UIViewController? {
        
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}
