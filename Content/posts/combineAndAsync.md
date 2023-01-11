---
date: 2021-12-06 08:12
description: 本文来聊聊 Combine 和 async/await 它们之间各自的优势、是否可以合作以及如何合作等问题。在 Xcode 13.2 中，苹果完成了 async/await 的向前部署（Back-deploying）工作，将最低的系统要求降低到了 iOS 13（macOS Catalina），这一举动鼓舞了越来越多的人开始尝试使用 async/await 进行开发。当大家在接触了异步序列（AsyncSequence）后，会发现它同 Combine 的表现有些接近，尤其结合近两年 Combine 框架几乎没有什么变化，不少人都提出了疑问：苹果是否打算使用 AsyncSequence 和 AsyncStream 替代 Combine。
tags: Combine,Swift,async/await
title: 聊聊 Combine 和 async/await 之间的合作
image: images/combineAndAsync.png
---
在 Xcode 13.2 中，苹果完成了 async/await 的向前部署（Back-deploying）工作，将最低的系统要求降低到了 iOS 13（macOS Catalina），这一举动鼓舞了越来越多的人开始尝试使用 async/await 进行开发。当大家在接触了异步序列（AsyncSequence）后，会发现它同 Combine 的表现有些接近，尤其结合近两年 Combine 框架几乎没有什么变化，不少人都提出了疑问：苹果是否打算使用 AsyncSequence 和 AsyncStream 替代 Combine。

恰巧我在最近的开发中碰到了一个可能需要结合 Combine 和 async/await 的使用场景，通过本文来聊聊 Combine 和 async/await 它们之间各自的优势、是否可以合作以及如何合作等问题。

```responser
id:1
```

## 需要解决的问题

在最近的开发中，我碰到了这样一个需求：

* 在 app 的生命周期中，会不定期的产生一系列事件，事件的发生频率不定、产生的途径不定
* 对每个事件的处理都需要消耗不小的系统资源，且需要调用系统提供的 async/await 版本的 API
* app 对事件的处理结果时效性要求不高
* 需要限制事件处理的系统消耗，避免同时处理多个事件
* 不考虑使用 GCD 或 OperationQueue

对上述的需求稍加分析，很快就可以确立解决问题的方向：

* Combine 在观察和接收事件方面表现的非常出色，应该是解决需求第一点的不二人选
* 在解决方案中必然会使用到 async/await 的编程模式

需要解决的问题就只剩下两个：

* 如何将事件处理串行化（必须处理完一个事件后才能处理下一个事件）
* 如何将 Combine 和 async/await 结合使用

## Combine 和 AsyncSequence 之间的比较

由于 Combine 同 AsyncSequence 之间存在不少相似之处，有不少开发者会认为 AsyncSequence 可能取代 Combine，例如：

* 两者都允许通过异步的方式处理未来的值
* 两者都允许开发者使用例如 map、flatMap 等函数对值进行操作
* 当发生错误时，两者都会结束数据流

但事实上，它们之间还是有相当的区别。

### 事件的观察与接收

Combine 是为响应式编程而生的工具，从名称上就可以看出，它非常擅长将不同的事件流进行变形和合并，生成新的事件流。Combine 关注于对变化的响应。当一个属性发生变化，一个用户点击了按钮，或者通过 NotificationCenter 发送了一个通知，开发者都可以通过 Combine 提供了的内置工具做出及时处理。

通过 Combine 提供的 Subject（PassthroughSubject、CurrentValueSubject），开发者可以非常方便的向数据流中注入值，当你的代码是以命令式风格编写的时候，Subject 就尤为显得有价值。

在 async/await 中，通过 AsyncSequence，我们可以观察并接收网络流、文件、Notification 等方面的数据，但相较于 Combine，仍缺乏数据绑定以及类似 Subject 的数据注入能力。

在对事件的观察与接收方面，Combine 占有较大优势。

### 关于数据处理、变形的能力

仅从用于数据处理、变形的方法数量上来看，AsyncSequence 相较 Combine 还是有不小的差距。但 AsyncSequence 也提供了一些 Combine 尚未提供，且非常实用的方法和变量，例如：characters、lines 等。

由于侧重点不同，即使随着时间的推移两者增加了更多的内置方法，在数据处理和变形方面也不会趋于一致，更大的可能性是不断地在各自擅长的领域进行扩展。

