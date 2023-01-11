---
date: 2022-11-01 08:12
description: Ask Apple 为开发者与苹果工程师创造了在 WWDC 之外进行直接交流的机会。本文对本次活动中与 SwiftUI 有关的一些问答进行了整理，并添加了一点个人见解。本文为下篇。
tags: SwiftUI,Ask Apple 2022
title: Ask Apple 2022 与 SwiftUI 有关的问答（下）
image: images/SwiftUI-of-Ask-Apple-2022-2.png
---
Ask Apple 为开发者与苹果工程师创造了在 WWDC 之外进行直接交流的机会。本文对本次活动中与 SwiftUI 有关的一些问答进行了整理，并添加了一点个人见解。本文为下篇。

## Q&A

### Form vs List

Q：这可能是一个非常愚蠢的问题，但我一直对 Form 和 List 感到困惑。它们之间有什么区别，什么时候应该使用 Form ，什么时候应该使用 List ？谢谢！

A：Form 是一种将许多相关控件组合在一起的方式。虽然 Form 和 List 在 iOS 上看起来差不多，但如果你看一下 macOS，就会发现它们之间的不少差异。与 macOS 上的 List 相比，许多控件在 Form 中的外观和行为都有所不同。与 Form 不同的是，List 内置了对编辑模式（ Edit Mode ）的支持。因此，如果你正在创建一个视图来显示可滚动的内容，并可能进行选择操作，那么在 iOS 和 macOS 上使用 List 将有最好的体验。如果你要渲染许多相关的控件，使用 Form 会在 iOS 和 macOS 上有最好的默认体验。

> 除了早期的 SwiftUI 版本，Form、List、LazyStack 以及 LazyGrid 之间在执行效率和子视图的生命周期方面的表现都相当接近。SwiftUI 4.0 的 Form 在 Ventura 上的表现与以往版本有很大的不同。形式上更接近 iOS 的状态，同时也对 mac 进行了更多的适配。

