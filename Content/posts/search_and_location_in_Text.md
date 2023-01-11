---
date: 2022-08-23 08:12
description: 前些日子，一位网友在聊天室中就如何通过 Text + AttributedString 实现类似文章关键字检索的功能，并可通过按钮在搜索结果中进行滚动切换的问题与大家进行了交流与探讨。考虑到这个问题对于 SwiftUI 的应用来说比较新颖，且涉及不少博客中介绍过的知识，因此我对聊天室原本给出的解决方案进行了重新整理，并通过本文对解决思路、方法手段以及注意事项等内容与大家进行探讨。
tags: SwiftUI
title: 在 Text 中实现基于关键字的搜索和定位
image: images/search_and_location_in_Text.png
---
前些日子，一位网友在聊天室中就如下的 [问题](https://discord.com/channels/967978112509935657/967978112509935663/999357869591908382) 与大家进行了交流与探讨 —— 如何通过 Text + AttributedString 实现类似文章关键字检索的功能，并可通过按钮在搜索结果中进行滚动切换？

![Fae3VkfVUAAFzqB](https://cdn.fatbobman.com/Fae3VkfVUAAFzqB.jpeg)

![Fae3VkkVUAAga7w](https://cdn.fatbobman.com/Fae3VkkVUAAga7w.jpeg)

考虑到这个问题对于 SwiftUI 的应用来说比较新颖，且涉及不少博客中介绍过的知识，因此我对聊天室原本给出的解决方案进行了重新整理，并通过本文对解决思路、方法手段以及注意事项等内容与大家进行探讨。

> 可在此获取本文提供的 [范例代码](https://github.com/fatbobman/BlogCodes/tree/main/ShowKeywordsInText) ，开发环境为 Xcode 14 beta 5

```responser
id:1
```

## 问题关键点

* 在分散的数据中进行关键字查询，并记录搜索结果

提问者给出的数据格式如下：

```swift
struct Transcription: Equatable, Identifiable {
    let id = UUID()
    let startTime: String
    var context: String
}

let transcriptions: [Transcription] = [
    .init(startTime: "06:32", context: "张老三，我问你，你的家乡在哪里"),
    .init(startTime: "08:42", context: "我的家，在山西，过河还有三百里"),
]
```

* 对搜索结果进行高亮显示（ 实时响应 ）

![realtim_hightlight_2022-08-22_09.16.25.2022-08-22 09_17_38](https://cdn.fatbobman.com/realtim_hightlight_2022-08-22_09.16.25.2022-08-22%2009_17_38.gif)

* 通过按钮实现搜索结果的切换

![image-20220822084740855](https://cdn.fatbobman.com/image-20220822084740855.png)

* 切换搜索结果时可自动定位到结果所在的位置

* 点击非当前高亮关键字，会自动将其设置为当前高亮关键字并滚动至视图中心位置

![scrollTo_keyword2_2022-08-22_09.06.20.2022-08-22 09_07_57](https://cdn.fatbobman.com/scrollTo_keyword2_2022-08-22_09.06.20.2022-08-22%2009_07_57.gif)

* 在对话数据较多的情况下（上千条）不应有性能瓶颈

## 解决思路

一千个人眼中有一千个哈姆雷特。本节的内容仅代表我在考虑处理上述问题时的想法和思路。其中不少功能已经超出了原本的需求，增加这些功能一方面有利于更多地融汇以前博客中的知识点，另一方面也提高了解题的乐趣。

### 搜索关键字

通过正则表达式获取到所有满足查询条件的信息。

* 通过 Regex 创建正则表达式

近两年，苹果逐步为 Foundation 添加越来越多的 Swift 原生实现。在去年增加了 AttributedString 和 FormatStyle 后，今年又增加了 Swift 版本的正则表达式实现 —— Regex。

对于当前的问题，我们首先要通过关键字创建在 transcription（ 录音转文字 ）中进行搜索的正则表达式：

```swift
let regex = Regex<AnyRegexOutput>(verbatim: keyword).ignoresCase()

// 相当于
let regex = try! NSRegularExpression(pattern: keyword, options: [.caseInsensitive,.ignoreMetacharacters])
```

verbatim 将保证不会将关键字中的特殊字符当作正则参数，ignoresCase 意味着将创建忽略大小写的正则表达式。

* 通过 ranges(of regex:) 获取匹配区间

使用 Swift 为字符串新增的正则方法，可以快速获取查询所需的信息：

```swift
for transcription in transcriptions {
    let ranges = transcription.context.ranges(of: regex) ranges
    for range in ranges {
       ...
    }
}
```

鉴于我们仅需要匹配的区间，因此使用了 ranges 方法。使用 matches 可以获得更加丰富的信息。

* 为定位及智能高亮保存更多数据

为了方便之后的搜索结果显示和定位，每次搜索均需记录如下的信息 —— 搜索结果总数量、当前高亮的结果位置、包含搜索结果的 transcription、每个 transcrption 中符合条件的 range 以及在搜索结果中的序号（ 位置 ）。为了方便其他的条件判断，我们又分别以满足条件的 transcription ID 和 position 为键，创建了两个辅助字典。

```swift
@Published var count: Int // 结果数量
@Published var rangeResult: [UUID: [TranscriptionRange]] // 搜索结果 transcription.id : 结果区间和序号
@Published var currentPosition: Int? // 当前的高亮位置
@Published var positionProxy: [Int: UUID] // 结果序号 : transcription.id
var positionProxyForID: [UUID: [Int]] = [:] // transcription.id : [结果序号]

struct TranscriptionRange {
    let position: Int
    let range: Range<String.Index>
}
```

### 高亮显示

在 Transcription 的显示视图 TranscriptionRow 中，通过 AttributedString 对结果进行高亮显示。

> 请阅读 [AttributedString——不仅仅让文字更漂亮](https://www.fatbobman.com/posts/attributedString/) 了解更多有关 AttributedString 的内容

* 将 `Range<String.Index>` 转换成 `AttributedString.Index`

通过字符串的 ranges 方法获取的结果类型是 `Range<String.Index>`，因此我们需要将其转换成 `AttributedString.Index` ，才能用于 AttributedString：

```swift
var text = AttributedString(transcription.context)
let lowerBound = AttributedString.Index(transcriptionRange.range.lowerBound, within: text)
let upperBound = AttributedString.Index(transcriptionRange.range.upperBound, within: text)
```

* 通过 AttributedString 的下标方法对区间进行高亮显示设置

```swift
if ranges.currentPosition == transcriptionRange.position {
    text[lowerBound..<upperBound].swiftUI.backgroundColor = currentHighlightColor
    if bold {
        text[lowerBound..<upperBound].foundation.inlinePresentationIntent = .stronglyEmphasized
    }
} else {
    text[lowerBound..<upperBound].swiftUI.backgroundColor = highlightColor
}
```

改变所有满足查询条件的内容背景色。对当前的选择位置，使用更加明亮的颜色并标注粗体。

![image-20220822161247454](https://cdn.fatbobman.com/image-20220822161247454.png)

### 点击切换按钮定位到对应的搜索结果

为 TranscriptionRow 视图添加显式标识符，并通过 ScrollViewProxy 滚动到指定的位置。

* 通过 id 修饰器为 transcription 添加定位信息

```swift
List(0..<store.transcriptions.count,id:\.self) { index in
    let transcription = store.transcriptions[index]
    TranscriptionRow()
    .id(transcription.id)
}
```

当为 ForEach （ 上面的代码使用了隐式 ForEach 形式 ）中的 View 添加显式标识符后（ 使用 id 修饰器），在视图刷新时，List 将会为 ForEach 中的所有视图创建实例（ 并非渲染 ）用以比对视图类型的构造参数是否发生变化，但仍然只会渲染屏幕上显示部分的 Row 视图。

因此，在本例中，我们舍弃了通过构造参数为 TranscriptionRow 传递搜索结果的方式，采用了在 TranscriptionRow 中引入符合 DynamicProperty 协议的  Source of Truth 。这样在搜索结果变化时，仅有当前显示的 TranscriptionRow 会重新计算并渲染（ 如果没有添加 id，通过构造参数传递搜索，对改善性能会更有帮助 ）。

> 请阅读 [优化在 SwiftUI List 中显示大数据集的响应效率](https://www.fatbobman.com/posts/optimize_the_response_efficiency_of_List/) 以及 [避免 SwiftUI 视图的重复计算](https://www.fatbobman.com/posts/avoid_repeated_calculations_of_SwiftUI_views/) 两篇文章，了解更多有关性能优化方面的内容

* 通过 currentPostion 获取需要滚动到的 transcriptionID

由于滚动定位是根据 transcription ID 来实现的，因此，我们需要将搜索结果的位置序号转换成对应的 transcription ID：

```swift
var currentID: UUID? { // 当前高亮所在的 transcription ID ，用于 scrollTo
    guard let currentPosition else { return nil }
    return positionProxy[currentPosition]
}
```

* 通过 onChange 比较 transcriptionID 变化的前后值，减少不必要的滚动

考虑到使用者的阅读感受，我希望如果当前定位的 transcription 中的结果值已经为高亮显示值（ 当前选择的高亮位置 ），且下一个序号位置仍在同一个 transcription 中，那么将放弃滚动。通过在 onChange 的闭包中将新值与保存的旧值进行比对，可以实现上述目标。

```swift
.onChange(of: store.currentPosition) { [lastID = store.currentID] _ in
    let currentID = store.currentID
    if lastID != currentID {
        withAnimation {
            scrollProxy.scrollTo(currentID, anchor: .center)
        }
    }
}

func gotoPrevious() {
    if let currentPosition, currentPosition > 0 {
        self.currentPosition = currentPosition - 1
    }
}

func gotoNext() {
    if let currentPosition, currentPosition < count - 1 {
        self.currentPosition = currentPosition + 1
    }
}
```

没有比较新旧值的情况：

![avoid_scroll_without_compare_2022-08-22_17.30.10.2022-08-22 17_31_07](https://cdn.fatbobman.com/avoid_scroll_without_compare_2022-08-22_17.30.10.2022-08-22%2017_31_07.gif)

比较了新旧值，避免不必要的滚动：

![avoid_scroll_with_compare_2022-08-22_17.28.56.2022-08-22 17_32_23](https://cdn.fatbobman.com/avoid_scroll_with_compare_2022-08-22_17.28.56.2022-08-22%2017_32_23.gif)

> 阅读 [了解 SwiftUI 的 onChange](https://www.fatbobman.com/posts/onChange/) 一文，了解更多有关 onChange 的内容

### 搜索关键字改变后有条件重新定位

* 如果当前的高亮位置仍能满足条件不发生滚动

```swift
/// 以当前选中的关键字为优先
private func getCurrentPositionIfSubRangeStillExist(oldRange: [UUID: [TranscriptionRange]], newRange: [UUID: [TranscriptionRange]], keyword: String, oldCurrentPosition: Int?) -> Int? {
    if let oldResult = oldRange.lazy.first(where: { $0.value.contains(where: { $0.position == oldCurrentPosition }) }),
       let oldRange = oldResult.value.first(where: { $0.position == oldCurrentPosition })?.range,
       let newResult = newRange.lazy.first(where: { $0.key == oldResult.key && $0.value.contains(where: { oldRange.overlaps($0.range) || $0.range.overlaps(oldRange) }) }),
       let newPosition = newResult.value.first(where: { oldRange.overlaps($0.range) })?.position
    {
        return newPosition
    } else {
        let nearPosition = getCurrentPositionIfInOnScreen()
        return nearPosition ?? nil
    }
}
```

![keep_in_single_hightlight_keyword_2022-08-22_17.42.13.2022-08-22 17_42_52](https://cdn.fatbobman.com/keep_in_single_hightlight_keyword_2022-08-22_17.42.13.2022-08-22%2017_42_52.gif)

* 优先定位于当前屏幕正在显示的 transcription

将搜索结果优先定位于 List 当前显示的 transcription 中。如果当前显示的 transcription 无法满足条件，才会定位到第一个满足条件的结果位置。

为了达成这个目标，我们首先需要记录在 List 中，哪些 transcription 正在被显示，以及该 transcription 的索引。通过 onAppear 和 onDisappear 即可达成此目的：

```swift
var onScreenID: [UUID: Int] = [:] // 当前屏幕中正显示的 transcription ID

List(0..<store.transcriptions.count, id: \.self) { index in
    let transcription = store.transcriptions[index]
    TranscriptionRow()
    .onAppear { store.onScreenID[transcription.id] = index }
    .onDisappear { store.onScreenID.removeValue(forKey: transcription.id) }
    .id(transcription.id)
}
```

> 在 List 中，每个视图进入显示窗口时都会调用它的 onAppear，每个视图退出显示窗口时都会调用它的 onDisapper。了解更多内容，请阅读 [SwiftUI 视图的生命周期研究](https://www.fatbobman.com/posts/swiftUILifeCycle/) 一文

优先定位于最靠近屏幕中央的搜索结果：

```swift
/// 从 List 当前显示中的 transcription 中就近选择 match 的 position
private func getCurrentPositionIfInOnScreen() -> Int? {
    guard let midPosition = Array(onScreenID.values).mid() else { return nil }
    let idList = onScreenID.sorted(by: { (Double($0.value) - midPosition) < (Double($1.value) - midPosition) })
    guard let id = idList.first(where: { positionProxyForID[$0.key] != nil })?.key, let position = positionProxyForID[id] else { return nil }
    guard let index = transcriptions.firstIndex(where: { $0.id == id }) else { return nil }
    if Double(index) >= midPosition {
        return position.first
    } else {
        return position.last
    }
}
```

![locate_onScreen_2022-08-22_17.49.52.2022-08-22 17_50_35](https://cdn.fatbobman.com/locate_onScreen_2022-08-22_17.49.52.2022-08-22%2017_50_35.gif)

```responser
id:1
```

### 点击搜索结果切换当前选择

点击非选择中的搜索结果，将其设置为当前的选择

![openURL_2022-08-22_18.08.13.2022-08-22 18_18_17](https://cdn.fatbobman.com/openURL_2022-08-22_18.08.13.2022-08-22%2018_18_17.gif)

* 通过 AttributedString 的 link 属性，添加定位信息

```swift
let positionScheme = "goPosition" // 自定义 Schmem

text[lowerBound..<upperBound].link = URL(string: "\(positionScheme)://\(transcriptionRange.position)")
```

* 使用 OpenURLAction 完成重定位操作

```swift
List(0..<store.transcriptions.count, id: \.self) { index in
   ...
}
.environment(\.openURL, OpenURLAction { url in
    switch url.scheme {
    case positionScheme:
        if let host = url.host(), let position = Int(host) {
            store.scrollToPosition(position)
        }
        return .handled
    default:
        return .systemAction
    }
})

@MainActor
func scrollToPosition(_ position: Int) {
    if position >= 0, position < count - 1 {
        self.currentPosition = position
    }
}
```

> 阅读 [在 SwiftUI 视图中打开 URL 的若干方法](https://www.fatbobman.com/posts/open_url_in_swiftUI/) 一文，了解更多有关 OpenURLAction 的内容

### 创建体验感优秀的搜索条

* 使用 safeAreaInset 添加搜索栏

在没有 safeAreaInset 修饰器的时候，我们通常会用两种方式添加搜索栏 —— 1、通过 VStack 将搜索栏放置在 List 下方，2、使用 overlay 将搜索栏放置在 List 视图的上层。但是如果采用 overlay 的方式，搜索栏将会挡住 List 最下方的记录。使用 safeAreaInset ，我们可以将搜索栏的区域设置为 List 下方的安全区域，这样既可以实现类似 Tab 覆盖 List 的效果，同时也不会遮盖 List 最下方的数据。

> 阅读 [掌握 SwiftUI 的 Safe Area](https://www.fatbobman.com/posts/safeArea/) 一文，了解更多有关 safeAreaInset 修饰器的内容

![safeArea_2022-08-22_18.24.59.2022-08-22 18_25_53](https://cdn.fatbobman.com/safeArea_2022-08-22_18.24.59.2022-08-22%2018_25_53.gif)

* 在搜索条出现时，让 TextField 获得焦点

通过 @FocusState ，让 TextField 在搜索条出现时，自动获得焦点，从而自动开启键盘。

> 阅读 [SwiftUI TextField 进阶 —— 事件、焦点、键盘](https://www.fatbobman.com/posts/textfield-event-focus-keyboard/) 一文，了解更多有关焦点的内容

```swift
@FocusState private var focused: Bool
TextField("查找", text: $store.keyword)
    .focused($focused)
    .task {
        focused = true
    }
```

### 减少因实时搜索造成的性能负担

在当前的案例中，实时响应关键字并进行搜索，会给性能造成很大的负担。我们需要采用如下方式避免因此而导致的应用卡顿：

* 确保搜索操作运行于后台线程
* 过滤关键字响应，避免因为输入太快导致的无效搜索操作

我们通常会在 Combine 中采用 `.subscribe(on: )` 来设定之后的 operator 操作线程。在范例代码中，我使用了 [聊聊 Combine 和 async/await 之间的合作](https://www.fatbobman.com/posts/combineAndAsync/) 一文中介绍的方法，通过自定义 Publisher ，将 async/await 方法嵌入到 Combine 的操作管道中，以实现同样的效果。

```swift
public extension Publisher {
    func task<T>(maxPublishers: Subscribers.Demand = .unlimited,
                 _ transform: @escaping (Output) async -> T) -> Publishers.FlatMap<Deferred<Future<T, Never>>, Self> {
        flatMap(maxPublishers: maxPublishers) { value in
            Deferred {
                Future { promise in
                    Task {
                        let output = await transform(value)
                        promise(.success(output))
                    }
                }
            }
        }
    }
}

public extension Publisher where Self.Failure == Never {
    func emptySink() -> AnyCancellable {
        sink(receiveValue: { _ in })
    }
}

cancellable = $keyword
    .removeDuplicates()
    .throttle(for: .seconds(0.1), scheduler: DispatchQueue.main, latest: true) // 使用 debounce 可能会漏掉 keyword 的最终变化
    .task(maxPublishers: .max(1)) { keyword in
        await self.search(keyword: keyword)
    }
    .emptySink()
```

同时，通过 `flatMap(maxPublishers: .max(1))` 、`removeDuplicates` 和 `throttle` 进一步限制在单位时间内的所能进行的搜索次数，以保证应用的流畅度。

## 总结

范例代码并没有十分刻意地创建规范的数据流，但由于做到视图与数据分离，因此将其改写成任何你想使用的数据流方式并非难事。

尽管仅在搜索和 TranscriptionRow 视图注入两处对性能做了部分优化，但最终的流畅度已基本满足需求，也从侧面证明了 SwiftUI 具备了相当的实战能力。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。

> 从本周开始我将以聊天室、Twitter、博客留言等讨论为灵感，从中选取有代表性的问题和技巧制作成 Tips ，发布在 Twitter 上。每周也会对当周博客上的新文章以及在 Twitter 上发布的 Tips 进行汇总，并通过邮件列表的形式发送给订阅者。

**订阅下方的 [邮件列表](https://artisanal-knitter-2544.ck.page/d3591dd1e7)，可以及时获得每周的 Tips 汇总。**
