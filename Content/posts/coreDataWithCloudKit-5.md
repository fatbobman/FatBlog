---
date: 2021-08-13 19:22
description: 本文将介绍如何通过 Core Data with CloudKit 将公共数据库同步到本地，在本地创建 Core Data 数据库镜像。
tags: CloudKit,Core Data
title:  Core Data with CloudKit（五）—— 同步公共数据库
image: images/coreDataWithCloudKit-5.jpg
---

本文将介绍如何通过`Core Data with CloudKit`将公共数据库同步到本地，在本地创建`Core Data`数据库镜像。

[Core Data with CloudKit （一） —— 基础](/posts/coreDataWithCloudKit-1/)

[Core Data with CloudKit（二） —— 同步本地数据库到 iCloud 私有数据库](/posts/coreDataWithCloudKit-2/)

[Core Data with CloudKit（三）—— CloudKit 仪表台](/posts/coreDataWithCloudKit-3/)

[Core Data with CloudKit（四）—— 调试、测试、迁移及其他](/posts/coreDataWithCloudKit-4/)

[Core Data with CloudKit（五）—— 同步公共数据库](/posts/coreDataWithCloudKit-5/)

[Core Data with CloudKit （六） —— 创建与多个 iCloud 用户共享数据的应用](/posts/coreDataWithCloudKit-6/)

```responser
id:1
```

## 三种 CloudKit 数据库 ##

介绍一下`CloudKit`中的三种数据库：

### 公共数据库 ###

公共数据库存放的是开发者希望任何人都能够访问的数据。不可以在公共数据库中添加自定义`Zone`，所有的数据都保存在默认的区域中。无论用户是否有`iCloud`账户，都可以通过应用程序或`CloudKit Web`服务访问其中的数据。公共数据库的内容在`CloudKit`仪表台是可见的。

公共数据库的数据容量计入应用程序的`CloudKit`存储配额。

### 私有数据库 ###

这是`iCloud`用户存储个人数据的地方，用户将不希望公众看到的内容通过应用程序保存在这里。只有在登录了`iCloud`账户后，用户才可以访问其中的数据。默认情况下，只有用户本人才能访问自己的私有数据库中的内容（可将部分内容分享给其他的`iCloud`用户）。用户对数据拥有全部的操作权限（创建、查看、更改、删除）。私有数据库中的数据在`CloudKit`仪表台中是不可见的，对开发者是完全保密的。

开发者可以在私有数据库中创建自定义区域，便于组织管理数据。

 私有数据库的数据容量计入用户的`iCloud`存储配额。

### 共享数据库 ###

`iCloud`用户在共享数据库中看到的数据，是其他的`iCloud`用户共享给你的数据投影，这些数据仍然保存在其他人各自的私有数据库中。你不拥有这些数据，并且只有在拥有必要权限的情况下才能查看和修改内容。只有已经登录了`iCloud`账户，此数据库才可用。

例如你将某条数据共享给某个用户，该数据仍保存在你的私有数据库中，但被共享者由于你的授权可以在他的共享数据库中看到该记录，且只能依据你设定的权限进行操作。

共享数据库中不可以自定义区域。其中的数据在`CloudKit`仪表台中不可见。

共享数据库的容量计入应用程序的`CloudKit`存储配额。

## 一样的名词、不一样的含义 ##

在 [Core Data with CloudKit（二）](/posts/coreDataWithCloudKit-2/) 中，我们介绍了如何同步本地数据库到`iCloud`私有数据库，本篇我们谈的是如果将共享数据库同步到本地。尽管两篇文章都在聊关于**同步**的话题，但这**两个同步的内在含义和逻辑是不一样的**。

**同步本地数据到私有数据库**，本质上讲仍是一个标准的`Core Data`项目，开发者从模型设计到代码开发，同开发【仅支持本地持久化数据库的项目】没有不同。`CloudtKit`仅起到一个将数据同步到用户其他设备的桥梁作用。在绝大多数的情况下，开发者在使用托管对象时可以完全不考虑私有数据库以及`CKRecord`的存在。

