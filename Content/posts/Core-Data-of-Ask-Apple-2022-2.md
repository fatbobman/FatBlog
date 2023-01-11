---
date: 2022-10-24 08:12
description: Ask Apple 为开发者与苹果工程师创造了在 WWDC 之外进行直接交流的机会。本文对本次活动中与 Core Data 有关的一些问答进行了整理，并添加了一点个人见解。本文为下篇。
tags: Core Data,Ask Apple 2022
title: Ask Apple 2022 中与 Core Data 有关的问答 (下）
image: images/Core-Data-of-Ask-Apple-2022-2.png
---
Ask Apple 为开发者与苹果工程师创造了在 WWDC 之外进行直接交流的机会。本文对本次活动中与 Core Data 有关的一些问答进行了整理，并添加了一点个人见解。本文为下篇。

## Q&A

### 派生属性（ Derived Attributes ）

Q：嗨，能否分享除 `.@count` 之外的“派生属性”的更多语法示例，提前致谢。

A：NSDerivedAttributeDescription 的文档中有一些 [说明](https://developer.apple.com/documentation/coredata/nsderivedattributedescription) 。

> 派生属性的值是从一个或多个其他的属性的值派生而来。通俗地说，就是在创建或修改托管对象实例时，Core Data 将自动为派生属性生成值。值依据预设的派生表达式（ Derived Expression ）并通过其他的属性值计算而来。详细内容请参阅 [如何在 Core Data 中使用 Derived 和 Transient 属性](https://www.fatbobman.com/posts/derivedAndTransient/) 一文。

```responser
id:1
```

### 主程序与扩展程序数据同步

Q：我有一个主应用程序和一个扩展程序，它们都读取相同的 Core Data 数据库。但是，当我在主应用程序中进行更改时，我的扩展程序在重新启动之前不会看到更改。我是通过简单地调用 `NSManagedObjectContext.refreshAllObjects` 来解决这个问题，还是必须用较困难的方法 —— 启用历史跟踪、检测远程更改、合并来自事务的更改、清理事务历史？

A：你应该使用 NSPersistentStore 上的 NSPersistentStoreRemoteChangeNotificationOptionKey 选项启用远程更改通知这一方法。该方法的 Persistent History 部分有助于确保你不会大量重复地从数据库中获取数据，并且仅在你需要的数据发生更改时才刷新。

> 又是一个有关持久化历史跟踪的问题。苹果真应该为该功能提供一个更加清晰的文档。使用 [ Persistent History Tracking Kit ](https://github.com/fatbobman/PersistentHistoryTrackingKit/blob/main/READMECN.md) 可以减少你的开发工作量。

### 如何更新通过文件系统删除的 Core Data 数据的 Spotlight 索引

Q：在使用 Spotlight 索引 Core Data 中的内容时，是否可以指定 Spotlight 索引的存储位置？我有一个基于文档的应用程序（ document based app ），一些文件以及 Core Data 创建的 sqlite 文件被制作成了一个包（ package bundle ）。如果用户在应用程序之外删除文档，例如在 Finder 中，我希望 Spotlight 中的索引与它一起被删除。所以我想如果索引可以存储在包文件夹中，那就可以解决这种情况。有没有办法正确处理这种情况？

A：听起来这是一个有价值的功能建议，鼓励你提交反馈请求！当前，从应用程序中调用 API 是从索引中删除项目的唯一方法。

> 当前 Spotlight 确实无法处理类似的状况。如果用户通过文件系统删除了这些文档（ 不经过应用程序 ），那么除非应用程序可以了解哪个文档被删除了，然后通过 CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers:) 删除属于该文档的索引，否则只能等待这些索引到期后自动从 Spotlight 中消失。参阅 [在 Spotlight 中展示应用中的 Core Data 数据](https://www.fatbobman.com/posts/spotlight/) 了解更多内容。

### @FetchRequest 的性能如何

Q：@FetchRequest 在性能方面是否优于在 ViewModel 的构造方法中通过 fetchRequest 获取数据的方式？

A：在初始数据获取完成后，@FetchRequest 的成本与结果变化的多少有关，而手动重新获取的成本与结果的总数有关。@FetchRequest 包装了一个 NSFetchedResultsController，它没有自己的特殊逻辑。

### 获取数据的方式

Q：我想知道哪种是比较好的方式？

1. 在应用程序中一次性加载 CoreData 数据并将其保存在局部变量中
2. 使用多个 FetchRequests

我目前在 SwiftUI 中使用 UICalendarView 并从 CoreData 中获取数据。可以在 `calendarView(_:decorationFor:)` 方法中通过 fetchRequest 来为日历中的每个日期加载数据吗（ 应该是指第二种方式 ）？还是只使用一个 fetchRequest，然后将数据保存在本地，并通过上述方法访问它（ 应该是指第一种方式 ）？我想知道这里的最佳做法是什么。谢谢！

A：一般来说，不同的视图经常使用不同的获取请求。对于日期范围之类的内容，你可能希望一次获取一批。过长的 I/O 会使您的视图绘图停滞。太短的 I/O 会导致你发出太多的单独请求，这会大大降低效率。 Instruments 的 Core Data 性能工具可以帮助调查什么才是最适合您的方案。

> UICalendarView 是 iOS 16 新增的控件，MultiDatePicker 只实现了它的部分功能。UICalendarView 允许开发者为特定日期添加装饰，使用方法可以参阅 [Getting UIKit's UICalendarView from iOS 16 fully functioning in a SwiftUI app](http://chriswu.com/posts/swiftui/uicalendarview/) 一文。

### 检索 NSAttributedString

Q：我需要将 NSAttributedString 存储在数据库中，并且可以对属性字符串中的任何文本进行搜索。通过创建两个单独的属性，一个包含纯文本字符串，另一个包含属性字符串的 Transformable 数据是否为最好的方法？是否有另一种更好的方式可以不通过两个属性来减少存储的数据量？

A：你使用的正是当前推荐的方式。此外，纯文本属性可以被 Spotlight 索引，方便它们被系统搜索。

> 生成对应数据的纯文本以进行检索，是一种很常见的方式。在某些情况下，即使属性的原始内容为纯文本，也可以通过为其生成标准化版本（ 忽略大小写以及变音符号的版本 ）以提高检索效率。

### 私有上下文

Q：如何配置 Core Data Stack，以便在后台保存更改时，用户可以继续使用应用程序。

A：NSPersistentContainer 可以满足你的需求，你可以使用 viewContext 来驱动与用户交互的 UI，同时通过 newBackgroundContext 方法创建私有上下文，并在其上完成数据的保存。请确保在 viewContext 上开启自动合并更改，以便 backgroundContext 上的更改可以在 viewContext 中自动更新。

> 无论是通过 newBackgroundContext 显式地创建一个私有上下文，还是通过 performBackgroundTask 在一个临时私有上下文中进行操作，都不能在私有上下文中使用从 viewContext 中获取到的托管对象。托管对象是线程绑定的。即使都来自于私有上下文但分属于不同的上下文，它也只能在其对应的上下文中使用。

### 如何从 UserDefaults 转换至 Core Data 

Q：目前，我的应用程序使用 @AppStorage 进行数据持久化。我有三个主要的模型对象，它们被存储在当前设备上。我想切换成 Core Data + CloudKit 的方式。当现有用户打开新应用程序时，如何确保现有的本地 @AppStorage 数据被安全地转换到 Core Data + CloudKit 中？

A：启动时检测 UserDefaults 是否为空，如果不是，则导入 Core Data，然后删除本地的 UserDefaults。

### 异步保存

Q：嗨，将照片数据保存到 Core Data 时使用异步是否有必要？谢谢！

A：你是在问是否应该使用 perform 或 performAndWait？我认为这取决于你的要求和所需的 UX 体验。

> perform 和 performAndWait 分别对应的是在上下文中进行异步/同步操作。对于私有上下文，即使使用 performAndWait 通常也不会对 UI 造成影响。

### 数据模型源文件（ Class/Category/Manual ）

Q：我希望获得与 Core Data 模型实体生成（ Codegen ）种类有关的指导。例如，什么情况下应该使用手动？我也不确定 Category/Extension 的作用以及如何在它和 Class 之间进行选择？

A：大多数人会使用 Class，并在他们自己的托管对象扩展中添加他们需要的任何自定义方法。但是在极少数情况下，例如你需要添加必须在类定义中声明的属性，此时应使用 Category/Extension 使你可以控制所需的类声明。

> 在早期的 Xcode 版本中，使用 Class 模式会生成两个文件，xxx+CoreDataClass.swift 和 xxx+CoreDataProperties.swift 。xxx+CoreDataProperties.swift 中是通过扩展为 Entity 的属性创建的声明，xxx+CoreDataClass.swift 是类的定义。而 Category/Extension 模式只会生成 xxx+CoreDataProperties.swift ，也就是说用户需要自己来写类的定义。不过在新版的 Xcode（ 至少从版本 13 起 ）中，两者之间已经没有区别了。都会生成两个文件，而且如果用户在类的定义中添加了自定义属性，Xcode 也不会在重新生成的代码中对其进行覆盖。当生成文件后，需要将 Entity 切换成 Manual /None 模式，否则 Xcode 会出现类型重复声明的错误（ Xcode 中还会有另一份 Entity 定义保存在项目内部 ），如果仍无法编译，应清空编译缓存。

### 通过 CloudKit Dashboard 删除数据

Q：一个与 Core Data 与 CloudKit 同步的问题。我注意到，当我使用 Safari 客户端从 CloudKit 数据库中删除一条记录时（ 通过 CloudKit Dashboard ），该对象仍会保留在设备上的 Core Data 数据存储中。这是有意为之的吗？如何在 CloudKit 管理器与设备之间同步这些更改？谢谢！

A：尚不清楚此工作流程是否会向 NSPersistentCloudKitContainer 生成推送通知。如果你重新启动应用程序，应该会看到更改。

```responser
id:1
```

### 如何确定是否已同步完成

Q：我正在使用 NSPersistentCloudKitContainer，并想改善设备初次从 iCloud 上下载数据时的用户体验。有没有办法告诉用户数据已完成同步？我知道 NSPersistentCloudKitContainer.eventChangedNotification，但它似乎没有真正的方式来告诉应用同步何时完成。

A：其他设备总是可能做出无穷无尽的新变化，你能做的是查看哪些导入已启动及其完成状态。欢迎向我们提交功能需求的 FB。（ The theoretical is intractable, the other devices can always be making an infinite stream of new changes, Seeing which imports have been kicked off and their completion status is the best you can do, But you could file a feedback for an enhancement for an approximate answer ）

> 苹果的工程师没有对此进行正面回答。有关同步进度的问题，无论是 WWDC、开发者论坛还是在本次 Ask Apple 上都被多次提及，但直到目前，尚没有好的解决方案。我的建议是，在应用中（ 尤其是首次启动时 ），在同步处于 import 状态时（ 通过 eventChangedNotification 获得 ）应对用户给予提示（ 使用 ProgressView 之类的动态元素 ）。Core Data with CloudKit 的同步机制会将同步过程分多次进行。也就是说，对于首次同步来说，import 状态很可能会多次出现（ 无法通过 import 状态发生转变来判断导入结束 ）。通过导入状态提示，可以在一定程度上减轻用户的疑惑。另外可以考虑使用 CloudKit API 查询云端的数据条数，然后与已经同步到本地的记录数进行比对，获得大致的同步进度（ 此方式仅适用于数据模型简单，关系不太复杂的情况 ）。

### 实体属性的可选性

Q：Core Data 中实体属性的可选性表现与预期不一致。如果我将某个属性标记为可选，则该属性不应具有默认值，并且托管属性应始终为可选属性。如果我将其标记为非可选，则它应该需要默认值，并且托管属性应始终是非可选的。我们是否可以期待将来（ 至少在新项目中 ）做出这样的修正？

A：Core Data 的可选性理念早于 Swift 的存在，允许属性暂时无效。例如，当你创建一个带有字符串属性的新对象时，初始值（ 在没有默认值的情况下 ）是 nil，这在对象被验证之前（ 通常在 save 时 ）是没有问题的。在可选标量的情况下，Core Data 受限于 Objective-C 中可表达的类型限制（ 例如没有 Int64 这样的类型，可选的类型只能表达为 NSNumber ）。就这一想法提交反馈报告可能是你最好的选择。

> 实体属性的可选性对于 Core Data 的初学者来说是一个容易困惑的地方。即使你在模型编辑器中将属性（ 例如字符串 ）标记为非可选（ 设定了默认值 ），但在从托管对象获取属性值的时候，返回值仍会是 `Optional<String>` 类型。对于上面的问题，可以考虑如下的解决方法：1、对于某些类型的属性来说，可以通过手动定义（ 或修改 Xcode 生成的 subclass 源文件 ），将生成代码中的类型 String? 改成 String；2、声明一个非可选值的计算属性，并在其中对可选值属性值进行处理；3、将托管对象实例整体转换成对 SwiftUI 视图更加友好的值类型。

### 数据手动排序

Q：在我的应用程序中，用户可以在表视图中通过拖放来重新排列项目。我的数据模型中有一个 Int16 类型的 userOrder 属性，在表视图的行被重新排序后，有什么好的方法来保存数据的新顺序？

A：与其使用 userorder == 0 存储第一个对象，使用 userOrder == 1 存储第二个对象，使用 userOrder == 2 存储第三个对象，或许将其建模为一种有序的关系（ ordered ）是更好的选择。让 Core Data 为你做这件事。为了管理有序的关系，Core Data 在 UInt16 空间中计算一个对象的索引，正好在前一个和后一个对象的中间。当整数空间用完时，将在任何一个方向上跨出一个对象，并均匀地重新分配这些对象。

> 很遗憾，有序关系无法在开启 Core Data 云同步的状态下使用，在此种情况下，提问者当前的做法应该是正确的选择。

### 筛选关系数据

Q：我发现在 SwiftUI 中使用 @FetchRequest 是将用户界面与 Core Data 数据绑定很好的手段。然而，在使用关系来获得同样的无缝绑定时，我碰到了一个小问题。由于 NSManagedObjects 以 NSSet 的形式表示一对多的关系，我必须在它自己的 @FetchRequest 中重新获取 “子女”（ 多方的数据 ），从而失去 Core Data 关系属性的好处。我的方法有什么问题？

A：这听起来与另一个问题相似，我在这个问题中建议使用谓词来过滤只具有某种关系的对象。我想同样的方法应该对你有用？让 Core Data 通过构建一个谓词来完成过滤工作会更快，比如 `NSPredicate(format: "country = %@", country)`。

> NSManagedObject 符合 ObservableObject 协议，这意味着当它的属性值发生变化时将会通过 Publisher 通知订阅者。遗憾的是，可监控的变化中并不包括关系对象中的属性值变化。通过谓词重新获取关系对象列表可能是目前最好的方式。另外，Antoine van der Lee 曾写过一篇通过扩展 NSFetchedResultsController 来实现监控关系对象属性变化的文章 [NSFetchedResultsController extension to observe relationship changes](https://www.avanderlee.com/swift/nsfetchedresultscontroller-observe-relationship-changes/) 。

### 在持久化历史中如何体现有序对象的变化状态

Q：持久化历史中是如何体现 “有序” 关系中的对象的顺序发生了改变？NSPersistentHistoryChange 是否包含父实体或子实体？updatedProperties 中有哪些属性？

A：对于排序的改变，关系的两边都会显示为 NSPersistentHistoryChange，并在 updatedProperties 中列出关系。

### 通过 navigationDestination 传递托管对象的需求

Q：我有一个与 SwiftUI 的 navigationDestination(for: myCoreDataClass) 有关的问题，需要让我的 NSManagedObjects 中符合 Codable 协议（ 猜测是想对 Path 进行持久化 ）。我手动生成了 NSManagedObject 代码并实现了 Codable 协议来实现这一目标。有什么更好的处理方法吗？谢谢。

A：Codable 无法准确地对对象图中的对象进行单独编码。相反，你应该创建一个适合于此处需求的数据子集的可编码转换。或许可以使用 URIRepresentation 。

> 当 NSManagedObject 包含关系时，对其进行编码是极为困难的。navigationDestination 对传入数据的唯一要求是符合 Hashable 协议，因此传入托管对象 ID 对应的 URL 应该是最佳的选择（ 通过 `objectID.uriRepresentation`，URL 符合 Codable 协议，满足对 Path 进行持久化的需求 ）。

## 总结

在上下两篇问答汇总中，我忽略掉了没有获得结论的问题。希望上述的整理能够对你有所帮助。

欢迎通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ) 或博客的留言板与我进行交流。

> 我正以聊天室、Twitter、博客留言等讨论为灵感，从中选取有代表性的问题和技巧制作成 Tips ，发布在 Twitter 上。每周也会对当周博客上的新文章以及在 Twitter 上发布的 Tips 进行汇总，并通过邮件列表的形式发送给订阅者。

**订阅下方的 [邮件列表](https://artisanal-knitter-2544.ck.page/d3591dd1e7)，可以及时获得每周的 Tips 汇总。**
