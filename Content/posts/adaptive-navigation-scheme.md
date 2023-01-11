---
date: 2022-11-15 08:20
description: 随着苹果对 iPadOS 的不断投入，越来越多的开发者都希望自己的应用能够在 iPad 中有更好的表现。尤其当用户开启了台前调度（ Stage Manager ）功能后，应用对不同视觉大小模式的兼容能力就越发显得重要。本文将就如何创建可自适应不同尺寸模式的程序化导航方案这一内容进行探讨。
tags: SwiftUI
title: 在 SwiftUI 中创建自适应的程序化导航方案
image: images/adaptive-navigation-scheme.png
---
随着苹果对 iPadOS 的不断投入，越来越多的开发者都希望自己的应用能够在 iPad 中有更好的表现。尤其当用户开启了台前调度（ Stage Manager ）功能后，应用对不同视觉大小模式的兼容能力就越发显得重要。本文将就如何创建可自适应不同尺寸模式的程序化导航方案这一内容进行探讨。

![iShot_2022-11-13_09.30.17.2022-11-13 09_35_46](https://cdn.fatbobman.com/iShot_2022-11-13_09.30.17.2022-11-13%2009_35_46-8387178.gif)

## 程序化导航与状态驱动

顾名思义，“程序化导航”就是开发者可以通过代码感知应用当前的导航状态并设置导航目标的方式。从 4.0 版本开始，苹果对之前 SwiftUI 有限的程序化导航能力进行了大幅度的增强，通过引入 NavigationStack 和 NavigationSplitView，开发者基本上具备了全程掌握应用的导航状态的能力，并可在视图内外的代码中实现任意位置的跳转。

与 UIKit 使用的命令式导航方式不同，SwiftUI 作为一个声明式框架，感知与设置两者之间是二位一体的关系。读取状态即可获知当前的导航位置，更改状态便可调整导航路径。因此在 SwiftUI 中，掌握两种导航容器的状态表述差异是实现自适应导航方案的关键。

```responser
id:1
```

## NavigationStack vs NavigationSplitView

> 本节仅对 NavigationStack 和 NavigationSplitView 之间的状态表述进行说明，想了解两者具体用法，请参阅 [SwiftUI 4.0 的全新导航系统](https://www.fatbobman.com/posts/new_navigator_of_SwiftUI_4/) 一文。

与视觉表现一致， NavigationStack 用“栈”作为导航的状态表述。使用数组（ NavigationPath 也是对 Hashable 数组的一种包装 ）作为状态的表现形式。在栈中推送和弹出数据的过程对应了导航容器中添加和移除视图的操作。弹出全部数据相当于返回根视图，推送多个数据相当于一次性添加多个视图并直接跳转到最后数据所代表的视图。需要特别注意的是，在 NavigationStack 中，根视图是直接通过代码声明的，并不存在于“栈”中。

我们可以将 NavigationSplitView 视为具备一些预置能力的 HStack，通过在其中声明两个或三个视图从而创建两列或三列的导航界面。在不少情况下，NavigationSplitView 与 拥有多个视图的 HStack 之间的状态表述十分类似。但是，因为  NavigationSplitView 的某些特性，从而对状态的表述有更多的要求和限制：

* 在需要的状况下（ iPhone 或 compact 模式下 ）可以自动转换成 NavigationStack 的视觉状态

  对于一些简单的两列或三列的导航布局，SwiftUI 可以自动将其转换成 NavigationStack 表现形式。下文中的方案一和方案二便是对这种能力的体现。但并非所有的状态表述都可在转换后实现程序化导航。

* 与 List 进行了深度的绑定

  对于一个包含三列（ A、B、C ）的 NavigationSplitView ，我们可以使用任意的方式让这些视图之间产生联动。例如：在 A 中修改状态 b，B 响应 b 状态；在 B 中修改状态 c，C 视图响应状态 c。不过仅有在前两列中通过 `List(selection:)` 来修改状态时，才能在自动转换的 NavigationStack 表现形式中具备程序化导航的能力。方案一对此有进一步的说明。

* 列中可以进一步嵌入 NavigationStack

  我们可以在 NavigationSplitView 的任意列中嵌入 NavigationStack 从而实现更加复杂的导航机制。但如此一来，自动转换将无法应对这类的场景。开发者需要自行对两种导航逻辑的状态进行转换。方案三将演示如何进行这一过程。

## 最易用的方案 —— NavigationSplitView + List

![navigationSplitView-three_38_14](https://cdn.fatbobman.com/navigationSplitView-three_38_14.gif)

```swift
struct ThreeColumnsView: View {
    @StateObject var store = ThreeStore()
    @State var visible = NavigationSplitViewVisibility.all
    var body: some View {
        VStack {
            NavigationSplitView(columnVisibility: $visible, sidebar: {
                List(selection: Binding<Int?>(get: { store.contentID }, set: {
                    store.contentID = $0
                    store.detailID = nil
                })) {
                    ForEach(0..<100) { i in
                        Text("SideBar \(i)")
                    }
                }
                .id(store.deselectSeed)
            }, content: {
                List(selection: $store.detailID) {
                    if let contentID = store.contentID {
                        ForEach(0..<100) { i in
                            Text("\(contentID):\(i)")
                        }
                    }
                }
                .overlay {
                    if store.contentID == nil {
                        Text("Empty")
                    }
                }
            }, detail: {
                if let detailID = store.detailID {
                    Text("\(detailID)")
                } else {
                    Text("Empty")
                }
            })
            .navigationSplitViewStyle(.balanced)
            HStack {
                Button("Back Root") {
                    store.backRoot()
                }
                Button("Back Parent") {
                    store.backParent()
                }
            }
            .buttonStyle(.bordered)
        }
    }
}

class ThreeStore: ObservableObject {
    @Published var contentID: Int?
    @Published var detailID: Int?
    @Published var deselectSeed = 0

    func backParent() {
        if detailID != nil {
            detailID = nil
        } else if contentID != nil {
            contentID = nil
        }
    }

    func backRoot() {
        detailID = nil
        contentID = nil
        // 改善 compact 模式下返回根目录后的表现。取消选中高亮
        // 可以用类似的方式，改善当 contentID 变化后，content 列仍会有灰色选择提示的问题
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                self.deselectSeed += 1
            }
        }
    }
}
```

代码很简单，我仅就几点进行提醒：

* List 必须出现在列代码的最上层

  为了保证在自动转换后仍具备程序化导航的能力，NavigationSplitView 对嵌入的 List 有严格的要求，List 代码必须出现在列代码中的最上层。比如在本例的 Content 列代码中，为了维持这个限定，只能通过 overlay 来定义占位视图。如果将代码调整成如下样式，则会在转换后丧失程序化导航的能力（ 无法通过修改状态，返回上层视图 ）。

```swift
if store.detailID != nil {
    List(selection: $store.detailID)
} else {
    Text("Empty")
}
```

* 修改状态后，List 仍会用灰色显示上次选中的项目

  即使取消了状态（ 例如修改 contentID ），List 仍会将上次选中的状态用灰色的选中框进行表示。为了避免使用者产生误解，代码中分别使用了两个 id 修饰器在状态变化后对列视图进行了刷新。

## 有得必有失 —— NavigationSplitView + LazyVStack

尽管 List 使用起来很简单，但也有一些不足之处，其中最重要的是无法自定义选中的状态。那么能否在导航列中使用 VStack 或 LazyVStack 实现程序化导航呢？

在不久前的 [Ask Apple](https://www.fatbobman.com/posts/SwiftUI-of-Ask-Apple-2022-2/) 中，苹果工程师介绍了如下的方法：

![image-20221114135939796](https://cdn.fatbobman.com/image-20221114135939796.png)

很遗憾，由于没有暴露 path 接口，问答中的 `navigationDestination(for:)` 无法实现程序化的回退。不过我们可以通过使用另一个 `navigationDestination(isPresented:)` 修饰器来达到类似的目的。俗话说，有得必有失，暂时这种方式只能支持两列，尚未找到可以在中间列中继续使用程序化导航的方式。

![navigationSplitView-two-_52](https://cdn.fatbobman.com/navigationSplitView-two-_52.gif)

```swift
class TwoStore: ObservableObject {
    @Published var detailID: Int?

    func backParent() {
        detailID = nil
    }
}

struct TowColumnsView: View {
    @StateObject var store = TwoStore()
    @State var visible = NavigationSplitViewVisibility.all
    var body: some View {
        VStack {
            NavigationSplitView(columnVisibility: $visible, sidebar: {
                ScrollView {
                    LazyVStack {
                        ForEach(0..<100) { i in
                            Text("SideBar \(i)")
                                .padding(5)
                                .padding(.leading, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(store.detailID == i ? Color.blue : .clear)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    store.detailID = i
                                }
                        }
                    }
                }
                .navigationDestination(
                    isPresented: Binding<Bool>(
                        get: { store.detailID != nil },
                        set: { if !$0 { store.detailID = nil }}
                    ),
                    destination: {
                        // 需要使用独立的 struct 来构造视图
                        DetailView(store: store)
                    }
                )
            }, detail: {
                Text("Empty")
            })
            Button("Back Parent") {
                store.backParent()
            }
            .buttonStyle(.bordered)
        }
    }
}

struct DetailView: View {
    @ObservedObject var store: TwoStore
    var body: some View {
        if let detailID = store.detailID {
            Text("\(detailID)")
        }
    }
}
```

需要特别提醒的是，由于处在不同的上下文中，在 navigationDestination 的 destination 中，必须用单独的 struct 来创建视图。否则视图无法响应状态的变化。

```responser
id:1
```

## 麻烦但最能打 —— NavigationSplitView + NavigationStack

如果上述两个方案仍无法满足你的需求，那么便需要根据当前的视觉大小模式选择性调用 NavigatoinStack 或 NavigationSplitView。

例如，下面的代码实现了一个具备两列的 NavigationSplitView ，Detail 列中包含一个 NavigationStack。在 InterfaceSizeClass 发生改变后，需要对导航状态进行调整，以匹配 NavigationStack 的需求。反之亦然。演示图片见本文第一个动图。

```swift
class AdaptiveStore: ObservableObject {
    @Published var detailPath = [DetailInfo]() {
        didSet {
            if sizeClass == .compact, detailPath.isEmpty {
                rootID = nil
            }
        }
    }

    @Published var rootID: Int?
    var sizeClass: UserInterfaceSizeClass? {
        didSet {
            if oldValue != nil, oldValue != sizeClass, let oldValue, let sizeClass {
                rebuild(from: oldValue, to: sizeClass)
            }
        }
    }

    func backRoot() {
        detailPath.removeAll()
    }

    func backParent() {
        if !detailPath.isEmpty {
            detailPath.removeLast()
        }
    }

    func selectRootID(rootID: Int) {
        if sizeClass == .regular {
            self.rootID = rootID
            detailPath.removeAll()
        } else {
            self.rootID = rootID
            detailPath.append(.init(level: 1, rootID: rootID))
        }
    }

    func rebuild(from: UserInterfaceSizeClass, to: UserInterfaceSizeClass) {
        guard let rootID else { return }
        if to == .regular {
            if !detailPath.isEmpty {
                detailPath.removeFirst()
            }
        } else {
            detailPath = [.init(level: 1, rootID: rootID)] + detailPath
        }
    }
}

struct DetailInfo: Hashable, Identifiable {
    let id = UUID()
    let level: Int
    let rootID: Int
}

struct AdaptiveNavigatorView: View {
    @StateObject var store = AdaptiveStore()
    @Environment(\.horizontalSizeClass) var sizeClass
    var body: some View {
        VStack {
            if sizeClass == .regular {
                SplitView(store: store)
                    .task {
                        store.sizeClass = sizeClass
                    }
            } else {
                StackView(store: store)
                    .task {
                        store.sizeClass = sizeClass
                    }
            }
            HStack {
                Button("Back Root") { store.backRoot() }
                Button("Back Parent") { store.backParent() }
            }
            .buttonStyle(.bordered)
        }
    }
}

struct SplitView: View {
    @ObservedObject var store: AdaptiveStore
    var body: some View {
        NavigationSplitView {
            SideBarView(store: store)
        } detail: {
            if let rootID = store.rootID {
                NavigationStack(path: $store.detailPath) {
                    DetailInfoView(store: store, info: .init(level: 1, rootID: rootID))
                        .navigationTitle("Root \(rootID), Level:\(store.detailPath.count + 1)")
                        .navigationDestination(for: DetailInfo.self) { info in
                            DetailInfoView(store: store, info: info)
                                .navigationTitle("Root \(info.rootID), Level \(info.level)")
                        }
                }
            } else {
                Text("Empty")
            }
        }
    }
}

struct StackView: View {
    @ObservedObject var store: AdaptiveStore
    var body: some View {
        NavigationStack(path: $store.detailPath) {
            SideBarView(store: store)
                .navigationDestination(for: DetailInfo.self) { info in
                    DetailInfoView(store: store, info: info)
                        .navigationTitle("Root \(info.rootID), Level \(info.level)")
                }
        }
    }
}

struct DetailInfoView: View {
    @ObservedObject var store: AdaptiveStore
    let info: DetailInfo
    var body: some View {
        List {
            Text("RootID:\(info.rootID)")
            Text("Current Level:\(info.level)")
            NavigationLink("Goto Next Level", value: DetailInfo(level: info.level + 1, rootID: info.rootID))
                .foregroundColor(.blue)
        }
    }
}

struct SideBarView: View {
    @ObservedObject var store: AdaptiveStore
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(0..<30) { rootID in
                    Button {
                        store.selectRootID(rootID: rootID)
                    }
                label: {
                        Text("RootID \(rootID)")
                            .padding(5)
                            .padding(.leading, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .background(store.rootID == rootID ? .cyan : .clear)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Root")
    }
}
```

请注意如下几点：

* 以导航容器所在的视图的 horizontalSizeClass 为判断标准

  InterfaceSizeClass 对应的是当前视图的视觉大小。最好以导航容器所在视图的 sizeClass 作为判断标准。例如，在 Side 列视图中，无论在任何环境下，horizontalSizeClass 始终为 compact 。

* 以导航容器的出现时机（ onAppear ）作为重新构建状态的起始点

  sizeClass 在变化的过程中，其中的值可能会出现重复变化的情况。因此，不应将 sizeClass 的值是否发生变化作为重构状态的判断标准。

* 不要忘记 NavigationStack 的根视图不在它的“栈”数据中

  在本例中，转换至 NavigationStack 时，需要将 Detail 列中声明的视图添加到“栈”的底端。反过来则将其移除。

本着“一案一议”的原则，当前方案可以实现对任意的导航逻辑进行转换。

## 总结

可以在 [此处](https://github.com/fatbobman/BlogCodes/tree/main/DynamicNavigationContainer) 获取本文的全部代码。

一次编写便可对应多种设备，这本就是 SwiftUI 的一个重要特点。尽管仍存在一些不足，但新的导航机制已经在这一方面取得了长足的进步。唯一遗憾的是，仅支持 iOS 16+。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ) 或博客的留言板与我进行交流。

> 我正以聊天室、Twitter、博客留言等讨论为灵感，从中选取有代表性的问题和技巧制作成 Tips ，发布在 Twitter 上。每周也会对当周博客上的新文章以及在 Twitter 上发布的 Tips 进行汇总，并通过邮件列表的形式发送给订阅者。

**订阅下方的 [邮件列表](https://artisanal-knitter-2544.ck.page/d3591dd1e7)，可以及时获得每周的 Tips 汇总。**
