---
date: 2022-06-06 08:20
description: Core Data 的优势主要体现在对象图管理、数据描述、缓存、延迟加载、内存管理等方面，但在对持久化数据的操作性能方面表现一般。事实上，在相当长的时间中，Core Data 的竞品总是喜欢通过各种图表来展现它们在数据操作性能上对 Core Data 的碾压之势。Apple 于数年前起陆续提供了批量更新、批量删除以及批量添加等 API ，在相当程度上改善 Core Data 在处理大量数据时性能劣势。本文将对 Core Data 的批量操作做以介绍，包括：原理、使用方法、高级技巧、 注意事项等内容。
tags: Core Data
title: 如何在 Core Data 中进行批量操作
image: images/batchProcessingInCoreData.png
---
Core Data 是 Apple 为其生态提供的拥有持久化功能的对象图管理框架。具备稳定（ 广泛应用于苹果的各类系统软件 ）、成熟（ Core Data 发布于 2009 年，其历史可以追溯到上世纪 90 年代 ）、开箱即用（ 内置于整个苹果生态系统 ）等特点。

Core Data 的优势主要体现在对象图管理、数据描述、缓存、延迟加载、内存管理等方面，但在对持久化数据的操作性能方面表现一般。事实上，在相当长的时间中，Core Data 的竞品总是喜欢通过各种图表来展现它们在数据操作性能上对 Core Data 的碾压之势。

Apple 于数年前起陆续提供了批量更新、批量删除以及批量添加等 API ，在相当程度上改善 Core Data 在处理大量数据时性能劣势。

本文将对 Core Data 的批量操作做以介绍，包括：原理、使用方法、高级技巧、 注意事项等内容。

```responser
id:1
```

## 批量操作的使用方法

