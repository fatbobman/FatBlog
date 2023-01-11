---
date: 2022-10-20 12:12
description: Ask Apple 为开发者与苹果工程师创造了在 WWDC 之外进行直接交流的机会。本文对本次活动中与 Core Data 有关的一些问答进行了整理，并添加了一点个人见解。本文为上篇。
tags: Core Data,Ask Apple 2022
title: Ask Apple 2022 中与 Core Data 有关的问答 (上)
image: images/Core-Data-of-Ask-Apple-2022.png
---
Ask Apple 为开发者与苹果工程师创造了在 WWDC 之外进行直接交流的机会。本文对本次活动中与 Core Data 有关的一些问答进行了整理，并添加了一点个人见解。本文为上篇。

## Q&A

### 是否可以在 Core Data 中存储照片

Q：你好，我看到一些网站建议 Core Data 不应该用于保存照片，也许他们没注意到可以使用 "使用外部存储选项（ use external storage ）"？我正在开发一个应用程序，用户可能一周左右拍一次照片。保存到 Core Data 中或保存到目录哪种更合适？我不想保存到照片库中，因为用户可能不想让别人轻易看到这些照片。

A：在 Core Data 中使用外部存储是可以的。你也可以在 Core Data 中存储一个 URL ，然后自己管理的文件。如果你打算将 URL 传递给其他框架，比如媒体播放器，那么你就应该采用后一种方式。