将**公共数据库同步到本地**，则完全不同。公共数据库是网络数据库概念。标准逻辑为开发者在`CloudKit`仪表台上创建`Record Type`，通过仪表台或客户端向公共数据库添加`CKRecord`记录，客户端通过访问服务器获取网络数据记录。`Core Data with CloudKit`方便我们利用已有的`Core Data`知识来完成这一过程。同步到本地的数据，是服务器端公共数据库的镜像，在本地通过对托管对象数据的操作间接完成对服务器端`CKRecord`记录的操作。

> 后面讨论的鉴权，尽管操作对象为托管对象或本地持久化存储，但检查的却是网络端的记录或数据库。

## 公共数据库 vs 私有数据库 ##

我们从几个维度来比较一下公共数据库和私有数据库。

### 鉴权 ###

在不考虑数据共享的情况下，私有数据库中的数据只有用户自己（已登录`iCloud`账户）可以访问。用户作为数据的创建者拥有所有的操作权限。私有数据库的鉴权规则非常简单：

![image-20210812153836921](https://cdn.fatbobman.com/image-20210812153836921-8753918.png)

在 [iCloud 仪表台](/posts/coreDataWithCloudKit-3/) 一文中，我们介绍了安全角色的概念。系统为公共数据库创建了 3 个预置角色：`World`、`Authenticated`以及`Creator`。在公共数据库中，鉴权时需要考虑用户是否已登录`iCloud`账户、是否为数据记录的创建者等多种因素。

![image-20210812154950463](https://cdn.fatbobman.com/image-20210812154950463-8754592.png)

* 每个用户都可以读取记录（无论是否登录账户）
* 每个已登录账户的用户都可以创建记录
* 已登录用户只能修改或删除自己创建的记录

通过标准`CloudKit API`来判断权限除了代码量较多外，鉴权时间也较长（每次都需要访问服务器才能获得结果）。`Core Data with CloudKit`通过在本地备份`CKRecord`的元数据的方式，完美解决了鉴权效率问题，并提供了便捷`API`供开发者调用。

我们可以通过类似的代码来判断，用户是否对当前的托管对象（`ManagedObject`）有修改删除的权限：

```swift
let container = PersistenceController.shared.container

if container.canUpdateRecord(forManagedObjectWith:item.objectID) {
    // 修改或删除 itme
}
```

最近两年，苹果不断提升`NSPersistentCloudKitContainer`的存在感，为它添加了不少重要的方法。这些方法不仅可以用于公共数据库或其中的托管对象，还可以用于其他类型的数据库或数据（私有数据库、本地数据库、共享数据等）。

* `canUpdateRecord`和`canDeleteRecord`

  获取是否具有修改数据的权限。在以下情况都将返回 true：

  1. `objectID`是临时对象标识符（意味着还没有被持久化）。
  2. 包含托管对象的持久化存储不适用`CloudKit`（不用于同步的本地数据库）。
  3. 持久化存储管理私有数据库（用户对私有数据库拥有全部权限）
  4. 持久化存储管理公共数据库，并且用户是该记录的创建者，或者`Core Data`尚未将托管对象更新到`iCloud`中。
  5. 持久化存储管理共享数据库，并且用户拥有更改数据的权限。

  *实际使用中`canDeleteRecord`返回的结果不准，目前推荐大家只使用`canUpdateRecord`*

  **`canUpdateRecord`返回`false`，并非意味着你无法从本地存储删除数据，只意味你并不拥有该托管对象对应的网络记录的修改权限**。

* `canModifyMangedObject(in:NSPersistentStore)`

  指示是否可以可以更改特定的持久化存储。

  使用此方法确定用户能否将记录写入`CloudKit`数据库。比如当用户没有登录`iCloud`账户时，无法写入管理公共数据库的持久化存储。
  
  **同样的`canModifyManagedObjects`返回`false`，也并非意味着你不可以在本地的`sqlite`文件中写入数据，仅意味着你不拥有对该持久化存储对应的网络存储的修改权限**。

> 由于本地数据和持久化存储是没有权限概念的，开发者很可能编写出尽管没有网络端的权限但仍在本地进行了错误操作的代码。这在同步公共数据库和同步共享数据库的项目中是十分危险的。如果你对一个没有网络端权限的数据记录进行了修改或删除，网络端会拒绝你的请求，`Core Data with CloudKit`在收到拒绝后会停止之后所有同步工作。因此**在编写同步公共数据库或共享数据库的项目时，必须在确保拥有对应的权限后再对数据进行操作**。

### 同步机制 ###

从`export`（将本地数据更改同步至服务器）这一侧讲，无论是同步私有数据库还是公共数据库，表现都是一样的。`Core Data with CloudKit`会在本地数据发生变化后，立即将变化同步给服务器。是一种即时的单向行为。

从`import`（将网络数据的更改同步至本地）角度来将，私有数据库和公共数据库的机制则完全不同。

在 [基础](/posts/coreDataWithCloudKit-1/) 和 [CloudKit 仪表台](/posts/coreDataWithCloudKit-3/) 两篇文章，我们已经介绍了私有数据库的同步机制：

* 客户端在服务器订阅`CKDatabaseSubscription`
* 服务器端在私有数据库自定义`Zone`的内容发生变化后，向客户端推送静默远程提醒
* 客户端收到提醒后，通过`CKFetchRecordZoneChangesOperation`向服务器端请求变更数据
* 服务器端在比对令牌后，将令牌更新的变动数据同步给客户端

整个过程有来有往，两方配合共同完成。

由于公共数据库的一些技术限制，上述的机制无法适用于公共数据库的同步。

* 公共数据库不能自定义`Zone`
* 没有自定义`Zone`则不能订阅`CKDatabaseSubscription`
* `CKFetchrecordZoneChangesOperation`利用了私有数据库的专有技术，公共数据库只能采用`CKQureyOperation`
* 公共数据库没有墓碑机制，无法记录全部的用户操作（删除）

由于上述原因，`Core Data with CloudKit`只能采用轮询方式（`poll for changes`）来获取公共数据库的变化数据。

当应用程序启动时或每运行 30 分钟，`NSPersistentCloudKitContainer`都会通过`CKQurey`操作来查询公共数据库的变化并进行获取数据。`import`过程是由客户端发起，服务器端响应。

此种同步机制将限制适用场景，**只有即时性不高的数据才适合保存在公共数据库中**。

### 数据模型 ###

由于同步机制不同，在为公共数据库设计数据模型时须考虑以下几点：

* **复杂度**

  公共数据库使用`CKQureyOperation`查询自上次以来的服务器端变化，它的效率远低于`CKFetchRecordZoneChangesOperation`。如果能控制`ManagedObjectModel`的实体、属性数量则查询所需的`Request`越少，执行效率越高。如无特殊需要，应尽可能减少公共数据库的模型复杂度。

* **墓碑**

  私有数据库在收到客户端发送的记录删除操作后，会立即将服务器端的记录删除，并保存删除操作的墓碑标志。其他的客户端设备通过`CKFetchRecordZoneChangesOperation`获取变更时，私有数据库将变更记录（包括墓碑）一并发送给客户端。客户端根据墓碑指示删除掉本地对应的数据记录，从而保证数据的一致性。

  公共数据库也会在收记录删除操作后，立即删除掉服务器端的记录。不过由于公共数据库没有墓碑机制，因此当其他的客户端向它查询是否有数据变化时，公共数据库只会将新增或更改的记录变化告诉客户端设备，无法将删除操作通知给客户端。这意味着，我们无法将删除操作从一个设备传递给另一个设备，两个设备的公共数据库本地镜像将出现差异。

  我们在设计公共数据库数据模型时，通过添加一个类似墓碑（比如`isDeleted`）的属性，尽可能地避免这种差异。

```swift
// "删除"时，将 isDelete 设置为 true
if container.canUpdateRecord(forManagedObjectWith:item.objectID){
    item.isDeleted = true
    try! viewContext.save()
}
```

 调用数据时，只获取`isDeleted`为`false`的记录。

```swift
@FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        predicate: NSPredicate(format: "%K = false", #keyPath(Item.isDelete)),
        animation: .default
)
private var items: FetchedResults<Item>
```

> 记录并没有被真正删除，只是被屏蔽了。公共数据库可以将记录修改操作在设备间传递，在保证了设备之间数据一致同时，也实现了对数据的"删除"。被"删除"的数据在本地和服务器端仍然占据空间，需谨慎地选择清空其占据空间的时机。

### 存储配额 ###

私有数据库的数据是保存在用户个人的`iCloud`空间中的，占用的是其个人空间的容量配额。如果该用户的`iCloud`空间满了，数据将不能够继续通过网络在各个设备间进行同步。用户可以通过清理个人空间或选择更大的空间方案来解决这个问题。

公共数据库的数据容量占用的是你的应用程序的空间配额。苹果给每一款支持`CloudKit`的应用都提供了基础的空间容量，限制如下：10GB 的`Asset`存储，100MB 的数据库，每月 2GB 数据传输量以及每秒 40 次的查询请求。空间、流量、请求数都会根据你应用程序的活跃用户数（16 月内使用过应用）的提高而提高，至多会增加到 10PB、10TB、每天 200TB 的级别。

尽管绝大多数的应用程序都不会超过这些限额，但是作为开发者还是应该尽可能的减少空间的使用量，提高数据响应效率。

`Core Data with CloudKit`对公共数据库的同步是将整个公共库在本地保存一个镜像，因此，如果不能很好的控制数据量，应用程序对用户设备的占用将十分恐怖。上文采取的"删除"方法还将进一步侵占网络和设备空间。

开发者在项目设计之初就应该考虑好清空伪"删除"数据的时机。

我们无法保证清空一定会发生在所有的客户端都已经同步了"删除"状态，在不影响应用程序业务逻辑的情况下，适当允许设备间的数据不一致是可以接受的。

开发者可以根据应用程序的平均使用频率，在客户端对一定时间前"删除"的数据进行清除操作。尽管`Core Data with CloudKit`在本地保存了托管对象对应的`CKRecord`元数据，但没有给开发者提供 API。为了删除方便，我们可以在模型中添加"删除"时间属性，配合清除时的查询工作。

## 公共数据库的适用场合 ##

通过`CloudKit`调用公共数据库和通过`Core Data with CloudKit`同步公共数据库两者的技术特点不同，考虑的侧重点也不一样。

我个人推荐以下几种场合适于使用`Core Data with CloudKit`同步公共数据库：

* 只读不写

  比如提供模版、初始数据、新闻提醒等。

  公共数据库数据的创建、修改、删除均由开发者通过仪表台或特定的应用操作，用户的应用程序仅读取公共数据库的内容，不创建也不更改。

* 仅处理一条记录

  应用程序仅创建一条和用户或设备关联的数据，并仅对该条数据进行内容更新。

  通常应用在记录和设备关联的状态或用户（可关联）的状态或 数据。例如游戏高分排行榜（仅保存用户的最高分数）。

* 只创建不修改

  日志类的场景。用户负责创建数据，并不特别依赖数据本身。应用程序定期清除掉本地的过期数据。通过`CloudKit Web`服务或其他的特定应用对公共数据库记录进行查询或备份并定期清除。

> 开发者在考虑使用`Core data with CloudKit`同步公共数据库数据时，一定要仔细考虑各方利弊，选择合适的应用场景。

## 同步公共数据库 ##

本节大量涉及了 [Core Data with CloudKit（二）——同步本地数据库到 iCloud 私有数据库](/posts/coreDataWithCloudKit-2/) 和 [Core Data with CloudKit（三）——CloudKit 仪表台](/posts/coreDataWithCloudKit-3/) 中的知识，请阅读上述两篇文章后再继续。

### 项目配置 ###

在项目中配置公共数据库同配置私有数据库几乎完全一致。

* 在项目`Target`的`Signing&Capabilities`中添加`iCloud`
* 选择`CloudKit`并添加`Container`

*如果在项目中仅使用公共数据库，可以不添加`Background Mode`的`Remote notifications`功能*

### 使用 NSPersistentCloudKitContainer 创建本地镜像 ###

* 在`Xcode Data Model Editor`中创建新的`Configuration`，并将你想公开的实体（`Entity`）添加到这个新配置中。
* 在你的`Core Data Stack`中（比如模版项目的`Persistenc.swift`）添加如下代码：

```swift
let publicURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("public.sqlite")
let publicDesc = NSPersistentStoreDescription(url: publicURL)
publicDesc.configuration = "public" //Configuration 名称
publicDesc.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "your.public.containerID")
publicDesc.cloudKitContainerOptions?.databaseScope = .public
```

代码非常熟悉？那就对了。事实上，同步公共数据库只比同步私有数据库多了一行代码：

```swift
publicDesc.cloudKitContainerOptions?.databaseScope = .public
```

> `databaseScope`是苹果 2020 年为`cloudKitContainerOptions`新添加的属性。默认值为`.private`，因此同步私有库时无需设置。

就这？

是的，就这。其他配置都和同步私有数据库一样。将`Descriptioin`添加到`persistentStoreDescriptions`，配置上下文，有需要的话配置 [Persistent History Tracking](/posts/persistentHistoryTracking/)。

### 配置仪表台 ###

由于`NSPersistentCloudKitContainer`对公共数据的获取方式（`CKQurey`）和对私有数据的获取方式（`CKFetchRecordZoneChangesOperation`）不同，我们还需要在`CloudKit`仪表台上对`Schema`进行一定的修改，才能保证程序的正常运行。

在`CloudKit`仪表台中，选择`Indexes`，为**每个**用于公共数据库的`Record Type`添加两个索引：

![image-20210813153127111](https://cdn.fatbobman.com/image-20210813153127111-8839888.png)

> 在写本文的时候，当我使用`Xcode 13 beta5`构建演示项目时发现，还需要再增加一个索引才能正常同步公共数据库。如果你使用`Xcode 13`请在仪表台多添加一个索引`Sortable`。

![image-20210813153521321](https://cdn.fatbobman.com/image-20210813153521321-8840122.png)

## 其他 ##

### 初始化 Schema ###

**按照上文操作，进行至在`CloudKit`仪表台上添加索引时，你会发现没有`Record Type`供你添加索引。这是因为我们并没有在网络数据库端初始化`Schema`。**

在网络端初始化 Schema 有两种方法：

* 创建一个托管对象数据并将其同步到服务器端

  服务器在收到数据后，如发现没有对应的`Record Type`会自动为其创建

* 使用`initializeCloudKitSchema`

  `initializeCloudKitSchema`让我们可以在不创建数据的情况下就可以在服务器端初始化`Schema`。在`Core Data Stack`中添加下面代码：

```swift
try! container.initializeCloudKitSchema(options: .printSchema)
```

运行项目后，我们就可以在仪表台上看到项目中对应的`Record Type`了。

**该代码只需执行一次，在初始化后将其删除或注释掉。**

另外我们也可以在单元测试中使用`initializeCloudKitSchema`验证`Model`是否符合同步模型的兼容需求。

```swift
let result = try! container.initializeCloudKitSchema(options: .dryRun)
```

符合兼容需求`result`为真。`.dryRun`意味着仅在本地检查，并不在服务器端实际初始化。

### 多容器、多配置 ###

在之前的文章我们已经提及，可以在一个项目中关联多个`CloudKit`容器，一个容器也可以对应多个应用程序。

如果你的项目同时使用私有数据库和公共数据库，并且两个容器不一致，除了在项目中对两个容器都进行关联外，在代码中，也需要为`Description`设置正确的`ContainerID`。

```swift
let publicDesc = NSPersistentStoreDescription(url: publicURL)
publicDesc.configuration = "public"
publicDesc.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "public.container")
publicDesc.cloudKitContainerOptions?.databaseScope = .public

let privateDesc = NSPersistentStoreDescription(url: privateURL)
privateDesc.configuration = "private"
privateDesc.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "private.container")
```

公共数据库的`NSPersistentStoreDescription`的`URL`同私有数据库的`URL`必须是不同的（也就是要创建两个`sqlite`文件），协调器无法多次加载同一个`URL`。

```swift
let publicURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("public.sqlite")

let privateURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("private.sqlite")
```

### Xcode13 beta ###

`Xcode 13 beta`好像对`CloudKit`模块做了未公开的调整。在`Xcode 13 beta5`下使用`Core Data with CloudKit`会出现很多奇怪的警告。现阶段，最好使用`Xcode 12`来进行本文测试。

## 总结 ##

`本地数据同步至私有数据库`和`同步公共数据库`在代码中的实现是极为相似的，开发者不要被这种假象所迷惑，一定要认清同步机制的本质，这样才能更好的设计数据模型，规划业务逻辑。

我将在`Xcode 13`稳定后继续完成本系列的下一篇——同步共享数据库。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
