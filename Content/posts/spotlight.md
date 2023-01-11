---
date: 2021-09-22 15:00
description: 本文将讲解如何通过 NSCoreDataSpotlightDelegate（WWDC 2021 版本）实现将应用程序中的 Core Data 数据添加到 Spotlight 索引，方便用户查找并提高 App 的曝光率。
tags: Core Data,SwiftUI,Spotlight
title:  在 Spotlight 中展示应用中的 Core Data 数据
image: images/spotlight.png
---

本文将讲解如何通过 NSCoreDataSpotlightDelegate（WWDC 2021 版本）实现将应用程序中的 Core Data 数据添加到 Spotlight 索引，方便用户查找并提高 App 的曝光率。

```responser
id:1
```

## 基础 ##

### Spotlight ###

自 2009 年登陆 iOS 以来，经过 10 多年的发展，Spotlight（聚焦）已经从苹果系统的官方应用搜索变成了一个包罗万象的功能入口，用户对 Spotligh 的使用率及依赖程度也在不断地提升。

在 Spotlight 中展示应用程序中的数据可以显著地提高应用的曝光率。

### Core Spotlight ###

从 iOS 9 开始，苹果推出了 Core Spotlight 框架，让开发者可以将自己应用的内容添加到 Spotlight 的索引中，方便用户统一查找。

为应用中的项目建立 Spotlight 索引，需要以下步骤：

* 创建一个 CSSearchableItemAttributeSet（属性集）对象，为你要索引的项目设置适合的元数据（属性）。
* 创建一个 CSSearchableItem（可搜索项）对象来表示该项目。每个 CSSearchableItem 对象均设有唯一标识符，方便之后引用（更新、删除、重建）
* 如果有需要，可以为项目指定一个域标识符，这样就可以将多个项目组织在一起，便于统一管理
* 将上面创建的属性集（CSSearchableItemAttributeSet）关联到可搜索项（CSSearchableItem）中
* 将可搜索项添加到系统的 Spotlight 索引中

开发者还需要在应用中的项目发生修改或删除时及时更新 Spotlight 索引，让使用者始终获得有效的搜索结果。

### NSUserActivity ###

NSUserActivity 对象提供了一种轻量级的方式来描述你的应用程序状态，并将其用于以后。创建这个对象来捕获关于用户正在做什么的信息，如查看应用程序内容、编辑文档、查看网页或观看视频等。

当使用者从 Spotlight 中搜索到你的应用程序内容数据（可搜索项）并点击后，系统将启动应用程序，并向其传递一个同可搜索项对应的 NSUserActivity 对象（activityType 为 CSSearchableItemActionType），应用程序可以通过该对象中的信息，将自己恢复到一个适当的状态。

比如，用户在 Spotlight 中通过关键字查询邮件，点击搜索结果后，应用将直接定位到该邮件并显示其详细信息。

### 流程 ###

结合上面对于 Core Spotlight 和 NSUserActivity 的介绍，我们用代码段简单地梳理一下流程：

#### 创建可搜索项 ####

```swift
import CoreSpotlight

let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
attributeSet.displayName = "星球大战"
attributeSet.contentDescription = "在很久以前，一个遥远的银河系，肩负正义使命的绝地武士与帝国邪恶黑暗势力作战的故事。"

let searchableItem = CSSearchableItem(uniqueIdentifier: "starWar", domainIdentifier: "com.fatbobman.Movies.Sci-fi", attributeSet: attributeSet)
```

#### 添加至 Spotlight 索引 ####

```swift
        CSSearchableIndex.default().indexSearchableItems([searchableItem]){ error in
            if let error = error {
                print(error.localizedDescription)
            }
        }
```

