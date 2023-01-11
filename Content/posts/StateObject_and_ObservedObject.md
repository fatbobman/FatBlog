---
date: 2022-10-11 08:12
description: StateObject 是在 SwiftUI 2.0 中才添加的属性包装器，它的出现解决了在某些情况下使用 ObservedObject 视图会出现超预期的问题。本文将介绍两者间的异同，原理以及注意事项。
tags: SwiftUI
title: StateObject 与 ObservedObject
image: images/StateObject_and_ObservedObject.png
---
StateObject 是在 SwiftUI 2.0 中才添加的属性包装器，它的出现解决了在某些情况下使用 ObservedObject 视图会出现超预期的问题。本文将介绍两者间的异同，原理以及注意事项。

## 先说结论

StateObject 和 ObservedObject 两者都是用来订阅可观察对象（ 符合 ObservableObject 协议的引用类型 ）的属性包装器。当被订阅的可观察对象通过内置的 Publisher 发送数据时（ 通过 @Published 或直接调用其 objectWillChange.send 方法 ），StateObject 和 ObservedObject 会驱动其所属的视图进行更新。

ObservedObject 在视图的存续期间只保存了订阅关系，而 StateObject 除了保存了订阅关系外还保持了对可观察对象的强引用。

基于 Swift 的 ARC（ 自动引用计数 ）机制，StateObject 保证了可观察对象的生存期必定不小于视图的存续期，从而确保了在视图的存续期内数据的稳定。

而由于 ObservedObject 只保存了订阅关系，一旦被订阅的可观察对象的生存期小于视图的存续期，视图会出现各种不可控的表现。

相信有人会提出这样的疑问，难道下面代码中的 testObject 对应的实例，其存续时间会小于视图的存续时间吗？

```swift
struct DemoView: View {
    @ObservedObject var testObject = TestObject()
    var body: some View {
        Text(testObject.name)
    }
}
```

在某些情况下，确实会是这样。下文中将详细探讨其中的原因。

```responser
id:1
```

## 原理

### ARC

Swift 使用自动引用计数（ ARC ）来跟踪和管理引用类型实例的内存使用情况。只要还有一个对类实例的强引用存在，ARC 便不会释放该实例占用的内存。换而言之，一旦对实例的强引用为 0 ，该实例将被 Swift 销毁，其所占用的内存也将被收回。

StateObject 通过保持一个对可观察对象的强引用，确保了该对象实例的存续期不小于视图的存续期。

### 订阅 与 Cancellable

在 Combine 中，当使用 sink 或 assign 来订阅某个 Publisher 时，必须要持有该订阅关系，才能让这个订阅正常工作，订阅关系被包装成 AnyCancellable 类型，开发者可以通过调用 AnyCancellable 的 cancel 方法手动取消订阅。

```swift
var cancellable: AnyCancellable?
init() {
    cancellable = NotificationCenter.default.publisher(for: .AVAssetContainsFragmentsDidChange)
        .sink { print($0) }
}

var cancellable = Set<AnyCancellable>()
init() {
    NotificationCenter.default.publisher(for: .AVAssetContainsFragmentsDidChange)
        .sink { print($0) }
        .store(in: &cancellable)
}
```

除了可以从订阅者一方主动取消订阅关系外，如果 Publisher 不复存在了，订阅关系也将自动解除。

ObservedObject 和 StateObject 两者都保存了视图与可观察对象的订阅关系，在视图存续期内，它们都不会主动取消这个订阅，但 ObservedObject 无法确保可观察对象是否会由于被销毁而提前取消订阅。

### 描述、实例与视图

SwiftUI 是一个声明式的框架，开发者用代码来声明（ 描述 ）想要的 UI 呈现。例如下面便是一个有关视图的声明（ 描述 ）：

```swift
struct DemoView:View{
    @StateObject var store = Store()
    var body: some View{
        Text("Hello \(store.username)")
    }
}
```

当 SwiftUI 开始创建以该描述生成的视图时，大致会进行如下的步骤：

* 创建一个 DemoView 的实例
* 进行与该视图有关的一些准备工作（ 例如依赖注入 ）
* 对该实例的 body 属性求值
* 渲染视图

从 SwiftUI 的角度来说，视图是对应着屏幕上某个区域的一段数据，它是通过调用某个根据描述该区域的声明所创建的实例的 body 属性计算而来。

视图的生存期从其被加载到视图树时开始，至其被从视图树上移走结束。

在视图的存续期中，视图值将根据 source of truth （ 各种依赖源 ）的变化而不断变化。SwiftUI 也会在视图存续期内因多种原因，**不断地依据描述该区域的声明创建新的实例**，从而保证始终能够获得准确的计算值。

由于实例是会反复创建的，因此，开发者必须用特定的标识（ @State、@StateObject 等 ）告诉 SwiftUI ，某些状态是与视图存续期绑定的，在存续期期间是唯一的。

