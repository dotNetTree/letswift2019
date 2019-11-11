//
//  ParticleExampleVC.swift
//  LetsSwift-Looper
//
//  Created by SeungChul Kang on 09/10/2019.
//  Copyright © 2019 SeungChul Kang. All rights reserved.
//

import Foundation
import UIKit

func showParticle(target view: UIView, pos: (x: CGFloat, y: CGFloat)? = nil, typing: Bool = false) {

    let sW = UIScreen.main.bounds.size.width
    let sH = UIScreen.main.bounds.size.height
    let halfW = Double(pos?.x ?? sW / 2)
    let halfH = Double(pos?.y ?? sH / 2)

    for _ in 1...(pos == nil ? 1000 : 10) {
        let size = CGFloat.random(in: 3...8.0)
        let r = CGFloat.random(in: 0.3...0.7)
        let g = CGFloat.random(in: 0.3...0.7)
        let b = CGFloat.random(in: 0.3...0.7)

        var x: CGFloat; var y: CGFloat
        switch typing ? 2 : Int.random(in: 0...3) {
        case 0:  x = 0;  y = CGFloat.random(in: 0...(sH - size))            // 2, 3 사분면
        case 1:  x = sW - size; y = CGFloat.random(in: 0...(sH - size))     // 1, 4 사분면
        case 2:  y = 0;  x = CGFloat.random(in: 0...(sW - size))            // 1, 2 사분면
        default: y = sH - size; x = CGFloat.random(in: 0...(sW - size))     // 3, 4 사분면
        }

        let dot = also(UIView()) {
            $0.backgroundColor = UIColor(red: r, green: g, blue: b, alpha: 1)
            $0.layer.cornerRadius = size / 2
            $0.isUserInteractionEnabled = false
        }
        view.addSubview(dot)
        dot.translatesAutoresizingMaskIntoConstraints = false
        let leftAnchor   = dot.leftAnchor.constraint(equalTo: view.leftAnchor, constant: pos?.x ?? sW / 2)
        let topAnchor    = dot.topAnchor.constraint(equalTo: view.topAnchor, constant: pos?.y ?? sH / 2)
        let widthAnchor  = dot.widthAnchor.constraint(equalToConstant: size)
        let heightAnchor = dot.heightAnchor.constraint(equalToConstant: size)
        NSLayoutConstraint.activate([
            leftAnchor, topAnchor, widthAnchor, heightAnchor
        ])
        let delay = pos == nil ? Double.random(in: 0...3) : 0
        let term  = Double.random(in: 0.7...1.5) + (pos == nil ? 2 : 0)

        looper.invoke { (dsl) in
            dsl.delay = delay
            dsl.time  = term
            dsl.block = { [weak dot] item in
                guard let dot = dot else {  item.isStop = true; return }
                leftAnchor.constant   = CGFloat(item.sineInOut(from: halfW, to: Double(x)))
                topAnchor.constant    = CGFloat(item.sineInOut(from: halfH, to: Double(y)))
                widthAnchor.constant  = CGFloat(item.sineIn(from: Double(size), to: Double(size + 20)))
                heightAnchor.constant = CGFloat(item.sineIn(from: Double(size), to: Double(size + 20)))
                dot.layer.cornerRadius = heightAnchor.constant / 2
            }
            dsl.ended = { [weak dot] _ in
                dot?.removeFromSuperview()
            }
        }
        looper.invoke { (dsl) in
            dsl.delay = delay
            dsl.time  = pos == nil ? term : term / 3
            dsl.block = { [weak dot] item in
                guard let dot = dot else { return }
                switch item.rate {
                case 1:  dot.alpha = 0
                default: dot.alpha = CGFloat(item.sineIn(from: 1, to: 0))
                }
            }
            dsl.ended = { [weak dot] _ in
                dot?.removeFromSuperview()
            }
        }

    }

}

class LooperVC: UIViewController {

    private let btnBack = UIButton()
    private var backAction: ButtonAction! = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(btnBack)
        btnBack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            btnBack.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 20),
            btnBack.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 50),
            btnBack.heightAnchor.constraint(equalToConstant: 40)
        ])
        btnBack.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        btnBack.setTitle("Back", for: .normal)
        btnBack.setTitleColor(.red, for: .normal)

        backAction = ButtonAction { Router.prev() }
        btnBack.addTarget(backAction, action: #selector(backAction.click(_:)), for: .touchUpInside)

    }
}

class ParticleExampleVC: LooperVC, VCFactoryProtocol {
    static func create() -> UIViewController {
        return ParticleExampleVC()
    }
    private let btnNext = UIButton()
    private var nextAction: ButtonAction! = nil

    override func loadView() {
        let getsture = UIPanGestureRecognizer(target: self, action:  #selector (self.touched))

        view = UIView()
        view.backgroundColor = .white
        view.addGestureRecognizer(getsture)
    }
    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(btnNext)
        btnNext.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            btnNext.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -20),
            btnNext.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 50),
            btnNext.heightAnchor.constraint(equalToConstant: 40)
        ])
        btnNext.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        btnNext.setTitle("Next", for: .normal)
        btnNext.setTitleColor(.red, for: .normal)

        nextAction = ButtonAction { Router.next(of: ParticlePowerModeExampleVC.self) }
        btnNext.addTarget(nextAction, action: #selector(nextAction.click(_:)), for: .touchUpInside)

        showParticle(target: self.view)
        
    }

    @objc func touched(_ sender: UIPanGestureRecognizer) {
        // debouce 처리 필요
        for i in 0..<sender.numberOfTouches {
            let pos = sender.location(ofTouch: i, in: self.view)
            showParticle(target: self.view, pos: (pos.x, pos.y))
        }
    }

}
