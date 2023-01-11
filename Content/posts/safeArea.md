---
date: 2021-11-22 08:12
description: Safe Area（安全区域）是指不与导航栏、标签栏、工具栏或其他视图控制器提供的视图重叠的内容空间。本文将探讨如何在 SwiftUI 中获取 SafeAreaInsets、将视图绘制到安全区域之外、修改视图的安全区域等内容。
tags: SwiftUI
title:  掌握 SwiftUI 的 Safe Area
image: images/safeArea.png
---
Safe Area（安全区域）是指不与导航栏、标签栏、工具栏或其他视图控制器提供的视图重叠的内容空间。

在 UIKit 中，开发者需要利用 safeAreaInsets 或 safeAreaLayoutGuide ，才能确保将视图放置在界面中的可见部分。

SwiftUI 对上述过程进行了彻底的简化。除非开发者明确要求视图突破安全区域的限制，否则 SwfitUI 将尽力确保开发者创建的视图都被布局到安全区域当中。SwiftUI 同时提供了一些方法和工具让开发者对安全区域有所控制。

本文将探讨如何在 SwiftUI 中获取 SafeAreaInsets、将视图绘制到安全区域之外、修改视图的安全区域等内容。

```responser
id:1
```

## 如何获取 SafeAreaInsets ##

### 什么是 SafeAreaInsets ###

SafeAreaInsets 是用来确定视图安全区域的插入值。

对于根视图来说，safeAreaInsets 反映的是状态栏、导航栏、主页提示器以及 TabBar 等在各个边的占用数值。对于视图层次上的其他视图，safeAreaInesets 只反映视图中被覆盖的部分。如果一个视图可以完整地放置在父视图的安全区域中，该视图的 safeAreaInsets 为 0。当视图尚未在屏幕上可见时，该视图的 safeAreaInset 也为 0 。

在 SwiftUI 中，开发者通常只有在需要获取 StatusBar + NavBar 的高度或 HomeIndeicator + TabBar 的高度时才会使用到 safeAreaInsets 。

### 使用 GeometryReader 获取 ###

GeometryProxy 提供了 safeAreaInsets 属性，开发者可以通过 GeometryReader 获取视图的 safeAreaInsets。

```swift
struct SafeAreaInsetsKey: PreferenceKey {
    static var defaultValue = EdgeInsets()
    static func reduce(value: inout EdgeInsets, nextValue: () -> EdgeInsets) {
        value = nextValue()
    }
}

extension View {
    func getSafeAreaInsets(_ safeInsets: Binding<EdgeInsets>) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: SafeAreaInsetsKey.self, value: proxy.safeAreaInsets)
            }
            .onPreferenceChange(SafeAreaInsetsKey.self) { value in
                safeInsets.wrappedValue = value
            }
        )
    }
}
```

使用方式：

```swift
struct GetSafeArea: View {
    @State var safeAreaInsets: EdgeInsets = .init()
    var body: some View {
        NavigationView {
            VStack {
                Color.blue
            }
        }
        .getSafeAreaInsets($safeAreaInsets)
    }
}

// iphone 13
// EdgeInsets(top: 47.0, leading: 0.0, bottom: 34.0, trailing: 0.0)
```

从获得的 insets 可以得知 HomeIndeicator 的高度为 34。

也可以使用下面的代码，进一步了解 safeAreaInsets 在各个层级视图中的状况。

```swift
extension View {
    func printSafeAreaInsets(id: String) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: SafeAreaInsetsKey.self, value: proxy.safeAreaInsets)
            }
            .onPreferenceChange(SafeAreaInsetsKey.self) { value in
                print("\(id) insets:\(value)")
            }
        )
    }
}
```

例如：

```swift
struct GetSafeArea: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Hello world")
                    .printSafeAreaInsets(id: "Text")
            }
        }
        .printSafeAreaInsets(id: "NavigationView")
    }
}

// iPhone 13 pro
// NavigationView insets:EdgeInsets(top: 47.0, leading: 0.0, bottom: 34.0, trailing: 0.0)
// Text insets:EdgeInsets(top: 0.0, leading: 0.0, bottom: 0.0, trailing: 0.0)
```

### 从 KeyWindow 中获取 ###

如果只需要获取根视图的 safeAreaInsets ，我们也可以使用更加直接的方式。