当将视图加载到视图树时，SwiftUI 会根据当时采用的实例将需要绑定的状态（  @State、@StateObject、onReceive 等 ）托管到 SwiftUI 的托管数据池中，之后无论实例再被创建多少次，SwiftUI 始终只使用首次创建的状态。也就是说，为视图绑定状态的工作只会进行一次。

> 请阅读 [SwiftUI 视图的生命周期研究](SwiftUI 视图的生命周期研究) 一文，了解更多有关视图与实例之间的关系

### 属性包装器

Swift 的属性包装器（ Property Wrappers ）在管理属性存储方式的代码和定义属性的代码之间添加了一层分离。一方面它方便开发者将一些通用的逻辑统一封装起来，作用于给定的数据之上，另一方面如果开发者对某个属性包装器的用途不甚了解，那么就可能会出现看到的和实际上的不一致的情况（ 理解偏差 ）。

很多情况下，我们需要从视图的角度来理解 SwiftUI 的属性包装器名称，例如：

* ObservedObject （ 视图订阅某个可观察对象 ）
* StateObject（ 订阅某个可观察对象，并持有其强引用 ）
* State（ 持有某个值 ）

ObservedObject 和 StateObject 两者通过满足 DynamicProperty 协议从而实现上面的功能。在 SwiftUI 将视图添加到视图树上时，调用 _makeProperty 方法将需要持有的订阅关系、强引用等信息保存到 SwiftUI 内部的数据池中。

> 请阅读 [避免 SwiftUI 视图的重复计算](https://www.fatbobman.com/posts/avoid_repeated_calculations_of_SwiftUI_views/) 一文，了解更多有关 DynamicProperty 的实现细节

## ObservedObject 偶尔出现灵异现象的原因

如果使用类似 `@ObservedObject var testObject = TestObject()` 这样的代码，有时会出现灵异现象。

> 在 [@StateObject 研究](https://www.fatbobman.com/posts/stateobject/) 一文中，展示了因错误使用 ObservedObject 而引发灵异现象的代码片段

出现这种情况是因为一旦，在视图的存续期中，SwiftUI 创建了新的实例并使用了该实例（ 有些情况下，创建新实例并不一定会使用 ），那么，最初创建的 TestObject 类实例将被释放（ 因为没有强引用 ），ObservedObject 中持有的订阅关系也将无效。

某些视图，或许是由于其所处的视图树的层级很高（ 例如根视图 ），或者由于其本身的生存期较短，抑或者它受其他状态的干扰较少。上述条件促使了在该视图的存续期内 SwiftUI 只会创建一个实例。这也是 `@ObservedObject var testObject = TestObject()` 并非总会失效的原因。

## 注意事项

* 避免创建 `@ObservedObject var testObject = TestObject()` 这样的代码

  原因上文中已经介绍了。ObservedObject 的正确用法为：`@ObservedObject var testObject:TestObject` 。通过从父视图传递一个可以保证存续期长于当前视图存续期的可观察对象，从而避免不可控的情况发生

* 避免创建 `@StateObject var testObject:TestObject` 这样的代码

  与 `@ObservedObject var testObject = TestObject()` 类似， `@StateObject var testObject:TestObject` 偶尔也会出现与预期不符的状况。例如，在某些情况下，开发者需要父视图不断地生成全新的可观察对象实例传递给子视图。但由于子视图中使用了 StateObject ，它只会保留首次传入的实例的强引用，后面传入的实例都将被忽略。尽量使用 `@StateObject var testObject = TestObject()` 这样不容易出现歧义表达的代码

* 轻量化视图中使用的引用类型的构造方法

  无论使用 ObservedObject 还是 StateObject 抑或不添加属性包装器，在视图中声明的类实例，都会随着视图描述实例的创建而一遍遍地被多次创建。不在它的构造方法中引入无关的操作可以极大地减轻系统的负担。对于数据的准备工作，可以使用 onAppear 或 task ，在视图加载时进行。

## 总结

StateObject 和 ObservedObject 是我们经常会使用的属性包装器，它们都有各自擅长的领域。了解它们内涵不仅有助于选择合适的应用场景，同时也对掌握 SwiftUI 视图的存续机制有所帮助。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ) 或博客的留言板与我进行交流。

> 我正以聊天室、Twitter、博客留言等讨论为灵感，从中选取有代表性的问题和技巧制作成 Tips ，发布在 Twitter 上。每周也会对当周博客上的新文章以及在 Twitter 上发布的 Tips 进行汇总，并通过邮件列表的形式发送给订阅者。

**订阅下方的 [邮件列表](https://artisanal-knitter-2544.ck.page/d3591dd1e7)，可以及时获得每周的 Tips 汇总。**
