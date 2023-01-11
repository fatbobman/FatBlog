---
date: 2021-08-28 08:20
description: 本文将探讨导致 SwiftUI 预览崩溃的部分原因，如何在之后的开发中避免类似的崩溃出现以及如何在 Xcode 中安全可靠地预览含有 Core Data 元素的 SwiftUI 视图
tags: SwiftUI,Core Data
title: 如何在 Xcode 下预览含有 Core Data 元素的 SwiftUI 视图
image: images/coreDataInPreview.png
---

从 SwiftUI 诞生之日起，预览（Canvas Preview ）一直是个让开发者又爱又恨的功能。当预览正常工作时，它可以极大地提高开发效率；而预览又随时可能因为各种莫名其妙的原因崩溃，不仅影响开发进程，同时又让开发者感到沮丧（很难排查出导致预览崩溃的故障）。

在预览含有 Core Data 元素的视图时崩溃的出现次数会愈发频繁，在某种程度上可能已经影响了开发者在 SwiftUI 中使用 Core Data 的热情。

结合两年来我在 SwiftUI 中使用 Core Data 的经验和教训，我们将在本文中探讨：

* 导致 SwiftUI 预览崩溃的部分原因
* 如何在之后的开发中避免类似的崩溃出现
* 如何在 Xcode 中安全可靠地预览含有 Core Data 元素的 SwiftUI 视图

```responser
id:1
```

## 预览 ##

### 预览是模拟器 ###

预览是模拟器，是一个高度优化且精简的模拟器。

预览在 Xcode 中的**工作原理**同标准的模拟器十分接近。但为了让它可以即时响应 SwiftUI 视图的变化，苹果对其做出了不少的修改。如果说标准的模拟器可以涵盖真实设备的 90%的功能，那么用于预览的模拟器可能只能提供 50%的设备拟真度。

用于预览的模拟器同样使用沙盒机制，具有同标准设备（或模拟器）一致的目录结构。

预览模拟器不支持控制台输出显示、不支持断点调试，即使在动态预览模式下（支持交互的预览模式），我们也不会在 Xcode 中获得任何代码中的控制台输出内容。因此在预览发生问题时，用于排查故障的手段很有限。

在明确了预览是模拟器的概念后，很多在预览中出现的问题，就有了新的解决思路。

### 导致视图无法预览的原因不仅仅是当前视图中的代码 ###

同标准模拟器运行项目一样，在针对某个视图进行预览时，预览模拟器需要项目整体的代码均能够正常编译。其他视图、方法、声明等的代码错误，都可能会导致你无法预览当前的视图。

在排查视图预览崩溃的原因时，一定不能只关注当前视图或临近视图的代码，其他代码中的错误可能才是罪魁祸首。通常此种情况下，会影响很多的视图，甚至全部的视图都不能预览。

### 用于修复标准模拟器故障的经验同样适用于排查预览故障 ###

在使用标准模拟器进行程序调试时，我们会碰到由于模拟器的原因产生的各种奇异状况。通常在这种情况下，我们可能会采用如下的方式来尝试解决：

* 删除模拟器上的应用程序重新安装运行
* 清除编译缓存（Clean Build Folder）
* 删除项目对应的派生数据（Derived Data）
* 重置模拟器
* 在模拟器设备管理器中删除模拟器再重新添加

上述的手段，多数也都适用于修复某些情况下的预览崩溃。预览模拟器没有提供管理入口，我们通常需要使用更加简单粗暴的方式来实现上面的修复作业。

预览模拟器的数据被保存在`/Users/你的用户名/Library/Developer/Xcode/UserData/Previews`目录下，在其中你会看到数量众多由 UUID 命名的若干子目录。在预览仍可正常使用的情况下，通过在视图代码中加入：

```swift
Text("\(FileManager.default.urls(for: .applicationDirectory, in: .userDomainMask).first!)")
```

可以在预览视图中看到对应的 UUID 目录名（必须在动态预览模式下才会显示）。

