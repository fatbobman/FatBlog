---
date: 2022-10-27 08:12
description: Ask Apple 为开发者与苹果工程师创造了在 WWDC 之外进行直接交流的机会。本文对本次活动中与 SwiftUI 有关的一些问答进行了整理，并添加了一点个人见解。本文为上篇。
tags: SwiftUI,Ask Apple 2022
title: Ask Apple 2022 与 SwiftUI 有关的问答（上）
image: images/SwiftUI-of-Ask-Apple-2022-1.png
---
Ask Apple 为开发者与苹果工程师创造了在 WWDC 之外进行直接交流的机会。本文对本次活动中与 SwiftUI 有关的一些问答进行了整理，并添加了一点个人见解。本文为上篇。

## Q&A

### UIActivityViewController

Q：是否有计划为 iOS 系统的 UIActivityViewController 添加 “原生” 的 SwiftUI 支持？

A：现在已经可以使用了！请查看 [ShareLink](https://developer.apple.com/documentation/swiftui/sharelink/)

### contextAction

Q：在早期的 iOS 16 和 macOS 13 测试版中，我们看到一个新的 `.contextAction` 修改器，后来被删除了。是否有任何建议用来检测列表中的行选择，类似于 “NavigationLink”，但不导航到另一个视图（例如，显示 Sheet 或从列表中选择一个选项 ）？对 iOS 和 iPadOS 来说，一个按钮或许有效，但对 macOS 就不太适合了。另外，`.contextAction` 支持多选。它还会回来吗？

A：看一下上下文菜单修饰器（ contextMenu ）的 primaryAction 参数。该 API 也有一个 forSelectionType 参数，支持多选。

> 在 SwiftUI 4.0 中，contextMenu 的功能获得了不小的提高。例如一个上下文菜单中可以有多个选项、支持 primaryAction、以及可定制预览视图。上文中提到的带 primaryAction 参数的 contextMenu 不仅可以用于 List ，而且也可以用于 Table。

![contextMenu_2022-10-26_14.01.21.2022-10-26 14_02_29](https://cdn.fatbobman.com/contextMenu_2022-10-26_14.01.21.2022-10-26%2014_02_29.gif)

```responser
id:1
```

### 如何对 @State 变量进行测试

Q：对于测试 SwiftUI 视图中的 @State 变量是否有推荐的方式？只有将这些变量重构到视图模型中去这一种方式？

A：如果在同一个视图中，有多个相互关联的 @State 属性，将他们提取到一个结构中或许是好的选择。将他们提取到 view model 中也是一种策略，但不是必须的。

> 在单元测试中，很难对 SwiftUI 视图中的依赖（ 符合 DynamicProperty 协议 ）进行测试。这也是 Redux-like 框架的优势之一（ 将状态从视图中抽离出来，方便测试 ）。请阅读 [Writing testable code when using SwiftUI](https://www.swiftbysundell.com/articles/writing-testable-code-when-using-swiftui/) 一文，了解如何编写对测试友好的视图代码。

### 创建与 IM 应用类似的底部文字输入栏

Q：你好，我的问题是关于 TextField 的。假设我们想创建一个类似于 iMessage 的视图，在那里你可以看到一个信息列表（与本例无关），在视图的底部有一个文本框。当用户点击文本字段时，键盘会在其工具栏中出现一个文本字段。我试着在 ToolbarItemGroup(place: .bottomBar) 中添加一个 TextFiled ，在 ToolbarItemGroup(place: .keyboard) 中添加第二个，然后在 @FocusState 变量的帮助下，我可以隐藏一个并将焦点转移到键盘上。这有点笨拙，我不认为有两个文本框是正确的做法。另外，按照这种方法，@FocusState 变量会变得没有反应，而且它不能被设置为 nil（ 返回到以前的视图并没有移除键盘 ）。是否可以在纯 SwiftUI 中完成（ 不使用 UIKit ）？给我一些方向来完成它吗？

A：一般来说，我建议使用 `.safeAreaInset(edge: .bottom)` 来实现底部文本字段。然后根据它的焦点状态来定制它的显示样式。希望这对你的设计有用。

> 自从 SwiftUI 3.0 提供了 safeAreaInset 视图修饰器之后，实现问题中的案例将不再是难事。详情请参阅 [掌握 SwiftUI 的 Safe Area](https://www.fatbobman.com/posts/safeArea/) 一文。

### 在使用 environmentObject 的情况下，如何避免创建实例的视图被重新计算

Q：如何在避免重新计算顶层视图 body 的情况下，在不同子树的两个子视图之间共享状态（ 例如 ObservableObject ）？比如说我可以在父级视图中拥有 StateObject，并通过 EnvironmentObject 传递该对象。然而，如果里面的 @Published 属性改变了，父视图和它的子树也都被重新计算。

A：EnvironmentObject 是一个很好的工具。如果你不想让父视图也被更新，可以在创建对象时不使用 @StateObject 或 @ObservedObject 。

> 对于苹果工程师给予的建议有一点请注意，那就是如果有在父视图中修改该环境对象实例的需求，须确保父视图不会被反复重构（ SwiftUI 重新创建视图类型的实例 ）。详情请参阅 [StateObject 与 ObservedObject](https://www.fatbobman.com/posts/StateObject_and_ObservedObject/) 。

### NavigationPath

Q：很高兴看到新的 NavigationStack/NavigationPath，对我来说它们运行良好。我想知道我是否可以通过观察（ inspect ）NavigationPath 以判断我的 SearchView 是否进入了某个视图（ 仅是举例 ）。我已经有了使用 NavigationPath.CodableRepresentation 的想法，但我担心这可能不是观察 NavigationPath 最佳或最可持续的方式。谢谢！

A：没有办法对 NavigationPath 进行内省。如果你需要知道路径的内容，一个好的方法是使用一个同质（ 同一类型 ）的 PATH，比如 `@State private var path: [MyEnum]` ，然后使用 navigationDestination 在该枚举类型上切换。

> NavigationPath 会创建一个完全类型擦除的数据集合，它仅要求元素符合 Hashable 协议。NavigationPath 具备一个有趣且强大的特点，它能够在所有元素的类型信息都已被抹除的情况下，提供将自身编解码到 JSON 的能力。阅读 [Reverse Engineering SwiftUI’s NavigationPath Codability](https://www.pointfree.co/blog/posts/78-reverse-engineering-swiftui-s-navigationpath-codability) 一文，以了解它的实现原理。

### 锁定 Charts 纵轴刻度

Q：我有一个 Swift 图表，通过监听拖动事件实现在拖动过程中显示一个 RuleMark。在拖动过程中，Y 轴的刻度会变大。在我的例子中，不拖动时从 0 到 75，拖动时从 0 到 100。有什么办法可以阻止这种情况吗？

A：你可以用 `.chartYScale(domain: 0 ... 75)` 锁定 Y 轴的刻度域。

### 隐式动画和显式动画

Q：你好！是否有其他方法可以直接根据状态的变化对视图进行动画处理而不使用 onChange 修饰器？我的代码是这样的。

```swift
.onChange(of: modle.state.aChange { value in
    withAnimation(...) {
        self.isAnimated = value
    }
   }
)
```

A：你可以通过使用 `.animation(.easeInOut, value: model.state)` ，直接对特定状态的变化进行动画。model.state 的任何变动都将引起动画。

> 通过使用与某个特定状态绑定的 animation 修饰器（ 老版本的 animation 修饰器已被软弃用 ），可以实现更加精确的动画效果。阅读 [SwiftUI 的动画机制](https://www.fatbobman.com/posts/the_animation_mechanism_of_swiftUI/) 一文，了解更多有关动画的内容。

### 自适应高度 Sheet

Q：如何在 iOS16 中呈现与动态内容高度相匹配的 Sheet？我想在 presentationDetents 中使用视图高度。

A：谢谢你的问题。这在目前是不可能的，但也是我们感兴趣的事情。

> 估计苹果的工程师比较忙，没有认真考虑这个问题。在 iOS 16 中，通过 presentationDetents 同 GeometryReader 的配合，可以创建与内容高度一致的 Sheet。此处查看 [完整代码](https://gist.github.com/fatbobman/5feab313dbade52cfc66c4f1fd101f66) 。

![adaptiveSheet_2022-10-22_08.50.29](https://cdn.fatbobman.com/adaptiveSheet_2022-10-22_08.50.29.gif)

### ToolbarContentBuilder

Q：我希望看到 @ToolbarBuilder 或对 `if condition { ToolbarItem(a) } else { ToolbarItem(b) } ` 这类的代码有更好的支持。

A：你永远不会看到 @ToolbarBuilder 了，因为 @ToolbarContentBuilder 在 iOS 16 中得到了功能增强。 
@ToolbarContentBuilder 已经提供了对 `if else` 的支持，而且可以在符合 ToolbarContent 的自定义类型中使用 @Environment / @EnvironmentObject 等动态属性。

### WindowGroup

Q：早上好！我是 SwiftUI 新手。我的问题是关于场景的。几乎所有教程和示例代码库中，只使用了一个 WindowGroup 场景，所有内容都嵌套在 ContentView 中。是否关于如何使用多个场景的指导或例子？或者大多数应用程序只需要一个 WindowGroup ？

A：多场景对于建立复杂的应用程序是很有用的，特别是在 macOS 上。例如，你可能希望有一个同时定义了 “窗口组” 和 “文档组” 的应用程序，或者有一个 “窗口组” 和一个辅助的 “窗口” 场景的应用程序。场景的内容视图定义了场景创建的窗口中的视图内容，但场景本身定义了应用程序的整体结构。

> SwiftUI 4.0 中，WindowGroup 获得了相当大的更新，真正具备了开发 macOS 应用的能力。详细的内容请阅读 [Bringing multiple windows to your SwiftUI app](https://developer.apple.com/documentation/swiftui/bringing_multiple_windows_to_your_swiftui_app) 以及 [WWDC 2022 Session](https://developer.apple.com/videos/play/wwdc2022/10061/) 。

### DocumentGroup

Q：在 macOS 上使用 SwiftUI 应用生命周期和 DocumentGroup 时，如果应用仅为数据阅读器，是否可以禁止创建新文件？

A：DocumentGroup 提供一个 [初始化器](https://developer.apple.com/documentation/swiftui/documentgroup/init(viewing:viewer:)-6dq9n)，用于创建一个阅读器类型的应用程序。只允许打开该内容类型的文件，但不能进行编辑。

### MVVM 

Q：在 UIKit 时代，MVVM 是一种常见的架构，视图显示的数据来自一个单独的 viewModel 类。这在 SwiftUI 中仍适用，还是说 struct 本身现在被视为 viewModel ？

A：SwiftUI 试图与应用程序的整体架构无关。不过，在传统的 viewModel 意义上，我不建议将视图（ 结构本身 ）作为视图模型。这可能会导致一些不好的后果，例如使视图的可重用性降低，并将业务逻辑与 SwiftUI 视图的生命周期挂钩，这将使处理业务逻辑变得更加困难。简而言之，我们不建议使用视图作为视图模型。但 SwiftUI 确实提供了实现经典 MVVM 架构的工具（例如 StateObjects、ObservedObjects ）。

### onAppear、init、viewDidLoad

Q：在我的应用程序中，我在 UIHostingController 中托管了 SwiftUI 视图，这些视图都处于一个 UITabBarController 中。最近，我注意到 SwiftUI 视图的 onAppear 在意想不到的时间启动，比如当 UITabBarController 被创建时，而不是当视图本身出现时。我在想：1、对于像这样的 UITabBarController 中的 SwiftUI 视图，onAppear 到底应该在什么时候被调用？2、当视图出现在 UITabBarController 中时，推荐的执行代码的方法是什么？

A：当在其他类型的 UIViewControllers 中使用 UIHostingController 时，你可能会通过调用托管控制器的方法来触发视图加载提前发生。对于非惰性视图（如 LazyVStack ），一旦 hosting controller 的视图被初始化，onAppear 将被调用。 对于惰性视图，当在 hosting controller 视图上调用 layoutSubviews 或 sizeThatFits 方法时，会初始化视图。所以，如果你看到视图在你的 UITabBarController 的 init 方法中被初始化，就需要看看在 init 中到底做了什么。可以试着把 init 中的工作转移到 UITabBarController 的 viewDidLoad 中。

> 惰性容器中的视图，会根据其是否出现在可视区域而反复调用 onAppear 和 onDisapper。但 onAppear 和 onDisappear 并非为视图存续期起点和终点。事实上，这些视图（ 惰性容器中的视图 ）一旦被创建，其存续期将持续到惰性容器被销毁为止。请阅读 [SwiftUI 视图的生命周期研究](https://www.fatbobman.com/posts/swiftUILifeCycle/) 了解更多内容。

### 通用导航模型

Q：我们正在使用带有路径参数的 NavigationStack，但当用户在 stage manager 中把窗口的大小从 Regular 调整为 Compact 时，我们在 “转换” 路径方面遇到了麻烦。在常规宽度下，我们在详细视图中有一个带有导航堆栈的侧边栏。在紧凑宽度下，我们有一个标签栏，每个标签都有一个导航堆栈。

A：目前最好的方法是建立一个导航状态模型对象，它持有导航状态的规范表示，它可以为你的正常和紧凑显示提供专门的程序绑定。例如，在你的模型中，有多个路径，每个标签都有一个，但在 split view 中，只投射其中一个路径的细节。使用一个共同的底层数据源，并将其投射到 UI 的需求上，这样就可以对该模型进行单元测试，以确保常规和紧凑的投影是一致的。

> 在 SwiftUI 4 中，紧凑和常规分别对应着 NavigationStack 和 NavigationSplitView 两种不同的控件。两者有着完全不同的驱动模式。开发者目前仍在尝试创建一个可优雅地同时为两种模式提供路径的模型。阅读 [SwiftUI 4.0 的全新导航系统](https://www.fatbobman.com/posts/new_navigator_of_SwiftUI_4/) ，了解它们之间的不同。

### 位置偏移的方法与效率

Q：在非线性位置（ 有 2 个轴 ）渲染带有圆形图像最好方法是什么？我目前使用的是 ZStack，图像通过 offset 进行偏移，这样就可以把它们放在我想要的地方，但我不知道这是否是最有效的方法。

A：只要性能足够好，能够满足你的用例那就是可取的方法。对我来说，这似乎是一个完全合理的实现。如果你遇到了性能问题或者希望大幅扩展你所绘制的图片数量，可以试一下 .drawingGroup 和 Canvas APIs ，它们都可以用于更密集地绘制。

> 在 SwiftUI 中，能够实现偏移的手段有很多，例如：offset、alignmentGuide、padding、position 等。除了使用习惯外，还应考虑偏移后的视图是否需要会对周边的视图产生影响（ 布局层面 ）。详情请阅读 [在 SwiftUI 中实现视图居中的若干种方法](https://www.fatbobman.com/posts/centering_the_View_in_SwiftUI/) 。

### NavigationSplitView 的尺寸规则

Q：你好！我已经开始采用 NavigationSplitView，并且非常喜欢它。在有些情况下，我想根据视图是否折叠来做决定（ 例如，如果展开，在详细视图中显示一条信息，如果折叠，则显示一个警告或其他指示 ）。我是否可以认为，如果水平尺寸类是紧凑（ compact ）的，它就是折叠的？还是有一个更可靠的判断方法？

A：紧凑（ compact ）确实对应于一个折叠的导航分割视图。

```responser
id:1
```

### 如何改善一个包含大量 UITextField 的视图效率

Q：我有一个包含 132 个 UITextField 的 SwiftUI 视图。我知道这个数量很大，但这是由业务逻辑决定的。与内存泄漏进行了大量的较量后，我设法让它工作起来。但是从一个文本字段到下一个文本字段的聚焦感觉不够流畅，而且每当我在一个文本字段中输入一个字母时，我的 CPU 使用率似乎会飙升到 70% — 100%。另外，用 UIKit 实现同样功能的视图，它没有任何的性能问题。

A：如果你在 iOS 上使用 UITextField 遇到性能问题，你可以尝试避免每个视图都是 UITextField ，默认渲染为 Text ，当文本被点击时动态切换为 UITextField 。

### 跨视图层次共享

Q：在数据来自 API 响应的情况下，在多个视图之间共享数据的最佳方式是什么？ 我在 ContentView 中使用了 enviromentObject 作为所有视图的封装器，在每个视图中，我使用 @EnviromentObject 来访问这些数据，对于这种情况，这是最好的方法吗？ 这种方法的唯一问题是，当我添加新数据时，内存使用量增加。

A：@EnvironmentObject / environmentObject 可能是跨视图层次共享同一模型的最佳工具。使用它们应该只创建一个实例，然后可以在子视图中读取。这应该不会增加内存的使用（ 如果有的话，请提出反馈 ）。如果你向你的模型对象追加越来越多的数据，你可能会增加内存的使用，这是很正常的。如果发生这种情况，克服这种情况的技术是在外部存储上保存一些数据，只在内存中保留最相关的数据和一个标识符，以便能够完全取回其余的数据。

### task vs onAppear

Q：如果同步操作，`.task` 和 `.onAppear` 之间有什么区别吗？换句话说，如果我写 `Color.green.task { self.someState += }` ，是否能保证在视图第一次出现之前状态一定会改变？我问这个问题是因为我喜欢用 `.task(id:...)`来代替 `.onAppear`与 `.onChange(of:)` 。

A：onAppear 和 task 都是在我们第一次在视图上运行 body 之前调用的。对于你的用例，它们在行为上是等同的。

> 阅读 [掌握 SwiftUI 的 task 修饰器](https://www.fatbobman.com/posts/mastering_SwiftUI_task_modifier/) 了解更多有关 task 的内容。

### WindowGroup 和 OpenWindowAction

Q：在 macOS 上是否可以在创建新窗口时附加参数？我在同一个子上下文中创建一个新的托管对象，并希望将这个对象发送到一个新的窗口。目前我的做法是在一个单例中保存对子上下文和托管对象的引用，然后用一个 URL 打开一个新窗口，这个 URL 在单例中检查上下文和托管对象。如果我们能用自定义参数启动新窗口，那就更好了。

A：在 macOS Ventura 中，我们在 [WindowGroup 上引入了新的 API](https://developer.apple.com/documentation/swiftui/windowgroup/init(for:content:))，可以让你在打开窗口时向其传递数据。这也可以和 [OpenWindowAction](https://developer.apple.com/documentation/swiftui/openwindowaction/) 一起使用。请注意，你的数据需要是可选的，或者指定一个默认值，因为在某些情况下，框架自身也会创建窗口（ 例如，当选择新窗口菜单项 ）。它也可以在 iPadOS 上工作，将创建一个新的场景，即 2/3 或 1/3 分割。

### 在构造函数中初始化 @StateObject

Q：是否有办法在视图中用该视图结构参数初始化一个 @StateObject ？

A：可以通过在 init 方法中手动初始化 @StateObject 来实现。`self._store = StateObject(wrappedValue: Store(id: id))` 。澄清一下。下划线会让它看起来有点诡异，但访问底层存储并没有错。官方文档主要试图指出人们最常见的用法，这样他们就不会一开始就试图直接初始化他们的属性包装器。顺便提一下，试图通过底层存储来初始化 @State 是我们在过去警告过的事情。不是因为它不能工作，而是因为如果你不深入了解 @State 和身份（ identity ）的工作原理，它的行为就会相当混乱。

> 属性包装器（ property wrapper ）类型在编译的时候，首先会对用户自定义的属性包装类型代码进行转译。有关下划线的含义和用法，请参阅 [为自定义属性包装类型添加类 @Published 的能力](https://www.fatbobman.com/posts/adding-Published-ability-to-custom-property-wrapper-types/) 。

![image-20221022135326560](https://cdn.fatbobman.com/image-20221022135326560.png)

### San Francisco 宽度风格

Q：如何在 SwiftUI 中如何使用 SF 字体家族新增的三种宽度风格（ Compressed、Condensed、Expanded ）？

A：你可以使用 fontWidth 修饰器来进行调整。

> 很遗憾，仅支持 SF，对中文没有效果。阅读 [How to change SwiftUI Font Width](https://sarunw.com/posts/swiftui-font-width/) 一文，了解具体用法。

![image-20221022135907441](https://cdn.fatbobman.com/image-20221022135907441.png)

### 为 Stepper 添加快捷键

Q：我们如何为 SwiftUI 的 Stepper（ 在 MacOS 上 ）添加增量和减量操作的快捷键？

A：实现近似行为的方法是在菜单中使用命令来提供相同的操作。通常情况下，应该有列表让人们知道有哪些键盘快捷键可用。但是，如果这不适合你的使用情况，我们会对这方面的增强请求反馈感兴趣。

> 可以通过将包含快捷键的 Button 隐藏起来实现类似的需求

```swift
struct ContentView: View {
    @State var value = 10
    var body: some View {
        Form {
            Stepper(value: $value, in: 0...100, label: { Text("Value:\(value)") })
                .background(
                    VStack {
                        Button("+") { value += value < 100 ? 1 : 0 }.keyboardShortcut("+",modifiers: [])
                        Button("-") { value -= value > 1 ? 1 : 0 }.keyboardShortcut("-",modifiers: [])
                    }.frame(width: 0).opacity(0)
                )
        }
    }
}
```

### LabeledContent

Q：Label 有时被（ 误 ）用来为一个值提供文字说明（ 例如，账户余额为 10 美元 ），但一些开发人员没有意识到这个说明在 VoiceOver 中无法被读取。除了我们创建一个 LabeledValue 组件外，SwiftUI 是否提供了其他的解决方案？

A：SwiftUI 现在有一个 [LabeledContent](https://developer.apple.com/documentation/swiftui/labeledcontent) 视图，你可以用它来给一些内容加上标签。LabeledContent 包含内置的格式化支持！例如 `LabeledContent("Age", value: person.age, format: .number)` 。

> 阅读 [Mastering LabeledContent in SwiftUI](https://swiftwithmajid.com/2022/07/13/mastering-labeledcontent-in-swiftui/)，了解有关 LabeledContent 的更多用例。

### ViewBuilder 中的 if 语句

Q：我知道 SwiftUI 是基于 ResultBuilder 的。所以 if 语句通过树状结构与 buildEither 进行操作。那么在 SwiftUI 中使 if 语句是否有什么注意事项？

A：关于 if/else 需要注意的是，它们如何影响视图的身份，我们在 WWDC 上有一个很好的 [演讲](https://developer.apple.com/videos/play/wwdc2021/10022/)。

> 在某些情况下，利用惰性视图修饰器，不仅可以保持视图身份的稳定，同时也能获得 SwiftUI 更多的优化。例如用  `.opacity(value < 10 ? 1 : 0.5)` 代替 `if value < 10 {} else {}`

### @State 的初始化

Q：在启动时设置 @State var 值的正确方法是什么？我知道 @State 应该是一个内部值，但在某些情况下，我们需要从外部传入一个值，这对于 onAppear 似乎并不可行。下面的方法由于某种原因并不总是有效。

```swift
init(id: UUID) {
    self._store = StateObject(wrappedValue: Store(id: id))
}
```

> 开发人员应该是没理解提问者的疑问，给出了同上面 StateObject 一样的回答。提问者应该是想通过在父视图中不断修改 id 的参数值，来重新初始化 State 的值。这就涉及到了所有符合 DynamicProperty 协议的属性包装器的一个特点：在视图的生存期内仅有第一次初始化的实例会与视图创建关联。详细请阅读 [避免 SwiftUI 视图的重复计算](https://www.fatbobman.com/posts/avoid_repeated_calculations_of_SwiftUI_views/) 。从父视图通过环境值进行传递应该可以满足提问者当前的需求：父视图可以传入新值，当前视图也可以在视图范围内改变该值。

## 总结

我忽略掉了没有获得结论的问题。希望上述的整理能够对你有所帮助。

欢迎通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ) 或博客的留言板与我进行交流。

> 我正以聊天室、Twitter、博客留言等讨论为灵感，从中选取有代表性的问题和技巧制作成 Tips ，发布在 Twitter 上。每周也会对当周博客上的新文章以及在 Twitter 上发布的 Tips 进行汇总，并通过邮件列表的形式发送给订阅者。

**订阅下方的 [邮件列表](https://artisanal-knitter-2544.ck.page/d3591dd1e7)，可以及时获得每周的 Tips 汇总。**
