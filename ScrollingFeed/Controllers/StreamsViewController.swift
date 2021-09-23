//
//  StreamsViewController.swift
//  StreamsViewController
//
//  Created by Uldis Zingis on 23/09/2021.
//  Copyright © 2021 Twitch. All rights reserved.

import UIKit

class StreamsViewController: UIPageViewController {

    private var streams: [Stream] = []

    // MARK: Application Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource = self
        delegate = self
        loadStreams()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: Data setup

    private func loadStreams() {
        if let path = Bundle.main.path(forResource: "feed", ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                do {
                    self.streams = try JSONDecoder().decode(Streams.self, from: data).streams
                    self.setFirstView()
                } catch {
                    print("‼️ Error decoding streams: \(error)")
                    print("Received: \(String(data: data, encoding: .utf8) ?? "")")
                }
            } catch {
                print("‼️ Error: \(error)")
            }
        }
    }

    private func setFirstView() {
        guard let streamVC = storyboard?.instantiateViewController(withIdentifier: "StreamViewController") as? StreamViewController else {
            return
        }
        streamVC.setup(streams[0], delegate: self)
        setViewControllers([streamVC], direction: .forward, animated: true, completion: nil)
        streamVC.startPlayback()
    }
}

extension StreamsViewController: UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let previousStreamVC = storyboard?.instantiateViewController(withIdentifier: "StreamViewController") as? StreamViewController,
              let vc = viewController as? StreamViewController,
              let stream = vc.stream else {
                  return nil
              }

        let currentIndex = streams.firstIndex(where: { $0.id == stream.id }) ?? 0
        let index = currentIndex == 0 ? streams.count - 1 : currentIndex - 1
        previousStreamVC.setup(streams[index], delegate: self)
        return previousStreamVC
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let nextStreamVC = storyboard?.instantiateViewController(withIdentifier: "StreamViewController") as? StreamViewController,
              let vc = viewController as? StreamViewController,
              let stream = vc.stream else {
                  return nil
              }

        let currentIndex = streams.firstIndex(where: { $0.id == stream.id }) ?? 0
        let index = currentIndex == streams.count - 1 ? 0 : currentIndex + 1
        nextStreamVC.setup(streams[index], delegate: self)
        return nextStreamVC
    }
}

// MARK: - StreamDelegate

extension StreamsViewController: StreamDelegate {
    func presentError(_ error: Error, componentName: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "\(componentName) Error", message: String(reflecting: error), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Close", style: .cancel))
            self.present(alert, animated: true)
        }
    }

    func presentAlert(_ message: String, componentName: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "\(componentName)", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Close", style: .cancel))
            self.present(alert, animated: true)
        }
    }

    func didTapShare(_ items: [Any]) {
        DispatchQueue.main.async {
            let activityController = UIActivityViewController(activityItems: items, applicationActivities: nil)
            activityController.popoverPresentationController?.sourceView = self.view
            self.present(activityController, animated: true, completion: nil)
        }
    }
}

extension StreamsViewController: UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        if let currentVC = pageViewController.viewControllers?.first as? StreamViewController {
            currentVC.pausePlayback()
        }
        if let nextVC = pendingViewControllers.first as? StreamViewController {
            nextVC.startPlayback()
        }
    }
}