### 错误处理方式

在 Combine 中，明确地规定了错误值 Failure 的类型，在数据处理链条中，除了要求 Output 数据值类型一致外，还要求错误值的类型也要相互匹配。为了实现这一目标，Combine 提供了大量的用于处理错误类型的操作方法，例如：mapError、setFailureType、retry 等。

使用上述方法处理错误，可以获得编译器级别的保证优势，但在另一方面，对于一个逻辑复杂的数据处理链，上述的错误处理方式也将导致代码的可读性显著下降，对开发者在错误处理方面的掌握要求也比较高。

async/await 则采用了开发者最为熟悉的 throw-catch 方式来进行错误处理。基本没有学习难度，代码也更符合大多数人的阅读习惯。

两者在错误处理上功能没有太大区别，主要体现在处理风格不同。

### 生命周期的管理

在 Combine 中，从订阅开始，到取消订阅，开发者通过代码可以对数据链的生命周期做清晰的定义。当使用 AsyncSequence 时，异步序列生命周期的表述则没有那么的明确。

### 调度与组织

在 Combine 中，开发者不仅可以通过指定调度器（scheduler），显式地组织异步事件的行为和地点，而且 Combine 还提供了控制管道数量、调整处理频率等多维度的处理手段。

AsyncSequence 则缺乏对于数据流的处理地点、频率、并发数量等控制能力。

> 下文中，我们将尝试解决前文中提出的需求，每个解决方案均采用了 Combine + async/await 融合的方式。

## 方案一

在 Combine 中，可以使用两种手段来限制数据的并发处理能力，一种是通过设定 flatMap 的 maxPublishers，另一种则是通过自定义 Subscriber。本方案中，我们将采用 flatMap 的方式来将事件的处理串行化。

在 Combine 中调用异步 API，目前官方提供的方法是将上游数据包装成 Future Publisher，并通过 flatMap 进行切换。

在方案一中，通过将 flatMap、Deferred（确保只有在订阅后 Future 才执行）、Future 结合到一起，创建一个新的 Operator，以实现我们的需求。

```swift
public extension Publisher {
    func task<T>(maxPublishers: Subscribers.Demand = .unlimited,
                     _ transform: @escaping (Output) async -> T) -> Publishers.FlatMap<Deferred<Future<T, Never>>, Self> {
        flatMap(maxPublishers: maxPublishers) { value in
            Deferred {
                Future { promise in
                    Task {
                        let output = await transform(value)
                        promise(.success(output))
                    }
                }
            }
        }
    }
}

public extension Publisher where Self.Failure == Never {
    func emptySink() -> AnyCancellable {
        sink(receiveValue: { _ in })
    }
}
```

