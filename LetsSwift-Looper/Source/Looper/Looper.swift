//
//  Looper.swift
//  LetsSwift-Looper
//
//  Created by SeungChul Kang on 10/09/2019.
//  Copyright © 2019 LooperAlience. All rights reserved.
//

import Foundation
import UIKit

typealias VoidClosure = () -> Void

func after(delay seconds: Double = 0.0, closure: @escaping VoidClosure) {
    DispatchQueue.main.asyncAfter(
        deadline: .now() + DispatchTimeInterval.milliseconds(Int(seconds * 1000)),
        execute: closure
    )
}

@discardableResult
func also<T>(_ obj: T, _ block: (inout T)->Void) -> T {
    var copy = obj
    block(&copy)
    return copy
}

class ThreadSafeCollection<Element> {

    // Concurrent synchronization queue
    private let queue = DispatchQueue(label: "ThreadSafeCollection.queue", attributes: .concurrent)

    private var _elements: [Element] = []

    var elements: [Element] {
        var result: [Element] = []

        queue.sync { // Read
            result = _elements
        }

        return result
    }

    func append(_ element: Element) {
        // Write with .barrier
        // This can be performed synchronously or asynchronously not to block calling thread.
        queue.async(flags: .barrier) {
            self._elements.append(element)
        }
    }

    func append(_ sequence: [Element]) {
        queue.async(flags: .barrier) {
            self._elements.append(contentsOf: sequence)
        }
    }
}

extension ThreadSafeCollection where Element == Looper.Item {
    func removeMarkedItems() -> [Element] {
        var result: [Element] = []
        queue.sync {
            for i in (0..<self._elements.count).reversed() {
                let item = self._elements[i]
                if item.marked {
                    item.block = Looper.Item.emptyBlock
                    item.ended = Looper.Item.emptyBlock
                    self._elements.remove(at: i)
                    result.append(item)
                    if let next = item.next {
                        self._elements.append(next)
                    }
                }
            }
        }
        return result
    }
    func element() -> Element {
        var element: Element! = nil
        queue.sync {
            if self._elements.count == 0 {
                element = Element()
            } else {
                element = self._elements.removeFirst()
            }
        }
        return element
    }
}

/// Main Looper
let looper = also(Looper.Looper()) { $0.start() }

typealias Now = () -> Double
let now: Now = { Date.timeIntervalSinceReferenceDate }

enum Looper {
    private class Updater {
        private var displayLink: CADisplayLink?
        private var activated = false
        fileprivate var loopers = [Looper]()
        func start() {
            if !activated {
                displayLink = CADisplayLink(target: self, selector: #selector(update))
                displayLink?.add(to: RunLoop.main, forMode: RunLoop.Mode.common)
//                displayLink?.add(to: .main, forMode: .default)
            }
        }
        func stop() {
            displayLink?.invalidate()
            displayLink = nil
            activated = false
        }
        @objc func update() {
            loopers.forEach { $0.loop() }
        }
    }

    class Item {
        typealias Block = (Item) -> Void
        static let emptyBlock: Block = { _ in }
        var rate    = 0.0
        var current = 0.0
        var start   = 0.0
        var end     = 0.0
        var term    = 0.0
        var loop    = 1
        var isPaused   = false
//        var isInfinity = false

        var block: Block = Item.emptyBlock
        var ended: Block = Item.emptyBlock
        var next: Item?  = nil
        var isStop = false
        private var pauseStart = 0.0
        fileprivate var marked = false
    }

    class Pause {
        static let `default` = Pause()
        var active: Bool = false {
            didSet {
                let paused = active
                items.forEach { v in
                    (v as? Item)?.isPaused = paused
                }
            }
        }
        private var items = NSMutableSet()
        func add(item: Item) {
            item.isPaused = active
            items.add(item)
        }
        func remove(item: Item) {
            items.remove(item)
        }
    }
    
