---
date: 2022-08-16 08:12
description: SwiftUI 提供了强大的布局能力，不过这些布局操作都是在视图之间进行的。当我们想在 Text 中进行图文混排时，需要采用与视图布局不同的思路与操作方式。本文将首先介绍一些与 Text 有关的知识，并通过一个实际案例，为大家梳理出在 SwiftUI 中用 Text 实现图文混排的思路。
tags: SwiftUI
title: 在 SwiftUI 中用 Text 实现图文混排
image: images/mixing_text_and_graphics_with_Text_in_SwiftUI.png
---
SwiftUI 提供了强大的布局能力，不过这些布局操作都是在视图之间进行的。当我们想在 Text 中进行图文混排时，需要采用与视图布局不同的思路与操作方式。本文将首先介绍一些与 Text 有关的知识，并通过一个实际案例，为大家梳理出在 SwiftUI 中用 Text 实现图文混排的思路。

## 一个和一组

在 SwiftUI 中，Text 是使用频率最高的几个组件之一，几乎所有的文字显示操作均由其完成。随着 SwiftUI 版本的不断提升，Text 的功能也得到持续地增强。除了基本的文本内容外，还提供了对 AttributedString、Image（ 有限度 ）、Fomatter 等类型的支持。

如果 Text 视图无法在给定的建议宽度内显示全部的内容，在建议高度允许的情况下（ 没有限制高度或显示行数 ），Text  会对内容进行换行处理，通过多行显示的方式保证内容的完整性。上述特性有一个基本要求 —— 换行操作是在单一 Text 视图中进行的。在下面的代码中，尽管我们通过布局容器视图将 Text 横向排列到一起，但 SwiftUI 仍会将它们视作多个 Text 视图（ 一组 ），对每个 Text 分别进行换行操作：

```swift
struct TempView:View{
    let str = "道可道，非常道；名可名，非常名。"
    var body: some View{
        HStack{
            Text(str)
        }
        .padding()
    }
}
```

