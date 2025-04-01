import UIKit
import AVKit

class VideoReviewViewController: UIViewController {
    let videoURL: URL
    var playerViewController: AVPlayerViewController?

    init(videoURL: URL) {
        self.videoURL = videoURL
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // Video player
        let playerVC = AVPlayerViewController()
        playerVC.player = AVPlayer(url: videoURL)
        playerVC.view.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height - 100)
        playerVC.showsPlaybackControls = true
        addChild(playerVC)
        view.addSubview(playerVC.view)
        playerVC.didMove(toParent: self)
        playerVC.player?.play()
        self.playerViewController = playerVC

        // Buttons
        let discardButton = UIButton(type: .system)
        discardButton.setTitle("Discard", for: .normal)
        discardButton.addTarget(self, action: #selector(discardTapped), for: .touchUpInside)

        let saveButton = UIButton(type: .system)
        saveButton.setTitle("Save", for: .normal)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [discardButton, saveButton])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.widthAnchor.constraint(equalToConstant: 240),
            stack.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    @objc private func discardTapped() {
        try? FileManager.default.removeItem(at: videoURL)
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        let activityVC = UIActivityViewController(activityItems: [videoURL], applicationActivities: nil)
        present(activityVC, animated: true)
    }
}
