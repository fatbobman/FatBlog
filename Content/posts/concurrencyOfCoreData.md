---
date: 2021-11-05 08:20
description: Swift 5.5 提供了盼望已久的 async/await 的功能，为多线程开发带来了前所未有的便利。但 Core Data 由于其特有的并发规则，使用不慎容易导致代码陷入不可控状态，因此让不少开发者对在 Core Data 中进行多线程开发产生了望而却步的情绪。本文将对 Core Data 并发编程中几个常见的问题予以提示，以便开发者更好地了解 Core Data 的并发规则，充分享受 Core Data 提供的强大功能。
tags: Core Data
title:  关于 Core Data 并发编程的几点提示
image: images/concurrencyOfCoreData.png
---

Swift 5.5 提供了盼望已久的 async/await 的功能，为多线程开发带来了前所未有的便利。但 Core Data 由于其特有的并发规则，使用不慎容易导致代码陷入不可控状态，因此让不少开发者对在 Core Data 中进行多线程开发产生了望而却步的情绪。本文将对 Core Data 并发编程中几个常见的问题予以提示，以便开发者更好地了解 Core Data 的并发规则，充分享受 Core Data 提供的强大功能。

```responser
id:1
```

## 启用 Core Data 并发调试参数 ##

开发者在 Core Data 中使用并发编程很容易碰到如下场景：程序在调试期间没有出现问题。程序上线后，由于使用者的增多，会出现无法预期、难以重现、定位麻烦的程序异常或崩溃。其中有不少是因错误的使用 Core Data 的并发编程而产生的。

为了将因违反 Core Data 并发规则导致的问题尽量扼杀在开发阶段，在使用 Core Data 框架时，务必在启动参数上添加`-com.apple.CoreData.ConcurrencyDebug 1`。该标志将迫使程序执行到理论上会导致并发异常的 Core Data 代码时，立刻抛出错误。做到及时发现，尽早解决。

