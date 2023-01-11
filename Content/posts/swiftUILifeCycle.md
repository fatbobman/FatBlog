---
date: 2021-11-28 08:12
description: 本文将作者对 SwiftUI 视图、SwiftUI 视图生命周期的理解和研究做以介绍，供大家一起探讨。在 UIKit（AppKit）的世界中，通过框架提供的大量钩子（例如 viewDidLoad、viewWillLayoutSubviews 等），开发者可以将自己的意志注入视图控制器生命周期的各个节点之中，宛如神明。在 SwiftUI 中，系统收回了上述的权利，开发者基本丧失了对视图生命周期的掌控。不少 SwiftUI 开发者都碰到过视图生命周期的行为超出预期的状况（例如视图多次构造、onAppear 无从控制等）。
tags: SwiftUI,Architecture
title: SwiftUI 视图的生命周期研究
image: images/swiftuiLifeCycle.png
---
在 UIKit（AppKit）的世界中，通过框架提供的大量钩子（例如 viewDidLoad、viewWillLayoutSubviews 等），开发者可以将自己的意志注入视图控制器生命周期的各个节点之中，宛如神明。在 SwiftUI 中，系统收回了上述的权利，开发者基本丧失了对视图生命周期的掌控。不少 SwiftUI 开发者都碰到过视图生命周期的行为超出预期的状况（例如视图多次构造、onAppear 无从控制等）。

本文将作者对 SwiftUI 视图、SwiftUI 视图生命周期的理解和研究做以介绍，供大家一起探讨。

```responser
id:1
```

在进行更详尽说明之前，请大家先明确两个观点：

* SwiftUI 没有同 UIkit（AppKit）对应的视图与视图生命周期
* 应避免对 SwiftUI 视图的创建、body 的调用、布局与渲染等的时机和频率进行假设

## SwiftUI 的视图

在 SwiftUI 中，视图定义了一块用户界面，并以视图树的形式组织在一起，SwiftUI 通过解析视图树来创建合适的渲染。

在 SwiftUI 内部它会至少创建两种类型的树——类型树、视图值树

### 类型树

开发者通过创建符合 View 协议的结构体定义想要呈现的用户界面，结构体的 body 属性是一个带有众多泛型参数的庞大类型，SwiftUI 会将这些类型组织成一棵类型树。它包含了 app 生命周期中可能会出现在屏幕上的所有符合 View 协议的类型（即使可能永远不会被渲染）。

例如：

```swift
struct ContentView:View{
    var body: some View{
        Group {
            if true {
                Text("hello world")
            }
            else {
                Text("Won't be rendered")
            }
        }
    }
}
```

上面的代码将构建成如下的类型树：

```swift
Group<_ConditionalContent<Text, Text>>
```

即使`Text("Won't be rendered")`永远都不会被显示，它仍然被包含在类型树中。

类型树在编译后就已经固定，在 app 的生命周期内都不会发生变化。

### 视图值树

