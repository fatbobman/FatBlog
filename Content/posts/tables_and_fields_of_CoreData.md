---
date: 2022-05-31 08:20
description: Core Data 是一个具备数据持久化能力的对象图框架。相同的对象图在不同的持久化存储类型中（ SQLite 、XML）的数据组织结构差别较大。如果你浏览过 Core Data 生成的 SQLite 数据库文件，一定会见过其中包含不少奇怪的表和字段。本文将对这些表和字段进行介绍，或许可以换个角度帮助你解开部分疑惑，例如： Core Data 为什么不需要主键、NSManagedObjectID 是如何构成的 、保存冲突的判断依据是什么。
tags: Core Data
title: Core Data 是如何在 SQLite 中保存数据的
image: images/tablesAndFieldsInCoreData.png
---
Core Data 是一个具备数据持久化能力的对象图框架。相同的对象图在不同的持久化存储类型中（ SQLite 、XML）的数据组织结构差别较大。如果你浏览过 Core Data 生成的 SQLite 数据库文件，一定会见过其中包含不少奇怪的表和字段。本文将对这些表和字段进行介绍，或许可以换个角度帮助你解开部分疑惑，例如： Core Data 为什么不需要主键、NSManagedObjectID 是如何构成的 、保存冲突的判断依据是什么。

## 如何获取 Core Data 的 SQLite 数据库文件

可以通过以下集中方法获取到 Core Data 生成的 SQLite 数据库文件：

* 直接获取文件的存储地址