在官方文档中并没有对批量操作的使用方法进行过多的讲解，苹果为开发者提供了一个持续更新的 [演示项目](https://developer.apple.com/documentation/swiftui/loading_and_displaying_a_large_data_feed) 来展示它的工作流程。本节将按照由易到难的顺序，逐个介绍批量删除、批量更新和批量添加。

### 批量删除

批量删除可能是 Core Data 所有批量操作中使用最方便、应用最广泛的一项功能了。

```swift
func delItemBatch() async throws -> Int {
    // 创建私有上下文
    let context = container.newBackgroundContext() 
    // 在私有上下文线程中执行（避免对视图线程造成影响）
    return try await context.perform {
        // 创建 NSFetchRequest ，其指明了批量删除对应的实体
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Item") 
        // 设置谓词，timestamp 早于三天前的所有 Item 数据 。 不设置谓词则意味着全部 Item 数据均 m
        request.predicate = NSPredicate(format: "%K < %@", #keyPath(Item.timestamp),Date.now.addingTimeInterval(-259200) as CVarArg)
        // 创建批量删除请求（ NSBatchDeleteRequest ）
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        // 设置返回结果类型
        batchDeleteRequest.resultType = .resultTypeCount
        // 执行批量删除操作
        let result = try context.execute(batchDeleteRequest) as! NSBatchDeleteResult
        // 返回批量删除的记录数量
        return result.result as! Int
    }
}
```

上面的代码将从持久化数据中（ 数据库 ）删除所有属性 `timestamp` 早于当前日期三天前的 `Item` 实体数据。代码中的注释应该能够清楚地解释全部的批量删除操作过程。

其他需要注意的还有：

* 批量操作最好是在私有托管对象上下文线程中进行
* 如果不指定谓词（ NSPredicate ），意味着将删除所有的 Item 数据
* 所有的批量操作请求（ 删除、更新、添加，以及持久化历史跟踪使用的 NSPersistentHistoryChangeRequest ）都是 [NSPersistentStoreRequest](https://developer.apple.com/documentation/coredata/nspersistentstorerequest) 的子类
* 批量请求通过托管对象上下文发出（  `context.execute(batchDeleteRequest)` ），经由持久化存储协调器直接转发给持久化存储
* 通过 `resultType` 可以设置批量操作的返回结果类型。共三种：结果状态（ statusOnly ）、记录数量（ count ）、所有记录的 NSManagedObjectID (  objectIDs ) 。如果想在批量操作后在同一段代码中将数据变化合并到视图上下文，需要将结果类型设置为 resultTypeObjectIDs
* 如果多个持久化存储均包含同一个实体模型，那么可以通过 `affectedStores` 指定仅在某个（ 或某几个 ）持久化存储中进行批量操作。默认值为在所有持久化存储上操作。该属性在所有批量操作（删除、更新、添加）中作用均相同。关于如何让不同的持久化存储拥有同样的实体模型，请参阅 [同步本地数据库到 iCloud 私有数据库中](https://www.fatbobman.com/posts/coreDataWithCloudKit-2/#在不同的_Configuration_中放置同一个_Entity) 的对应章节

除了通过 NSFetchRequest 来指定需要删除的数据外，还可以使用 NSBatchDeleteRequest 的另一个构造方法，直接指定需要删除数据的 NSManagedObjectID ：

```swift
func batchDeleteItem(items:[Item]) async throws -> Bool {
    let context = container.newBackgroundContext()
    return try await context.perform {
        // 通过 [NSManagedObjectID] 创建 NSBatchDeleteRequest
        let batchDeleteRequest = NSBatchDeleteRequest(objectIDs: items.map(\.objectID))
        batchDeleteRequest.resultType = .resultTypeStatusOnly
        let result = try context.execute(batchDeleteRequest) as! NSBatchDeleteResult
        return result.result as! Bool
    }
}
```

此种方式适合于数据或数据 ID 已被载入内存场景。需要注意的是，**所有的 NSManagedObjectID 对应的实体（ Entity ）必须一致**，比如本例中均为 Item 。

批量删除对 Core Data 中的关系提供了有限度的支持，详细内容见下文。

### 批量更新

相较于批量删除，批量更新除了需要指定实体以及谓词外（ 可省略 ），还要提供需要更新的属性和值。

下面的代码将更新所有 `timestamp` 晚于三天前的 Item 数据，将其的 `timestamp` 更新为当前日期：

```swift
func batchUpdateItem() async throws -> [NSManagedObjectID] {
    let context = container.newBackgroundContext()
    return try await context.perform {
        // 创建 NSBatchUpdateRequest ，设置对应的实体
        let batchUpdateRequest = NSBatchUpdateRequest(entity: Item.entity())
        // 设置结果返回类型，本例中返回所有更改记录的 NSManagedObjectID
        batchUpdateRequest.resultType = .updatedObjectIDsResultType
        let date = Date.now // 当前日期
        // 设置谓词，所有 timestamp 晚于三天前的记录
        batchUpdateRequest.predicate = NSPredicate(format: "%K > %@", #keyPath(Item.timestamp), date.addingTimeInterval(-259200) as CVarArg)
        // 设置更新字典 [属性：更新值] ，可以设置多个属性
        batchUpdateRequest.propertiesToUpdate = [#keyPath(Item.timestamp): date]
        // 执行批量操作
        let result = try context.execute(batchUpdateRequest) as! NSBatchUpdateResult
        // 返回结果
        return result.result as! [NSManagedObjectID]
    }
}
```

需要注意如下事项：

* propertiesToUpdate 中，如属性名称拼写错误将导致程序崩溃
* propertiesToUpdate 中，如更新值类型错误将导致程序崩溃
* 批处理将忽略 Core Data 所有的值验证过程，无论是在数据模型编辑器中设置的，还是在 validateForXXXX 方法中添加的
* 批量更新无法实现在原值的基础上进行改动的情况，如需实现 `item.count += 1` 仍只能通过传统的手段
* 无法在批量更新中修改关系属性或关系属性的子属性
* 如果更新的实体为抽象实体，可以通过 `includesSubentities` 设置更新是否包含子实体
* 在批量更新操作中无法使用关键路径连接的方式设置谓词（ 批量删除支持关键路径连接 ）。比如下面的谓词在批量操作中就是非法的（ 假设 Item 有个 attachment 关系，Attachment 有 count 属性 ）：`NSPredicate(format: "attachment.count > 10")` 。

### 批量添加

下面的代码将创建给定数量（ `amount` ）的 Item 数据：

```swift
func batchInsertItem(amount: Int) async throws -> Bool {
    // 创建私有上下文
    let context = container.newBackgroundContext()
    return try await context.perform {
        // 已添加的记录数量
        var index = 0
        // 创建 NSBatchInsertRequest ，并声明数据处理闭包。如果 dictionaryHandler 返回 false , Core Data 将继续调用闭包创建数据，直至闭包返回 true 。
        let batchRequest = NSBatchInsertRequest(entityName: "Item", dictionaryHandler: { dict in                                                                           
            if index < amount {
                // 创建数据。当前的 Item 只有一个属性 timestamp ，类型为 Date
                let item = ["timestamp": Date().addingTimeInterval(TimeInterval(index))]
                dict.setDictionary( item )
                index += 1
                return false // 尚未全部完成，仍需继续添加
            } else {
                return true // index == amout , 已添加了指定数量（ amount ）的数据，结束批量添加操作
            }
        })
        batchRequest.resultType = .statusOnly
        let result = try context.execute(batchRequest) as! NSBatchInsertResult
        return result.result as! Bool
    }
}
```

NSBatchInsertRequest 提供了三种添加新数据的构造方法：

1. init(entityName: String, objects: [[String : Any]])

   该方法需要将所有的数据预先保存成字典数组，相较于其他两种方式会占用更大的内存空间

2. init(entityName: String, dictionaryHandler: (NSMutableDictionary) -> Bool)

   上面例程中使用的方法。同批量更新一样，使用字典来构建数据

3. init(entityName: String, managedObjectHandler: (NSManagedObject) -> Bool)

   相较于方法 2 ，由于采用了托管对象来构建数据，因此避免了可能出现的属性名称拼写及值的类型错误。但由于每次都需要实例化一个托管对象，理论上性能较方法 2 稍慢。相较于同样使用托管对象实例来新建数据的传统方式，方法 3 在内存占用上有巨大的优势（ 占用空间极小 ）

下面的代码采用了方法三：

```swift
let batchRequest = NSBatchInsertRequest(entityName: "Item", managedObjectHandler: { obj in
    let item = obj as! Item
    if index < amount {
        // 通过属性赋值避免了通过字典添加可能导致的属性名称或值类型错误
        item.timestamp = Date().addingTimeInterval(TimeInterval(index))
        index += 1
        return false
    } else {
        return true
    }
})
```

其他需要注意的事项：

* 通过字典创建数据时，如果可选属性的值为 nil，可以不在字典中添加
* 批量添加无法处理 Core Data 的关系
* 当多个持久化存储都包含同一个实体模型时，默认情况下，新创建的数据会写入到持久化存储协调器 persistentStores 属性中位置靠前的持久化存储中。可以通过 affectedStores 改变写入的持久化存储
* 通过在数据模型编辑器中设置约束，可以让批量添加具备批量更新（选择性）的能力。下文中会详细说明

### 将变化合并到视图上下文

由于批量操作是直接在持久化存储上完成的，因此必须通过某种方式将变化后的数据合并到视图上下文中，才能将变化在 UI 上体现出来。

可以采用如下两种方式：

* 启用持久化历史跟踪功能（ 当前的首选方式 ）

  详细内容请参阅 [在 CoreData 中使用持久化历史跟踪](https://www.fatbobman.com/posts/persistentHistoryTracking/) 。此种方式不仅可以让批量操作的变动在当前的应用中及时体现出来，而且可以让 App Group 的其他成员（ 共享数据库文件 ），也能及时地对数据的变化作出反应

* 将合并操作集成在批量操作的代码中

  下面的代码会将新添加的 Item 数据合并到视图上下文中

```swift
func batchInsertItemAndMerge(amount: Int) async throws {
    let context = container.newBackgroundContext()
    try await context.perform {
        var index = 0
        let batchRequest = NSBatchInsertRequest(entityName: "Item", dictionaryHandler: { dict in
            if index < amount {
                let item = ["timestamp": Date().addingTimeInterval(TimeInterval(index))]
                dict.setDictionary(item)
                index += 1
                return false 
            } else {
                return true 
            }
        })
        // 设置返回类型必须设置为 [NSManagedObjectID]
        batchRequest.resultType = .objectIDs
        let result = try context.execute(batchRequest) as! NSBatchInsertResult
        let objs = result.result as? [NSManagedObjectID] ?? []
        // 创建变动字典。根据数据变化类型，创建不同的键值对。插入：NSInsertedObjectIDsKey、更新：NSUpdatedObjectIDsKey、删除：NSDeletedObjectIDsKey。
        let changes: [AnyHashable: Any] = [NSInsertedObjectIDsKey: objs]
        // 合并变动
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.container.viewContext])
    }
}
```

```responser
id:1
```

## 批量操作的快与省

无论是官方给出的数据，还是开发者的实际测试，Core Data 的批量操作相较于实现相同结果的传统方式（ 在托管对象上下文中使用托管对象 ）来说都具有相当明显的优势 —— 执行速度快、内存占用小。那么其中的原因是什么呢？为了获得这些优势，“批量操作” 又是牺牲了哪些 Core Data 的重要特性呢？本节将上述问题做一点探讨。

### Core Data 中各个组件的协作

想搞清楚批量操作又快又省的原因，需要对 Core Data 的几大组件之间的协作规则以及数据在各个组件间传递的机制有一定了解。

以从 Core Data 中对获取的结果修改属性值为例，我们简单了解一下各组件之间的协作以及数据的流动（ 存储格式为 SQLite ）：

```swift
let request = NSFetchRequest<Item>(entityName: "Item")
request.predicate = NSPredicate(format: "%K > %@", #keyPath(Item.timestamp), date.addingTimeInterval(-259200) as CVarArg)
let items = try! context.fetch(request)
for item in items {
    item.timestamp = Date()
}
try! context.save()
```

1. 托管对象上下文 context（ NSManagedObjectContext ）通过调用 request（ NSFetchRequest ）的 `executeRequest()` 方法将 “获取请求” 传递给持久化存储协调器（ NSPersistentStoreCoordinator ）
2. 持久化存储协调器将 NSFetchRequest 转换成对应的 NSPersistentStoreRequest ，并调用自身的 `executeRequest(_:with:)`方法，将 “获取请求” 和发起请求的 “上下文” 一并发送给所有的持久化存储（ NSPersistentStore ）
3. 持久化存储将 NSPersistentStoreRequest 转换成 SQL 语句，并把这个语句发送给 SQLite
4. SQlite 执行这个语句，将匹配查询条件的所有数据返回给持久化存储（ 包括对象 ID、每行数据的属性内容、数据版本等信息 ），持久化存储将其保存在行缓存中（ row catch ）
5. 持久化存储将从步骤 4 获取的数据实例化为托管对象（ 本例中实例化为 Item ），并把这些对象返回给持久化存储协调器，由于 NSFetchRequest 的 returnsObjectsAsFaults 默认值为 true，因此此时这些对象是惰值（ Fault ）形态的
6. 持久化存储协调器将步骤 5 中实例化的数据以托管对象数组的形式返回给发起请求的托管对象上下文
7. 如果上下文中有部分新数据或数据改动与本次获取的条件一致，上下文将一并考虑进来与步骤 6 的数据合并
8. items 变量获得最终满足条件的全部数据（ 此时数据为惰值形态 ）
9. 使用 item.timestamp 更新数据时，Core Data 会检查当前的托管对象是否为惰值 （ 本例中是 ）
10. 上下文向持久化存储协调器发起填充请求
11. 持久化存储协调器向持久化存储请求与当前对象关联的数据
12. 持久化存储在它的行缓存中查找数据，并返回（ 在本例中，数据已经被载入到行缓存中。假如在其他情况下，数据没在缓存中，持久化存储会通过 SQL 语句从 SQLite 中获取到对应的数据 ）
13. 持久化存储协调器将从持久化存储中获取的数据转交给上下文
14. 上下文用获得到的数据填充惰值状态的 item ，并用新数据替换掉原来的 timestamp
15. 上下文通过发送 NSManagedObjectContextWillSaveNotification 通知（ 由 save 方法引发 ），通知中包含了即将更新的对象集合
16. 对所有发生变动的 item 进行验证 （ 调用 Item 的 validateForUpdate 方法中的自定义验证代码以及模型编辑器中定义的验证条件 ），如验证失败则抛出错误
17. 调用所有需要更新的托管对象 （ item ）的 `willSave` 方法
18. 创建一个持久化存储请求（ NSSaveChangesRequest ）并调用持久化存储协调器的 `executeRequest(_:with:)` 方法
19. 持久化存储协调器将请求发送给持久化存储
20. 持久化存储对请求中的数据与持久化存储行缓存中的数据进行冲突检测。如果发生冲突（ 在我们于上下文更改数据的过程中，行缓存中的数据发生了变动 ）则按照合并策略进行处理
21. 将 NSSaveChangesRequest 翻译成对应的 SQL 语句发送给 SQLite 数据库（ SQL 语句会根据合并策略的不同而有所变化，在 SQlite 保存过程中还会再进行一次冲突检查 ）
22. SQLite 执行给定的 SQL 语句（ Core Data 在 SQLite 中对数据的处理也有其独特的地方，详情请阅读 [Core Data 是如何在 SQLite 中保存数据的](https://www.fatbobman.com/posts/tables_and_fields_of_CoreData/) ）
23. 在 SQLite  完成更新后，持久化存储会更新它的行缓存，将数据以及数据版本更新到当前状态
24. 调用所有更新后的 item 实例的 `didSave()` 方法
25. 抹除更新后的 item 和 托管对象上下文的脏状态
26. 托管对象上下文发送 NSManagedObjectContextDidSaveNotification 通知。通知中包含了本次更新的对象集合

或许上面的步骤已经让你有点头痛，但事实上我们还是省略了相当多的细节。

这些烦琐的操作或许会造成 Core Data 在某些情况下的性能问题，但 Core Data 的强大也同样在这些细节中得以展现。不仅让开发者可以从多个维度、时机来处理数据，同时 Core Data 也将根据数据的状态在性能、内存占用等方面寻找合适的平衡。对于一个成熟的 Core Data 开发者，从整体的收益上来看，Core Data 相较于直接操作数据库或使用其他的 ORM 框架仍是有优势的。

### 批量操作为什么快

上面使用传统的方式实现的功能与本文之前介绍的批量更新代码完全一样。那么 Core Data 在使用批量更新代码时的内部操作过程是如何的呢？

1. 托管对象上下文通过 `execute` 将持久化存储查询请求（ NSBatchUpdateRequest ）发送给持久化存储协调器
2. 协调器直接将请求转发给持久化存储
3. 持久化存储将其转换成 SQL 语句，发送给 SQLite
4. SQLite 执行更新语句，并将更新后的记录 ID 回传给持久化存储
5. 持久化存储将 ID 转换成 NSManagedObjectID ，通过协调器回传给上下文

看到这里，我想无须再继续解释批量操作为什么相较于传统操作效率要更高了吧。

所谓有得必有失，Core Data 的批量操作是在放弃了大量的细节处理的基础上换取的效率提升。整个过程中，我们将失去检验、通知、回调机制、关系处理等功能。

因此，如果你的操作要求并不需要上述略过的能力，那么批量操作确实是非常好的选择。

### 批量操作为什么省

对于更新和删除操作来说，由于批量操作无须将数据提取到内存中（ 上下文、行缓存 ），因此整个操作过程中几乎不会造成什么内存的占用。

至于添加新数据的批量操作，dictionaryHandler 闭包（ 或 managedObjectHandler 闭包）会在每次构建一个数据后立即将其转换成对应的 SQL 语句并发送给持久化存储，在整个的创建过程中，内存中只会保留一份数据。相较于传统的方法需要在上下文中实例化所有的新添加数据的方式，内存占用也几乎可以忽略不计。

### 避免 WAL 文件溢出

由于批量操作对内存的占用极小，导致开发者在使用批量操作上几乎没有什么心理负担，从而容易在一次操作过程中执行过量的指令。默认情况下 Core Data 为 SQLite 启用了 WAL 模式，当 SQL 事务的量过大时，WAL 文件的尺寸会急速增加并达到 WAL 的预设检查点，容易造成文件溢出，从而导致操作失败。

因此开发者仍需控制每次批量操作的数据规模，如果确实有需要，可以通过设置持久化存储元数据（ [NSSQLitePragmasOption](https://developer.apple.com/documentation/coredata/nssqlitepragmasoption) ）的方式，修改 Core Data 的 SQLite 数据库的默认设置。

## 批量操作中的高级技巧

除了上文中介绍的能力外，批量操作中还有一些其他有用的技巧。

### 用约束来控制批量添加的行为

在 Core Data 中，通过在数据模型编辑器中将实体中某个属性（ 或某几个属性 ）设置为约束，以使此属性的值具有唯一性。

![image-20220605145151785](https://cdn.fatbobman.com/image-20220605145151785.png)

因为 Core Data 的唯一约束是依赖 SQLite 的特性实现的，因此批量操作也自然地拥有了这项能力。

假设，应用程序需要定期从服务器上下载一个巨大的 JSON 文件，并将其中的数据保存到数据库中。如果可以确定源数据中的某个属性是唯一的（ 例如 ID、城市名、产品号等等 ），那么可以在数据模型编辑器中将该属性设置为约束属性。当使用批量添加将 JSON 数据保存到数据库时，Core Data 将根据开发者设定的合并策略来进行操作（ 有关合并策略的详细内容，请参阅 [关于 Core Data 并发编程的几点提示](https://www.fatbobman.com/posts/concurrencyOfCoreData/#设置正确的合并策略）的对应章节 )。比如说以新数据为准，或者以数据库中的数据为准。

Core Data 会根据是否在数据模型中开启了约束已经定义了何种合并策略来创建批量添加操作对应的 SQL 语句。例如下面的情况：

* 没有开启约束

```sql
INSERT INTO ZQUAKE(Z_PK, Z_ENT, Z_OPT, ZCODE, ZMAGNITUDE, ZPLACE, ZTIME) VALUES(?, ?, ?, ?, ?, ?, ?)
```

* 开启了约束，并将合并策略设置为 NSErrorMergePolicy

  此种状态下，新数据（ 约束属性一致 ）将忽略（ 不作改动 ）

```sql
INSERT OR IGNORE INTO ZQUAKEZ_PK, Z_ENT, Z_OPT, ZCODE, ZMAGNITUDE, ZPLACE, ZTIME) VALUES(?, ?, ?, ?, ?, ?, ?)
```

* 开启了约束，并将合并策略设置为 NSMergeByPropertyObjectTrumpMergePolicy

  在此种情况下，行为变成了更新

```sql
INSERT INTO ZQUAKE(Z_PK, Z_ENT, Z_OPT, ZCODE, ZMAGNITUDE, ZPLACE, ZTIME) VALUES(?, ?, ?, ?, ?, ?, ?) ON CONFLICT(ZCODE) DO UPDATE SET Z_OPT = Z_OPT+1 , ZPLACE = excluded.ZPLACE , ZMAGNITUDE = excluded.ZMAGNITUDE , ZTIME = excluded.ZTIME
```

> 注意：创建约束 与 Core Data with CloudKit 功能冲突，了解哪些属性或功能无法在 Core Data with CloudKit 下开启，请参阅 [Core Data with CloudKit（二） —— 同步本地数据库到 iCloud 私有数据库](https://www.fatbobman.com/posts/coreDataWithCloudKit-2/#创建可同步_Model_的注意事项)

### 批量删除对 Core Data 关系的有限支持

在以下两种情况下，批量删除可以自动完成关系数据的清理工作：

* 采用了 Cascade 删除规则的关系

  比如 Item 有一个名为 attachment 的关系（ 一对一或一对多 ），Item 端设定的删除规则为 Cascade 。在对 Item 进行批量删除时，Core Data 会自动将 Item 对应的 Attachment 数据一并删除

![image-20220605153333679](https://cdn.fatbobman.com/image-20220605153333679.png)

* 删除规则为 Nullify ，且关系为可选

  比如 Item 有一个名为 attachment 的关系（ 一对一或一对多 ），Item 端设定的删除规则为 Nullify ，且关系为可选（ Optional ）。在对 Item 进行批量删除时，Core Data 会将 Item 对应的 Attachment 的关系 ID （ 对应 Item ）设置为 NULL（ 并不会删除这些 Attachment 数据 ）

![image-20220605154156584](https://cdn.fatbobman.com/image-20220605154156584.png)

或许正因为批量删除提供了对部分 Core Data 关系的支持，因此让它成为最常使用的批量操作。

## 总结

批量操作改善了某些场合下 Core Data 数据操作效率低、内存占用大的问题，使用得当，必将成为开发者的得力工具。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
