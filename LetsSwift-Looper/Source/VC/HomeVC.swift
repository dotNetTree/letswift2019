//
//  HomeVC.swift
//  LetsSwift-Looper
//
//  Created by SeungChul Kang on 09/10/2019.
//  Copyright © 2019 SeungChul Kang. All rights reserved.
//
import Foundation
import UIKit

class ButtonAction {
    let action: VoidClosure
    init(action: @escaping VoidClosure) {
        self.action = action
    }
    @objc func click(_ sender: UIButton) {
        self.action()
    }
}

enum Router {
    static func next<T>(of: T.Type) where T: VCFactoryProtocol {
        (UIApplication.shared.keyWindow?.rootViewController as? UINavigationController)?.pushViewController(
            T.create(), animated: true
        )
    }
    static func prev() {
        dismiss(toRoot: false)
    }
    static func root() {
        dismiss(toRoot: true)
    }
    private static func dismiss(toRoot: Bool = false) {
        let nvc = UIApplication.shared.keyWindow?.rootViewController as? UINavigationController
        if toRoot {
            nvc?.popToRootViewController(animated: true)
        } else {
            nvc?.popViewController(animated: true)
        }
    }
}


class HomeVC: UIViewController {
    typealias DSL = Looper.Looper.ItemDSL
    let pause = Looper.Pause()

    @IBOutlet var t1_label: [UILabel]!
    @IBOutlet var t1_centerY: [NSLayoutConstraint]!

    @IBOutlet weak var t2_iv: UIImageView!
    @IBOutlet var t2_iv_trailing: NSLayoutConstraint!
    @IBOutlet var t2_label: [UILabel]!

    var actions = [ButtonAction]()
    var vCircleCenterX: NSLayoutConstraint! = nil

    let now: () -> Double = { Date.timeIntervalSinceReferenceDate }
    private var displayLink: CADisplayLink?

    var start1: TimeInterval! = nil
    var term1: TimeInterval! = nil
    var isEnd1: Bool = false
    var start2: TimeInterval! = nil
    var term2: TimeInterval! = nil
    var isEnd2: Bool = false

    func aniStart() {
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.add(to: .main, forMode: .common)
        start1 = now(); start2 = now()
        term1 = 4     ; term2 = 2
        isEnd1 = false; isEnd2 = false
    }

    @objc func update() { ani1(); ani2() }

    func ani1() {
        guard !isEnd1 else { return }
        let rate = min(1.0, (now() - start1) / term1)
        if rate == 1.0 { isEnd1 = true }
        vCircle.center = CGPoint.init(x: 500.0 * rate, y: 100)
    }
    func ani2() {
        guard !isEnd2 else { return }
        let rate = min(1.0, (now() - start2) / term2)
        if rate == 1.0 { isEnd2 = true }
        vCircle.alpha = CGFloat(1.0 - rate)
    }

    let vCircle = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.


        vCircle.backgroundColor = .red
        vCircle.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        vCircle.center = CGPoint.init(x: 0, y: 100)

        self.view.addSubview(vCircle)
//        aniStart()

        looper.invoke { dsl in
            dsl.time = 4
            dsl.block = { item in
                self.vCircle.center = CGPoint.init(x: 500.0 * item.rate, y: 100)
            }
        }
        looper.invoke { dsl in
            dsl.time = 2
            dsl.block = { item in
                self.vCircle.alpha = CGFloat(1.0 - item.rate)
            }
        }

//        let circlePath = UIBezierPath(
//            arcCenter: CGPoint(x: 100, y: 100),
//            radius: 50,
//            startAngle: 0,
//            endAngle: .pi * 2,
//            clockwise: true
//        )
//
//        let animation = CAKeyframeAnimation(keyPath: #keyPath(CALayer.position))
//        animation.duration = 1
//        animation.path = circlePath.cgPath
//        animation.fillMode = .forwards
//        animation.isRemovedOnCompletion = false

//        vCircle.layer.add(animation, forKey: nil)


        t1_label.forEach { $0.alpha = 0 }
        t2_label.forEach { $0.alpha = 0 }
        t2_iv_trailing.constant = 500

        // MARK: Let's Swfit Wave Animation
        var t1Ended = false
        if true {
            let count = t1_centerY.count
            for i in 0..<count {
                let label = t1_label[i]
                let constraint = t1_centerY[i]
                var down: ((DSL) -> Void)! = nil
                let up = { [weak self] (dsl: DSL) in
                    dsl.delay = Double(i) * 0.1
                    dsl.time  = Double(count) * 0.05
                    dsl.block = { item in
                        label.alpha = CGFloat(item.rate * 0.5)
                        constraint.constant = CGFloat(item.rate * -40)
                    }
                    dsl.ended = {  _ in
                        looper.invoke(pause: self?.pause, down)
                    }
                }
                down = { (dsl: DSL) in
                    dsl.time  = Double(count) * 0.05
                    dsl.block = { item in
                        label.alpha = 0.5 + CGFloat(item.rate * 0.5)
                        constraint.constant = -40 - CGFloat(item.rate * -40)
                    }
                    dsl.ended = { _ in
                        if i == count - 1 {
                            t1Ended = true
                        }
                    }
                }
                looper.invoke(pause: pause, up)
            }

        }

