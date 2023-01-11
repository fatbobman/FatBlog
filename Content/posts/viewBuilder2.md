---
date: 2022-04-12 08:20
description: 在【ViewBuilder 研究（上）—— 掌握 Result builders】中，我们对 result builders 做了较详细的介绍。本篇我们将通过对 ViewBuilder 的仿制，探索更多有关 SwiftUI 视图背后的秘密。
tags: SwiftUI
title: ViewBuilder 研究（下） —— 从模仿中学习
image: images/viewbuilder_2.png
---

在[上篇](https://www.fatbobman.com/posts/viewBuilder1/)中，我们对 result builders 做了较详细的介绍。本篇我们将通过对 ViewBuilder 的仿制，探索更多有关 SwiftUI 视图背后的秘密。

## 视图能够提供的信息

> 本文中的视图是指符合 SwiftUI View 协议的各种类型

开发者通过 SwiftUI 框架提供的基础视图类型将自定义的视图串联起来，这些视图将向 SwiftUI 提供如下的信息：

* 界面设计

  开发者通过声明的方式对用户界面进行轻量级描述。 SwiftUI 会在恰当的时机从开发者创建的视图 body 属性中读取这些描述并进行绘制。

* 依赖

  我们常说，视图是状态的函数。对于单个视图来说，它的状态是由所有与之相关的依赖共同组成的。视图的依赖包括：视图的基本属性（无需符合 DynamicProperty 协议）、可驱动视图更新的属性 （ 符合 DynamicProperty 协议，例如 @State、@Environment 等）以及 onRecevie 等元素。

* 视图类型

  SwiftUI 根据视图层次结构（视图树）中的视图类型和具体位置来区分视图（谁是谁）。对 SwiftUI 来说视图的类型本身就是最重要的信息之一。

* 其他

  与当前视图有关的一些轻量级代码。

```responser
id:1
```

## SwiftUI 如何处理视图

SwiftUI 从加载视图、响应状态到屏幕绘制大概经历如下过程：

* 从根视图开始按视图层级结构沿特定分支（依据初始状态）逐个实例化视图，直到满足当前全部的显示所需
* 上述实例化后的视图值（结构值，非 body 值）将被保存在 SwiftUI 的托管数据池中
* 根据视图的依赖信息在 AttributeGraph 数据池中创建与当前显示的视图树对应的依赖图，并监控依赖的变化
* 依据 SwiftUI 数据池中视图值的 body 属性或视图类型的特定类型方法（非公开）进行布局和渲染
* 当用户或系统的某些行为导致依赖数据发生变化后，SwiftUI 将根据依赖图定位到需要重新评估的视图
* 以需重新评估的视图为根，按视图层级结构依当前状态逐个实例化视图类型（到满足全部显示所需为止）
* 将已不再需要参与布局和渲染的视图的值从 SwiftUI 数据池中移除，并在数据池中添加上新增的视图值
* 对于仍需显示但视图值发生变化的视图，使用新的视图值替换原有视图值
* 重组依赖图并绘制新增及发生变化的视图
* 周而复始、循环往复

## 仿制 ViewBuilder

ViewBuilder（视图构建器）将帮助开发者以一种简洁、清晰、易读的方式声明视图。对其实现原理尚不清楚朋友请先阅读 [ViewBuilder 研究（上）—— 掌握 Result builders](https://www.fatbobman.com/posts/viewBuilder1/)。

> 本文中仿制的 View协议、ViewBuilder 以及其他内容仅涉及 SwiftUI 框架内容的冰山一角。可在[此处](https://github.com/fatbobman/BlogCodes/tree/main/ViewBuilder/)获得本文的全部代码。

### 创建 View 协议

既然视图指是符合 View 协议的各种类型，我们首先需要定义自己的 View 协议。

```swift
import Foundation

public protocol View {
    associatedtype Body: View
    var body: Self.Body { get }
}
```

View 协议的公开接口非常简单，开发者自定义的视图类型只需提供一个符合 View 协议的 body 属性即可。SwiftUI 是怎样通过如此简单的接口完成上面缜密的视图处理过程呢？答案是：不能！

SwiftUI View 协议还有三个没有公开的接口，它们是：

```swift
static func _makeView(view: SwiftUI._GraphValue<Self>, inputs: SwiftUI._ViewInputs) -> SwiftUI._ViewOutputs
static func _makeViewList(view: SwiftUI._GraphValue<Self>, inputs: SwiftUI._ViewListInputs) -> SwiftUI._ViewListOutputs
static func _viewListCount(inputs: SwiftUI._ViewListCountInputs) -> Swift.Int?
```

一个完整功能的视图类型应该提供上述要求的全部定义。目前无法自行实现这几个非公开的方法，仅能使用 SwiftUI 提供的默认实现。但 SwiftUI 框架提供的基本视图类型则充分利用了这些接口以实现各自的不同需求。

如果你查看 SwiftUI 的文档，它所提供的基本视图类型（例如：Text、EmptyView、Group 等等）的 body 类型大多都是 Never ，这与开发者的自定义视图类型截然不同。

这些使用了 Never 作为 body 属性类型的视图主要分为几类：

* 定义布局

  例如：VStack、HStack、Spacer

* 沟通底层绘制元素

  例如：Text、TextField、UIViewControllerRepresentable

* 类型占位与擦除

  例如：EmptyView、AnyView

* 包装

  例如：ModifiedContent、Group

* 逻辑描述：

  例如：_ConditionalContent

SwiftUI 在碰到这些视图类型时，并不会尝试获取它们的 body 属性内容（ Never 是不可触碰的），而是按照其各自特定的逻辑来进行处理。

因此，我们需要让 Never 符合 View 协议以继续下面的工作：

```swift
extension Never: View {
    public typealias Body = Never
    public var body: Never { fatalError() }
}
```

### 创建 EmptyView

有了 View 协议后，我们将创建第一个基础视图 EmptyView 。顾名思义，EmptyView 就是一个什么都不做的空视图：

```swift
public struct EmptyView: View {
    public typealias Body = Never
    public var body: Never { fatalError() }
    public init() {}
}
```

> 本文中，我们主要的目的是让 ViewBuilder 的逻辑跑起来，仅需让视图类型满足 View 协议的公开要求即可。

### 类型打印工具

为了在下文中更好的比对我们自定义的 ViewBuilder 同 SwiftUI 官方的 ViewBuilder 之间对视图类型的解析是否一致，我们还需要准备一个视图扩展方法（对原装和仿制的都有效）：

```swift
public extension View {
    func debug() -> some View {
        let _ = print(Mirror(reflecting: self).subjectType)
        return self
    }
}
```

在 SwiftUI 下使用 debug 打印视图的类型信息示例如下：

```swift
struct ContentView:View {
    var body: some View {
        Group {
            Text("Hello")
            Text("World")
        }
        .debug()
    }
}

// Group<TupleView<(Text, Text)>>
```

打印的内容将向我们展示当前的视图层次结构，我们的自定义 ViewBuilder 应该能生成同 SwiftUI 的 ViewBuilder 几乎一样的信息。

### 创建 ViewBuilder

对于一个 result builders 来说，至少应该提供一个 [buildBlock](https://www.fatbobman.com/posts/viewBuilder1/#使用构建器转译_Block) 的实现。

```swift
@resultBuilder
public enum ViewBuilder {
    // 对于空闭包，将返回类型设定为 EmptyView
    public static func buildBlock() -> EmptyView {
        EmptyView()
    }
}
```

恭喜你，至此我们已经完成了对 ViewBuilder 的最基础的创建工作。

使用它来解析第一个视图：

```swift
@ViewBuilder
func myFirstView() -> some View {}
```

通过 debug 查看视图的类型信息：

```swift
print(type(of: myFirstView()))
// EmptyView
```

现在我们可以在之前的 View 协议以及 debug 扩展中使用 ViewBuilder 了，将它们改为：

```swift
public protocol View {
    associatedtype Body: View
    @ViewBuilder var body: Self.Body { get }  // 添加了 @ViewBuilder
}

public extension View {
    @ViewBuilder
    func debug() -> some View {
        let _ = print(Mirror(reflecting: self).subjectType)
        self
    }
}
```

### 创建更多的 buildBlock

上文中仅提供了一个支持空闭包（ 0 个component ）的 buildBlock 实现，下面的代码将允许我们在视图声明中添加一个 component （视图）：

```swift
// 对于单个 component ，buildBlock 将保留它的原始类型
public static func buildBlock<Content>(_ content: Content) -> Content where Content: View {
    content
}
```

现在就可以在闭包中添加一个 component 了：

```swift
struct ContentView:View {
    var body: some View {
        EmptyView()
    }
}

ContentView().body.debug() // 因为我们的视图无法加载，需要使用这种方法来获得视图 body 的类型信息
// EmptyView
```

此时如果现在我们在闭包中添加两个 EmptyView 会如何呢？

![image-20220406164006295](https://cdn.fatbobman.com/image-20220406164006295.png)

由于目前仅定义了支持 0 个和 1 个 component 的 buildBlock ，编译器会提示我们无法找到对应的 buildBlock 实现。

因为 View 协议中使用了关联类型，所以我们无法像上篇的 AttributedTextBuilder 那样使用数组来处理任意数量的 component 。SwiftUI 通过创建多个返回类型为 TupleView 的 buildBlock 重载来应对不同数量的 component 情况。

创建 TupleView 基础视图类型：

```swift
public struct TupleView<T>: View {
    var content: T
    public var body: Never { fatalError() }
    public init(_ content: T) {
        self.content = content
    }
}
```

创建更多的 buildBlock :

```swift
// 针对 2 个到 10 个的 component，返回类型为 TupleView<>
public extension ViewBuilder {
    static func buildBlock<C0, C1>(_ c0: C0, _ c1: C1) -> TupleView<(C0, C1)> where C0: View, C1: View {
        TupleView((c0, c1))
    }

    static func buildBlock<C0, C1, C2>(_ c0: C0, _ c1: C1, _ c2: C2) -> TupleView<(C0, C1, C2)> where C0: View, C1: View, C2: View {
        .init((c0, c1, c2))
    }

    static func buildBlock<C0, C1, C2, C3>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) -> TupleView<(C0, C1, C2, C3)> where C0: View, C1: View, C2: View, C3: View {
        .init((c0, c1, c2, c3))
    }
    
    // ... 
}
```

当前的 SwiftUI 只创建了至多支持 10 个 component 的 buildBlock 重载，因此我们在视图闭包中的同一个层次最多只能声明 10 个视图。如果你想让 SwiftUI 支持更多的 component 数量，只需创建更多的重载即可。

```swift
// 现在我们可以在闭包中声明更多的视图了
struct ContentView:View {
    var body: some View {
        EmptyView()
        EmptyView()
    }
}

ContentView().body.debug()
// TupleView<(EmptyView, EmptyView)>
```

> 目前有一个针对 result builds 的[提案](https://github.com/apple/swift-evolution/blob/main/proposals/0348-buildpartialblock.md)正在审议中。添加了 buildPartialBlock 方法。如该提案通过，只需实现 `buildPartialBlock(first: Component) -> Component`和 `buildPartialBlock(accumulated: Component, next: Component) -> Component` 两个方法即可应对任意数量的 component 。

### 创建更多的基础视图

目前我们已经创建了两个基础视图类型： EmptyView 及 TupleView ，接下来将创建更多的基础视图类型为之后做准备。

* Group

```swift
public struct Group<Content>: View {
    var content: Content
    public var body: Never { fatalError() }
    public init(@ViewBuilder _ content: () -> Content) {
        self.content = content()
    }
}

struct ContentView: View {
    var body: some View {
        Group {
            EmptyView()
            EmptyView()
        }
    }
}

ContentView().body.debug()
// Group<TupleView<(EmptyView, EmptyView)>>
```

* Text

```swift
public struct Text: View {
    public typealias Body = Never
    public var body: Never { fatalError() }
    var content: String //SwiftUI 中，会通过一个枚举类型来区分 String 同 LocalizedStringKey ，仿制过程将一律简化
    public init(_ content: String) {
        self.content = content
    }
}

struct ContentView: View {
    var body: some View {
        Group {
            EmptyView()
            Text("hello world")
        }
    }
}

// Group<TupleView<(EmptyView, Text)>>
```

```responser
id:1
```

### 在不同的分支中保存类型信息

在上篇的[添加对多分支选择的支持](https://www.fatbobman.com/posts/viewBuilder1/#添加对多分支选择的支持)一节中， AttributedStringBuilder 在处理选择时，仅需考虑当前的分支而无需考虑另一条未被调用的分支。AttributedStringBuilder 的定义如下：

```swift
// 对条件为真的分支调用 （左侧分支）
public static func buildEither(first component: AttributedString) -> AttributedString {
    component
}

// 对条件为否的分支调用 （右侧分支）
public static func buildEither(second component: AttributedString) -> AttributedString {
    component
}
```

但 SwiftUI 需要通过视图的类型和位置对视图进行标识，因此在处理选择分支时，无论该分支是否被显示，在视图代码被编译后，所有分支的类型信息都需要明确下来。SwiftUI 利用 _ConditionalContent 视图类型来达成此目的。

```swift
public struct _ConditionalContent<TrueContent, FalseContent>: View {
    public var body: Never { fatalError() }
    let storage: Storage
    // 利用枚举锁定类型信息
    enum Storage {
        case trueContent(TrueContent)
        case falseContent(FalseContent)
    }

    init(storage: Storage) {
        self.storage = storage
    }
}

public static func buildEither<TrueContent, FalseContent>(first content: TrueContent) -> _ConditionalContent<TrueContent, FalseContent> where TrueContent: View, FalseContent: View {
    .init(storage: .trueContent(content))
}

public static func buildEither<TrueContent, FalseContent>(second content: FalseContent) -> _ConditionalContent<TrueContent, FalseContent> where TrueContent: View, FalseContent: View {
    .init(storage: .falseContent(content))
}
```

> 参照 SwiftUI ViewBuilder 的实现，上面的代码是可以正常运行的。但对 buildEither 能同时推断 TrueContent 和 FalseContent 两个的类型的能力我无法理解。是编译器为 result builders 开的后门吗？希望了解的朋友能给一点提示。

如此一来，不同分支的类型都将在编译后被固定下来。

```swift
struct ContentView: View {
    var show: Bool
    var body: some View {
        if show {
            Text("hello")
        } else {
            Text("hello")
            Text("world")
        }
    }
}

ContentView(show:true).body.debug()
// _ConditionalContent<Text, TupleView<(Text, Text)>>

struct ContentView: View {
    var selection: Int
    var body: some View {
        switch selection {
            case 1:
                Text("喜羊羊")
            case 2:
                Text("灰太狼")
            default:
                Text("懒羊羊")
        }
    }
}

ContentView(selection: 2).body.debug()
// _ConditionalContent<_ConditionalContent<Text, Text>, Text>
```

这个实现对于 SwiftUI 至关重要，它是隐式标识的重要保证之一。

### 不一样的 buildOptional

在仿制 ViewBuilder 的过程中，唯有 [buildOptional](https://www.fatbobman.com/posts/viewBuilder1/#添加选择语句支持（_不带_else_的_if_）) 我无法实现的同 SwiftUI 完全一致。这是因为在 SwiftUI 诞生时，result builders 使用 buildIf 来处理不包含 `else` 的 `if` 语句。尽管当前仍支持 buildIf ，但已经无法像官方的 ViewBuilder 版本那样返回 Optional 类型的数据了。

```swift
// SwiftUI 的 ViewBuilder 的 buildIf 定义
public static func buildIf<Content>(_ content: Content?) -> Content? where Content : View
```

如果我们也定义成 `Content?` 编译器将无法通过。我们可以通过在 buildOptional 中使用  _ConditionalContent 实现一样的目的（处理不包含 `else` 的 `if` 语句）：

```swift
public static func buildOptional<Content>(_ content: Content?) -> _ConditionalContent<Content, EmptyView> where Content: View {
    guard let content = content else {
        return .init(storage: .falseContent(EmptyView()))
    }
    return .init(storage: .trueContent(content))
}
```

尽管实现同原版的略有不同，但转译后的实现的显示效果完全一致。我们可以通过如下的方式在 SwiftUI 中验证上述代码：

* 在 SwiftUI 环境中添加如下代码

```swift
public extension ViewBuilder {
    static func buildOptional<Content>(_ content: Content?) -> _ConditionalContent<Content, EmptyView> where Content: View {
        guard let content = content else {
            return buildEither(second: EmptyView())
        }
        return buildEither(first: content) // 因为 _ConditionalContent 的构造器没有开放 public 权限，使用 buildEither 过渡一下
    }
}
```

> buildOptional 的优先级高于 buildIf , SwiftUI 的 ViewBuilder 将使用我们提供的 buildOptional 来处理不包含 `else` 的 `if` 语句

* 在 SwiftUI 环境中创建如下视图

```swift
struct ContentView: View {
    var show: Bool
    var body: some View {
        Group {
            if show {
                Text("Hello")
            }
            Text("World")
        }
        .debug()
    }
}

// Group<TupleView<(Optional<Text>, Text)>>  原装的 ViewBuilder 的解析类型（通过 buildIf ）
// Group<TupleView<(_ConditionalContent<Text, EmptyView>, Text)>> 仿制的 ViewBuilder 的解析类型（通过 buildOptional ）
```

虽然两者转译后的类型略有不同，但在显示效果上是完全一样的。

### 支持 API 可用性检查

result builders 通过 [buildLimitedAvailablility](https://www.fatbobman.com/posts/viewBuilder1/#提高版本兼容性) 提供对 API 可用性检查的支持。它会和 buildOptional 或 buildEither 一并使用，在满足了 API 可用性检查的情况下会调用该实现。

请考虑下面 buildLimitedAvailability 的代码有什么不妥：

```swift
public static func buildLimitedAvailability<Content>(_ content: Content) -> Content where Content: View {
    content
}

@available(macOS 14, iOS 16,*)
struct MyText: View {
    var body: some View {
        Text("abc")
    }
}

struct TestView: View {
    var body: some View {
        if #available(macOS 14, iOS 16, *) {
            MyText()
        }
    }
}
```

由于 MyText 仅应出现在 macOS 14 或 iOS 16 以上的版本，尽管我们已经提供了 buildLimitedAvailability 实现，但在编译该代码时，仍将会得到如下的错误提示：

![image-20220407092636776](https://cdn.fatbobman.com/image-20220407092636776.png)

这是因为，SwiftUI 会在编译之后将所有视图的类型固定下来（无论是否执行该分支），而在低版本的系统中并没有 MyText 的定义。为了解决这个问题，我们需要将 MyText 转换成在低版本系统下可识别的类型。因此 buildLimitedAvailability 的最终定义如下：

```swift
public static func buildLimitedAvailability<Content>(_ content: Content) -> AnyView where Content: View {
    AnyView(content)
}
```

### 创建 AnyView

在 Swift 的世界中难免会碰到需要使用类型擦除的场景，SwiftUI 也无法避免。例如，上文中 buildLimitedAvailability  通过返回 AnyView 实现在低版本系统中隐藏尚不支持的视图类型；亦或将不同类型的视图转换为 AnyView（ View 协议使用了关联类型）以保存至数组。

由于 SwiftUI 通过视图层次结构中的类型和位置来对视图进行标识，AnyView 将会擦除（隐藏）掉这些重要的信息，因此除非到了必须使用的地步，否则**我们应尽量避免在 SwiftUI 中使用 AnyView。**

为了让 ViewBuilder 的仿制过程能够继续下去，我们也需要创建一个 AnyView 类型。

```swift
// 有多种方法可以实现类型擦除，本例中的 AnyView 实现与 SwiftUI 的实现有较大区别
protocol TypeErasing {
    var view: Any { get }
}

public struct AnyView: View {
    var eraser: TypeErasing
    public var body: Never { fatalError() }
    public init<V>(_ content: V) where V: View {
        self.eraser = ViewEraser(content)
    }

    var wrappedView: Any {
        eraser.view
    }

    class ViewEraser<V: View>: TypeErasing {
        let originalView: V
        var view: Any {
            originalView
        }

        init(_ view: V) {
            self.originalView = view
        }
    }
}
```

现在，下面的代码就可以正常编译了：

```swift
struct TestView: View {
    var body: some View {
        if #available(macOS 14, iOS 16, *) {
            MyText()
        }
    }
}

// _ConditionalContent<AnyView, EmptyView>
```

> 苹果在 WWDC 2021 的 [Demystify SwiftUI](https://developer.apple.com/videos/play/wwdc2021/10022/) 专题中特别指出了应减少 AnyView 的使用。AnyView 除了会隐藏重要的类型和位置信息外，转换过程也会导致一定的性能损失。不过，SwiftUI 的 AnyView 实现得十分精妙，通过将大量的原始信息（依赖、分解后的视图值等）保存在其中，将性能损失降至相当低的程度。

至此，我们已经基本完成了对 SwiftUI 的 ViewBuilder 的仿制，创建了一个可以表述视图层次结构的构建器。

### 其他的 result builders 方法

SwiftUI 的 ViewBuilder 并没有支持 buildExpression、buildArray 以及 buildFinalResult 等方法。如果你自己有需要，可以对其进行扩展，例如可以参照上篇中的范例，通过 buildExpression 将字符串直接转换成 Text 。

## 没有 Modifier 的视图是不完整的

SwiftUI 通过视图修饰符（ ViewModifier ）为视图的声明提供了巨大的灵活性。在本文的最后一部分，我们将对 Modifier 做一点探讨。

### 创建通用的 ViewModifier

SwiftUI 为我们提供了大量的 modifier，比如下面的代码：

```swift
struct TestView: View {
    var body: some View {
        VStack {
            Text("Hello world")
                .background(Color.blue)
        }
        .frame(width: 100, height: 200, alignment: .leading)
    }
}

// ModifiedContent<VStack<ModifiedContent<Text, _BackgroundModifier<Color>>>, _FrameLayout>
```

background（ `_BackgroundModifier` ）和 frame （ `_FrameLayout` ）都是内置的 Modifier。

ViewBuilder 是视图构建器，根据 buildBlock 的定义，它的每个 component 都必须符合 View 协议。开发者通过 Modifier 在视图中表述自己的想法，SwiftUI 只会在布局和渲染时才会真正调用这些 modifier 的实现。考虑到 View 协议所能提供的 API 有限，无法应对 modifier 的各种需求，SwiftUI 通过 ViewModifier 协议（ _ViewModifier_Content ）为 modifier 提供了更多的表述空间。

首先，我们先仿制一个 ViewModifier 协议：

```swift
public protocol ViewModifier {
    associatedtype Body: View
    typealias Content = _ViewModifier_Content<Self>
    @ViewBuilder func body(content: Content) -> Self.Body
}

// _ViewModifier_Content 提供了额外的 API ，在此就不进行复现了。
public struct _ViewModifier_Content<Modifier>: View where Modifier: ViewModifier {
    public typealias Body = Never
    public var body: Never { fatalError() }
}
```

创建 ModifiedContent 视图类型：

```swift
public struct ModifiedContent<Content, Modifier>: View where Content: View, Modifier: ViewModifier {
    public typealias Body = Never
    public var content: Content
    public var modifier: Modifier
    public init(content: Content, modifier: Modifier) {
        self.content = content
        self.modifier = modifier
    }

    public var body: ModifiedContent<Content, Modifier>.Body {
        fatalError()
    }
}
```

仿造一个 overlay 方法：

```swift
public struct _OverlayModifier<Overlay>: ViewModifier where Overlay: View {
    public var overlay: Overlay
    public init(overlay: Overlay) {
        self.overlay = overlay
    }

    public func body(content: Content) -> Never {
        fatalError()
    }
}

public extension View {
    func modifier<T>(_ modifier: T) -> ModifiedContent<Self, T> {
        .init(content: self, modifier: modifier)
    }

    func overlay<Overlay>(_ overlay: Overlay) -> some View where Overlay: View {
        modifier(_OverlayModifier(overlay: overlay))
    }
    
    func overlay<Overlay>(@ViewBuilder _ overlay: () -> Overlay) -> some View where Overlay: View {
        modifier(_OverlayModifier(overlay: overlay()))
    }
}

struct TestView: View {
    var body: some View {
        Group {
            Text("Hello")
        }
        .overlay(Text("world"))
    }
}
// ModifiedContent<Group<Text>, _OverlayModifier<Text>>
```

ModifiedContent 通过泛型 `<Content, Modifier>` 在视图层次结构中对自身进行标识。

### 为特定视图类型创建 Modifier

除了符合 ViewModifier 协议的通用 modifier 外，SwiftUI 中还有很多仅适用于特定视图类型的 modifier，比如 Text 、TextField、ForEach 等等都有其专有的修饰符。它们的实现要比通用 modifier 简单的多，但同[在 SwiftUI 中使用 UIKit 视图](https://fatbobman.com/posts/uikitInSwiftUI/#SwiftUI_风格化) 一文中介绍的方式略有不同。

以 Text 的 foregroundColor 举例：

```swift
public struct Text: View {
    public typealias Body = Never
    public var body: Never { fatalError() }
    var content: String 
    var modifiers: [Modifier] = []  // 记录所使用的 Modifier
    public init(_ content: String) {
        self.content = content
    }
}

public extension Text {
    // SwiftUI 通过枚举列出了仅适用于 Text 视图类型的 modifier
    enum Modifier {
        case color(Color?)
        /*
        case font(Font?)
        case italic
        case weight(Font.Weight?)
        case kerning(CGFloat)
        case tracking(CGFloat)
        case baseline(CGFloat)
        case rounded
        case anyTextModifier(AnyTextModifier)
        */
    }
}
```

扩展 Text ：

```swift
func foregroundColor(_ color: Color?) -> Text {
    guard !modifiers.contains(where: {
        if case .color = $0 { return true } else { return false }
    }) else { return self }
    var text = self
    text.modifiers.append(.color(color))
    return text
}
```

此种处理 modifier 的方式有如下优点：

* 转译时仅传递信息，只在布局或渲染时才会真正处理 modifier
* 方便兼容不同的框架（ UIKit 、AppKit ）
* modifier 的优先级逻辑同 SwiftUI 的通用 modifier 一致 —— 内层优先

## 总结

result builders 已经推出一段时间了，但一直没有对其进行深入地研究。最初只想通过仿制 ViewBuilder 加深对 result builders 的理解，但没想到此次的仿制过程，让我厘清了不少与 SwiftUI 视图有关的困惑，可谓意外之喜。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。

