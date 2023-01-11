---
date: 2021-08-05 20:50
description: 介绍如何使用 NSPersistentContainer 的文章并不少，但同其他 Core Data 的功能一样，用好并不容易。在两年多的使用中，我便碰到不少问题。借着今年打算在【健康笔记 3】中实现共享数据库功能的机会，我最近较系统地重新学习了 Core Data with CloudKit 并对其知识点进行了梳理。希望通过这个系列博文能让更多的开发者了解并使用 Core Data with Cloudkit 功能。
tags: CloudKit,Core Data
title: Core Data with CloudKit （一） —— 基础 
---

在 WWDC 2019 上，苹果为`Core Data`带了一项重大的更新——引入了`NSPersistentCloudKitContainer`。这意味着无需编写大量代码，使用`Core Data with CloudKit`可以让用户在他所有的苹果设备上无缝访问应用程序中的数据。

`Core Data`为开发具有结构化数据的应用程序提供了强大的对象图管理功能。CloudKit 允许用户在登录其 iCloud 账户的每台设备上访问他们的数据，同时提供一个始终可用的备份服务。`Core Data with CloudKit`则结合了本地持久化+云备份和网络分发的优点。

2020 年、2021 年，苹果持续对`Core Data with CloudKit`进行了强化，在最初仅支持私有数据库同步的基础上，添加了公有数据库同步以及共享数据库同步的功能。

我将通过几篇博文介绍`Core Data with CloudKit`的用法、调试技巧、控制台设置并尝试更深入地研究其同步机制。

[Core Data with CloudKit （一） —— 基础](/posts/coreDataWithCloudKit-1/)

[Core Data with CloudKit（二） —— 同步本地数据库到 iCloud 私有数据库](/posts/coreDataWithCloudKit-2/)

[Core Data with CloudKit（三）—— CloudKit 仪表台](/posts/coreDataWithCloudKit-3/)

[Core Data with CloudKit（四）—— 调试、测试、迁移及其他](/posts/coreDataWithCloudKit-4/)

[Core Data with CloudKit（五）—— 同步公共数据库](/posts/coreDataWithCloudKit-5/)

[Core Data with CloudKit （六） —— 创建与多个 iCloud 用户共享数据的应用](/posts/coreDataWithCloudKit-6/)

```responser
id:1
```

## Core Data with CloudKit 的局限性 ##

* **只能运行在苹果的生态**

  不同于其他的跨平台解决方案，`Core Data with CloudKit`只能运行于苹果生态中，并且只能为苹果生态的用户提供服务。

