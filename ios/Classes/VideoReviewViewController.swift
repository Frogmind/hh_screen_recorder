import UIKit
import AVKit

class VideoReviewViewController: UIViewController {
    let videoURL: URL
    let titleText: String
    var playerViewController: AVPlayerViewController?

    init(videoURL: URL, title: String) {
        self.videoURL = videoURL
        self.titleText = title
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // Title label
        let titleLabel = UILabel()
        titleLabel.text = titleText
        titleLabel.textColor = .white
        titleLabel.font = .boldSystemFont(ofSize: 20)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

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

        // Video player
        let playerVC = AVPlayerViewController()
        playerVC.player = AVPlayer(url: videoURL)
        playerVC.showsPlaybackControls = true
        addChild(playerVC)
        view.addSubview(playerVC.view)
        playerVC.didMove(toParent: self)
        self.playerViewController = playerVC

        playerVC.view.translatesAutoresizingMaskIntoConstraints = false

        // Constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            titleLabel.heightAnchor.constraint(equalToConstant: 30),

            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.widthAnchor.constraint(equalToConstant: 240),
            stack.heightAnchor.constraint(equalToConstant: 44),

            playerVC.view.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            playerVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerVC.view.bottomAnchor.constraint(equalTo: stack.topAnchor, constant: -10)
        ])

        playerVC.player?.play()
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
