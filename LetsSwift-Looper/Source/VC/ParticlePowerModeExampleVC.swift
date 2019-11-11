//
//  ParticlePowerModeExampleVC.swift
//  LetsSwift-Looper
//
//  Created by chpike on 13/10/2019.
//  Copyright © 2019 SeungChul Kang. All rights reserved.
//

import Foundation
import UIKit

extension ParticlePowerModeExampleVC: UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        guard let selectedRange = textView.selectedTextRange,
            let textPos = textView.position(
                from: textView.beginningOfDocument,
                offset: textView.offset(from: textView.beginningOfDocument, to: selectedRange.start)
            )
            else { return }

        let rect = textView.caretRect(for: textPos)
        let pos = textView.convert(rect.origin, to: self.view)

        showParticle(target: self.view, pos: (pos.x, pos.y + rect.size.height / 2), typing: true)

    }
}

class ParticlePowerModeExampleVC: LooperVC, VCFactoryProtocol {
    static func create() -> UIViewController {
        return ParticlePowerModeExampleVC()
    }
    let textview = UITextView()
    override func loadView() {
        view = UIView()
        view.backgroundColor = .white
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(textview)
        textview.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textview.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 20),
            textview.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -20),
            textview.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 100),
            textview.heightAnchor.constraint(equalToConstant: 100)
        ])
        textview.font = UIFont.systemFont(ofSize: 30, weight: .medium)
        textview.delegate = self
        textview.layer.cornerRadius = 5
        textview.layer.borderWidth  = 7
        textview.layer.borderColor  = UIColor.init(red: 255.0/255, green: 53.0/255, blue: 183.0/255, alpha: 1).cgColor

    }

}
