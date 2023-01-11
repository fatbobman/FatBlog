---
date: 2021-11-02 08:10
description: 或许觉得比较枯燥，亦或许感觉 Xcode 提供的模版已经满足了使用的需要，很多 Core Data 的使用者并不愿意在 Core Data Stack 的了解和掌握上花费太多的精力。这不仅限制了他们充分使用 Core Data 提供的丰富功能，同时也让开发者在面对异常错误时无所适从。本文将对 Core Data Stack 的功能、组成、配置等做以说明，并结合个人的使用经验聊一下如何设计一个符合当下需求的 Core Data Stack。本文并不会展示一个完整的创建代码，更多是原理、思路和经验的阐述。
tags: Core Data
title:  掌握 Core Data Stack
image: images/coreDataStack.png
---
或许觉得比较枯燥，亦或许感觉 Xcode 提供的模版已经满足了使用的需要，很多 Core Data 的使用者并不愿意在 Core Data Stack 的了解和掌握上花费太多的精力。这不仅限制了他们充分使用 Core Data 提供的丰富功能，同时也让开发者在面对异常错误时无所适从。本文将对 Core Data Stack 的功能、组成、配置等做以说明，并结合个人的使用经验聊一下如何设计一个符合当下需求的 Core Data Stack。本文并不会展示一个完整的创建代码，更多是原理、思路和经验的阐述。

```responser
id:1
```

## 什么是 Core Data Stack ##

### 功能 ###

在使用 Core Data 的应用程序中，将将管理并持久化应用的模型层视为 Core Data Stack。在 Core Data Stack 中，通过创建并配置 Core Data 提供的一组相互配合的类的实例来为应用程序提供对象图管理、数据持久化等服务。

Core Data Stack 对其实例的命名、类型没有具体的要求，你可以根据自己的习惯和需求使用结构、类来创建、组织自己的代码。

### 组成 ###

一个最基本的 Core Data Stack 至少要由以下四个类的实例构成：

* NSManagedObjectModel（托管对象模型）
* NSManagedObjectContext（托管对象上下文）
* NSPersistentStoreCoordinator（持久化存储协调器）
* NSPersistentStore（持久化存储）

下面这张图表说明了它们之间的关系：