![image-20211104164632098](https://cdn.fatbobman.com/image-20211104164632098.png)

下文中的部分代码片段，只有在开启该标志后才会抛出错误，否则超过 90%以上的几率都不会有异常表现（继续保留隐患）。

## 使用后台上下文减少主线程阻塞 ##

无论硬件发展的多么迅速，操作系统、API 框架、各式服务总会想尽办法将其能力用尽榨干。尤其随着设备显示刷新率的不断提高，主线程（UI 线程）的压力也越来越大。通过创建后台托管对象上下文（私有队列上下文），降低 Core Data 对主线程的占用。

在 Core Data 中，我们可以创建两种类型的托管对象上下文（NSManagedObjectContext）——主队列上下文和私有队列上下文。

* 主队列上下文（NSManagedObjectContextConcurrencyType.mainQueueConcurrencyType ）

  定义于且只能用于主队列上的托管对象上下文。从事同界面（UI）有关的工作，主要用来从持久化存储中获取 UI 显示所需数据。使用 NSPersistentContainer 来创建 Core Data Stack 时，container 的 viewContext 属性对应的便是主队列上下文。

* 私有队列上下文（NSManagedObjectContextConcurrencyType.privateQueueConcurrencyType）

  顾名思义，私有队列上下文在创建时将创建它自己的队列，且只能在它自己创建的队列上使用。主要适用于执行时间较长，如果运行在主队列可能会影响 UI 响应的操作。

创建私有队列有两种方式：

```swift
let backgroundContext = persistentContainer.newBackgroundContext() // 方式一

persistentContainer.performBackgroundTask{ bgContext in  // 方式二
    ....
}
```

如果该项操作的生命周期长、频次多，通常会采用方式一，创建一个专用于该事务的私有队列（比如 [Persistent History Tracking](https://www.fatbobman.com/posts/persistentHistoryTracking/)）。

如果该项操作执行频次少，可以使用方式二，临时创建一个私有队列，随用随弃（例如文件导入）。

通过不同队列的上下文进行数据操作是最常见的 Core Data 并发应用场景。

## 托管对象上下文和托管对象是队列绑定的 ##

Core Data 是为多线程开发而设计的。然而，Core Data 框架下的对象并非都是线程安全的。其中，开发者接触最频繁、使用量最大的托管对象上下文（NSManagedObjectContext）和托管对象（NSManagedObject）恰好都不是线程安全的。

因此，在 Core Data 中进行并发编程时，请确保遵守以下规则：

* 托管对象上下文在初始化时被绑定到了与之相关的线程（队列）。
* 从托管对象上下文中检索的托管对象被绑定到了所属上下文所在的队列。

通俗的来说，就是上下文只能在自己被绑定的队列上执行才是安全的，托管对象亦然。

> 使用 Xcode 创建一个 Core Data 模版，在 ContextView.swift 中添加代码，开启 Core Data 并发调试标志。

下面的代码在执行时，将立即抛出错误：

```swift
Button("context in wrong queue") {
    Task.detached { // 将其推到其它线程（非主线程）
        print(Thread.isMainThread) // false 当前不在主线程上
        let context = PersistenceController.shared.container.viewContext
        context.reset() //  在非主线程上调用主队列上下文的方法，绝大多数的操作都会报错
    }
}
```

在非主线程上调用 viewContext 的方法时，程序会立即崩溃。

```swift
Button("NSManagedObject in wrong context"){
    // 视图运行在主线程
    let backgroundContext = PersistenceController.shared.container.newBackgroundContext() // 创建了一个私有队列
    // 在主线程进行了本应在私有线程上进行的操作
    let item = Item(context: backgroundContext) // 在私有上下文中创建 item,item 被绑定在私有队列上
    item.timestamp = .now // 在主队列上赋值
}
```

如果没有开启 Core Data 并发调试标识，上述代码在绝大多数的情况下都将正常运行，这正是此类错误难以发现的原因。

## 使用 perform 确保正确的队列 ##

为了杜绝上面代码中的错误，我们必须将对托管对象上下文和托管对象的操作放入正确的队列中。

对于主队列上下文，由于它所在的队列是明确且固定的——主线程队列，因此，只要能够保证操作是在主队列中进行即可。例如：

```swift
Button("context in wrong queue") {
        print(Thread.isMainThread) // true 视图队列为主队列
        let context = PersistenceController.shared.container.viewContext
        context.reset() // 在主线程上操作主线程上下文没有问题
}
```

或者通过使用 `DispatchQueue.main.async`、`MainActor.run`都可以确保操作是在主线程上进行。

但是，对于私有上下文，由于队列是私有的，只存在于 NSManagedObjectContext 实例的内部，因此只能通过`perform`或`performAndwait`方法来调用它。`perform`和`performAndwait`两者之间的区别为执行指定代码块的方式，异步或同步。

从 iOS 15（macOS Monterey）开始，Core Data 提供了上述方法的 async/await 版本。将两者合二为一，通过参数 schedule 来设置任务类型。immediate 即时计划任务，enqueued 排队计划任务。

```swift
perform<T>(schedule: NSManagedObjectContext.ScheduledTaskType = .immediate, _ block: @escaping () throws -> T) async rethrows -> T
```

将上文导致崩溃的代码放入 perform 中执行即可排除错误。

```swift
Button("context in wrong queue") {
    // 主队列
    Task.detached { // 推到其它队列（非主队列）
        print(Thread.isMainThread) // false
        let context = PersistenceController.shared.container.viewContext
        await context.perform { // 调整回 context 队列（本例中为主队列）
            context.reset()
        }
    }
}

Button("NSManagedObject in wrong context"){
    // 视图为主线程
    let backgroundContext = PersistenceController.shared.container.newBackgroundContext() // 创建了一个私有队列
    backgroundContext.perform {  // 在 backgroundContext 所在的私有队列中执行
        let item = Item(context: backgroundContext) 
        item.timestamp = .now 
    }
}
```

> 除非开发者能够绝对保证代码运行于主队列中，且调用的是主队列上下文或属于该上下文的托管对象，否则最保险的方式是使用 perform 来杜绝出错。

```responser
id:1
```

## 通过 NSManagedObject 来查找上下文 ##

在某些情况下，只能获得托管对象（NSManagedObject），通过从中获取托管对象上下文，保证在正确的队列中对其操作。

例如：

```swift
// Item 为 NSManagedObject
func delItem(item:Item) {
    guard let context = item.managedObjectContext else {return}
    context.perform {
        context.delete(item)
        try! context.save()
    }
}
```

托管对象对应的上下文声明为`unowned(unsafe)`，请在确认上下文仍存在的情况下使用此种方式。

## 使用 NSManagedObjectID 进行传递 ##

因为托管对象是同托管它的上下文绑定在同一个队列上，因此，无法在不同队列的上下文之间传递 NSManageObject。

对于需要在不同的队列中对同一个数据记录进行操作情况，解决方式是使用 NSManagedObjectID。

以上面删除 Item 的代码为例：假设该托管对象是在主队列中获取到的（在视图中通过@FetchRequest 或 NSFetchedResultsController），点击视图按钮，调用 delItem。为了减轻主线程的压力，在私有队列上进行数据删除操作。

调整后的代码：

```swift
func delItem(id:NSManagedObjectID) {
    let bgContext = PersistenceController.shared.container.newBackgroundContext()
    bgContext.perform {
        let item = bgContext.object(with: id)
        bgContext.delete(item)
        try! bgContext.save()
    }
}
```

或者仍采用 NSManagedObject 为参数

```swift
func delItem(item:Item) {
    let id = item.objectID
    let bgContext = PersistenceController.shared.container.newBackgroundContext()
    bgContext.perform {
        let item = bgContext.object(with: id)
        bgContext.delete(item)
        try! bgContext.save()
    }
}
```

> 细心的读者可能会疑惑，托管对象不是不能在其它队列上调用吗？从托管对象中获取 objectID 或 managedObjectContext 难道不会出问题？事实上，尽管托管对象上下文和托管对象绝大多数的属性、方法都是非线程安全的，但还是有个别属性是可以在其它线程上安全使用的。比如托管对象的 objectID、managedObjectContext、hasChanges、isFault 等。托管对象上下文的 persistentStoreCoordinator、automaticallyMergesChangesFromParent 等。

NSManagedObjectID 作为托管对象的紧凑通用标识符，被广泛使用于 Core Data 框架中。例如在批量操作、持久化历史跟踪、上下文通知等等方面都是以 NSManagedObjectID 作为数据标识的。但需要注意的是，它并不是绝对不变的。比如在托管对象创建后尚未持久化时，它将首先产生临时 ID，持久化后再转换回持久 ID；亦或者当数据库的版本或某些 meta 信息发生改变后也可能导致它发生变化（苹果没有公布它的生成规则）。

除非在程序运行时，否则不要将其作为托管对象的唯一标识（类似主键的存在），最好还是通过创建自己的 id 属性（例如 UUID）来实现。

如果确有将 ID 归档的需要，可以将 NSManagedObjectID 转换成 URI 表示。具体用例，请参阅 [在 Spotlight 中展示应用中的 Core Data 数据](https://www.fatbobman.com/posts/spotlight/)

> 前面例子中使用了 object(with: id) 来获取托管对象，其它通过 NSManagedObjectID 获取托管对象的上下文方法还有 regiesterdObject、existingObject。它们的适用场合均有不同，详情见下表。

![image-20211104211037413](https://cdn.fatbobman.com/image-20211104211037413.png)

## 在不同的上下文之间合并更改 ##

使用上面的 delItem 代码，在后台上下文中删除托管对象后，主线程上下文中的托管对象仍然存在。如果此时该数据显示在界面上的话，并不会发生变化。只有将一个上下文（本例为后台上下文）的更改合并到另一个上下文（主上下文）中，变化才会体现在界面中（@FetchRequest 或 NSFetchedResultsController）。

在 iOS 10 之前，合并上下文更改需要以下几个步骤：

* 添加一个观察者来监听 Core Data 发送的上下文已保存通知（Notification.Name.NSManagedObjectContextDidSave）
* 在观察者中，将通知的 userInfo 和要合并的上下文作为参数传递给 mergeChanges

```swift
 NotificationCenter.default.addObserver(forName:Notification.Name.NSManagedObjectContextDidSave, object: nil, queue: nil, using: merge)

func merge(_ notification:Notification) {
    let userInfo = notification.userInfo ?? [:]
    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: userInfo, into: [container.viewContext])
}
```

> 也可以使用 NSManagedObjectContext 实例的 mergeChanges 方法，逐个上下文合并。

在 iOS 10 版本，Core Data 为 NSManagedObjectContext 添加了 automaticallyMergesChangesFromParent 属性。

将上下文的 automaticallyMergesChangesFromParent 属性设置为 true，则该上下文会自动合并其它上下文的更改变化。在 [Core Data with CloudKit（二） —— 同步本地数据库到 iCloud 私有数据库](https://www.fatbobman.com/posts/coreDataWithCloudKit-2/) 中可以看到如何通过 automaticallyMergesChangesFromParent 将网络数据的变化体现在用户界面中。

## 设置正确的合并策略 ##

当使用了多个上下文或多个持久化存储协调器时，在保存处在不同环境的托管对象时就有可能发生冲突。

> 本节的合并策略中的合并，并非指上节中的上下文合并。是指将托管对象进行持久化时，为解决因托管对象乐观锁的版本不一致产生的保存冲突而进行的合并策略设置。

尽管并发不是保存冲突的必要条件，但在并发环境下非常容易发生保存冲突。

举个例子，方便大家对保存冲突有直观的了解：

* 主上下文中使用 fetch 从数据库中获取了托管对象 A（对应数据库中的数据 B）
* 使用 NSBatchUpdaterequest （不经过上下文）修改了数据库中的数据 B。
* 在主上下文中修改托管对象 A，尝试保存。
* 在保存时，A 的乐观锁版本号已经同数据库 B 新的版本号不一致了，发生了保存冲突。此时就需要根据设置的合并策略来解决如何取舍的问题。

使用 mergePolicy 设定合并冲突策略。如果不设置该属性，Core Data 会默认使用 NSErrorMergePolicy 作为冲突解决策略（所有冲突都不处理，直接报错），这会导致数据无法正确保存到本地数据库。

```swift
viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
```

Core Data 预设了四种合并冲突策略，分别为：

* NSMergeByPropertyStoreTrumpMergePolicy

逐属性比较，如果持久化数据和内存数据都改变且冲突，持久化数据胜出

* NSMergeByPropertyObjectTrumpMergePolicy

逐属性比较，如果持久化数据和内存数据都改变且冲突，内存数据胜出

* NSOverwriteMergePolicy

内存数据永远胜出

* NSRollbackMergePolicy

持久化数据永远胜出

如果预设的合并策略无法满足你的需要，也可以通过继承 NSMergePolicy 创建自定义的合并策略。

仍以上面的例子介绍策略：

* 数据 B 共有三个属性：name、age、sex
* 上下文中修改了 name 和 age
* NSBatchUpdaterequest 中修改了 age 和 sex
* 当前设置的合并策略为 NSMergeByPropertyObjectTrumpMergePolicy
* 最终的合并结果为 name 和 age 采用了上下文的修改，sex 保持了 NSBatchUpdaterequest 的修改。

## 总结 ##

Core Data 有一套开发者应严守的规则，违背了它，Core Data 将让你体会深刻的教训。不过一旦掌握了这些规则，曾经的障碍将不再是问题。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。