    class Looper {
        class ItemDSL {
            var time:  Double = -1
            var delay: Double = 0
            var loop:  Int = 1
            var block: Item.Block = Item.emptyBlock
            var ended: Item.Block = Item.emptyBlock
            var isInfinity: Bool  = false
        }

        private var fps        = 0.0
        private var previus    = 0.0
        private var pauseStart = 0.0
        private var pausedTime = 0.0
        private var items = ThreadSafeCollection<Item>()
        private var pool  = ThreadSafeCollection<Item>()

        private static let updater = Updater()

        private lazy var _sequence = Sequence(looper: self)
        private var sequence: Sequence {
            get { return _sequence }
        }

        func start() {
            Looper.updater.loopers += [self]
            Looper.updater.start()
        }

        fileprivate func loop() {
//            guard pauseStart == 0.0 else { return }
            let c = now() - pausedTime
//            let gap = c - previus
//            if gap > 0.0 {
//                fps = 1.0 / gap
//            }
//            print(fps)
//            previus = c
            let _items = items.elements
            var cnt = _items.count
            var hasRemoveItems = false
            while 0 < cnt {
                cnt -= 1
                let item = _items[cnt]
                if item.isPaused || item.start > c {    // pause 상태이거나 아직 시작할 타이밍이 아님
                    continue
                }
                var isEnd = false
                item.rate = {
                    if item.end <= c {
                        item.loop -= 1
                        if item.loop == 0 {
                            isEnd = true
                            return 1.0
                        } else {
                            item.start = c
                            item.end = c + item.term
                            return 0.0
                        }
                    } else if item.term == 0.0 {
                        return 0.0
                    } else {
                        return (c - item.start) / item.term
                    }
                }()
                item.current = c
                item.isStop  = false
                item.block(item)
                if item.isStop || isEnd {
                    item.ended(item)
                    if let n = item.next {
                        n.start += c
                        n.end = n.start + n.term
                    }
                    item.marked = true
                    hasRemoveItems = true
                }
            }

            if hasRemoveItems {
                pool.append(items.removeMarkedItems())
                    #if DEBUG
//                    print("working items := \(self.items.count) | in pool := \(self.itemPool.count)")
                    #endif
            }
        }

        fileprivate func getItem(_ i: ItemDSL, pause: Pause? = nil) -> Item {
            return also(pool.element()) {
                $0.term  = i.time
                $0.start = i.delay
                $0.loop  = i.isInfinity ? -1 : i.loop
                $0.next  = nil
                $0.isPaused = false
                $0.isStop   = false
                $0.marked   = false
                let ended = i.ended
                $0.block = i.block
                $0.ended = { [weak pause] item in
                    pause?.remove(item: item)
                    ended(item)
                }
                pause?.add(item: $0)
            }
        }

        @discardableResult
        func invoke(pause: Pause? = nil, _ block: (ItemDSL) -> Void) -> Sequence {
            let dsl = ItemDSL()
            block(dsl)
            let item = getItem(dsl)
            item.start += now()
            item.end   = item.start + item.term
            items.append(item)
            sequence.current = item
            return sequence
        }

        func pause(){
            if (pauseStart == 0.0) { pauseStart = now() }
        }

        func resume(){
            if(pauseStart != 0.0){
                pausedTime += now() - pauseStart
                pauseStart = 0.0
            }
        }
    }

    class Sequence {
        private let looper: Looper
        var current: Item? = nil
        init(looper: Looper) {
            self.looper = looper
        }
        @discardableResult
        func next(pause: Pause? = nil, _ block: (Looper.ItemDSL) -> Void) -> Sequence {
            let item = looper.getItem(also(Looper.ItemDSL()) { block($0) }, pause: pause)
            current?.next = item
            current = item
            return self
        }
    }
}

fileprivate let PI  = Double.pi
fileprivate let HPI = Double.pi / 2
extension Looper.Item {
    
