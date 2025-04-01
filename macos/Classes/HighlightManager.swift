import ReplayKit
import AVFoundation
import AVKit

@available(macOS 11.0, *)
class HighlightManager {
    
    static let shared = HighlightManager()
    private let maxBufferDuration: TimeInterval = 15.0
    private let saveSeconds: TimeInterval = 3.0
    
    // A thread-safe serial queue for sample buffer operations.
    private let bufferQueue = DispatchQueue(label: "com.example.HighlightBufferQueue")
    // Circular buffer to store recent CMSampleBuffers (video only in this example).
    private var sampleBuffers: [CMSampleBuffer] = []
    
    // An array to keep track of our exported highlight file URLs.
    private var highlightURLs: [URL] = []
    
    private init() {}
    
    // MARK: - Start Capture
    
    /// Begins screen capture using ReplayKit and stores video sample buffers in a circular buffer.
    func startHighlight() {
        let recorder = RPScreenRecorder.shared()
        recorder.isMicrophoneEnabled = false
        
        do {
            try recorder.startCapture(handler: { [weak self] (sampleBuffer, sampleType, error) in
                guard let self = self else { return }
                if let error = error {
                    print("Capture error: \(error.localizedDescription)")
                    return
                }
                
                // In this example we handle video only.
                if sampleType == .video {
                    self.bufferQueue.async {
                        self.sampleBuffers.append(sampleBuffer)
                        self.trimBufferIfNeeded()
                    }
                }
            }, completionHandler: { error in
                if let error = error {
                    print("Error starting capture: \(error.localizedDescription)")
                } else {
                    print("Screen capture started")
                }
            })
        } catch {
            print("Failed to start capture: \(error.localizedDescription)")
        }
    }
    
    /// Trims the sampleBuffers array so that the total duration does not exceed maxBufferDuration.
    private func trimBufferIfNeeded() {
        guard let firstBuffer = sampleBuffers.first,
              let lastBuffer = sampleBuffers.last else { return }
        
        let firstTime = CMSampleBufferGetPresentationTimeStamp(firstBuffer).seconds
        let lastTime = CMSampleBufferGetPresentationTimeStamp(lastBuffer).seconds
        
        // Remove oldest buffers until the duration is within our limit.
        while !sampleBuffers.isEmpty && (lastTime - CMSampleBufferGetPresentationTimeStamp(sampleBuffers.first!).seconds) > maxBufferDuration {
            sampleBuffers.removeFirst()
        }
    }
    
    // MARK: - Trigger Highlight
    
    /// Exports the last saveSeconds of captured video to a temporary file.
    func triggerHighlight(filename: String = "highlight") {
        bufferQueue.async { [weak self] in
            guard let self = self, let lastBuffer = self.sampleBuffers.last else {
                print("No sample buffers available for export")
                return
            }
            
            let currentTime = CMSampleBufferGetPresentationTimeStamp(lastBuffer)
            let startTime = CMTimeSubtract(currentTime, CMTimeMakeWithSeconds(self.saveSeconds, preferredTimescale: currentTime.timescale))
            
            // Select sample buffers within our desired time range.
            let buffersToExport = self.sampleBuffers.filter { buffer in
                let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
                return pts >= startTime && pts <= currentTime
            }
            
            self.exportBuffers(buffersToExport, filename: filename)
        }
    }
    
    /// Uses AVAssetWriter to write the provided sample buffers into a .mov file.
    private func exportBuffers(_ buffers: [CMSampleBuffer], filename: String) {
        // Ensure there is at least one valid buffer.
        guard let firstValidBuffer = buffers.first,
              let formatDescription = CMSampleBufferGetFormatDescription(firstValidBuffer) else {
            print("No valid video buffer found for export")
            return
        }
        
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(filename)_\(Date().timeIntervalSince1970).mov")
        
        do {
            let assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(dimensions.width),
                AVVideoHeightKey: Int(dimensions.height)
            ]
            
            let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            writerInput.expectsMediaDataInRealTime = false
            
            if assetWriter.canAdd(writerInput) {
                assetWriter.add(writerInput)
            } else {
                print("Cannot add asset writer input")
                return
            }
            
            assetWriter.startWriting()
            if let firstPTS = buffers.first.map({ CMSampleBufferGetPresentationTimeStamp($0) }) {
                assetWriter.startSession(atSourceTime: firstPTS)
            }
            
            // Write buffers sequentially.
            let inputQueue = DispatchQueue(label: "com.example.AssetWriterInputQueue")
            writerInput.requestMediaDataWhenReady(on: inputQueue) {
                for sampleBuffer in buffers {
                    // Wait until the writer input is ready.
                    while !writerInput.isReadyForMoreMediaData {
                        Thread.sleep(forTimeInterval: 0.01)
                    }
                    writerInput.append(sampleBuffer)
                }
                writerInput.markAsFinished()
                assetWriter.finishWriting {
                    if assetWriter.status == .completed {
                        print("Export succeeded to \(outputURL)")
                        self.bufferQueue.async {
                            self.highlightURLs.append(outputURL)
                        }
                    } else {
                        print("Export failed: \(String(describing: assetWriter.error))")
                    }
                }
            }
        } catch {
            print("Error creating asset writer: \(error.localizedDescription)")
        }
    }
    
    // MARK: - End Highlight and Merge Clips
    
    /// Stops capture, merges all exported highlight clips, and presents a preview.
    func endHighlight() {
        let recorder = RPScreenRecorder.shared()
        recorder.stopCapture { [weak self] error in
            if let error = error {
                print("Error stopping capture: \(error.localizedDescription)")
            } else {
                print("Capture stopped")
                self?.mergeHighlightsAndPresent()
            }
        }
    }
    private func mergeHighlightsAndPresent() {
        let composition = AVMutableComposition()
        guard let compositionTrack = composition.addMutableTrack(withMediaType: .video,
                                                                 preferredTrackID: kCMPersistentTrackID_Invalid) else {
            print("Unable to create composition track")
            return
        }
        
        var currentTime = CMTime.zero
        
        // Append each highlight file
        for highlightURL in highlightURLs {
            let asset = AVAsset(url: highlightURL)
            guard let assetTrack = asset.tracks(withMediaType: .video).first else { continue }
            
            do {
                let timeRange = CMTimeRange(start: .zero, duration: asset.duration)
                try compositionTrack.insertTimeRange(timeRange, of: assetTrack, at: currentTime)
                currentTime = CMTimeAdd(currentTime, asset.duration)
            } catch {
                print("Error inserting time range: \(error.localizedDescription)")
            }
        }
        
        // Export merged video
        let mergedOutputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("merged_highlight_\(Date().timeIntervalSince1970).mov")
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            print("Could not create export session")
            return
        }
        
        exportSession.outputURL = mergedOutputURL
        exportSession.outputFileType = .mov
        exportSession.exportAsynchronously {
            if exportSession.status == .completed {
                print("Merged video exported to \(mergedOutputURL)")
                
                DispatchQueue.main.async {
                    
                }
            } else {
                print("Merged export failed: \(String(describing: exportSession.error))")
            }
        }
    }
 
}