> 鉴于篇幅，完整的代码（支持 Error、SetFailureType）版本，请访问 [Gist](https://gist.github.com/fatbobman/45ead2eac52c5f6f18f9f51cf294745f)，本方案的代码参考了 Sundell 的 [文章](https://www.swiftbysundell.com/articles/calling-async-functions-within-a-combine-pipeline/)。

使用方法如下：

```swift
var cancellables = Set<AnyCancellable>()

func asyncPrint(value: String) async {
    print("hello \(value)")
    try? await Task.sleep(nanoseconds: 1000000000)
}

["abc","sdg","353"].publisher
    .task(maxPublishers:.max(1)){ value in
        await asyncPrint(value:value)
    }
    .emptySink()
    .store(in: &cancellables)
// Output
// hello abc
// 等待 1 秒
// hello sdg
// 等待 1 秒
// hello 353
```

假如将将上述代码中的`["abc","sdg","353"].publisher`更换成 PassthoughSubject 或 Notification ，会出现数据遗漏的情况。这个状况是因为我们限制了数据的并行处理数量，从而导致数据的消耗时间超过了数据的生成时间。需要在 Publisher 的后面添加 buffer，对数据进行缓冲。

```swift
let publisher = PassthroughSubject<String, Never>()
publisher
    .buffer(size: 10, prefetch: .keepFull, whenFull: .dropOldest) // 缓存数量和策略根据业务的具体情况确定
    .task(maxPublishers: .max(1)) { value in
        await asyncPrint(value:value)
    }
    .emptySink()
    .store(in: &cancellables)

publisher.send("fat")
publisher.send("bob")
publisher.send("man")
```

```responser
id:1
```

## 方案二

在方案二中，我们将采用的自定义 Subscriber 的方式来限制并行处理的数量，并尝试在 Subscriber 中调用 async/await 方法。

创建自定义 Subscriber：

```swift
extension Subscribers {
    public class OneByOneSink<Input, Failure: Error>: Subscriber, Cancellable {
        let receiveValue: (Input) -> Void
        let receiveCompletion: (Subscribers.Completion<Failure>) -> Void

        var subscription: Subscription?

        public init(receiveCompletion: @escaping (Subscribers.Completion<Failure>) -> Void,
             receiveValue: @escaping (Input) -> Void) {
            self.receiveCompletion = receiveCompletion
            self.receiveValue = receiveValue
        }

        public func receive(subscription: Subscription) {
            self.subscription = subscription
            subscription.request(.max(1)) // 订阅时申请数据量
        }

        public func receive(_ input: Input) -> Subscribers.Demand {
            receiveValue(input)
            return .max(1) // 数据处理结束后，再此申请的数据量
        }

        public func receive(completion: Subscribers.Completion<Failure>) {
            receiveCompletion(completion)
        }

        public func cancel() {
            subscription?.cancel()
            subscription = nil
        }
    }
}
```

在`receive(subscription: Subscription)`中，使用`subscription.request(.max(1))`设定了订阅者订阅时请求的数据量，在`receive(_ input: Input)`中，使用`return .max(1)`设定了每次执行完`receiveValue`方法后请求的数据量。通过上述方式，我们创建了一个每次申请一个值，逐个处理的订阅者。

但当我们在`receiveValue`方法中使用 Task 调用 async/await 代码时会发现，由于没有提供回调机制，订阅者将无视异步代码执行完成与否，调用后直接会申请下一个值，这与我们的需求不符。

在 Subscriber 中可以通过多种方式来实现回调机制，例如回调方法、Notification、@Published 等。下面的代码中我们使用 Notification 进行回调通知。

```swift
public extension Subscribers {
    class OneByOneSink<Input, Failure: Error>: Subscriber, Cancellable {
        let receiveValue: (Input) -> Void
        let receiveCompletion: (Subscribers.Completion<Failure>) -> Void

        var subscription: Subscription?
        var cancellable: AnyCancellable?

        public init(notificationName: Notification.Name,
                    receiveCompletion: @escaping (Subscribers.Completion<Failure>) -> Void,
                    receiveValue: @escaping (Input) -> Void) {
            self.receiveCompletion = receiveCompletion
            self.receiveValue = receiveValue
            cancellable = NotificationCenter.default.publisher(for: notificationName, object: nil)
                .sink(receiveValue: { [weak self] _ in self?.resume() })
                // 在收到回调通知后，继续向 Publisher 申请新值
        }

        public func receive(subscription: Subscription) {
            self.subscription = subscription
            subscription.request(.max(1))
        }

        public func receive(_ input: Input) -> Subscribers.Demand {
            receiveValue(input)
            return .none // 调用函数后不继续申请新值
        }

        public func receive(completion: Subscribers.Completion<Failure>) {
            receiveCompletion(completion)
        }

        public func cancel() {
            subscription?.cancel()
            subscription = nil
        }

        private func resume() {
            subscription?.request(.max(1))
        }
    }
}

public extension Publisher {
    func oneByOneSink(
        _ notificationName: Notification.Name,
        receiveCompletion: @escaping (Subscribers.Completion<Failure>) -> Void,
        receiveValue: @escaping (Output) -> Void
    ) -> Cancellable {
        let sink = Subscribers.OneByOneSink<Output, Failure>(
            notificationName: notificationName,
            receiveCompletion: receiveCompletion,
            receiveValue: receiveValue
        )
        self.subscribe(sink)
        return sink
    }
}

public extension Publisher where Failure == Never {
    func oneByOneSink(
        _ notificationName: Notification.Name,
        receiveValue: @escaping (Output) -> Void
    ) -> Cancellable where Failure == Never {
        let sink = Subscribers.OneByOneSink<Output, Failure>(
            notificationName: notificationName,
            receiveCompletion: { _ in },
            receiveValue: receiveValue
        )
        self.subscribe(sink)
        return sink
    }
}
```

调用：

```swift
let resumeNotification = Notification.Name("resume")

publisher
    .buffer(size: 10, prefetch: .keepFull, whenFull: .dropOldest)
    .oneByOneSink(
        resumeNotification,
        receiveValue: { value in
            Task {
                await asyncPrint(value: value)
                NotificationCenter.default.post(name: resumeNotification, object: nil)
            }
        }
    )
    .store(in: &cancellables)
```

由于需要回调才能完成整个处理逻辑，针对本文需求，方案一相较方案二明显更优雅。

方案二中，数据处理链是可暂停的，很适合用于需要触发某种条件才可继续执行的场景。

## 方案三

在前文中提到过，苹果已经为 Notification 提供了 AsyncSequence 的支持。如果我们只通过 NotificationCenter 来发送事件，下面的代码就直接可以满足我们的需求：

```swift
let n = Notification.Name("event")
Task {
    for await value in NotificationCenter.default.notifications(named: n, object: nil) {
        if let str = value.object as? String {
            await asyncPrint(value: str)
        }
    }
}

NotificationCenter.default.post(name: n, object: "event1")
NotificationCenter.default.post(name: n, object: "event2")
NotificationCenter.default.post(name: n, object: "event3")
```

简单的难以想象是吗？

遗憾的是，Combine 的 Subject 和其他的 Publishe 并没有直接遵循 AsyncSequence 协议。

但今年的 Combine 为 Publisher 增加了一个非常小但非常重要的功能——values。

values 的类型为 AsyncPublisher，其符合 AsyncSequence 协议。设计的目的就是将 Publisher 转换成 AsyncSequence。使用下面的代码便可以满足各种 Publisher 类型的需求：

```swift
let publisher = PassthroughSubject<String, Never>()
let p = publisher
        .buffer(size: 10, prefetch: .keepFull, whenFull: .dropOldest)
Task {
    for await value in p.values {
        await asyncPrint(value: value)
    }
}
```

因为 AsyncSequence 只能对数据逐个处理，因此我们无需再考虑数据的串行问题。

将 Publisher 转换成 AsyncSequence 的原理并不复杂，创建一个符合 AsyncSequence 的结构，将从 Publihser 中获取的数据通过 AsyncStream 转送出去，并将迭代器指向 AsyncStream 的迭代器即可。

我们可以用代码自己实现上面的 values 功能。下面我们创建了一个 sequence，功能表现同 values 类似。

```swift
public struct CombineAsyncPublsiher<P>: AsyncSequence, AsyncIteratorProtocol where P: Publisher, P.Failure == Never {
    public typealias Element = P.Output
    public typealias AsyncIterator = CombineAsyncPublsiher<P>

    public func makeAsyncIterator() -> Self {
        return self
    }

    private let stream: AsyncStream<P.Output>
    private var iterator: AsyncStream<P.Output>.Iterator
    private var cancellable: AnyCancellable?

    public init(_ upstream: P, bufferingPolicy limit: AsyncStream<Element>.Continuation.BufferingPolicy = .unbounded) {
        var subscription: AnyCancellable?
        stream = AsyncStream<P.Output>(P.Output.self, bufferingPolicy: limit) { continuation in
            subscription = upstream
                .sink(receiveValue: { value in
                    continuation.yield(value)
                })
        }
        cancellable = subscription
        iterator = stream.makeAsyncIterator()
    }

    public mutating func next() async -> P.Output? {
        await iterator.next()
    }
}

public extension Publisher where Self.Failure == Never {
    var sequence: CombineAsyncPublsiher<Self> {
        CombineAsyncPublsiher(self)
    }
}
```

> 完整代码，请参阅 [Gist](https://gist.github.com/fatbobman/09954daa67f8f78cb11c0ff9f8bcb318)，本例的代码参考了 Marin Todorov 的 [文章](https://trycombine.com/posts/combine-async-sequence-1/)

sequence 在实现上和 values 还是有微小的不同的，如果感兴趣的朋友可以使用下面的代码，分析一下它们的不同点。

```swift
let p = publisher
    .print()  // 观察订阅器的请求情况。 values 的实现同方案二一样。
    // sequence 使用了 AsyncStream 的 buffer，因此无需再设定 buffer

for await value in p.sequence {
    await asyncPrint(value: value)
}
```

## 总结

在可以预见的未来，苹果一定会为 Combine 和 async/await 提供更多的预置融合手段。或许明后年，前两种方案就可以直接使用官方提供的 API 了。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。