![image-20210827150544279](https://cdn.fatbobman.com/image-20210827150544279-0047945.png)

通过清空对应的目录，即可完成上面的 1、4、5 项。

如果你的预览已经不好用了，且无法通过例如文件修改时间等手段判断对应目录，删除掉全部的目录也未尝不可。

> 有时需要重启 Xcode 甚至重启系统才会恢复正常

## SwiftUI 下的 Core Data ##

### SwiftUI App life cycle ###

从 Xcode 12 开始，开发者可以在 Xcode 中使用 SwiftUI 原生的应用程序生命周期创建项目。项目的执行入口采用了同视图定义类似的代码形式。

```swift
@main
struct PreviewStudyApp: App {
    var container = PersistenceController.shared.previewInBundle

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, container.viewContext)
        }
    }
}
```

我们需要在`App`中完成诸如`CoreDataStack`实例创建或引用、环境注入等准备工作。作为项目代码的根结构，它的编译、执行的时间都早于其他的代码。

### 环境注入 ###

SwiftUI 提供了多种途径在视图之间传递数据。其中通过环境值（EnvironmentValue）或环境对象（EnvironmentObject）传递数据是其中使用量较大的两种方式。SwiftUI 预设了大量同系统有关的环境值，通过设置或响应这些数据，我们可以修改系统配置或读取系统信息。

SwiftUI 视图采用树状结构组织，在任意节点视图上注入的环境数据都将影响该节点的所有子视图。对于当前视图的环境注入，必须在其祖先视图中完成。

如果视图中声明了对某个环境数据的依赖，而忘记在其祖先视图中注入，并不会导致编译错误。应用程序在运行至该视图时会直接崩溃。

SwiftUI 提供的`managedObjectContext`环境值为在视图中使用或操作 Core Data 元素提供了基础和便利。

### Redux-like ###

SwiftUI + Combine 是苹果推出的声明+响应式结构方案。SwiftUI 应用程序的开发逻辑非常类似于 Redux 设计模式。通过采用单向数据流的方式，将视图描述同数据逻辑进行分离。

在这种模式下，通常我们不会在视图中执行复杂的行为（同视图描述无关），通过向`Store`发送`Action`让`Reducer`完成程序的`State`调整，视图仅仅是对当前状态的一种呈现。

因此，通常不推荐在视图中直接获取或操作`Core Data`数据（非常简单的应用除外）。将需求发送给`Store`，数据经过处理和加工后再提交给`State`，视图往往使用的并非`Core Data`框架产生的原生数据（比如说托管对象）。

`@FetchRequest`是个例外。虽然它完全破坏了单向数据流的逻辑和美感，但由于它过分的好用，因此在 SwiftUI 的开发中仍被广泛的采用。

## 常见的 Core Data 元素视图预览故障 ##

在应用程序可以正常执行的情况下，真正由于 Core Data 因素导致的预览崩溃的原因其实并不多。

### 忘记注入上下文 ###

含有 Core Data 元素的视图预览崩溃的情况相当比例都是由于忘记在环境值中注入持久化存储上下文（`NSManagedObjectContext`）而导致的。

如果你的视图中使用了`@Environment(\.managedObjectContext) var viewContext`或者`@FetchRequest`，请务必检查该视图对应的`PreviewProvider`中，是否为预览视图提供了正确的上下文注入，例如：

```swift
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
           .environment(\.managedObjectContext,
                        PersistenceController.shared.previewInMemory.viewContext)
    }
}
```

### 错误的使用单例 ###

有些开发者比较喜欢在`CoreDataStack`中使用单例，比如上面的代码`PersistenceController.shared.previewInMemory.viewContext`便是通过单例完成了在预览视图中的上下文注入。

由于前文中提到的 SwiftUI App life cycle 的独特性，你无法在根视图中使用单例来注入持久化上下文。比如下面的代码会在运行中报错（编译中不报错）：

```swift
@main
struct PreviewStudyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext,
                             PersistenceController.shared.container.viewContext)
        }
    }
}
```

而且这种错误会导致你全部含有 Core Data 元素的视图崩溃。

> 预览也是模拟器，会执行应用程序的全部代码。当`App`执行出错后，所有的视图都不能正常预览。

正确的方式是，在 App 中先对`CoreDataStack`的单例进行引用，然后再注入：

```swift
@main
struct PreviewStudyApp: App {
    var container = PersistenceController.shared.container

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, container.viewContext)
        }
    }
}
```

> 除了不能在`App`中使用`CoreDataStack`的单例外，在代码的其他部分都是可以正常使用的，包括`Preview`

### 其他常见的 Core Data 故障 ###

当我们对 Core Data 的 DataModel 进行修改时，如果结构修改过大且没有设置 Mapping 的情况下，Core Data 将无法对数据进行自动迁移，从而导致应用程序运行错误。此种情况下，通常我们会在模拟器中删除 App，重新安装运行即可解决问题。由于预览也是模拟器，在它的沙盒中同样可能出现类似的问题。可以使用上文中关于预览模拟器的修复方法来尝试解决。

### 错误使用了 Preview 的修饰符 ###

对于含有 Core Data 元素的视图，在预览中使用`preview`专用修饰符（`Modifier`）须谨慎。某些`Modifier`会导致预览模拟器处于更加受限的运行状态。例如：

```swift
struct Test_Previews: PreviewProvider {
    static var previews: some View {
        Test()
            .environment(\.managedObjectContext,
                         PersistenceController.shared.previewInMemory.viewContext)
            .previewLayout(.sizeThatFits)
    }
}
```

添加了`.previewLayout`后，将无法正常预览含有 Core Data 元素的视图。

### 可以预览但是有错误提示 ###

有时含有 Core Data 元素的视图在预览时会出现如下的错误提示：

![image-20210827191644251](https://cdn.fatbobman.com/image-20210827191644251-0063005.png)

将预览切换到动态模式通常就可以正常显示。

在某些情况下，即使感觉上预览是正常（实际上数据没有刷新），通过切换到动态模式也会强制 Core Data 数据刷新。

## 为 SwiftUI 预览提供 Core Data 数据 ##

本节中，我们将介绍几种为预览组织 Core Data 数据的方式，提高 SwiftUI+Core Data 的开发效率。

> 本节中介绍的方案，不仅适用于预览，同样也适用于 Unit Test。演示代码可以在 [此处下载](https://github.com/fatbobman/CoreDataInPreview)

### 不使用 Core Data 元素 ###

最好的防止出错的手段就是不给错误机会。SwiftUI 通常采用 Redux 的开发模式，通过将获取到的 Core Data 数据转换成标准的 Swift 结构从而避免在视图中使用托管对象上下文或托管对象。

比如我们有一个 Student 的托管对象：

```swift
@objc(Student)
public class Student: NSManagedObject {
    @NSManaged public var name: String?
    @NSManaged public var age: Int32
}
```

通过原生 Swift 结构来进行数据交换

```swift
struct StudentViewModel {
    var name:String
    var age:Int
}

extension Student{
    var viewModel:StudentViewModel{
        .init(name: name ?? "",
              age: Int(age))
    }
}
```

为`StudentRowView`视图创建一个`Connect`（也可以叫`Controller`）视图进行数据转换。直接在`StudentRowView`视图中使用 Swift 结构数据。

```swift
struct StudentRowViewConnect:View{
    let student:Student
    var body: some View{
        StudentRowView(student: student.viewModel)
    }
}

struct StudentRowView:View{
    let student:StudentViewModel
    var body: some View{
        Text("\(student.name)'s age is \(student.age)")
    }
}

struct StudentRowView_Previews_2: PreviewProvider {
    static var previews: some View {
        let student = StudentViewModel(name: "fat", age: 18)
        StudentRowView(student: student)
    }
}
```

这种方式不仅避免了预览崩溃的可能，同时由于转换后的`ViewModel`的属性类型可控（无需类型转换、无需判定可选值等），便于在代码中使用。

> 尽管 SwiftUI 的 Redux 模式有诸多优点，但由于只存在视图这一种表现形式，因此在视图描述中经常会参杂不少的数据计算、整理的工作。通过为此种类型的视图添加一个专门用来处理数据的父视图，可以有效的将两种逻辑分割开来。本例仅为演示，通常 Connect 视图的数据准备工作会复杂的多。

### 直接使用托管对象 ###

当然，我们仍然可以直接给视图传递托管对象。为了便于在预览中重复使用，我们可以在`CoreDataStack`或其他你认为合适的地方提前创建好用于预览的数据，在预览时直接调用即可。

```swift
struct RowView: View {
    let item: Item
    var body: some View {
        VStack {
            Text("Item at \(item.timestamp!, formatter: itemFormatter)")
        }
    }
}

struct RowView_Previews: PreviewProvider {
    static var previews: some View {
        RowView(item: PersistenceController.shared.samepleItem)
    }
}
// 预置演示数据
extension PersistenceController {
    var samepleItem: Item {
        let context = Self.shared.previewInMemory.viewContext
        let item = Item(context: context)
        item.timestamp = Date().addingTimeInterval(30000000)
        return item
    }
}
```

### 内存数据库 ###

从 Xcode 12 开始，苹果在预置的`CoreDataStack`模版`Persistence.swift`中已经添加了`inMemory`选项，为预览创建了专用的`Container`。这种创建内存数据库的形式在 Unit Test 中已经被使用很久了。

CoreData 支持四种持久化存储类型：Sqlite、XML、二进制、内存。**不过我们在`CoreDataStack`中创建的基于内存的持久化存储仍然是`Sqlite`类型**。是将数据文件保存在`/dev/null`的`Sqlite`类型。此种内存数据库除了不能持久化外同标准 Sqlite 数据库功能完全一样。内存中的 Sqlite 数据库执行效率稍高于正常的 Sqlite 数据库，并没有巨大的差别。

Xcode 的 Core Data 模版将`inMemory`同标准 Sqlite 的`Container`定义混在一起的，我个人还是喜欢将其独立出来。

```swift
    lazy var previewInMemory: NSPersistentContainer = {
        let container = NSPersistentContainer(name: modelName)
        container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        container.loadPersistentStores(completionHandler: { _, error in

            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        let viewContext = container.viewContext
      // 创建演示数据
        for _ in 0..<10 {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
        }
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return container
    }()

    lazy var container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: modelName)
        container.loadPersistentStores(completionHandler: { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
```

在完成了持久化容器的创建后，代码在数据库中创建了用于预览的演示数据。批量创建的数据有利于用于使用了`@FetchRequest`的视图在预览中调用。

```swift
struct ContentView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default
    )
    private var items: FetchedResults<Item>

    var body: some View {
        ...      
    }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext,
                         PersistenceController.shared.previewInMemory.viewContext)
    }
}
```

> 使用此种方式的数据模型通常不复杂，否则创建演示数据就需要非常多的代码量。

### 预置复杂数据的 Bundle 数据库 ###

对于拥有复杂数据模型的应用该如何创建用于预览的演示数据呢？

我目前在开发使用 SwiftUI+CoreData 的应用程序时，将 CoreData 部分的开发同应用程序的 UI 构建是完全分离的。在完成了各种处理 CoreData 数据的方法后，通常会创建一些非常简陋的视图或 Unit Test 来验证代码以及创建测试数据集。这样在进行 UI 开发的时候，我已经可以有一个可用来演示的数据库文件了。

使用打印、查看调试输出、`po NSHomeDirectory()`等手段，可以获取到模拟器中的数据库文件`URL`。将三个数据库文件（包括`wal`和`shm`）一并拖入项目中，创建一个使用`Bundle`中数据库文件的`NSPersistentContainer`，方便我们预览使用了复杂数据模型的视图。

![image-20210827202250305](https://cdn.fatbobman.com/image-20210827202250305-0066971.png)

```swift
    lazy var previewInBundle: NSPersistentContainer = {
        let container = NSPersistentContainer(name: modelName,managedObjectModel: Self.model())
        guard let url = Bundle.main.url(forResource: "PreviewStudy", withExtension: "sqlite") else {
            fatalError("无法从 Bundle 中获取数据库文件")
        }
        container.persistentStoreDescriptions.first?.url = url
        container.loadPersistentStores(completionHandler: { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
```

在预览中使用`previewInBundle`

```swift
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext,
                         PersistenceController.shared.previewInBundle.viewContext)
    }
}
```

尽管 Bundle 是只读的，但我们仍然可以在标准模拟器或动态预览模式下添加修改数据。在重启应用或重启预览后，数据会恢复成 Bundle 中的原始数据集（有时在预览模式下数据不会立即复原，需在几次动态模式切换后才会恢复）。

### Bundle 数据库加强版 ###

上面的 Bundle 数据库方便了开发者预览拥有复杂数据模型的视图。不过由于 Bundle 是只读的，你在动态预览中修改创建的数据并不会被真正的持久化。如果确有持久化的需要，可以使用下面的方案。将 Bundle 中的数据库文件保存到`Catch`目录中。

```swift
lazy var previewInCatch: NSPersistentContainer = {
        let container = NSPersistentContainer(name: modelName,managedObjectModel: Self.model())
        let fm = FileManager.default
        let DBName = "PreviewStudy"

        guard let sqliteURL = Bundle.main.url(forResource: DBName, withExtension: "sqlite"),
              let shmURL = Bundle.main.url(forResource: DBName, withExtension: "sqlite-shm"),
              let walURL = Bundle.main.url(forResource: DBName, withExtension: "sqlite-wal")
        else {
            fatalError("无法从 Bundle 中获取数据库文件")
        }
        let originalURLs = [sqliteURL, shmURL, walURL]

        let storeURL = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!

        let sqliteTargetURL = storeURL.appendingPathComponent(sqliteURL.lastPathComponent)
        let shmTargetURL = storeURL.appendingPathComponent(shmURL.lastPathComponent)
        let walTargetURL = storeURL.appendingPathComponent(walURL.lastPathComponent)

        let tragetURLs = [sqliteTargetURL, shmTargetURL, walTargetURL]

        zip(originalURLs, tragetURLs).forEach { originalURL, targetURL in
            do {
                if fm.fileExists(atPath: targetURL.path) {
                    if Self.alwaysCopy {
                        try fm.removeItem(at: targetURL)
                        try fm.copyItem(at: originalURL, to: targetURL)
                    }
                } else {
                    try fm.copyItem(at: originalURL, to: targetURL)
                }
            } catch let error as NSError {
                fatalError(error.localizedDescription)
            }
        }

        container.persistentStoreDescriptions.first?.url = sqliteTargetURL
        container.loadPersistentStores(completionHandler: { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
```

本文的演示代码可以在 [此处下载](https://github.com/fatbobman/CoreDataInPreview)

## 总结 ##

在我两年的 SwiftUI+Core Data 使用中，痛苦和快乐始终相伴而行。只要始终保持用心、耐心、平常心，再加上一点点运气，总会找到解决问题的方法。

希望本文对你在 SwiftUI 中使用 Core Data 有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
