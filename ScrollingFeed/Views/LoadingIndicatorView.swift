//
//  LoadingIndicatorView.swift
//  ScrollingFeed
//
//  Created by Zingis, Uldis on 7/10/20.
//  Copyright © 2020 Twitch. All rights reserved.
//

import UIKit

class LoadingIndicatorView: UIView {
    var endColor: UIColor = .white  {
        didSet { setNeedsLayout() }
    }

    private let gradientLayer: CAGradientLayer = {
        let gradientLayer = CAGradientLayer()
        gradientLayer.type = .conic
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        return gradientLayer
    }()

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        layer.addSublayer(gradientLayer)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        layer.addSublayer(gradientLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        gradientLayer.frame = bounds
        gradientLayer.colors = [.clear, endColor].map { $0.cgColor }

        let lineWidth: CGFloat = 4
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = (bounds.height - lineWidth) / 2
        let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        let mask = CAShapeLayer()

        mask.fillColor = UIColor.clear.cgColor
        mask.strokeColor = UIColor.white.cgColor
        mask.lineWidth = lineWidth
        mask.path = path.cgPath

        gradientLayer.mask = mask
    }
}
