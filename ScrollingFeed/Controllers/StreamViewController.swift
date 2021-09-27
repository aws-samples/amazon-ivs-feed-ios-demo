//
//  StreamViewController.swift
//  StreamViewController
//
//  Created by Uldis Zingis on 23/09/2021.
//  Copyright © 2021 Twitch. All rights reserved.

import UIKit
import AmazonIVSPlayer
import SpriteKit

protocol StreamDelegate {
    func presentError(_ error: Error, componentName: String)
    func presentAlert(_ message: String, componentName: String)
    func didTapShare(_ items: [Any])
}

class StreamViewController: UIViewController {

    private let dateFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    // MARK: IBOutlet

    @IBOutlet private var playerView: IVSPlayerView!
    @IBOutlet private var bufferView: UIView!
    @IBOutlet private var bufferSpinnerView: LoadingIndicatorView!
    @IBOutlet private var muteButton: UIButton!
    @IBOutlet private var detailsView: UIView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var avatarImageView: UIImageView!
    @IBOutlet private var usernameLabel: UILabel!
    @IBOutlet private var onlineTimerLabel: UILabel!
    @IBOutlet private var shareButton: UIButton!
    @IBOutlet private var likeButton: UIButton!
    @IBOutlet private var topGradientView: UIView!

    // MARK: IBAction

    @IBAction private func didTapMute(_ sender: Any) {
        if let player = player {
            toggleMuteStatus(!player.muted)
        }
    }

    @IBAction private func didTapLike(_ sender: Any) {
        let heartSize: CGFloat = 35
        let heart = HeartView(frame: CGRect(x: 0, y: 0, width: heartSize, height: heartSize))
        detailsView.addSubview(heart)
        heart.center = likeButton.center
        heart.animateInView(view: detailsView)
    }

    @IBAction private func didTapShare(_ sender: Any) {
        if let streamUrl = streamUrl, let watchUrl = URL(string: "https://ivs.rocks/live#\(streamUrl.absoluteString)") {
            delegate?.didTapShare([watchUrl])
        }
    }

    @objc private func didTapPlayerView() {
        player?.state == .playing ? player?.pause() : player?.play()
    }

    // MARK: Application Lifecycle

    @objc private func applicationDidEnterBackground(notification: Notification) {
        if player?.state == .playing || player?.state == .buffering {
            pausePlayback()
        }
    }

    @objc private func applicationWillEnterForeground(notification: Notification) {
        startPlayback()
    }