    func linear(from: Double, to: Double) -> Double {
        return from + rate * (to - from)
    }
    func sineIn(from: Double, to: Double) -> Double {
        let b = to - from
        return -b * cos(rate * HPI) + b + from
    }
    func sineOut(from: Double, to: Double) -> Double {
        return (to - from) * sin(rate * HPI) + from
    }
    func sineInOut(from: Double, to: Double) -> Double {
        return 0.5 * -(to - from) * (cos(PI * rate) - 1) + from
    }
    func circleIn(from: Double, to: Double) -> Double {
        return -(to - from) * (sqrt(1 - rate * rate) - 1) + from
    }
    func circleOut(from: Double, to: Double) -> Double {
        let a = rate - 1
        return (to - from) * sqrt(1 - a * a) + from
    }
    func circleInOut(from: Double, to: Double) -> Double {
        var a = rate * 2
        let b = to - from
        if (1 > a) {
            return 0.5 * -b * (sqrt(1 - a * a) - 1) + from
        } else {
            a -= 2.0
            return 0.5 * b * (sqrt(1 - a * a) + 1) + from
        }
    }

}

protocol WeakContextHasable {
    var context: AnyObject? { get }
}
class WeakContextContainer {
    static let shared = WeakContextContainer()
    private static let period: Double = 2.0 // 2초 주기
    private var targets = [WeakContextHasable]()
    init() {
        looper.invoke { (dsl) in
            dsl.isInfinity = true
            dsl.block = { item in
                item.start += WeakContextContainer.period
                for i in (0..<self.targets.count).reversed() {
                    if self.targets[i].context == nil {
                        self.targets.remove(at: i)
                    }
                }
                #if DEBUG
//                print("live context counts := \(self.targets.count)")
                #endif
            }
        }
    }
    func add(_ weakObj: WeakContextHasable) {
        targets.append(weakObj)
    }
}

class Flow {

    typealias VoidClosure = () -> Void
    typealias Sync  = (@escaping VoidClosure) -> Void
    typealias Async = (@escaping Sync) -> Void
    typealias Bundle = () -> Flow

    fileprivate class Block {
        static let EmptyBody = { }
        static let TypeAsync  = "async"
        static let TypeSync   = "sync"
        static let TypePause  = "pause"
        static let TypeBundle = "bundle"
        var type: String
        let body: Any
        var delay: () -> Double
        init(type: String, body: Any, delay: @escaping () -> Double = { 0 }) {
            self.type  = type
            self.body  = body
            self.delay = delay
        }
    }

    private var active = false
    fileprivate var blocks = [Block]()
    var seq: Looper.Sequence?

    @discardableResult
    func async(body: @escaping Async) -> Flow {
        blocks.append(Flow.Block(type: Block.TypeAsync, body: body))
        return self
    }
    @discardableResult
    func sync(body: @escaping VoidClosure) -> Flow {
        blocks.append(Flow.Block(type: Block.TypeSync, body: body))
        return self
    }
    @discardableResult
    func pause(
        duration: @escaping () -> Double,
        body: @escaping VoidClosure = Block.EmptyBody
    ) -> Flow {
        blocks.append(Flow.Block(type: Block.TypePause, body: body, delay: duration))
        return self
    }
    @discardableResult
    func bundle(body: @escaping Bundle) -> Flow {
        blocks.append(Flow.Block(type: Block.TypeBundle, body: body))
        return self
    }
    private func _start() {
        var sub: Flow?
        knitting: while blocks.count > 0 {
            let block = blocks.removeFirst()
            switch block.type {
            case Block.TypeAsync:
                let delay = block.delay
                let body  = block.body as! Async
                let dslBlock = getDSLBlock(delay: delay, body)
                seq  = seq?.next(dslBlock) ?? looper.invoke(dslBlock)
            case Block.TypeSync:
                let body = block.body as! VoidClosure
                let nBody: Async = { sync in sync(body) }
                blocks.insert(Flow.Block(type: Block.TypeAsync, body: nBody), at: 0)
            case Block.TypePause:
                let body = block.body as! VoidClosure
                let nBody: Async = { sync in sync(body) }
                blocks.insert(Flow.Block(type: Block.TypeAsync, body: nBody, delay: block.delay), at: 0)
            case Block.TypeBundle:
                let body = block.body as! Bundle
                sub = body()
                break knitting
            default: break
            }
        }
        if let sub = sub {
            if blocks.count > 0 {
                sub.blocks.append(
                    Flow.Block(
                        type: Block.TypeBundle,
                        body: { () -> Flow in self.seq = nil; return self }
                    )
                )
            }
            if seq?.current != nil {
                seq?.current?.ended = { _ in sub._start() }
            } else {
                sub._start()
            }
        }
    }
    func start() {
        guard !active else { return }
        active = true
        _start()
    }

