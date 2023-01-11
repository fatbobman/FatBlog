---
date: 2022-06-14 08:12
description: 长久以来，开发者对 SwiftUI 的导航系统颇有微词。受 NavigationView 的能力限制，开发者需要动用各种技巧乃至黑科技才能实现一些本应具备基本功能（例如：返回根视图、向堆栈添加任意视图、返回任意层级视图 、Deep Link 跳转等 ）。SwiftUI 4.0（ iOS 16+ 、macOS 13+ ）对导航系统作出了重大改变，提供了以视图堆栈为管理对象的新 API ，让开发者可以轻松实现编程式导航。本文将对新的导航系统作以介绍。
tags: SwiftUI,WWDC22
title:  SwiftUI 4.0 的全新导航系统
image: images/new_navigator_of_SwiftUI_4.png
---
长久以来，开发者对 SwiftUI 的导航系统颇有微词。受 NavigationView 的能力限制，开发者需要动用各种技巧乃至黑科技才能实现一些本应具备基本功能（例如：返回根视图、向堆栈添加任意视图、返回任意层级视图 、Deep Link 跳转等 ）。SwiftUI 4.0（ iOS 16+ 、macOS 13+ ）对导航系统作出了重大改变，提供了以视图堆栈为管理对象的新 API ，让开发者可以轻松实现编程式导航。本文将对新的导航系统作以介绍。

## 一分为二

新的导航系统最直接的变化是废弃了 NavigationView，将其功能分成了两个单独的控件 NavigationStack 和 NavigationSplitView。

NavigationStack 针对的是单栏的使用场景，例如 iPhone 、Apple TV、Apple Watch：

```swift
NavigationStack {}
// 相当于
NavigationView{}
    .navigationViewStyle(.stack)
```

NavigationSplitView 则针对的是多栏场景，例如 ：iPadOS 、macOS：

```swift
NavigationSplitView {
   SideBarView()
} detail: {
   DetailView()
}

// 对应的是双列场景

NavigationView {
    SideBarView()
    DetailView()
}
.navigationViewStyle(.columns)
```

