---
date: 2022-08-30 08:20
description: 将某个视图在父视图中居中显示是一个常见的需求，即使对于 SwiftUI 的初学者来说这也并非难事。在 SwiftUI 中，有很多手段可以达成此目的。本文将介绍其中的一些方法，并对每种方法背后的实现原理、适用场景以及注意事项做以说明。
tags: SwiftUI,小题大做
title: 在 SwiftUI 中实现视图居中的若干种方法
image: images/centeringInSwiftUI.png
---
将某个视图在父视图中居中显示是一个常见的需求，即使对于 SwiftUI 的初学者来说这也并非难事。在 SwiftUI 中，有很多手段可以达成此目的。本文将介绍其中的一些方法，并对每种方法背后的实现原理、适用场景以及注意事项做以说明。

## 需求

实现下图中展示的样式：在彩色矩形视图中居中显示单行 Text

![image-20220829142518962](https://cdn.fatbobman.com/image-20220829142518962.png)

```responser
id:1
```

## 填充物

### Spacer

最常见也是最容易想到的解决方案。

```swift
var hello: some View {
    Text("Hello world")
        .foregroundColor(.white)
        .font(.title)
        .lineLimit(1)
}

HStack {
    Spacer()
    hello
    Spacer()
}
.frame(width: 300, height: 60)
.background(.blue)
```

如果我告诉你上面的代码有两个隐患你相信吗？

* 文本内容超出了矩形的宽度

  Spacer 是有最小厚度设定的，默认的最小垫片厚度为 8px 。即使文本宽度超出了 HStack 给出的建议宽度，但 HStack 在布局时，仍会保留其最小厚度，导致下图上方的文本无法充分利用矩形视图的宽度。

  解决方法为：`Spacer(minLength: 0)`。

  当然，你也可以利用 Spacer 这个特性，控制 Text 在 HStack 中可使用的宽度。

![image-20220829152914736](https://cdn.fatbobman.com/image-20220829152914736.png)

* 将合成后的视图放置在某个可能会充满屏幕的视图的顶部或底部显示结果或者与你的预期不符

```swift
  VStack {
    // Hello world 视图 1
    HStack {
          Spacer(minLength: 0)
          hello
          Spacer(minLength: 0)
      }
      .frame(width: 300, height: 60)
      .background(.blue)
      
    HStack {
          Spacer(minLength: 0)
          hello
          Spacer(minLength: 0)
      }
      .frame(width: 300, height: 60) // 相同的尺寸
      .background(.red)
  
    Spacer() // 让 VStack 充满可用空间
}
```

  ![image-20220829154641251](https://cdn.fatbobman.com/image-20220829154641251.png)

  从 SwiftUI 3.0 开始，在使用 background 添加符合 ShapeStyle 协议的元素时，可以通过 ignoresSafeAreaEdges 参数设置是否忽略安全区域，默认值为 `.all` （ 忽略任何的安全区域 ）。因此，当我们将合成后的 hello world 视图放置在 VStack 顶部时（ 通过 Spacer ），矩形的 background 会连同顶部的安全区域一并渲染。

  解决的方法是：`.background(.blue, ignoresSafeAreaEdges: [])` ，排除掉不希望忽略的安全区域。

另外，在给定尺寸不明的情况下（ 未显式为矩形设置尺寸 ），上面的代码也需要进行一定的调整。例如，在 List Row 中显示 hello world 视图，希望矩形能够充满 Row ：

```swift
List {
    HStack {
        Spacer(minLength: 0)
        hello
        Spacer(minLength: 0)
    }
    .background(.blue)
    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0)) // 将 Row 的 Insets 设置为 0
    
}
.listStyle(.plain)
.environment(\.defaultMinListRowHeight, 80) // 设置 List 最小行高度

```

hello world 视图并不能充满 Row 提供的高度。这是由于 HStack 的高度是由容器子视图对齐排列后的高度决定的。Spacer 在 HStack 中只能进行横向填充，并不具备纵向的高度（ 高度为 0 ），因此 HStack 最终的需求高度与 Text 的高度一致。

![image-20220829155353877](https://cdn.fatbobman.com/image-20220829155353877.png)

解决的方法是：

```swift
HStack {
    Spacer(minLength: 0)
    hello
    Spacer(minLength: 0)
}
.frame(maxHeight: .infinity) // 用满建议高度
.background(.blue)
```

> 后文中为了简洁将省略掉针对给定尺寸不明情况的处理方式。统一使用固定尺寸（`.frame(width: 300, height: 60)`）。

### 其他填充物

那么，我们是否可以利用其它的视图实现与 Spacer 类似的填充效果呢？例如：

```swift
HStack {
    Color.clear
    hello
    Color.clear
}
.frame(width: 300, height: 60)
.background(Color.cyan)

```

很遗憾，使用上面的代码，Text 将只能使用 HStack 三分之一的宽度。

HStack、VStack 在进行布局时，会为每个子视图提供四种不同的建议模式（ 最小、最大、明确尺寸以及未指定 ），如果子视图在不同的模式下返回的需求尺寸是不一样的，则意味着该视图是可变尺寸视图。那么 HStack、VStack 会在明确了所有固定尺寸子视图的需求尺寸后，将所剩的可用尺寸（ HStack、VStack 的父视图给他们的建议尺寸 - 固定尺寸子视图的需求尺寸 ）平均分配（ 在优先级相同的情况下 ）给这些可变尺寸视图。

由于 Color、Text 都具备可变尺寸的特性，因此，它们三等分了 HStack。

![image-20220829160625981](https://cdn.fatbobman.com/image-20220829160625981.png)

但是我们可以通过调整视图优先级的方式，来保证 Text 能够获得最大的分量，例如：

```swift
HStack {
    Color.clear
        .layoutPriority(0)
    hello
        .layoutPriority(1)
    Color.clear
        .layoutPriority(0)
}
.frame(width: 300, height: 60)
.background(Color.cyan)

Text("Hello world,hello world,hello world") // hello 的宽度超出了矩形的宽度
```

![image-20220829161755393](https://cdn.fatbobman.com/image-20220829161755393.png)

至于上图中 Text 仍没有充分利用 HStack 全部宽度的原因，是因为没有为 HStack 设置明确的 spacing ，将其设置为 0 即可：`HStack(spacing:0)` 。

为布局容器设置明确的 spacing 是一个好习惯，在未明确指定时，HStack、VStack 在进行布局时可能会出现某些超出你预期的情况。下文中也会碰到此种情况。

> HStack、VStack 是不会给 Spacer 分配 spacing 的，毕竟 Spacer 本身就代表了空间占用。因此在第一个例子中，即使没有为 HStack 设置 spacing ，Text 仍然会使用全部的 HStack 宽度。

掌握了视图优先级的使用方式，我们还可以利用其他具备可变尺寸的特性的视图来充当填充物，例如：

* `Rectangle().opacity(0)`
* `Color.blue.opacity(0)`
* `ContainerRelativeShape().fill(.clear)`

在使用 SwiftUI 进行开发的过程中，Color、Rectangle 等经常被用来实现对容器的等分操作。另外，由于 Color、Rectangle 会在两个维度进行填充（ Spacer 会根据容器选择填充维度 ），因此，使用它们作为填充物时，将会自动使用全部的可用空间（ 包括高度 ），无需通过 `.frame(maxHeight: .infinity)` 应对给定尺寸不明的场景。

> 请阅读 [SwiftUI 專欄 #4 Color 不只是顏色](https://www.ethanhuang13.com/p/swiftui-4-not-just-color) ，掌握有关 Color 更多的内容

## 对齐指南

上节中，我们通过填充物让 Text 实现了左右居中。上下居中则是利用了 HStack 对齐指南的默认设定（ `.center` ）实现的。本节中，我们将完全通过对齐指南来实现居中操作。

### ZStack

```swift
ZStack { // 使用对齐指南的默认值，相当于 ZStack(alignment:.center)
    Color.green
    hello
}
.frame(width: 300, height: 60)
```

上述代码的布局逻辑是：

* ZStack 为 Color 和 Text 分别给出了 300 x 60 的建议尺寸
* Color 会将建议尺寸作为自己的需求尺寸（ 表现为充满 ZStack 空间 ）
* Text 最大可用宽度为 300
* Color 与 Text 将按照对齐指南 center 进行对齐（ 看起来就是 Text 显示在 Color 的中间 ）

如果将代码改写成下面的方式就会出现问题：

```swift
ZStack { // 在不明确设置 VStack spacing 的情况下，会出现 VStack spacing 不一致的情况
    Color.gray
        .frame(width: 300, height: 60)
    hello // 宽度没有约定，当文本较长时，会超过 Color 的宽度
}
```

上方代码的布局逻辑是：

* Color 的尺寸为 300 x 60 ( 不关心 ZStack 给出的建议尺寸 )
* ZStack 的尺寸为 Color 和 Text 两者的最大宽度 x 最大高度，该尺寸是一个可变尺寸（ 取决于 Text 文本的长度 ）
* 当 ZStack 给出的建议宽度大于 300 时，Text 的可利用宽度将超过 Color 的宽度

因此会出现两种可能的错误状态：

* 当文本较长时，Text 会超过 Color 的宽度
* 由于合成视图具备可变尺寸特性，VStack、HStack 在为其添加 spacing 时将可能出现与预期不符的状况 （ 下图中 spacing 的分配不均匀。显式设置可以解决该问题，请养成显式设置 spacing 的习惯 ）

```swift
VStack { // 没有设定 spacing ，显式设置可修复 spacing 不均匀的问题
    ZStack {
        Color.green
        hello
    }
    .frame(width: 300, height: 60)

    ZStack { // 在不明确设置 VStack spacing 的情况下，会出现 VStack spacing 不一致的情况
        Color.gray
            .frame(width: 300, height: 60)
        hello // 对于文字超过矩形宽度的情况不好处理
    }

    // Spacer 版本
    HStack {
        Spacer(minLength: 0)
        hello
            .sizeInfo()
        Spacer(minLength: 0)
            .sizeInfo()
    }
    .frame(width: 300, height: 60)
    .background(.blue, ignoresSafeAreaEdges: [])
}
```

![image-20220829175721185](https://cdn.fatbobman.com/image-20220829175721185.png)

> 在不给 VStack、HStack 的 spacing 设定明确值的情况下（ spacing = nil ），布局容器将尝试从每个子视图中获取子视图的预设 spacing 值，并将此值应用在与之临近的视图之间。由于不同种类的视图的默认 spacing 并不相同，因此就会出现貌似 spacing 分配不均匀的情况（ 事实上布局容器正确地执行了我们的要求 ）。如果想保证所有的视图之间都能保持一致的间隔，需要给布局容器设置明确的 spacing 值

```responser
id:1
```

### frame

```swift
hello
    .frame(width: 300, height: 60) // 使用了默认的 center 的对齐指南，相当于 .frame(width: 300, height: 60,alignment: .center)
    .background(.pink)
```

布局逻辑：

* 使用 FrameLayout 布局容器对 Text 进行布局
* FrameLayout 给 Text 的建议尺寸为 300 x 60
* Text 与占位视图（ 空白视图的尺寸为 300 x 600 ）按对齐指南 center 进行对齐

这是我个人最喜欢使用的居中手段，应对给定尺寸不明的情况也十分方便：

```swift
hello
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.pink)
```

> 想了解 frame 的实现原理请阅读 [SwiftUI 布局 —— 尺寸（ 下 ）](https://www.fatbobman.com/posts/layout-dimensions-2/) 一文

### overlay

```swift
Rectangle() // 直接使用 Color.orange 也可以
    .fill(Color.orange)
    .frame(width: 300, height: 60)
    .overlay(hello) // 相当于 .overlay(hello,alignment: .center)
```

布局逻辑：

* Rectangle 将获得 300 x 60 建议尺寸（ Rectangle 将使用全部的尺寸 ）
* 使用 OverlayLayout 布局容器对 Rectangle 及 Text 进行布局，建议尺寸采用主视图的需求尺寸（ Rectangle 的需求尺寸 ）
* Text 与 Rectangle 按照对齐指南 center 进行对齐

那么是否可以用 background 实现类似的样式呢？例如：

```swift
hello
    .background(
        Color.cyan.frame(width: 300,height: 60)
    )
    .border(.red) // 显示边框以查看合成视图的布局尺寸
```

![image-20220829182808201](https://cdn.fatbobman.com/image-20220829182808201.png)

很遗憾，你将获得与上文中 ZStack 错误用法类似的结果。文字可能会超长，视图无法获得 spacing （ 即使进行了显式设置 ）。

> 请阅读 [SwiftUI 布局 —— 对齐](https://www.fatbobman.com/posts/layout-alignment/) ，了解更多有关 ZStack、overlay、background 的对齐机制

## Geometry

虽然有些大材小用，但当我们需要获取更多有关视图的信息时，GeometryReader 是一个相当不错的选择：

```swift
GeometryReader { proxy in
    hello
        .position(.init(x: proxy.size.width / 2, y: proxy.size.height / 2))
        .background(Color.brown)
}
.frame(width: 300, height: 60)
```

布局逻辑：

* GeometryReader 将获得 300 x 60 的建议尺寸
* 由于 GeometryReader 拥有与 Color、Rectangle 类似的特征，会将给定的建议尺寸作为需求尺寸（ 表现为占用全部可用空间 ）
* GeometryReader 给 Text 提供 300 x 60 的建议尺寸
* GeometryReader 中的视图，默认基于 topLeading 对齐（ 类似 `overlay(alignment:.topLeading)` 的效果 ）
* 使用 postion 将 Text 的中心点与给定的位置进行对齐（ postion 是一个通过 CGPoint 来对齐中心点的视图修饰器 ）

当然，你也可以获取 Text 的 Geometry 信息，通过 offset 或 padding 的方式实现居中。不过除非矩形的尺寸明确，否则里外都需要使用 GeometryReader ，实现将过于烦琐。

## 总结

本文选取了一些有代表性的解决方法，随着 SwiftUI 功能的不断增强，会有越来越多的手段可供使用。万变不离其宗，掌握了 SwiftUI 的布局原理，无论需求如何变化都可轻松应对。

我为本文这种通过多种方法来解决一个问题的方式添加了【小题大做】标签，目前使用该便签的文章还有：[在 Core Data 中查询和使用 count 的若干方法](https://www.fatbobman.com/posts/countInCoreData/)、[在 SwiftUI 视图中打开 URL 的若干方法](https://www.fatbobman.com/posts/open_url_in_swiftUI/) 。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。

> 我正以聊天室、Twitter、博客留言等讨论为灵感，从中选取有代表性的问题和技巧制作成 Tips ，发布在 Twitter 上。每周也会对当周博客上的新文章以及在 Twitter 上发布的 Tips 进行汇总，并通过邮件列表的形式发送给订阅者。

**订阅下方的 [邮件列表](https://artisanal-knitter-2544.ck.page/d3591dd1e7)，可以及时获得每周的 Tips 汇总。**