> 下面代码取自 [StackOverFlow](https://stackoverflow.com/a/68709575/12260342) 网友 Mirko 的答案

```swift
extension UIApplication {
    var keyWindow: UIWindow? {
        connectedScenes
            .compactMap {
                $0 as? UIWindowScene
            }
            .flatMap {
                $0.windows
            }
            .first {
                $0.isKeyWindow
            }
    }
}

private struct SafeAreaInsetsKey: EnvironmentKey {
    static var defaultValue: EdgeInsets {
        UIApplication.shared.keyWindow?.safeAreaInsets.swiftUiInsets ?? EdgeInsets()
    }
}

extension EnvironmentValues {
    var safeAreaInsets: EdgeInsets {
        self[SafeAreaInsetsKey.self]
    }
}

private extension UIEdgeInsets {
    var swiftUiInsets: EdgeInsets {
        EdgeInsets(top: top, leading: left, bottom: bottom, trailing: right)
    }
}
```

可以通过环境值获取到根视图的 safeAreaInsets ：

```swift
@Environment(\.safeAreaInsets) private var safeAreaInsets
```

## 使用 ignoresSafeArea 忽略安全区域 ##

在开发 iOS 应用时，经常会碰到需要让视图可以扩展到非安全区域的情况。例如，希望让背景颜色充满整个屏幕。

```swift
struct FullScreenView: View {
    var body: some View {
        ZStack {
            Color.blue
            Text("Hello world").foregroundColor(.white)
        }
    }
}
```

由于 SwiftUI 在默认的情况下会将用户视图置于安全区之内，因此我们只能得到如下的结果：

![image-20211120141245282](https://cdn.fatbobman.com/image-20211120141245282.png)

为了让视图能够突破安全区域的限制，SwiftUI 提供了 ignoresSafeArea 修饰器。

```swift
struct FullScreenView: View {
    var body: some View {
        ZStack {
            Color.blue
            Text("Hello world").foregroundColor(.white)
        }
        .ignoresSafeArea() // 全方向忽略安全区域
    }
}
```

![image-20211120141804145](https://cdn.fatbobman.com/image-20211120141804145.png)

> iOS 13 提供的 edgesIgnoringSafeArea 修饰器已经在 iOS 14.5 中弃用。

ignoresSafeArea 的定义如下：

```swift
@inlinable public func ignoresSafeArea(_ regions: SafeAreaRegions = .all, edges: Edge.Set = .all) -> some View
```

在默认情况下， `.ignoresSafeArea()` 代表着在全部方向，忽略全部的安全区域划分（SafeAreaRegions）。

通过指定 edges，我们可以让某个或某几个边突破安全区域的限制。

```swift
// 只扩展到底部
.ignoresSafeArea(edges: .bottom)

// 扩展到顶部和底部
.ignoresSafeArea(edges: [.bottom, .trailing])

// 横向扩展
.ignoresSafeArea(edges:.horizontal)
```

使用起来非常直观、方便，但为什么视图会在有键盘输入时出现不符合预期的行为？这是因为，我们并没有正确的设置 ignoresSafeArea 另一个重要的参数`regions`。

ignoresSafeArea 相较于 SwiftUI 1.0 提供的 edgesIgnoringSafeArea 最大的提升便是允许我们设置 SafeAreaRegions 。

SafeAreaRegions 定义了三种安全区域划分：

* container

  由设备和用户界面内的容器所定义的安全区域，包括诸如顶部和底部栏等元素。

* keyboard

  与显示在视图内容上的任何软键盘的当前范围相匹配的安全区域。

* all（默认）

  上述两种安全区域划分的合集

iOS 13 并没有提供键盘自动避让功能，开发者需要编写一些额外的代码来解决软键盘不恰当遮盖视图（如 TextField ）的问题。

从 iOS 14 开始，SwiftUI 计算视图的安全区域时，将软键盘在屏幕上的覆盖区域（iPadOS 下，将软键盘缩小后键盘的覆盖区域将被忽略）也一并进行考虑。因此，无需使用任何额外的代码，视图便自动获得了键盘避让的能力。但有时，并非所有的视图都需要将软键盘的覆盖区域从安全区域中去除，因此需要正确地设置 SafeAreaRegions 。

```swift
struct IgnoresSafeAreaTest: View {
    var body: some View {
        ZStack {
            // 渐变背景
            Rectangle()
                .fill(.linearGradient(.init(colors: [.red, .blue, .orange]), startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack {
                // Logo
                Circle().fill(.regularMaterial).frame(width: 100, height: 100).padding(.vertical, 100)
                // 文本输入
                TextField("name", text: .constant(""))
                    .textFieldStyle(.roundedBorder)
                    .padding()
            }
        }
    }
}
```

![ignoresDemo1](https://cdn.fatbobman.com/ignoresDemo1.gif)

上面的代码尽管实现了键盘的自动避让，但并不完全符合预期行为。首先，背景并没有充满全部屏幕，其次在软键盘弹出时，我们并不希望背景因为安全区域的变化而发生改变。尽管通过 ignoresSafeArea 可以解决上述问题，但在什么位置添加、如何设定还是有一点讲究的。

我们将 ignoresSafeArea 添加到 ZStack 之后：

```swift
ZStack {
    ...
}
.ignoresSafeArea()
```

此时，背景充满了屏幕，也不受软键盘弹出的影响了。但前景的内容失去了键盘自动避让的能力。

![ignoresDemo2](https://cdn.fatbobman.com/ignoresDemo2.gif)

如果将代码修改成：

```swift
ZStack {
    ...
}
.ignoresSafeArea(.container)
```

此时，背景充满了屏幕，前景支持了键盘避让，但背景会在键盘出现时，发生了不该有的变化。

![ignoresDemo3](https://cdn.fatbobman.com/ignoresDemo3.gif)

正确的处理方式是，只让背景忽略安全区域：

```swift
struct IgnoresSafeAreaTest: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.linearGradient(.init(colors: [.red, .blue, .orange]), startPoint: .topLeading, endPoint: .bottomTrailing))
                .ignoresSafeArea(.all) // 只让背景忽略安全区域
            VStack {
                Circle().fill(.regularMaterial).frame(width: 100, height: 100).padding(.vertical, 100)
                TextField("name", text: .constant(""))
                    .textFieldStyle(.roundedBorder)
                    .padding()
            }
        }
    }
}
```

![ignoresDemo4](https://cdn.fatbobman.com/ignoresDemo4.gif)

除了需要对正确的视图设定正确的 ignoresSafeArea 参数外，有时为了获得满意的结果，适当地调整视图的组织形式也是不错的选择。

```responser
id:1
```

## 使用 safeAreaInset 扩展安全区域 ##

在 SwiftUI 中，所有基于 UIScrollView 的组件（ScrollView、List、Form），在默认情况下都会充满整个屏幕，但仍可确保我们可以在安全区域内看到所有的内容。

```swift
List(0..<100){ id in
    Text("id\(id)")
}
```

![safeAreInsetList1](https://cdn.fatbobman.com/safeAreInsetList1.png)

当被嵌入到 TabView 时，TabView 会调整其内部的安全区域。

![safeAreaInsetList2](https://cdn.fatbobman.com/safeAreaInsetList2.png)

遗憾的是，在 iOS 15 之前，SwiftUI 并没有提供调整视图安全区的手段，如果我们想通过 SwiftUI 的手段创建一个自定义 Tabbar 时，列表中最后的内容将被 Tabbar 遮挡。

safeAreaInset 修饰符的出现解决了上述的问题。通过 safeAreaInset，我们可以缩小视图的安全区域，以确保所有内容都可以按预期显示。

例如：

```swift
struct AddSafeAreaDemo: View {
    var body: some View {
        ZStack {
            Color.yellow.border(.red, width: 10)
        }
        .safeAreaInset(edge: .bottom, alignment: .center, spacing: 0) {
            Rectangle().fill(.blue)
                .frame(height: 100)
        }
        .ignoresSafeArea()
    }
}
```

我们使用了 safeAreaInset，将 ZStack 内部的安全区从底边缩小了 100，并在此处显示了一个蓝色的矩形。

![image-20211120165303239](https://cdn.fatbobman.com/image-20211120165303239.png)

利用 safeAreaInset，可以让 List 在自定义的 TabBar 中表现同系统 TabBar 一致的行为。

```swift
struct AddSafeAreaDemo: View {
    var body: some View {
        NavigationView {
            List(0..<100) { i in
                Text("id:\(i)")
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Text("底部状态条")
                    .font(.title3)
                    .foregroundColor(.indigo)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 40)
                    .padding()
                    .background(.green.opacity(0.6))

            }
        }
    }
}
```

在 iPhone 13 下的表现

![safeAreaTabbarDemo1](https://cdn.fatbobman.com/safeAreaTabbarDemo1-7400021.gif)

我们只调整了安全区域， SwiftUI 会自动在不同的设备上进行适配（在 iPhone 13 上，状态条的高度为 40 + HomeIndeicator区域高度）。

> 自动适配只对 **background** 有效。

相同的代码，在 iPhone 8 下的表现

![image-20211120172325088](https://cdn.fatbobman.com/image-20211120172325088.png)

> iOS 15.2 之前的版本，safeAreaInset 对 List 和 Form 的支持有问题（ScrollView 表现正常），无法将列表最后的内容全部显示完整。该 Bug 已在 iOS 15.2 中得到了修复。本文中的代码，在 Xcode 13.2 beta (13C5066c) 之后的版本都可以获得符合预期的表现。

![image-20211120170839227](https://cdn.fatbobman.com/image-20211120170839227.png)

safeAreaInset 可以叠加，这样我们可以在多个边对安全区域进行调整，例如：

```swift
ZStack {
    Color.yellow.border(.red, width: 10)
}
.safeAreaInset(edge: .bottom, alignment: .center, spacing: 0) {
    Rectangle().fill(.blue)
        .frame(height: 100)
}
.safeAreaInset(edge: .trailing, alignment: .center, spacing: 0) {
    Rectangle().fill(.blue)
        .frame(width: 50)
}
```

我们也可以通过 aligmnet 为安全区域插入内容设置对齐方式，用 spacing 在想要显示的内容和安全区域添加内容之间添加额外的空间。

尽管使用 safeAreaInset 为列表在底部添加状态栏或自定义 TabBar 非常方便，**但如果你的列表中使用了 TextField，情况将变得很麻烦**。

比如，下面是一个很极端的例子：

```swift
struct AddSafeAreaDemo: View {
    var body: some View {
        ScrollView {
            ForEach(0..<100) { i in
                TextField("input text for id:\(i)",text:.constant(""))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Text("底部状态条")
                .font(.title3)
                .foregroundColor(.indigo)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 40)
                .padding()
                .background(.green.opacity(0.6))
                .ignoresSafeArea(.all)
        }
    }
}
```

![safeAreaStatusBarWithTextField](https://cdn.fatbobman.com/safeAreaStatusBarWithTextField.gif)

我们是无法通过使用 ignoresSafeArea，让 TextField 在保持对键盘自动避让的情况下，固定底部的状态条。此时，底部状态条的表现肯定不符合设计的初衷。

如果想让底部状态条固定，同时又保持 TextField 的自动避让能力，需要通过监控键盘的状态，做一点额外的操作。

```swift
final class KeyboardMonitor: ObservableObject {
    @Published var willShow: Bool = false
    private var cancellables = Set<AnyCancellable>()
    init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification, object: nil)
            .sink { _ in
                self.willShow = true
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification, object: nil)
            .sink { _ in
                self.willShow = false
            }
            .store(in: &cancellables)
    }
}

struct AddSafeAreaDemo: View {
    @StateObject var monitor = KeyboardMonitor()
    var body: some View {
        ScrollView {
            ForEach(0..<100) { i in
                TextField("input text for id:\(i)", text: .constant(""))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !monitor.willShow { // 在键盘即将弹出时隐藏
                Text("底部状态条")
                    .font(.title3)
                    .foregroundColor(.indigo)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 40)
                    .padding()
                    .background(.green.opacity(0.6))
                    .ignoresSafeArea(.all)
            }
        }
    }
}
```

![safeAreaStatusBarWithTextFieldKeyMonitor](https://cdn.fatbobman.com/safeAreaStatusBarWithTextFieldKeyMonitor.gif)

> 如果上述的代码被放置在 NavigationView 中，还需要对底部状态条动画做更加精细地处理。

### 实战：用 safeAreaInset 实现类似微信的对话页面 ###

使用 safeAreaInset，我们只需很少的代码便可以实现一个类似微信的对话页面。

![safeAreaChatDemo](https://cdn.fatbobman.com/safeAreaChatDemo.gif)

```swift
struct ChatBarDemo: View {
    @State var messages: [Message] = (0...60).map { Message(text: "message:\($0)") }
    @State var text = ""
    @FocusState var focused: Bool
    @State var bottomTrigger = false
    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                List {
                    ForEach(messages) { message in
                        Text(message.text)
                            .id(message.id)
                    }
                }
                .listStyle(.inset)
                .safeAreaInset(edge: .bottom) {
                    ZStack(alignment: .top) {
                        Color.clear
                        Rectangle().fill(.secondary).opacity(0.3).frame(height: 0.6) // 上部线条
                        HStack(alignment: .firstTextBaseline) {
                            // 输入框
                            TextField("输入", text: $text)
                                .focused($focused)
                                .textFieldStyle(.roundedBorder)
                                .padding(.horizontal, 10)
                                .padding(.top, 10)
                                .onSubmit {
                                    addMessage()
                                    scrollToBottom()
                                }
                                .onChange(of: focused) { value in
                                    if value {
                                        scrollToBottom()
                                    }
                                }
                            // 回复按钮
                            Button("回复") {
                                addMessage()
                                scrollToBottom()
                                focused = false
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(.green)
                        }
                        .padding(.horizontal, 30)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 53)
                    .background(.regularMaterial)
                }
                .onChange(of: bottomTrigger) { _ in
                    withAnimation(.spring()) {
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .navigationBarTitle("SafeArea Chat Demo")
        }
    }

    func scrollToBottom() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            bottomTrigger.toggle()
        }
    }

    func addMessage() {
        if !text.isEmpty {
            withAnimation {
                messages.append(Message(text: text))
            }
            text = ""
        }
    }
}

struct Message: Identifiable, Hashable {
    let id = UUID()
    let text: String
}
```

## 总结 ##

在 SwiftUI 中，有不少的功能都属于看一眼就会，但用起来就废的情况。即使表面上平平无奇的功能，仔细深挖仍可获得不少收获。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
