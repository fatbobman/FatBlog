---
date: 2021-08-11 07:50
description: 本文聊一下在开发 Core Data with CloudKit 项目中常见的一些问题，让大家少走弯路、避免踩坑。
tags: CloudKit,Core Data
title: Core Data with CloudKit（四）—— 调试、测试、迁移及其他
---
本文聊一下在开发`Core Data with CloudKit`项目中常见的一些问题，让大家少走弯路、避免踩坑。

[Core Data with CloudKit （一） —— 基础](/posts/coreDataWithCloudKit-1/)

[Core Data with CloudKit（二） —— 同步本地数据库到 iCloud 私有数据库](/posts/coreDataWithCloudKit-2/)

[Core Data with CloudKit（三）—— CloudKit 仪表台](/posts/coreDataWithCloudKit-3/)

[Core Data with CloudKit（四）—— 调试、测试、迁移及其他](/posts/coreDataWithCloudKit-4/)

[Core Data with CloudKit（五）—— 同步公共数据库](/posts/coreDataWithCloudKit-5/)

[Core Data with CloudKit （六） —— 创建与多个 iCloud 用户共享数据的应用](/posts/coreDataWithCloudKit-6/)

```responser
id:1
```

## 控制台日志信息 ##

![log](https://cdn.fatbobman.com/log.gif)

一个支持`Core Data with CloudKit`的项目，控制台输出将常态化地成为上图状态。

每个项目面对的情况不同且信息中的废话较多，因此我仅就可能的信息种类做一下归纳。

### 正常情况的信息 ###

* **初始化信息**

  代码启动后，通常首先出现在控制台的便是`NSPersistentCloudKitContainer`展示的初始化信息。包括：成功在指定`url`创建了容器，成功启用了`NSCloudKitMirroringDelegate`同步响应等。如果是首次运行项目，还会有成功在`iCloud`上创建了`Schema`之类的提示。

* **数据模型迁移信息**

  如果本地和服务器端的数据模型不一致，会出现迁移提醒。有时即使本地的`Core Data`模型和`iCloud`上的模型一致，也会看到类似`Skipping migration for 'ANSCKDATABASEMETADATA' because it already has a column named 'ZLASTFETCHDATE'`之类的信息，表示无需迁移。

* **数据同步信息**

  会详细描述导入、导出的具体的内容，信息比较好理解。应用程序端或服务器端任何数据发生变动都会出现对应的信息。

* **持久化历史跟踪信息**

  `NSPersistentCloudKitContainer`使用持久化历史跟踪来管理导入导出事务，在数据同步信息的左右经常会伴随包含`NSPersistentHistoryToken`之类的提示。另外类似`Ignoring remote change notification because the exporter has already caught up to this transaction: 11 / 11 - <NSSQLCore: 0x7ff73e4053b0>`的信息也是持久化历史跟踪产生的，容易让人误以为总有事务没有处理。关于`Persistent History Tracking`可以阅读我另一篇文章 [在 CoreData 中使用持久化历史跟踪](/posts/persistentHistoryTracking/)。

### 可能的不正常情况的信息 ###

* **初始化错误**

  比较常见的有，无法创建或读取`sqlite`文件产生的本地`url`错误以及`CKContainerID`权限问题。如果`url`指向`appGroupContainer`，一定要确认`appGroupID`正确，且`app`已获得`group`权限。`CKContainerID`权限问题通常使用 [之前文章](/posts/coreDataWithCloudKit-2/) 中提到的重置`Certificates,Identifiers&Profiles`中的配置来解决。

* **模型迁移错误**

  正常情况下，`Xcode`不会让你生成同`CloudKit`的`Schema`不兼容的`ManagedObjectModel`，所以多数情况下，都是由于在开发环境下，本地的数据模型和服务器端的数据模型不匹配导致的问题（比如更改了某个属性名称、或者使用了较老的开发版本等）。在确认代码版本正确的情况下，可采取删除本地`app`，重置`CloudKit`端开发环境的方法来解决。但如果你的应用程序已经上线，应尽量避免此类问题的发生可能。请考虑后文中的更新数据模型提供的模型迁移策略。

* **合并冲突**

  请检查是否设置了正确的合并冲突策略`NSMergeByPropertyObjectTrumpMergePolicy`？是否从`CloudKit`控制台对数据做出了错误的修改？如仍处于开发阶段，可采用和上面一样的方式解决。

* **iCloud 账号或网络错误**

  `iCloud`没登录，`iCloud`服务器没响应，iCloud 账号受限等。以上问题多数都是开发人员这端无法解决的。`NSPersistentCloudKitContainer`会在`iCloud`账户登录后自动恢复同步。在代码中进行账号状态检查，并提醒用户登录账号。

## 关闭日志输出 ##

在确认同步功能代码已正常工作的情况下，如无法忍受控制台的信息轰炸，可尝试关闭`Core Data with CloudKit`的日志输出。调试任何使用`Core Data`的项目，我都推荐大家为项目添加如下的默认参数：

![image-20210810152755744](https://cdn.fatbobman.com/image-20210810152755744-8580476.png)

* **-com.apple.CoreData.ConcurrencyDebug**

  及时发现由托管对象或上下文线程错误而导致的问题。执行任何可能导致错误的代码时，应用程序会立刻崩溃，帮助在开发阶段清除隐患。启用后，控制台会显示`CoreData: annotation: Core Data multi-threading assertions enabled.`

* **-com.apple.CoreData.CloudKitDebug**

  `CloudKit`调试信息输出级别，从 1 开始，数字越大信息愈详尽

* **-com.apple.CoreData.SQLDebug**

  `CoreData`发送到`SQLite`的实际`SQL`语句，1——4，数值越大越详细。输出提供的信息在调试性能问题时很有用——特别是它可以告诉你什么时候 `Core Data` 正在执行大量的小提取（例如当单独填充`fault`时）。

* **-com.apple.CoreData.MigrationDebug**

  迁移调试启动参数将使您在控制台中了解迁移数据时的异常情况。

* **-com.apple.CoreData.Logging.stderr**

  信息输出开关

设置`-com.apple.CoreData.Logging.stderr 0`，所有的同数据库有关日志信息都将不再输出。

## 关闭网络同步 ##

在程序开发阶段，我们有时候并不想被数据同步所打扰。增加网络同步控制参数方便提高专注力。

当`NSPersistentCloudKitContainer`载入没有配置`cloudKitContainerOptions`的`NSPersistentStoreDescription`时，它的行为同`NSPersistentContainer`是一致的。通过使用类似下面的代码，可在调试中控制是否启用数据网络同步功能。

```swift
let allowCloudKitSync: Bool = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(where: {$0 == "-allowCloudKitSync"}),
              index + 1 < arguments.count - 1 else {return true}
        return arguments[index + 1] == "1"
    }()

if allowCloudKitSync {
            cloudDesc.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.fatobman.blog.SyncDemo")
        } else {
            cloudDesc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            cloudDesc.setOption(true as NSNumber,
                                forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
```

因为`NSPersistentCloudKitContiner`会自动启用持久化历史跟踪的，如没有设置`NSPersistentCloudKitContainerOptions`，必须在代码中显式启用`Persistent History Tracking`，否则数据库会变成只读。

![image-20210810155946312](https://cdn.fatbobman.com/image-20210810155946312-8582387.png)

设置为`0`将关闭网络同步。

本地数据库的更改在恢复同步功能后，仍将会同步到服务器端。

## 同步不正常 ##

当网络同步不正常时，请先尝试做以下检查：

* 网络连接是否正常
* 设备是否已登录`iCloud`账户
* 同步私有数据库的设备是否登录的是同一个`iCloud`账号
* 检查日志，是否有错误提示，尤其是服务器端的
* 模拟器不支持后台静默推送，将模拟器中的`app`切换至后台再切换回来，看看是否有数据

如果还是找不到原因的话，请泡壶茶、听听歌、看看远方，过一会可能就好了。

苹果服务器抽风的频率并不低，推送延迟不必惊讶。

## 检查用户账户状态 ##

`NSPersistentCloudKitContainer`会在`iCloud`账号可用时自动恢复网络同步。通过代码检查用户的`iCloud`账户登录情况，在应用程序中提醒用户进行账户登录。

调用`CKContainer.default().accountStatus`检查用户`iCloud`账号状态，订阅`CKAccountChanged`，在登录成功后取消提醒。譬如

```swift
    func checkAccountStatus() {
        CKContainer.default().accountStatus { status, error in
          DispatchQueue.main.async {
            switch status {
            case .available:
               accountAvailable = true
            default:
               accountAvailable = false
            }
            if let error = error {
                print(error)
            }
          }
        }
    }
```

## 检查网络同步状态 ##

`CloudKit`没有提供详尽的网络同步状态`API`，开发者无法获得例如有多少数据需要同步、同步进度等信息。

`NSPersistentCloudKitContainer`提供了一个`eventChangedNotification`通知，该通知将在`import`、`export`、`setup`三种状态切换时提醒我们。严格意义上，我们很难仅通过切换通知来判断当前同步的实际状态。

在实际的使用中，对用户感知影响最大的是数据导入状态。当用户在新设备上安装了应用程序，并且已经在网络上保存有较多数据时，面对完全没有数据的应用程序用户会感到很茫然。

数据会在应用程序启动后 20-30 秒开始导入，如果数据量较大，用户很可能会在 1-2 分钟后才会在 UI 上看到数据（批量导入通常会在整批数据都导入后才会`merge`到上下文中）。因此为用户提供足够的提示尤为重要。

在实际使用中，当导入状态结束后，会切换到其他的状态。利用类似如下的代码，尝试给用户提供一点提示。

```swift
@State private var importing = false
@State private var publisher = NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)

var body:some View{
  VStack{
     if importing {
        ProgressView()
     }
  }
  .onReceive(publisher){ notification in
     if let userInfo = notification.userInfo {
        if let event = userInfo["event"] as? NSPersistentCloudKitContainer.Event {
            if event.type == .import {
              importing = true
            }
            else {
              importing = false
            }
         }
      }
   }  
}
```

> 当应用程序被切到后台时，同步任务仅能继续执行 30 秒左右，在切换回前台后数据会继续进行同步。因此当数据较多时，需做好用户的提示工作（比如保持在前台，或让用户继续等待）。

## 创建默认数据集 ##

有的应用程序会为用户提供一些默认的数据，比如说起始数据集，或者演示数据集。如果提供的数据集是放置在可同步的数据库中时需要谨慎处理。比如，已经在一台设备上创建了默认数据集并进行了修改，当在新设备上再次安装并运行应用程序时，处理不当可能导致数据被异常覆盖，或者重复。

* **确认数据集是否一定需要被同步**

  如无需同步可以考虑采用 [同步本地数据库到 iCloud 私有数据库](/posts/coreDataWithCloudKit-2/) 一文中，有选择的同步数据解决方案。

* **如数据集必须要同步**

  1. 最好引导用户手动点击创建默认数据按钮，让用户自行判断是否需要再度创建。

  2. 也可在应用程序首次运行时，利用`CKQuerySubscription`通过查询特定记录判断网络数据库中是否已有数据（此方法是在前几天和一个网友交流时他采用的方法，不过该网友对返回响应并不满意，用户感知不太好）。
  3. 或许可考虑通过使用`NSUbiquitousKeyValueStore`进行判断。

> 2、3 两种方式都需要保证网络及账号状态正常的情况下才能检查，让用户自行判断或许最为简单。

## 移动本地数据库 ##

已经在`AppStore`上架的应用程序，在某些情况下有移动本地数据库到其他`URL`的需求。比如，为了让`Widget`也可以访问数据库，我将 [健康笔记](https://www.fatbobman.com/project/healthnotes/) 的数据库移动到了`appGroupContainerURL`。

如果使用`NSPersistentContainer`，可以直接调用`coordinator.migratePersistentStore`即可安全完成数据库文件的位置转移。但如果对`NSPersistentCloudKitContainer`加载的`store`调用此方法，则必须强制退出应用程序后再次进入方可正常使用（虽然数据库文件被转移，但迁移后会告知加载`CloudKit container`错误，无法进行同步。需重启应用程序才能正常同步）。

因此正确的移动方案是，在创建`container`之前，采用`FileManager`将数据库文件移动到新位置。需同时移动`sqlite`、`sqlite-wal`、`sqlite-shm`三个文件。

类似如下代码：

```swift
func migrateStore() {
        let fm = FileManager.default
        guard !FileManager.default.fileExists(atPath: groupStoreURL.path) else {
            return
        }

        guard FileManager.default.fileExists(atPath: originalStoreURL.path) else {
            return
        }

        let walFileURL = originalStoreURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
        let shmFileURL = originalStoreURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
        let originalFileURLs = [originalStoreURL, walFileURL, shmFileURL]
        let targetFileURLs = originalFileURLs.map {
            groupStoreURL
                .deletingLastPathComponent()
                .appendingPathComponent($0.lastPathComponent)
        }

        // 将原始文件移动到新的位置。
        zip(originalFileURLs, targetFileURLs).forEach { originalURL, targetURL in
            do {
                try fm.moveItem(at: originalURL, to: targetURL)
            } catch error {
                print(error)
            }
        }
}
```

## 更新数据模型 ##

在 [CloudKit 仪表台](/posts/coreDataWithCloudKit-3/) 一文，我们已经探讨过`CloudKit`的两种环境设置。一旦将`Schema`部署到生产环境，开发者便无法对记录类型和字段进行重命名或者删除。**必须仔细规划你的应用程序，保证其在对数据模型进行更新时仍做到向前兼容**。

不可以随心所欲地修改数据模型，对实体、属性尽量做到：只加、不减、不改。

可以考虑以下的模型更新策略：

### 增量更新 ###

以增量的方式添加记录类型或向现有记录类型添加新字段。

采用这种方式，旧版本的应用程序仍可以访问用户创建的记录，但不是每个字段。

请确保新增的属性或实体都只服务于新版本的新功能，且即使没有这些数据，新版本程序仍可可正常运行（如此时用户仍使用旧版本更新数据，新添加的实体和属性都不会有内容）。

### 增加 version 属性 ###

这个策略是上一个策略的加强版。通过一开始在实体上添加`version`属性，对实体进行版本控制，通过谓词仅提取与应用程序当前版本兼容的记录。旧版本程序将不会提取新版本创建的数据。

例如，实体`Post`具备`version`属性

```swift
// 当前的数据版本。
let maxCompatibleVersion = 3

context.performAndWait {
    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Post")
    
    // 提取不大于当前版本的数据
    fetchRequest.predicate = NSPredicate(
        format: "version <= %d",
        argumentArray: [maxCompatibleVersion]
    )
    
    let results = context.fetch(fetchRequest)
}
```

### 锁定数据，提示升级 ###

利用`version`属性，应用程序可以很容易知道当前的版本已经不满足数据模型的需要。它可以禁止用户修改数据，并提示用户更新应用程序版本。

### 创建新 CKContainer 及新的本地存储 ###

如果你的数据模型发生了巨大的变化，采用上述方式已经很难处理，或者上述方式会造成巨大的数据浪费时，可以为应用程序添加一个新的关联容器，并通过代码将原始数据转移到新容器上。

大概的流程为：

* 在应用程序中添加新的`xcdatamodeld`（此时应该有两个模型，旧模型对应旧容器，新模型对应新容器）
* 为应用程序添加新的关联容器（同时使用两个容器）
* 判断是否已经迁移，如果没有迁移则让应用程序通过旧模型和容器正常运行
* 让用户选择迁移数据（提醒用户须确保旧数据都已经同步到本地再执行迁移）
* 通过代码将旧数据转移到新容器和本地存储中，标记迁移完成（使用两个`NSPersistentCloudKitContainer`）
* 切换数据源

> 无论采用上述哪种策略，都应该不计一切代价避免数据丢失、混乱。

## 总结 ##

本文中的问题，是我在开发过程中碰到并已尝试解决的。其他的开发者还会碰到更多的未知情况，只要能掌握其规律，总是可以找到解决之法。

在下一篇文章中，我们聊一下**同步公共数据库**

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
