---
date: 2022-07-05 08:11
description: “对齐”是 SwiftUI 中极为重要的概念，然而相当多的开发者并不能很好地驾驭这个布局利器。在 WWDC 2022 中，苹果为 SwiftUI 增添了 Layout 协议，让我们有了更多的机会了解和验证 SwiftUI 的布局原理。本文将结合 Layout 协议的内容对 SwiftUI 的 “对齐” 进行梳理，希望能让读者对“对齐”有更加清晰地认识和掌握。
tags: SwiftUI,WWDC22,布局
title: SwiftUI 布局 —— 对齐
image: images/layout-alignment.png
---
“对齐”是 SwiftUI 中极为重要的概念，然而相当多的开发者并不能很好地驾驭这个布局利器。在 WWDC 2022 中，苹果为 SwiftUI 增添了 Layout 协议，让我们有了更多的机会了解和验证 SwiftUI 的布局原理。本文将结合 Layout 协议的内容对 SwiftUI 的 “对齐” 进行梳理，希望能让读者对“对齐”有更加清晰地认识和掌握。

> 本文并不会对 alignment 、alignmentGuide 等内容作详尽的介绍，想了解更多的内容可以阅读文中推荐的资料。可以在此处下载 [本文所需的源代码](https://github.com/fatbobman/BlogCodes/tree/main/MyZStack)

## 什么是对齐（ Alignment ）

对齐是发生在多个对象之间的一种行为。比如将书桌上的一摞书摆放整齐，列队训练时向左（右）看齐等等。在 SwiftUI 中，对齐是指在布局容器中，将多个视图按照对齐指南（ Alignment Guide ）进行对齐。比如下面的代码便是要求 ZStack 容器内的所有视图，按照各自的中心点进行对齐：

```swift
ZStack(alignment: .center) {
    Text("Hello")
    Text("World")
    Circle()
        .frame(width: 50, height: 50)
}
```

在“对齐”行为中最关键的两点为：

* 以什么为对齐指南
* 对哪些视图进行“对齐”

```responser
id:1
```

## 对齐指南

### 概述

对齐指南（ alignment guide）用来标识视图间进行对齐的依据，它具备如下特点：

* 对齐指南不仅可以标识点，还可以标识线

  在 SwiftUI 中，分别用 HorizontalAlignment 和 VerticalAlignment 来标识在视图纵轴和横轴方向的参考线，并且可以由两者共同构成对视图中的某个具体的参考点的标识。

HorizontalAlignment.leading 、HorizontalAlignment.center 、HorizontalAlignment.trailing 分别标识了前沿、中心和后缘（ 沿视图水平轴 ）。

VerticalAlignment.top 、VerticalAlignment.center 、VerticalAlignment.bottom 则分别标识了顶部、中心和底部（ 沿视图垂直轴 ）。

而 Alignment.topLeading 则由 HorizontalAlignment.leading 和 VerticalAlignment.top 构成，两条参考线的交叉点标识了视图的顶部—前沿。

![image-20220704154347077](https://cdn.fatbobman.com/image-20220704154347077.png)

![image-20220704154754068](https://cdn.fatbobman.com/image-20220704154754068.png)

* 对齐指南由函数构成

  HorizontalAlignment 和 VerticalAlignment 本质上是一个返回类型为 CGFloat 的函数。该函数将返回沿特定轴向的对齐位置（ 偏移量 ）

* 对齐指南支持多种布局方向

  正是由于对齐指南由函数构成，因此其先天便具备了灵活的适应能力。在 SwiftUI 中，系统预置对齐指南都提供了对不同布局方向的支持。只需修改视图的排版方向，对齐指南将自动改变其对应的位置

```swift
VStack(alignment:.leading){
    Text("Hello world")
    Text("WWDC 2022")
}
.environment(\.layoutDirection, .rightToLeft)
```

![image-20220629202253658](https://cdn.fatbobman.com/image-20220629202253658.png)

![image-20220629202556777](https://cdn.fatbobman.com/image-20220629202556777.png)

> 想更多地了解自定义对齐指南以及 Alignment Guide 的应用案例，推荐阅读 Javier 的 [Alignment Guides in SwiftUI](https://swiftui-lab.com/alignment-guides/) 一文

### 自定义对齐指南

除了 SwiftUI 提供的预置对齐指南外，开发者也可以自定义对齐指南：

```swift
struct OneThirdWidthID: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> CGFloat {
        context.width / 3
    }
}
// 自定义了一个 HorizontalAlignment , 该参考值为视图宽度的三分之一
extension HorizontalAlignment {
    static let oneThird = HorizontalAlignment(OneThirdWidthID.self)
}

// 也可以为 ZStack 、frame 定义同时具备两个维度值的参考点
extension Alignment {
    static let customAlignment = Alignment(horizontal: .oneThird, vertical: .top)
}
```

自定义对齐指南与 SwiftUI 预置的对齐指南一样，可用于任何支持对齐的容器视图。

### alignmentGuide 修饰器

在 SwiftUI 中，开发者可以使用 alignmentGuide 修饰器来修改视图某个对齐指南的值（ 为对齐指南设定显式值，有关显式值见下文）。比如：

```swift
struct AlignmentGuideDemo:View{
    var body: some View{
        VStack(alignment:.leading) {
            rectangle // Rectangle1
                .alignmentGuide(.leading, computeValue: { viewDimensions in
                    let defaultLeading = viewDimensions[.leading] // default is 0
                    let newLeading = defaultLeading + 30
                    return newLeading
                })

            rectangle // Rectangle2
        }
        .border(.pink)
    }

    var rectangle:some View {
        Rectangle()
            .fill(.blue.gradient)
            .frame(width: 100, height: 100)
    }
}
```

通过 alignmentGuide 我们将 Rectangle1 的 HorizontalAlignment.leading 沿水平轴向右侧偏移了 30 ，与 Rectangle2 在 VStack 中按 .leading 对齐后结果如下图：

![image-20220704171710023](https://cdn.fatbobman.com/image-20220704171710023.png)

### 对齐指南的显式值

对齐指南值 = 显式值 ?? 默认值

视图中的每个对齐指南都有默认值（ 通过在对齐指南定义中的 defaultValue 方法获取 ）。在不为对齐指南设置显式值（ 显式值为 nil ）的情况下，对齐指南将返回默认值。

```swift
Rectangle()
    .fill(.blue.gradient)
    .frame(width: 100, height: 100)
// 默认的对齐指南值：
// leading: 0 , HorizontalAlignment.center: 50, trailing: 100
// top: 0 , VerticalAlignment.center: 50 , bottom: 100
// firstTextBaseline : 100 , lastTextBaseline : 100
```

如果我们使用了 alignmentGuide 为某个对齐指南设置了显式值，那么此时对齐指南的值为我们设置的显式值。

```swift
Rectangle()
    .fill(.blue.gradient)
    .frame(width: 100, height: 100)
    .alignmentGuide(.leading, computeValue: { viewDimensions in
        let leading = viewDimensions[.leading] // 由于此时显式值为 nil , 因此 leading 值为 0
        return viewDimensions.width / 3 // 将 leading 的显式值设置为宽度三分之一处
    })
    .alignmentGuide(.leading, computeValue: { viewDimensions in
        let leading = viewDimensions[.leading] //  因为上面设置了显式值，此时 leading 值为 33.33
        let explicitLeading = viewDimensions[explicit: .leading] // 显式值 , 此时为 Optional(33.33)
        return viewDimensions[HorizontalAlignment.center] // 再度设置 leading 的显式值。此时显式值为 Optional(50) , .leading 值为 50
    })
```

即使你没有修改对齐指南的默认值，但只要为 alignmentGuide 提供了返回值，便设置了显式值：

```swift
Rectangle()
    .fill(.blue.gradient)
    .frame(width: 100, height: 100)
    .alignmentGuide(.leading, computeValue: { viewDimensions in
        let leading = viewDimensions[.leading] // 此时 leading 的显式值为 nil
        return leading  // 此时 leading 为 0 ，leading 的显式值为 0
    })
```

### 特殊的对齐指南

在上文中，我们故意避开了两个容易令人困惑的对齐指南：firstTextBaseline、lastTextBaseline 。因为这两个对齐指南会根据视图内容的不同而变化。

在阅读下面的代码时，请在心中自行分析一下视图对应的 firstTextBaseline 和 lastTextBaseline 对齐指南的位置：

```swift
Rectangle()
    .fill(.orange.gradient)
    .frame(width: 100, height: 100)
```

![image-20220629205343135](https://cdn.fatbobman.com/image-20220629205343135.png)

> 视图中没有文字，firstTextBaseline 和 lastTextBaseline 等同于 bottom

```swift
Text("Hello world")
    .border(.red)
```

![image-20220704175657449](https://cdn.fatbobman.com/image-20220704175657449.png)

> 单行文字，firstTextBaseline 和 lastTextBaseline 相同。文字基线不同于 bottom

```swift
Text("山不在高，有仙则名。水不在深，有龙则灵。斯是陋室，惟吾德馨。苔痕上阶绿，草色入帘青。谈笑有鸿儒，往来无白丁。可以调素琴，阅金经。无丝竹之乱耳，无案牍之劳形。南阳诸葛庐，西蜀子云亭。孔子云：何陋之有？")
    .frame(width:200)
```

![image-20220704175811856](https://cdn.fatbobman.com/image-20220704175811856.png)

> 多行文字，firstTextBaseline 为第一行文字基线，lastTextBaseline 为最后一行文字基线

SwiftUI 对于布局容器（ 复合视图 ）的 firstTextBaseline 和 lastTextBaseline 的不透明计算方法，是产生困惑的主要原因。

```swift
Button("Hello world"){}
    .buttonStyle(.borderedProminent)
    .controlSize(.large)
```

![image-20220629212234572](https://cdn.fatbobman.com/image-20220629212234572.png)

```swift
Button(action: {}, label: {
    Capsule(style: .circular).fill(.yellow.gradient).frame(width: 30, height: 15)
})
.buttonStyle(.borderedProminent)
.controlSize(.large)
```

![image-20220630112907178](https://cdn.fatbobman.com/image-20220630112907178.png)

```swift
Text("Hello world")
    .frame(width: 100, height: 100, alignment: .topLeading)
    .border(.red)
```

![image-20220629210927483](https://cdn.fatbobman.com/image-20220629210927483.png)

```swift
VStack {
    Rectangle().fill(.red.gradient).frame(width: 50, height: 10)
    Text("Hello world")
    Text("WWDC 2022")
    Text("肘子的 Swift 记事本")
    Rectangle().fill(.blue.gradient).frame(width: 50, height: 10)
}
.border(.red)
```

![image-20220630112242594](https://cdn.fatbobman.com/image-20220630112242594.png)

```swift
VStack {
    Rectangle().fill(.red.gradient).frame(width: 50, height: 50)
    Rectangle().fill(.blue.gradient).frame(width: 50, height: 50)
}
.border(.red)
```

![image-20220630112428784](https://cdn.fatbobman.com/image-20220630112428784.png)

```swift
HStack(alignment: .center) {
    Rectangle().fill(.blue.gradient).frame(width: 20, height: 50)
    Text("Hello world")
        .frame(width: 100, height: 100, alignment: .top)
    Text("山不在高，有仙则名。水不在深，有龙则灵。斯是陋室，惟吾德馨。苔痕上阶绿，草色入帘青。谈笑有鸿儒，往来无白丁。可以调素琴，阅金经。无丝竹之乱耳，无案牍之劳形。南阳诸葛庐，西蜀子云亭。孔子云：何陋之有？")
        .frame(width: 100)
    Text("WWDC 2022")
        .frame(width: 100, height: 100, alignment: .center)
    Rectangle().fill(.blue.gradient).frame(width: 20, height: 50)
}
.border(.red)
```

![image-20220630113215811](https://cdn.fatbobman.com/image-20220630113215811.png)

```swift
ZStack {
    Text("Hello world")
        .frame(width: 100, height: 100, alignment: .topTrailing)
        .border(.red)
    Color.blue.opacity(0.2)
    Text("肘子的 Swift 记事本")
        .frame(width: 100, height: 100, alignment: .bottomLeading)
        .border(.red)
}
.frame(width: 130, height: 130)
.border(.red)
```

![image-20220629211312570](https://cdn.fatbobman.com/image-20220629211312570.png)

```swift
Grid {
    GridRow(alignment:.lastTextBaseline) {
        Text("Good")
        Text("Hello world")
            .frame(width: 50, height:50, alignment: .top)
            .border(.red)
        Text("Nice")
    }
    GridRow {
        Color.red.opacity(0.3)
        Color.green.opacity(0.2)
        Color.pink.opacity(0.2)
    }
    GridRow(alignment:.top) {
        Text("Start")
        Text("WWDC 2022")
            .frame(width: 70, height:50, alignment: .center)
            .border(.red)
        Rectangle()
            .fill(.blue.gradient)
    }
}
.frame(maxWidth: 300, maxHeight: 300)
.border(.red)
```

![image-20220630113419551](https://cdn.fatbobman.com/image-20220630113419551.png)

```swift
HStack {
    Text("First")
    VStack {
        Text("Hello world")
        Text("肘子的 Swift 记事本")
        Text("WWDC")
    }
    .border(.red)
    .padding()
    Text("Second")
    Rectangle().fill(.red.gradient)
        .frame(maxWidth: 10, maxHeight: 100)
}
.border(.green)
```

![image-20220630113655186](https://cdn.fatbobman.com/image-20220630113655186.png)

请暂停阅读下文，看看你是否可以从上面的代码中总结出 SwiftUI 对于布局容器（ 复合视图 ）的 firstTextBaseline 和 lastTextBaseline 的计算规律。

…

…

…

…

…

…

…

…

…

…

复合视图的 firstTextBaseline 和 lastTextBaseline 计算方法为：

* 对于 firstTextBaseline ，如果复合视图中（ 容器中 ）的子视图存在**显式值非 nil** 的 firstTextBaseline ，则返回显式值位置最高的 firstTextBaseline，否则返回默认值（ 通常为 bottom ）
* 对于 lastTextBaseline ，如果复合视图中（ 容器中 ）的子视图存在**显式值非 nil** 的 lastTextBaseline ，则返回显式值位置最低的 lastTextBaseline，否则返回默认值（ 通常为 bottom ）

这就是尽管开发者很少会在 alignmentGuide 中关心并使用对齐指南的显式值，但它在 SwiftUI 中仍十分重要的原因。

### 为符合 Layout 协议的自定义布局设置显式对齐指南

SwiftUI 4.0 新增的 Layout 协议，让开发者拥有了自定义布局容器的能力。通过使用 Layout 协议提供的 explicitAlignment 方法，我们可以验证上面有关布局容器（ 复合视图 ）的 firstTextBaseline 和 lastTextBaseline 的算法正确与否。

Layout 协议提供了两个不同参数类型的 explicitAlignment 方法，分别对应 VerticalAlignment 和 HorizontalAlignment 类型。explicitAlignment 让开发者可以站在布局的角度来设置对齐指南的显式值。explicitAlignment 的默认实现将为任何的布局指南的显式值返回 nil 。

下面的代码片段来自本文附带的源码 —— 用 Layout 协议仿制 ZStack 。我将通过在 explicitAlignment 方法中分别为 firstTextBaseline 和 lastTextBaseline 设置了显式对齐指南，以证实之前的猜想。

```swift
// SwiftUI 通过此方法来获取特定的对齐指南的显式值
func explicitAlignment(of guide: VerticalAlignment,  // 查询的对齐指南
                       in bounds: CGRect, // 自定义容器的 bounds ，该 bounds 的尺寸由 sizeThatFits 方法计算得出，与 placeSubviews 的 bounds 参数一致
                       proposal: ProposedViewSize,  // 父视图的建议尺寸
                       subviews: Subviews,  // 容器内的子视图代理
                       cache: inout CacheInfo // 缓存数据，本例中，我们在缓存数据中保存了每个子视图的 viewDimension、虚拟 bounds 能信息
                      ) -> CGFloat? {
    let offsetY = cache.cropBounds.minY * -1
    let infinity: CGFloat = .infinity

    // 检查子视图中是否有 显式 firstTextBaseline 不为 nil 的视图。如果有，则返回位置最高的 firstTextBaseline 值。 
    if guide == .firstTextBaseline,!cache.subviewInfo.isEmpty {
        let firstTextBaseline = cache.subviewInfo.reduce(infinity) { current, info in
            let baseline = info.viewDimension[explicit: .firstTextBaseline] ?? infinity
            // 将子视图的显式 firstTextBaseline 转换成 bounds 中的偏移值
            let transformBaseline = transformPoint(original: baseline + info.bounds.minY, offset: offsetY, targetBoundsMinX: 0)
            // 返回位置最高的值（ 值最小 ）
            return min(current, transformBaseline)
        }
        return firstTextBaseline != infinity ? firstTextBaseline : nil
    }

    if guide == .lastTextBaseline,!cache.subviewInfo.isEmpty {
        let lastTextBaseline = cache.subviewInfo.reduce(-infinity) { current, info in
            let baseline = info.viewDimension[explicit: .lastTextBaseline] ?? -infinity
            let transformBaseline = transformPoint(original: baseline + info.bounds.minY, offset: offsetY, targetBoundsMinX: 0)
            return max(current, transformBaseline)
        }
        return lastTextBaseline != -infinity ? lastTextBaseline : nil
    }

    return nil
}
```

> 由于视图使用 Layout 协议的 explicitAlignment 方法的默认实现效果与使用我们自定义的方法效果完全一致，因此可以证明我们之前的猜想是正确的。如果你只想让你的自定义布局容器呈现与 SwiftUI 预置容器一致的对齐指南效果，直接使用 Layout 协议的默认实现即可（ 无需实现 explicitAlignment 方法 ）。

即使布局容器通过 explicitAlignment 为对齐指南提供了显式值，开发者仍然可以通过 alignmentGuide 做进一步设置。

```responser
id:1
```

## 对哪些视图进行“对齐”

在上文中我们用了不小的篇幅介绍了对齐指南，本节中我们将探讨“对齐”的另一大关键点 —— 在不同的上下文中，哪些视图会使用对齐指南进行“对齐”。

### VStack、HStack、ZStack 等支持多视图的布局容器

你是否了解 SwiftUI 常用布局容器构造方法中的对齐参数的含义？它们又是如何实现的呢？

```swift
VStack(alignment:.trailing) { ... }
ZStack(alignment: .center) { ... }
HStack(alignment:.lastTextBaseline) { ... }
GridRow(alignment:.firstTextBaseline) { ... }
```

由于苹果对容器视图的 alignment 参数的描述并不很清晰，因而开发者很容易出现理解偏差。

> The guide for aligning the subviews in this stack. This guide has the same vertical screen coordinate for every child view —— Apple documentation for VStack's alignment

对于本段视图声明代码，你会选择下面哪种文字表述：

```swift
ZStack(alignment: .bottomLeading) {
    Rectangle()
        .fill(.orange.gradient)
        .frame(width: 100, height: 300)
    Rectangle()
        .fill(.cyan.gradient).opacity(0.7)
        .frame(width: 300, height: 100)
}
```

1. 在 ZStack 中按顺序重叠排列子视图（ Rectangle1 和 Rectangle2 ），并让每个子视图的 bottomLeading 与 ZStack 的 bottomLeading 对齐

2. 按顺序重叠排列 Rectangle1 和 Rectangle2，并让两者的 bottomLeading 对齐

![image-20220701132738722](https://cdn.fatbobman.com/image-20220701132738722.png)

如果你选择了 1 ，请问你该如何解释下面代码中的 alignmentGuide 无法影响子视图的对齐。

```swift
ZStack(alignment: .bottomLeading) {
    Rectangle()
        .fill(.orange.gradient)
        .frame(width: 100, height: 300)
    Rectangle()
        .fill(.cyan.gradient).opacity(0.7)
        .frame(width: 300, height: 100)
}
.alignmentGuide(.leading){
    $0[.leading] + 10
}
```

描述 1 在绝大多数的情况下（ 不设置对齐指南显式值 ）看起来都**像是**正确的，而且也很符合人的直觉，但从 SwiftUI 的角度来说，它将根据描述二来执行。因为在布局容器构造方法中设定的对齐指南只用于容器的子视图之间。

为了更好地理解之所以描述二才是正确的，我们需要对 SwiftUI 的布局原理以及 ZStack 的处理方式有所了解。

布局容器在布局时，容器会为每个子视图提供一个建议尺寸（ proposal size ），子视图将参考容器提供的建议尺寸返回自己的需求尺寸（ 子视图也可以完全无视容器的建议尺寸而提供任意的需求尺寸 ）。容器按照预设的行为（ 在指定轴向排列、点对齐、线对齐 、添加间隙等 ）在一个虚拟的画布中摆放所有的子视图。摆放结束后，容器将汇总摆放后的所有子视图的情况并向它的父视图（ 父容器 ）返回一个自身的需求尺寸。

因此，在布局容器对子视图进行对齐摆放过程中，布局容器的尺寸并没有确定下来，所以不会存在将子视图的对齐指南与容器的对齐指南进行“对齐”的可能。

通过创建符合 Layout 协议的布局容器可以清楚地展示上述的过程，下面的代码来自本文附带的演示代码 —— 一个 ZStack 的复制品 ：

```swift
// 容器的父视图（父容器）通过调用容器的 sizeThatFits 获取容器的建议尺寸，本方法通常会被多次调用，并提供不同的建议尺寸
func sizeThatFits(
    proposal: ProposedViewSize, // 容器的父视图（父容器）提供的建议尺寸
    subviews: Subviews, // 当前容器内的所有子视图的代理
    cache: inout CacheInfo // 缓存数据，本例中用于保存子视图的返回的需求尺寸，减少调用次数
) -> CGSize {
    cache = .init() // 清除缓存
    for subview in subviews {
        // 为子视图提供建议尺寸，获取子视图的需求尺寸 (ViewDimensions)
        let viewDimension = subview.dimensions(in: proposal)
        // 根据 MyZStack 的 alignment 的设置获取子视图 alignmentGuide 对应的点
        let alignmentGuide: CGPoint = .init(
            x: viewDimension[alignment.horizontal],
            y: viewDimension[alignment.vertical]
        )
        // 以子视图的 alignmentGuide 对应点为 (0,0) , 在虚拟的画布中，为子视图创建 Bounds
        let bounds: CGRect = .init(
            origin: .init(x: -alignmentGuide.x, y: -alignmentGuide.y),
            size: .init(width: viewDimension.width, height: viewDimension.height)
        )
        // 保存子视图在虚拟画布中的信息
        cache.subviewInfo.append(.init(viewDimension: viewDimension, bounds: bounds))
    }

    // 根据所有子视图在虚拟画布中的数据，生成 MyZStack 的 Bounds
    cache.cropBounds = cache.subviewInfo.map(\.bounds).cropBounds()
    // 返回当前容器的需求尺寸，当前容器的父视图将使用该尺寸在它的内部进行摆放
    return cache.cropBounds.size
}

// 容器的父视图（父容器）将在需要的时机调用本方法，为本容器的子视图设置渲染尺寸
func placeSubviews(
    in bounds: CGRect, // 根据当前容器在 sizeThatFits 提供的尺寸，在真实渲染处创建的 Bounds
    proposal: ProposedViewSize, // 容器的父视图（父容器）提供的建议尺寸
    subviews: Subviews, // 当前容器内的所有子视图的代理
    cache: inout CacheInfo // 缓存数据，本例中用于保存子视图的返回的需求尺寸，减少调用次数
) {
    // 虚拟画布左上角的偏移值 ( 到 0,0 )
    let offsetX = cache.cropBounds.minX * -1
    let offsetY = cache.cropBounds.minY * -1

    for index in subviews.indices {
        let info = cache.subviewInfo[index]
        // 将虚拟画布中的位置信息转换成渲染 bounds 的位置信息
        let x = transformPoint(original: info.bounds.minX, offset: offsetX, targetBoundsMinX: bounds.minX)
        let y = transformPoint(original: info.bounds.minY, offset: offsetY, targetBoundsMinX: bounds.minY)
        // 将转换后的位置信息设置到子视图上
        subviews[index].place(at: .init(x: x, y: y), anchor: .topLeading, proposal: proposal)
    }
}
```

VStack 和 HStack 相对于 ZStack 在布局时将更加复杂。由于需要考虑在特定维度上可动态调整尺寸的子视图，比如： Spacer 、Text 、frame(minWidth:maxWidth:minHeight:maxHeight) 等，VStack 和 HStack 会为子视图进行多次尺寸提案（ 包括理想尺寸、最小尺寸、最大尺寸、特定尺寸等 ），并结合子视图的布局优先级（ layoutPriority ）才能计算出子视图的需求尺寸，并最终确定自身的尺寸。

总之，为 VStack、HStack、ZStack 这类可包含多个子视图的官方布局容器设置 alignment 的含义就只有一种 —— 在特定维度上，将所有的子视图按照给定的对齐指南进行对齐摆放。

### overlay、background

在 SwiftUI 中，除了我们熟悉的 VStack、HStack、ZStack 、Grid 、List 外，很多 modifier 的功能也都是通过布局来实现的。例如 overlay、background、frame、padding 等等。

你可以将 overlay 和 background 视作一个特殊版本的 ZStack 。

```swift
// 主视图
Rectangle()
    .fill(.orange.gradient)
    .frame(width: 100, height: 100)
    // 附加视图
    .overlay(alignment:.topTrailing){
        Text("Hi")
    }
```

比如上面的代码，如果用布局的逻辑可以表示为（ 伪代码）：

```swift
_OverlayLayout {
    // 主视图
    Rectangle()
        .fill(.orange.gradient)
        .frame(width: 100, height: 100)
    
    // 附加视图
    Text("Hi")
        .layoutValue(key: Alignment.self, value: .topTrailing) // 一种子视图向最近容器传递信息的方式
}
```

与 ZStack 的不同在于，它只会包含两个子视图，且它的尺寸将仅由主视图来决定。主视图将和附加视图按照设定的对齐指南进行对齐。只要理解了这点，就会知道该如何调整主视图或辅助视图的对齐指南了，比如：

```swift
// 主视图
Rectangle()
    .fill(.orange.gradient)
    .frame(width: 100, height: 100)
    .alignmentGuide(.trailing, computeValue: {
        $0[.trailing] - 30
    })
    .alignmentGuide(.top, computeValue: {
        $0[.top] + 30
    })
    // 附加视图
    .overlay(alignment:.topTrailing){
        Text("Hi")
    }
```

![image-20220701143710982](https://cdn.fatbobman.com/image-20220701143710982.png)

### frame

frame 本质上就是 SwiftUI 中一个用于调节尺寸的布局容器，它会变换容器传递给子视图的建议尺寸，也可能会改变子视图返回给容器的需求尺寸。比如：

```swift
VStack {
    Text("Hello world")
       .frame(width: 10, height: 30, alignment: .top)
}
```

在上面的代码中，由于添加了 frame 修饰器，因此 FrameLayout（ 实现 frame 的后端布局容器 ）将无视 VStack 提供的建议尺寸，强行为 Text 提供 10 x 30 的建议尺寸，并且无视子视图 Text 的需求尺寸，为父视图（ VStack ）返回 10 x 30 的需求尺寸。虽然 FrameLayout 中只包含一个子视图，但在布局时它会让子视图与一个特定尺寸的虚拟视图进行对齐。或许将上面的 frame 代码转换成 background 的布局模式会更加方便理解：

```swift
_BackgroundLayout {
    Color.clear
        .frame(width: 10, height: 30)
    
    Text("Hello world")
        .layoutValue(key: Alignment.self, value: .top)
}
```

> 动态版本的 frame（ FlexFrameLayout ） 修饰器是一个学习、理解 SwiftUI 布局中尺寸协商机制的绝佳案例。有兴趣的朋友可以使用 Layout 协议对其进行仿制。

## 总结

虽然本文并没有提供具体的对齐使用技巧，但只要你理解并掌握了对齐的两大要点：以什么为对齐指南、对哪些视图进行“对齐”，那么相信一定会减少你在开发中遇到的对齐困扰，并可以通过对齐实现很多以前不容易完成的效果。

如果你想对 Layout 协议做更全面地了解，推荐你观看 Jane（ 美眉 up 主）制作的有关 SwiftUI Layout 协议的中文视频 —— [自订 Layout 排版教学](https://youtu.be/du_Bl7Br9DM) 。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