    private func getDSLBlock(
        delay: @escaping () -> TimeInterval = { 0 },
        _ body: @escaping Async
    ) -> (Looper.Looper.ItemDSL) -> Void {
        { dsl in
            var waiting: TimeInterval!
            var started: Double!
            var completion: VoidClosure?
            body({ c in completion = c })
            dsl.isInfinity = true
            dsl.block = { item in
                if started == nil {
                    started = item.current
                    waiting = delay()
                }
                if completion != nil && item.current - started >= waiting {
                    completion?(); item.isStop = true
                }
            }
        }
    }
//    deinit { print("deinit Funnel") }
}

class Watcher {
    class Sequence<Who> where Who: AnyObject {
        weak var who: Who?
        private var _prev: Sequence<Who>?
        private weak var pause: Looper.Pause?
        fileprivate var _invalidate: VoidClosure?
        fileprivate init(who: Who?, pause: Looper.Pause?) { self.who = who; self.pause = pause }
        @discardableResult
        func watch<V>(
            _ keyPath: KeyPath<Who, V>,
            initValue: V? = nil,
            predicate: @escaping (V, V) -> Bool = { $0 != $1 },
            changeHandler: @escaping (Who, (V, V)) -> Void
        ) -> Sequence<Who> where Who: AnyObject, V: Equatable {
            _invalidate = Watcher.watch(pause: pause, who: who, keyPath, initValue: initValue, predicate: predicate, changeHandler: changeHandler)
            return also(Sequence(who: who, pause: pause)) { [weak self] in
                $0._prev = self
                $0._invalidate = self?._invalidate
            }
        }
        func invalidate() {
            _invalidate?()
        }
        func invalidateAll() {
            invalidate()
            _prev?.invalidateAll()
        }
    }
    static func who<Who>(_ who: Who?, pause: Looper.Pause? = nil) -> Sequence<Who> where Who: AnyObject {
        return Sequence(who: who, pause: pause)
    }
    @discardableResult
    private static func watch<Who, V>(
        pause: Looper.Pause?,
        who: Who?,
        _ keyPath: KeyPath<Who, V>,
        initValue: V? = nil,
        predicate: @escaping (V, V) -> Bool = { $0 != $1 },
        changeHandler: @escaping (Who, (V, V)) -> Void
    ) -> VoidClosure where Who: AnyObject, V: Equatable  {
        var isFinish = false
        looper.invoke(pause: pause) { [weak who] (dsl) in
            var oVal = initValue ?? who?[keyPath: keyPath]
            dsl.isInfinity = true
            dsl.block = { (item) in
                guard !isFinish else { item.isStop = true; return }
                switch who {
                case .none: item.isStop = true
                case .some(let who):
                    let nVal = who[keyPath: keyPath]
                    if let _oVal = oVal, predicate(_oVal, nVal) {
                        changeHandler(who, (_oVal, nVal))
                        oVal = nVal
                    }
                }
            }
            dsl.ended = { _ in
//                print("watch finished")
            }
        }
        return { isFinish = true }
    }
}
