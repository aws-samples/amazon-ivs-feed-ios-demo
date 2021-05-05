//
//  TableViewCell.swift
//  ScrollingFeed
//
//  Created by Zingis, Uldis on 6/30/20.
//  Copyright © 2020 Twitch. All rights reserved.
//

import UIKit
import AmazonIVSPlayer
import SpriteKit

protocol StreamCellDelegate {
    func presentError(_ error: Error, componentName: String)
    func presentAlert(_ message: String, componentName: String)
    func didTapShare(_ items: [Any])
}

class TableViewCell: UITableViewCell {
    
    private let dateFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    // MARK: IBOutlet

    @IBOutlet private var playerView: IVSPlayerView!
    @IBOutlet private var cellContentView: UIView!
    @IBOutlet private var bufferView: UIView!
    @IBOutlet private var bufferAvatarImageView: UIImageView!
    @IBOutlet private var bufferSpinnerView: LoadingIndicatorView!
    @IBOutlet private var muteButton: UIButton!
    @IBOutlet private var detailsView: UIView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var avatarImageView: UIImageView!
    @IBOutlet private var usernameLabel: UILabel!
    @IBOutlet private var onlineTimerLabel: UILabel!
    @IBOutlet private var shareButton: UIButton!
    @IBOutlet private var likeButton: UIButton!
    @IBOutlet private var pauseOverlay: UIView!

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
        if let streamUrl = streamUrl {
            delegate?.didTapShare([streamUrl])
        }
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

    // MARK: Cell setup

    private var delegate: StreamCellDelegate?
    private var streamUrl: URL?
    private var gradient: CAGradientLayer?

    func setup(with stream: Stream, delegate: StreamCellDelegate) {
        self.delegate = delegate
        cellContentView.backgroundColor = UIColor(hex: stream.metadata.userColors.primary)
        titleLabel.text = stream.metadata.streamTitle
        usernameLabel.text = stream.metadata.userName
        onlineTimerLabel.text = " for \(durationString(since: stream.streamInfo.startTime))"

        bufferSpinnerView.endColor = UIColor(hex: stream.metadata.userColors.secondary)
        rotateLoadingView()

        muteButton.layer.shadowColor = UIColor.black.cgColor
        muteButton.layer.shadowOpacity = 0.25
        muteButton.layer.shadowOffset = CGSize(width: 0, height: 4)

        if let avatarUrl = URL(string: stream.metadata.userAvatarUrl) {
            getImageFrom(avatarUrl) { [weak self] (avatarImage) in
                self?.bufferAvatarImageView.image = avatarImage
                self?.avatarImageView.image = avatarImage
            }
        }

        if gradient == nil {
            gradient = CAGradientLayer()
            gradient?.colors = [
                UIColor(red: 0, green: 0, blue: 0, alpha: 0).cgColor,
                UIColor(red: 0, green: 0, blue: 0, alpha: 0.8).cgColor
            ]
            let gradientSize = CGSize(width: UIScreen.main.bounds.width, height: detailsView.bounds.height)
            gradient?.frame = CGRect(origin: detailsView.bounds.origin, size: gradientSize)
            detailsView.layer.insertSublayer(gradient!, at: 0)
        }

        streamUrl = URL(string: stream.streamInfo.playbackUrl)

        if let streamUrl = streamUrl {
            loadStream(from: streamUrl)
            pausePlayback()
        }
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

    private func loadStream(from streamURL: URL) {
        let player: IVSPlayer
        if let existingPlayer = self.player {
            player = existingPlayer
        } else {
            player = IVSPlayer()
            player.delegate = self
            self.player = player
            print("ℹ️ Player initialized: version \(player.version)")
        }
        player.load(streamURL)
        toggleMuteStatus(true)
    }

    func startPlayback() {
        player?.play()
        pauseOverlay.isHidden = true
        toggleInfoAndButtons(true)
    }

    func pausePlayback() {
        player?.pause()
        pauseOverlay.isHidden = false
        toggleInfoAndButtons(false)
    }

    // MARK: State

    private func updateForState(_ state: IVSPlayer.State) {
        if state == .buffering {
            bufferView.isHidden = false
        } else {
            bufferView.isHidden = true
        }
    }

    private func toggleInfoAndButtons(_ show: Bool) {
        detailsView.isHidden = !show
        muteButton.isHidden = !show
    }

    private func rotateLoadingView() {
        UIView.animate(withDuration: 1, delay: 0, options: [.curveLinear], animations: {
            self.bufferSpinnerView.transform = self.bufferSpinnerView.transform.rotated(by: .pi / 2)
        }) { (finished) -> Void in
            finished ? self.rotateLoadingView() : ()
        }
    }

    private func toggleMuteStatus(_ newStatus: Bool) {
        if let player = player {
            player.muted = newStatus
            muteButton.setImage(newStatus ? UIImage(named: "sound-off") : UIImage(named: "sound-on"), for: .normal)
        }
    }
}

// MARK: - IVSPlayer.Delegate

extension TableViewCell: IVSPlayer.Delegate {

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