* **测试门槛较高**

  需要有一个 [Apple Developer Program](https://developer.apple.com/programs/) 账号才能在开发过程中访问`CloudKit`服务和开发团队的`CKContainer`。另外，在模拟器上的运行效果也远没有在真机上可靠。

## Core Data with CloudKit 的优点 ##

* **几乎免费**

  开发者基本上不需要为网络服务再额外支付费用。私有数据库保存在用户个人的 iCloud 空间中，公共数据库的容量会随着应用程序使用者的增加而自动提高，最高可增加到 1 PB 存储、10 TB 数据库存储，以及每天 200 TB 流量。之所以说几乎免费，毕竟苹果会扣取 15-30%的 app 收益。

* **安全**

  一方面苹果通过沙盒容器、数据库区隔、加密字段、鉴权等多种技术手段保证了用户的数据安全。另一方面，鉴于苹果长期以来在用户中树立的隐私捍卫者的形象，使用`Core Dat with CloudKit`可以让用户对你的应用程序增加更多的信任。

  事实上，正是在 WWDC2019 年看到这个功能后，我才有了开发 [【健康笔记】](/healthnotes/) 的原动力——既保证数据隐私又能长久的保存数据。

* **集成度高、用户感知好**

  鉴权、分发等都是无感的。用户不需要进行任何额外的登录便可享受全部的功能。

## Core Data ##

`Core Data`诞生于 2005 年，它的前身`EOF`在 1994 年便已经获得的不少用户的认可。经过了多年的演进，`Core Data`已经发展的相当成熟。作为对象图和持久化框架，几乎每个教程都会告诉你，不要把它当作数据库，也不要把它当作`ORM`。

`Core Data`的功能包括但不限于：管理序列化版本、管理对象生命周期、对象图管理、SQL 隔离、处理变更、持久化数据、数据内存优化以及数据查询等。

`Core Data`提供的功能繁多，但对于初学者并不十分友好，拥有陡峭的学习曲线。最近几年苹果也注意到了这个问题，通过添加`PersistentContainer`极大的降低了`Stack`创建的难度；`SwiftUI`及`Core Data 模版`的出现让初学者也可以较轻松地在项目中使用其强大的功能了。

## CloudKit ##

在苹果推出`iCloud`之后的几年中，开发者都无法将自己的应用程序同`iCloud`结合起来。这个问题直到 2014 年苹果推出了`CloudKit`框架后才得到解决。

`CloudKit`是数据库、文件存储、用户认证系统的集合服务，提供了在应用程序和`iCloud 容器`之间的移动数据接口。用户可以在多个设备上访问保存在`iCloud`上的数据。

`CloudKit`的数据类型、内在逻辑和`Core Data`有很大的不同，需要做一些妥协或处理才能将两者的数据对象进行转换。事实上，当`CloudKit`一经推出，开发者就强烈希望两者之间能够进行便捷的转换。在推出`Core Data with CloudKit`之前，已经有第三方的开发者提供了将`Core Data`或其他数据的对象（比如`realm`）同步到`CloudKit`的解决方案，这些方案中的大多数目前仍在提供支持。

依赖于之前推出的 [持久化历史追踪](/posts/persistentHistoryTracking/) 功能，苹果终于在 2019 年提供了自己的解决方案`Core Data with CloudKit`。

## Core Data 对象 vs CloudKit 对象 ##

两个框架都有各自的基础对象类型，相互之间并不能被一一对应。在此仅对本文涉及的一些基础对象类型做简单的介绍和比较：

* **NSPersistentContainer vs CKContainer**

  `NSPersistentContainer`通过处理托管对象模型（`NSManagedObjectModel`），对持久性协调器（`NSPersistentStoreCoordinator`）和托管对象上下文（`NSManagedObjectContext`）进行统一的创建和管理。开发者通过代码创建其的实例。

  `CKContainer`则和应用程序的沙盒逻辑类似，在其中可以保存结构化数据、文件等多种资源。每个使用`CloudKit`的应用程序应有一个属于自己的`CKContainer`（通过配置，一个应用程序可以对应多个`CKContainer`，一个`CKContainer` 也可以服务于多个应用程序）。开发者通常不会在代码中直接创建新的`CKConttainer`，一般通过`iCoud 控制台`或在`Xcode Target`的`Signing&Capabilities`中创建。

* **NSPersistentStore vs CKDatabase/CkRecordZone**

  `NSPersistentStore`是所有 `Core Data` 持久存储的抽象基类，支持四种持久化的类型（`SQLite`、`Binary`、`XML` 和 `In-Memory`）。在一个`NSPersistentContainer`中，通过声明多个的`NSPersistentStoreDescription`，可以持有多个`NSPersistentStore 实例`（可以是不同的类型）。`NSPersistentStore`没有用户鉴权的概念，但可以设置只读或读写两种模式。由于`Core Data with CloudKit`需要 [持久化历史追踪](/posts/persistentHistoryTracking/) 的支持，因此只能同步将`SQLite`作为存储类型的`NSPersistentStore`，在设备上，该`NSPersistentStore 的实例`将指向一个`SQLite 数据库文件`。

  在`CloudKit`上，结构化的数据存储只有一种类型，但采用了**两个维度**对数据进行了区分。

  从用户鉴权角度，`CKDatabase`分别提供了三种形式的数据库：私有数据库、公有数据库、共享数据库。应用程序的使用者（已经登录了`iCloud`账号）只能访问自己的私有数据库，该数据库的数据保存在用户个人的`iCloud`空间中，其他人都不可以对其数据进行操作。在公共数据库中保存的数据可以被任何授权过的应用程序调用，即使 app 的使用者没有登录`iCloud`账户，应用程序仍然可以读取其中的内容。应用程序的使用者，可以将部分数据共享给其他的同一个`app`的使用者，共享的数据将被放置在共享数据库中，共享者可以设置其他用户对于数据的读写权限。

  数据在`CKDatabase`中也不是以零散的方式放置在一起的，它们被放置在指定的`RecordZone`中。我们可以在私有数据库中创建任意多的`Zone`（公共数据库和共享数据库只支持默认`Zone`）。当`CKContainer`被创建后，每种数据库中都会默认生成一个名为`_defaultZone`的`CKRecordZone`。

  因此，当我们保存数据到 CloudKit 数据库时，不仅需要指明数据库（私有、公有、共享）类型，同时也需要标明具体的`zoneID`（当保存到`_defaultZone`时无需标记）。

* **NSManagedObjectModel vs Schema**

  `NSManagedObjectModel`是托管对象模型，标示着`Core Data`对应的数据实体（Enities）。绝大多数情况下，开发者都是使用`Xcode`的`Data Model Editor`来对其进行的定义，定义会被保存在`xcdatamodeled`文件中，其中包含了实体属性、关系、索引、约束、校验、配置等等信息。

  当在应用程序中启用`CloudKit`后，将在`CKContainer`创建一个`Schema`。`Schema`中包括记录类型（`Record Type`）、记录类型类型之间可能存在的关系、索引以及用户权限。

  除了直接在`iCloud`控制台创建`Schema`的内容外，也可以通过在代码中创建`CKRecord`，让`CloudKit`自动为我们创建或更新`Schema`中对应的内容。

  `Schema`中有权限的设定（`Security Roles`），可以分别为`world`、`icloud`以及`creator`设定不同的读写权限。

* **Entities vs Record Types**

  尽管我们通常会强调`Core Data`不是数据库，但实体（`Enitities`）与数据库中的表非常相似。我们在实体中描述对象，包括其名称、属性和关系。最终将其描述成`NSEntityDescription`并汇总到`NSManagedObjectModel`中。

  在`CloudKit`中用`Record Types`描述数据对象的名称、属性。

  `Enitiy`中有大量的信息可以配置，但`Record Types`只能对应描述其中的一部分。由于两方无法一一对应，因此在设计`Core Data with CloudKit`的数据对象时要遵守相关规定（具体规定将在下一篇文章中探讨）。

* **Managed Object vs CKRecord**

  托管对象（`Managed Object`）是表示持久存储记录的模型对象。托管对象是`NSManagedObject`或其子类的实例。托管对象在托管对象上下文（`NSManagedObjectContext`）中注册。在任何给定的上下文中，托管对象最多有一个实例对应于持久存储中的给定记录。

  在`CloudKit`上，每条记录被称作为`CKRecord`。

  我们不需要关心`Managed Object`的`ID`（`NSMangedObjectID`）的创建过程，`Core Data`将为我们处理一切，但对于`CKRecord`，多数情况下，我们需要在代码中明确为每条记录设定`CKRecordIdentifier`。作为`CKRecord`的唯一标识，`CKRecordIdentifier`被用于确定该`CKRecord`在数据库的唯一位置。如果数据保存在自定义的`CKRecordZone`，我们也需要在`CKRecord.ID`中指明。

* **CKSubscription**

  `CloudKit`是云端服务，它要同一`iCloud`账户的不同设备（私有数据库）或者使用不同`iCloud`账号的设备（公共数据库）的数据变化做出相应的反馈。

  开发者通过`CloudKit`在`iCloud`上创建`CKSubscription`, 当`CKContainer`中的数据发生变化时，云端服务器会检查该变化是否满足某个`CKSubscription`的触发条件，在条件满足时，对订阅的设备发送远程提醒（`Remote Notification`）。这就是当我们在`Xcode Target`的`Signing&Capabilities`中添加上`CloudKit`功能时，会`Xcode`自动添加`Remote Notification`的原因。

  在实际使用中，需要通过`CKSubscription`的三个子类完成不同的订阅任务：

  `CKQuerySubscription`，当某个`CKRecord`满足设定的`NSPercidate`时推送`Notification`。

  `CKDatabaseSubscription`，订阅并跟踪数据库（`CKDatabase`）中记录的创建、修改和删除。该订阅只能用于私有数据库和共享数据库中自定义的`CKRecordZone`，并只会通知`订阅的创建者`。在以后的文章中，我们可以看到`Core Data with CloudKit`是如何在私有库中使用该订阅的。

  `CKRecordZoneNotification`，当用户、或者在某些情况下，`CloudKit`修改该区域（`CKRecordZone`）的记录时，记录区的订阅就会执行，例如，当记录中某个字段的值发生变化时。

  对于`iCloud`服务器推送的远程通知，应用程序需要在`Application Delegate`中做出响应。多数情况下，`远程提醒`可以采用`静默通知`的形式，为此开发者需要在的应用程序中启用`Backgroud Modes`的`Remote notifications`。

## Core Data with CloudKit 的实现猜想 ##

结合上面介绍的基础知识，让我们尝试推测一下`Core Data with CloudKit`的实现过程。

以私有数据库同步为例：

* 初始化：
  1. 创建`CKContainer`
  2. 根据`NSManagedObjectModel`配置`Schema`
  3. 在私有数据库中创建 ID 为`com.apple.coredata.cloudkit.zone`的`CKRecordZone`
  4. 在私有数据库上创建`CKDatabaseSubscription`

* 数据导出（将本地`Core Data`数据导出到云端）
  1. `NSPersistentCloudKitContainer`创建后台任务响应`持久化历史跟踪`的`NSPersistentStoreRemoteChange`通知
  2. 根据`NSPersistentStoreRemoteChange`的`transaction`，将`Core Data`的操作转换成`CloudKit`的操作。比如对于新增数据，将`NSManagedObject`实例转换成`CKRecord`实例。
  3. 通过`CloudKit`将转换后的`CKRecord`或其他`CloudKit 操作`传递给`iCloud`服务器

* 服务器端
  1. 按顺序处理从远端设备提交的`CloudKit 操作数据`
  2. 根据初始化创建的`CKDatabaseSubscription`检查该操作是否导致私有数据库的`com.apple.coredata.cloudkit.zone`中的数据发生变化
  3. 对所有创建`CKDatabaseSubscription`订阅的设备（同一`iCloud`账户）分发远程通知

* 数据导入（将远程数据同步到本地）
  1. `NSPersistentCloudKitContainer`创建的后台任务响应云端的`静默推送`
  2. 向云端发送刷新操作要求并附上上次操作的`令牌`
  3. 云端根据每个设备的`令牌`，为其返回自上次刷新后数据库发生的变化
  4. 将远端数据转换成本地数据（删除、更新、添加等）
  5. 由于`视图上下文`的`automaticallyMergesChangesFromParen`属性设置为真，本地数据的变化将自动在`视图上下文`中体现出来

上述步骤中省略了所有技术难点及细节，仅描述了大概的流程。

## 总结 ##

本文中，我们简单介绍了关于`Core Data`、`CloudKit`以及`Core Data with CloudKit`的一点基础知识。在下一篇文章中我们将探讨如何使用`Core Data with CloudKit`实现**本地数据库和私有数据库的同步**。

PS：介绍如何使用 NSPersistentContainer 的文章并不少，但同其他 Core Data 的功能一样，用好并不容易。在两年多的使用中，我便碰到不少问题。借着今年打算在 [【健康笔记 3】](/healthnotes/) 中实现`共享数据库`功能的机会，我最近较系统地重新学习了`Core Data with CloudKit`并对其知识点进行了梳理。希望通过这个系列博文能让更多的开发者了解并使用`Core Data with Cloudkit`功能。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
