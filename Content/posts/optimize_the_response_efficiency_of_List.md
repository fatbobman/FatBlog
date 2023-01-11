---
date: 2022-04-26 08:12
description: 拥有优秀的交互效果和手感，是很多 iOS 开发者长久以来坚守的原则。同样一段代码，在不同数据量级下的响应表现可能会有云泥之别。本文将通过一个优化列表视图的案例，展现在 SwiftUI 中查找问题、解决问题的思路，其中也会对 SwiftUI 视图的显式标识、@FetchRequest 的动态设置、List 的运作机制等内容有所涉及。本文的范例需运行在 iOS 15 及以上系统，技术特性也以 SwiftUI 3.0 为基础。
tags: SwiftUI
title: 优化在 SwiftUI List 中显示大数据集的响应效率
image: images/optimizeList.png
---
拥有优秀的交互效果和手感，是很多 iOS 开发者长久以来坚守的原则。同样一段代码，在不同数据量级下的响应表现可能会有云泥之别。本文将通过一个优化列表视图的案例，展现在 SwiftUI 中查找问题、解决问题的思路，其中也会对 SwiftUI 视图的显式标识、@FetchRequest 的动态设置、List 的运作机制等内容有所涉及。本文的范例需运行在 iOS 15 及以上系统，技术特性也以 SwiftUI 3.0 为基础。

首先创建一个假设性的需求：

* 一个可以展示数万条记录的视图
* 从上个视图进入该视图时不应有明显延迟
* 可以一键到达数据的顶部或底部且没有响应延迟

```responser
id:1
```

## 响应迟钝的列表视图

通常会考虑采用如下的步骤以实现上面的要求：

* 创建数据集
* 通过 List 展示数据集
* 用 ScrollViewReader 对 List 进行包裹
* 给 List 中的 item 添加 id 标识，用于定位
* 通过 scrollTo 滚动到指定的位置（顶部或底部）

下面的代码便是按照此思路来实现的：

```swift
struct ContentView: View {
    var body: some View {
        NavigationView {
            List {
                // 通过一个 NavigationView 进入列表视图
                NavigationLink("包含 40000 条数据的列表视图", destination: ListEachRowHasID())
            }
        }
    }
}

struct ListEachRowHasID: View {
    // 数据通过 CoreData 创建。创建了 40000 条演示数据。Item 的结构非常简单，记录容量很小。
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default
    )
    private var items: FetchedResults<Item>

    var body: some View {
        ScrollViewReader { proxy in
            VStack {
                HStack {
                    Button("Top") {
                        withAnimation {
                            // 滚动到列表最上面的记录
                            proxy.scrollTo(items.first?.objectID, anchor: .center)
                        }
                    }.buttonStyle(.bordered)
                    Button("Bottom") {
                        withAnimation {
                            // 滚动到列表最下面的记录
                            proxy.scrollTo(items.last?.objectID)
                        }
                    }.buttonStyle(.bordered)
                }
                List {
                    ForEach(items) { item in
                        ItemRow(item: item)
                            // 给每行记录视图设置标识
                            .id(item.objectID)
                    }
                }
            }
        }
    }
}

struct ItemRow: View {
    let item: Item
    var body: some View {
        Text(item.timestamp, format: .dateTime)
            .frame(minHeight: 40)
    }
}
// 满足 ForEach 的 Identifiable 需求
extension Item: Identifiable {}
```

