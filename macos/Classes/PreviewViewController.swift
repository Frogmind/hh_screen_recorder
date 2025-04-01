//
//  PreviewViewController.swift
//  Pods
//
//  Created by Inan Evin on 31.3.2025.
//


#if os(macOS)
import Cocoa
import AVKit

class PreviewViewController: NSViewController {
    var videoURL: URL
    var player: AVPlayer!
    var playerView: AVPlayerView!
    
    init(videoURL: URL) {
        self.videoURL = videoURL
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = NSView()
        self.view.wantsLayer = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up AVPlayerView
        player = AVPlayer(url: videoURL)
        playerView = AVPlayerView(frame: view.bounds)
        playerView.autoresizingMask = [.width, .height]
        playerView.player = player
        view.addSubview(playerView)
        
        // Save button
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveTapped))
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(saveButton)
        
        // Discard button
        let discardButton = NSButton(title: "Discard", target: self, action: #selector(discardTapped))
        discardButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(discardButton)
        
        NSLayoutConstraint.activate([
            saveButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -100),
            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 100),
            discardButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -100),
            discardButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -100)
        ])
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        player.play()
    }
    
    @objc func saveTapped() {
        let savePanel = NSSavePanel()
        savePanel.allowedFileTypes = ["mov"]
        savePanel.nameFieldStringValue = "Highlight.mov"
        savePanel.begin { (result) in
            if result == .OK, let url = savePanel.url {
                do {
                    try FileManager.default.copyItem(at: self.videoURL, to: url)
                    self.dismiss(self)
                } catch {
                    print("Save error: \(error)")
                }
            }
        }
    }
    
    @objc func discardTapped() {
        try? FileManager.default.removeItem(at: videoURL)
        self.dismiss(self)
    }
}
#endif