![navigationSplitView_2_demo](https://cdn.fatbobman.com/navigationSplitView_2_demo.PNG)

```swift
NavigationSplitView {
    SideBarView()
} content: {
    ContentView()
} detail: {
    DetailView
}

// 对应的是三列场景
NavigationView {
    SideBarView()
    ContentView()
    DetailView()
}
.navigationViewStyle(.columns)
```

![navigationSplitView_3_demo](https://cdn.fatbobman.com/navigationSplitView_3_demo.png)

相较于通过 navigationViewStyle 设定 NavigationView 样式的做法，一分为二的方式将让布局表达更加清晰，同时也会强迫开发者为 SwiftUI 应用对 iPadOS 和 macOS 做更多的适配。

> 在 iPhone 这类设备中，NavigationSplitView 会自动进行单栏适配。但是无论是切换动画、编程式 API 接口等多方面都与 NavigationStack 明显不同。因此对于支持多硬件平台的应用来说，最好针对不同的场景分别使用对应的导航控件。

## 两个组件两种逻辑

相较于控件名称上的改变，编程式导航 API 才是本次更新的最大亮点。使用新的编程式 API ，开发者可以轻松地实现例如：返回根视图、在当前视图堆栈中添加任意视图（ 视图跳转 ）、视图外跳转（ Deep Link ）等功能。

苹果为 NavigationStack 和 NavigationSplitView 提供了两种不同逻辑的 API ，这点或许会给部分开发者造成困扰。

```responser
id:1
```

### NavigationView 的编程式导航

NavigationView 其实是具备一定的编程式导航能力的，比如，我们可以通过以下两种 NavigationLink 的构造方法来实现有限的编程式跳转：

```swift
init<S>(_ title: S, isActive: Binding<Bool>, @ViewBuilder destination: () -> Destination)
init<S, V>(_ title: S, tag: V, selection: Binding<V?>, @ViewBuilder destination: () -> Destination)
```

上述两种方法有一定的局限性：

* 需要逐级视图进行绑定，开发者如想实现返回任意层级视图则需要自行管理状态
* 在声明 NavigationLink 时仍需设定目标视图，会造成不必要的实例创建开销
* 较难实现从视图外调用导航功能

“能用，但不好用” 可能就是对老版本编程式导航比较贴切地总结。

### NavigationStack

NavigationStack 从两个角度入手以解决上述问题。

#### 基于类型的响应式目标视图处理机制

比如下面的代码是在老版本（ 4.0 之前 ）SwiftUI 中使用编程式跳转的一种方式：

```swift
struct NavigationViewDemo: View {
    @State var selectedTarget: Target?
    @State var target: Int?
    var body: some View {
        NavigationView{
            List{
                NavigationLink("SubView1", destination: SubView1(), tag: Target.subView1, selection: $selectedTarget) // SwiftUI 在进入当前视图时，无论是否进入目标视图，均将创建其实例（ 不对 body 求值 ）
                NavigationLink("SubView2", destination: SubView2(), tag: Target.subView1, selection: $selectedTarget)
                NavigationLink("SubView3", destination: SubView3(), tag: 3, selection: $target)
                NavigationLink("SubView4", destination: SubView4(), tag: 4, selection: $target)
            }
        }
    }

    enum Target {
        case subView1,subView2
    }
}
```

NavigationStack 实现上述功能将更加地清晰、灵活和高效。

```swift
struct NavigationStackDemo: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("SubView1", value: Target.subView1) // 只声明关联的状态值
                NavigationLink("SubView2", value: Target.subView2)
                NavigationLink("SubView3", value: 3)
                NavigationLink("SubView4", value: 4)
            }
            .navigationDestination(for: Target.self){ target in // 对同一类型进行统一处理，返回目标视图
                switch target {
                    case .subView1:
                        SubView1()
                    case .subView2:
                        SubView2()
                }
            }
            .navigationDestination(for: Int.self) { target in  // 为不同的类型添加多个处理模块
                switch target {
                case 3:
                    SubView3()
                default:
                    SubView4()
                }
            }
        }
    }

    enum Target {
        case subView1,subView2
    }
}
```

NavigationStack 的处理方式有以下特点和优势：

* 由于无需在 NavigationLink 中指定目标视图，因此无须创建多余的视图实例
* 对由同一类型的值驱动的目标进行统一管理（ 可以将堆栈中所有视图的 NavigationLink 处理程序统一到根视图中 ），有利于复杂的逻辑判断，也方便剥离代码
* NavigationLink 将优先使用最接近的类型目标管理代码。例如根视图，与第三层视图都通过 navigationDestination 定义了对 Int 的响应，那么第三层及其之上的视图将使用第三层的处理逻辑

#### 可管理的视图堆栈系统

相较于基于类型的响应式目标视图处理机制，可管理的视图堆栈系统才是新导航系统的杀手锏。

NavigationStack 支持两种堆栈管理类型：

* NavigationPath

  通过添加多个的 navigationDestination ，NavigationStack 可以对多种类型值（ Hashable ）进行响应，使用 `removeLast(_ k: Int = 1)` 返回指定的层级，使用 `append` 进入新的层级

```swift
class PathManager:ObservableObject{
    @Published var path = NavigationPath()
}

struct NavigationViewDemo1: View {
    @StateObject var pathManager = PathManager()
    var body: some View {
        NavigationStack(path:$pathManager.path) {
            List {
                NavigationLink("SubView1", value: 1)
                NavigationLink("SubView2", value: Target.subView2)
                NavigationLink("SubView3", value: 3)
                NavigationLink("SubView4", value: 4)
            }
            .navigationDestination(for: Target.self) { target in
                switch target {
                case .subView1:
                    SubView1()
                case .subView2:
                    SubView2()
                }
            }
            .navigationDestination(for: Int.self) { target in
                switch target {
                case 1:
                    SubView1()
                case 3:
                    SubView3()
                default:
                    SubView4()
                }
            }
        }
        .environmentObject(pathManager)
        .task{
            // 使用 append 可以跳入指定层级，下面将为 root -> SubView3 -> SubView1 -> SubView2 ，在初始状态添加层级将屏蔽动画
            pathManager.path.append(3)
            pathManager.path.append(1)
            pathManager.path.append(Target.subView2)
        }
    }
}

enum Target {
    case subView1, subView2
}

struct SubView1: View {
    @EnvironmentObject var pathManager:PathManager
    var body: some View {
        List{
            // 仍然可以使用此种形式的 NavigationLink，目标视图的处理在根视图对应的 navigationDestination 中
            NavigationLink("SubView2", destination: Target.subView2 )
            NavigationLink("subView3",value: 3)
            Button("go to SubView3"){
                pathManager.path.append(3) // 效果与上面的 NavigationLink("subView3",value: 3) 一样
            }
            Button("返回根视图"){
                pathManager.path.removeLast(pathManager.path.count)       
            }
            Button("返回上层视图"){
                pathManager.path.removeLast() 
            }
        }
    }
}
```

* 元素为符合 Hashable 的单一类型序列

  采用此种堆栈，NavigationStack 将只能响应该序列元素的特定类型

```swift
class PathManager:ObservableObject{
    @Published var path:[Int] = [] // Hashable 序列
}

struct NavigationViewDemo1: View {
    @StateObject var pathManager = PathManager()
    var body: some View {
        NavigationStack(path:$pathManager.path) {
            List {
                NavigationLink("SubView1", value: 1)
                NavigationLink("SubView3", value: 3)
                NavigationLink("SubView4", value: 4)
            }
            // 只能响应序列元素类型
            .navigationDestination(for: Int.self) { target in
                switch target {
                case 1:
                    SubView1()
                case 3:
                    SubView3()
                default:
                    SubView4()
                }
            }
        }
        .environmentObject(pathManager)
        .task{
            pathManager.path = [3,4]  // 直接跳转到指定层级，赋值更加方便
        }
    }
}

struct SubView1: View {
    @EnvironmentObject var pathManager:PathManager
    var body: some View {
        List{
            NavigationLink("subView3",value: 3)
            Button("go to SubView3"){
                pathManager.path.append(3) // 效果与上面的 NavigationLink("subView3",value: 3) 一样
            }
            Button("返回根视图"){
                pathManager.path.removeAll()
            }
            Button("返回上层视图"){
                if pathManager.path.count > 0 {
                    pathManager.path.removeLast()
                }
            }
            Button("响应 Deep Link，重置 Path Stack "){
                pathManager.path = [3,1,1] // 会自动屏蔽动画
            }
            
        }
    }
}
```

开发者可以根据自己的需求选择对应的视图堆栈类型。

> ⚠️  在使用堆栈管理系统的情况下，请不要在编程式导航中混用声明式导航，这样会破坏当前的视图堆栈数据

下面的代码，如果点击声明式导航，将导致堆栈数据重置。

```swift
NavigationLink("SubView3",value: 3)
NavigationLink("SubView4", destination: { SubView4() }) // 不要在编程式导航中混用声明式导航
```

### NavigationSplitView

如果说 NavigationStack 是在三维的空间里堆叠视图，那么 NavigationSplitView 便是在二维的空间中于不同的栏之间动态切换视图。

#### 分栏布局

在 SwiftUI 4.0 之前的版本，可以这样使用 NavigationView 来创建拥有左右两个栏的编程式导航视图：

```swift
class MyStore: ObservableObject {
    @Published var selection: Int?
}

struct NavigationViewDoubleColumnView: View {
    @StateObject var store = MyStore()
    var body: some View {
        NavigationView {
            SideBarView()
            DetailView()
        }
        .environmentObject(store)
    }
}

struct SideBarView: View {
    @EnvironmentObject var store: MyStore
    var body: some View {
        List(0..<30, id: \.self) { i in
            // 此处我们没有使用 NavigationLink 来切换右侧视图，而是改变了 seletion 的值，让右侧视图响应该值的变化                      
            Button("ID: \(i)") {
                store.selection = i
            }
        }
    }
}

struct DetailView: View {
    @EnvironmentObject var store: MyStore
    var body: some View {
        if let selection = store.selection {
            Text("视图：\(selection)")
        } else {
            Text("请选择")
        }
    }
}
```

![double_colunm_2022-06-11_10.16.38](https://cdn.fatbobman.com/double_colunm_2022-06-11_10.16.38.png)

用 NavigationSplitView 实现上面的代码基本上一样。最大的区别是，SwiftUI 4.0 为我们提供了在 NavigationSplitView 中通过 List 快速绑定数据的能力。

```swift
struct NavigationSplitViewDoubleColumnView: View {
    @StateObject var store = MyStore()
    var body: some View {
        NavigationSplitView {
            SideBarView()
        } detail: {
            DetailView()
        }
        .environmentObject(store)
    }
}

struct SideBarView: View {
    @EnvironmentObject var store: MyStore
    var body: some View {
        // 可以在 List 中直接绑定数据，无需通过 Button 显式进行修改
        List(0..<30, id: \.self, selection: $store.selection) { i in
            NavigationLink("ID: \(i)", value: i)  // 使用编程式的 NavigationLink
        }
    }
}
```

![image-20220611104123815](https://cdn.fatbobman.com/image-20220611104123815.png)

由于 SwiftUI 4.0 为 List 提供了进一步的加强，我们还可以不使用 NavigationLink ，改写成下面的代码：

```swift
struct SideBarView: View {
    @EnvironmentObject var store: MyStore
    var body: some View {
        List(0..<30, id: \.self, selection: $store.selection) { i in
            Text("ID: \(i)")  // 也可以换成 Label 或其他视图 ，但不能是 Button
//            NavigationLink("ID: \(i)", value: i)
        }
    }
}
```

> SwiftUI 4.0 中，在 List 绑定了数据后，通过 List 构造方法创建的循环或 ForEach 创建的循环中的内容（ 不能自带点击属性，例如 Button 或 onTapGesture ），将被隐式添加 tag 修饰符，从而具备点击后可更改绑定数据的能力

无论将 List 放置在 NavigationSplitView 的最左侧一栏（ 双栏模式 ）还是左侧两栏中（ 三栏模式 ），都可以通过 List 的绑定数据进行导航。这是 NavigationSplitView 的独有功能。

> 从 iOS 16.1 开始，开发者可以无需通过 List 的绑定模式来跳转视图了。通过在 NavigationSplitView 侧边栏里放一个.navigationDestination，这样侧边栏里的 NavigationLink 就会取代详细栏的根视图。

```swift
NavigationSplitView {
    LazyVStack {
        NavigationLink("link", value: 213)
    }
    .navigationDestination(for: Int.self) { i in
        Text("The value is \(i)")
    }
} detail: {
    Text("Click an item")
}
```

#### 与 NavigationStack 合作

在 SwiftUI 4.0 之前，对于多栏的 NavigationView ，如果我们想在 SideBar 栏内实现堆栈跳转的话，可以使用如下代码：

```swift
struct SideBarView: View {
    @EnvironmentObject var store: MyStore
    var body: some View {
        List(0..<30, id: \.self) { i in
            NavigationLink("ID: \(i)", destination: Text("\(i)")) // 必须使用 NavigationLink
                .isDetailLink(false) // 指定 destination 不要显示在 Detail 列中
        }
    }
}
```

但如果，我们想在 Detail 栏中也想嵌入一个可以实现堆栈跳转的 NavigationView 则会有很大的问题。此时在 Detail 栏中将出现两个 NavigationTitle 以及两个 Toolbar 。

```swift
struct NavigationViewDoubleColumnView: View {
    @StateObject var store = MyStore()
    var body: some View {
        NavigationView {
            SideBarView()
            DetailView()
                .navigationTitle("Detail")  // 为 Detail 栏定义 title
                .toolbar{
                    EditButton()  // 在 Detail 栏创建按钮
                }
        }
        .environmentObject(store)
    }
}

struct SideBarView: View {
    @EnvironmentObject var store: MyStore
    var body: some View {
        List(0..<30, id: \.self) { i in
            Button("ID: \(i)") {
                store.selection = i
            }
        }
    }
}

struct DetailView: View {
    @EnvironmentObject var store: MyStore
    var body: some View {
        NavigationView {
            VStack {
                if let selection = store.selection {
                    NavigationLink("查看详情", destination: Text("\(selection)"))
                } else {
                    Text("请选择")
                }
            }
            .toolbar{
                EditButton()  // 在 Detail 栏中的 NavigationView 创建按钮
            }
            .navigationTitle("Detail") // 为 Detail 栏中的 NavigationView 定义 Title
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }
}
```

![image-20220611110657857](https://cdn.fatbobman.com/image-20220611110657857.png)

> 为此，我之前不得已在 iPad 版本的应用程序中，使用 HStack 来避免出现上述问题。详情请参阅 [在 SwiftUI 下对 iPad 进行适配](https://www.fatbobman.com/posts/swiftui-ipad/)

NavigationSpiteView 已经解决了上述问题，它现在可以同 NavigationStack 进行完美的合作。

```swift
class MyStore: ObservableObject {
    @Published var selection: Int?
}

struct NavigationSplitViewDoubleColumnView: View {
    @StateObject var store = MyStore()
    var body: some View {
        NavigationSplitView {
            SideBarView()
        } detail: {
            DetailView()
                .toolbar {
                    EditButton() // 在 Detail 栏中的 NavigationView 创建按钮
                }
                .navigationTitle("Detail")
        }
        .environmentObject(store)
    }
}

struct SideBarView: View {
    @EnvironmentObject var store: MyStore
    var body: some View {
        List(0..<30, id: \.self, selection: $store.selection) { i in
            Text("ID: \(i)")
        }
    }
}

struct DetailView: View {
    @EnvironmentObject var store: MyStore
    var body: some View {
        NavigationStack {
            VStack {
                if let selection = store.selection {
                    NavigationLink("查看详情", value: selection)
                } else {
                    Text("请选择")
                }
            }
            .navigationDestination(for: Int.self, destination: {
                Text("\($0)")
            })
            .toolbar {
                RenameButton() // 在 Detail 栏中的 NavigationView 创建按钮 
            }
            .navigationTitle("Detail inLine")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
```

NavigationSplitView 会保留最近的 Title 设定，并对分别在 NavigationSplitView 和 NavigationStack 中为 Detail 栏添加的 Toolbar 按钮进行合并。

![image-20220611134247340](https://cdn.fatbobman.com/image-20220611134247340.png)

通过在 NavigationSplitView 中使用 NavigationStack ，开发者拥有了更加丰富的视图调度能力。

#### 动态控制多栏显示状态

另一个之前困扰多栏 NavigationView 的问题就是，无法通过编程的手段动态地控制多栏显示状态。NavigationSplitView 在构造方法中提供了 columnVisibility 参数 （ NavigationSplitViewVisibility 类型 ），通过设置该参数，开发者拥有了对导航栏显示状态的控制能力。

```swift
struct NavigationSplitViewDoubleColumnView: View {
    @StateObject var store = MyStore()
    @State var mode: NavigationSplitViewVisibility = .all 
    var body: some View {
        NavigationSplitView(columnVisibility: $mode) {
            SideBarView()
        }
    content: {
            ContentColumnView()
        }
    detail: {
            DetailView()
        }
        .environmentObject(store)
    }
}
```

![three_column_2022-06-11_13.52.10](https://cdn.fatbobman.com/three_column_2022-06-11_13.52.10.png)

* detailOnly 只显示 Detail 栏（ 最右侧栏 ）
* doubleColumn 在三栏状态下隐藏 Sidebar （ 最左侧 ）栏
* all 显示所有的栏
* automatic 根据当前的上下文自动决定显示行为

*上述选项并非适用于所有的平台，例如，在 macOS 上，detalOnly 不会起作用*

> 如果想在 SwiftUI 4.0 之前的版本上使用类似的功能，可以参考我在 [用 NavigationViewKit 增强 SwiftUI 的导航视图](https://www.fatbobman.com/posts/NavigationViewKit/) 一文中的实现方法

## 其他增强

除了上述的功能， 新的导航系统还在很多其他的地方也进行了增强。

```responser
id:1
```

### 设置栏宽度

NavigationSplitView 为栏中的视图提供了一个新的修饰符 navigationSplitViewColumnWidth ，通过它开发者可以修改栏的默认宽度：

```swift
struct NavigationSplitViewDemo: View {
    @State var mode: NavigationSplitViewVisibility = .all
    var body: some View {
        NavigationSplitView(columnVisibility: $mode) {
            SideBarView()
                .navigationSplitViewColumnWidth(200)
        }
    content: {
            ContentColumnView()
                .navigationSplitViewColumnWidth(min: 100, ideal: 150, max: 200)
        }
    detail: {
            DetailView()
        }
    }
}
```

### 设置 NavigationSplitView 的样式

使用 navigationSplitViewStyle 可以设置 NavigationSplitView 的样式

```swift
struct NavigationSplitViewDemo: View {
    @State var mode: NavigationSplitViewVisibility = .all
    var body: some View {
        NavigationSplitView(columnVisibility: $mode) {
            SideBarView()
        }
    content: {
            ContentColumnView()
        }
    detail: {
            DetailView()
        }
        .navigationSplitViewStyle(.balanced) // 设置样式
    }
}
```

* prominentDetail

  无论左侧栏显示与否，保持右侧的 Detail 栏尺寸不变（ 通常是全屏 ）。iPad 在 Portrait 显示状态下，默认即为此种模式

* balanced

  在显示左侧栏的时候，缩小右侧 Detail 栏的尺寸。iPad 在 landscape 显示状态下，默认即为此种模式

* automatic

  默认值，根据上下文自动调整外观样式

### 在 NavigationTitle 中添加菜单

使用新的 navigationTitle 构造方法，可以将菜单嵌入到标题栏中。

```swift
.navigationTitle( Text("Setting"), actions: {
                Button("Action1"){}
                Button("Action2"){}
                Button("Action3"){}
            })
```

![image-20220612085945286](https://cdn.fatbobman.com/image-20220612085945286.png)

### 更改 NavigationBar 背景色

```swift
NavigationStack{
    List(0..<30,id:\.self){ i in
        Text("\(i)")
    }
    .listStyle(.plain)
    .navigationTitle("Hello")
    .toolbarBackground(.pink, in: .navigationBar)
}
```

![RocketSim_Screenshot_iPhone_13_Pro_Max_2022-06-12_09.12.01](https://cdn.fatbobman.com/RocketSim_Screenshot_iPhone_13_Pro_Max_2022-06-12_09.12.01.png)

NavigationStack 的 toolbar 背景色只有在视图上滚时才会显示。

> SwiftUI 4.0 中，将 toolbar 的认定范围扩大到了 TabView 。在 toolbar 的设置中，通过 placement 可以设置适用的对象

### 隐藏 toolbar

```swift
NavigationStack {
    ContentView()
        .toolbar(.hidden, in: .navigationBar)
}
```

### 设置 toolbar 的色彩外观（ Color Scheme ）

```swift
.toolbarColorScheme(.dark, for: .navigationBar)
```

![RocketSim_Screenshot_iPhone_13_Pro_Max_2022-06-12_09.21.29](https://cdn.fatbobman.com/RocketSim_Screenshot_iPhone_13_Pro_Max_2022-06-12_09.21.29.png)

### Toolbar 角色

使用 toolbarRole 设置当前 toolbar 的角色身份。不同的角色将让 toolbar 的外观和排版有所不同（ 视设备而异 ）。

```swift
struct ToolRoleTest: View {
    var body: some View {
        NavigationStack {
            List(0..<10, id: \.self) {
                NavigationLink("ID: \($0)", value: $0)
            }
            .navigationDestination(for: Int.self) {
                Text("\($0)")
                    .navigationTitle("Title for \($0)")
                    .toolbarRole(.editor)
            }
            .navigationTitle("Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarRole(.browser)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
        }
    }
}
```

* navigationStack

  默认角色，长按可显示视图堆栈列表

* browser

  在 iPad 下，当前视图的 Title 将显示在左侧

![image-20220612190914949](https://cdn.fatbobman.com/image-20220612190914949.png)

* editor

  不显示返回按钮旁边的上页视图 Title

![image-20220612191040190](https://cdn.fatbobman.com/image-20220612191040190.png)

### 定制 NavigationLink 样式

在之前版本的 SwiftUI 中，NavigationLink 其实一直都是作为一种特殊的 Button 存在的。到了 SwiftUI 4.0 版本后，SwiftUI 已经将其真正的视为了 Button 。

```swift
NavigationStack {
    VStack {
        NavigationLink("Hello world", value: "sub1")
            .buttonStyle(.bordered)
            .controlSize(.large)
        NavigationLink("Goto next", destination: Text("Next"))
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.red)
    }
    .navigationDestination(for: String.self){ _ in
        Text("Sub View")
    }
}
```

![image-20220613220926715](https://cdn.fatbobman.com/image-20220613220926715.png)

## 总结

SwiftUI 4.0 导航系统的变化如此之大，开发者在惊喜的同时，也要冷静的面对事实。相当一部分开发者由于版本适配的原因并不会使用新的 API ，因此，每个人都需要认真考虑如下问题：

* 如何从新 API 中获得灵感
* 如何在老版本中运用编程式导航思想
* 如何让新老版本的程序都能享受系统提供的便利

另一方面，新导航系统也向每一个开发者传递了明确的信号，苹果希望应用能够为 iPad 和 macOS 提供更加符合各自设备特点的 UI 界面。这种信号会越来越强，苹果也为此会提供越来越多的 API。

> 目前已经有人实现了 NavigationStack 在低版本 SwiftUI 下的仿制品 —— [NavigationBackport](https://github.com/johnpatrickmorgan/NavigationBackport) ，有兴趣的朋友可以参考作者的实现方式

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
