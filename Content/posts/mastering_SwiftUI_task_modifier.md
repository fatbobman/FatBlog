---
date: 2022-08-09 08:12
description: 随着 Swift 5.5 引入了 async/await 特性，苹果也为 SwiftUI 添加了 task 视图修饰器，以方便开发者在视图中使用基于 async/await 的异步代码。本文将对 task 视图修饰器的特点、用法、注意事项等内容做以介绍，并提供了将其移植到老版本 SwiftUI 的方法。
tags: SwiftUI
title: 掌握 SwiftUI 的 task 修饰器
image: images/mastering_SwiftUI_task_modifier.png
---
随着 Swift 5.5 引入了 async/await 特性，苹果也为 SwiftUI 添加了 task 视图修饰器，以方便开发者在视图中使用基于 async/await 的异步代码。本文将对 task 视图修饰器的特点、用法、注意事项等内容做以介绍，并提供了将其移植到老版本 SwiftUI 的方法。

```responser
id:1
```

## task vs onAppear

SwiftUI 提供了两个版本的 task 修饰器，版本一的作用和调用时机与 onAppear 十分类似：

```swift
public func task(priority: TaskPriority = .userInitiated, _ action: @escaping @Sendable () async -> Void) -> some View
```

![image-20220806084339042](https://cdn.fatbobman.com/image-20220806084339042.png)

![image-20220806084436930](https://cdn.fatbobman.com/image-20220806084436930.png)

通过 task 修饰器开发者可以添加在视图“出现之前”的异步操作。

> 用 “出现之前” 来描述 onAppear 或 task 闭包的调用时机属于无奈之举。在不同的上下文中，“出现之前”会有不同的解释。详情请参阅 [SwiftUI 视图的生命周期研究](https://www.fatbobman.com/posts/swiftUILifeCycle/#onAppear_和_onDisappear) 一文中有关 onAppear 和 onDisappear 的章节

SwiftUI 为了判断视图的状态是否发生了改变，它会在视图的存续期内，反复地生成视图类型实例以达成此目的。因此，开发者应避免将一些会对性能造成影响的操作放置在视图类型的构造函数之中，而是在 onAppear 或 task 中进行该类型的操作。

```swift
struct TaskDemo1:View{
    @State var message:String?
    let url = URL(string:"https://news.baidu.com/")!
    var body: some View{
        VStack {
            if let message = message {
                Text(message)
            } else {
                ProgressView()
            }
        }
        .task {  // VStack “出现之前” 执行闭包中的代码
            do {
                var lines = 0
                for try await _ in url.lines { // 读取指定 url 的内容
                    lines += 1
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 模拟更复杂的任务
                message = "Received \(lines) lines"
            } catch {
                message = "Failed to load data"
            }
        }
    }
}
```

我们可以通过 priority 参数来设定创建异步任务时要使用的任务优先级（ 默认优先级为 userInitiated ）。

```swift
.task(priority: .background) {
    // do something
}
```

> 任务优先级并不会影响创建任务所使用的线程

## task vs onChange

另一个版本的 task 修饰器则提供了类似 onChange + onAppear 的联合能力。

```swift
public func task<T>(id value: T, priority: TaskPriority = .userInitiated, _ action: @escaping @Sendable () async -> Void) -> some View where T : Equatable
```

除了在视图“出现之前”执行一次异步任务外，还会在其观察的值（ 符合 Equatable 协议 ）发生变化时，重新执行一次任务（ 创建一个新的异步任务 ）：

```swift
struct TaskDemo2: View {
    @State var status: Status = .loading
    @State var reloadTrigger = false
    let url = URL(string: "https://source.unsplash.com/400x300")! // 获取随机图片的地址
    var body: some View {
        VStack {
            Group {
                switch status {
                case .loading:
                    Rectangle()
                        .fill(.secondary)
                        .overlay(Text("Loading"))
                case .image(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .error:
                    Rectangle()
                        .fill(.secondary)
                        .overlay(Text("Failed to load image"))
                }
            }
            .padding()
            .frame(width: 400, height: 300)

            Button(status.loading ? "Loading" : "Reload") {
                reloadTrigger.toggle()  // 读取新图
            }
            .disabled(status.loading)
            .buttonStyle(.bordered)
        }
        .animation(.easeInOut, value: status)
        .task(id: reloadTrigger) { // 在 VStack “出现之前” 以及当 reloadTrigger 发生变化时，执行如下内容。
            do {
                status = .loading
                var bytes = [UInt8]()
                for try await byte in url.resourceBytes {
                    bytes.append(byte)
                }
                if let uiImage = UIImage(data: Data(bytes)) {
                    let image = Image(uiImage: uiImage)
                    status = .image(image)
                } else {
                    status = .error
                }
            } catch {
                status = .error
            }
        }
    }

    enum Status: Equatable {
        case loading
        case image(Image)
        case error

        var loading: Bool {
            switch self {
            case .loading:
                return true
            default:
                return false
            }
        }
    }
}
```

![task_onChange_Recording_iPhone_12_Pro_15.5_2022-08-06_10.50.13.2022-08-06 10_51_57](https://cdn.fatbobman.com/task_onChange_Recording_iPhone_12_Pro_15.5_2022-08-06_10.50.13.2022-08-06%2010_51_57.gif)

> 请阅读 [了解 SwiftUI 的 onChange](https://www.fatbobman.com/posts/onChange/) 一文 ，掌握更多有关 onChang 修饰器的知识

## task 的生命周期

上文中的两段演示代码，即使算上网络延迟， task 闭包的运行持续时间也不会太长。这并没有充分发挥 task 的优势，因为我们还可以用 task 修饰器创建可以持续运行的异步任务：

```swift
struct TimerView:View{
    @State var date = Date.now
    @State var show = true
    var body: some View{
        VStack {
            Button(show ? "Hide Timer" : "Show Timer"){
                show.toggle()
            }
            if show {
                Text(date,format: .dateTime.hour().minute().second())
                    .task {
                        let taskID = UUID()  // 任务 ID
                        while true { // 持续运行
                            try? await Task.sleep(nanoseconds: 1_000_000_000) // 间隔一秒
                            let now = Date.now // 每隔一秒更新一次时间
                            date = now
                            print("Task ID \(taskID) :\(now.formatted(date: .numeric, time: .complete))")
                        }
                    }
            }
        }
    }
}
```

这段代码将通过 task 修饰器创建一个持续运行的异步任务，每秒更新一次 date 变量，并且在控制台中显示当前的任务 ID 及时间。

![task_longrun1_2022-08-07_09.07.44.2022-08-07 09_09_38](https://cdn.fatbobman.com/task_longrun1_2022-08-07_09.07.44.2022-08-07%2009_09_38.gif)

我们的本意是通过按钮来开启和关闭计时器的显示以控制任务的生命周期（ 关闭时结束任务 ），但在点击 Hide Timer 按钮后，app 出现了无法响应且控制台仍在持续输出（ 不按照原定的间隔时间 ）的情况，为什么会出现这样的问题呢？

> app 无法响应是由于当前 task 是在主线程上运行的，如果按照下文中的方法将 task 运行在后台线程之中，那么 app 将可以继续响应，但会在不显示日期文字的情况下，继续更新 date 变量，并且会在控制台持续输出

Swift 采用的是协作式任务取消机制，也就是说，SwiftUI 是无法直接停止掉我们通过 task 修饰器创建的异步任务的。当满足了需要停止由 task 修饰器创建的异步任务条件时，SwiftUI 会给该任务发送任务取消信号，任务必须自行响应该信号并停止作业。

在以下两种情况下，SwiftUI 会给由 task 创建的异步任务发送任务取消信号：

* 视图（ task 修饰器绑定的视图 ）满足 onDisappear 触发条件时
* 绑定的值发生变化时（ 采用 task 观察值变化时 ）

为了让之前的代码可以响应取消信号，我们需做如下调整：

```swift
// 将
while true {
// 修改成 
while !Task.isCancelled { // 仅在当前任务没被取消时执行以下代码
```

![task_longrun2_2022-08-07_09.39.21.2022-08-07 09_40_53](https://cdn.fatbobman.com/task_longrun2_2022-08-07_09.39.21.2022-08-07%2009_40_53.gif)

开发者也可以利用 Swift 这种协作式取消的机制来实现一些类似 onDisappear 的操作。

```swift
.task {
    let taskID = UUID()
    defer {
        print("Task \(taskID) has been cancelled.")
        // 做一些数据的善后工作
    }
    while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 1000000000)
        let now = Date.now
        date = now
        print("Task ID \(taskID) :\(now.formatted(date: .numeric, time: .complete))")
    }
}
```

## task 运行的线程

使用 task 修饰器在视图中创建异步任务，除了方便使用基于 async/await 语法的 API 外，开发者也希望能够让这些任务运行在后台线程中，以减少主线程的负担。

非常遗憾，当前上文中所有的使用 task 创建的异步任务都是运行在主线程当中的。你可以通过在闭包中添加如下语句查看当前任务运行的线程：

```swift
print(Thread.current)

// <_NSMainThread: 0x6000011d0b80>{number = 1, name = main}
```

为什么会出现这样的情况呢？task 为什么没有默认运行在后台线程中？

> 使用 url.lines 和 url.resourceBytes 获取网络数据时，系统 API 会跳转到后台线程，不过最终仍会回到主线程上

想要了解并解决这个问题，我们还要从 task 修饰器的定义中入手。以下是 task 修饰器更加完整的定义（ 从 swiftinterface 文件中获得 ）：

```swift
@inlinable public func task(priority: _Concurrency.TaskPriority = .userInitiated, @_inheritActorContext _ action: @escaping @Sendable () async -> Swift.Void) -> some SwiftUI.View {
    modifier(_TaskModifier(priority: priority, action: action))
}
```

其中 `@_inheritActorContext` 编译属性将为我们带来答案。

![image-20220807111608120](https://cdn.fatbobman.com/image-20220807111608120.png)

当一个 `@Sendable async` 闭包被标记 `@_inheritActorContext` 属性后，闭包将根据其声明的地点来继承 actor 上下文（ 即它应该在哪个 actor 上运行 ）。那些没有特别声明需运行在某特定 actor 上的闭包，它们可以运行于任意地点（ 任何的线程之中 ）。

回到当前的问题，由于 View 协议限定了 body 属性必须运行于主线程中（ 使用了 @MainActor 进行标注 ），因此，如果我们直接在 body 中为 task 修饰器添加闭包代码，那么该闭包只能运行于主线程中（ 闭包继承了 body 的 actor 上下文 ）。

```swift
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol View {
    associatedtype Body : View
    @ViewBuilder @MainActor var body: Self.Body { get }
}
```

如果我们想让 task 修饰器中的闭包不运行在主线程上，只需要将其声明在没有要求运行于 @MainActor 的地方即可。例如，将上面的计时器代码修改为：

```swift
struct TimerView: View {
    @State var date = Date.now
    @State var show = true
    var body: some View {
        VStack {
            Button(show ? "Hide Timer" : "Show Timer") {
                show.toggle()
            }
            if show {
                Text(date, format: .dateTime.hour().minute().second())
                    .task(timer) 
            }
        }
    }

    // 在 body 外面定义异步函数
    @Sendable
    func timer() async {
        let taskID = UUID()
        print(Thread.current)
        defer {
            print("Task \(taskID) has been cancelled.")
            // 做一些数据的善后工作
        }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1000000000)
            let now = Date.now
            date = now
            print("Task ID \(taskID) :\(now.formatted(date: .numeric, time: .complete))")
        }
    }
}
```

![task_thread1_2022-08-07_15.21.25.2022-08-07 15_23_01](https://cdn.fatbobman.com/task_thread1_2022-08-07_15.21.25.2022-08-07%2015_23_01.gif)

> 务必注意，如果将 `.task(timer)` 写为 `.task{ await timer() }` ，则仍会运行于主线程中

如果你的视图中声明了其他符合 DynamicProperty 协议的 Source of Truth （ **将 wrappedValue 和 projectedValue 标注为 @MainActor** ），那么上面的方法将不再适用。因为 **SwiftUI 会将视图类型的实例默认推断为标注了 @MainActor ，并限定运行于主线程（ 不仅仅是 body 属性 ）**。

```swift
struct TimerView: View {
    @State var date = Date.now
    @State var show = true
    // 在 StateObject 的定义中，wrappedValue 和 projectedValue 被标注了 @MainActor
    @StateObject var testObject = TestObject() // 导致 SwiftUI 会将视图类型的实例默认推断为运行于主线程
    var body: some View {
        VStack {
            Button(show ? "Hide Timer" : "Show Timer") {
                show.toggle()
            }
            if show {
                Text(date, format: .dateTime.hour().minute().second())
                    .task(timer) 
            }
        }
    }

    // 在 body 外面定义异步函数
    @Sendable
    func timer() async {
       print(Thread.current) // 仍然会运行于主线程
       ....
    }
}
```

我们可以通过将异步方法移到视图类型之外来解决这个问题。

SwiftUI 对 @State 做了特别的处理，我们可以在任意线程中对其进行安全的修改。但对于其他符合 DynamicProperty 协议的 Source of Truth （ 将 wrappedValue 和 projectedValue 标注为 @MainActor ），在修改前必须切换到主线程上：

```swift
struct TimerView: View {
    @StateObject var object = TestObject()

    var body: some View {
        VStack {
            Button(object.show ? "Hide Timer" : "Show Timer") {
                object.show.toggle()
            }
            if object.show {
                Text(object.date, format: .dateTime.hour().minute().second())
                    .task(object.timer)
            }
        }
    }
}

class TestObject: ObservableObject {
    @Published var date: Date = .now
    @Published var show = true

    @Sendable
    func timer() async {
        let taskID = UUID()
        print(Thread.current)
        defer {
            print("Task \(taskID) has been cancelled.")
            // 做一些数据的善后工作
        }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1000000000)
            let now = Date.now
            await MainActor.run { // 需要切换回主线程
                date = now
            }
            print("Task ID \(taskID) :\(now.formatted(date: .numeric, time: .complete))")
        }
    }
}

```

```responser
id:1
```

## task vs onReceive

通常，我们会用 onReceive 修饰器在视图中响应 Notification Center 的消息。作为一个事件源类型的 Source of Truth，每当接收到一个新的消息时，它都会导致 SwiftUI 对视图的 body 重新求值。

> 请阅读 [避免 SwiftUI 视图的重复计算](https://www.fatbobman.com/posts/avoid_repeated_calculations_of_SwiftUI_views/) 一文，以了解更多有关事件源方面的内容

如果，你想有选择性的处理消息，可以考虑用 task 来代替 onReceive，例如：

```swift
struct NotificationHandlerDemo: View {
    @State var message = ""
    var body: some View {
        Text(message)
            .task(notificationHandler)
    }

    @Sendable
    func notificationHandler() async {
        for await notification in NotificationCenter.default.notifications(named: .messageSender) where !Task.isCancelled {
            // 判断是否满足特定条件
            if let message = notification.object as? String, condition(message) {
                self.message = message
            }
        }
    }

    func func condition(_ message: String) -> Bool { message.count > 10 }
}

extension Notification.Name {
    static let messageSender = Notification.Name("messageSender")
}
```

在当前场景中，使用 task 替换 onReceive 可以获得两个好处：

* 减少视图不必要的刷新（ 避免重复计算 ）
* 在后台线程响应消息，减少主线程的负荷

> 请注意！task 并不能完全取代 onReceive。对于某些视图（ 在惰性容器中的视图、处在 TabView 中的视图等 ），它们可能会反复满足 onAppear 和 onDisappear 的触发条件（ 滚动出屏幕外、在不同的 Tab 中切换 ）。如此一来，运行在 task 中的 notificationHandler 并不会持续运行。但对于 onRecevie，即使视图触发了 onDisappear ，但只要视图的仍然存续，那么就会持续执行闭包中的操作（ 不会丢失必要的信息 ）。

## 为老版本的 SwiftUI 添加 task 修饰器

当前，Swift 已经将 async/await 特性向后移植至 iOS 13，但并没有在低版本的 SwiftUI 中提供 task 修饰器（ 原生的 task 修饰器最低要求 iOS 15 ）。

在了解了两个版本的 task 修饰器的工作原理和调用机制后，为老版本的 SwiftUI 添加 task 修饰器将不再有任何困难。

```swift
#if canImport(_Concurrency)
import _Concurrency
import Foundation
import SwiftUI

public extension View {
    @available(iOS, introduced: 13.0, obsoleted: 15.0)
    func task(priority: TaskPriority = .userInitiated, @_inheritActorContext _ action: @escaping @Sendable () async -> Void) -> some View {
        modifier(_MyTaskModifier(priority: priority, action: action))
    }

    @available(iOS, introduced: 14.0, obsoleted: 15.0)
    func task<T>(id value: T, priority: TaskPriority = .userInitiated, @_inheritActorContext _ action: @escaping @Sendable () async -> Void) -> some View where T: Equatable {
        modifier(_MyTaskValueModifier(value: value, priority: priority, action: action))
    }
}

@available(iOS 13,*)
struct _MyTaskModifier: ViewModifier {
    @State private var currentTask: Task<Void, Never>?
    let priority: TaskPriority
    let action: @Sendable () async -> Void

    @inlinable public init(priority: TaskPriority, action: @escaping @Sendable () async -> Void) {
        self.priority = priority
        self.action = action
    }

    public func body(content: Content) -> some View {
        content
            .onAppear {
                currentTask = Task(priority: priority, operation: action)
            }
            .onDisappear {
                currentTask?.cancel()
            }
    }
}

@available(iOS 13,*)
struct _MyTaskValueModifier<Value>: ViewModifier where Value: Equatable {
    var action: @Sendable () async -> Void
    var priority: TaskPriority
    var value: Value
    @State private var currentTask: Task<Void, Never>?

    public init(value: Value, priority: TaskPriority, action: @escaping @Sendable () async -> Void) {
        self.action = action
        self.priority = priority
        self.value = value
    }

    public func body(content: Content) -> some View {
        content
            .onAppear {
                currentTask = Task(priority: priority, operation: action)
            }
            .onDisappear {
                currentTask?.cancel()
            }
            .onChange(of: value) { _ in
                currentTask?.cancel()
                currentTask = Task(priority: priority, operation: action)
            }
    }
}
#endif
```

> 你可以自行添加一个 onChange 的向后移植版本（ 支持 iOS 13 ），让第二个版本的 task 修饰器（ onAppear + onChange ）支持到 iOS 13

## 总结

task 修饰器将 async/await 和 SwiftUI 视图的生命周期连接起来，让开发者可以在视图中高效地构建复杂的异步任务。但过度地通过 task 修饰器在视图声明中对副作用进行控制，也会对视图的纯粹度、可测试度、复用性等造成影响。开发者应拿捏好使用的分寸。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
