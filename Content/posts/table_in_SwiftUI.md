---
date: 2022-06-22 08:20
description: Table 是 SwiftUI 3.0 中为 macOS 平台提供的表格控件，开发者通过它可以快捷地创建可交互的多列表格。在 WWDC 2022 中，Table 被拓展到 iPadOS 平台，让其拥有了更大的施展空间。本文将介绍 Table 的用法、分析 Table 的特点以及如何在其他的平台上实现类似的功能。
tags: SwiftUI,WWDC22
title: 用 Table 在 SwiftUI 下创建表格
image: images/table_in_SwiftUI.png
---
Table 是 SwiftUI 3.0 中为 macOS 平台提供的表格控件，开发者通过它可以快捷地创建可交互的多列表格。在 WWDC 2022 中，Table 被拓展到 iPadOS 平台，让其拥有了更大的施展空间。本文将介绍 Table 的用法、分析 Table 的特点以及如何在其他的平台上实现类似的功能。

## 具有列（ Row ）特征的 List

在 Table 的定义中，具备明确的行（ Row ）与列（ Column ）的概念。但相较于 SwiftUI 中的网格容器（ LazyVGrid、Grid ）来说，Table 本质上更接近于 List 。开发者可以将 Table 视为具备列特征的 List 。

![image-20220620142551830](https://cdn.fatbobman.com/image-20220620142551830.png)

上图是我们使用 List 创建一个有关 Locale 信息的表格，每行都显示一个与 Locale 有关的数据。创建代码如下：

```swift
struct LocaleInfoList: View {
    @State var localeInfos: [LocaleInfo] = []
    let titles = ["标识符", "语言", "价格", "货币代码", "货币符号"]
    var body: some View {
        List {
            HStack {
                ForEach(titles, id: \.self) { title in
                    Text(title)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    Divider()
                }
            }

            ForEach(localeInfos) { localeInfo in
                HStack {
                    Group {
                        Text(localeInfo.identifier)
                        Text(localeInfo.language)
                        Text(localeInfo.price.formatted())
                            .foregroundColor(localeInfo.price > 4 ? .red : .green)
                        Text(localeInfo.currencyCode)
                        Text(localeInfo.currencySymbol)
                    }
                    .lineLimit(1)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .task {
            localeInfos = prepareData()
        }
    }
}

struct LocaleInfo: Identifiable, Hashable {
    var id: String {
        identifier
    }

    let identifier: String
    let language: String
    let currencyCode: String
    let currencySymbol: String
    let price: Int = .random(in: 3...6)
    let updateDate = Date.now.addingTimeInterval(.random(in: -100000...100000))
    var supported: Bool = .random()

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// 生成演示数据
func prepareData() -> [LocaleInfo] {
    Locale.availableIdentifiers
        .map {
            let cnLocale = Locale(identifier: "zh-cn")
            let locale = Locale(identifier: $0)
            return LocaleInfo(
                identifier: $0,
                language: cnLocale.localizedString(forIdentifier: $0) ?? "",
                currencyCode: locale.currencyCode ?? "",
                currencySymbol: locale.currencySymbol ?? ""
            )
        }
        .filter {
            !($0.currencySymbol.isEmpty || $0.currencySymbol.isEmpty || $0.currencyCode.isEmpty)
        }
}
```

下面的是使用 Table 创建同样表格的代码：

```swift
struct TableDemo: View {
    @State var localeInfos = [LocaleInfo]()
    var body: some View {
        Table {
            TableColumn("标识符", value: \.identifier)
            TableColumn("语言", value: \.language)
            TableColumn("价格") {
                Text("\($0.price)")
                    .foregroundColor($0.price > 4 ? .red : .green)
            }
            TableColumn("货币代码", value: \.currencyCode)
            TableColumn("货币符号", value: \.currencySymbol)
        } rows: {
            ForEach(localeInfos) {
                TableRow($0)
            }
        }
        .task {
            localeInfos = prepareData()
        }
    }
}
```

![image-20220620142510240](https://cdn.fatbobman.com/image-20220620142510240.png)

相较于 List 的版本，不仅代码量更少、表述更加清晰，而且我们还可以获得可固定的标题栏。同 List 一样，Table 也拥有直接引用数据的构造方法，上面的代码还可以进一步地简化为：

```swift
struct TableDemo: View {
    @State var localeInfos = [LocaleInfo]()
    var body: some View {
        Table(localeInfos) { // 直接引用数据源
            TableColumn("标识符", value: \.identifier)
            TableColumn("语言", value: \.language)
            TableColumn("价格") {
                Text("\($0.price)")
                    .foregroundColor($0.price > 4 ? .red : .green)
            }
            TableColumn("货币代码", value: \.currencyCode)
            TableColumn("货币符号", value: \.currencySymbol)
        }
        .task {
            localeInfos = prepareData()
        }
    }
}
```

> 在 SwiftUI 4.0 的第一个测试版本中（ Xcode 14.0 beta (14A5228q) ），Table 在 iPad OS 上的表现不佳，存在不少的 Bug 。例如：标题行与数据行（ 首行 ）重叠；标题行第一列不显示；滚动不顺畅以及某些表现（ 行高 ）与 macOS 版本不一致等情况。

Table 与 List 的近似点：

* 声明逻辑接近
* 与 LazyVGrid（ LazyHGrid ）和 Grid 倾向于将数据元素放置于一个单元格（ Cell ）中不同，在 Table 与 List 中，更习惯于将数据元素以行（ Row ）的形式进行展示（ 在一行中显示数据的不同属性内容 ）
* 在 Table 中数据是懒加载的，行视图（ TableColumn ）的 onAppear 和 onDisappear 的行为也与 List 一致
* Table 与 List 并非真正意义上的布局容器，它们并不像 LazyVGrid、Grid、VStack 等布局容器那样支持视图渲染功能（ ImageRenderer ）

```responser
id:1
```

## 列宽与行高

### 列宽

在 Table 中，我们可以在列设定中设置列宽：

```swift
Table(localeInfos) {
    TableColumn("标识符", value: \.identifier)
    TableColumn("语言", value: \.language)
        .width(min: 200, max: 300)  // 设置宽度范围
    TableColumn("价格") {
        Text("\($0.price)")
            .foregroundColor($0.price > 4 ? .red : .green)
    }
    .width(50) // 设置具体宽度
    TableColumn("货币代码", value: \.currencyCode)
    TableColumn("货币符号", value: \.currencySymbol)
}
```

![image-20220620150114288](https://cdn.fatbobman.com/image-20220620150114288.png)

其他未指定列宽的列（ 标识符、货币代码、货币符号），将会根据 Table 中剩余的横向尺寸进行平分。在 macOS 上，使用者可以通过鼠标拖动列间隔线来改变列间距。

与 List 一样，Table 内置了纵向的滚动支持。在 macOS 上，如果 Table 中的内容（ 行宽度 ）超过了 Table 的宽度，Table 将自动开启横向滚动支持。

如果数据量较小能够完整展示，开发者可以使用 `scrollDisabled(true)` 屏蔽内置的滚动支持。

### 行高

在 macOS 下，Table 的行高是锁定的。无论单元格中内容的实际高度需求有多大，Table 始终将保持系统给定的默认行高。

```swift
TableColumn("价格") {
    Text("\($0.price)")
        .foregroundColor($0.price > 4 ? .red : .green)
        .font(.system(size: 64))
        .frame(height:100)
```

![image-20220620181736770](https://cdn.fatbobman.com/image-20220620181736770.png)

在 iPadOS 下，Table 将根据单元格的高度，自动调整行高。

![image-20220620181923446](https://cdn.fatbobman.com/image-20220620181923446.png)

> 目前无法确定这种情况是有意的设计还是 Bug

## 间隔与对齐

由于 Table 并非真正意义上的网格布局容器，因此并没有提供行列间隔或行列对齐方面的设定。

开发者可以通过 frame 修饰符来更改单元格中内容的对齐方式（ 暂时无法更改标题的对齐方式 ）：

```swift
TableColumn("货币代码") {
    Text($0.currencyCode)
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
}
```

![image-20220620182615838](https://cdn.fatbobman.com/image-20220620182615838.png)

在 Table 中，如果该列显示的属性类型为 String，且无须添加其他设定，可以使用基于 KeyPath 的精简写法：

```swift
TableColumn("货币代码", value:\.currencyCode)
```

但是，如果属性类型不为 String，或者需要添加其他的设定（ 字体、颜色等 ），只能采用尾随闭包的方式来定义 TableColumn （ 如上方的货币代码 ）。

## 样式

SwiftUI 为 Table 提供了几种样式选择，遗憾的是目前只有 `.inset` 可以用于 iPadOS 。

```swift
Table(localeInfos) {
   // 定义 TableColumn ...
}
.tableStyle(.inset(alternatesRowBackgrounds:false))
```

* inset

  默认样式（ 本文之前的截图均为 inset 样式 ），可用于 macOS 和 iPadOS。在 mac 下等同于 `inset(alternatesRowBackgrounds: true)` ，在 iPadOS 下等同于 `inset(alternatesRowBackgrounds: false)`

* inset(alternatesRowBackgrounds: Bool)

  仅用于 macOS，可以设置是否开启行交错背景，便于视觉区分

* bordered

  仅用于 macOS，为 Table 添加边框

![image-20220620183823794](https://cdn.fatbobman.com/image-20220620183823794.png)

* bordered(alternatesRowBackgrounds: Bool)

  仅用于 macOS，可以设置是否开启行交错背景，便于视觉区分

> 或许在之后的测试版中，SwiftUI 会扩展更多的样式到 iPadOS 平台

## 行选择

在 Table 中启用行选择与 List 中的方式十分类似：

```swift
struct TableDemo: View {
    @State var localeInfos = [LocaleInfo]()
    @State var selection: String?
    var body: some View {
        Table(localeInfos, selection: $selection) {
           // 定义 TableColumn ...
        }
    }
}
```

需要注意的是，Table 要求绑定的变量类型与数据（ 数据需要遵循 Identifier 协议 ）的 id 类型一致。比如本例中，LocaleInfo 的 id 类型为 String。

```swift
@State var selection: String?  // 单选
@State var selections: Set<String> = []  // 多选，需要 LocaleInfo 遵循 Hashable 协议
```

下图为开启多选后的场景：

![image-20220620184638673](https://cdn.fatbobman.com/image-20220620184638673.png)

## 排序

Table 另一大核心功能是可以高效地实现多属性排序。

```swift
struct TableDemo: View {
    @State var localeInfos = [LocaleInfo]()
    @State var order: [KeyPathComparator<LocaleInfo>] = [.init(\.identifier, order: .forward)] // 排序条件
    var body: some View {
        Table(localeInfos, sortOrder: $order) { // 绑定排序条件
            TableColumn("标识符", value: \.identifier)
            TableColumn("语言", value: \.language)
                .width(min: 200, max: 300)
            TableColumn("价格",value: \.price) {
                Text("\($0.price)")
                    .foregroundColor($0.price > 4 ? .red : .green)
            }
            .width(50)
            TableColumn("货币代码", value: \.currencyCode)
            TableColumn("货币符号", value: \.currencySymbol)
        }
        .onChange(of: order) { newOrder in
            withAnimation {
                localeInfos.sort(using: newOrder) // 排序条件改变时对数据重排序
            }
        }
        .task {
            localeInfos = prepareData()
            localeInfos.sort(using: order) // 初始化排序
        }
        .scenePadding()
    }
}
```

![table_sort_demo1_2022-06-20_18.55.16.2022-06-20 18_57_13](https://cdn.fatbobman.com/table_sort_demo1_2022-06-20_18.55.16.2022-06-20%2018_57_13.gif)

Table 本身并不会修改数据源，当 Table 绑定了排序变量后，点击支持排序的列标题，Table 会自动更改排序变量的内容。开发者仍需监控排序变量的变化进行排序。

Table 要求排序变量的类型为遵循 SortComparator 的数组，本例中我们直接使用了 Swift 提供的 KeyPathComparator 类型。

如果不想让某个列支持排序，只需要不使用含有 value 参数的 TableColumn 构造方法即可，例如：

```swift
TableColumn("货币代码", value: \.currencyCode) // 启用以该属性为依据的排序
TableColumn("货币代码"){ Text($0.currencyCode) } // 不启用以该属性为依据的排序

// 切勿在不绑定排序变量时，使用如下的写法。应用程序将无法编译（ 并且几乎不会获得错误提示 ）
TableColumn("价格",value: \.currencyCode) {
    Text("\($0.price)")
        .foregroundColor($0.price > 4 ? .red : .green)
}
```

> 目前的测试版 14A5228q ，当属性类型为 Bool 时，在该列上启用排序会导致应用无法编译

尽管在点击可排序列标题后，仅有一个列标题显示了排序方向，但事实上 Table 将按照用户的点击顺序添加或整理排序变量的排序顺序。下面的代码可以清晰地体现这一点：

```swift
struct TableDemo: View {
    @State var localeInfos = [LocaleInfo]()
    @State var order: [KeyPathComparator<LocaleInfo>] = [.init(\.identifier, order: .forward)]
    var body: some View {
        VStack {
            sortKeyPathView() // 显示当前的排序顺序
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
            Table(localeInfos, sortOrder: $order) {
                TableColumn("标识符", value: \.identifier)
                TableColumn("语言", value: \.language)
                    .width(min: 200, max: 300)
                TableColumn("价格", value: \.price) {
                    Text("\($0.price)")
                        .foregroundColor($0.price > 4 ? .red : .green)
                }
                .width(50)
                TableColumn("货币代码", value: \.currencyCode)
                TableColumn("货币符号", value: \.currencySymbol)
            }
        }
        .onChange(of: order) { newOrder in
            withAnimation {
                localeInfos.sort(using: newOrder)
            }
        }
        .task {
            localeInfos = prepareData()
            localeInfos.sort(using: order)
        }
        .scenePadding()
    }

    func sortKeyPath() -> [String] {
        order
            .map {
                let keyPath = $0.keyPath
                let sortOrder = $0.order
                var keyPathString = ""
                switch keyPath {
                case \LocaleInfo.identifier:
                    keyPathString = "标识符"
                case \LocaleInfo.language:
                    keyPathString = "语言"
                case \LocaleInfo.price:
                    keyPathString = "价格"
                case \LocaleInfo.currencyCode:
                    keyPathString = "货币代码"
                case \LocaleInfo.currencySymbol:
                    keyPathString = "货币符号"
                case \LocaleInfo.supported:
                    keyPathString = "已支持"
                case \LocaleInfo.updateDate:
                    keyPathString = "日期"
                default:
                    break
                }

                return keyPathString + (sortOrder == .reverse ? "↓" : "↑")
            }
    }

    @ViewBuilder
    func sortKeyPathView() -> some View {
        HStack {
            ForEach(sortKeyPath(), id: \.self) { sortKeyPath in
                Text(sortKeyPath)
            }
        }
    }
}
```

![table_sort_demo2_2022-06-20_19.11.48.2022-06-20 19_13_16](https://cdn.fatbobman.com/table_sort_demo2_2022-06-20_19.11.48.2022-06-20%2019_13_16.gif)

如果担心基于多属性的排序方式有性能方面的问题（ 在数据量很大时 ），可以只使用最后创建的排序条件：

```swift
.onChange(of: order) { newOrder in
    if let singleOrder = newOrder.first {
        withAnimation {
            localeInfos.sort(using: singleOrder)
        }
    }
}
```

在将 SortComparator 转换成 SortDescription（ 或 NSSortDescription ） 用于 Core Data 时，请不要使用 Core Data 无法支持的 Compare 算法。

```responser
id:1
```

## 拖拽

Table 支持以行为单位进行 Drag&Drop 。启用 Drag 支持时，将无法使用 Table 的简化版定义：

```swift
Table {
    TableColumn("标识符", value: \.identifier)
    TableColumn("语言", value: \.language)
        .width(min: 200, max: 300)
    TableColumn("价格", value: \.price) {
        Text("\($0.price)")
            .foregroundColor($0.price > 4 ? .red : .green)
    }
    .width(50)
    TableColumn("货币代码", value: \.currencyCode)
    TableColumn("货币符号", value: \.currencySymbol)
} rows: {
    ForEach(localeInfos){ localeInfo in
        TableRow(localeInfo)
            .itemProvider {  // enable Drap 
                NSItemProvider(object: localeInfo.identifier as NSString)
            }
    }
}
```

![table_drag_demo_2022-06-20_19.36.09.2022-06-20 19_37_28](https://cdn.fatbobman.com/table_drag_demo_2022-06-20_19.36.09.2022-06-20%2019_37_28.gif)

## 交互

除了行选择和行拖拽外，Table 还支持对行设置上下文菜单（ macOS 13+、iPadOS 16+ ）：

```swift
ForEach(localeInfos) { localeInfo in
    TableRow(localeInfo)
        .contextMenu{
            Button("编辑"){}
            Button("删除"){}
            Button("共享"){}
        }
}
```

![image-20220620194057400](https://cdn.fatbobman.com/image-20220620194057400.png)

创建可交互的单元格，将极大地提升表格的用户体验。

```swift
struct TableDemo: View {
    @State var localeInfos = [LocaleInfo]()
    var body: some View {
        VStack {
            Table(localeInfos) {
                TableColumn("标识符", value: \.identifier)
                TableColumn("语言", value: \.language)
                    .width(min: 200, max: 300)
                TableColumn("价格") {
                    Text("\($0.price)")
                        .foregroundColor($0.price > 4 ? .red : .green)
                }
                .width(50)
                TableColumn("货币代码", value: \.currencyCode)
                TableColumn("货币符号", value: \.currencySymbol)
                TableColumn("已支持") {
                    supportedToggle(identifier: $0.identifier, supported: $0.supported)
                }
            }
        }
        .lineLimit(1)
        .task {
            localeInfos = prepareData()
        }
        .scenePadding()
    }

    @ViewBuilder
    func supportedToggle(identifier: String, supported: Bool) -> some View {
        let binding = Binding<Bool>(
            get: { supported },
            set: {
                if let id = localeInfos.firstIndex(where: { $0.identifier == identifier }) {
                    self.localeInfos[id].supported = $0
                }
            }
        )
        Toggle(isOn: binding, label: { Text("") })
    }
}
```

![image-20220620194359218](https://cdn.fatbobman.com/image-20220620194359218.png)

## 先驱还是先烈？

如果你在 Xcode 中编写使用 Table 的代码，大概率会碰到自动提示无法工作的情况。甚至还会出现应用程序无法编译，但没有明确的错误提示（ 错误发生在 Table 内部）。

出现上述问题的主要原因是，苹果没有采用其他 SwiftUI 控件常用的编写方式（ 原生的 SwiftUI 容器或包装 UIKit 控件），开创性地使用了 result builder 为 Table 编写了自己的 DSL 。

或许由于 Table 的 DSL 效率不佳的缘故（ 过多的泛型、过多的构造方法、一个 Table 中有两个 Builder ），当前版本的 Xcode 在处理 Table 代码时相当吃力。

另外，由于 Table DSL 的定义并不完整（ 缺少类似 Group 的容器 ），目前至多只能支持十列数据（ 原因请参阅 [ViewBuilder 研究（下） —— 从模仿中学习](https://www.fatbobman.com/posts/viewBuilder2/#创建更多的_buildBlock) ）。

也许苹果是吸取了 Table DSL 的教训，WWDC 2022 中推出的 SwiftUI Charts（ 也是基于 result builder ）在 Xcode 下的性能表现明显地好于 Table 。

希望苹果能将 Charts 中获取的经验反哺给 Table ，避免让先驱变成了先烈。

## 在其他平台上创建表格

虽然 Table 可以在按照 iOS 16 的 iPhone 上运行，但由于只能显示首列数据，因此并不具备实际的意义。

如果想在 Table 尚不支持或支持不完善的平台（譬如 iPhone）上实现表格功能，请根据你的需求选择合适的替代方案：

* 数据量较大，需要懒加载

  List、LazyVGrid

* 基于行的交互操作（ 拖拽、上下文菜单、选择 ）

  List（ Grid 中的 GridRow 并非真正意义上的行 ）

* 需要视图可渲染（ 保存成图片 ）

  LazyVGrid、Grid

* 可固定的标题行

  List、LazyVGrid、Grid（ 比如使用 matchedGeometryEffect ）

## 总结

如果你想在 SwiftUI 中用更少的代码、更清晰的表达方式创建可交互的表格，不妨试试 Table 。同时也盼望苹果能在接下来的版本中改善 Table 在 Xcode 中的开发效率，并为 Table 添加更多的原生功能。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