        // MARK: Looper Text Animation
        var t2Ended = false
        if true {
            var take2: VoidClosure!
            looper.invoke { dsl in
                dsl.isInfinity = true
                dsl.block = { $0.isStop = t1Ended } // take 1 animation이 끝남을 감지
                dsl.ended = { _ in // take 2 시작 애니메이션 조합
                    take2()
                }
            }

            take2 = {
                let count = self.t2_label.count
                var seq: Looper.Sequence!
                for i in 0..<count {
                    let label = self.t2_label[i]
                    seq = looper.invoke(pause: self.pause) { (dsl) in
                        dsl.delay = Double(i) * 0.1
                        dsl.time  = 0.3
                        dsl.block = { item in
                            let scale = CGFloat(1 + (1 - item.rate) * 2)
                            let alpha = CGFloat(item.rate)
                            label.transform = CGAffineTransform(
                                scaleX: scale, y: scale
                            )
                            label.alpha = alpha
                        }
                    }
                }
                seq.next { [weak self] (dsl) in
//                        2 * 25 * 3.14 = 157
                    self?.t2_iv_trailing.constant = 6 + (157 * 2)   // 2바퀴 구른다.
                    dsl.time  = 0.5
                    dsl.block = { item in
                        self?.t2_iv_trailing.constant = 6 + CGFloat((157 * 2) * (1 - item.rate))
                        self?.t2_iv.transform = CGAffineTransform(
                            rotationAngle: CGFloat(.pi * 2 * item.rate * 2)
                        )
                    }
                }
                .next { [weak self] dsl in
                    let flip = {
                        for i in 0..<count {
                            let label = self?.t2_label[i]
                            seq = looper.invoke(pause: self?.pause) { (dsl) in
                                dsl.delay = Double(i) * 0.02
                                dsl.time  = 1
                                dsl.block = { item in
                                    let r = item.sineInOut(
                                        from: item.rate <= 0.5 ? 0 : 1,
                                        to:   item.rate <= 0.5 ? 1 : 0
                                    )
                                    var transform = CATransform3DIdentity
                                    transform.m34 = 1 / -200
                                    transform = CATransform3DRotate(transform, .pi * CGFloat(r) * 0.7, 0, 1, 0)   // y 축 회전 (0.3 = 30%만 넘김 처리함)
                                    label?.contentMode = .right
                                    label?.layer.transform = CATransform3DScale(transform, 1, 1, 1)
                                }
                                dsl.ended = { _ in
                                    if i == count - 1 {
                                        t2Ended = true
                                    }
                                }
                            }
                        }
                    }
                    dsl.block = { _ in flip() }
                }
            }

        }

        // MARK: Button Animation
        if true {
            var take3: VoidClosure!
            looper.invoke { dsl in
                dsl.isInfinity = true
                dsl.block = { $0.isStop = t1Ended } // take 1 animation이 끝남을 감지
                dsl.ended = { _ in // take 2 시작 애니메이션 조합
                    take3()
                }
            }

            take3 = {
                var data: [(title: String, action: VoidClosure)]!
                Flow()
                    .async { sync in
                        after(delay: 3) {
                            sync {
                                data = [
                                    ("파티클",  { Router.next(of: ParticleExampleVC.self) }),
                                    ("순차처리", { Router.next(of: FlowExampleVC.self) })
                                ]
                            }
                        }
                    }
                    .sync { [weak self] in
                        let x: CGFloat = 50
                        var y: CGFloat = 250
                        let w: CGFloat = (self?.view.bounds.size.width ?? 0) - (x * 2)
                        let h: CGFloat = 65
                        data.forEach { (body) in
                            let (title, block) = body
                            let action = also(ButtonAction(action: block)) { self?.actions.append($0) }
                            let _ = also(UIButton()) {
                                self?.view.addSubview($0)
                                $0.addTarget(action, action: #selector(action.click(_:)), for: .touchUpInside)
                                $0.setTitle(title, for: .normal)
                                $0.setTitleColor(UIColor.init(red: 128/255, green: 128/255, blue: 128/255, alpha: 1), for: .normal)
                                $0.titleLabel?.font = UIFont.systemFont(ofSize: 32, weight: .bold)
                                $0.translatesAutoresizingMaskIntoConstraints = true
                                $0.frame = CGRect.init(x: x, y: y, width: w, height: h)

                                $0.backgroundColor = .white
                                $0.layer.cornerRadius = 5
                                $0.layer.borderWidth  = 7
                                $0.layer.borderColor  = UIColor.init(red: 255.0/255, green: 53.0/255, blue: 183.0/255, alpha: 1).cgColor

                            }
                            y += h + 20
                        }
                    }
                    .sync {

                    }
                    .start()
            }
        }
    }


}

