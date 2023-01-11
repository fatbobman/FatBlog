---
date: 2021-08-09 08:50
description: 本篇文章中，我们将探讨 Core Data with CloudKit 应用中最常见的场景——将本地数据库同步到 iCloud 私有数据库。
tags: CloudKit,Core Data
title: Core Data with CloudKit（二） —— 同步本地数据库到 iCloud 私有数据库
---

本篇文章中，我们将探讨`Core Data with CloudKit`应用中最常见的场景——将本地数据库同步到`iCloud`私有数据库。我们将从几个层面逐步展开：

* 在新项目中直接支持`Core Data with CloudKit`
* 创建可同步`Model`的注意事项
* 在现有项目`Core Date`中添加`Host in CloudKit`支持
* 有选择的同步数据

> 本文使用的开发环境为`Xcode 12.5`。关于私有数据库的概念，请参阅 [Core Data with CloudKit （一） —— 基础](/posts/coreDataWithCloudKit-1/)。如想实际操作本文内容，需要拥有 [Apple Developer Program](https://developer.apple.com/programs/) 账号。

[Core Data with CloudKit （一） —— 基础](/posts/coreDataWithCloudKit-1/)

[Core Data with CloudKit（二） —— 同步本地数据库到 iCloud 私有数据库](/posts/coreDataWithCloudKit-2/)

[Core Data with CloudKit（三）—— CloudKit 仪表台](/posts/coreDataWithCloudKit-3/)

[Core Data with CloudKit（四）—— 调试、测试、迁移及其他](/posts/coreDataWithCloudKit-4/)

[Core Data with CloudKit（五）—— 同步公共数据库](/posts/coreDataWithCloudKit-5/)

[Core Data with CloudKit （六） —— 创建与多个 iCloud 用户共享数据的应用](/posts/coreDataWithCloudKit-6/)

```responser
id:1
```

## 快速指南 ##

在应用程序中启用`Core Data with CloudKit` 功能，只需要以下几步：

1. 使用`NSPersistentCloudKitContainer`
2. 在`项目 Target`的`Signing&Capablities`中添加`CloudKit`支持
3. 为项目创建或指定`CloudKit container`
4. 在`项目 Target`的`Signing&Capablities`中添加`background`支持
5. 配置`NSPersistentStoreDescription`以及`viewContext`
6. 检查`Data Model`是否满足同步的要求

## 在新项目中直接支持 Core Data with CloudKit ##

在最近几年苹果不断完善`Xcode`的`Core Data 模版`，直接使用自带模版来新建一个支持`Core Data with CloudKit`的项目是最便捷的入手方式。

### 创建新的 Xcode 项目 ###

创建新项目，在项目设置界面勾选`Use Core Data`及`Host in CloudKit`（早期版本为`Use CloudKit`），并设置开发团队（`Team`）

![image-20210806180200853](https://cdn.fatbobman.com/image-20210806180200853-8244122.png)

设定保存地址后，Xcode 将使用预置模版为你生成包含`Core Data with CloudKit`支持的项目文档。

> Xcode 可能会提醒新项目代码有错误，如果觉得烦只需要 Build 一下项目即可取消错误提示（生成 NSManagoedObject Subclass）

接下来，我们根据**快速指南**逐步操作。

### 设置 PersistentCloudKitContainer ###

`Persistence.swift`是官方模版创建的`Core Data Stack`。由于在创建项目的时候已经选择了`Host in CloudKit`，因此模版代码已直接使用`NSPersistentCloudKitContianer`替代`NSPersistentContianer`，无需进行修改。

```swift
let container: NSPersistentCloudKitContainer
```

### 启用 CloudKit ####

点击项目中对应的`Target`，选择`Signing&Capabilities`。点击`+Capability`查找`icloud`添加`CloudKit`支持。

![image-20210806185136390](https://cdn.fatbobman.com/image-20210806185136390-8247097.png)

![image-20210806185247739](https://cdn.fatbobman.com/image-20210806185247739-8247169.png)

勾选`CloudKit`。点击`+`，输入`CloudKit container`名称。Xcode 会在你`CloutKit container`名称的前面自动添加`iCloud.`。`container`的名称通常采用反向域名的方式，无需和项目或`BundleID`一致。*如果没有配置开发者团队，将无法创建`container`。*

![image-20210808091434886](https://cdn.fatbobman.com/image-20210808091434886.png)

*在添加了`CloudKit`支持后，Xcode 会自动为你添加`Push Notifications`功能，原因我们在上一篇聊过。*

### 启用后台通知 ###

继续点击`+Capability`，搜索`backgroud`并添加，勾选`Remote notifications`

![image-20210806190813361](https://cdn.fatbobman.com/image-20210806190813361-8248094.png)

此功能让你的应用程序能够响应云端数据内容变化时推送的**静默通知**。

### 配置 NSPersistentStoreDescription 和 viewContext ###

查看当前项目中的`.xcdatamodeld`文件，`CONFIGURATIONS`中只有一个默认配置`Default`，点击可以看到，右侧的`Used with CloudKit`已经被勾选上了。

![image-20210806193028530](https://cdn.fatbobman.com/image-20210806193028530-8249430.png)

如果开发者没有在`Data Model Editor`中自定义`Configuration`，如果勾选了`Used with CloudKit`，`Core Data`会使用选定的`Cloudkit container`设置``cloudKitContainerOptions`。因此在当前的`Persistence.swift`代码中，我们无需对`NSPersistentStoreDescription`做任何额外设置（我们会在后面的章节介绍如何设置`NSPersistentStoreDescription`）。

在`Persistence.swift`对上下文做如下配置：

```swift
container.loadPersistentStores(completionHandler: { (storeDescription, error) in
       if let error = error as NSError? {
              ...
                fatalError("Unresolved error \(error), \(error.userInfo)")
        }
})
//添加如下代码        
container.viewContext.automaticallyMergesChangesFromParent = true
container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
do {
      try container.viewContext.setQueryGenerationFrom(.current)
} catch {
     fatalError("Failed to pin viewContext to the current generation:\(error)")
}
```

`container.viewContext.automaticallyMergesChangesFromParent = true`让视图上下文自动合并服务器端同步（`import`）来的数据。使用`@FetchRequest`或`NSFetchedResultsController`的视图可以将数据变化及时反应在 UI 上。

`container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy`设定合并冲突策略。如果不设置该属性，`Core Data`会默认使用`NSErrorMergePolicy`作为冲突解决策略（所有冲突都不处理，直接报错），这会导致`iCloud`的数据无法正确合并到本地数据库。

`Core Data`预设了四种合并冲突策略，分别为：

* NSMergeByPropertyStoreTrumpMergePolicy

  逐属性比较，如果持久化数据和内存数据都改变且冲突，持久化数据胜出

* NSMergeByPropertyObjectTrumpMergePolicy

  逐属性比较，如果持久化数据和内存数据都改变且冲突，内存数据胜出

* NSOverwriteMergePolicy

  内存数据永远胜出

* NSRollbackMergePolicy

  持久化数据永远胜出

对于`Core Data with CloudKit`这样的使用场景，通常会选择`NSMergeByPropertyObjectTrumpMergePolicy`。

`setQueryGenerationFrom(.current)`这个是在最近才出现在苹果的文档和例程中的。目的是避免在数据导入期间应用程序产生的数据变化和导入数据不一致而可能出现的不稳定情况。尽管在我两年多的使用中，基本没有遇到过这种情况，但我还是推荐大家在代码中增加上下文快照的锁定以提高稳定性。

> 直到`Xcode 13 beta4`苹果仍然没有在预置的`Core Data with CloudKit`模版中添加上下文的设置，这导致使用原版模版导入数据的行为会和预期有出入，对初学者不很友好。

### 检查 Data Model 是否满足同步的要求 ###

模版项目的 Data Model 非常简单，只有一个`Entity`且只有一个`Attribute`，当下无需做调整。`Data Model`的同步适用规则会在下个章节详细介绍。

![image-20210806204211377](https://cdn.fatbobman.com/image-20210806204211377-8253732.png)

### 修改 ContentView.swift ###

> **提醒**：模版生成的 ContentView.swift 是不完整的，需修改后方能正确显示。

```swift
    var body: some View {
        NavigationView { // 添加 NavigationView
            List {
                ForEach(items) { item in
                    Text("Item at \(item.timestamp!, formatter: itemFormatter)")
                }
                .onDelete(perform: deleteItems)
            }
            .toolbar {
                HStack { // 添加 HStack
                    EditButton()
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        }
    }
```

修改后，可以正常显示 Toolbar 按钮了。

至此，我们已经完成了一个支持`Core Data with CloudKit`的项目了。

### 运行 ###

在模拟器上或实机上**设置并登录相同的`iCloud`账户**，只有同一个账户才能访问同一个`iCloud`私有数据库。

下面的动图，是在一台实机（`Airplay`投屏）和一个模拟器上的运行效果。

![syncToPrivateDB](https://cdn.fatbobman.com/syncToPrivateDB-8292698.gif)

*视频经过剪辑，数据的同步时间通常为 15-20 秒左右。*

从模拟器上进行的操作（添加、删除）通常会在 15-20 秒中左右会反应到实机上；但从实机上进行的操作，则需要将模拟器切换到后台再返回前台才能在模拟器中体现出来（因为模拟器不支持静默通知响应）。如果是在两个模拟器间进行测试，两端都需要做类似操作。

苹果文档对同步+分发的时间描述为不超过 1 分钟，在实际使用中通常都会在 10-30 秒左右。支持批量数据更新，无需担心大量数据更新的效率问题。

当数据发生变化时，控制台会有大量的调试信息产生，之后会有专文涉及更多关于调试方面的内容。

## 创建可同步 Model 的注意事项 ##

要在`Core Data`和`CloudKit`数据库之间完美地传递记录，最好对双方的数据结构类型有一定的了解，具体请参阅 [Core Data with CloudKit （一） —— 基础](/posts/coreDataWithCloudKit-1/)。

`CloudKit Schema`并不支持`Core Data Model`的所有功能、配置，因此在设计可同步的`Core Data`项目时，请注意以下限制，并确保你创建了一个兼容的数据模型。

### Enitites ###

* **`CloudKit Sechma`不支持`Core Data`的唯一限制（`Unique constraints`）**

`Core Data`的`Unique constraints`需要`SQLite`提供支持，`CloudKit`本身并非关系型数据库，因此不支持并不意外。

```swift
CREATE UNIQUE INDEX Z_Movie_UNIQUE_color_colors ON ZMOVIE (ZCOLOR COLLATE BINARY ASC, ZCOLORS COLLATE BINARY ASC)
```

![image-20210807090639166](https://cdn.fatbobman.com/image-20210807090639166-8298400.png)

### Attributes ###

* **不可以有即为`非可选值`又`没有默认值`的属性。允许：可选 、有默认值、可选 + 有默认值**

![image-20210807091044353](https://cdn.fatbobman.com/image-20210807091044353-8298645.png)

上图中的属性 `非 Optional` 且 `没有 Default Value`是不兼容的形式，`Xcode`会报错。

* **不支持`Undefined`类型**
![image-20210808073123665](https://cdn.fatbobman.com/image-20210808073123665-8379084.png)

### Relationships ###

* **所有的 relationship 必须设置为可选（`Optional`）**
* **所有的 relationship 必须有逆向（`Invers`）关系**
* **不支持`Deny`的删除规则**

`CloudKit`本来也有一种类似于`Core Data`关系类型的对象——`CKReference`。不过该对象最多只能支持对应 750 条记录，无法满足大多数`Core Data`应用场景的需要，`CloudKit`采用将`Core Data`的关系转换成`Record Name`（`UUID`字符串形式）逐条对应，这导致`CloudKit`可能不会原子化（`atomically`）地保存关系变化，因此对关系的定义做出了较严格的限制。

在`Core Data`日常始终中，多数的关系定义还是能满足上述的要求。

### Configurations ##

* **实体（`Entity`）不得与其他配置（`Configuration`）中的实体建立`relationship`**

官方文档中这个限制我比较困惑，因为即使不采用网络同步，开发者也通常不会为两个`Configuration`中的实体建立`relationship`。如果需要建立联系，通常会采用创建`Fetched Properties`。

![image-20210807094550677](https://cdn.fatbobman.com/image-20210807094550677-8300752.png)

> 在启用`CloudKit`同步后，如果`Model`不满足同步兼容条件时`Xcode`会报错提醒开发者。在将已有项目更改为支持`Core Data with CloudKit`时，可能需要对代码做出一定的修改。

## 在现有 Core Data 项目中添加 Host in CloudKit 支持 ##

有了模版项目的基础，将`Core Data`项目升级为支持`Core Data with CloudKit`也就非常容易了：

* 使用`NSPersistentCloudKitContainer`替换`NSPersistentContainer`
* 添加`CloudKit`、`background`功能并添加`CloudKit container`
* 配置上下文

以下两点仍需提醒：

### `CloudKit container`无法认证 ###

  添加`CloudKit container`时，有时候会出现无法认证的情况。尤其是添加一个已经创建的`container`，该情况几乎必然发生。

```bash
CoreData: error: CoreData+CloudKit: -[NSCloudKitMirroringDelegate recoverFromPartialError:forStore:inMonitor:]block_invoke(1943): <NSCloudKitMirroringDelegate: 0x282430000>: Found unknown error as part of a partial failure: <CKError 0x28112d500: "Permission Failure" (10/2007); server message = "Invalid bundle ID for container"; uuid = ; container ID = "iCloud.Appname">
```

解决的方法为：登录开发者账户->`Certificates,Identifiers&Profiles`->`Identifiers App IDs`，选择对应的`BundleID`，配置`iCloud`，点击`Edit`，重新配置`container`。

  ![image-20210807100856319](https://cdn.fatbobman.com/image-20210807100856319-8302137.png)

### 使用自定义的`NSPersistentStoreDescription` ###

  有些开发者喜欢自定义`NSPersistentDescription`（即使只有一个`Configuration`）, 这种情况下，需要显式为`NSPersistentDescription`设置`cloudKitContainerOptions`，例如：

```swift
let cloudStoreDescription = NSPersistentStoreDescription(url: cloudStoreLocation)
cloudStoreDescription.configuration = "Cloud"
  
cloudStoreDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "your.containerID")
```

即使不将`Model Editor`中的`Configuration`设置为`Used with CloudKit`，网络同步功能同样生效。勾选`Used with CloudKit`的最大好处是：`Xcode`会帮你检查`Model`是否兼容`CloudKit`。

## 有选择的同步数据 ##

在实际应用中，有某些场景我们想有选择性地对数据进行同步。通过在`Data Model Editor`中定义多个`Configuration`，可以帮助我们实现对数据同步的控制。

配置`Configuration`非常简单，只需将`Entity`拖入其中即可。

### 在不同的 Configuration 中放置不同的 Enitity ###

假设以下场景，我们有一个`Entity`——`Catch`，用于作为本地数据缓存，其中的数据不需要同步到 iCloud 上。

> 苹果的官方文档以及其他探讨 Configuration 的资料基本上都是针对类似上述这种情况

我们创建两个`Configuration`：

* local——`Catch`
* cloud——其他需要同步的`Entities`

采用类似如下的代码：

```swift
let cloudURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
              .appendingPathComponent("cloud.sqlite")
let localURL = FileManager.default.urls(for:.documentDirectory, in:.userDomainMask).first!
              .appendingPathComponent("local.sqlite")

let cloudDesc = NSPersistentStoreDescription(url: cloudURL)
cloudDesc.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "your.cloudKit.container")
cloudDesc.configuration = "cloud"

let localDesc = NSPersistentStoreDescription(url: localURL)
localDesc.configuration = "local"

container.persistentStoreDescriptions = [cloudDesc,localDesc]
```

只有`Configuration cloud`中的`Entities`数据会被同步到`iCloud`上。

*我们不可以在跨`Configuration`的`Entity`之间创建`relationship`，如确有需要可以使用`Fetched Preoperties`达到受限的近似效果*

### 在不同的 Configuration 中放置同一个 Entity ###

如果想对**同一个`Entity`**的数据进行同步控制（部分同步），可以使用下面的方案。

场景如下：假设有一个`Entity`——`Movie`，无论出于什么理由，你只想对其中的部分数据进行同步。

* 为`Movie`增加一个`Attribute`——`local:Bool`（本地数据为`true`，同步数据为`false`）

* 创建两个`Configuration`——`cloud`、`local`，在两个`Configuration`中都添加上`Moive`

* 采用和上面一样的代码，在`NSPersistentCloudKitContainer`中添加两个`Description`

  当`fetch Movie`的时候，`NSPersistentCoordinator`会自动合并处理两个`Store`里面的`Moive`记录。不过当写入`Movie`实例时，协调器只会将实例写到最先包含`Movie`的`Description`，因此需要特别注意添加的顺序。

  比如`container.persistentStoreDescriptions = [cloudDesc,localDesc]`，在`container.viewContext`中新建的`Movie`会写入到`cloud.sqlite`中

* 创建一个`NSPersistentContainer`命名为`localContainer`，只包含`localDesc`（多`container`方案）

* 在`localDesc`上开启`Persistent History Tracking`

* 使用`localContainer`创建上下文写入`Movie`实例（实例将只保存到本地，而不进行网络同步）

* 处理`NSPersistentStoreRemoteChange`通知，将从`localContainer`中写入的数据合并到`container`的`viewContext`中

以上方案需要使用`Persistent History Tracking`，更多资料可以查看我的另一篇文章 [【在 CoreData 中使用持久化历史跟踪】](/posts/persistentHistoryTracking/)。

## 总结 ##

在本文中，我们探讨了如何实现将本地数据库同步到`iCloud`私有数据库。

下一篇文章让我们一起探讨如何使用`CloudKit`仪表台。从另一个角度认识`Core Data with CloudKit`。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