> 本文中的 [全部源代码可以在此处获取](https://github.com/fatbobman/BlogCodes/tree/main/FetchRequestDemo)

在只拥有数百条记录的情况下，上面的代码运行的效果非常良好，但在创建了 40000 条演示数据后，该视图的响应状况如下：

![id_delay_demo_2022-04-23 12.22.44.2022-04-23 12_29_07](https://cdn.fatbobman.com/id_delay_demo_2022-04-23%2012.22.44.2022-04-23%2012_29_07.gif)

进入视图的时候有明显的卡顿（1 秒多钟），进入后列表滚动流畅且可无延迟的响应滚动到列表底部或顶部的指令。

## 找寻问题原因

或许有人会认为，毕竟数据量较大，进入列表视图有一定的延迟是正常的。但即使在 SwiftUI 的效能并非十分优秀的今天，我们仍然可以做到以更小的卡顿进入一个数倍于当面数据量的列表视图。

考虑到当前的卡顿出现在进入视图的时刻，我们可以将查找问题的关注点集中在如下几个方面：

* Core Data 的性能（ IO 或 惰值填充 ）
* 列表视图的初始化或 body 求值
* List 的效能

### Core Data 的性能

@FetchRequest 是 NSFetchedResultsController 的 SwiftUI 包装。它会根据指定的 NSFetchReqeust ，自动响应数据的变化并刷新视图。上面的代码对应的 NSFetchRequest 如下：

```swift
@FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default
    )
private var items: FetchedResults<Item>

// 等效的 NSFetchRequest
extension Item {
    static var fetchRequest:NSFetchRequest<Item> {
        let fetchRequest = NSFetchRequest<Item>(entityName: "Item")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)]
        return fetchRequest
    }
}

// 相当于
@FetchRequest(fetchRequest: Item.fetchRequest, animation: .default)
var items:FetchedResults<Item>
```

此时 fetchRequest 的 returnsObjectsAsFaults 为默认值 false （托管对象为惰值状态），fetchBatchSize 没有设置 （会将所有数据加载到持久化存储的行缓冲区）。

通过使用 Instruments 得知，即便使用当前没有进行优化的 fetchRequest ,  从数据库中将 40000 条记录加载到持久化存储的行缓冲所用的时间也只有 11ms 左右。

![image-20220423145552324](https://cdn.fatbobman.com/image-20220423145552324.png)

另外，通过下面的代码也可以看到仅有 10 余个托管对象（ 显示屏幕高度所需的数据 ）进行了惰值化填充：

```swift
func info() -> some View {
    let faultCount = items.filter { $0.isFault }.count
    return VStack {
        Text("item's count: \(items.count)")
        Text("fault item's count : \(faultCount)")
    }
}
```

![image-20220425075620588](https://cdn.fatbobman.com/image-20220425075620588.png)

因此可以排除卡顿是由于 Core Data 的原因所导致的。

### 列表视图的初始化和 body 求值

如果对 SwiftUI 的 NavigationView 有一定了解的话，应该知道 SwiftUI 会对 NavigationLink 的目标视图进行预实例化（但不会对 body 求值）。也就是当显示主界面菜单时，列表视图已经完成了实例的创建（可以通过在 ListEachRowHasID 的构造函数中添加打印命令得以证明），因此也不应是实例化列表视图导致的延迟。

通过检查 ListEachRowHasID 的 body 的求值消耗时间，也没有发现任何的效率问题。

```swift
    var body: some View {
        let start = Date()
        ScrollViewReader { proxy in
            VStack {
                ....
            }
        }
        let _ = print(Date().timeIntervalSince(start))
    }
// 0.0004889965057373047
```

目前已经可以基本排除性能问题来源于 IO、数据库、列表视图实例化等因素，那么有极大的可能源自 SwiftUI 的内部处理机制。

### List 的效能

List 作为 SwiftUI 对 UITableView （ NSTableView ）的封装，大多数情况下它的性能都比较令人满意。在 [SwiftUI 视图的生命周期研究](https://www.fatbobman.com/posts/swiftUILifeCycle/) 一文中，我对 List 如何对子视图的显示进行优化做了一定的介绍。按照正常的逻辑，当进入列表视图 ListEachRowHasID 后 List 只应该实例化十几个 ItemRow 子视图 （ 按屏幕的显示需要 ），即便使用 scrollTo 滚动到列表底部，List 也会对滚动过程进行显示优化，滚动过程中至多实例化 100 多个 ItemRow 。

我们对 ItemRow 进行一定的修改以验证上述假设：

```swift
struct ItemRow:View{
    static var count = 0
    let item:Item
    init(item:Item){
        self.item = item
        Self.count += 1
        print(Self.count)
    }
    var body: some View{
//        let _ = print("get body value")
        Text(item.timestamp, format: .dateTime)
            .frame(minHeight:40)
    }
}
```

重新运行，再次进入列表视图，我们竟然得到了如下的结果：

![itemRow_count_2022-04-23_16.39.41.2022-04-23 16_40_53](https://cdn.fatbobman.com/itemRow_count_2022-04-23_16.39.41.2022-04-23%2016_40_53.gif)

List 将所有数据的 itemRow 都进行了实例化，一共 40000 个。这与之前仅会实例化 10 - 20 个子视图的预测真是大相径庭。是什么影响了 List 对视图的优化逻辑？

在进一步排除掉 ScrollViewReader 的影响后，所有的迹象都表明用于给 scrollTo 定位的 id 修饰符可能是导致延迟的罪魁祸首。

在将 `.id(item.objectID)` 注释掉后，进入列表视图的卡顿立刻消失了，List 对子视图的实例化数量也完全同我们最初的预测一致。

![itemRow_withoutID_2022_04_23.2022-04-23 17_01_05](https://cdn.fatbobman.com/itemRow_withoutID_2022_04_23.2022-04-23%2017_01_05.gif)

现在摆在我们面前有两个问题：

* 为什么使用了 id 修饰符的视图会提前实例化呢？
* 不使用 `.id(item.objectID)` ，我们还有什么方法为列表两端定位？

## id 修饰符与视图的显式标识

想搞清楚为什么使用了 id 修饰符的视图会提前实例化，我们首先需要了解 id 修饰符的作用。

标识（ Identity ）是 SwiftUI 在程序的多次更新中识别相同或不同元素的手段，是 SwiftUI 理解你 app 的关键。标识为随时间推移而变化的视图值提供了一个坚固的锚，它应该是稳定且唯一的。

在 SwiftUI 应用代码中，绝大多数的视图标识都是通过结构性标识 （有关结构性标识的内容可以参阅 [ViewBuilder 研究（下） —— 从模仿中学习](https://www.fatbobman.com/posts/viewBuilder2/)）来实现的 —— 通过视图层次结构（视图树）中的视图类型和具体位置来区分视图。但在某些情况下，我们需要使用显式标识（ Explicit identity ）的方式来帮助 SwiftUI 辨认视图。

在 SwiftUI 中为视图设置显式标识目前有两种方式：

* 在 ForEach 的构造方法中指定

  由于 ForEach 中的视图数量是动态的且是在运行时生成的，因此需要在 ForEach 的构造方法中指定可用来标识子视图的 KeyPath 。在我们的当前的例子中，通过将 Item 声明为符合 Identifiable 协议，从而实现了在 ForEach 中进行了默认指定。

```swift
extension Item: Identifiable {}
// NSManagedObject 是 NSObject 的子类。NSObject 为 Identifiable 提供了默认实现
ForEach(items) { item in ... }
// 相当于
ForEach(items, id:\.id) { item in ... }
```

* 通过 id 修饰符指定

  id 修饰符是另一个对视图进行显式标识的方式。通过它，开发者可以使用任何符合 Hashable 协议的值为视图设置显式标识。ScrollViewProxy 的 scrollTo 方法就是通过该值来找到对应的视图。另外如果 id 的标识值发生变化，SwiftUI 将丢弃原视图（生命周期终止及重置状态）并重新创建新的视图。

当仅通过 ForEach 来指定显示标识时，List 会对这些视图的显示进行优化，仅在需要显示时才会对其进行实例化。但一旦为这些子视图添加了 id 修饰符，这些视图将无法享受到 List 提供的优化能力 （ List 只会对 ForEach 中的内容进行优化）。

> id 修饰符标识是通过 IDViewList 对显式标识视图进行跟踪、管理和缓存，它与 ForEach 的标识处理机制完全不同。使用了 id 修饰符相当于将这些视图从 ForEach 中拆分出来，因此丧失了优化条件。

总之，**当前在数据量较大的情况下，应避免在 List 中对 ForEach 的子视图使用 id 修饰符**。

虽然我们已经找到了导致进入列表视图卡顿的原因，但如何在不影响效率的情况下通过 scrollTo 来实现到列表端点的滚动呢？

```responser
id:1
```

## 解决方案一

从 iOS 15 开始，SwiftUI 为 List 添加了更多的定制选项，尤其是解除了对列表行分割线设置的屏蔽且添加了官方的实现。我们可以通过在 ForEach 的外面分别为列表端点设置显式标识来解决使用 scrollTo 滚动到指定位置的问题。

对 ListEachRowHasID 进行如下修改：

```swift
struct ListEachRowHasID: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default
    )
    private var items: FetchedResults<Item>

    @FetchRequest(fetchRequest: Item.fetchRequest1, animation: .default)
    var items1:FetchedResults<Item>

    init(){
        print("init")
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack {
                HStack {
                    Button("Top") {
                        withAnimation {
                            proxy.scrollTo("top", anchor: .center)
                        }
                    }.buttonStyle(.bordered)
                    Button("Bottom") {
                        withAnimation {
                            proxy.scrollTo("bottom")
                        }
                    }.buttonStyle(.bordered)
                }
                List {
                    // List 中不在 ForEach 中的视图不享受优化，无论显示与否都会提前实例化
                    TopCell()
                        .id("top")
                        // 隐藏两端视图的列表分割线
                        .listRowSeparator(.hidden)
                    ForEach(items) { item in
                        ItemRow(item: item)
                    }
                    BottomCell()
                        .id("bottom")
                        .listRowSeparator(.hidden)
                }
                // 设置最小行高，隐藏列表两端的视图
                .environment(\.defaultMinListRowHeight, 0)
            }
        }
    }
}

struct TopCell: View {
    init() { print("top cell init") } 
    var body: some View {
        Text("Top")
            .frame(width: 0, height: 0) // 隐藏两端视图
    }
}

struct BottomCell: View {
    init() { print("bottom cell init") }  // 仅两端的视图会被提前实例化，其他的视图仅在需要时进行实例化
    var body: some View {
        Text("Bottom")
            .frame(width: 0, height: 0)
    }
}
```

运行修改后的代码结果如下：

![onlyTopAndBottomWithID_2022-04-23_18.58.53.2022-04-23 19_02_53](https://cdn.fatbobman.com/onlyTopAndBottomWithID_2022-04-23_18.58.53.2022-04-23%2019_02_53.gif)

目前我们已经可以秒进列表视图，并实现了通过 scrollTo 滚动到指定的位置。

> 由于 id 修饰符并非惰性修饰符（ Inert modifier ），因此我们无法在 ForEach 中仅为列表的头尾数据使用 id 修饰符。如果你尝试通过 if 语句的方式利用判断来添加 id 修饰符，将进一步劣化性能（可在 [ViewBuilder 研究（下） —— 从模仿中学习](https://www.fatbobman.com/posts/viewBuilder2/)）中找到原因 ）。[范例代码](https://github.com/fatbobman/BlogCodes/tree/main/FetchRequestDemo) 中也提供了这种实现方式，大家可以自行比对。

## 新的问题

细心的朋友应该可以注意到，运行解决方案一的代码后，在第一次点击 bottom 按钮时，大概率会出现延迟情况（并不会立即开始滚动）。

![scrollToBottomDelay_2022-04-24_07.40.24.2022-04-24 07_42_06](https://cdn.fatbobman.com/scrollToBottomDelay_2022-04-24_07.40.24.2022-04-24%2007_42_06.gif)

从控制台的打印信息可以得知，通过 scrollTo 滚动到指定的位置，List 会对滚动过程进行优化。通过对视觉的欺骗，仅需实例化少量的子视图即可完成滚动动画（同最初的预计一致），从而提高效率。

由于整个的滚动过程中仅实例化并绘制了 100 多个子视图，对系统的压力并不大，因此在经过反复测试后，首次点击 bottom 按钮会延迟滚动的问题大概率为当前 ScrollViewProxy 的 Bug 所致。

## 解决方案二

在认识到 ScrollViewProxy 以及在 ForEach 中使用 id 修饰符两者的异常表现后，我们只能尝试通过调用底层的方式来获得更加完美的效果。

> 除非没有其他选择，否则我并不推荐大家对 UIKit ( AppKit ) 控件进行重新包装，应使用尽可能微小的侵入方式对 SwiftUI 的原生控件进行补充和完善。

我们将通过 [SwiftUI-Introspect](https://github.com/siteline/SwiftUI-Introspect) 来实现在 List 中滚动到列表两端。

```swift
import Introspect
import SwiftUI
import UIKit

struct ListUsingUIKitToScroll: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default
    )
    private var items: FetchedResults<Item>
    @State var tableView: UITableView?
    var body: some View {
        VStack {
            HStack {
                Button("Top") {
                    // 使用 UITableView 的 scrollToRow 替代 ScrollViewReader 的 scrollTo
                    self.tableView?.scrollToRow(at: IndexPath(item: 0, section: 0), at: .middle, animated: true)
                }.buttonStyle(.bordered)
                Button("Bottom") {
                    self.tableView?.scrollToRow(at: IndexPath(item: items.count - 1, section: 0), at: .bottom, animated: true)
                }.buttonStyle(.bordered)
            }
            List {
                // 无需使用 id 修饰符进行标识定位
                ForEach(items) { item in
                    ItemRow(item: item)
                }
            }
            .introspectTableView(customize: {
                // 获取 List 对应的 UITableView 实例
                self.tableView = $0
            })
        }
    }
}
```

至此我们已经实现了无延迟的进入列表视图，并在首次滚动到列表底部时也没有延迟。

![scrollByUITableView_2022-04-23_19.44.26.2022-04-23 19_46_20](https://cdn.fatbobman.com/scrollByUITableView_2022-04-23_19.44.26.2022-04-23%2019_46_20.gif)

希望 SwiftUI 在之后的版本中能够改善上面的性能问题，这样就可以无需使用非原生方法也能达成好的效果。

> 范例代码还提供了使用 @SectionedFetchRequest 和 section 进行定位的例子。

## 生产中的处理方式

本文为了演示 id 修饰符在 ForEach 中的异常状况以及问题排查思路，创建了一个在生产环境中几乎不可能使用的范例。如果在正式开发中面对需要在 List 中使用大量数据的情况，我们或许可以考虑下述的几种解决思路（ 以数据采用 Core Data 存储为例 ）：

### 数据分页

将数据分割成若干页面是处理大数据集的常用方法，Core Data 对此也提供了足够的支持。

```swift
fetchRequest.fetchBatchSize = 50 
fetchRequest.returnsObjectsAsFaults = true // 如每页数据较少，可直接对其进行惰值填充，进一步提高效率
fetchRequest.fetchLimit = 50 // 每页所需数据量
fetchRequest.fetchOffset = 0 // 逐页变换  count * pageNumber
```

通过使用类似上面的代码，我们可以逐页获取到所需数据，极大地减轻了系统的负担。

### 升降序切换

对数据进行降序显示且仅允许使用者手工滚动列表。系统中的邮件、备忘录等应用均采用此种方式。

由于用户滚动列表的速度并不算快，所以对于 List 来说压力并不算大，系统将有足够的时间构建视图。

对于拥有复杂结构子视图（尺寸不一致、图文混排）的 List 来说，在数据量大的情况下，任何的大跨度滚动（ 例如直接滚动到列表底部 ）都会给 List 造成巨大的布局压力，有不小的滚动失败的概率。如果必须给用户提供直接访问两端数据的方式，动态切换 SortDescriptors 或许是更好的选择。

```swift
@FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default
    )
private var items: FetchedResults<Item>

// 在视图中切换 SortDescriptors
$items.wrappedValue.sortDescriptors = [SortDescriptor(\Item.timestamp,order: .reverse)]
```

### 增量读取

通讯类软件（比如微信）往往采用初期仅显示部分最新数据，向上滚动后采用增量获取数据的方式来减轻系统压力。

* 不使用 @FetchRequest 或 NSFetchResultController 等动态管理方式，用数组来持有数据
* 通过设置 NSPredicate 、NSSortDescription 和 `fetchRequest.fetchLimit`获取若干最新数据，将数据逆向添加入数组
* 在列表显示后率先移动到最底端（取消动画）
* 通过 refreshable 调用下一批数据，并继续逆向添加入数组

用类似的思路，还可以实现向下增量读取或者两端增量读取。

## 总结

相较于 UIKit ，已经推出了 3 年的 SwiftUI 仍有很多的不足。但回首最初的版本，现在我们已经可以实现太多以前无法想象的功能。期盼 6 月的 WWDC 会带来更多的好消息。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