![coreDataStack](https://cdn.fatbobman.com/coreDataStack.svg)

#### NSManagedObjectModel ####

每个 Core Data Stack 都要有一个 NSManagedObjectModel（托管对象模型）实例，可以将其看作是实际数据模型的程序呈现。

通常我们会使用 Xcode 提供的数据模型编辑器来创建数据蓝图，并在其中定义应用程序使用的 Entity（实体）、Attributes（属性）、RelationShip（关系）、Configurations 等。

数据模型编辑器将定义的结果保存成 XML 格式的文件，Xcode 会在编译项目时将该文件编译成尾缀为 momd 的二进制文件并放置在 Bundle 中，在创建 NSManagedObjectModel 实例时，实际使用的即为该文件。

#### NSManagedObjectContext ####

NSManagedObjectContext（托管对象上下文）可以将其看作一个类似绘图的刮擦板，我们可以在其中任意绘画，并随时清除。

托管对象上下文的主要职责是管理 NSManagedObject（托管对象）实例的集合，对托管对象的获取、创建、删除、修改等操作绝大多数都是在此进行。托管对象上下文内置撤销管理器，提供了 Undo/Redo 的功能。

托管对象上下文将确保一个上下文中不会出现多个托管对象实例对应同一个持久存储记录的情况，并提供了其它诸如缓存、更改跟踪、惰性加载、数据验证、变更通知等功能。

它位于 Core Data Stack 的顶部，在应用程序与 Core Data Stack 之间承担着主要的交互职责。

应用程序通常至少需要创建一个运行于主线程的托管对象上下文实例。实际使用中创建多个托管对象上下文的情况并不少见。

#### NSPersistentStore ####

NSPersistentStore（持久化存储）是所有 Core Data 持久存储的抽象基类，通过指定存储类型（SQLite、Binary、XML 和 Memory）创建不同的实例。持久化存储提供了一种标准的 API，将 Core Data 的内部数据对象、逻辑、操作转换成对应存储类型的指令或记录。

如果 Core Data 预置的四种存储类型不能满足你的需要，开发者也可以为自己的数据源定制所需的持久化存储。

在几年前，多数应用只需创建一个持久化存储。随着 Core Data with CloudKit 的不断普及，拥有多个持久化存储的应用越来越多。

#### NSPersistentStoreCoordinator ####

NSPersistentStoreCoordinator（持久化存储协调器）在 Core Data Stack 中起到了胶水的作用。作为协调器，它为其它组件之间创建了沟通的桥梁。无论是托管对象模型、托管对象上下文、或者持久化存储都以持久化存储协调器为核心进行协作。

处于效率的考虑，数据批量处理、CoreData with CoreSpotlight、数据库迁移等应用场合通常都需要开发者直接和其打交道。

如上图所示，一个持久化存储协调器只对应一个托管对象模型，但可以与多个托管对象上下文和多个持久化存储配合使用。

> 看到这里，应该会有不少读者认为本文有了一个巨大的遗漏——NSPersistentContainer。作为近几年最常用的创建 Core Data Stack 的手段，截至目前还没有做介绍。NSPersistentContainer 创建的初衷即为简化上述模组的配置复杂度，在其内部仍以上面四个组件为主。下文中，将以 NSPersistentContainer 的诞生为分界线，分别介绍在其出现前后的 Core Data Stack 的创建过程，让读者对 Core Data Stack 的发展进程和实现原理有更多的了解。

## 没有 NSPersistentContainer 的时代 ##

在 NSPersistentContainer 诞生之前（Xcode 8 以前），我们通常会采用如下的流程通过上述的四大组件来创建 Core Data Stack。

* 实例化一个托管对象模型

要创建一个 NSManagedObjectModel 的实例，需要从应用程序包中加载数据模型文件。大致的代码如下：

```swift
  guard let url = Bundle.main.url(forResource: "Model", withExtension: "momd") else {fatalError()}
  guard let model = NSManagedObjectModel(contentsOf: url) else {fatalError()}
```

* 实例化持久化存储协调器

创建持久化存储协调器需要使用托管对象模型实例，只有掌握了应用程序的数据模型后，协调器才能添加持久化存储。

```swift
let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
```

* 创建持久化存储

创建持久化存储时，需要指定存储类型、配置名称（在数据模型编辑器中设置）、路径等信息。对于已经存在的数据库文件，持久化存储协调器将检查它是否同托管对象模型的定义完全一致。

```swift
        guard let store = try? coordinator.addPersistentStore(type: .sqlite,
                                                              configuration: "Local",
                                                              at: localURL,
                                                              options: nil)
        else {
            fatalError()
        }
```

* 创建托管对象上下文并保留对托管对象的引用

创建托管对象上下文，设置其类型（主线程或后台线程），并保留持久化存储协调器的引用

```swift
        let viewContext = NSManagedObjectContext(.mainQueue)
        viewContext.persistentStoreCoordinator = coordinator
```

> 如果单纯从代码量上来看，即使不使用 NSPersistentContainer，创建一个具有基本功能的 Core Data Stack 也用不了几行代码。但此种创建方式要求开发者对 Core Data 的几大组件要有充分的认识和掌握才能完成。NSPersistentContainer 正是为了降低开发者创建 Core Data Stack 的门槛而诞生的。

## NSPersistentContainer 开启的新时代 ##

### Xcode 8.x —— Xcode 10.x ###

自 Xcode 8.0 开始，苹果为 Core Data 推出了 NSPersistentContainer（持久化容器）。

NSPersistentContainer 将托管对象模型、持久化存储协调器、托管对象上下文以及持久化存储都封装到了一起，简化了 Core Data Stack 的创建和管理。

可以将一个 NSPersistentContainer 的实例视为一个简化版本的 Core Data Stack，Xcode 中提供的模版可以应对大多数的场景下对 Core Data Stack 的需求。

下面便是 Xcode 13 中提供的 Core Data 模版的部分代码。

```swift
struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Model")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
    }
}
```

无需任何托管对象模型、持久化存储协调器以及持久化存储的知识，开发者便可以创建 Core Data Stack。

NSPersistentContainer 一方面极大地降低了 Core Data 的使用门槛，同时也造成了很多新的 Core Data 使用者对 Core Data 的内部运作原理不明而无法深入使用 Core Data 的局面。

直到 Xcode 11 NSPersistentCloudContainer 推出之前，NSPersistentContainer 的作用仅限于简化 Core Data Stack 创建，本身并没有提供什么新的功能。

### Xcode 11.x —— 至今 ###

从 Xcode 11 开始，苹果推出了 NSPersistentCloudContainer，将 Core Data 同 CloudKit 两者之间的壁垒打通。至此，NSPersistentContainer 逐渐开始拥有了自己独有的功能，并愈发地重要起来。

NSPersistentCloudContainer 是 NSPersistentContainer 的子类，它在简化传统 Core Data Stack 创建的基础上，提供了对于 CloudKit 网络数据库的支持。目前多数同网络数据库有关的方法和属性都只能在 NSPersistentCloudContainer 中进行操作。由于苹果没有公开 NSPersistentCloudContainer 的内部细节，导致目前针对 Core Data 的第三方 Stack 封装库仅能支持本地存储（无法使用 Core Data with CloudKit 的功能）。

## 当下的 Core Data Stack 中都有些什么内容 ##

近年来，随着 Core Data 的功能不断增强，Core Data Stack 中包含的内容也越来越多。即便使用了 NSPersistentContainer，代码也不可避免的重新复杂起来。

### Core Data with CloudKit ###

作为苹果生态优势的集中体现，越来越多应用程序都提供了基于 Core Data with CloudKit 的网络同步功能，为此就需要在 Core Data Stack 中为网络同步进行更多的设定和扩展。

> 更多关于 NSPersistentCloudContainer 的信息，请参阅我关于 [Core Data with CloudKit](https://www.fatbobman.com/tags/cloudkit/) 的系列文章。

除了在 Core Data Stack 中使用 Core Data 框架提供的网络同步方法和属性外，很多开发者都会在 Core Data Stack 的层面创建适合项目应用的方法。例如，苹果在关于 [数据共享的例程](https://developer.apple.com/documentation/coredata/synchronizing_a_local_store_to_the_cloud) 中，为共享参与者、创建 CKShare、获取 CKShare、数据权限判定等方面在 Core Data Stack 上创建了不少便捷方法。

### Persistent History Tracking ###

近年来，在苹果的大力推广下，越来越多的应用程序提供了 Widget（桌面部件），或通过 App Group 方式让多个应用程序共享相同的数据内容。

对于使用 Core Data 的应用来说，为 Core Data 启用 Persistent History Tracking（持久化历史跟踪）功能可以让用户获得更好的使用体验。另外，苹果的一些新 API 也要求必须在开启持久化历史跟踪的情况下方可使用。

因此，Core Data Stack 中又新增了对于 Persistent History Tracking 的设定和事务处理功能需要。

> 更多关于 Persistent History Tracking 的内容，请参阅我的文章 [在 CoreData 中使用持久化历史跟踪](https://www.fatbobman.com/posts/persistentHistoryTracking/)。

### CoreData with CoreSpotlight ###

在 WWDC 2021 上，苹果推出了新版的 NSCoreDataCoreSpotlightDelegate API。该 API 极大地降低了在系统 Spotlight 上维护应用程序中的 Core Data 数据的难度。由于创建 NSCoreDataCoreSpotlightDelegate 需要使用 NSPersistentStoreDescription 和 NSPersistentStoreCoordinator ，因此同样需要在 Core Data Stack 中来完成这些工作。Core Data Stack 的内容和功能也将进一步增多。

> 更多关于 NSCoreDataCoreSpotlightDelegate 的内容，请参阅我的文章 [在 Spotlight 中展示应用中的 Core Data 数据](https://www.fatbobman.com/posts/spotlight/)。

```responser
id:1
```

## 该暴露 Context 还是 Container ##

几年前的 Core Data Stack，对外通常只需要提供一个 NSManagedObjectContext 的实例即可。通过该实例，我们可以获取到持久化存储协调器，通过协调器可以获取到托管对象模型以及持久化存储。

但在使用了 NSPersistentContainer 之后（尤其是 NSPersistentCloudContainer），开发者无法通过托管对象上下文获得到对应的持久化容器，从而无法调用持久化容器特有的属性和方法。

因此，在目前的 Core Data Stack 中最好也能将持久化容器暴露给其它的模块或代码以方便使用。

## 使用结构还是类 ##

目前 Xcode 提供的 Core Data 模版使用结构来定义 Core Data Stack。以我个人的使用经验来看，如果你的 Core Data Stack 的功能需求较多，代码较复杂，类或许是更好的选择。原因有二：

* 在一个应用程序中通常只需要一个 Core Data Stack 实例，使用类的单例将给我更好的安全感，也方便在代码不同的地方对 Stack 进行访问。
* 如果你需要在 Core Data Stack 中处理持久化历史跟踪的事务通知或者调用 NSCoreDataCoreSpotlightDelegate 的话，使用类更方便编程。具体可参阅我之前提供的两篇文章。

## 为 Core Data Stack 创建多个配置模式 ##

### 为什么要创建多个配置 ###

如今创建一个 Core Data Stack 除了需要保证程序的正常运行功能所需外，最好同时为 Unit Test，SwiftUI 的 Preview 等场景做以准备。通过 Core Data Stack 构造函数的参数或应用程序的启动参数，为 Core Data Stack 创建应对不同场景的多个配置。

### 内存模式 ###

在 Xcode 提供的 Core Data 模版中，已经为开发者提供了内存模式的配置和如何在内存模式下创建测试数据的演示。

需要注意的是，此处所说的内存模式对应的存储类型仍为 SQLite（并非 NSPersistentStore 支持的四种存储模式之一的内存模式），通过将持久化存储的存储路径设置为`/dev/null`，从而达到只在内存中保存数据的效果。

使用参数来设定内存模式：

```swift
    /// 是否开启仅内存模式。可以通过启动参数 -InMemory 1 或 构造函数的参数 inMemory:true 开启
    private let _inMemory: Bool
    private lazy var inMemory: Bool = {
        let arguments = ProcessInfo.processInfo.arguments
        var allow = false
        for index in 0..<arguments.count - 1 where arguments[index] == "-InMemory" {
            allow = arguments.count >= (index + 1) ? arguments[index + 1] == "1" : false
            break
        }
        return allow || _inMemory
    }()
```

在 Xcode 的模版中，内存模式同非内存模式是无法共存的，这在绝大多数的情况下都是合理的。

在开发中的 [健康笔记 3](https://www.fatbobman.com/healthnotes/) 里，我需要让内存模式同非内存模式共存，也就是在特定的情况下，应用程序中同时会存在两个使用同样托管对象模型的 Container，并可随时切换。为了应对同一个托管对象模型文件只能在应用中被一个实例所持有的问题，可以通过创建一个 NSManagedObjectModel 实例，然后分别用该实例来创建 NSPersistentCloudContainer 的方式予以解决。

```swift
class CoreDataStack {
    private static var _model: NSManagedObjectModel?
    static func model(name: String = CoreDataStackSetting.defaultModelName) -> NSManagedObjectModel {

        if _model == nil {
            do {
                _model = try loadModel(name: name, bundle: Bundle.main)
            } catch {
                let err = error.localizedDescription
                fatalError("❌数据库 momd 文件无法加载")
            }
        }
  
        return _model!
    }

    private static func loadModel(name: String, bundle: Bundle) throws -> NSManagedObjectModel {
        guard let modelURL = bundle.url(forResource: name, withExtension: "momd") else {
            fatalError("❌数据库 momd 文件无法加载")
        }
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("❌数据库 momd 文件无法解析")
        }
        return model
    }
    
    public lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(
            name: modelName,
            managedObjectModel: Self.model(name: modelName)
        )
        // 其它配置代码   
        ........
    }
}
```

### 无需网络同步的模式 ###

在使用 Core Data with CloudKit 的应用中，我们无需在每次代码调试时都启用网络同步功能。通过参数关闭网络同步，简化调试流程，减少因网络同步产生的大量控制台输出。

使用参数设置网络同步：

```swift
   /// 是否允许网络同步，可以使用构造器参数 allowCloudKiteSync = false 或 启动参数-AllowCloudKitSync 0 来禁止网络同步
    private let _allowCloudKitSync: Bool
    private lazy var allowCloudKitSync: Bool = {
        let arguments = ProcessInfo.processInfo.arguments
        var allow = true
        for index in 0..<arguments.count - 1 where arguments[index] == "-AllowCloudKitSync" {
            allow = arguments.count >= (index + 1) ? arguments[index + 1] == "1" : true
            break
        }
        return allow && _allowCloudKitSync
    }()
```

关闭网络同步：

```swift
        if !allowCloudKitSync {
            privateDescrition.cloudKitContainerOptions = nil
            shareDescription.cloudKitContainerOptions = nil
        }
```

只需要将对应的 NSPersistentStoreDescription 实例中的 cloudKitContainerOptions 设置为 nil 即可。

需要注意的是，如果你在代码中启用了 Persistent History Tracking，在关闭网络同步的时候仍需保持其开启。

### 测试模式 ###

为了在 Unit Test 测试中不损害原有的 SQLite 数据库文件内容，我通常会创建一个测试模式。该模式下数据仍将被持久化，但会将其保存在用户的 caches 目录中，并在每次测试前对其进行清空处理。

```swift
    /// 是否为测试模式，用于在 Unit Test，在此模式下，本地存储将保存在 Catch 目录中
    private let _testMode: Bool
    private lazy var testMode: Bool = {
        let arguments = ProcessInfo.processInfo.arguments
        var allow = false
        for index in 0..<arguments.count - 1 where arguments[index] == "-TestMode" {
            allow = arguments.count >= (index + 1) ? arguments[index + 1] == "1" : false
            break
        }
        return allow || _testMode
    }()

     if !testMode {
                privateDescrition = NSPersistentStoreDescription(url: groupStoreURL)
     } else {
            // 保存在 catch 目录中
            privateDescrition = NSPersistentStoreDescription(url: privateStoreTestURL)
     }
```

> 根据自己的需要为 Core Data Stack 创建适合的模式，并通过单例的方式进行引用

```swift
public extension CoreDataStack {
    /// 正常 App 使用的 Stack
    static let shared = CoreDataStack(modelName: "Model")

    /// 只保存在内存的预览 Stack
    static let previewInMemory = CoreDataStack(modelName: "Model", inMemory: true)

    /// 保存在本地存储的预览 Stack
    static let previewInPersistentStore = CoreDataStack(modelName: "Model", allowCloudKitSync: false)

    /// Unit Test 模式
    static let testMode = CoreDataStack(modelName: "Model",testMode: true)
}
```

![image-20211101202616881](https://cdn.fatbobman.com/image-20211101202616881.png)

## 总结 ##

Core Data Stack 近年来逐渐走过了由难至简，由小至大的历程创建真实的代码并多做练习将有助于对其更好地了解和掌握。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
