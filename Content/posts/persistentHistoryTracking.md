---
date: 2021-07-27 12:00
description: 本文介绍了 CoreData 的 Persistent History Tracking 功能。详细讲解了从响应、提取、合并到清除的全过程处理方式，并提供了演示代码供读者使用。
tags: Core Data
title: 在 CoreData 中使用持久化历史跟踪
---
## 前言 ##

> **2022年2月更新**：我已经重写了代码，并将其整理成库 [PersistentHistoryTrackingKit](https://github.com/fatbobman/PersistentHistoryTrackingKit) 以方便大家使用。

知道持久化历史跟踪功能已经有一段时间了，之前简单地浏览过文档但没有太当回事。一方面关于它的资料不多，学习起来并不容易；另一方面也没有使用它的特别动力。

在计划中的 [【健康笔记 3】](/healthnotes/) 中，我考虑为 App 添加 Widget 或者其他的 Extentsion，另外我也打算将 WWDC21 上介绍的 NSCoreDataCoreSpotlightDelegate 用到 App 的新版本中。为此就不得不认真地了解该如何使用持久化历史跟踪功能了。

```responser
id:1
```

## 什么是持久化历史跟踪（Persistent History Tracking） ##

> 使用持久化历史跟踪（Persistent History Tracking）来确定自启用该项功能以来，存储（Store）中发生了哪些更改。 —— 苹果官方文档

在 CoreData 中，如果你的数据保存形式是 Sqlite（绝大多数的开发者都采用此种方式）且启用了持久化历史跟踪功能，无论数据库中的数据有了何种变化（删除、添加、修改等），调用此数据库并注册了该通知的应用，都会收到一个数据库有变化的系统提醒。

## 为什么要使用它 ##

持久化历史跟踪目前主要有以下几个应用的场景：

* 在 App 中，将 App 的批处理（BatchInsert、BatchUpdate、BatchDelete）业务产生的数据变化合并到当前的视图上下文（ViewContext）中。

  批处理是直接通过协调器（PersistentStoreCoordinator）来操作的，由于该操作并不经过上下文（ManagedObejctContext），因此如果不对其做特别的处理，App 并不会及时的将批处理导致的数据变化在当前的视图上下文中体现出来。在没有 Persistent History Tracking 之前，我们必须在每个批处理操作后，使用例如`mergeChanegs`将变化合并到上下文中。在使用了 Persistent History Tracking 之后，我们可以将所有的批处理变化统一到一个代码段中进行合并处理。

* 在一个 App Group 中，当 App 和 App Extension 共享一个数据库文件，将某个成员在数据库中做出的修改及时地体现在另一个成员的视图上下文中。

  想象一个场景，你有一个汇总网页 Clips 的 App，并且提供了一个 Safari Extentsion 用来在浏览网页的时候，将合适的剪辑保存下来。在 Safari Extension 将一个 Clip 保存到数据库中后，将你的 App（Safari 保存数据时，该 App 已经启动且切换到了后台）切换到前台，如果正在显示 Clip 列表，最新的（由 Safari Extentsion 添加）Clip 并不会出现在列表中。一旦启用了 Persistent History Tracking，你的 App 将及时得到数据库发生变化的通知、并做出响应，用户便可以在第一时间在列表中看到新添加的 Clip。

* 当使用 PersistentCloudKitContainer 将你的 CoreData 数据库同 Cloudkit 进行数据同步时。

  Persistent History Tracking 是实现 CoreData 同 CloudKit 数据同步的重要保证。无需开发者自行设定，当你使用 PersistentCloudKitContainer 作为容器后，CoreData 便已经为你的数据库启用了 Persistent History Tracking 功能。不过除非你在自己的代码中明确声明启用持久化历史跟踪，否则所有网络同步的数据变化都并不会通知到你的代码，CoreData 会在后台默默地处理好一切。

* 当使用 NSCoreDataCoreSpotlightDelegate 时。

  在今年的 WWDC2021 上，苹果推出了 NSCoreDataCoreSpotlightDelegate，可以非常便捷的将 CoreData 中的数据同 Spotlight 集成到一起。为了使用该功能，必须为你的数据库开启 Persistent History Tracking 功能。

## Persistent History Tracking 的工作原理 ##

为持久化存储启用 Persistent History Tracking 后，你的应用程序将开始为 Core Data 的持久化存储中发生的任何更改创建事务记录（ Transaction ）。无论该事务是由何种方式（通过上下文还是不经过上下文）产生的，由那个 App 或 Extension 产生，都将事无巨细的记录下来。

所有的变化都会被保存在你的 Sqlite 数据库文件中，苹果在 Sqlite 中创建了几个表，用来记录了 Transaction 对应的各类信息。

![image-20210727092416404](https://cdn.fatbobman.com/image-20210727092416404-7349058.png)

苹果并没有公开这些表的具体结构，不过我们可以使用 Persistent History Tracking 提供的 API 来对其中的数据进行查询、清除等工作。

> 如果有兴趣也可以自己看看这几个表的内容，苹果将数据组织的非常紧凑的。`ATRANSACTION`中是尚未消除的 transaction，`ATRANSACTIONSTRING`中是 author 和 contextName 的字符串标识，`ACHANGE`是变化的数据，以上数据最终转换成对应的 ManagedObjectID。

Transaction 将按照产生顺序被自动记录。我们可以检索特定时间后发生的所有更改。你可以通过多种表达方式来确定这个时间点：

* 基于令牌（Token）
* 基于时间戳（Timestamp）
* 基于交易本身（Transaction）

一个基本的 Persistent History Tracking 处理流程如下：

1. 响应 Persistent History Tracking 产生的 NSPersistentStoreRemoteChange 通知
2. 检查从上次处理的时间戳后是否仍有需要处理的 Transaction
3. 将需要处理的 Transaction 合并到当前的视图上下文中
4. 记录最后处理的 Transaction 时间戳
5. 择机删除已经被合并的 Transaction

## App Groups ##

在继续聊 Persisten History Tracking 之前，我们先介绍一下 App Groups。

由于苹果对 App 采取了严格的沙盒机制，因此每个 App，Extension 都有其自己的存储空间。它们只能读取自己沙盒文件空间的内容。如果我们想让不同的 App，或者在 App 和 Extension 之间共享数据的话，在 App Groups 出现之前只能通过一些第三方库来进行简单的数据交换。

为了解决这个问题，苹果推出了自己的解决方案 App Groups。App Group 让不同的 App 或者 App&App Extension 之间可以通过两种方式来共享资料（必须是同一个开发者账户）：

* UserDefauls
* Group URL（Group 中每个成员都可以访问的存储空间）

绝大多数的 Persistent History Tracking 应用场合，都是发生在启用了 App Group 的情况下。因此了解如何创建 App Grups、如何访问 Group 共享的 UserDefaults、如何读取 Group URL 中的文件非常有必要。

### 让 App 加入 App Groups ###

在项目导航栏中，选择需要加入 Group 的 Target，在 Signing&Capabilities 中，点击`+`，添加 App Group 功能。

![image-20210726193034435](https://cdn.fatbobman.com/image-20210726193034435-7299035.png)

在 App Groups 中选择或者创建 group

![image-20210726193200091](https://cdn.fatbobman.com/image-20210726193200091-7299122.png)

*只有在 Team 设定的情况下，Group 才能被正确的添加。*

App Group Container ID 必须以`group.`开始，后面通常会使用逆向域名的方式。

如果你有开发者账号，可以在 App ID 下加入 App Groups

![image-20210726193614636](https://cdn.fatbobman.com/image-20210726193614636-7299375.png)

其他的 App 或者 App Extension 也都按照同样的方式，指定到同一个 App Group 中。

### 创建可在 Group 中共享的 UserDefaults ##

```swift
public extension UserDefaults {
    /// 用于 app group 的 userDefaults, 在此处设定的内容可以被 app group 中的成员使用
    static let appGroup = UserDefaults(suiteName: "group.com.fatbobman.healthnote")!
}
```

`suitName`是你在前面创建的 App Group Container ID

在 Group 中的 App 代码中，使用如下代码创建的 UserDefaults 数据，将被 Group 中所有的成员共享，每个成员都可以对其进行读写操作

```swift
let userDefaults = UserDefaults.appGroup
userDefaults.set("hello world", forKey: "shareString")
```

### 获取 Group Container URL ###

```swift
 let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.fatbobman.healthnote")!
```

对这个 URL 进行操作和对于 App 自己沙盒中的 URL 操作完全一样。Group 中的所有成员都可以在该文件夹中对文件进行读写。

> 接下来的代码都假设 App 是在一个 App Group 中，并且通过 UserDefaults 和 Container URL 来进行数据共享。

## 启用持久化历史跟踪 ##

启用 Persistent History Tracking 功能非常简单，我们只需要对 NSPersistentStoreDescription`进行设置即可。

以下是在 Xcode 生成的 CoreData 模版`Persistence.swift`中启用的例子：

```swift
   init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "PersistentTrackBlog")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        // 添加如下代码：
        let desc = container.persistentStoreDescriptions.first!
        // 如果不指定 desc.url 的话，默认的 URL 当前 App 的 Application Support 目录
        // FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        // 在该 Description 上启用 Persistent History Tracking
        desc.setOption(true as NSNumber,
                       forKey: NSPersistentHistoryTrackingKey)
        // 接收有关的远程通知
        desc.setOption(true as NSNumber,
                       forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
         // 对 description 的设置必须在 load 之前完成，否则不起作用
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
    }
```

如果创建自己的 Description，类似的代码如下：

```swift
        let defaultDesc: NSPersistentStoreDescription
        let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.fatbobman.healthnote")!
        // 数据库保存在 App Group Container 中，其他的 App 或者 App Extension 也可以读取
        defaultDesc.url = groupURL
        defaultDesc.configuration = "Local"
        defaultDesc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        defaultDesc.setOption(true as NSNumber, 
                              forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        container.persistentStoreDescriptions = [defaultDesc]

        container.loadPersistentStores(completionHandler: { _, error in
            if let error = error as NSError? {
            }
        })
```

Persistent History Tracking 功能是在 description 上设置的，因此如果你的 CoreData 使用了多个`Configuration`的话，可以只为有需要的`configuration`启用该功能。

```responser
id:1
```

## 响应持久化存储跟踪远程通知 ##

```swift
final class PersistentHistoryTrackingManager {
    init(container: NSPersistentContainer, currentActor: AppActor) {
        self.container = container
        self.currentActor = currentActor

        // 注册 StoreRemoteChange 的响应
        NotificationCenter.default.publisher(
            for: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator
        )
        .subscribe(on: queue, options: nil)
        .sink { _ in
            // notification 的内容没有意义，仅起到提示需要处理的作用
            self.processor()
        }
        .store(in: &cancellables)
    }

    var container: NSPersistentContainer
    var currentActor: AppActor
    let userDefaults = UserDefaults.appGroup

    lazy var backgroundContext = { container.newBackgroundContext() }()

    private var cancellables: Set<AnyCancellable> = []
    private lazy var queue = {
        DispatchQueue(label: "com.fatbobman.\(self.currentActor.rawValue).processPersistentHistory")
    }()

    /// 处理 persistent history
    private func processor() {
        // 在正确的上下文中进行操作，避免影响主线程
        backgroundContext.performAndWait {
            // fetcher 用来获取需要处理的 transaction
            guard let transactions = try? fetcher() else { return }
            // merger 将 transaction 合并当当前的视图上下文中
            merger(transaction: transactions)
        }
    }
}
```

我简单的解释一下上面的代码。

我们注册`processor`来响应`NSNotification.Name.NSPersistentStoreRemoteChange`。

每当你的数据库中启用 Persistent History Tracking 的 Entity 发生数据变动时，`processor`都将会被调用。在上面的代码中，我们完全忽视了`notification`，因为它本身的内容没有意义，只是告诉我们数据库发生了变化，需要 processor 来处理，具体发生了什么变化、是否有必要进行处理等都需要通过自己的代码来判断。

所有针对 Persistent History Tracking 的数据操作都放在 `backgroundContext`中进行，避免影响主线程。

`PersistentHistoryTrackingManager`是我们处理 Persistent History Tracking 的核心。在 CoreDataStack 中（比如上面的 persistent.swift），通过在 init 中添加如下代码来处理 Persistent History Tracking 事件

```swift
let persistentHistoryTrackingManager : PersistentHistoryTrackingManager
init(inMemory: Bool = false) {
  ....
  // 标记当前上下文的 author 名称
    container.viewContext.transactionAuthor = AppActor.mainApp.rawValue
    persistentHistoryTrackingManager = PersistentHistoryTrackingManager(
                        container: container,
                        currentActor: AppActor.mainApp //当前的成员
   )
}
```

因为 App Group 中的成员都可以读写我们的数据库，为了在接下来的处理中更好的分辨到底是由那个成员产生的 Transaction，我们需要创建一个枚举类型来对每个成员进行标记。

```swift
enum AppActor:String,CaseIterable{
    case mainApp  // iOS App
    case safariExtension //Safari Extension
}
```

按照自己的需求来创建成员的标记。

## 获取需要处理的 Transaction ##

在接收到`NSPersistentStoreRemoteChange`消息后，我们首先应该将需要处理的 Transaction 提取出来。就像在前面的工作原理中提到的一样，API 为我们提供了 3 种不同的方法：

```swift
open class func fetchHistory(after date: Date) -> Self
open class func fetchHistory(after token: NSPersistentHistoryToken?) -> Self
open class func fetchHistory(after transaction: NSPersistentHistoryTransaction?) -> Self
```

获取指定**时间点之后**且满足条件的 Transaction

这里我更推荐使用`Timestamp`也就是`Date`来进行处理。主要有两个原因：

* 当我们用 UserDefaults 来保存最后的记录时，`Date`是 UserDefaults 直接支持的结构，无需进行转换
* `Timestamp`已经被记录在 Transaction 中（表`ATRANSACTION`），可以直接查找，无需转换，而 Token 是需要再度计算的

通过使用下面的代码，我们可以获取当前 sqlite 数据库中，所有的 Transaction 信息：

```swift
NSPersistentHistoryChangeRequest.fetchHistory(after: .distantPast)
```

这些信息包括任意来源产生的`Transaction`，无论这些`Transaction`是否是当前 App 所需要的，是否已经被当前 App 处理过了。

在上面的处理流程中，我们已经介绍过需要通过时间戳来过滤不必要的信息，并保存最后处理的`Transaction`时间戳。我们这些信息保存在 UserDefaults 中，方便 App Group 的成员来共同处理。

```swift
extension UserDefaults {
    /// 从全部的 app actor 的最后时间戳中获取最晚的时间戳
    /// 只删除最晚的时间戳之前的 transaction，这样可以保证其他的 appActor
    /// 都可以正常的获取未处理的 transaction
    /// 设置了一个 7 天的界限。即使有的 appActor 没有使用（没有创建 userdefauls）
    /// 也会至多只保留 7 天的 transaction
    /// - Parameter appActors: app 角色，比如 healthnote ,widget
    /// - Returns: 日期（时间戳）, 返回值为 nil 时会处理全部未处理的 transaction
    func lastCommonTransactionTimestamp(in appActors: [AppActor]) -> Date? {
        // 七天前
        let sevenDaysAgo = Date().addingTimeInterval(-604800)
        let lasttimestamps = appActors
            .compactMap {
                lastHistoryTransactionTimestamp(for: $0)
            }
        // 全部 actor 都没有设定值
        guard !lasttimestamps.isEmpty else {return nil}
        let minTimestamp = lasttimestamps.min()!
        // 检查是否全部的 actor 都设定了值
        guard lasttimestamps.count != appActors.count else {
            //返回最晚的时间戳
            return minTimestamp
        }
        // 如果超过 7 天还没有获得全部 actor 的值，则返回七天，防止有的 actor 永远不会被设定
        if minTimestamp < sevenDaysAgo {
            return sevenDaysAgo
        }
        else {
            return nil
        }
    } 

    /// 获取指定的 appActor 最后处理的 transaction 的时间戳
    /// - Parameter appActore: app 角色，比如 healthnote ,widget
    /// - Returns: 日期（时间戳）, 返回值为 nil 时会处理全部未处理的 transaction
    func lastHistoryTransactionTimestamp(for appActor: AppActor) -> Date? {
        let key = "PersistentHistoryTracker.lastToken.\(appActor.rawValue)"
        return object(forKey: key) as? Date
    }

    /// 给指定的 appActor 设置最新的 transaction 时间戳
    /// - Parameters:
    ///   - appActor: app 角色，比如 healthnote ,widget
    ///   - newDate: 日期（时间戳）
    func updateLastHistoryTransactionTimestamp(for appActor: AppActor, to newDate: Date?) {
        let key = "PersistentHistoryTracker.lastToken.\(appActor.rawValue)"
        set(newDate, forKey: key)
    }
}
```

由于 App Group 的成员每个都会保存自己的`lastHistoryTransactionTimestamp`，因此为了保证`Transaction`能够被所有成员都正确合并后，再被清除掉，`lastCommonTransactionTimestamp`将返回所有成员最晚的时间戳。`lastCommonTransactionTimestamp`在清除合并后的`Transaction`时，将被使用到。

有了这些基础，上面的代码变可以修改为：

```swift
let fromDate = userDefaults.lastHistoryTransactionTimestamp(for: currentActor) ?? Date.distantPast
NSPersistentHistoryChangeRequest.fetchHistory(after: fromDate)
```

通过时间戳，我们已经过滤了大量不必关心的`Transaction`了，但在剩下的`Transaction`中都是我们需要的吗？答案是否定的，至少有两种情况的 Transaction 我们是不需要关心的：

* 由当前 App 本身上下文产生的`Transaction`

  通常 App 会对自身通过上下文产生的数据变化做出即时的反馈，如果改变化已经体现在了视图上下文中（主线程 ManagedObjectContext），则我们可以无需理会这些 Transaction。但如果数据是通过批量操作完成的，或者是在`backgroudContext`操作，且并没有被合并到视图上下文中，我们还是要处理这些 Transaction 的。

* 由系统产生的 Transaction

  比如当你使用了 PersistentCloudKitContainer 时，所有的网络同步数据都将会产生`Transaction`，这些`Transaction`会由 CoreData 来处理，我们无需理会。

基于以上两点，我们可以进一步缩小需要处理的`Transaction`范围。最终 fetcher 的代码如下：

```swift
extension PersistentHistoryTrackerManager {
    enum Error: String, Swift.Error {
        case historyTransactionConvertionFailed
    }
    // 获取过滤后的 Transaction
    func fetcher() throws -> [NSPersistentHistoryTransaction] {
        let fromDate = userDefaults.lastHistoryTransactionTimestamp(for: currentActor) ?? Date.distantPast
        NSPersistentHistoryChangeRequest.fetchHistory(after: fromDate)

        let historyFetchRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: fromDate)
        if let fetchRequest = NSPersistentHistoryTransaction.fetchRequest {
            var predicates: [NSPredicate] = []

            AppActor.allCases.forEach { appActor in
                if appActor == currentActor {
                    // 本代码假设在 App 中，即使通过 backgroud 进行的操作也已经被即时合并到了 ViewContext 中
                    // 因此对于当前 appActor，只处理名称为 batchContext 上下文产生的 transaction
                    let perdicate = NSPredicate(format: "%K = %@ AND %K = %@",
                                                #keyPath(NSPersistentHistoryTransaction.author),
                                                appActor.rawValue,
                                                #keyPath(NSPersistentHistoryTransaction.contextName),
                                                "batchContext")
                    predicates.append(perdicate)
                } else {
                    // 其他的 appActor 产生的 transactions，全部都要进行处理
                    let perdicate = NSPredicate(format: "%K = %@",
                                                #keyPath(NSPersistentHistoryTransaction.author),
                                                appActor.rawValue)
                    predicates.append(perdicate)
                }
            }

            let compoundPredicate = NSCompoundPredicate(type: .or, subpredicates: predicates)
            fetchRequest.predicate = compoundPredicate
            historyFetchRequest.fetchRequest = fetchRequest
        }
        guard let historyResult = try backgroundContext.execute(historyFetchRequest) as? NSPersistentHistoryResult,
              let history = historyResult.result as? [NSPersistentHistoryTransaction]
        else {
            throw Error.historyTransactionConvertionFailed
        }
        return history
    }
}
```

> 如果你的 App 比较单纯（比如没有使用 PersistentCloudKitContainer），可以不需要上面更精细的`predicate`处理过程。总的来说，即使获取的`Transaction`超出了需要的范围，CoreData 在合并时给系统造成的压力也并不大。

由于 fetcher 是通过`NSPersistentHistoryTransaction.author`和`NSPersistentHistoryTransaction.contextName`来对`Transaction`进行进一步过滤的，因此请在你的代码中，明确的在`NSManagedObjectContext`中标记上身份：

```swift
// 标记代码中的上下文的 author，例如
viewContext.transactionAuthor = AppActor.mainApp.rawValue
// 如果用于批处理的操作，请标记 name，例如
backgroundContext.name = "batchContext"
```

**清楚地标记 Transaction 信息，是使用 Persistent History Tracking 的基本要求**

## 将 Transaction 合并到视图上下文中 ##

通过 fetcher 获取到了需要处理的 Transaction 后，我们需要将这些 Transaction 合并到视图上下文中。

合并的操作就很简单了，在合并后将最后的时间戳保存即可。

```swift
extension PersistentHistoryTrackerManager {
    func merger(transaction: [NSPersistentHistoryTransaction]) {
        let viewContext = container.viewContext
        viewContext.perform {
            transaction.forEach { transaction in
                let userInfo = transaction.objectIDNotification().userInfo ?? [:]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: userInfo, into: [viewContext])
            }
        }

        // 更新最后的 transaction 时间戳
        guard let lastTimestamp = transaction.last?.timestamp else { return }
        userDefaults.updateLastHistoryTransactionTimestamp(for: currentActor, to: lastTimestamp)
    }
}
```

可以根据自己的习惯选用合并代码，下面的代码和上面的`NSManagedObjectContext.mergeChanges`是等效的：

```swift
viewContext.perform {
   transaction.forEach { transaction in
      viewContext.mergeChanges(fromContextDidSave: transaction.objectIDNotification())
   }
}
```

这些已经在数据库中发生但尚未反映在视图上下文中的 Transaction，会在合并后立即体现在你的 App UI 上。

## 清理合并后的 Transaction ##

所有的 Transaction 都被保存在 Sqlite 文件中，不仅会占用空间，而且随着记录的增多也会影响 Sqlite 的访问速度。我们需要制定明确的清理策略来删除已经处理过的 Transaction。

同`fetcher`中使用`open class func fetchHistory(after date: Date) -> Self`类似，Persistent History Tracking 同样为我们准备了三个方法用来做清理工作：

```swift
open class func deleteHistory(before date: Date) -> Self
open class func deleteHistory(before token: NSPersistentHistoryToken?) -> Self
open class func deleteHistory(before transaction: NSPersistentHistoryTransaction?) -> Self
```

删除指定**时间点之前**且满足条件的 Transaction

清理策略可以粗旷的也可以很精细的，例如在苹果官方文档中便采取了一种比较粗旷的清理策略：

```swift
let sevenDaysAgo = Date(timeIntervalSinceNow: TimeInterval(exactly: -604_800)!)
let purgeHistoryRequest =
    NSPersistentHistoryChangeRequest.deleteHistory(
        before: sevenDaysAgo)

do {
    try persistentContainer.backgroundContext.execute(purgeHistoryRequest)
} catch {
    fatalError("Could not purge history: \(error)")
}
```

删除一切 7 天前的 Transaction，无论其 author 是谁。事实上，这个看似粗旷的策略在实际使用中几乎没有任何问题。

在本文中，我们将同 fetcher 一样，对清除策略做更精细的处理。

```swift
import CoreData
import Foundation

/// 删除已经处理过的 transaction
public struct PersistentHistoryCleaner {
    /// NSPersistentCloudkitContainer
    let container: NSPersistentContainer
    /// app group userDefaults
    let userDefault = UserDefaults.appGroup
    /// 全部的 appActor
    let appActors = AppActor.allCases

    /// 清除已经处理过的 persistent history transaction
    public func clean() {
        guard let timestamp = userDefault.lastCommonTransactionTimestamp(in: appActors) else {
            return
        }

        // 获取可以删除的 transaction 的 request
        let deleteHistoryRequest = NSPersistentHistoryChangeRequest.deleteHistory(before: timestamp)

        // 只删除由 App Group 的成员产生的 Transaction
        if let fetchRequest = NSPersistentHistoryTransaction.fetchRequest {
            var predicates: [NSPredicate] = []

            appActors.forEach { appActor in
                // 清理 App Group 成员创建的 Transaction
                let perdicate = NSPredicate(format: "%K = %@",
                                            #keyPath(NSPersistentHistoryTransaction.author),
                                            appActor.rawValue)
                predicates.append(perdicate)
            }

            let compoundPredicate = NSCompoundPredicate(type: .or, subpredicates: predicates)
            fetchRequest.predicate = compoundPredicate
            deleteHistoryRequest.fetchRequest = fetchRequest
        }

        container.performBackgroundTask { context in
            do {
                try context.execute(deleteHistoryRequest)
                // 重置全部 appActor 的时间戳
                appActors.forEach { actor in
                    userDefault.updateLastHistoryTransactionTimestamp(for: actor, to: nil)
                }
            } catch {
                print(error)
            }
        }
    }
}
```

之所以在我在 fetcher 和 cleaner 中设置了如此详尽的 predicate，是因为我自己是在`PersistentCloudKitContainer`中使用 Persistent History Tracking 功能的。Cloudkit 同步会产生大量的 Transaction，因此需要更精准的对操作对象进行过滤。

**CoreData 会自动处理和清除 CloudKit 同步产生的 Transaction，但是如果我们不小心删除了尚没被 CoreData 处理的 CloudKit Transaction，可能会导致数据库同步错误，CoreData 会清空当前的全部数据，尝试从远程重新加载数据。**

**因此，如果你是在`PersistentCloudKitContainer 上`使用 Persistent History Tracking，请务必仅对 App Group 成员产生的 Transaction 做清除操作。**

如果仅是在`PersistentContainer`上使用 Persistent History Tracking，fetcher 和 cleaner 中都可以不用过滤的如此彻底。

在创建了`PersistentHistoryCleaner`后，我们可以根据自己的实际情况选择调用时机。

如果采用`PersistentContainer`，可以尝试比较积极的清除策略。在`PersistentHistoryTrackingManager`中添加如下代码：

```swift
    private func processor() {
        backgroundContext.performAndWait {
            ...
        }

        let cleaner = PersistentHistoryCleaner(container: container)
        cleaner.clean()
    }
```

这样在每次响应`NSPersistentStoreRemoteChange`通知后，都会尝试清除已经合并过的 Transaction。

不过我个人更推荐使用不那么积极的清除策略。

```swift
@main
struct PersistentTrackBlogApp: App {
    let persistenceController = PersistenceController.shared
    @Environment(\.scenePhase) var scenePhase
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onChange(of: scenePhase) { scenePhase in
                    switch scenePhase {
                    case .active:
                        break
                    case .background:
                        let clean = PersistentHistoryCleaner(container: persistenceController.container)
                        clean.clean()
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
        }
    }
}
```

比如当 app 退到后台时，进行清除工作。

## 总结 ##

可以在 [Github](https://github.com/fatbobman/PersistentHistoryTrackingDemo) 下载本文的全部代码。

以下资料对于本文有着至关重要的作用：

* [Practical Core Data](https://donnywals.gumroad.com/l/practical-core-data)

  Donny Wals 的这本书是我最近一段时间非常喜欢的一本 CoreData 的书籍。其中有关于 Persistent History Tracking 的章节。另外他的 [Blog](https://www.donnywals.com/the-blog/) 也经常会有关于 CoreData 的文章

* [SwiftLee](https://www.avanderlee.com)

  Avanderlee 的博客也有大量关于 CoreData 的精彩文章，[Persistent History Tracking in Core Data](https://www.avanderlee.com/swift/persistent-history-tracking-core-data/) 这篇文章同样做了非常详细的说明。本文的代码结构也受其影响。

苹果构建了 Persistent History Tracking，让多个成员可以共享单个数据库并保持 UI 的及时更新。无论你是构建一套应用程序，或者是想为你的 App 添加合适的 Extension，亦或仅为了统一的响应批处理操作的数据，持久化历史跟踪都能为你提供良好的帮助。

Persistent History Tracking 尽管可能会造成一点系统负担，不过和它带来的便利性相比是微不足道的。在实际使用中，我基本上感受不到因它而导致的性能损失。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