![image-20210922084725675](https://cdn.fatbobman.com/image-20210922084725675-2271647.png)

#### 应用程序从 Spotlight 接收 NSUserActivity ####

SwiftUI life cycle

```swift
        .onContinueUserActivity(CSSearchableItemActionType){ userActivity in
            if let userinfo = userActivity.userInfo as? [String:Any] {
                let identifier = userinfo["kCSSearchableItemActivityIdentifier"] as? String ?? ""
                let queryString = userinfo["kCSSearchQueryString"] as? String ?? ""
                print(identifier,queryString)
            }
        }

// Output : starWar 星球大战
```

UIKit life cycle

```swift
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        if userActivity.activityType == CSSearchableItemActionType {
            if let userinfo = userActivity.userInfo as? [String:Any] {
                let identifier = userinfo["kCSSearchableItemActivityIdentifier"] as? String ?? ""
                let queryString = userinfo["kCSSearchQueryString"] as? String ?? ""
                print(identifier,queryString)
            }
        }
    }
```

#### 更新 Spotlight 索引 ####

方式同新增索引完全一样，必须保证`uniqueIdentifier`一致。

```swift
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.displayName = "星球大战（修改版）"
        attributeSet.contentDescription = "在很久以前，一个遥远的银河系，肩负正义使命的绝地武士与帝国邪恶黑暗势力作战的故事。"
        attributeSet.artist = "乔治·卢卡斯"

        let searchableItem = CSSearchableItem(uniqueIdentifier: "starWar", domainIdentifier: "com.fatbobman.Movies.Sci-fi", attributeSet: attributeSet)

        CSSearchableIndex.default().indexSearchableItems([searchableItem]){ error in
            if let error = error {
                print(error.localizedDescription)
            }
        }
```

![image-20210922091534038](https://cdn.fatbobman.com/image-20210922091534038.png)

#### 删除 Spotlight 索引 ####

* 删除指定`uniqueIdentifier`的项目

```swift
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ["starWar"]){ error in
            if let error = error {
                print(error.localizedDescription)
            }
        }
```

* 删除指定域标识符的项目

```swift
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: ["com.fatbobman.Movies.Sci-fi"]){_ in }
```

删除域标识符的操作是递归的。上面的代码只会删除所有`Sci-fi`组别，而下面的代码将删除应用程序中全部的电影数据

```swift
CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: ["com.fatbobman.Movies"]){_ in }
```

* 删除应用程序中的全部索引数据

```swift
        CSSearchableIndex.default().deleteAllSearchableItems{ error in
            if let error = error {
                print(error.localizedDescription)
            }
        }
```

```responser
id:1
```

## NSCoreDataCoreSpotlightDelegate 实现 ##

NSCoreDataCoreSpotlightDelegate 提供了一组支持 Core Data 同 Core Spotlight 集成的方法，极大地简化了开发者在 Spotlight 中创建并维护应用程序中 Core Data 数据的工作难度。

在 WWDC 2021 中，NSCoreDataCoreSpotlightDelegate 得到进一步升级，通过持久化历史跟踪，开发者**将无需手动维护数据的更新、删除，Core Data 数据的任何变化都将及时地反应在 Spotlight 中**。

### Data Model Editor ###

要在 Spotlight 中索引应用中的 Core Data 数据，首先需要在数据模型编辑器中对需要索引的实体（Entity）进行标记。

* 只有标记过的实体才能被索引
* 只有被标记过的实体属性发生变化，才会触发索引

![image-20210922101458785](https://cdn.fatbobman.com/image-20210922101458785-2276899.png)

比如说，你的应用中创建了若干的 Entity，不过只想对其中的`Movie`进行索引，且只有当`Movie`的`title`和`description`发生变化时才会更新索引。那么只需要开启`Movie`实体中`title`和`dscription`的`Index in Spotlight`即可。

> Xcode 13 中废弃了 Store in External Record File 并且删除了在 Data Model Editor 中设置 DisplayName。

### NSCoreDataCoreSpotlightDelegate ###

当被标记的实体记录数据更新时（创建、修改），Core Data 将调用 NSCoreDataCoreSpotlightDelegate 中的`attributeSet`方法，尝试获得对应的可搜索项，并更新索引。

```swift
public class DemoSpotlightDelegate: NSCoreDataCoreSpotlightDelegate {
    public override func domainIdentifier() -> String {
        return "com.fatbobman.CoreSpotlightDemo"
    }

    public override func attributeSet(for object: NSManagedObject) -> CSSearchableItemAttributeSet? {
        if let note = object as? Note {
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.identifier = "note." + note.viewModel.id.uuidString
            attributeSet.displayName = note.viewModel.name
            return attributeSet
        } else if let item = object as? Item {
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.identifier = "item." + item.viewModel.id.uuidString
            attributeSet.displayName = item.viewModel.name
            attributeSet.contentDescription = item.viewModel.descriptioinContent
            return attributeSet
        }
        return nil
    }
}
```

* 如果你的应用程序中需要索引多个 Entity，在`attributeSet`中需首先判断托管对象的具体类型，然后为其创建对应的可搜索项数据。
* 对于特定的数据，即使被标记成可索引，也可以通过在 attributeSet 中返回 nil 将其排除在索引之外
* identifier 中最好设置成可以同你的记录对应的标识（identifier 是元数据，并非 CSSearchableItem 的`uniqueIdentifier`），方便你在之后的代码中直接利用它。
* 如不特别指定域标识符，默认系统会使用 Core Data 持久存储的标识符
* 应用中的数据记录被删除后，Core Data 将自动从 Spotlight 中删除其对应的可搜索项。

> CSSearchableItemAttributeSet 具有众多的可用元数据。比如，你可以添加缩略图（`thumbnailData`），或者让用户可以直接拨打记录中的电话号码（分别设置`phoneNUmbers`和`supportsPhoneCall`）。更多信息，请看 [官方文档](https://developer.apple.com/documentation/corespotlight/cssearchableitemattributeset)

### CoreDataStack ###

在 Core Data 中启用 NSCoreDataCoreSpotlightDelegate 有两个先决条件：

* 持久化存储的类型为 Sqlite
* 必须启用持久化历史跟踪（Persistent History Tracking）

因此在 Core Data Stack 中需要使用类似如下的代码：

```swift
class CoreDataStack {
    static let shared = CoreDataStack()

    let container: NSPersistentContainer
    let spotlightDelegate:NSCoreDataCoreSpotlightDelegate

    init() {
        container = NSPersistentContainer(name: "CoreSpotlightDelegateDemo")
        guard let description = container.persistentStoreDescriptions.first else {
                    fatalError("###\(#function): Failed to retrieve a persistent store description.")
        }

        // 启用持久化历史跟踪
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })

        // 创建索引委托
        self.spotlightDelegate = NSCoreDataCoreSpotlightDelegate(forStoreWith: description, coordinator: container.persistentStoreCoordinator)

        // 启动自动索引
        spotlightDelegate.startSpotlightIndexing()
    }
}
```

对于已经上线的应用程序，在添加了 NSCoreDataCoreSpotlightDelegate 功能后， 首次启动时，Core Data 会自动将满足条件（被标记）的数据添加到 Spotlight 索引中。

> 上述代码中，只开启了持久化历史跟踪，并没有对失效数据进行定期清理，长期运行下去会导致数据膨胀，影响执行效率。如想了解更多有关持久化历史跟踪信息，请阅读 [在 CoreData 中使用持久化历史跟踪](https://www.fatbobman.com/posts/persistentHistoryTracking/)。

### 停止、删除索引 ###

如果想重建索引，应该首先停止索引，然后再删除索引。

```swift
       stack.spotlightDelegate.stopSpotlightIndexing()
       stack.spotlightDelegate.deleteSpotlightIndex{ error in
           if let error = error {
                  print(error)
           } 
       }
```

> 另外，也可以使用上面介绍的方法，直接使用 CSSearchableIndex 来更精细的删除索引内容。

### onContinueUserActivity ###

NSCoreDataCoreSpotlight 在创建可搜索项（CSSearchableItem）时会使用托管对象的 uri 数据作为`uniqueIdentifier`，因此，当用户点击 Spotlight 中的搜索结果时，我们可以从传递给应用程序的 NSUserActivity 的 userinfo 中获取到这个 uri。

由于传递给应用程序的 NSUserActivity 中仅提供有限的信息（`contentAttributeSet`为空），因此，我们只能依靠这个 uri 来确定对应的托管对象。

SwiftUI 提供了一种便捷的方法`onConinueUserActivity`来处理系统传递的 NSUserActivity。

```swift
import SwiftUI
import CoreSpotlight
@main
struct CoreSpotlightDelegateDemoApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onContinueUserActivity(CSSearchableItemActionType, perform: { na in
                    if let userinfo = na.userInfo as? [String:Any] {
                        if let identifier = userinfo["kCSSearchableItemActivityIdentifier"] as? String {
                            let uri = URL(string:identifier)!
                            let container = persistenceController.container
                            if let objectID = container.persistentStoreCoordinator.managedObjectID(forURIRepresentation: uri) {
                            if let note = container.viewContext.object(with: objectID) as? Note {
                                // 切换到 note 对应的状态
                            } else if let item = container.viewContext.object(with: objectID) as? Item {
                               // 切换到 item 对应的状态
                            }
                        }
                    }
                })
        }
    }
}
```

* 通过 userinfo 中的`kCSSearchableItemActivityIdentifier`键获取到`uniqueIdentifier`（Core Data 数据的 uri）
* 将 uri 转换成 NSManagedObjectID
* 通过 objectID 获取到托管对象
* 根据托管对象，设置应用程序到对应的状态。

> 我个人不太喜欢这种将处理 NSUserActivity 的逻辑嵌入视图代码的做法，如果想在 UIWindowSceneDelegate 中处理 NSUserActivity，请参阅 [Core Data with CloudKit （六） —— 创建与多个 iCloud 用户共享数据的应用](https://www.fatbobman.com/posts/coreDataWithCloudKit-6/) 中关于 UIWindowSceneDelegate 的用法。

### CSSearchQuery ###

CoreSpotlight 中还提供了一种在应用程序中查询 Spotlight 的方案。通过创建 CSSearchQuery，开发者可以在 Spotlight 中搜索当前应用已被索引的数据。

```swift
    func getSearchResult(_ keyword: String) {
        let escapedString = keyword.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let queryString = "(displayName == \"*" + escapedString + "*\"cd)"
        let searchQuery = CSSearchQuery(queryString: queryString, attributes: ["displayName", "contentDescription"])
        var spotlightFoundItems = [CSSearchableItem]()
        searchQuery.foundItemsHandler = { items in
            spotlightFoundItems.append(contentsOf: items)
        }

        searchQuery.completionHandler = { error in
            if let error = error {
                print(error.localizedDescription)
            }
            spotlightFoundItems.forEach { item in
                //  do something
            }
        }

        searchQuery.start()
    }
```

* 首先需要对搜索关键字进行安全处理，对`\`进行转义
* `queryString`的查询形式同 NSPredicate 很类似，比如上面代码中就是查询所有`displayName`中含有 keyword 的数据（忽视大小写、音标字符），详细信息请查阅 [官方文档](https://developer.apple.com/documentation/corespotlight/cssearchquery)
* attributes 中设置了返回的可搜索项（CSSearchableItem）中需要的属性（例如可搜索项中有十个元数据内容，只需返回设置中的两个）
* 当获得搜索结果时将调用`foundItemsHandler`闭包中的代码
* 配置好后用`searchQuery.start()`启动查询

> 对于使用 Core Data 的应用来说，直接通过 Core Data 查询或许是更好的方式。

## 注意事项 ##

### 失效日期 ###

默认情况下，CSSearchableItem 的失效日期（`expirationDate`）为 30 天。也就是说，如果一个数据被添加到索引中，如果在 30 天内没有发生任何的变动（更新索引），那么 30 天后，我们将无法从 Spotlight 中搜索到这个数据。

解决的方案有两种：

* 定期重建 Core Data 数据的 Spotlight 索引

  方法为停止索引——删除索引——重新启动索引

* 为 CSSearchableItemAttributeSet 添加失效日期元数据

  正常情况下，我们可以为 NSUserActivity 设置失效日期，并将 CSSearchableItemAttributeSet 同其进行关联。但 NSCoreDataCoreSpotlightDelegate 中只能设置 CSSearchableItemAttributeSet。

  官方并没有公开 CSSearchableItemAttributeSet 的失效日期属性，因此无法保证下面的方法一直有效

```swift
        if let note = object as? Note {
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.identifier = "note." + note.viewModel.id.uuidString
            attributeSet.displayName = note.viewModel.name
            attributeSet.setValue(Date.distantFuture, forKey: "expirationDate")
            return attributeSet
        }
```

> setValue 会自动将 CSSearchableItemAttributeSet 中的`_kMDItemExpirationDate`设置成`4001-01-01`，Spotlight 会将`_kMDItemExpirationDate`的时间设置为 NSUserActivity 的`expirationDate`

### 模糊查询 ###

Spotlight 支持模糊查询。比如输入`xingqiu`便可能在搜索结果中显示上图的“星球大战”。不过苹果并没有在 CSSearchQuery 中开放模糊查询的能力。如果希望用户在应用内获得同 Spotlight 类似的体验，还是通过创建自己的代码在 Core Data 中实现比较好。

另外，Spotlight 的模糊查询只对`displayName`有效，对`contentDescription`没有效果

### 字数限制 ###

CSSearchableItemAttributeSet 中的元数据是用来描述记录的，并不适合保存大量的数据。 `contentDescription`目前支持的最大字符数为 300。如果你的内容较多，最好截取真正对用户有用的信息。

### 可搜索项数量 ###

应用的可搜索项需控制在几千条之内。超出这个量级，将严重影响查询性能

## 总结 ##

希望有更多的应用认识到 Spotlight 的重要性，尽早登陆这个设备应用的重要入口。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
