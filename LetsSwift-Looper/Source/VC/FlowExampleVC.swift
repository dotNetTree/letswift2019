//
//  FlowExampleVC.swift
//  LetsSwift-Looper
//
//  Created by chpike on 11/11/2019.
//  Copyright © 2019 SeungChul Kang. All rights reserved.
//

import Foundation
import UIKit

class SectionView: UIView {
    func render(with: String) {
        self.isHidden = false
    }
}

class Indicator: UIView {
    private let _indicator = UIActivityIndicatorView.init()
    var target: UIView
    init(target: UIView) {
        self.target = target
        super.init(frame: .zero)
        self.backgroundColor = UIColor.init(white: 0.3, alpha: 0.5)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    func show() {
        target.addSubview(self)
        self.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.widthAnchor.constraint(equalToConstant: 80),
            self.heightAnchor.constraint(equalToConstant: 80),
            self.centerXAnchor.constraint(equalTo: target.centerXAnchor),
            self.centerYAnchor.constraint(equalTo: target.centerYAnchor),
        ])
        self.addSubview(_indicator)
        _indicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            _indicator.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            _indicator.centerYAnchor.constraint(equalTo: self.centerYAnchor),
        ])
        _indicator.style = .whiteLarge
        _indicator.startAnimating()
    }
    func hide() {
        removeFromSuperview()
        _indicator.removeFromSuperview()
        _indicator.stopAnimating()
    }
}

class FlowExampleVC: LooperVC, VCFactoryProtocol {
    static func create() -> UIViewController {
        return FlowExampleVC()
    }
    let stkView  = UIStackView()
    lazy var indicator = Indicator(target: self.view)
    let section1 = SectionView()
    let section2 = SectionView()
    let section3 = SectionView()

    override func loadView() {
        view = UIView()
        view.backgroundColor = .white

        view.addSubview(stkView)
        stkView.axis = .vertical
        stkView.spacing = 10
        stkView.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 11.0, *) {
            NSLayoutConstraint.activate([
                stkView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                stkView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                view.safeAreaLayoutGuide.topAnchor.constraint(equalTo: stkView.topAnchor),
                view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: stkView.bottomAnchor)
            ])
        } else {
            // Fallback on earlier versions
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        section1.isHidden = true
        section1.backgroundColor = UIColor(red: 248/255, green: 186/255, blue: 0, alpha: 1)
        stkView.addArrangedSubview(section1)
        section1.translatesAutoresizingMaskIntoConstraints = false
        section1.heightAnchor.constraint(equalToConstant: 200).isActive = true

        section2.isHidden = true
        section2.backgroundColor = UIColor(red: 239/255, green: 95/255, blue: 167, alpha: 1)
        section2.translatesAutoresizingMaskIntoConstraints = false
        section2.heightAnchor.constraint(equalToConstant: 200).isActive = true
        stkView.addArrangedSubview(section2)

        section3.isHidden = true
        section3.backgroundColor = UIColor(red: 0, green: 162/255, blue: 1, alpha: 1)
        stkView.addArrangedSubview(section3)
        section3.translatesAutoresizingMaskIntoConstraints = false
        section3.heightAnchor.constraint(equalToConstant: 200).isActive = true

        let section4 = UIView()
        section4.backgroundColor = .clear
        stkView.addArrangedSubview(section4)

        batch()
    }

    func batch() {
        var started: TimeInterval!
        var k1: String! = nil
        var k2: String! = nil
        Flow()
            .sync { self.indicator.show(); started = now() }
            .bundle {
                Flow()
                    .async { sync in self.fetchKey1 { r in sync { k1 = r } } }
                    .async { sync in self.fetchKey2 { r in sync { k2 = r } } }
            }
            .async { sync in self.fetch1(k1, k2) { r in sync { self.section1.render(with: r) } } }
            .async { sync in self.fetch2 { r in sync { self.section2.render(with: r) } } }
            .async { sync in self.fetch3 { r in sync { self.section3.render(with: r) } } }
            .pause(duration: { 2 - min(2, now() - started) }) {
                self.indicator.hide()
            }
            .start()
    }
}

extension FlowExampleVC {
    func fetchKey1(completion: @escaping (String) -> Void) {
        after(delay: 1) {
            completion("fectchKey1 completion")
        }
    }
    func fetchKey2(completion: @escaping (String) -> Void) {
        after(delay: 0.5) {
            completion("fectchKey2 completion")
        }
    }
    func fetch1(_ k1: String, _ k2: String, completion: @escaping (String) -> Void) {
        after(delay: 0.2) {
            completion("fetch1 completion")
        }
    }
    func fetch2(completion: @escaping (String) -> Void) {
        after(delay: 0.8) {
            completion("fetch2 completion")
        }
    }
    func fetch3(completion: @escaping (String) -> Void) {
        after(delay: 0.3) {
            completion("fetch3 completion")
        }
    }
}
