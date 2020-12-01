//
//  ViewController.swift
//  ScrollingFeed
//
//  Created by Zingis, Uldis on 6/30/20.
//  Copyright © 2020 Twitch. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    // MARK: IBOutlet

    @IBOutlet var feedsTableView: UITableView!

    var streams: Streams? {
        didSet {
            DispatchQueue.main.async {
                self.feedsTableView.reloadData()
                if let cell = self.feedsTableView.cellForRow(at: IndexPath(row: self.currentActiveCellIndex, section: 0)) as? TableViewCell {
                    cell.startPlayback()
                }
            }
        }
    }
    var currentActiveCellIndex: Int = 0

    // MARK: Application Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        feedsTableView.rowHeight = view.frame.height - 120
        feedsTableView.delegate = self
        feedsTableView.dataSource = self
        feedsTableView.decelerationRate = .fast
        loadStreams()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: Data setup

    func loadStreams() {
        if let path = Bundle.main.path(forResource: "feed", ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                do {
                    self.streams = try JSONDecoder().decode(Streams.self, from: data)
                } catch {
                    print("‼️ Error decoding streams: \(error)")
                    print("Received: \(String(data: data, encoding: .utf8) ?? "")")
                }
            } catch {
                print("‼️ Error: \(error)")
            }
        }
    }

    // MARK: Scroll view

    func setContentOffset(scrollView: UIScrollView) {
        guard let streams = streams else { return }
        scrollView.isScrollEnabled = false

        if let oldActiveCell = feedsTableView.cellForRow(at: IndexPath(row: currentActiveCellIndex, section: 0)) as? TableViewCell {
            oldActiveCell.pausePlayback()
        }
        let didSwipeDown = scrollView.panGestureRecognizer.translation(in: scrollView.superview).y < 0
        let maxIndex = streams.streams.count - 1
        currentActiveCellIndex += didSwipeDown ? 1 : -1
        currentActiveCellIndex = currentActiveCellIndex < 0 ? 0 : currentActiveCellIndex
        currentActiveCellIndex = currentActiveCellIndex > maxIndex ? maxIndex : currentActiveCellIndex

        let newOffsetY = feedsTableView.rowHeight * CGFloat(currentActiveCellIndex) - feedsTableView.estimatedSectionHeaderHeight
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: newOffsetY), animated: true)

        if let newActiveCell = feedsTableView.cellForRow(at: IndexPath(row: currentActiveCellIndex, section: 0)) as? TableViewCell {
            newActiveCell.startPlayback()
        }
        scrollView.isScrollEnabled = true
    }
}

// MARK: - UITableViewDataSource

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return streams?.streams.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "streamTableViewCell") as? TableViewCell,
            let stream = streams?.streams[indexPath.row] else {
            return UITableViewCell()
        }
        cell.setup(with: stream, delegate: self)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return UIView()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return tableView.rowHeight
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 30
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        setContentOffset(scrollView: scrollView)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            setContentOffset(scrollView: scrollView)
        }
    }
}

// MARK: - StreamCellDelegate

extension ViewController: StreamCellDelegate {
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
        let activityController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        present(activityController, animated: true)
    }
}