在代码中（ 通常放置在 Core Data Stack 中，更多有关 Stack 的信息，请参阅 [掌握 Core Data Stack](https://www.fatbobman.com/posts/masteringOfCoreDataStack/) ）直接打印持久化存储的保存位置，是最直接、高效的获取手段：

```swift
container.loadPersistentStores(completionHandler: { _, error in
    if let error = error as NSError? {
        fatalError("Unresolved error \(error), \(error.userInfo)")
    }
})

#if DEBUG
// 如果你有多个存储，且保存在不同的目录，需依次将其打印出来
if let url = container.persistentStoreCoordinator.persistentStores.first?.url {
    print(url)
}
#endif
```

![image-20220528103822780](https://cdn.fatbobman.com/image-20220528103822780.png)

在 Finder 中通过快捷键（ ⇧⌘ G ）或菜单命令（ 前往文件夹 ）可以直接到达文件所在的位置。

![image-20220528103959218](https://cdn.fatbobman.com/image-20220528103959218.png)

* 启用调试参数

如果你在项目中开启了 Core Data 的调试信息输出，那么可以直接在调试信息的顶部找到数据库的路径地址。

```swift
-com.apple.CoreData.CloudKitDebug 1 
```

> 更多有关调试参数的内容，请参阅 [Core Data with CloudKit（四）—— 调试、测试、迁移及其他](https://www.fatbobman.com/posts/coreDataWithCloudKit-4/#关闭日志输出)

* 通过断点查找

在应用执行过程中，通过任意断点暂停程序的执行，在调试窗口中输入如下命令，即可获得应用在沙盒中的根路径。

```swift
po NSHomeDirectory()
```

```responser
id:1
```

* 第三方工具

一些第三方工具（例如 RocketSim）提供了直接访问模拟器中 App 目录的功能。

![rocketSim_get_URL](https://cdn.fatbobman.com/rocketSim_get_URL.png)

> 读者最好能在打开一个由 Core Data 生成的 SQLite 数据库文件的情况下继续阅读接下来的内容

## 基础的表与字段

所谓基础的表与字段是指，在没有启用其他附加功能（持久化历史跟踪、Core Data With CloudKit）的情况下，Core Data 为了满足基本功能而在 SQLite 数据库中创建的表（ 非实体表 ）和在实体表中创建的特殊字段。

### 实体对应的表

下图为使用 Xcode Core Data 模板创建的项目的数据库结构（仅定义了一个实体 Item，且 Item 只有一个属性 timestamp ），其中实体 Item 在 SQLite 中对应的表是 ZITEM 。

![tableAndFieldInCoreData_tableList1](https://cdn.fatbobman.com/tableAndFieldInCoreData_tableList1.png)

Core Data 按照如下规则将数据模型中的实体转换成 SQLite 的格式：

* 实体对应的表名为 Z + 实体名称（全部大写），本例中为 ZITEM
* 实体中属性对应的字段为 Z + 属性名称（全部大写），本例中为 ZTIMESTAMP
* 对于大写后名称一致的属性（属性在定义时是大小写敏感的），将为其他重名属性添加编号。如 Item 有两个属性 timestamp 和 timeStamp ，将在表中创建两个字段 ZTIMESTAMP 及 ZTIMESTAMP1
* 为每个实体表添加三个特殊字段： Z_PK、Z_ENT、Z_OPT（均为 INTEGER 类型）

* 如实体定义中包含关系，在实体表中为关系创建对应的字段或创建对应的中间关系表（详细内容见后文）

#### Z_ENT 字段

每个实体表均在 Z_PRIMARYKEY 表（下文详述）中进行了登记。该字段与登记记录的 Z_ENT 一致。可以将其视为表的 ID 。

#### Z_PK 字段

从 1 开始递增的整数，可以将其视为表的主键。Z_PK + Z_ENT （ 主键 + 表 ID ）是 Core Data 在特定 SQLite 数据文件中查找具体条目的关键。

#### Z_OPT 字段

数据记录版本号。每一次对数据的修改，均会导致该值加一。

### Z_PRIMARYKEY 表

Z_PRIMARYKEY 表是实现通过 Z_PK + Z_ENT 定位数据的基础。它的主要作用有：

* 对 Core Data 在 SQLite 中创建的表（所有需要通过 Z_PK + Z_ENT 定位记录的表，不包括 Z_PRIMARYKEY、Z_METADATA、Z_MODELCACHE）进行登记
* 标注实体之间的关系（仅针对抽象实体）
* 记录实体的名称（数据模型中定义的名称）
* 记录每个登记表当前已使用的最大 Z_PK 值

#### Z_ENT

表的 ID。实体表会从编号 1 开始，而为其他系统功能创建的表会从编号 16000 开始。下图展示了实体 Memo 表中的 Z_ENT 与 Memo 在 Z_PRIMARYKEY 表中记录的 Z_Ent 字段的对应关系。

![tableAndFieldInCoreData_z_ent_1](https://cdn.fatbobman.com/tableAndFieldInCoreData_z_ent_1.png)

![tableAndFieldInCoreData_z_ent_2](https://cdn.fatbobman.com/tableAndFieldInCoreData_z_ent_2.png)

#### Z_NAME 字段

实体在数据模型中的名称（大小写敏感），用于从 URL 反向查找对应数据（ 具体应用见下文 ）。

#### Z_SUPER 字段

如果实体为某个实体（ [Abstract Entity](https://developer.apple.com/documentation/coredata/modeling_data/configuring_entities) ）的子实体，该值对应其父实体的 Z_ENT 。0 表示该实体没有父实体。下图展示了当 Item 为抽象实体，ItemSub 为它的子实体时 Z_SUPER 的情况。

![tableAndFieldInCoreData_z_super_1](https://cdn.fatbobman.com/tableAndFieldInCoreData_z_super_1.png)

![tableAndFieldInCoreData_z_super_2](https://cdn.fatbobman.com/tableAndFieldInCoreData_z_super_2.png)

#### Z_MAX 字段

标记了每个登记表最后使用的 Z_PK 值。在创建新的实体数据时，Core Data 将从 Z_PRIMARYKEY 表中找到对应实体最后使用的 Z_PK 值（ Z_MAX ），在此值基础上加一，作为新记录的 Z_PK 值，并更新该实体对应的 Z_MAX 值。

### Z_METADATA 表

Z_METADATA 表中记录了与当前 SQLite 文件有关的信息，包括：版本、标识符以及其他元数据。

#### Z_UUID 字段

当前数据库文件的 ID 标识（ UUID 类型）。可以通过托管对象协调器获取该值。在将 NSManagedObjectID 转换成可存储的 URL 时，该值表示对应的持久化存储。

#### Z_PLIST 字段

采用 Plist 的格式存储的有关持久化存储的元数据（ 不包含持久化存储的 UUID 标识 ）。可以通过持久化存储协调器来读取或添加数据。如有需要，开发者还可以在其中保存与数据库无关的数据（ 可以将其视为通过 Core Data 的数据库文件保存程序配置的另类用法 ）。

```swift
let coordinate = container.persistentStoreCoordinator
guard let store = coordinate.persistentStores.first else {
    fatalError()
}
var metadata = coordinate.metadata(for: store) // 获取元数据（ Z_PLIST + Z_UUID ）
metadata["Author"] = "fat" // 添加新的元数据
store.metadata = metadata

try! container.viewContext.save() // 除了在创建新的持久化存储时添加 metadata 外，其他情况下添加的数据都需要显式调用上下文的 save 方法来完成持久化
```

下图为将 Z_PLIST 中的数据（ BLOB 格式 ）导出成 Plist 格式后的情况：

![tableAndFieldInCoreData_z_plist](https://cdn.fatbobman.com/tableAndFieldInCoreData_z_plist.png)

#### Z_VERSION 字段

具体作用未知（估计为 Core Data 的 SQLite 格式版本），当前始终为 1 。

### Z_MODELCACHE 表

尽管 Core Data 在 Z_METADATA 表中的 Z_PLIST 中保留了当前使用的数据模型版本的签名信息，但由于 Z_PLIST 的内容是可更改的，因此为了确保应用正在使用的数据模型版本与 SQLite 文件中的完全一致，Core Data 在 Z_MODELCACHE 表中保存了一份与当前 SQLite 数据对应的数据模型的缓存版本 （某种 mom 或 omo 的变体）。

Z_MODELCACHE 中的缓存数据和元数据中的数据模型签名共同为数据模型的版本验证和版本迁移提供了保障。

## 从数据库结构中得到的收获

在对 SQLite 的表和字段有了一定的了解后，一些困扰 Core Data 开发者的问题或许就会得到有效的解释。

### 为什么不需要主键

Core Data 通过实体表对应的 Z_MAX 自动为每条新增记录添加了自增主键数据。因此在 Core Data 定义数据模型时，开发者无须为实体特别定义主键属性（事实上也无法创建自增主键）。

### NSManagedObjectID 的构成

托管对象的 NSManagedObjectID 由：数据库 ID + 表 ID + 实体表中的主键共同构成。在 SQLite 中对应的字段为 Z_UUID + Z_ENT + Z_PK 。通过将 NSManagedObjectID 转换成可存储格式的 URL ，可以将它的构成清晰地展示出来。

```swift
let url = itemSub.objectID.uriRepresentation()
```

![tableAndFieldInCoreData_nsmanagedObjectID_url](https://cdn.fatbobman.com/tableAndFieldInCoreData_nsmanagedObjectID_url.png)

【 文件（持久化存储）+ 表 + 行 】的信息组合也将帮助 Core Data 实现从 URL 转换为对应的托管对象。

```swift
let url = URL(string:"x-coredata://E8B22CEA-8316-45E7-BC08-3FBA516F962C/ItemSub/p1")!

if let objectID = container.persistentStoreCoordinator.managedObjectID(forURIRepresentation: url) {
    if let itemSub = container.viewContext.object(with: objectID) as? ItemSub {
        ...
    } 
}
```

> 更多有关从 URL 转换成托管对象的内容请参阅 [在 Spotlight 中展示应用中的 Core Data 数据](https://www.fatbobman.com/posts/spotlight/#onContinueUserActivity)。

### 如何在数据库中标识关系

Core Data 利用了在同一个数据库中仅需依靠 Z_ENT + Z_PK 即可定位记录的特性来实现了在不同的实体之间标注关系的工作。为了节省空间，Core Data 仅保存了每个关系记录的 Z_PK 数据，Z_ENT 则直接由数据模型从 Z_PRIMARYKEY 表中获取。

在数据库中创建关系的规则为：

* 一对多

  “一”的一侧不创建新的字段，在“多”的一侧为关系创建新的字段，该字段对应“一”的 Z_PK 值。字段名称为 Z + 关系名称（大写）

* 一对一

  关系两端都添加新的字段，分别为对应数据的 Z_PK 值

* 多对一

  关系两端都不添加新的字段，创建一个表示该多对多关系的新表，并在其中逐行添加关系两侧数据的 Z_PK 值。

  下图中，Item 与 Tag 为多对多关系，Core Data 创建了 Z_2TAGS 表来管理该关系数据。

  ![image-20220528162005978](https://cdn.fatbobman.com/image-20220528162005978.png)

> 在启用了抽象实体的情况下，除了记录对应关系数据的 Z_PK 值外，还会添加一个字段以记录该数据具体属于哪个 Z_ENT （ 父实体或某个子实体）。

### 保存冲突的判断

Core Data 在保存数据时，通过乐观锁的方式来判断是否会出现保存冲突的情况。而乐观锁的判断依据则是根据每条记录的 Z_OPT 数据，采用了版本号机制。

在数据进行持久化时，如果 Core Data 发现上下文的数据快照中的 Z_OPT 数据与行缓存中的不一致，或者行缓存中的 Z_OPT 与数据库文件不一致，均会认为是发生了保存冲突。

> 更多有关保存冲突的内容，请参阅 [关于 Core Data 并发编程的几点提示](https://fatbobman.com/posts/concurrencyOfCoreData/#设置正确的合并策略) 。

## 用于持久化历史跟踪的表

在 CoreData 中，如果你的数据保存形式是 SQLite（绝大多数的开发者都采用此种方式）且启用了持久化历史跟踪功能，无论数据库中的数据有了何种变化（删除、添加、修改等），调用此数据库并注册了该通知的应用，都会收到一个“数据库有变化”的系统提醒。

```responser
id:1
```

近几年随着 App Group、小组件、Core Data with CloudKit 、Core Data in Spotlight 等功能的应用，越来越多的 Core Data 应用中都主动或被动地开启了持久化历史跟踪选项。在启用了该功能后（ `desc.setOption(true as NSNumber,forKey: NSPersistentHistoryTrackingKey)` ），Core Data 会在 SQLite 中新建三张表来管理和记录事务，并且会在 Z_PRIMARYKEY 表中登记这三张表的信息。

> 更多详细的有关持久化历史跟踪的内容，请参阅 [在 CoreData 中使用持久化历史跟踪](https://fatbobman.com/posts/persistentHistoryTracking/) 。

![tableAndFieldInCoreData_persistent_history_tracing_tables](https://cdn.fatbobman.com/tableAndFieldInCoreData_persistent_history_tracing_tables.png)

![image-20220528172620831](https://cdn.fatbobman.com/image-20220528172620831.png)

### Z_ATRANSACTIONSTRING 表

为了能够分辨事务（ Transaction ）的来源，事务的产生者需要为托管对象上下文设置事务作者，Core Data 将所有的事务作者的信息都汇总在 Z_ATRANSACTIONSTRING 表中。

```swift
container.viewContext.transactionAuthor = "fatbobman"
```

如果开发者也为上下文也设置了名称，那么 Core Data 也将为该上下文名称创建一条记录

```swift
container.viewContext.name = "viewContext"
```

![tableAndFieldInCoreData_atransactionString](https://cdn.fatbobman.com/tableAndFieldInCoreData_atransactionString.png)

Core Data 还会为一些其他的系统功能创建默认的作者记录。在处理事务时，应忽略这些系统作者产生的事务。

> Z_PK 和 Z_ENT 的含义与上文中一致，后文将不再赘述

### Z_ATRANSACTION 表

你可以将持久化历史跟踪的事务理解为在 Core Data 中的某一次持久化过程（比如调用上下文的 save 方法）。Core Data 将与某次事务有关的信息保存在 Z_ATRANSACTION 表中。其中最为关键的信息是事务创建的时间和事务作者。

![image-20220528174541292](https://cdn.fatbobman.com/image-20220528174541292.png)

#### ZAUTHORTS 字段

对应 Z_ATRANSACTIONSTRING 表中的事务作者的 Z_PK 。上图中对应的是 Z_ATRANSACTIONSTRING 中的 Z_PK 为 1 的 fatbobman 。

#### ZCONTEXTNAMETS 字段

如果为创建事务的上下文设置了名称，则该字段对应上下文名称在 Z_ATRANSACTIONSTRING 表中的记录的 Z_PK 。上图对应的是 viewContext 。

#### ZTIMESTAMP 字段

事务的创建时间。

#### ZQUERYGEN 字段

如果为托管对象上下文设置了锁定查询令牌（ [NSQueryGenerationToken](https://developer.apple.com/documentation/coredata/nsquerygenerationtoken) ），那么事务记录中还会将当时的查询令牌保存在 ZQUERYGEN 字段中 ( BLOB 类型 )。

```swift
try? container.viewContext.setQueryGenerationFrom(.current)
```

### Z_ACHANGE 表

在一次事务中，通常会包含若干个数据操作（创建、更改、删除）。Core Data 将每个数据操作都保持在 Z_CHANGE 表中，并通过 Z_PK 与特定的事务进行关联。

![tableAndFieldInCoreData_change](https://cdn.fatbobman.com/tableAndFieldInCoreData_change.png)

#### ZCHANGETYPE 字段

数据操作类型：0 新建 1 更新 2 删除

#### ZENTITY 字段

操作对应的实体表的 Z_ENT

#### ZENTITYPK 字段

操作对应的数据记录在实体表中的 Z_PK

#### ZTRANSACTIONID 字段

操作对应的事务在 Z_ATRANSACTION 表中的 Z_PK

### 从 SQLite 角度认识持久化历史跟踪

### 创建事务

在持久化历史跟踪中，创建事务的工作是由 Core Data 自动完成的，大概的流程如下：

* 从 Z_PRIMARYKEY 表中获取 Z_ATRANSACTION 的 Z_MAX
* 使用 Z_PK （ Z_MAX + 1 ） + Z_ENT ( 事务表在 Z_PRIMARYKEY 中对应的 Z_ENT ) + 作者 ID + 时间戳 在 Z_ATRANSACTION 中创建新事务记录，并更新 Z_MAX
* 获取 Z_ACHANGE 的 Z_MAX
* 在 Z_ACHANGE 中逐条创建数据操作记录

### 查询事务

因为数据库中只保存了事务创建的时间戳，因此无论采用哪种查询方式（时间 Date、令牌 NSPersistentHistoryToken、事务 NSPersistentHistoryTransaction ）最终都会转换成比较时间戳的方式。

* 时间戳晚于上次当前应用的查询时间
* 作者不是当前 App 的作者或其他系统功能作者
* 获取满足上述条件的全部 Z_CHANGE 记录

### 合并事务

事务中提取的数据操作记录（ Z_ACHANGE ）中包含了完整的操作类型、对应的实例数据位置等信息，按图索骥从数据库中提取实体数据（ Z_PK + Z_ENT ）并将其合并（ 转换成 NSManagedObjectID ）到指定的上下文中。

### 删除事务

* 查询并提取时间戳早于全部作者（ 包含当前应用作者，但不包含系统功能作者 ）的最后查询时间的事务
* 删除上述事务（ Z_ATRANSACTION ）及其对应的操作数据（ Z_ACHANGE ）。

> 了解上述过程对理解 [Persistent History Tracking Kit](https://github.com/fatbobman/PersistentHistoryTrackingKit) 的代码很有帮助

## 其他

如果你的应用使用了 [Core Data with CloudKit](https://fatbobman.com/posts/coreDataWithCloudKit-1/) ，那么在浏览 SQLite 数据结构时你将获得进一步的惊喜（😱）。Core Data 将创建更多的表来处理与 CloudKit 的同步事宜。考虑到表的复杂性和篇幅，就不继续展开了。不过有了上文的基础，了解它们的用途也并非很困难。

下图为开启了私有数据库同步功能后 SQLite 中新增的系统表：

![image-20220528201143040](https://cdn.fatbobman.com/image-20220528201143040.png)

这些表主要记载了：CloudKit 私有域信息、上次同步时间、上次同步令牌、导出操作日志、导入操作日志、待导出数据、Core Data 关系与 CloudKit 关系对照表、本地数据对应的 CKRecordName、本地数据的 CKRecord 完整镜像（ 共享公共数据库 ）等等信息。

随着 Core Data 功能的不断增加，将来可能会看到更多的系统功能表。

## 总结

撰写本文的主要目的是对我近段时间来的零散研究进行汇总，方便日后查询。因此即便你已经完全掌握了 Core Data 的外部存储结构，但最好还是尽量不要直接对数据库进行操作，苹果可能在任何时刻改变它的底层实现。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
