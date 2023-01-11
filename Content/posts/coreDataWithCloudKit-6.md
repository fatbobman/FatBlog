---
date: 2021-09-11 19:20
description: 本文中，我们将探讨如何使用 Core Data with CloudKit 创建使用 NSPersistentCloudKitContainer 与多个 iCloud 用户共享数据的应用。
tags: CloudKit,Core Data
title:  Core Data with CloudKit （六） —— 创建与多个 iCloud 用户共享数据的应用
image: images/coreDataWithCloudKit-6.png
---

本文中，我们将探讨如何使用 Core Data with CloudKit 创建与多个 iCloud 用户共享数据的应用。

> 本篇是本系列的最后一篇，本文中将涉及大量之前提到的知识，阅读本文前，最好已经阅读过之前的 [文章](https://www.fatbobman.com/tags/cloudkit/)。

[Core Data with CloudKit （一） —— 基础](/posts/coreDataWithCloudKit-1/)

[Core Data with CloudKit（二） —— 同步本地数据库到 iCloud 私有数据库](/posts/coreDataWithCloudKit-2/)

[Core Data with CloudKit（三）—— CloudKit 仪表台](/posts/coreDataWithCloudKit-3/)

[Core Data with CloudKit（四）—— 调试、测试、迁移及其他](/posts/coreDataWithCloudKit-4/)

[Core Data with CloudKit（五）—— 同步公共数据库](/posts/coreDataWithCloudKit-5/)

[Core Data with CloudKit （六） —— 创建与多个 iCloud 用户共享数据的应用](/posts/coreDataWithCloudKit-6/)

相信应该有不少的朋友都使用过 iOS 自带的共享相簿或者共享备忘录功能。这些功能的实现都是基于几年前苹果推出的 CloudKit 共享数据 API。在 WWDC 2021 中，苹果将该功能集成到 Core Data with CloudKit 之中，我们终于可以在使用少量 CloudKit API 的情况下，用 Core Data 的操作方式创建具有同样功能的应用程序了。

就像 WWDC session [Build apps that share data through CloudKit and Core Data](https://developer.apple.com/videos/play/wwdc2021/10015/) 提到的那样，共享数据功能的实现远复杂于同步私有数据库以及同步公共数据库。尽管苹果提供了不少新的 API 来简化该操作，但想完整的在应用程序中实现该功能仍具有不小的挑战。

```responser
id:1
```

## 基础 ##

> 本节主要介绍的是 Core Data with CloudKit 下的共享机制，某些地方同原生的 CloudKit 共享不同。

### 所有者和参与者 ###

在每个共享数据关系中，都有一个所有者（`owner`）和若干个参与者（`participant`）。无论是所有者还是参与者，都必须为 iCloud 用户，且只能在已经登录了有效 iCloud 账户的苹果设备上进行操作。

所有者发起共享，并向参与者发送共享链接。参与者点击共享链接后，设备将自动打开对应的 app，导入共享数据。

所有者可以指定具体的参与者，或者将共享设置为任何点击共享链接的人都可以访问。两种情况互斥，可以切换，当从指定具体参与者切换到任何人时，系统将删除所有的具体参与者信息。

所有者可以为参与者设置数据操作权限，只读或可读写，权限可以在之后修改。

### CKShare ###

CKShare 是管理共享记录集合的专用记录类型。包含了需要共享的根记录或自定义区域信息以及在此次共享关系中的所有者和参与者的信息。

在 Core Data with CloudKit 模式下，所有者将托管对象实例（`NSManagedObject`）设置为共享的过程，其实就是为其创建了一个`CKShare`实例。

```swift
let (ids, share, ckContainer) = try await stack.persistentContainer.share([note1,note2], to: nil)
```

我们可以在一个共享关系中，一次性共享多个托管对象。

托管对象关系（`relationship`）对应的所有数据都将自动被共享。

针对共享后的托管对象的任何修改都将自动同步到所有者和参与者的设备中。在当前的 Core Data with CloudKit 机制下，我们无法在共享后添加最顶层的托管对象（例如上面代码中的`note`）。

### 云端共享机制 ##

在 WWDC 2021 之前，CloudKit 的机制是通过一个`rootRecord`来实现共享，所有者为某个 CKRecord 创建 CKShare，实现单个记录（包含它的关系数据）共享。

```swift
let user = CKRecord(recordType:"User")
let share = CKShare(rootRecord: user)
```

WWDC 2021 中 CloudKit 提供了一种新的共享机制——共享自定义区域（Zone）。所有者在自己的私有数据库中创建一个新的自定义区域，为该区域创建 CKShare。参与者将共享该区域中所有的数据。

```swift
init(recordZoneID: CKRecordZone.ID)
```

此种共享方式更适合数据集较大、关系较复杂的应用场景。Core Data with CloudKit 的数据共享就是采用这种共享机制。

在之前的同步私有数据库中我们介绍过，私有数据库的自定义区域可以创建`CKDatabaseSubscription`，参与者正式通过该订阅来及时获取到共享数据的变化。

当所有者创建了一个共享关系后，系统将自动为其在私有数据库中创建一个新的自定义区域（`com.apple.coredata.cloudkit.share.xxx-xx-xx-xx-xxx`），并将共享的数据（包括其关系数据）从私有数据库中的`com.apple.coredata.cloudkit.zone`移动到新建的 Zone 中。此过程为 NSPersistentCloudContainer 自动完成。

每个共享关系都将创建一个新的自定义区域。

![image-20210911110311850](https://cdn.fatbobman.com/image-20210911110311850.png)

参与者将在他的网络共享数据库中看到一个同上面新建的 Zone 名称一样的自定义区域（之前的文章介绍过，共享数据库是其他用户的私有数据库的数据投影）。

所有者对数据都操作都是在自己的网络私有数据库自定义区域中进行的，而参与者则是在自己的网络共享数据库对应的自定义区域中进行的。

> 每个使用者都可能发起共享，也可能接受共享，无论用户在一个共享关系中是什么角色，数据的保存逻辑是不变的。

### 本地存储机制 ###

在之前的文章中，我们已经介绍了如何通过多个 NSPersistentStoreDescription 创建多个持久化存储。同网络端类似，在用户的设备端，通过 Core Data with CloudKit 共享数据同样需要创建两个本地 Sqlite 数据库。两个数据库分别对应网络端的私有数据库和共享数据库。

从共享关系中的所有者来看，所有者创建的所有数据都保存在本地的私有数据库中。即使该数据被共享，其他参与者对数据的修改也保存在所有者的私有数据库中。

从数据的参与者来看，任何所有者共享的数据，都保存在参与者的本地的共享数据库文件中，即使是参与者本人进行的添加或修改，也同样保存在本地共享数据库文件中。

以上的行为，同网络端的逻辑完全一致。

> 苹果为了实现以上的功能，在背后做了大量的工作。NSPersistentCloudContainer 在同步数据时，需要对每条数据进行网络自定义区域和本地持久化存储的判断、转换等大量工作。因此在实际使用中，同步速度比单纯的同步本地数据库要慢。

由于网络共享库是网络私有库数据的投影，因此两个数据库使用的数据模型是完全一致的。因此在代码实现上，基本上就是采用简单的`Copy`完成。

```swift
guard let shareDesc = privateDesc.copy() as? NSPersistentStoreDescription else {
            fatalError("Create shareDesc error")
        }
```

苹果在去年为`cloudKitContainerOptions`添加了`databasScope`属性，支持了`private`和`public`，今年又增加了`shared`选项以支持共享数据类型。

```swift
shareDescOption.databaseScope = .shared
```

> 由于所有的共享数据都是需要对应的 CKRecord 信息，因此，本地私有数据库必须同时支持网络同步。

网络端和本地端数据保存逻辑如下：

![共享数据库示意图。drawio-2](https://cdn.fatbobman.com/%E5%85%B1%E4%BA%AB%E6%95%B0%E6%8D%AE%E5%BA%93%E7%A4%BA%E6%84%8F%E5%9B%BE.drawio-2.png)

与同步公共数据库一样，Core Data with CloudKit 为了缩短通过网络查询 CloudKit 数据时间，将 NSManagedObject 对应的 CKRecord 都保存在本地数据库文件中，在使用共享数据功能的情况下，本地还会保存对应的自定义区域以及所有的 CKShare 信息。

以上举措一方面极大的改善了数据查询的效率，同时也对维护本地 Catch 数据的有效性提出了更高的要求。苹果提供了部分的 API 来解决 Catch 的新鲜度问题，不过并不完美，仍需开发者编写较多的额外代码。另外，系统自带的 UICloudSharingController 仍未支持 Catch 更新（Xcode 13 beta 5）。

### 新 API ###

苹果今年为 CloudKit API 做了大幅的更新，给所有的回调式异步方法都添加了 Async/Await 版本。同时，也为 Core Data with CloudKit 更新并添加了不少方法以支持数据共享。在上篇文章中，我们已经提到，苹果大幅增强了 NSPersistentCloudContainer 的存在感，新添加的方法，大多都是增加在 NSPersistentCloudContainer 中。

* acceptShareInvitations

  参与者接受邀请，该方法运行在 AppDelegate 中

* share

  为托管对象创建 CKShare

* fetchShares(in:)

  获取持久化存储中的所有 CKShare

* fetchShares(matching:)

  获取指定托管对象的 CKShare

* fetchParticipants

  通过 CKUserIdentity.LookupInfo 获取共享关系中的 Participant 信息。比如通过 email 或电话号码进行查找

* persistUpdatedShare

  更新本地 Catch 中的 CKShare。在开发者通过代码修改 CKShare 后，应将经过网络更新后的 CKShare 持久化到本地的 Catch 中，目前的 UICloudSharingController 缺少了这个步骤，导致停止更新后出现 Bug。

* purgeObjectsAndrecordsInZone

  删除指定的自定义区域，并删除本地对应的所有托管对象。在当前版本中（XCode 13 beta 5），所有者停止更新后，并没有完成足够的善后工作。导致本地 Catch 中仍保存 CKShare，该托管对象无法唤起 UICloudSharingController，网络端的数据仍旧保存在为共享创建的自定义区域中（应该移回正常的自定义 Zone）。

### UICloudShareingController ###

![IMG_1886](https://cdn.fatbobman.com/IMG_1886.png)

UICloudShareingController 是 UIKit 提供的一个用于从 CloudKit 共享记录中添加和删除人员的视图控制器。开发者仅需少量的代码，便可以拥有以下功能：

* 邀请人们查看或协作共享记录

* 设置访问权限，确定谁可以访问共享记录（只有被邀请的人或有共享链接的任何人）。

* 设置一般或个别权限（只读或读/写）。

* 取消一个或多个参与者的访问权限

* 停止参与（如果用户是参与者）。

* 停止与所有参与者共享（如果用户是共享记录的所有者）。

UICloudSharingController 提供了两个构造方法，分别用于已经生成了 CKShare 和没有生成 CKShare 的情况。

在 SwiftUI 下，用于尚未生成 CKShare 情况的构造方法在使用 UIViewControllerRepresentable 包装时异常，因此，推荐在 SwiftUI 下首先使用代码（`share`）手动为托管对象生成 CKShare，然后使用另一个针对已生成 CKShare 的构造方法。

UICloudSharingController 提供了若干的委托方法，我们需要在其中做一些停止共享后的善后工作。

当前版本（Xcode 13 beta 5）的 UICloudSharingController 仍有 Bug，希望能够尽快修复。

## 实例 ##

> 我写了一个 Demo 放在 [Github](https://github.com/fatbobman/ShareData_Demo_For_CoreDataWithCloudKit) 上，本文中仅对其中重点进行说明。

### 项目设置 ###

#### info.plist ####

在 info.plist 添加`CKSharingSupported`，为应用程序添加打开共享链接的能力。Xcode 13 可以直接在`info`中添加。

![image-20210911162206667](https://cdn.fatbobman.com/image-20210911162206667.png)

#### Signing&Capablilities ####

与同步本地数据一样，在`Signing&Capabilities`中添加对应的功能（iCloud、background），并添加 CKContainer。

![image-20210911162525003](https://cdn.fatbobman.com/image-20210911162525003-1348726.png)

### 设置 AppDelegate ###

为了让应用程序能够接受共享邀请，我们必须在 UIApplicationDelegate 中响应传入的共享元数据。在 UIKit lifeCycle 模式下，只需要在 AppDelegate 中的添加类似如下代码即可：

```swift
    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        let shareStore = CoreDataStack.shared.sharedPersistentStore
        let persistentContainer = CoreDataStack.shared.persistentContainer
        persistentContainer.acceptShareInvitations(from: [cloudKitShareMetadata], into: shareStore, completion: { metas,error in
            if let error = error {
                print("accepteShareInvitation error :\(error)")
            }
        })
    }
```

使用 NSPersistentCloudContainer 的`acceptShareInvitations`方法接收 CKShare.Metadata。

在 SwiftUI lifeCycle 模式下，该响应发生在`UIWindowSceneDelegate`中。因此需要在 AppDelegate 中进行转接。

```swift
final class AppDelegate:NSObject,UIApplicationDelegate{
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let sceneConfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        sceneConfig.delegateClass = SceneDelegate.self
        return sceneConfig
    }
}

final class SceneDelegate:NSObject,UIWindowSceneDelegate{
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        let shareStore = CoreDataStack.shared.sharedPersistentStore
        let persistentContainer = CoreDataStack.shared.persistentContainer
        persistentContainer.acceptShareInvitations(from: [cloudKitShareMetadata], into: shareStore, completion: { metas,error in
            if let error = error {
                print("accepteShareInvitation error :\(error)")
            }
        })
    }
}
```

### Core Data Stack ###

CoreDataStack 的设置基本上同前几篇文章中的设置类似，需要注意的是，为了方便判断持久化存储，在 Stack 层面添加了`privatePersistentStore`和`sharedPersistentStore`，保存本地的私有数据库持久化存储以及共享数据库持久化存储。

```swift
        let dbURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        let privateDesc = NSPersistentStoreDescription(url: dbURL.appendingPathComponent("model.sqlite"))
        privateDesc.configuration = "Private"
        privateDesc.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: ckContainerID)
        privateDesc.cloudKitContainerOptions?.databaseScope = .private

        guard let shareDesc = privateDesc.copy() as? NSPersistentStoreDescription else {
            fatalError("Create shareDesc error")
        }
        shareDesc.url = dbURL.appendingPathComponent("share.sqlite")
        let shareDescOption = NSPersistentCloudKitContainerOptions(containerIdentifier: ckContainerID)
        shareDescOption.databaseScope = .shared
        shareDesc.cloudKitContainerOptions = shareDescOption
```

本地共享数据库是使用私有数据库的 Description Copy 出来的。分别为两个持久化存储设定 URL，并为共享 Description 设置`shareDescOption.databaseScope = .shared`

为 Stack 添加了便捷方法，方便视图中的逻辑判断。

例如：

下面的代码是判断托管托管对象是否为共享数据。为了加快判断，首先判断该数据是否保存在本地共享数据库中，其次才使用`fetchShares`检查是否已经生成 CKShare。

```swift
    func isShared(objectID: NSManagedObjectID) -> Bool {
        var isShared = false
        if let persistentStore = objectID.persistentStore {
            if persistentStore == sharedPersistentStore {
                isShared = true
            } else {
                let container = persistentContainer
                do {
                    let shares = try container.fetchShares(matching: [objectID])
                    if shares.first != nil {
                        isShared = true
                    }
                } catch {
                    print("Failed to fetch share for \(objectID): \(error)")
                }
            }
        }
        return isShared
    }
```

下面的代码是判断当前用户是否为共享数据的所有者：

```swift
    func isOwner(object: NSManagedObject) -> Bool {
        guard isShared(object: object) else { return false }
        guard let share = try? persistentContainer.fetchShares(matching: [object.objectID])[object.objectID] else {
            print("Get ckshare error")
            return false
        }
        if let currentUser = share.currentUserParticipant, currentUser == share.owner {
            return true
        }
        return false
    }

```

### 包装 UICloudSharingController ###

想更多地了解 UIViewControllerRepresentable 的使用方法，请阅读我的另一篇文章 [在 SwiftUI 中使用 UIKit 视图](https://www.fatbobman.com/posts/uikitInSwiftUI/)。

对 UICloudShareingController 的包装并不困难，但需要注意以下几点：

* 需保证被共享的托管对象已经创建了 CKShare。

  由于 UICloudShareingController 针对没有创建 CKShare 的构造器用于 UIViewControllerRepresentable 后表现异常，对于首次共享的托管对象，我们需要在代码中先为其创建 CKShare。创建 CKShare 通常需要几秒钟，对用户体验有一定影响。我在 Demo 中也展示了另一种不通过 UIViewControllerRepresentable 调用 UICloudSharingController 的方式。

创建 CKShare 的代码如下：

```swift
func getShare(_ note: Note) -> CKShare? {
        guard isShared(object: note) else { return nil }
        guard let share = try? persistentContainer.fetchShares(matching: [note.objectID])[note.objectID] else {
            print("Get ckshare error")
            return nil
        }
        share[CKShare.SystemFieldKey.title] = note.name
        return share
    }
```

* 需要保证 CKShare 的`CKShare.SystemFieldKey.title`元数据有值，否则将无法通过邮件、信息等进行共享。内容可以自己定义，能够表示清楚你要共享的内容即可

```swift
func makeUIViewController(context: Context) -> UICloudSharingController {
        share[CKShare.SystemFieldKey.title] = note.name
        let controller = UICloudSharingController(share: share, container: container)
        controller.modalPresentationStyle = .formSheet
        controller.delegate = context.coordinator
        context.coordinator.note = note
        return controller
    }
```

* Coordinator 的生命周期要长于 UIViewControllerRepresentable。

  由于共享操作需要网络操作，通常数秒之后才能返回结果。UICloudSharingController 在发送共享链接后即会销毁，如果 Coordinator 被定义在 UIViewControllerRepresentable 中，会导致返回结果后，无法回调委托方法。

* 委托方法`itemTitle`需要返回内容，否则邮件共享无法唤醒

* 在委托方法`cloudSharingControllerDidStopSharing`中处理停止共享的善后问题

### 发起共享 ###

在对托管对象调用 UICloudSharingController 前需要首先判断是否已经为其创建了 CKShare，如果没有需要先创建 CKShare。对已经共享的托管对象调用 UICloudSharingController，视图将显示当前共享关系的所有参与者信息，并可修改共享方式以及用户权限。

```swift
        if isShared {
              showShareController = true
          } else {
              Task.detached {
                 await createShare(note)
                      }
          }
```

采用`Task.detached`避免生成 CKShare 时导致线程阻塞。

另外，Demo 中还有一个直接调用 UICloudSharingController 的方式（已被注释掉），这种方式的用户体验更好，不过手段不是很 SwiftUI 化。

```swift
private func openSharingController(note: Note) {
        let keyWindow = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .map { $0 as? UIWindowScene }
            .compactMap { $0 }
            .first?.windows
            .filter { $0.isKeyWindow }.first

        let sharingController = UICloudSharingController {
            (_, completion: @escaping (CKShare?, CKContainer?, Error?) -> Void) in

            stack.persistentContainer.share([note], to: nil) { _, share, container, error in
                if let actualShare = share {
                    note.managedObjectContext?.performAndWait {
                        actualShare[CKShare.SystemFieldKey.title] = note.name
                    }
                }
                completion(share, container, error)
            }
        }

        keyWindow?.rootViewController?.present(sharingController, animated: true)
    }
```

### 检查权限 ###

在应用程序中，对托管对象进行修改删除操作前，请务必首先判断操作权限。只对有读写权限的数据开启修改功能。

```swift
   if canEdit {
         Button {
            withAnimation {
                stack.addMemo(note)
              }
         }
         label: {
             Image(systemName: "plus")
              }
   }

    func canEdit(object: NSManagedObject) -> Bool {
        return persistentContainer.canUpdateRecord(forManagedObjectWith: object.objectID)
    }
```

> 可以在我的 [Github](https://github.com/fatbobman/ShareData_Demo_For_CoreDataWithCloudKit) 上下载全部的代码。

## 调试须知 ##

相较于同步本地数据库、同步公共数据库，调试共享数据的难度更大，对开发者的心态考验也更多。

由于无法在模拟器上进行调试，开发者需要准备至少两台拥有不同 iCloud 账户的设备。

可能是仍处于测试阶段，共享同步的响应速度要远慢于单纯的同步本地私有数据库。通常在本地创建一个数据，需要数十秒才能同步到云端的私有数据库。参与者在接收同步邀请后，两台设备的 CKShare 数据也需要一段时间才能刷新。

如果感觉一定时间后数据仍未同步，请将应用程序切换至后台再切换回来，有些时候甚至需要对应用程序进行冷启动。

另外，某些已知 Bug 也会导致异常状况，请在调试前首先阅读下面的已知问题，避开我在调试时踩过的坑。

## 已知问题 ##

1. 共享时，如设置成任何人可接收，参与者将无法获取到共享前托管对象的关系数据，且只有在共享的托管对象修改后（或添加新的关系数据后）才会在参与者的应用程序中显示。不知道是 Bug 还是苹果有意为之。

2. 共享时，如设置成任何人可接收，尽量不要直接在 UICloudSharingController 中通过信息、邮件等方式发送到另一个有效的 iCloud 账户上，否则大概率无法打开该共享链接，会显示共享已取消。可以选择拷贝链接然后再通过信息、邮件发送即可解决该问题。

3. 尽量通过信息或系统邮件打开共享链接（将启动 Deep link）。其他的手段可能会直接通过浏览器访问该链接，导致无法接受邀请。

4. 记录所有者通过 UICloudSharingController 停止某个参与者的共享权限后，UICloudSharingController 无法正常刷新修改后的 CKShare，导致无法再次唤醒 UICloudSharingController。由于没有对应的委托方法，因此当前没有直接的解决方案。正常的逻辑是，在修改 CKShare 后，服务器返回新的 CKShare，通过`persistUpdatedShare`更新本地 Catch

5. 数据所有者通过 UICloudSharingController 停止共享后（停止全部共享），UICloudSharingController 会出现与前一条类似的问题——不会删除本地 Catch 中 CKShare。这个问题目前可以通过在`cloudSharingControllerDidStopSharing`中，对停止共享的托管对象进行 Deep Copy（深拷贝，包含所有关系数据），然后再执行`purgeObjectsAndRecordsInZone`解决。如果数据量较多，该解决方案的执行时间会较长。希望苹果可以推出更加直接的善后方法。

6. 所有者取消某个参与者的共享权限后，参与者的 CKShare 刷新不完整。参与者设备上的共享数据可能会消失（在应用程序下次冷启动后一定会消失），也可能不消失。此时如果参与者对共享数据进行操作，会导致应用程序崩溃，影响用户体验。

7. 参与者通过 UICloudSharingController 取消自己的共享后，CKShare 刷新不完全，现象同上一条一样。不过该问题可以在`cloudSharingControllerDidStopSharing`通过删除参与者设备上的托管对象来解决。

其中，4、5、7 条都可以通过创建自己的 UICloudSharingController 实现得以避免。

所有的问题和异常我都已经向苹果提交了 feedback。如果你在调试中也出现了类似或其他的异常情况，希望也能及时提交 feedback，督促并帮助苹果及时改正。

## 总结 ##

尽管仍未完全成熟，但使用 Core Data with CloudKit 来共享数据仍是一个令人惊喜的功能。我对其在 [健康笔记 3](https://www.fatbobman.com/healthnotes/) 中的表现充满了期待和信心。

从开启本系列文章开始，完全没有想到整个过程竟需耗费如此多的时间和精力。不过从整理和写作过程中我也受益颇多，对之前掌握不扎实的知识通过反复的强化加深了认识。

希望本文能够对你有所帮助，也希望能够有更多的开发者可以了解并使用 Core Data & CloudKit。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流