![image-20221031081829661](https://cdn.fatbobman.com/image-20221031081829661.png)

```responser
id:1
```

### 在辅助状态隐藏图像

Q：对于辅助功能，Image(decorative:) 和 .accessibilityHidden 之间是否有区别？

A：没有区别，使用这两种方法可以适当地隐藏图像，使其不被辅助技术所发现！

> accessibilityHidden 支持任意符合 View 协议的元素，同时可以动态调整它的隐藏状态。

### Table 中上下文菜单

Q：如果我在 TABLE 上添加了一个上下文菜单，我如何确定哪一行导致了菜单的显示（无需选择该行）？

A：在 TABLE 外使用 contextMenu(forSelectionType:) 。

> 在 [上篇第一个问题中](https://www.fatbobman.com/posts/SwiftUI-of-Ask-Apple-2022-1/#contextAction) 已经介绍了 `contextMenu(forSelectionType:)` 的使用方式。同经常使用的 `contextMenu` 不同，`contextMenu(forSelectionType:)` 是针对整个 List 或 Table 使用的（ 非单元格 ）。阅读 [用 Table 在 SwiftUI 下创建表格](https://www.fatbobman.com/posts/table_in_SwiftUI/) ，了解 Table 的具体用法。

### 视图的性能优化

Q：面对复杂的用户界面时，控制视图中的更新范围的最佳做法是什么（ 以避免不需要的转发以及重复计算 ）。在更复杂的 UI 中，由于视图的更新速度过快，性能（ 至少在 macOS 上 ）迅速下降。

A：有不同的策略。

* ObservableObject 是使视图或视图层次结构的失效（ 引发重新计算 ）的单元。你可以使用符合 ObservableObject 协议的不同对象来分割失效的范围
* 有时，不依赖 @Published 而获得一些手动控制并直接向 objectWillChange 发布变化是很有用的
* 添加一个中间视图，只提取你需要的属性，并依靠 SwiftUI 的 equality 检查来提前中止无效计算

> 苹果工程师给出的答案与 [避免 SwiftUI 视图的重复计算](https://www.fatbobman.com/posts/avoid_repeated_calculations_of_SwiftUI_views/) 一文中的很多建议都一致。视图的性能优化是一个系统工程，在对其运作机制、注入原理、更新时机等方面有了综合认识后，可以更好地做出有针对性的解决方案。

### 快速检索数组元素

Q：为什么没有简单的方法将 TABLE 选择的行映射到提供表内容的数组元素上？似乎唯一的方法是在数组中搜索匹配的 id 值，这对于大表来说似乎效率很低。

A：用数组索引来存储选择是很脆弱的：如果数组发生了突变，选择就会变得不同步。[Swift Collections](https://github.com/apple/swift-collections) 有一个 OrderedDictionary，可能会对你有所帮助。

> 这正是 [Swift Identified Collections](https://github.com/pointfreeco/swift-identified-collections) 项目存在的意义。Swift Identified Collections 是基于 OrderedDictionary 实现的一个拥有键属性的类数组。它的唯一要求是元素必须符合 Identifiable 协议。

```swift
struct Todo: Identifiable {
  var description = ""
  let id: UUID
  var isComplete = false
}

class TodosViewModel: ObservableObject {
  @Published var todos: IdentifiedArrayOf<Todo> = []
  ...
}

// 可以用类似字典的方式对元素进行操作，快速定位，同时在更新 IdentifiedArray 时，也不容易引发 ForEach 的异常
todos[id:id] = newTodo
```

### 自定义布局

Q：在实现自定义布局时，处理非常小或非常大的可用空间的边缘情况有多重要？

A：和很多事情一样，这个问题的答案是取决于你的使用情况（ 无论这个答案多么不令人满意：sweat_smile: ）。如果容器对 zero 和 infinite 的可用空间提出要求，需要用以确定最小和最大的尺寸，至少应该考虑这些情况。除此以外，当你试图实现一个可以在各种情况下使用通用的布局时，一定要考虑！但是，如果你只是自己使用它，并且条件可控，那么不处理这些情况也是合理的。

> 创建一个考虑到所有情况的通用布局（ 例如：VStack、HStack ）是一项相当艰巨的工作。开发者即使无法实现这样的布局容器，也应对各种尺寸需求的定义有清晰的理解。在 [SwiftUI 布局 —— 尺寸（ 上 ）](https://www.fatbobman.com/posts/layout-dimensions-1/) 一文中，对建议尺寸的几种模式都进行了介绍。

### 如何减少主线程的负担

Q：如何避免所有操作都被放置在主线上？任何标记 @Published 的变量都应该在主线上被修改，所以应该使用 @MainActor 。但任何触及该属性的代码都将被影响。是否有建议的标准模式或方法来改善这一点？

A：一般来说，你确实需要在主线程上与 UI 框架互动。在使用引用类型时，这一点尤其重要，因为你必须确保总是有对它进行序列化的读取。实际上，我们有一个非常棒的 WWDC [演讲](https://developer.apple.com/videos/play/wwdc2021/10019/)，详细介绍了并发性和 SwiftUI ，特别提到了有关使用 ObservableObject 的情况。一般来说，性能瓶颈不在写入 @Published 属性的周围。我建议的方法是在主线程之外做任何昂贵的或阻塞的工作，然后只在需要写入 ObservableObject 上的属性时再跳回主线程。

> @State 是线程安全的，@StateObject 会自动将 wrappedValue（ 符合 ObservableObject 协议的引用类型 ）标注为 @MainActor 。

### 自定义布局

Q：我经常想根据列表中最长或最短的文字来布置各种小组件。鉴于动态文本大小在应用程序运行时可能会发生变化，衡量给定字体的文本大小的最佳方法是什么？

A：你好！我们新的布局协议支持这个功能。任何自定义布局的完整实现都比我在这里的帖子中快速勾勒出来的要长，但总体思路是，你可以创建一个布局来查询其子级的理想大小并相应地对它们进行排序。然后，您可以使用垂直或水平堆栈布局来组合它，这样您就不需要自己完成所有的实现工作。

> Jane 的 [自动根据宽度排版](https://www.youtube.com/watch?v=du_Bl7Br9DM&t=107s) 视频与该问题十分契合。阅读 [The SwiftUI Layout Protocol ](https://swiftui-lab.com/layout-protocol-part-1/) 了解如何创建自定义布局。

### 创建从底部开始的滚动视图

Q：我如何实现一个在底部对齐的滚动视图，在 macOS 上会不会有糟糕的性能？我采用了常见的解决方案，即旋转滚动视图和里面的每个单元格，以获得预期的倒置列表，在 iOS 上，这很有效。但在 macOS 上，它使 CPU 使用率保持在 100%。

A：你最好的选择是使用 ScrollView 和 ScrollViewReader，并在 onAppear 或新内容进来时滚动到最底部的视图。我不建议尝试旋转滚动视图。

> [Swiftcord](https://github.com/SwiftcordApp/Swiftcord) 的代码展示了如何在 SwiftUI 下实现倒置列表。阅读 [优化在 SwiftUI List 中显示大数据集的响应效率](https://www.fatbobman.com/posts/optimize_the_response_efficiency_of_List/) 一文，了解苹果工程师推荐的方法。在两种方案中，如果在数据量很大的情况下，我更倾向于第一种方式，这样可以按需求读取数据。

### 定制 List

Q：是否有办法以完全可定制的方式使用 List ，这样我就可以实现删除缩进、分隔线，甚至更改整个列表的背景等操作？
目前，我总是去找 LazyVStack 来代替。

A：有多种修饰器可以实现这个功能：listRowSeparator, listRowInsets。不支持整个列表填充，请对此提出反馈。

> 在 SwiftUI 4 中，可以使用 `.scrollContentBackground(.hidden)` 隐藏列表的默认背景

### searchable

Q：是否有办法在`.searchable()` 修饰器中以编程方式设置搜索字段的焦点？

A：你可以使用 dismissSearch 环境属性以编程方式取消搜索字段。目前还没有 API 可以程序化地将焦点转至搜索字段。

### TextField 内容验证

Q：如何实现一个只接受数字的 SwiftUI TextField，小数是允许的。

A：向文本字段提供 FormatStyle 以实现自动将文本转换为各种数字。但是，此转换仅在文本字段完成编辑时才会发生，并且不会阻止输入非数字字符。目前 SwiftUI 没有 API 可以限制用户在字段中输入的字符。

> 很希望苹果能够继续扩展基于 FormatStyle 的解决方案，让其可以实时对输入内容进行校验。阅读 [SwiftUI TextField 进阶 —— 格式与校验](https://www.fatbobman.com/posts/textfield-1/) 一文了解其他的验证手段，以及如何通过 onChange 实现近乎实时地限制输入字符的方法。

### 将背景扩展到安全区域

Q：如果我有一个自定义的容器类型，可以接受一个顶部和底部的视图，是否有办法让 API 的调用者将所提供的视图的背景扩展到安全区域内，同时将内容（ 如文本或按钮 ）保留在安全区域内？

A：你可以尝试使用 safeAreaInset(edge: .top) { ... } 或 safeAreaInset(edge: .bottom) { ... } 修饰器来放置你的顶部和底部视图。然后让顶部/底部视图忽略安全区域。我不确定这是否能满足你的用例，但值得一试。

> 在 background 修饰器中，可以通过 ignoresSafeAreaEdges 参数设置是否忽略安全区域。这个技巧对于处于屏幕的顶部或底部的视图十分有用。详情请参阅 [推文](https://twitter.com/fatbobman/status/1564054945891921921?s=61&t=DOfEKfprtvzQFXuJJkmBXA) 。

### 动画转场

Q：为什么下面的代码没有显示动画转场。

```swift
struct ContentView: View {
    @State var isPresented = false
    var body: some View {
        VStack {
            Button("Toggle") {
                isPresented.toggle()
            }
            if isPresented {
                Text("Hello world!")
                    .transition(.move(edge: .top).animation(.default))
            }
        }
    }
}
```

A：尝试将动画修饰器移到 transition 参数之外。

```swift
struct ContentView: View {
    @State var isPresented = false
    var body: some View {
        VStack {
            Button("Toggle") {
                withAnimation {
                    isPresented.toggle()
                }
            }
            if isPresented {
                Text("Hello world!")
                    .transition(.move(edge: .top))
                    .animation(.default, value: isPresented)
            }
        }
    }
}
```

> 在上面苹果工程师给出的修改代码中。`.animation(.default, value: isPresented)` 是多余的。转场的动画事件是通过 withAnimation 来显式添加的。对于类似的情况，也可以不使用显式动画驱动（ 不使用 withAnimation ），只需将 `.animation(.default, value: isPresented)` 移动到 VStack 之外即可。阅读 [SwiftUI 的动画机制](https://www.fatbobman.com/posts/the_animation_mechanism_of_swiftUI/) 一文，了解更多有关动画的内容。

```responser
id:1
```

### 在 NavigationSplitView 的边栏中使用 LazyVStack

Q：iOS 16 的新 NavigationSplitView 当前只与主（ master ）列中的 List 一起工作。这意味着我们不能使用 LazyVStack，或任何其他将选择与详细视图绑定的自定义视图。有扩展这个功能的计划吗？

A：在 iOS 16.1 中，你可以在侧边栏里放一个。navigationDestination，这样侧边栏里的 NavigationLink 就会取代详细栏的根视图。

```swift
NavigationSplitView {
    LazyVStack {
        NavigationLink("link", value: 213)
    }
    .navigationDestination(for: Int.self) { i in
        Text("The value is \(value)")
    }
} detail: {
    Text("Click an item")
}
```

> 这是一个相当重要的改进！解决了之前的一大遗憾。如此一来，边栏视图的样式自由度获得了极大的提高。

### 软弃用

Q：最近，我注意到新的 @ViewBuilder 函数在以前的版本中是不可用的，弃用信息提示我使用新的方法取代老方法，这是 SwiftUI 的 API 设计缺陷还是我错过了什么？

```swift
 @available(iOS, introduced: 13.0, deprecated: 100000.0, message: "Use `overlay(alignment:content:)` instead.")
 @inlinable public func overlay<Overlay>(_ overlay: Overlay, alignment: Alignment = .center) -> some View 
```

 A：100000.0 的 deprecated 版本是 Swift 框架作者的一种沟通方式，即一个 API 不应该在新项目中使用，但在现有项目中继续使用也无妨。这种 “软弃用” 的 API 不会在代码自动补全中提供，而且通常处在文档中单独的一个部分。但编译器不会对现有的使用发出警告。因为这些使用并不有害，我们不希望开发者因为使用了新的编译器版本而处理一堆的警告。

### macOS API

Q：对于运行 Monterey 的 Mac，能否如何在 SwiftUI 中实现下面需求的建议：

1. 打开一个窗口
2. 在该窗口中初始化数据
3. 找到所有打开的窗口
4. 确定一个窗口是否打开
5. 从不在该窗口的视图中关闭一个窗口

A：我想说的是，如果可以，将 macOS Ventura 作为目标平台会对其中的一些操作更有帮助。特别是，我们在 WindowGroup 上添加了新的 OpenWindowAction 和新的初始化方法，这将同时满足 1 和 2 。如果您无法做到这一点，则可以使用 URL 和 handleExternalEvents 来模仿其中的一些行为，但它的局限性要大得多。关于其他点，目前没有合适的 API 。

### 连锁动画

Q：在 SwiftUI 中，如何实现连锁动画？例如，我想先给一个视图做动画，当动画完成后立即启动另一个动画。

A：不幸的是，目前不可能实现连锁动画。根据你的问题，你可以使用 animation.delay(...) 将动画的后半部分延迟到前半部分完成之后。如果你能将你的用例的细节反馈给我们，我们将非常感激。

> SwiftUI 当前缺乏动画完成后的回调机制。在动画不复杂的情况下，可以通过创建一个符合 Animatable 协议的 ViewModifier 来同步观察动画的进程。详情请参阅 [推文](https://twitter.com/fatbobman/status/1567310429600243712?s=61&t=M-TT_ssTFvXutwDlPdWjbg)、[代码](https://gist.github.com/fatbobman/205f221e078af96a3c11716c5d7cbcd3) 。

### Too complex to type check

Q：我在 iOS 14 SwiftUI 中遇到一个问题，我试图有条件地显示 3 个符合 Shape 协议的对象中的一个。其中 2 个是自定义形状（ 基本上是圆角矩形，只有两个角是圆的 ），其中一个是矩形。编译器抛出一个错误，说它花了太多时间来检查视图的类型。

A：是的，不幸的是，像这样的大型构造器表达式有时会让 Swift 编译器难以处理。遇到这种错误的解决办法是把表达式拆成更小的子表达式，特别是如果这些小的子表达式被赋予了明确的类型。

> 当视图的结构过于复杂时，除了难以阅读外，还会出现无法使用代码自动补全以及上文提到的无法编译（ too complex to type check ）的情况。将视图的功能分散到函数、更小的视图结构以及视图修饰器当中是很好的解决方法。

### Text 与 TextField 在编辑模式下的切换

Q：在 editMode 的文档中建议，在非编辑模式下，可以选择将 Text 视图换成 TextField 。然而，两个内容相同的视图之间的交换并不能使视图顺利地产生动画，因为两者的文本也被动画化了。我正在使用仅禁用 TextField 的替代方法，但有没有办法引导动画以使用文档中的方法？

A：解决办法：保留 TextField ，但当它不能被编辑时，有条件地设置 disabled(true)，当它可以编辑时使用 disabled(false) 。

> 设置正确的转场形式，可以避免非必要的闪烁或动画。

```swift
struct ContentView: View {
    var body: some View{
        VStack {
            EditButton()
            List{
                Cell()
            }
        }
    }
}

struct Cell:View {
    @State var text = "Hello"
    @Environment(\.editMode) var editMode
    var body: some View{
        ZStack {
            if editMode?.wrappedValue == .active {
                TextField("",text: $text).transition(.identity)
            } else {
                Text(text).transition(.identity)
            }
        }
    }
}
```

### 分离代码

Q：我注意到我的视图代码变大了，但原因并非来自实际的视图内容，而是由于 sheet、toolbar 等修饰器中的代码造成的。我当前设法在一个标注 @ToolbarContentBuilder 的函数中单独提取 toolbar 的内容，是否有好的方法来提取掉大量的 shee 和 alert 中的代码。

A：你可以通过创建自定义 ViewModifier 来封装其中的一些代码。另外，sheet 和 alert 的内容都采用了 ViewBuilders，所以你可以以类似于处理 toolbar 内容的方式将其提取到函数或计算属性中。

## Q&A （ 集锦 - 简体中文 ）

> 下文中的问题来自开发者与苹果工程师在【 集锦 - 简体中文 】频道进行的中文讨论（ 没有出现在英文 SwiftUI 频道中 ）。我直接对其进行了复制粘贴。

### 加载 Core Data 图片

Q：我的 CoreData 内使用 BinaryData with extern storage 存储图片。然后用 SwiftUI Image 来加载，data 还挺大的，当多个图同时加载，会卡顿和内存占用，请问这种情况下怎么改善

A：首先尽量保证采用异步加载的方式加载和创建图片，比如 SwiftUI 中的 AsyncImage 就可以从 URL 中异步加载图片，也可以根据需要实现自己的异步加载器完成异步加载。对于内存占用问题，首先尽量只在内存中保留需要显示的图片，对于预先加载的图片也适度，建议参看 WWDC18 的 [Image and Graphic Best Practices](https://developer.apple.com/wwdc18/219) , 有很多图片内存优化上的很好的建议。

> 异步 + 缩率图。对于可能造成卡顿的图片数据，放弃从托管对象的图片关系中直接获取的方式。在 Cell 视图中，通过创建 request 从私有上下文中提取数据并转换成图片。另外，可以考虑为原始图片创建缩略图，进一步提高显示的效率。

### TextField 中文输入的问题

Q：请问 SwiftUI 的 TextField 在中文输入时，会在字母选择阶段就直接上屏，造成输入内容错误的问题是已知问题吗？会在 16.1 RC 修复吗？

A：我们没能在 iOS 16.0.3 上重现你说的问题，你是否可以提供相关的代码段方便我们重现问题和调查？如果通过 Feedback Assistant 提交过此问题，请告诉我们 Feedback ID。

> 这是一个在多个版本中都出现过的奇怪问题。在 SwiftUI 早期版本中，当在 iOS 中使用系统中文输入法时，很容易触发这种情况。但后期逐步得到了修复。近期，在聊天室中我也看到了类似的讨论（ 我本人尚未在 iOS 16 上遇到 ）。贴一个临时的解决方案。

![image-20221023171100484](https://cdn.fatbobman.com/image-20221023171100484.png)

### 滚动速度

Q：有好的方式在 `List` 和 `ScrollView` 滑动时监听滑动的 velocity 值么？截止 SwiftUI 目前的版本，可以通过以下步骤获取到滑动的距离：

1. 自定义 struct, 让它实现 `PreferenceKey` 协议，其自定义结构体，是需要收集的 gemmetry data （视图坐标信息）
2. 调用 `transformAnchorPreference(key:_, value:_, transform:_)` or `preference(key:_,value:_)` 来在  SwiftUI 更新视图时收集坐标信息
3. 调用 `onPreferenceChange(:_,perform:_)` 来获取收集的坐标信息但是这样的实现方式，无法获取到 velocity

A：请问你需要这个速度值做什么用途？因为通常情况下并不需要这个值，如果是要检测滚动掉帧，可以在 Xcode Organizer 里查看，或者用 MetricKit 生成报告，开发环境也可以使用 Instruments 。所以更想知道你需要这个速度值有什么特定的用途。可以尝试在获取位置改变的同时记录时间变化来计算速度。不过如果是涉及到用户交互，建议衡量一下用户对速度的敏感程度和交互效果本身，是否可以用更便捷的方式实现。

> 在 SwiftUI 中，有一个从第一版开始就存在但尚未公开的纯 SwiftUI 实现的滚动容器 —— _ScrollView 。该滚动容器提供了不少标准 ScrollView 无法提供的 API 接口，例如对手势的加强控制、容器内视图的位移、反弹控制等。但这个滚动有两大问题，1、是一个未公开的半成品，有可能会被从 SwiftUI 框架中移除；2、不支持懒加载，即使和 Lazy 视图一起使用也会一次性加载全部的视图。更多内容可以查看一个对其进行二次包装的 [SolidScroll](https://github.com/edudnyk/SolidScroll) 库。

## 总结

我忽略掉了没有获得结论的问题。希望上述的整理能够对你有所帮助。

欢迎通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ) 或博客的留言板与我进行交流。

> 我正以聊天室、Twitter、博客留言等讨论为灵感，从中选取有代表性的问题和技巧制作成 Tips ，发布在 Twitter 上。每周也会对当周博客上的新文章以及在 Twitter 上发布的 Tips 进行汇总，并通过邮件列表的形式发送给订阅者。

**订阅下方的 [邮件列表](https://artisanal-knitter-2544.ck.page/d3591dd1e7)，可以及时获得每周的 Tips 汇总。**