在 SwiftUI 中，[视图是状态的函数](https://developer.apple.com/videos/play/wwdc2019/226/)。

开发者通过符合 View 协议的结构体来声明界面，SwiftUI 通过调用结构体实例的 body 获取对应的视图值。body 则根据用户的界面描述和对应的依赖（Source of truth）计算结果。

在 app 运行后进行第一次渲染时，SwiftUI 将依据类型树按图索骥，创建类型实例，实例的 body 根据初始状态计算视图值，并组织成视图值树。需要创建哪些实例，则是根据当时的状态决定的，每次的状态变化都可能会导致最终生成的视图值树不同（可能仅是某个节点的视图值发生变化，也可能是视图值树的结构都发生了巨大的变化）。

当 State 发生变化后，SwiftUI 会生成一棵新的视图值树（Source of truth 没有发生变化的节点，不会重新计算，直接使用旧值），并同老的视图值树进行比对，SwiftUI 将对其中有变化的部分重新布局渲染，并用新生成的视图值树取代老的视图值树。

视图值树通常只保存当前布局、渲染所需的内容（个别情况下，会缓存少数不参与布局、渲染的视图值），在 app 的生命周期中，随着 State 的变化而不断地变化。

### 什么是视图

开发者更习惯将符合 View 协议的结构体或结构体实例视作视图，而在 SwiftUI 的角度，视图值树上的节点内容，才是它所认为的视图。

## SwiftUI 视图的生命周期

大多介绍 SwiftUI 视图生命周期的文章，通常会将视图的生命周期描述成如下的链条：

初始化视图实例——注册数据依赖——调用 body 计算结果——onAppear——销毁实例——onDisapper

有了上面的关于视图的定义，我们再看这种关于生命周期的描述便会发现其中的问题——将两种视图类型视为一体，将不同类型的视图的生命周期强行混编到一条逻辑线上。

在 WWDC 2020 的 [Data Essentials in SwiftUI](Data Essentials in SwiftUI) 专题中，苹果特别指出：**视图的生命的周期与定义它的结构的生命周期是分开的**。

因此，我们需要将开发者眼中的视图和 SwiftUI 眼中的视图分别对待，各自独立的分析其生命周期。

### 符合 View 协议的结构体实例的生命周期

#### 初始化

通过在结构体的构造函数中添加打印命令，我们很容易就可以获知 SwiftUI 创建了某个结构体的实例。如果你仔细分析构造函数的打印结果，你会发现创建结构体实例的时机和频率远超你的预期。

**想要获取 body 值一定要首先创建实例，但创建实例并非一定有获取 body 值的必要！**

* 在 SwiftUI 生成视图值树时，当发现没有对应的实例时，SwiftUI 会创建一个实例从而获取它的 body 结果。
* 在生成新的视图值树时，即使已经有可以对应的实例（该实例并未销毁），SwiftUI 仍可能会创建一个新的实例。但 SwiftUI 并非一定会从新的实例中获取 body 结果，如果之前的实例注册过数据依赖，视图值树仍可能会从原来的实例的 body 中获取结果。
* 在 NavigationView 中，如果在 NavigationLink 中使用了静态的目标视图，SwiftUI 将会为所有的目标视图创建实例，无论是否访问。
* 在 TabView 中，SwiftUI 在一开始就为所有 tab 对应的视图创建了实例。

类似上面的情况还有不少。这也就很好的解释了，很多开发者都会碰到某些视图莫名多次初始化的情况。这种情况可能是 SwiftUI 将第一个实例销毁后创建了一个新的实例，也可能是没有销毁第一个实例而直接创建了一个新的实例。

总之，SwiftUI 将根据它自身的需要，可能在任意的时间、创建任意数量的实例。开发者为了适应 SwiftUI 的这种特性，唯一可以做的就是让结构体的构造函数尽可能的简单。除了必要的参数设置外，不要做任何多余的操作。这样即使 SwiftUI 创建了多余的实例，也不会加大系统的负担。

#### 注册数据依赖

在 SwiftUI 中，状态（或者说是数据）是驱动 UI 的动力。为了让视图能够反映状态的变化，视图需要注册和其对应的依赖项。尽管在结构体的构造函数中，我们可以使用特定的属性包装器（例如@State、@StateObject 等）声明依赖项，但我并不认为注册数据依赖的工作是在初始化阶段进行的。主要的理由有三条：

* 注册依赖的负担并不小。比如，@ObservableObject 在每次创建依赖的时候都需要重新进行堆分配，消耗很大，并可能有会有丢失数据的风险。如果在构造方法中进行注册依赖的工作，将不符合创建轻量化构造方法的准则。
* 除了使用属性包装器外，SwiftUI 还为视图还提供了 onReceive、onChange、onOpenURL、onContinueUserActivity 等方式进行依赖注册。以上四种方式必须对 body 中的内容进行解析后才能完成。
* 下文中会提到，在视图值树的视图生命周期内，无论创建多少个实例都只会保留一份依赖项副本。当使用新实例时，SwiftUI 仍会将新的实例同原有的依赖项关联起来。

鉴于以上原因，注册视图依赖项的时机应该在初始化后，获得 body 结果之前。

#### 调用 body 计算结果

通过在 body 中添加类似如下的代码，我们可以在 SwiftUI 调用实例的 body 时获得通知：

```swift
let _ = print("update some view")
```

计算 body 值是在主线程上进行的，并且 SwiftUI 必须在一个渲染周期内完成所有的计算、比较、布局等工作。为了避免造成 UI 卡顿，body 应设计成纯函数，只在其中创建简单的视图描述，将复杂的逻辑运算和副作用交给其他的线程来进行（比如在 Store 中将逻辑调度到其他线程或在视图中使用 task 将任务派遣到其他线程）。

#### 销毁

结构体并不提供析构方法，我们可以通过类似下面的代码观察结构体实例大致的销毁时机：

```swift
class LifeMonitor {
    let name: String
    init(name: String) {
        self.name = name
        print("\(name) init")
    }

    deinit {
        print("\(name) deinit")
    }
}

struct TestView:View {
    let lifeMonitor:LifeMonitor
    init(){
        self.lifeMonitor = LifeMonitor(name:"testView")
    }
}
```

通过观察，我们可以发现 SwiftUI 在处理结构体实例的销毁上也并没统一的规律。

比如类似如下的代码：

```swift
ZStack {
    ShowMessage(text: "1")
        .opacity(selection == 1 ? 1 : 0)
    ShowMessage(text: "2")
        .opacity(selection == 2 ? 1 : 0)
}

struct ShowMessage:View{
    let text:String
    let lifeMonitor:LifeMonitor
    init(text:String){
        self.text = text
        self.lifeMonitor = LifeMonitor(name: text)
    }

    var body: some View{
        Text(text)
    }
}
```

每次当 selection 在 1 和 2 之间切换时，SwiftUI 都会重新创建两个新的实例，并且将旧的实例销毁。

而如下的代码：

```swift
TabView(selection: $selection) {
    ShowMessage(text: "1")
        .tag(1)
    ShowMessage(text: "2")
        .tag(2)
}
```

SwiftUI 将只在最初创建两个 ShowMessage 的实例，无论如何切换 selection，TabView 将全程只使用这两个实例。

SwiftUI 可能随时销毁实例，并创建新的实例，也可能将实例保留较长的时间。总之，应避免对实例的创建、销毁的时机和频率进行假设。

```responser
id:1
```

### 视图值树中的视图的生命周期

#### 存活时间

同符合 View 协议的结构体实例的存活时间完全不确定相比，视图值树中的视图的生命周期则是容易判断的多。

每个视图值都有对应的标识符，视图值和标识符结合在一起代表屏幕上的某一块视图。 在 Source of trueh 发生变化后，视图值也会随之发生变化，但由于标识符不变，则该视图将仍然存在。

通常情况下，SwiftUI 在需要渲染屏幕某个区域或需要该区域的数据配合布局时，会在视图值树上创建对应的视图。当不再需要其参与布局或渲染时视图将被销毁。

极个别情况下，尽管某些视图暂时不需要参与布局与渲染，但 SwiftUI 出于效率的考量，仍然会将其保留在视图值树上。比如在 List 和 LazyVStack 中，Cell 视图在创建之后即使滚动出屏幕不参与布局与渲染，但 SwiftUI 仍会保留这些视图的数据，直到 List 或 LazyVStack 被销毁。

@State 和@StateObject，它们的生命周期同视图的生命周期是一致的，**这里所说的视图，便是视图值树中的视图**。如果感兴趣，可以使用@StateObject 来精确判断视图的生命周期。

#### onAppear 和 onDisappear

准确地说，视图值树中的视图，作为一个值在其生命周期中除了生死外，并没有其他的节点。但 onAppear 和 onDisappear 在行为表现上又确实与其有所关联。

需要注意的是，onAppear 和 onDisappear 中闭包的作用范围并非为包裹其的视图，而是其所附属视图，这点尤为重要！

SwiftUI 官方文档对 onAppear 和 onDisappear 的描述是：在此视图出现时执行的操作，在此视图消失时要执行的操作。这种描述与这两个修饰器在大多数场景下的行为很接近。因此，大家通常都会将其视作 UIKit 下的 viewDidAppear 和 viewDidDisappear 的 SwiftUI 版本，认为它们在生命周期中，只会出现一次。但，如果全方位分析它们的触发时机，便会发现它们的行为与描述并不完全相符。比如，在下面的几个场景中，onAppear 和 onDisappear 都将违背大多数认知：

* 在 ZStack 中，即使视图不显示，也同样会触发 onAppear，即使消失（不显示），也不会触发 onDisappear。视图保持存续状态

```swift
ZStack {
    Text("1")
        .opacity(selection == 1 ? 1 : 0)
        .onAppear { print("1 appear") }
        .onDisappear { print("1 disappear") }
    Text("2")
        .opacity(selection == 2 ? 1 : 0)
        .onAppear { print("2 appear") }
        .onDisappear { print("2 disappear") }
}

// Output
2 appear
1 appear
```

* 在 List 或 LazyVStack 中，Cell 视图进入屏幕后触发 onAppear，滚动出屏幕后会触发 onDisappear，在 Cell 视图的存续期内可以多次触发 onAppear 和 onDisappear

```swift
ScrollView {
    LazyVStack {
        ForEach(0..<100) { i in
            Text("\(i)")
                .onAppear { print("\(i) onAppear") }
                .onDisappear { print("\(i) onDisappear") }
        }
    }
}
```

* 在 ScrollView + VStack 中，即使 Cell 视图没有显示在屏幕中，仍会触发 onAppear

```swift
ScrollView {
    VStack {
        ForEach(0..<100) { i in
            Text("\(i)")
                .onAppear { print("\(i) onAppear") }
                .onDisappear { print("\(i) onDisappear") }
        }
    }
}
```

类似的例子还有很多，比如 TabView、或者将 frame 设置为 zero 等等。

由此可以看出在视图的存续期内，可以多次触发 onAppear 和 onDisappear。onAppear 和 onDisappear 的触发条件并非以是否 appear 或被看见为依据。

因此，我认为应该以**视图是否参与或影响了其父视图的布局作为 onAppear 和 onDisappear 的触发条件**。如果用此条件来解释上面的情况便完全可以说的通了。

* ZStack 中，即使层被隐藏，但被隐藏层也必然会影响父视图 ZStack 的布局规划。同理，将显示层切换为隐藏层后，该层仍参与布局，因此，ZStack 的所有层都会在最开始就触发 onAppear，但不会触发 onDisappear。

* 在 List 和 LazyVStack 中，SwiftUI 出于效率的考虑，即使 Cell 视图移出显示范围，它的视图仍将保留在视图值树上（视图仍将存续）。因此，当 Cell 视图出现在显示范围内（影响容器布局）会触发 onAppear，移出显示范围（不影响容器布局）会触发 onDisappar。在其存续期内可以反复触发。

  另外，由于 List 和 LazyVStack 的布局逻辑不同（List 的容器高度是固定的，LazyVStack 的容器高度是不固定的，向下预估的），两者触发 onDisappear 的时机点也不同。List 是上下两侧都会触发，LazyVStack 只有下方会触发。

* ScrollView + VStack 中，即使 Cell 视图没有出现在可见区域，但它在最开始就会参与容器的布局，因此会在创建初始便触发 onAppear，但无论如何滚动，所有的 Cell 视图始终会参与布局，因此并不会触发 onDisappear。

父视图恰恰是以该视图是否影响自身的布局为依据，来调用 onAppear 和 onDisappear 内的闭包，这也是为什么这两个修饰器的作用范围是父视图而不是视图本身。

#### task

task 有两种表现形式，一种与 onAppear 类似，另一种与 onAppear + onChange 类似（请参阅 [了解 SwiftUI 的 onChange](https://www.fatbobman.com/posts/onChange/)）。

同 onAppear 类似的版本，可以将其视为 onAppear 的异步版本。如果任务的执行时间较短，下面的代码也可以实现一样的效果：

```swift
.onAppear {
    Task{
        ....
    }
}
```

很多资料认为 task 与视图的生命周期相同，这是不准确的。更确切的表述应该是，当视图销毁时，将向 task 修饰器中的闭包发送任务取消的信号。至于是否取消，仍由 task 中的闭包自己决定。

```swift
struct ContentView: View {
    @State var show = true
    var body: some View {
        VStack {
            if show {
                Text("Hello, world!")
                    .padding()
                    .task{
                        var i = 0
                        while !Task.isCancelled {  // 尝试将本行代码改成 while true {
                            try? await Task.sleep(nanoseconds: 1_000_000_000)
                            print("task:",i)
                            i += 1
                        }
                    }
                    .onAppear{
                        Task{
                            var i = 0
                            while !Task.isCancelled {
                                try? await Task.sleep(nanoseconds: 1_000_000_000)
                                print("appear:",i)
                                i += 1
                            }
                        }
                    }

            }
            Button("show"){
                show.toggle()
            }
        }
    }
}
```

## 两种生命周期之间的关联

本节，我们将在上述两种生命周期之间寻找联系，进行汇总。

为了方便叙述，下文中将【符合 View 协议的结构体实例】简称为【实例】，将【视图值树中的视图】简称为【视图】。

* 必须先创建实例，才能生成视图
* 创建的实例并非一定会用于生成视图
* 在视图的生命周期中，可能创建多个实例
* 在视图的生命周期中，实例可能随时被销毁
* 在视图的生命周期中，至少始终保有一个实例
* 第一个生成视图值的实例，将完成依赖项的建立工作
* 在视图的生命周期中，只有一个依赖项副本
* 在视图的生命周期中，无论创建多少个实例，同一时间只有一个实例可以连接到依赖项
* 依赖项为视图的 Source of truth

## 了解 SwiftUI 视图的生命周期的意义

SwiftUI 试图淡化视图生命周期的概念，在大多数场景下确实实现了它的设计目标。开发者即使不了解文本上述的内容，也可以让 SwiftUI 的代码在日常中发挥出不错的效率。但如果能够对视图的生命周期有更深入的了解，将可以帮助开发者在一些特定的场合提高代码的执行效率。下文将举几个例子。

### 轻量化的构造器

目前，很多 SwiftUI 的开发者都已经注意到了结构体实例会被多次创建的问题。尤其在 WWDC 2020 的专题中已经明确告知应创建尽可能轻量化的结构体构造器后，开发者已经将很多原本在构造器中进行的数据准备工作转移到了 onAppear 中进行。

这在相当程度上改善了因多次创建实例而引发的效率问题。

### 让复杂的任务仅执行一次

但是，onAppear 或 task 也并非只会执行一次，如何保证让某些负担较重的任务只在页面中执行一次呢？利用@State 的生命周期同视图的生命周期一致的特性，便可以很好的解决这个问题。

```swift
struct TabViewDemo1: View {
    @State var selection = 1
    var body: some View {
        TabView(selection: $selection) {
            TabSub(idx: 1)
                .tabItem { Text("1") }
            TabSub(idx: 2)
                .tabItem { Text("2") }
        }
    }
}

struct TabSub: View {
    @State var loaded = false
    let idx: Int
    var body: some View {
        Text("View \(idx)")
            .onAppear {
                print("tab \(idx) appear")
                if !loaded {
                    print("load data \(idx)")
                    loaded = true
                }
            }
            .onDisappear{
                print("tab \(idx) disappear")
            }
    }
}

// OutPut
tab 1 appear
load data 1
tab 2 appear
load data 2
tab 1 disappear
tab 1 appear
tab 2 disappear
tab 2 appear
tab 1 disappear
tab 1 appear
```

### 减少视图的计算

在前文的视图值树介绍中我们提到，当 SwiftUI 重建该树时，如果树上某个节点（视图）的 Source of truth 没有发生变化，将不重新计算，直接使用旧值。利用这个特性，我们可以将视图结构体中的某些区域的定义拆分成可被节点承认的形式（符合 View 协议的结构体创建的视图），以提高视图树的刷新效率。

```swift
struct UpdateTest: View {
    @State var i = 0
    var body: some View {
        VStack {
            let _ = print("root update")
            Text("\(i)")
            Button("change") {
                i += 1
            }
            // circle 在每次刷新时都会重新计算
            VStack {
                let _ = print("circle update")
                Circle()
                    .fill(.red.opacity(0.5))
                    .frame(width: 50, height: 50)
            }
        }
    }
}
// Output
root update
circle update
root update
circle update
root update
circle update
```

将 Circle 拆分出来

```swift
struct UpdateTest: View {
    @State var i = 0
    var body: some View {
        VStack {
            let _ = print("root update")
            Text("\(i)")
            Button("change") {
                i += 1
            }
            UpdateSubView()
        }
    }
}

struct UpdateSubView: View {
    var body: some View {
        VStack {
            let _ = print("circle update")
            Circle()
                .fill(.red.opacity(0.5))
                .frame(width: 50, height: 50)
        }
    }
}

// Output
root update
circle update
root update
```

## 总结

SwiftUI 作为一个年轻的框架，大家对它的了解还不够深入。随着官方文档、WWDC 专题的不断完善，更多隐藏在 SwiftUI 背后的原理和机制将被开发者所认识并掌握。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
