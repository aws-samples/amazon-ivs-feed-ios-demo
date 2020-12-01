//
//  File.swift
//  ScrollingFeed
//
//  Created by Zingis, Uldis on 7/9/20.
//  Copyright © 2020 Twitch. All rights reserved.
//

import UIKit

enum RotationDirection: CGFloat {
    case Left = -1
    case Right = 1
}

public class HeartView: UIView {

    // MARK: Customisation

    private let availableColors = [
        UIColor(hex: "#FF00B8"),
        UIColor(hex: "#FF5555"),
        UIColor(hex: "#BB86FF"),
        UIColor(hex: "#FFE249"),
        UIColor(hex: "#49FFDE")
    ]
    private let animationDuration: TimeInterval = 4
    private let appearAnimationDuration: TimeInterval = 0.5

    // MARK: Overrides

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.clear
        layer.anchorPoint = CGPoint(x: 0.5, y: 1)
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override public func draw(_ rect: CGRect) {
        let randomColor = availableColors[Int.random(in: 0..<availableColors.count)]
        let imageBundle = Bundle(for: HeartView.self)
        let heartImage = UIImage(named: "like", in: imageBundle, compatibleWith: nil)?.withRenderingMode(.alwaysTemplate)
        randomColor.setFill()
        heartImage?.draw(in: rect, blendMode: .normal, alpha: 1.0)
    }

    // MARK: Animations

    public func animateInView(view: UIView) {
        // Pick -1 or 1
        let rawDirection = CGFloat(1 - (2 * Int.random(in: 0...1)))
        guard let rotationDirection = RotationDirection(rawValue: rawDirection) else { return }
        prepareForAnimation()
        performBloomAnimation()
        performSlightRotationAnimation(direction: rotationDirection)
        addPathAnimation(inView: view)
    }

    private func prepareForAnimation() {
        transform = CGAffineTransform(scaleX: 0, y: 0)
        alpha = 0
    }

    private func performBloomAnimation() {
        UIView.animate(withDuration: appearAnimationDuration, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: [UIView.AnimationOptions.curveEaseOut], animations: {
            self.transform = CGAffineTransform.identity
            self.alpha = 0.9
        })
    }

    private func performSlightRotationAnimation(direction: RotationDirection) {
        UIView.animate(withDuration: animationDuration, delay: 0, options: [], animations: {
            let radians = direction.rawValue * CGFloat.pi
            let randomRotation = 16 + (CGFloat.random(in: 0...9) * 0.2)
            self.transform = CGAffineTransform(rotationAngle: radians / randomRotation)
        })
    }

    private func addPathAnimation(inView view: UIView) {
        guard let heartTravelPath = travelPath(inView: view) else { return }

        let keyFrameAnimation = CAKeyframeAnimation(keyPath: "position")
        keyFrameAnimation.path = heartTravelPath.cgPath
        keyFrameAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)

        let durationAdjustment = 2 * TimeInterval(heartTravelPath.bounds.height / view.bounds.height)
        let duration = animationDuration + durationAdjustment
        keyFrameAnimation.duration = duration
        layer.add(keyFrameAnimation, forKey: "positionOnPath")

        animateToFinalState()
    }

    private func animateToFinalState() {
        UIView.animate(withDuration: animationDuration, delay: 0, options: [], animations: {
            self.alpha = 0.0
            self.bounds = CGRect(x: 0, y: 0, width: self.bounds.width / 2, height: self.bounds.height / 2)
        }, completion: { _ in
            self.removeFromSuperview()
        })
    }

    private func travelPath(inView view: UIView) -> UIBezierPath? {
        // Pick -1 or 1
        let rawDirection = CGFloat(1 - (2 * Int.random(in: 0...2)))
        guard let endPointDirection = RotationDirection(rawValue: rawDirection) else {
            return nil
        }
        let heartCenterX = center.x
        let heartSize = bounds.width
        let endPointX = heartCenterX + (endPointDirection.rawValue * CGFloat.random(in: 0..<(2 * heartSize)))
        let endPointY = view.bounds.height / 3
        let endPoint = CGPoint(x: endPointX, y: endPointY)

        let travelDirection = CGFloat(1 - (2 * Int.random(in: 0...1)))
        let xDelta = (heartSize / 2 + CGFloat.random(in: 0..<(2 * heartSize))) * travelDirection
        let yDelta = CGFloat.random(in: 0..<(10 * heartSize))
        let controlPoint1 = CGPoint(x: heartCenterX + xDelta, y: view.bounds.height - yDelta)
        let controlPoint2 = CGPoint(x: heartCenterX - 2 * xDelta, y: yDelta)

        let path = UIBezierPath()
        path.move(to: center)
        path.addCurve(to: endPoint, controlPoint1: controlPoint1, controlPoint2: controlPoint2)
        return path
    }
}