> 在 Core Data 中开启 Allows External Storage 后，[二进制的读取效率是有保障的](https://www.sqlite.org/intern-v-extern-blob.html)。Core Data 会将大于一定尺寸（ 100KB ）的文件保存在文件系统中，并且仅在 BLOB 字段中保存该文件的文件名。文件被保存在与 SQLite 数据库同级创建的一个隐藏目录（ _EXTERNAL_DATA ）下。很遗憾， Core Data 并没有提供直接返回这些文件 URL 的 API（ 或将 BLOB 转换成以某种 URL 访问的方式 ），因此，当需要将数据以 URL 的方式进行传递时，就需要先将数据写到临时目录后才能进行。因此，是否保存在 Core Data 中，取决于你的具体使用场景。对于需要同步的应用来说，如果采用在 Core Data 中保存 URL 并将数据保存到目录的方式，需要自己实现外置数据的同步。

```responser
id:1
```

### 切换 iCloud 后是否会清空本地数据

Q：在使用 Core Data with CloudKit 的情况下，当用户注销设备上的 iCloud 账户时，NSPersistentCloudKitContainer 将收到删除本地数据的指示。这是有意为之的吗？

A：是的。 NSPersistentCloudKitContainer 在 iCloud 帐户和存储中的数据之间强制执行严格绑定。

> 在 [实时切换 Core Data 的云同步状态](https://www.fatbobman.com/posts/real-time-switching-of-cloud-syncs-status/) 一文，我介绍过一种实验方法，在某些情况下可以尝试保留这些数据。但最好还是让应用保持 Core Data 原有的设计模式。考虑到两者间的强绑定策略，同时为了进一步节省用户的备份空间，可以考虑将 Core Data 数据的 SQLite 文件的 isExcludedFromBackup（ 取消文件级的云同步 ） 属性设置为 false ，避免多次备份。

### 如何禁用/启用网络同步

Q：对于想要禁用/启用 CloudKit 存储的用户，是否有推荐的方法让应用程序可以实现此操作。

A：不可以。用户可以从应用程序的设置/系统设置中修改应用的 iCloud 同步选项。你可以创建一个没有 NSPersistentCloudKitContainerOptions 描述的 NSPersistentCloudKitContainer，如此一来它将不会进行同步。但是由于 NSPersistentCloudKitContainer 强制将 iCloud 中的数据绑定到持久存储文件。没有办法告诉 NSPersistentCloudKitContainer 在帐户消失后保留本地数据（当用户在禁用该 App 的 iCloud 同步时会发生这种情况 ）。

> 在使用单 Container 的情况下，开发者可以通过 UserDefaults 的方式，控制应用程序在下次冷启动时，是否启用网络同步功能（ 通过设置 cloudKitContainerOptions 与否 ）。如想实现可实时切换的同步状态，可参阅 [实时切换 Core Data 的云同步状态](https://www.fatbobman.com/posts/real-time-switching-of-cloud-syncs-status/) 一文。

### 如何处理 Container 创建失败

Q：优雅地处理 container.loadPersistentStores 闭包中的错误的方法是什么？ Apple 模板（ Xcode 提供的 Core Data 模版 ）中有一个 fatalError，并提示它不应该在生产中使用，但如果我的 Core Data Stack 没有正确实例化，我的用户无法对我的应用程序做任何事情。

A：通常这些错误是由于未测试的架构迁移、错误的文件保护等级、磁盘空间不足等原因导致。在这些情况下，应进入恢复步骤以使应用程序再次处于可用状态。另一种方法是向用户显示 UI 存在问题并且需要进行重置。我们的应用程序模板无法为您的应用程序制作良好的 UI，而这几乎就是在此闭包中需要做的事情。

> 在 SwiftUI 中，我们通常会使用 environment 为视图树注入视图上下文，一旦 loadPersistentStores 出现错误导致 container 无法正常创建，那么调用上下文的注入将会失败，导致无法进入 UI 界面。如需要处理这种情况，就需要在主视图（ 或使用 Core Data 功能的根视图 ）对 Container 的状态进行判断（ 通常是在 loadPersistentStores 闭包中修改状态 ），转入失败提示逻辑。

### 共享数据出现错误

Q：我的问题是关于 Core Data with CloudKit 的。我已经成功使用 NSPersistentCloudKitContainer 实现了用户跨设备同步数据，但在共享数据方面的运气要差得多。我已经查看了两个相关的示例项目，现在可以进行到创建新共享的地步，但是任何管理现有共享的尝试（ 即添加人员等 ）似乎总是失败。我在控制台中看到了一些神秘的消息，例如“创建与 PPT 通信所需的 CFMessagePort 时出错”。如果我说尝试进行数据共享，如果 CKShare 不存在，它可以工作 - 万岁！但是，如果我第二次共享并且 CKShare 已经存在，它只会出现永远旋转的风火轮。这既出现于 UICloudSharingController，也出现于较新的 ShareLink/CKShareTransferRepresentation 版本。在示例代码中也看到了类似的问题。我的问题是 - 此种使用方式是否存在已知问题？有什么特别要记住的吗？

A：请使用 sysdiagnose 提交反馈报告以及受影响设备的存储文件。

*不止你一个人。我们在 CKShare 和 NSPersistentCloudKitContainer 上也遇到了很多麻烦。例如，从符合 Transferable 的结构中共享 URL 实例根本不起作用。 ShareLink 只是显示一个空的弹出窗口（ 另一个开发者的吐槽 ）*。

> 十分遗憾，苹果在为 Core Data with Cloud 添加了数据共享功能后，并没有进一步改善它的表现。目前共享数据的使用体验并不能令人满意。想了解如何共享数据以及了解当前它的限制请阅读 [创建与多个 iCloud 用户共享数据的应用](https://www.fatbobman.com/posts/coreDataWithCloudKit-6/) 一文。

### 保存音视频数据的建议方式

Q：在使用 Core Data with CloudKit 时，对于处理音频文件或图像文件存储，是否有任何推荐的方法。我知道对于较大的数据，最好将其存储在 CoreData 本身之外。

A：这取决于它们的大小。假如尺寸超过 100MB，尽量考虑自己管理文件数据。开发者可以考虑将非常大的文件创建为 CKAsset ，在他们的 NSPersistentCloudKitContainer 同步对象中保存一个外键，以便他们可以查找。这种方法可以减少同步的下载数据量（ 节省设备存储容量 ）并允许按需下载。

> 这是 Core Data with CloudKit 与纯 CloudKit API 相结合的一种方式。以图像举例，开发者可以考虑只在 Core Data 中保存一个小尺寸的缩率图，将大尺寸图片通过 CloudKit API 以 CKAsset 的方式保存在云端（ 在对应的 Core Data 数据中保存一个外链 ），用户在点击图片时，才会从云端将数据下载到本地，并保存在一个缓存目录中。

### 是否有最大同步尺寸或数量限制

Q：Core Data with CloudKit 是否最大同步尺寸限制？我在一个应用程序中尝试它，该应用程序有 30,000 多条记录，但它们无法从 Mac （ 开发状态 ）同步到 iPhone（ 开发状态 ）。

A：如果没有更多细节，很难确定。 NSPersistentCloudKitContainer 和 CloudKit 可以支持比某些限制（如设备存储）多两个数量级的数据。

> 理论上，可以同步的数量和尺寸只上取决于用户的 iCloud 可用容量。在某些情况下，开发者需要在 macOS 上手动开启应用的 iCloud 同步选项（ 尤其是在开发阶段 ），否则无法与其他的设备进行同步。 

### 如何重置本地数据

Q：想象一下，Core Data 正使用 NSPersistentCloudKitContainer 在所有设备上同步我的应用程序数据。假若其中一台设备出现某种故障，需要从云中的数据重置该设备的数据（ 并且有该设备的数据 ）。我的应用程序中是否有任何方法可以重置数据的本地缓存副本以假装它是新设备并让 CoreData 再次从云中获取所有数据？

A：使用 NSPersistentStoreCoordinator 的 destroyPersistentStore(at:type:options:) 方法，彻底销毁本地数据库。

> 销毁数据库后，还需要重新在本地创建新的数据库。相较于开发者使用文件管理的方式删除 SQLite 数据，这种方法更加地安全。另外，数据库迁移也可以通过 NSPersistentStoreCoordinator 的 migratePersistentStore(_:to:options:type:) 方法来实施。

### 如何保存枚举类型

Q：在 Core Data 中存储 Swift 枚举（ 有或没有关联值 ）的推荐方法是什么？

A：一种可能的解决方案是将枚举存储为 Transformable 以处理关联值的情况。 在没有枚举值的情况下，通过 rawValue 可以将其转换为 Core Data 支持的任意属性类型之一。

> 使用 Transformable 处理包含关联值的枚举有一定的局限性，1、有一定的性能损失；2、无法在 Core Data 中通过谓词对其进行查询。如果你对查询有特别的需求的话，可以将枚举类型中关联数据打散，在实体中，将所有的关联值都定义成属性，并增加一个与枚举对应的类型属性，在托管对象中定义一个枚举类型的计算属性，通过它对数据进行转换。虽然这种方式会浪费一定的存储空间，但具备转换效率高和可查询的优势。

### 是否可以显示同步进度并手动触发同步

Q：使用 NSPersistentCloudKitContainer 时，是否可以确定当前同步状态或手动触发同步？我希望能够在 UI 中显示进度视图，以便首次启动应用程序的用户可以看到他们的数据正在从云中下载。

A：NSPersistentCloudKitContainerEvent 填补了这个角色。您可以根据需要将通知侦听器绑定到事件以更新和显示状态。无法主动触发同步。

> NSPersistentCloudKitContainer 提供了一个 eventChangedNotification 通知，该通知将在 import、export、setup 三种状态切换时会提醒我们。严格意义上，我们很难仅通过切换通知来判断当前同步的实际状态。更多内容请参阅 [Core Data with CloudKit（四）—— 调试、测试、迁移及其他](https://www.fatbobman.com/posts/coreDataWithCloudKit-4/) 。

### 是否必须添加新版本的 Model

Q：我们什么时候需要添加新的 CoreData model 版本？我看到关于轻量级迁移的相互矛盾的建议，为每个版本添加一个新版本是否更安全？

A：在每个版本中添加一个新的托管对象模型会更安全，但是如果您从一个版本到另一个版本的更改经过充分测试以表明适用于轻量级迁移推断，那么单个托管对象模型就足够了。

> 对于已经上线的应用，最好还是采用手动添加一个新的版本的模式。除了更加安全外，也方便跟踪旧版本模型的变化。

### SwiftUI 下如何使用 FetchedResultsController

Q：是否有在 SwiftUI 应用程序中使用 Core Data 的任何实践或建议？假如广泛使用 Core Data，是否仍应该坚持使用 UIKit。例如，FetchedResultsController 是否有对应的 SwiftUI 版本？

A：在 SwiftUI 中使用 CoreData 没有问题。您可以通过 [@FetchRequest](https://developer.apple.com/documentation/swiftui/fetchrequest)  从存储中获取检索结果。

> @FetchRequest 是个让人又爱又恨的东西。它很好用，几乎是在视图中获取数据的首选。但对于 Redux-like 框架的使用者来说，它更像一个破坏者，让大量的数据游离于应用的单一状态之外。让单一状态框架与  @FetchRequest 更好地结合目前仍是一个课题。

### 运行 initializeCloudKitSchema 方法的时机

Q：在使用 Core Data with CloudKit 时，如果我在 Core Data Stack 中编辑持久化存储（ 例如，为共享对象添加新的持久化存储 ），而不触及实体及其属性，我应该运行 initializeCloudKitSchema 吗？

A：只有对托管对象模型进行更改时才需要 initializeCloudKitSchema。 一旦它针对 CKContainer 运行，该容器中的所有数据库都将具有相同的 Schema（ 公共/私有/共享 ）。

> initializeCloudKitSchema 通常是在开发阶段使用的一种方法，而且只需要在数据模型创建或变化后使用一次。当 CKContainer 已经创建了对应的 Schema 后，应该在你的代码中删除或注释掉该行代码。另外，initializeCloudKitSchema 还提供了一个 dryRun 选项，用于在单元测试中检查数据模型是否满足 CloudKit 的要求（ 只比对不上传 ）。

### 多线程的调试手段

Q：调试 Core Data 在多线程方式下的访问错误/崩溃的最佳方式是什么？我一直在使用 `-com.apple.CoreData.Logging.stderr 1` 和 `-com.apple.CoreData.ConcurrencyDebug 1` 参数来提供帮助。还有其他建议吗？

A：ASAN 也将有助于捕获并发问题导致的内存错误。

> 参阅 [关于 Core Data 并发编程的几点提示](https://www.fatbobman.com/posts/concurrencyOfCoreData/) 了解更多细节。

### 在 App Group 中如何立即反应变化

Q：当通过应用程序扩展（例如，SiriKit/AppIntents ）向存储提交更改时，保证更改立即反映在可能已经运行的主应用程序中的最佳方式是什么（ 反之亦然 ）？在应用程序和扩展程序中同时使用 NSPersistentContainer 的 viewContext 是否安全/推荐，或者应使用后台上下文的工作？在我的设置中，存储被保存到一个应用程序组目录中，以允许从应用程序和扩展程序访问，所以我认为每个进程都将利用各自的容器来访问它。 

A：这可以使用 [本文](https://developer.apple.com/documentation/coredata/sumption_relevant_store_changes) 中提到方法，通过设置你的 NSPersistentStoreDescription 远程更改选项来实现。

> 持久化历史跟踪正是为类似需求准备的解决方案。参阅 [在 CoreData 中使用持久化历史跟踪](https://www.fatbobman.com/posts/persistentHistoryTracking/) 一文，了解更多实现细节。

```responser
id:1
```

### 避免在小组件中执行复杂任务

Q：我们遇到了一系列崩溃，因为我们在一个 Widget 进程和一个应用程序进程中启动了相同的 CoreData 堆栈。通常这可以正常工作，但是一旦存储需要迁移（ 我们进行轻量级迁移 ），就会出现某种竞争状况，导致应用程序或小组件进程发生崩溃。在一次崩溃之后，迁移似乎可以正常工作，并且没有发生再次崩溃。是否有一个很好的解决方案如何解决这些崩溃？我们不确定 CoreData 是否正确处理了这件事，或者我们是否需要检测迁移并解决这些崩溃问题。

A：不应赋予 Widget 执行轻量级/推断迁移的能力。只有应用程序应该这样做。如果 Widget 遇到需要迁移的 CoreData Store，则 Widget 应重定向以启动应用程序。实际上，小部件永远不会从操作系统获得足够的资源来完成迁移。

> 小组件的运行资源有限，譬如持久化历史事务清除的操作也不应该在小组件中进行处理。

### 持久化历史事务的删除时机

Q：在 [Consuming Relevant Store Changes](https://developer.apple.com/documentation/coredata/consuming_relevant_store_changes) 的“清除历史记录”中提到：“因为持久历史跟踪事务会占用磁盘空间，所以确定一个清理策略以在不再需要它们时将其删除”。但是，没有给出明确的提示关于如何在不影响 CloudKit 正确性的情况下以安全的方式清除历史。给出的示例是删除所有超过 7 天的事务。但是，为什么是 7 天？为什么不是 14 天？非常希望一个可靠而具体的示例，说明如何安全地清除历史数据以防止磁盘空间浪费。

A：清除历史记录是由客户决定的。通常，应用每年或每半年清除一次历史记录。你的特定应用程序的写入速率可能需要不同的时间窗口，但是当使用 NSPersistentCloudKitContainer 清除历史记录时，可能会强制将存储文件数据全面同步到 CloudKit，因此不建议经常这样做。

> 无论进行清除的时间间隔为多少，我都不建议开发者清除 CloudKit 为自动同步创建的历史事务（ 绝大多数情况下，NSPersistentCloudKitContainer 会在确保同步完成后自动进行删除 ）。在进行删除操作时，应在 NSPersistentHistoryChangeRequest 中，忽略掉由系统产生的事务，只删除应用程序或程序组产生的事务。具体内容请参阅 [在 CoreData 中使用持久化历史跟踪](https://www.fatbobman.com/posts/persistentHistoryTracking/) 一文。

### 如何为 NSDictionary 创建模型

Q：我有一个 NSDictionary 值，需要存储在 Core Data 中。使用 Transformable 属性或 Binary Data 属性来存储它，哪个方案更好？ Binary Data 可以选择外部存储，而且我不相信 Transformable。当从存储获取数据时，这两个选项是否都会被加载到内存中？或者支持懒加载（ fault ）？不确定哪个更好用。

A：两者会有相同的内存状况。理想情况下的答案是“两者都不是好的选择” 。如果可能的话，你应该为字典建模（ 使用 Core Data 的方式，创建两个实体，通过关系来映射这个字典 ）。

> 很多情况下，不应将传统的数据组织方式照搬到 Core Data 的 Model 中。尽量用适于 Core Data 架构的方式来设计数据结构。尽管可能会有一定的性能损失和容量浪费，但对总体收益会更加有利。例如上面的情况，使用关系的方式来处理有如下优势：1、支持查询；2: 在开启同步的情况下，每次修改仅需同步修改部分；3: 无需担心转换性能。

### 是否必须设置逆关系

Q：在数据模型中设置关系的逆关系（ 通常在创建关系时都会设置对应的逆关系 ）有多重要？是否有可以不设置逆关系的相关例子？

A：定义逆向关系使得管理你的图表更容易（ 比如，设置一个“父级”会自动为对象添加为一个“子级” ），并且还允许你委托给 Core Data 进行图表清理（ 比如，你想删除一个 “发票” 同时也删除其所有 “项目” ）。如果您不需要这些语义，则不需要逆向，但大多数情况下，双向遍历都很有用。值得注意的是，如果您想使用 CloudKit 同步，则需要明确逆向关系。我强烈建议为所有关系设置逆向关系，直到它对性能产生重大影响时再考虑删除它。

> Core Data with CloudKit 为了突破 CloudKit API 中对于关系数量（ CKRecord.Reference 不能超过 750 个 ）的限制，采用了双向关联的方式。因此，只有明确逆关系，Core Data with CloudKit 才能在云端创建正确的 Schema。

### NSPersistentStore 的元数据

Q：NSPersistentStore  的元数据是否保存在磁盘上？可以用其了解设备是否执行了某种云迁移或其他活动吗？

A：Core Data 将元数据存储在存储文件本身中。此元数据归 Core Data 所有，不建议你更改它。如果你愿意，可以将自己的元数据存储在存储文件中，但请注意你的密钥不要与现有的 Core Data 拥有的密钥重叠。元数据受到与存储文件的其余内容相同的数据保护。

> 在有一段时间（ 主要针对文档应用 ），开发者喜欢通过自定义元数据来保存一些选项以方便跨设备使用。阅读 [Core Data 是如何在 SQLite 中保存数据的](https://www.fatbobman.com/posts/tables_and_fields_of_CoreData/) 一文，了解更多有关 Core Data 元数据的内容。

### 是否有必要同步中间数据

Q：当我使用 Core Data with CloudKit 时，快速保存数千个 GPS 位置的最佳方法是什么？当数据很多时，它会达到服务器极限。

> 冗长的讨论。提问者开发的是一款锻炼用途的应用，他需要在使用者锻炼期间存储所有的位置（坐标、速度、路线、时间戳），以便可以绘制一条折线。但并不需要在所有的设备上保留这些 GPS 信息（ 仅需要保存对这些数据的汇总信息 ）。苹果的工程师建议他通过创建另一个 Configuration 的方式，将这些数据保存在本地存储中（ 不进行同步 ），只将汇总后的信息保存在同步存储中。阅读 [同步本地数据库到 iCloud 私有数据库](https://www.fatbobman.com/posts/coreDataWithCloudKit-2/) 一文，了解如何通过创建多个 Configuration 实现有选择性地同步数据。

### 如何加密数据库

Q：如果我使用 NSPersistentStoreFileProtectionKey: FileProtectionType.complete 来加密我的数据库，当用户将手机数据备份到 iCloud 后，它会以加密格式存储吗？还是仅在设备上加密？

A：NSFileProtection 仅影响设备上数据的加密状态。

> 从 iOS 15 开始，可以在 Model Editor 中将属性启用加密选项（ 不支持老版本的 Model 升级）。在使用 Core Data with CloudKit 时，该属性的值将在 iCloud 中以加密的形式进行保存。Core Data 目前并不支持对 SQLite 进行加密。

### NSExpression 的 Bug

Q：我应该如何看待 NSExpression 中的 CAST 函数？这是我应该积极使用的功能吗？例如，如果我写 `CAST(now(), 'NSNumber')` 意图在当前时间做数学运算，我会收到 “Don't know how to cast to NSNumber” 的错误。

A：这是一个很好的问题。 我们建议您将其发布在开发者论坛中，Apple 工程师将在此进行整周的监控，并能够为您提供进一步的帮助。这似乎值得一个错误报告

> 使用 NSExpressionDescription ，可以在 SQLite 中对记录进行一定的计算，并将计算结果通过 NSFetchRequestResult 进行返回。阅读 [在 Core Data 中查询和使用 count 的若干方法](在 Core Data 中查询和使用 count 的若干方法) 一文，查看使用案例。

### 合并策略 or 选择性更新

Q：当前我们的 Core Data Stack 采用了 NSMergeByPropertyStoreTrumpMergePolicy 合并策略，它本质上是替换一个已经存储在我们存储中并在从 API 中拉下时由唯一约束标识的对象。另一种方法是通过获取请求（ fetch request ）确定对象是否已经存在，如果存在，则更新现有记录，如果不存在则创建新记录。在 Apple 看来，哪种方式是处理记录创建和更新的首选方式？

A：每种方法都有优点和缺点。一般来说，首先获取记录（ 通过 Core Data 在存储中检查数据是否存在 ）往往非常昂贵。如果您必须这样做，则必须批量获取。在此流程中一次获取一条记录将非常缓慢。

> 如果 Core Data 内置的合并策略无法满足你的需求时，创建自定义合并策略或许是不错的选择。

### 在多对多关系中创建谓词

Q：我的视频实体与标签具有多对多关系，并且我有一个带有一些标签 ID 的数组。我想获取在这组标签 ID 中至少有一个标签的所有视频。如何创建一个 NSPredicate 来表示这个？

A：或许可以尝试一下 `ANY tag.name IN %@`。

> %@ 对应的是标签数组。应该用 Core Data 的逻辑来组织数据并创建谓词，Core Data 会将谓词转换成对应的 SQL 语句。

### 动态修改 @FetchRequest 的配置

Q：在 SwiftUI 应用程序中，如何基于 @AppStorage 值创建 @FetchRequest？用例是：当我打开 Focus 过滤器时，我将 @AppStorage 值更改为用户希望在我的应用程序中看到的标签列表。如果我可以创建一个带有与此 @AppStorage 的值相关联的谓词的 @FetchRequest，则谓词将自动更新，并更新我的视图。目前我无法做到这一点，哪种解决方法能获得类似的结果？

A：@FetchRequest 的谓词属性是一个 Binding，它会在更改时重绘视图。

> 从 Swift 3.0 开始，FetchRequest 支持在视图中动态修改它的谓词和排序描述。例如上面的问题，可以通过在 task(id:) 中更改 request 的配置。

### uriRepresentation

Q：我现在正在为我的应用程序实现一个 URL 方案，我想提供一个打开特定 Core Data 对象的 URL。 有没有比在我的 URL 方案中使用 `NSManagedObject.objectID.uriRepresentation().absoluteString` 作为标识符更好的方法。

A：我想这也是我会做的。

> 使用 NSPersistentStoreCoordinator 的 managedObjectID(forURIRepresentation: ) 方法，可以将 URL 转换回对应的 NSManageObjectID。阅读 [在 Spotlight 中展示应用中的 Core Data 数据](https://www.fatbobman.com/posts/spotlight/) ，了解更多细节。

### 在同步状态下，如何进行大版本迁移

Q：嗨，在使用 Core Data 和 CloudKit 堆栈时遇到了一个关于迁移的问题。如果我们不再关心本地数据，是否可以从与 CloudKit 同步的数据模型中删除未使用的实体？在我们的例子中，我们首先从实体中删除所有数据（ 也就是将该数据迁移到新实体 ），然后从项目中删除该实体，因为我们可以确定所有用户都已升级。

A：是的，但是，旧版本的应用程序会做什么？从用户角度，旧版本将写入新版本从未见过的数据，而新版本将写入旧版本从未见过的数据。您将如何向您的用户解释这种差异？

> 在使用 Core Data with CloudKit 时，对数据模型最好采用只增不改不减的调整原则。如果确实需要对数据模型有破坏性的修改，最好创建两个 Container（ 分别使用不同的 Model ），在使用者确保原始数据都同步到本地后，再将旧数据转换至新的 Container 之上。

### 是否可以为共享数据创建单独的 CKRecordZone

Q：我有一个基于文档的应用程序。每个文档都是一个包含唯一 Core Data 存储的包。我想使用 Core Data 的内置 CloudKit 同步 API 分别同步每个文档。如何为每个文档创建唯一的 CKRecordZone ？

A：当前的 NSPersistentCloudKitContainer 不支持这样的用法。

> 或许可以考虑使用纯粹的 CloudKit API 来实现他的需求。

### 是否可以使用 @unchecked Sendable 标注 NSManagedObjectID

Q：在可以确保 NSManagedObjectID 不是临时状态的情况下，是否可以使用 @unchecked Sendable 对其进行标注。

A：它应该是。 请提交错误报告。

> 在 Core Data 中，NSManagedObjectID 是线程安全的。通过向其他的上下文传递 ID，并通过该 ID 在不同线程的上下文中获取托管对象，这样可以确保应用不会出现崩溃。

## 总结

Ask Apple 中有关 Core Data 的问题应该不是太多，我提的几个问题都获得了解答。希望苹果今后可以经常性地举办类似的活动，大家也应该更踊跃地进行参与。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ) 或博客的留言板与我进行交流。

> 我正以聊天室、Twitter、博客留言等讨论为灵感，从中选取有代表性的问题和技巧制作成 Tips ，发布在 Twitter 上。每周也会对当周博客上的新文章以及在 Twitter 上发布的 Tips 进行汇总，并通过邮件列表的形式发送给订阅者。

**订阅下方的 [邮件列表](https://artisanal-knitter-2544.ck.page/d3591dd1e7)，可以及时获得每周的 Tips 汇总。**