    private func addApplicationLifecycleObservers() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidEnterBackground(notification:)),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector:
                                                #selector(applicationWillEnterForeground(notification:)),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
    }

    private func removeApplicationLifecycleObservers() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    // MARK: View setup

    private var delegate: StreamDelegate?
    private(set) var stream: Stream?
    private var streamUrl: URL?
    private var gradientTop: CAGradientLayer?
    private var gradientBottom: CAGradientLayer?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setup()
        startPlayback()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        toggleMuteStatus(player?.muted ?? true)
    }

    func setup(_ stream: Stream, delegate: StreamDelegate) {
        self.delegate = delegate
        self.stream = stream
    }

    private func setup() {
        guard let stream = stream else { return }
        titleLabel.text = stream.metadata.streamTitle
        usernameLabel.text = stream.metadata.userName
        onlineTimerLabel.text = "Started \(durationString(since: stream.streamInfo.startTime)) ago"
        bufferSpinnerView.endColor = UIColor.white
        toggleMuteStatus(false)
        rotateLoadingView()

        if let avatarUrl = URL(string: stream.metadata.userAvatarUrl) {
            getImageFrom(avatarUrl) { [weak self] (avatarImage) in
                self?.avatarImageView.image = avatarImage
                self?.avatarImageView.layer.cornerRadius = (self?.avatarImageView.frame.size.width ?? 1) / 2
            }
        }

        view.setNeedsLayout()
        view.layoutIfNeeded()

        playerView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapPlayerView)))

        gradientTop == nil ? gradientTop = appendGradient(to: topGradientView, startAlpha: 0.6, endAlpha: 0) : ()
        gradientBottom == nil ? gradientBottom = appendGradient(to: detailsView, startAlpha: 0, endAlpha: 0.6) : ()

        loadStream()
    }

    private func durationString(since: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        if let startDate = isoFormatter.date(from: since) {
            let components = Calendar.current.dateComponents([.minute, .hour, .day], from: startDate, to: Date())
            return dateFormatter.string(from: components) ?? "0m"
        } else {
            return "0m"
        }
    }

    private func getImageFrom(_ url: URL, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url, completionHandler: { (data, _, error) in
            guard let data = data, error == nil else {
                print("Error getting image from \(url.absoluteString): \(error!)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            if let image = UIImage(data: data) {
                DispatchQueue.main.async { completion(image) }
            } else {
                print("Could not get UIImage from data \(data)")
                DispatchQueue.main.async { completion(nil) }
            }
        }).resume()
    }

    private func appendGradient(to view: UIView, startAlpha: CGFloat, endAlpha: CGFloat) -> CAGradientLayer {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 0, green: 0, blue: 0, alpha: startAlpha).cgColor,
            UIColor(red: 0, green: 0, blue: 0, alpha: endAlpha).cgColor
        ]
        gradientLayer.frame = CGRect(origin: view.bounds.origin,
                                     size: CGSize(width: UIScreen.main.bounds.width, height: view.bounds.height))
        view.layer.insertSublayer(gradientLayer, at: 0)
        return gradientLayer
    }

    // MARK: - Player

    private var player: IVSPlayer? {
        didSet {
            if oldValue != nil {
                removeApplicationLifecycleObservers()
            }
            playerView?.player = player
            if player != nil {
                addApplicationLifecycleObservers()
            }
        }
    }

    // MARK: Playback Control

    func loadStream() {
        guard let stream = stream else { return }
        let player: IVSPlayer
        if let existingPlayer = self.player {
            player = existingPlayer
        } else {
            player = IVSPlayer()
            player.delegate = self
            self.player = player
            print("ℹ️ Player initialized: version \(player.version)")
        }

        let streamUrl = URL(string: stream.streamInfo.playbackUrl)
        if let streamUrl = streamUrl, self.streamUrl == nil {
            player.load(streamUrl)
            self.streamUrl = streamUrl
        }

        player.muted = true
        pausePlayback()
    }

    func startPlayback() {
        player?.play()
    }

    func pausePlayback() {
        player?.pause()
    }

    // MARK: State

    private func updateForState(_ state: IVSPlayer.State) {
        bufferView.isHidden = state != .buffering
        if state == .playing {
            playerView.backgroundColor = UIColor.black
        }
    }

    private func rotateLoadingView() {
        bufferSpinnerView.layer.removeAllAnimations()
        UIView.animate(withDuration: 1, delay: 0, options: [.curveLinear], animations: {
            self.bufferSpinnerView.transform = self.bufferSpinnerView.transform.rotated(by: .pi / 2)
        }) { (finished) -> Void in
            finished ? self.rotateLoadingView() : ()
        }
    }

    private func toggleMuteStatus(_ newStatus: Bool) {
        if let player = player {
            player.muted = newStatus
            if #available(iOS 13.0, *) {
                muteButton.setImage(
                    newStatus ? UIImage(systemName: "speaker.slash.circle.fill") : UIImage(systemName: "speaker.wave.2.circle.fill"),
                    for: .normal)
            } else {
                muteButton.setImage(
                    newStatus ? UIImage(named: "sound-off") : UIImage(named: "sound-on"),
                    for: .normal)
            }
        }
    }
}

// MARK: - IVSPlayer.Delegate

extension StreamViewController: IVSPlayer.Delegate {
    func player(_ player: IVSPlayer, didChangeState state: IVSPlayer.State) {
        updateForState(state)
    }

    func player(_ player: IVSPlayer, didFailWithError error: Error) {
        delegate?.presentError(error, componentName: "Player")
    }

    func player(_ player: IVSPlayer, didChangeVideoSize videoSize: CGSize) {
        playerView.videoGravity = player.videoSize.height > player.videoSize.width ? AVLayerVideoGravity.resizeAspectFill : AVLayerVideoGravity.resizeAspect
    }
}
