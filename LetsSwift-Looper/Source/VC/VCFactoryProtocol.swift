//
//  VCFactoryProtocol.swift
//  LetsSwift-Looper
//
//  Created by SeungChul Kang on 09/10/2019.
//  Copyright © 2019 SeungChul Kang. All rights reserved.
//

import Foundation
import UIKit

protocol VCFactoryProtocol: class {
    static func create() -> UIViewController
}
