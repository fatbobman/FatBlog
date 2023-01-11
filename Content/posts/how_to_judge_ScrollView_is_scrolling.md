---
date: 2022-09-13 08:12
description: 判断一个可滚动控件（ ScrollView、List ）是否处于滚动状态在某些场景下具有重要的作用。比如在  SwipeCell 中，需要在可滚动组件开始滚动时，自动关闭已经打开的侧滑菜单。遗憾的是，SwiftUI 并没有提供这方面的 API 。本文将介绍几种在 SwiftUI 中获取当前滚动状态的方法，每种方法都有各自的优势和局限性。
tags: SwiftUI
title: 如何判断 ScrollView、List 是否正在滚动中
image: images/how_to_judge_ScrollView_is_scrolling.png
---
判断一个可滚动控件（ ScrollView、List ）是否处于滚动状态在某些场景下具有重要的作用。比如在  [SwipeCell](https://github.com/fatbobman/SwipeCell) 中，需要在可滚动组件开始滚动时，自动关闭已经打开的侧滑菜单。遗憾的是，SwiftUI 并没有提供这方面的 API 。本文将介绍几种在 SwiftUI 中获取当前滚动状态的方法，每种方法都有各自的优势和局限性。

![isScrolling_2022-09-12_10.26.06.2022-09-12 10_28_09](https://cdn.fatbobman.com/isScrolling_2022-09-12_10.26.06.2022-09-12%2010_28_09.gif)

## 方法一：Introspect

> 可在 [此处](https://github.com/fatbobman/BlogCodes/tree/main/ScrollStatus) 获取本节的代码

在 UIKit（ AppKit ）中，开发者可以通过 Delegate 的方式获知当前的滚动状态，主要依靠以下三个方法：

* `scrollViewDidScroll(_ scrollView: UIScrollView)`

  开始滚动时调用此方法

* `scrollViewDidEndDecelerating(_ scrollView: UIScrollView)`

  手指滑动可滚动区域后（ 此时手指已经离开 ），滚动逐渐减速，在滚动停止时会调用此方法

* `scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool)`

  手指拖动结束后（ 手指离开时 ），调用此方法

在 SwiftUI 中，很多的视图控件是对 UIKit（ AppKit ）控件的二次包装。因此，我们可以通过访问其背后的 UIKit 控件的方式（ 使用 [Introspect](https://github.com/siteline/SwiftUI-Introspect) ）来实现本文的需求。

```swift
final class ScrollDelegate: NSObject, UITableViewDelegate, UIScrollViewDelegate {
    var isScrolling: Binding<Bool>?

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let isScrolling = isScrolling?.wrappedValue,!isScrolling {
            self.isScrolling?.wrappedValue = true
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if let isScrolling = isScrolling?.wrappedValue, isScrolling {
            self.isScrolling?.wrappedValue = false
        }
    }

    // 手指缓慢拖动可滚动控件，手指离开后，decelerate 为 false，因此并不会调用 scrollViewDidEndDecelerating 方法
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            if let isScrolling = isScrolling?.wrappedValue, isScrolling {
                self.isScrolling?.wrappedValue = false
            }
        }
    }
}

extension View {
    func scrollStatusByIntrospect(isScrolling: Binding<Bool>) -> some View {
        modifier(ScrollStatusByIntrospectModifier(isScrolling: isScrolling))
    }
}

struct ScrollStatusByIntrospectModifier: ViewModifier {
    @State var delegate = ScrollDelegate()
    @Binding var isScrolling: Bool
    func body(content: Content) -> some View {
        content
            .onAppear {
                self.delegate.isScrolling = $isScrolling
            }
            // 同时支持 ScrollView 和 List
            .introspectScrollView { scrollView in
                scrollView.delegate = delegate
            }
            .introspectTableView { tableView in
                tableView.delegate = delegate
            }
    }
}
```

调用方法：

```swift
struct ScrollStatusByIntrospect: View {
    @State var isScrolling = false
    var body: some View {
        VStack {
            Text("isScrolling: \(isScrolling1 ? "True" : "False")")
            List {
                ForEach(0..<100) { i in
                    Text("id:\(i)")
                }
            }
            .scrollStatusByIntrospect(isScrolling: $isScrolling)
        }
    }
}
```

### 方案一优点

* 准确
* 及时
* 系统负担小

### 方案一缺点

* 向后兼容性差

  SwiftUI 随时可能会改变控件的内部实现方式，这种情况已经多次出现。目前 SwiftUI 在内部的实现上去 UIKit（ AppKit ）化很明显，比如，**本节介绍的方法在 SwiftUI 4.0 中已经失效**

```responser
id:1
```

## 方法二：Runloop

> 我第一次接触 Runloop 是在学习 Combine 的时候，直到我碰到 Timer 的闭包并没有按照预期被调用时才对其进行了一定的了解

Runloop 是一个事件处理循环。当没有事件时，Runloop 会进入休眠状态，而有事件时，Runloop 会调用对应的 Handler。

Runloop 与线程是绑定的。在应用程序启动的时候，主线程的 Runloop 会被自动创建并启动。

Runloop 拥有多种模式（ Mode ），它只会运行在一个模式之下。如果想切换 Mode，必须先退出 loop 然后再重新指定一个 Mode 进入。

在绝大多数的时间里，Runloop 都处于 kCFRunLoopDefaultMode（ default ）模式中，当可滚动控件处于滚动状态时，为了保证滚动的效率，系统会将 Runloop 切换至 UITrackingRunLoopMode（ tracking ）模式下。

本节采用的方法便是利用了上述特性，通过创建绑定于不同 Runloop 模式下的 TimerPublisher ，实现对滚动状态的判断。

```swift
final class ExclusionStore: ObservableObject {
    @Published var isScrolling = false
    // 当 Runloop 处于 default（ kCFRunLoopDefaultMode ）模式时，每隔 0.1 秒会发送一个时间信号
    private let idlePublisher = Timer.publish(every: 0.1, on: .main, in: .default).autoconnect()
    // 当 Runloop 处于 tracking（ UITrackingRunLoopMode ）模式时，每隔 0.1 秒会发送一个时间信号
    private let scrollingPublisher = Timer.publish(every: 0.1, on: .main, in: .tracking).autoconnect()

    private var publisher: some Publisher {
        scrollingPublisher
            .map { _ in 1 } // 滚动时，发送 1
            .merge(with:
                idlePublisher
                    .map { _ in 0 } // 不滚动时，发送 0
            )
    }

    var cancellable: AnyCancellable?

    init() {
        cancellable = publisher
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { output in
                guard let value = output as? Int else { return }
                if value == 1,!self.isScrolling {
                    self.isScrolling = true
                }
                if value == 0, self.isScrolling {
                    self.isScrolling = false
                }
            })
    }
}

struct ScrollStatusMonitorExclusionModifier: ViewModifier {
    @StateObject private var store = ExclusionStore()
    @Binding var isScrolling: Bool
    func body(content: Content) -> some View {
        content
            .environment(\.isScrolling, store.isScrolling)
            .onChange(of: store.isScrolling) { value in
                isScrolling = value
            }
            .onDisappear {
                store.cancellable = nil // 防止内存泄露
            }
    }
}
```

### 方案二优点

* 具备与 Delegate 方式几乎一致的准确性和及时性
* 实现的逻辑非常简单

### 方案二缺点

* 只能运行于 iOS 系统

  在 macOS 下的 eventTracking 模式中，该方案的表现并不理想

* 屏幕中只能有一个可滚动控件

  由于任意可滚动控件滚动时，都会导致主线程的 Runloop 切换至 tracing 模式，因此无法有效地区分滚动是由那个控件造成的

## 方法三：PreferenceKey

在 SwiftUI 中，子视图可以通过 preference 视图修饰器向其祖先视图传递信息（  PreferenceKey ）。preference 与 onChange 的调用时机非常类似，只有在值发生改变后才会传递数据。

在 ScrollView、List 发生滚动时，它们内部的子视图的位置也将发生改变。我们将以是否可以持续接收到它们的位置信息为依据判断当前是否处于滚动状态。

```swift
final class CommonStore: ObservableObject {
    @Published var isScrolling = false
    private var timestamp = Date()

    let preferencePublisher = PassthroughSubject<Int, Never>()
    let timeoutPublisher = PassthroughSubject<Int, Never>()

    private var publisher: some Publisher {
        preferencePublisher
            .dropFirst(2) // 改善进入视图时可能出现的状态抖动
            .handleEvents(
                receiveOutput: { _ in
                    self.timestamp = Date() 
                    // 如果 0.15 秒后没有继续收到位置变化的信号，则发送滚动状态停止的信号
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        if Date().timeIntervalSince(self.timestamp) > 0.1 {
                            self.timeoutPublisher.send(0)
                        }
                    }
                }
            )
            .merge(with: timeoutPublisher)
    }

    var cancellable: AnyCancellable?

    init() {
        cancellable = publisher
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { output in
                guard let value = output as? Int else { return }
                if value == 1,!self.isScrolling {
                    self.isScrolling = true
                }
                if value == 0, self.isScrolling {
                    self.isScrolling = false
                }
            })
    }
}

public struct MinValueKey: PreferenceKey {
    public static var defaultValue: CGRect = .zero
    public static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct ScrollStatusMonitorCommonModifier: ViewModifier {
    @StateObject private var store = CommonStore()
    @Binding var isScrolling: Bool
    func body(content: Content) -> some View {
        content
            .environment(\.isScrolling, store.isScrolling)
            .onChange(of: store.isScrolling) { value in
                isScrolling = value
            }
        // 接收来自子视图的位置信息
            .onPreferenceChange(MinValueKey.self) { _ in
                store.preferencePublisher.send(1) // 我们不关心具体的位置信息，只需将其标注为滚动中
            }
            .onDisappear {
                store.cancellable = nil
            }
    }
}

// 添加与 ScrollView、List 的子视图之上，用于在位置发生变化时发送信息
func scrollSensor() -> some View {
    overlay(
        GeometryReader { proxy in
            Color.clear
                .preference(
                    key: MinValueKey.self,
                    value: proxy.frame(in: .global)
                )
        }
    )
}
```

### 方案三优点

* 支持多平台（ iOS、macOS、macCatalyst ）
* 拥有较好的前后兼容性

### 方案三缺点

* 需要为可滚动容器的子视图添加修饰器

  对于 ScrollView + VStack（ HStack ）这类的组合，只需为可滚动视图添加一个 scrollSensor 即可。对于 List、ScrollView + LazyVStack（ LazyHStack ）这类的组合，需要为每个子视图都添加一个 scrollSensor。

* 判断的准确度没有前两种方式高

  当可滚动组件中的内容出现了非滚动引起的尺寸或位置的变化（ 例如 List 中某个视图的尺寸发生了动态变化 ），本方式会误判断为发生了滚动，但在视图的变化结束后，状态会马上恢复到滚动结束

  滚动开始后（ 状态已变化为滚动中 ），保持手指处于按压状态并停止滑动，此方式会将此时视为滚动结束，而前两种方式仍会保持滚动中的状态直到手指结束按压

## IsScrolling

我将后两种解决方案打包做成了一个库 —— [IsScrolling](https://github.com/fatbobman/IsScrolling) 以方便大家使用。其中 exclusion 对应着 Runloop 原理、common 对应着 PreferenceKey 解决方案。

使用范例（ exclusion ）：

```swift
struct VStackExclusionDemo: View {
    @State var isScrolling = false
    var body: some View {
        VStack {
            ScrollView {
                VStack {
                    ForEach(0..<100) { i in
                        CellView(index: i) // no need to add sensor in exclusion mode
                    }
                }
            }
            .scrollStatusMonitor($isScrolling, monitorMode: .exclusion) // add scrollStatusMonitor to get scroll status
        }
    }
}
```

使用范例（ common ）：

```swift
struct ListCommonDemo: View {
    @State var isScrolling = false
    var body: some View {
        VStack {
            List {
                ForEach(0..<100) { i in
                    CellView(index: i)
                        .scrollSensor() // Need to add sensor for each subview
                }
            }
            .scrollStatusMonitor($isScrolling, monitorMode: .common)
        }
    }
}
```

## 总结

SwiftUI 仍在高速进化中，很多积极的变化并不会立即体现出来。待 SwiftUI 更多的底层实现不再依赖 UIKit（ AppKit ）之时，才会是它 API 的爆发期。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ) 或博客的留言板与我进行交流。

> 我正以聊天室、Twitter、博客留言等讨论为灵感，从中选取有代表性的问题和技巧制作成 Tips ，发布在 Twitter 上。每周也会对当周博客上的新文章以及在 Twitter 上发布的 Tips 进行汇总，并通过邮件列表的形式发送给订阅者。

**订阅下方的 [邮件列表](https://artisanal-knitter-2544.ck.page/d3591dd1e7)，可以及时获得每周的 Tips 汇总。**
