---
date: 2022-07-26 08:12
description: 在 WWDC 2019 上，苹果推出了 Core Data with CloudKit API ，极大地降低了 Core Data 数据的云同步门槛。由于该服务对于开发者来说几乎是免费的，因此在之后的几年中，越来越多的开发者在应用中集成了该服务，并为用户带来了良好的跨设备、跨平台的使用体验。本文将对实时切换 Core Data 云同步状态的实现原理、操作细节以及注意事项进行探讨和说明。
tags: Core Data,CloudKit
title: 实时切换 Core Data 的云同步状态
image: images/real-time-switching-of-cloud-syncs-status.png
---
在 WWDC 2019 上，苹果推出了 Core Data with CloudKit API ，极大地降低了 Core Data 数据的云同步门槛。由于该服务对于开发者来说几乎是免费的，因此在之后的几年中，越来越多的开发者在应用中集成了该服务，并为用户带来了良好的跨设备、跨平台的使用体验。本文将对实时切换 Core Data 云同步状态的实现原理、操作细节以及注意事项进行探讨和说明。

> 如果你对 Core Data with CloudKit 尚不了解，请阅读我写的 [有关 Core Data with CloudKit 的系列文章](https://www.fatbobman.com/posts/coreDataWithCloudKit-1/)

```responser
id:1
```

## 非实时切换

所谓非实时切换是指：对 Core Data 云同步状态的修改并不能立即生效，同步状态只有在应用再次冷启动后才会发生改变。如果对同步状态切换的实时性没有迫切的需求，那么应该以此种切换方式为首选。

### 不设置 cloudKitContainerOptions

开发者通过对 NSPersistentStoreDescription 的 cloudKitContainerOptions 属性进行设置，让 NSPersistentStoreDescription（ 在 Data Model Editor 中通过 Configuration 创建 ） 中的持久化存储与某个 CloudKit container 关联起来。如果我们不对 cloudKitContainerOptions 进行设置（ 或设置为 nil ），那么 NSPersistentCloudKitContainer 将不会在此 NSPersistentStoreDescription 上启用网络同步功能。我们可以利用这一点来设置 NSPersistentCloudKitContainer 的同步状态。

> 由于对 NSPersistentStoreDescription 的设置必须在 loadPersistentStores 之前完成，因此使用此种方式进行的状态设置，通常会在应用的下次冷启动后生效（ 理论上，也可以通过创建新的 NSPersistentCloudKitContainer 实例来实现，但在单 container 的情况下，为了保证托管对象上下文中数据的完整性，需要照顾太多的可能性，难度较高 ）。

```swift
lazy var container:NSPersistentCloudKitContainer = {
    let container = NSPersistentCloudKitContainer(name: "Model")
    let enableMirror = UserDefaults.standard.bool(forKey: "enableMirror")
    if enableMirror {
        container.persistentStoreDescriptions.first?.cloudKitContainerOptions = .init(containerIdentifier: "YourCloudKitContainerID")
    }
    // 其他设定
    container.loadPersistentStores{ desc,error in
        // ..
    }
    // 其他设定
    return container
}()
```

### 统一成 NSPersistentContainer

如果你的应用只使用了同步私有数据库的功能，那么也可以利用 NSPersistentCloudKitContainer 是 NSPersistentContainer 的子类这一事实，来达到类似的目的：

```swift
lazy var container1:NSPersistentContainer = {
    let container:NSPersistentContainer
    let enableMirror = UserDefaults.standard.bool(forKey: "enableMirror")
    if enableMirror {
        container = NSPersistentCloudKitContainer(name: "Model")
        container.persistentStoreDescriptions.first?.cloudKitContainerOptions = .init(containerIdentifier: "YourCloudKitContainerID")
    } else {
        container = NSPersistentContainer(name: "Model")
    }
    // 其他设定
    container.loadPersistentStores{ desc,error in
        // ..
    }
    // 其他设定
    return container
}()
```

## NSPersistentCloudKitContainer 是如何运作的

在介绍如何实现实时切换同步状态之前，我们首先需要对 NSPersistentCloudKitContainer 的构成和工作机制有所了解。

NSPersistentCloudKitContainer 由如下几个功能模块所构成：

### NSPersistentContainer

NSPersistentCloudKitContainer 是 NSPersistentContainer 的子类，拥有 NSPersistentContainer 的全部能力。除了少量用于共享和公共数据鉴权 API 之外，开发者几乎百分百地只与 NSPersistentCloudKitContainer 中 NSPersistentContainer 部分打交道。因此从大的角度划分，NSPersistentCloudKitContainer 就是 NSPersistentContainer 加上网络处理部分。

### Persistent History Tracking 处理 + 格式转换模块

通过默认启用 Persistent History Tracking 支持，NSPersistentCloudKitContainer 可以获知应用在 SQLite 上的所有操作，然后将数据转换成 CloudKit 对应的格式，并保存在 SQLite 上的特定表中（ ANSCKEXPORT...、ANSCKMIRROREDRELATIONSHIP 等 ），待网络同步模块将其同步（ Export ）到云上。

同样对于从云上同步（ Import ）过来的数据，该模块会将其转换成 Core Data 对应的格式，并修改在 SQLite 中对应的数据。全部的修改操作将以 NSCloudKitMirroringDelegate.import（ Transaction author ）的身份记录在 Persistent History Tracking 的 Transaction 数据中。

> 由于该过程是在由 NSPersistentContainer 上创建的私有上下文中进行的，因此只需要将 `viewContext.automaticallyMergesChangesFromParent` 设置为 true ，即可实现数据在视图上下文中的自动合并，而无需对 Persistent History Tracking 创建的 Transaction 做处理。

通过使用 Persistent History Tracking 这一支持跨进程级别的数据修改提醒机制，让 NSPersistentContainer 与网络同步功能之间形成了解耦。

> 有关 Persistent History Tracking 方面的内容，请参阅 [在 CoreData 中使用持久化历史跟踪](https://www.fatbobman.com/posts/persistentHistoryTracking/) 一文。想了解 Core Data 是如何在 SQLite 上组织数据的，请参阅 [Core Data 是如何在 SQLite 中保存数据的](https://www.fatbobman.com/posts/tables_and_fields_of_CoreData/) 一文

### 网络同步模块

对于 Export 数据，该模块将择机（ 视网络状况、数据更新频率等 ）将转换后的数据上传到 iCloud 上。

对于 Import 数据，该模块在获得云端数据变更通知后（ 通过开启 Remote notifications ），会将网络端的变更数据保存到 SQLite 中，供转换模块使用。

所有的网络同步操作都将以日志的形式保存在 SQLite 中。在 iCloud 账户状态发生变动后，NSPersistentCloudKitContainer 将使用这些同步记录作为数据重置的凭据。

### 数据权限模块

在开启 NSPersistentCloudKitContainer 的同步共享数据库或公共数据库功能后，为了提高数据操作权限的验证效率，该模块会将共享或公共数据库在 iCloud 上对应的原始数据（ CKRecordType、记录令牌等 ）备份在本地的 SQLite 中，并提供鉴权 API 供开发者调用。

## 实时切换的原理

NSPersistentCloudKitContainer 这种模块化的构成方式，为实现实时切换同步状态提供了基础。

通过创建双 container （ NSPersistentContainer + NSPersistentCloudKitContainer ），我们将应用程序中对于 Core Data 的操作同网络同步功能分离开来。

两个 Container 都使用相同的 Data Model，并均开启 Persistent History Tracking 功能以感知对方在 SQLite 上的数据修改操作。程序中有关数据业务逻辑的操作在 NSPersistentContainer 实例上进行，而 NSPersistentCloudKitContainer 实例仅负责数据的网络同步服务。

如此一来，通过启用或禁用负责网络同步的 NSPersistentCloudKitContainer 实例，便可实现对网络同步状态的实时切换。由于应用中所有的数据操作仅在 NSPersistentContainer 上进行，因此在运行中实时切换同步状态并不会对数据的安全性和稳定性造成影响。

> 理论上，使用一个未配置 cloudKitContainerOptions 的 NSPersistentCloudKitContainer 替代 NSPersistentContainer 也是可以的。但由于尚未经过充分测试，本文中仍将使用 NSPersistentContainer + NSPersistentCloudKitContainer 的组合

## 实现细节提醒

> 可在此处获取基于以上分析创建的 [演示代码](https://github.com/fatbobman/BlogCodes/tree/main/SyncManager)

本节将根据演示代码对部分实现细节进行说明

### 多个 Container 使用同一个 Data Model

在一个应用程序中，Core Data 的 Data Model（ 使用数据模型编辑器创建的模型文件 ）只能被加载一次。因此我们需要在创建 container 前率先加载该文件并创建为 NSManageObjectModel 实例以供多个 container 使用。

```swift
private let model: NSManagedObjectModel
private let modelName: String

init(modelName: String) {
    self.modelName = modelName
    // load Data Model
    guard let url = Bundle.main.url(forResource: modelName, withExtension: "momd"),
          let model = NSManagedObjectModel(contentsOf: url) else {
        fatalError("Can't get \(modelName).momd in Bundle")
    }
    self.model = model
    
    ...
}

lazy var container: NSPersistentContainer = {
    // 使用 NSManagedObjectModel 来创建 container
    let container = NSPersistentContainer(name: modelName, managedObjectModel: model)
    ...
    return container
}()
```

> 这种方法在 [掌握 Core Data Stack](https://www.fatbobman.com/posts/masteringOfCoreDataStack/) 一文的内存模式章节中也有应用

### 将 NSPersistentCloudKitContainer 声明为可选值

通过将用于网络同步的 container 声明为可选值，即可轻松实现开启和关闭同步功能：

```swift
final class CoreDataStack {
    var cloudContainer: NSPersistentCloudKitContainer?
    lazy var container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: modelName, managedObjectModel: model)
        ...
        return container
    }
    
    init(modelName: String) {
        ....
        
        // 判断是否创建同步 container
        if UserDefaults.standard.bool(forKey: enableCloudMirrorKey) {
            setCloudContainer()
        } else {
            print("Cloud Mirror is closed")
        }
    }
    // 创建用于同步的 container
    func setCloudContainer() {
        if cloudContainer != nil {
            removeCloudContainer()
        }
        let container = NSPersistentCloudKitContainer(name: modelName, managedObjectModel: model)
        ....
        cloudContainer = container
    }

    // 删除用于同步的 container
    func removeCloudContainer() {
        guard cloudContainer != nil else { return }
        cloudContainer = nil
        print("Turn off the cloud mirror")
    }
}
```

### 两个 Container 上均需启用持久化历史跟踪

只有在两个 container 均开启 Persistent History Tracking 功能的情况下，它们才能感知到另一方对 Core Data 数据的修改行为，并进行处理。

```swift
container.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
container.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
```

同时为了能够解决合并冲突，两者都要设置正确的合并策略：

```swift
container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
```

### 在 NSPersistentContainer 实例中响应持久化历史跟踪通知

当 NSPersistentCloudKitContainer 实例从网络上获取到数据并更新到 SQLite 后，会在 SQLite 中创建 Transaction 并通过 NotificationCenter 发送 NSPersistentStoreRemoteChange 通知。我们需要在 NSPersistentContainer 实例中对该通知进行响应，并将同步数据合并到当前的视图上下文中。

> 如果像本文例程中一样使用 [Persistent History Tracking Kit](https://github.com/fatbobman/PersistentHistoryTrackingKit) 处理 Transaction 的话，需要开启 includingCloudKitMirroring 选项以合并由 NSPersistentCloudKitContainer 从网络上获取的变更数据：

```swift
persistentHistoryKit = .init(container: container,
                             currentAuthor: AppActor.app.rawValue,
                             allAuthors: [AppActor.app.rawValue],
                             includingCloudKitMirroring: true, // 合并网络同步数据
                             userDefaults: UserDefaults.standard,
                             cleanStrategy: .none)
```

> 请参阅 [在 CoreData 中使用持久化历史跟踪](https://www.fatbobman.com/posts/persistentHistoryTracking/) 一文了解 Persistent History Tracking 的详细用法。有关 Persistent History Tracking Kit 的内容请参阅其附带的 ReadMe 文档

### 不要清除 Transaction 记录

与仅在 App group 成员中使用 Persistent History Tracking 不同，在网络同步状态可以随时切换的情况下，最好**不要清除 Persistent History Tracking 功能创建的 Transaction 记录**。

这是因为 NSPersistentCloudKitContainer 是根据 Transaction 来判断哪些数据发生了变化，假设我们在关闭了网络同步状态的情况下删除了 Transaction，开启同步后，NSPersistentCloudKitContainer 将无法获知在关闭期间本地数据发生的变化，从而会造成本地和云端数据的永久不同步。

> 之所以仅在 App group 成员间使用 Persistent History Tracking 可以删除 Transaction 记录，那是因为每个成员都会在合并数据后，更新其对应的时间戳。当进行 Transaction 删除操作时，我们可以只删除已经被所有成员合并过的记录。由于无法通过简单的方式得知 NSPersistentCloudKitContainer 的最后更新时间以及已同步的数据位置，因此保留 Transaction 记录是最佳的选择

在本文的例程中，通过将 PersistentHistoryTrackingKit 的 cleanStrategy（ 清除策略 ）设置为 none ，禁止了对 Transaction 的清除操作：

```swift
persistentHistoryKit = .init(container: container,
                             currentAuthor: AppActor.app.rawValue,
                             allAuthors: [AppActor.app.rawValue],
                             includingCloudKitMirroring: true,
                             userDefaults: UserDefaults.standard,
                             cleanStrategy: .none) // 不清除 transaction
```

如果你的应用只会切换一次同步状态（ 从关闭切换到开启，并且之后不再关闭 ），那么可以在开启同步状态后，对由你的 App group 成员产生的 Transaction 进行清除。

```responser
id:1
```

## 如何处理共享数据库和公共数据库的同步

鉴于 NSPersistentContainer 并没有提供数据鉴权方面的 API，在你的应用使用了共享数据库或公共数据库同步功能时，可以采用类似如下的方式来处理：

```swift
import CloudKit

final class CoreDataStack {
    let localContainer:NSPersistentContainer
    let cloudContainer:NSPersistentCloudKitContainer?
    var container:NSPersistentContainer {
        guard let cloudContainer else {
            return localContainer
        }
        return cloudContainer
    }
    
    // 某些权限检查工作，仅用于举例
    func checkPermission(id:NSManagedObjectID) -> Bool {
        guard enableMirror,let container = self.container as? NSPersistentCloudKitContainer else { return false}
        return container.canUpdateRecord(forManagedObjectWith:id)
    }
}
```

强烈建议在关闭网络同步状态的情况下，屏蔽掉应用中可能导致共享数据库和公共数据库进行修改操作的功能。

## iCloud 账号状态变化的处理

> 本节介绍的内容会更改苹果有关 iCloud 数据一致性的预设行为，除非你清楚自己在做什么，也确实有这方面的特别需求，否则不要轻易尝试！

对于采用了 NSPersistentCloudKitContainer 进行数据同步的应用，当使用者在设备上退出 iCloud 账户、切换账户或者关闭应用的 iCloud 同步功能后，NSPersistentCloudKitContainer 会在重启后（ 在应用运行中进行如上操作，iOS 应用会自动重启 ）对所有的与账户关联的数据在设备上进行清除（ 并不会清除云端的数据，当账户恢复或开启同步功能后仍可同步回本地 ）。该清除操作属于一种预设行为，是正常的现象。

> 某些系统应用提供了在 iCloud 账户退出后保留本地数据的能力。但 NSPersistentCloudKitContainer 默认并不提供保留数据的设计。

在重新启动后，NSPersistentCloudKitContainer  通过查询 CKContainer 的 accountStatus 获得 noAccount 状态，从而激活数据删除操作。删除操作是以上文中提到的网络同步模块中保存的数据同步日志为依据进行的。

如果，你想修改 NSPersistentCloudKitContainer 默认的数据处理行为，可以在创建 NSPersistentCloudKitContainer 实例之前，首先判断 CloudKit container 的 accountStatus，只在其不为 noAccount 状态时创建实例。例如：

```swift
import CloudKit

func setCloudContainerWhenOtherStatus() {
    let container = CKContainer(identifier: "YourCloudKitContainerID")
    container.accountStatus{ status,error in
        if status != .noAccount {
            self.setCloudContainer()
        }
    }
}
```

或者，在 accountStatus 为 noAccount 状态时，将 NSPersistentCloudKitContainer 的 NSPersistentStoreDescription 的 cloudKitContainerOptions 设置为 nil，从而屏蔽它的自动清除行为。

> 如果我们将本该自动清除的数据保留在本地，且用户切换了 iCloud 账户，如果不做妥善处理的话，很可能会造成数据在多个账户之间的混乱

## 总结

俗话说有得必有失，使用了双 container 以及不清除 transaction 的方式实现对同步状态的实时切换，势必会带来些许的性能损失以及资源占用。不过，如果你的应用确有这方面的需求，这点付出还是非常值得的。

Persistent History Tracking 现在已经越来越多地出现于各种场合，除了感知 App group 成员间数据变动外，还被应用于 [数据批处理](https://www.fatbobman.com/posts/batchProcessingInCoreData/)、数据云同步、[Spotlight](https://www.fatbobman.com/posts/spotlight/) 等多个环节。建议 Core Data 的使用者应该对其有充分的了解，并尽早将其应用于你的程序之中。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