![image-20220814083426515](https://cdn.fatbobman.com/image-20220814083426515.png)

```responser
id:1
```

SwiftUI 提供了两种方式用以将多个 Text 转换成一个 Text：

* 通过 LocalizedStringKey 插值的方式

```swift
HStack{
    let a = Text(str)
    let b = Text(str)
    let c = Text(str)
    Text("\(a) \(b) \(c)") 
}
```

![image-20220814084617352](https://cdn.fatbobman.com/image-20220814084617352.png)

我们不仅可以通过插值的方式添加 Text ，还可以添加 Image、Date 等众多类型。王巍在 [SwiftUI 中的 Text 插值和本地化](https://onevcat.com/2021/03/swiftui-text-1/) 一文中对此做了详尽的介绍。

> 请注意：从第二个 Text 插值元素开始，必须在插值符号 `\(` 前添加一个空格，否则会出现显示异常（ 这是一个持续了多个版本的 Bug ）。尝试将上面的代码 `Text("\(a) \(b) \(c)")` 改成 `Text("\(a)\(b)\(c)")` 即可复现该错误。

* 使用加法运算符

```swift
HStack{
    let a = Text(str)
    let b = Text(str)
    let c = Text(str)
    a + b + c
}
```

加法运算仅可以在 Text 类型之间进行。这意味着，当我们对部分 Text 进行配置时，只能使用不改变 Text 类型的修饰器（ 该原则同样适用于通过插值方式进行的合并 ），例如：

```swift
HStack{
    let a = Text(str)
        .foregroundColor(.red) // Text 专用版本，不改变 Text 类型
        .underline() // 不改变 Text 类型
//      .background(Color.yellow) // background 是针对 View 协议的修饰器，会改变 Text 的类型，无法使用
    let b = Text(str)
        .foregroundColor(.blue)
        .font(.title)
    let c = Text(str)
        .foregroundColor(.green)
        .bold()
    a + b + c
}
```

![image-20220814090556878](https://cdn.fatbobman.com/image-20220814090556878-0439158.png)

如果你经常有组成复杂文本的需求，可以创建一个结果构造器来简化该过程：

```swift
@resultBuilder
enum TextBuilder {
    static func buildBlock(_ components: Text...) -> Text {
        components.reduce(Text(""),+)
    }
}
```

使用该构造器，我们可以更加清晰、快捷地合成复杂文本：

```swift
@TextBuilder
func textBuilder() -> Text {
    Text(str)
        .foregroundColor(.red)
        .underline()
    Text(str)
        .foregroundColor(.blue)
        .font(.title)
    Text(str)
        .foregroundColor(.green)
        .bold()
}
```

> 可以阅读 [掌握 Result builders](https://www.fatbobman.com/posts/viewBuilder1/) 一文，了解更多有关结构构造器方面的内容

## 在 Text 中使用 SF Symbols

[SF Symbols](https://developer.apple.com/sf-symbols/) 是苹果为开发者带来的一份厚礼，让开发者可以在苹果生态中近乎免费地使用由专业设计师创建的海量图标。截至 2022 年，SF Symbols 已经拥有了超过 4000 个符号，每个符号均拥有九种重量和三种比例，并可自动与文本标签对齐。

在 SwiftUI 中，我们需要通过 Image 来显示 SF Symbols，并可使用一些修饰器来对其进行设置：

```swift
Image(systemName: "ladybug")
    .symbolRenderingMode(.multicolor) // 指定渲染模式，Image 专用修饰器 ，Image 类型不发生改变
    .symbolVariant(.fill) // 设置变体 ，该修饰器适用于 View 协议，Image 类型发生了改变
    .font(.largeTitle) // 适用于 View 的修饰器，非 Text 专用版本
```

![image-20220814103141010](https://cdn.fatbobman.com/image-20220814103141010.png)

SF Symbols 提供了与苹果平台的系统字体 San Francisco 无缝集成的能力，Text 会在排版过程中将其视为普通文本而统一处理。上文中介绍的两种方法均适用于将 SF Symbols 添加到 Text 中：

```swift
let bug = Image(systemName: "ladybug.fill") // 由于 symbolVariant 会改变 Image 的类型，因此我们采用直接在名称中添加变体的方式来保持类型的稳定
    .symbolRenderingMode(.multicolor) // 指定渲染模式，Image 专用修饰器 ，Image 类型不发生改变
let bugText = Text(bug)
    .font(.largeTitle) // Text 专用版本，Text 类型不发生变化

// 通过插值的方式
Text("Hello \(bug)") // 在插值中使用 Image 类型，由于 font 会改变 Image 的类型，因此无法单独修改 bug 的大小

Text("Hello \(bugText)") // 在插值中使用 Text，font（ Text 专用修饰器 ）不会改变 Text 类型，因此可以单独调整 bug 的大小

// 使用加法运算符
Text("Hello ") + bugText 
```

![image-20220814104652581](https://cdn.fatbobman.com/image-20220814104652581.png)

可以说，在 Text 中，可以直接使用 Image 类型这个功能主要就是为 SF Symbols 而提供的。在可能的情况下，通过 Text + SF Symbols 的组合来实现图文混排是最佳的解决方案。

```swift
struct SymbolInTextView: View {
    @State private var value: Double = 0
    private let message = Image(systemName: "message.badge.filled.fill") // 􁋭
        .renderingMode(.original)
    private let wifi = Image(systemName: "wifi") // 􀙇
    private var animatableWifi: Image {
        Image(systemName: "wifi", variableValue: value)
    }

    var body: some View {
        VStack(spacing:50) {
            VStack {
                Text(message).font(.title) + Text("文字与 SF Symbols 混排。\(wifi) Text 会将插值图片视作文字的一部分。") + Text(animatableWifi).foregroundColor(.blue)
            }
        }
        .task(changeVariableValue)
        .frame(width:300)
    }

    @Sendable
    func changeVariableValue() async {
        while !Task.isCancelled {
            if value >= 1 { value = 0 }
            try? await Task.sleep(nanoseconds: 1000000000)
            value += 0.25
        }
    }
}
```

![sfsymbols_In_Text_2022-08-14_10.53.10.2022-08-14 10_53_54](https://cdn.fatbobman.com/sfsymbols_In_Text_2022-08-14_10.53.10.2022-08-14%2010_53_54.gif)

尽管我们可以使用 SF Symbols 应用程序来修改或创建自定义符号，但由于受颜色、比例等方面的限制，在相当多的场合中， SF Symbols 仍无法满足需求。此时，我们需要使用真正的 Image 来进行图文混排工作。

```swift
VStack {
    let logo = Image("logo")  // logo 是一个 80 x 28 尺寸的图片，默认情况下，title 的高度为 28

    Text("欢迎访问 \(logo) ！")
        .font(.title)

    Text("欢迎访问 \(logo) ！")
        .font(.body)
}
```

![image-20220814155725538](https://cdn.fatbobman.com/image-20220814155725538.png)

当在 Text 中使用真正的 Image （ 非 SF Symbols ）时，Text 只能以图片的原始尺寸进行渲染（ SVG、PDF 以标注尺寸为准 ），**图片的尺寸并不会随字体尺寸大小的变化而变化**。

另一方面，由于 Image（ 非 SF Symbols ）的 textBaseline 在默认情况下是与其 bottom 一致的，这导致在与 Text 中其他的文字进行混排时，图片与文字会由于基准线的不同而发生上下错位的情况。我们可以通过使用 Text 专属版本的 baselineOffset 修饰器对其进行调整。

```swift
let logo = Text(Image("logo")).baselineOffset(-3) // Text 版本的修饰器，不会改变 Text 类型，使用 alignmentGuide 进行修改会更改类型

Text("欢迎访问 \(logo) ！")
    .font(.title)
```

![image-20220814160547051](https://cdn.fatbobman.com/image-20220814160547051.png)

> 有关 baseline 对齐线方面的内容，请阅读 [SwiftUI 布局 —— 对齐](https://www.fatbobman.com/posts/layout-alignment/) 一文

再次强调，我们只能使用不会改变 Text 或 Image 类型的修饰器。例如 frame、scaleEffect、scaleToFit、alignmentGuide 之类会改变类型状态的修饰器将导致无法进行 Text 插值以及加法运算操作！

如此一来，**为了能让视图与文字完美地进行匹配，我们需要为不同尺寸的文字准备不同尺寸的视图**。

## 动态类型（ 自动缩放字体 ）

苹果一直很努力地改善其生态的用户体验，考虑到用户与显示器的距离、视力、运动与否，以及环境照明条件等因素，苹果为用户提供了动态类型功能来提高内容的可读性。

动态类型（ Dynamic Type ）功能允许使用者在设备端设置屏幕上显示的文本内容的大小。它可以帮助那些需要较大文本以提高可读性的用户，还能满足那些可以阅读较小文字的人，让更多信息出现在屏幕上。支持动态类型的应用程序也会为使用者提供一个更一致的阅读体验。

用户可以在控制中心或通过【设置】—【辅助功能】—【显示与文字大小】—【更大字体】来更改单个或全部应用程序的文字显示大小。

![DynamicType](https://cdn.fatbobman.com/DynamicType.png)

从 Xcode 14 开始，开发者可以在预览中快速检查视图在不同动态类型下的表现。

```swift
Text("欢迎访问 \(logo) ！")
    .font(.title)  // title 在不同动态模式下，显示的尺寸不同。
```

![image-20220814173320321](https://cdn.fatbobman.com/image-20220814173320321-0469602.png)

在 SwiftUI 中，除非进行了特别的设置，否则所有字体的尺寸都会跟随动态类型的变化而变化。从上图中可以看出，**动态类型仅对文本有效，Text 中的图片尺寸并不会发生改变**。

在使用 Text 实现图文混排时，如果图片不能伴随文本的尺寸变化而变化，就会出现上图中的结果。因此，我们必须通过某种手段让图片的尺寸也能自动适应动态类型的改变。

使用 SwiftUI 提供的 @ScaledMetric 属性包装器，可以创建能够跟随动态类型自动缩放的数值。relativeTo 参数可以让数值与特定的文本风格的尺寸变化曲线相关联。

```swift
@ScaledMetric(relativeTo: .body) var imageSize = 17 
```

> 不同的文本风格（ Text Style ）用以响应动态类型变化的尺寸数值曲线并不相同，详情请阅读苹果的 [设计文档](https://developer.apple.com/design/human-interface-guidelines/foundations/typography/#specifications)

```swift
struct TempView: View {
    @ScaledMetric(relativeTo:.body) var height = 17 // body 的默认高度
    var body: some View {
        VStack {
            Image("logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height:height)

            Text("欢迎访问！")
                .font(.body)
        }
        .padding()
    }
}
```

上面的代码，通过 ScaledMetric 将图片的高度与 .body 文本风格的尺寸进行了关联，当动态类型发生改变时，图片的尺寸也会随之做出调整。

![image-20220814181138809](https://cdn.fatbobman.com/image-20220814181138809.png)

遗憾的是，由于 frame 会更改 Image 的类型，因此我们无法将通过 frame 动态更改尺寸后的图片嵌入到 Text 中，以实现可动态调整尺寸的图文混排。

使用 `.dynamicTypeSize(DynamicTypeSize.xSmall...DynamicTypeSize.xxxLarge)` 可以让视图只在指定的动态类型范围内发生变化。

使用 `.font(custom(_ name: String, size: CGFloat))` 设置的自定义尺寸的字体也会在动态类型变化时自动调整尺寸。

使用 `.font(custom(_ name: String, size: CGFloat, relativeTo textStyle: Font.TextStyle))` 可以让自定义尺寸的字体与某个预设文本风格的动态类型尺寸变化曲线相关联。

使用`.font(custom(_ name: String, fixedSize: CGFloat))` 将让自定义尺寸字体忽略动态类型的变化，尺寸始终不发生改变。

## 一个有关图文混排的问题

前几天在 [聊天室](https://discord.gg/ApqXmy5pQJ) 中，一个朋友询问 SwiftUI 是否能实现下图中 tag（ 超市标签 ）+ 商品介绍的版式效果。我直接回复没有问题，但直到考虑具体实现时才发现，情况没有那么简单。

![image-20220815082801108](https://cdn.fatbobman.com/image-20220815082801108.png)

* 标签采用了圆角背景，意味着基于 [AttributedString](https://www.fatbobman.com/posts/attributedString/) 的解决方案被排除
* 标签特定的尺寸与内容，意味着基于自定义 SF Symbols 的解决方案被排除
* 通过在 Text 中添加 Image 进行图文混排，需要考虑如何处理动态类型变化的问题（ 不可能预生成如此多尺寸的图片 ）
* 是否可以不通过预制标签图片的方式（ 用动态视图 ）来解决当前问题

下文中，我将提供三种解决思路和对应代码，利用不同的方式来实现当前的需求。

> 限于篇幅，下文中将不会对范例代码做详尽的讲解，建议你结合本文附带的 [范例代码](https://github.com/fatbobman/BlogCodes/tree/main/InlineImageWithText) 一并阅读接下来的内容。从 Xcode 运行范例代码，动态创建的图片可能并不会立即显示出来（ 这是 Xcode 的问题 ）。直接从模拟器或实机上再次运行将不会出现上述延迟现象。

```responser
id:1
```

## 方案一：在 Text 中直接使用图片

### 方案一的解决思路

既然为不同的动态类型提供不同尺寸的图片可以满足 Text 图文混排的需求，那么方案一就以此为基础，根据动态类型的变化自动对给定的预制图片进行等比例缩放即可。

* 从应用程序或网络上获取标签图片
* 当动态类型变化时，将图片缩放至与关联的文本风格尺寸一致

```swift
VStack(alignment: .leading, spacing: 50) {
            TitleWithImage(title: "佳农 马来西亚冷冻 猫山王浏览果肉 D197", fontStyle: .body, tagName: "JD_Tag")

            TitleWithImage(title: "佳农 马来西亚冷冻 猫山王浏览果肉 D197", fontStyle: .body, tagName: "JD_Tag")
                .environment(\.sizeCategory, .extraExtraExtraLarge)
        }
```

![image-20220815112324138](https://cdn.fatbobman.com/image-20220815112324138.png)

### 方案一的注意事项

* 为了保证图片缩放后的质量，范例中采用了 SVG 格式
* 鉴于 SwiftUI 提供的图片缩放 modifier 均会改变类型，缩放操作将使用 UIGraphicsImageRenderer 针对 UIImage 进行

```swift
extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
```

* 由于使用了 `UIFont.preferredFont` 获取 Text Style 的尺寸，因此 Text Style 参数采用了 UIFont.TextStyle 类型。
* 让 Image 的初始高度与给定的 Text Style 一致，并通过使用 @ScaledMetric 让两者的尺寸变化保持同步

```swift
let uiFont = UIFont.preferredFont(forTextStyle: fontStyle)
pointSize = uiFont.pointSize
textStyle = Font.TextStyle.convert(from: fontStyle)
_fontSize = ScaledMetric(wrappedValue: pointSize, relativeTo: textStyle)
```

* 使用 `.font(.custom("", size: pointSize, relativeTo: textStyle))` 设置字体尺寸，并与给定的 Text Style 进行关联
* 正确使用 task 修饰器，以确保尺寸缩放操作在后台线程进行，减少对主线程的影响

```swift
@Sendable
func resizeImage() async {
    if var image = UIImage(named: tagName) {
        let aspectRatio = image.size.width / image.size.height
        let newSize = CGSize(width: aspectRatio * fontSize, height: fontSize)
        image = image.resized(to: newSize)
        tagImage = Image(uiImage: image)
    }
}

.task(id: fontSize, resizeImage)
```

* 通过 baselineOffset 修改图片的文本基线。偏移值应该根据不同的动态类型进行微调（ 本人偷懒，范例代码中使用了固定值 ）

### 方案一的优缺点

* 方案简单，实现容易

* 由于图片需要预制，因此不适合标签种类多，且经常变动的场景
* 在无法使用矢量图片的情况下，为了保证缩放后的效果，需要提供分辨率较高的原始图片，这样会造成更多的系统负担

## 方案二：在 Text 上使用覆盖视图

### 方案二的解决思路

* 不使用预制图片，通过 SwiftUI 视图创建标签
* 根据标签视图的尺寸创建空白占位图片
* 在 Text 中添加占位图片，进行混排
* 使用 overlay 将标签视图定位在 leadingTop 位置，覆盖于占位图片上

```swift
TitleWithOverlay(title: "佳农 马来西亚冷冻 猫山王浏览果肉 D197", tag: "京东超市", fontStyle: .body)

TitleWithOverlay(title: "佳农 马来西亚冷冻 猫山王浏览果肉 D197", tag: "京东超市", fontStyle: .body)
    .environment(\.sizeCategory, .extraExtraExtraLarge)
```

![image-20220815134505932](https://cdn.fatbobman.com/image-20220815134505932.png)

### 方案二的注意事项

* 使用 `fixedSize` 禁止标签视图自行响应动态类型。标签视图 TagView 中的文字尺寸完全由 TitleWithOverlay 控制

```swift
Text(tag)
    .font(.custom("", fixedSize: fontSize))
```

* 使用 `alignmentGuide` 微调标签视图的位置，使其与 Text 的文字对齐。与方案一类似，offset、padding、fontSize 等最好根据动态类型进行微调（ 作者偷懒，没有微调。不过最终效果还可以接受 ）

```swift
TagView(tag: tag, textStyle: textStyle, fontSize: fontSize - 6, horizontalPadding: 5.5, verticalPadding: 2)
    .alignmentGuide(.top, computeValue: { $0[.top] - fontSize / 18 })
```

* 当 fontSize （ 动态类型下当前的文本尺寸 ）发生变化时，更新标签视图尺寸

```swift
Color.clear
    .task(id:fontSize) { // 使用 task(id:)
        tagSize = proxy.size
    }
```

* 当标签视图尺寸 tagSize 发生变化时，重新创建占位图片

```swift
.task(id: tagSize, createPlaceHolder)
```

* 正确使用 task 修饰器，以确保创建占位图片的操作在后台线程进行，减少对主线程的影响

```swift
extension UIImage {
    @Sendable
    static func solidImageGenerator(_ color: UIColor, size: CGSize) async -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        let image = UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
            color.setFill()
            rendererContext.fill(CGRect(origin: .zero, size: size))
        }
        return image
    }
}

@Sendable
func createPlaceHolder() async {
    let size = CGSize(width: tagSize.width, height: 1) // 仅需横向占位，高度够用就行
    let uiImage = await UIImage.solidImageGenerator(.clear, size: size)
    let image = Image(uiImage: uiImage)
    placeHolder = Text(image)
}
```

### 方案二的优缺点

* 无须预制图片
* 标签的内容、复杂度等不再受限
* 仅适用于当前的特殊案例（ 标签在左上角 ），一旦改变标签的位置，此方案将不再有效（ 其他位置很难在 overlay 中对齐 ）

## 方案三：将视图转换成图片，插入 Text 中

### 方案三的解决思路

* 与方案二一样，不使用预制图片，使用 SwiftUI 视图创建标签
* 将标签视图转换成图片添加到 Text 中进行混排

```swift
TitleWithDynamicImage(title: "佳农 马来西亚冷冻 猫山王浏览果肉 D197", tag: "京东超市", fontStyle: .body)

TitleWithDynamicImage(title: "佳农 马来西亚冷冻 猫山王浏览果肉 D197", tag: "京东超市", fontStyle: .body)
    .environment(\.sizeCategory, .extraExtraExtraLarge)
```

![image-20220815141821917](https://cdn.fatbobman.com/image-20220815141821917.png)

### 方案三的注意事项

* 确保在后台进程中进行视图转换成图片的操作

```swift
@Sendable
func createImage() async {
    let tagView = TagView(tag: tag, textStyle: textStyle, fontSize: fontSize - 6, horizontalPadding: 5.5, verticalPadding: 2)
    tagView.generateSnapshot(snapshot: $tagImage)
}
```

* 转换图片的过程中需设置正确的 scale 值，以保证图片的品质

```swift
func generateSnapshot(snapshot: Binding<Image>) {
    Task {
        let renderer = await ImageRenderer(content: self)
        await MainActor.run {
            renderer.scale = UIScreen.main.scale // 设置正确的 scale 值
        }
        if let image = await renderer.uiImage {
            snapshot.wrappedValue = Image(uiImage: image)
        }
    }
}
```

### 方案三的优缺点

* 无须预制图片
* 标签的内容、复杂度等不再受限
* 无须限制标签的位置，可以将其放置在 Text 中的任意位置
* 由于范例代码中采用了 SwiftUI 4 提供的 ImageRenderer 完成视图至图片的转换，因此仅支持 iOS 16+

> 在低版本的 SwiftUI 中，可以通过用 UIHostingController 包裹视图的方式，在 UIKit 下完成图片的转换操作。但由于 UIHostingController 仅能运行于主线程，因此这种转换操作对主线程的影响较大，请自行取舍

## 总结

在读完本文后，或许你的第一感受是 SwiftUI 好笨呀，竟然需要如此多的操作才能完成这种简单的需求。但能用现有的方法来解决这类实际问题，何尝又不是一种挑战和乐趣？至少对我如此。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
