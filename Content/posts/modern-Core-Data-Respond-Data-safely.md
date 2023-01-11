---
date: 2022-12-13 08:20
description: 保证应用不因 Core Data 的原因导致意外崩溃是对开发者的起码要求。本文将介绍可能在视图中产生严重错误的原因，如何避免，以及在保证视图对数据变化实时响应的前提下如何为使用者提供更好、更准确的信息。由于本文会涉及大量前文中介绍的技巧和方法，因此最好一并阅读。
tags: Core Data,SwiftUI
title: SwiftUI 与 Core Data —— 安全地响应数据
image: images/modern-Core-Data-Respond-Data-safely.png
---
保证应用不因 Core Data 的原因导致意外崩溃是对开发者的起码要求。本文将介绍可能在视图中产生严重错误的原因，如何避免，以及在保证视图对数据变化实时响应的前提下如何为使用者提供更好、更准确的信息。由于本文会涉及大量前文中介绍的技巧和方法，因此最好一并阅读。

* [SwiftUI 与 Core Data —— 问题](https://www.fatbobman.com/posts/modern-Core-Data-Problem/)
* [SwiftUI 与 Core Data —— 数据定义](https://www.fatbobman.com/posts/modern-Core-Data-Data-definition/)
* [SwiftUI 与 Core Data —— 数据获取](https://www.fatbobman.com/posts/modern-Core-Data-fetcher/)

> 可以在 [此处](https://github.com/fatbobman/Todo) 获取演示项目 Todo 的代码

```responser
id:1
```

## 托管对象与可选值

Core Data 实体属性的可选性理念早于 Swift 的存在，允许属性暂时无效。例如，当你创建一个带有字符串属性的新对象时，初始值（ 在没有默认值的情况下 ）是 nil，这在对象被验证之前（ 通常在 save 时 ）是没有问题的。

当开发者在模型编辑器中为属性设置了默认值（ 取消可选 ），在 Xcode 自动生成的托管对象类定义代码中仍会将不少类型声明为可选值类型。通过手动修改类型（ 将 String? 修改为 String ）当声明代码可以部分改善在视图中使用托管对象的友善度。

相较于将具有默认值的属性声明为可选值类型（ 例如 String ），数值属性的声明则更加令人困惑。例如下面的 count 属性（ Integer 16 ）在模型编辑器中被设定为可选，但在生成的代码中仍将为非可选值类型（ Int16 ）。

![image-20221212090247999](https://cdn.fatbobman.com/image-20221212090247999.png)

![image-20221212090306573](https://cdn.fatbobman.com/image-20221212090306573.png)

而且，开发者无法通过更改声明代码将该属性类型修改为 Int16? 。

![image-20221212090739291](https://cdn.fatbobman.com/image-20221212090739291.png)

这意味着，开发者在实体的某些属性类型上将失去 Swift 中一个极有特色且功能强大的可选值能力。

之所以出现上述的情况，是因为 Xcode 中模型编辑器中的 optional 并非对应 Swift 语言中的可选值。Core Data 受限于 Objective-C 中可表达的类型限制，在即使使用了标量转换的情况下（ Scalar ）也不具备与 Swift 原生类型对应的能力。

如果取消标量类型，我们可以让模型编辑器生成支持可选值的特定类型（ 例如 NSNumber? ）：

![image-20221212092612578](https://cdn.fatbobman.com/image-20221212092612578.png)

![image-20221212092628708](https://cdn.fatbobman.com/image-20221212092628708.png)

开发者可以通过为托管对象声明计算属性实现在 NSNumber? 与 Int16? 之间的转换。

可能开发者会有这样的疑问，假如某个实体的属性在模型中被定义为可选，且在托管对象的类型声明中也为可选值类型（ 例如上方的 timestamp 属性 ），那么如果在可以保证 save 时一定有值的情况下，是否可以在使用中使用 `!` 号对其进行强制解包？

事实上，在 Xcode 自带的 Core Data 模版中，就是这样使用的。

![image-20221212101526366](https://cdn.fatbobman.com/image-20221212101526366.png)

但这确实是正确的使用方式吗？是否会有严重的安全隐患？在 timestamp 对应的数据库字段有值的情况下，timestamp 一定会有值吗？是否会有 nil 的可能？

## 删除与响应式编程

托管对象的实例创建于托管上下文中，且仅能安全运行于其绑定的托管上下文所在的线程之中。每个托管对象都对应着持久化存储中的一条数据（ 不考虑关系的情况下 ）。

为了节省内存，托管对象上下分通常会积极释放（ retainsRegisteredObjects 默认为 false ）失去引用的托管对象实例所占用的空间。也就是说，如果一个用于显示托管对象实例数据的视图被销毁了，那么假如没有其他的视图或代码引用视图中显示的托管对象实例，托管上下文将从内存中将这些数据占用的内存释放掉。

> 在 retainsRegisteredObjects 为 true 的情况下，托管对象会在内部保留对该对象的强引用，即使没有外部代码引用该托管对象实例，对象实例也不会被销毁。

从另一个角度来看，即使在托管上下文中使用 `delete` 方法删除该实例在数据库中对应的数据，但如果该托管对象实例仍被代码或视图所引用，Swift 并不会销毁该实例，此时，托管对象上下文会将该实例的 managedObjectContext 属性设置为 nil ，取消其与托管上下文之间的绑定。此时如果再访问该实例的可选值类型属性（ 例如之前一定有值的 timestamp ），返回值则为 nil 。强制解包将导致应用崩溃。

如今的 Core Data，随着云同步以及持久化存储历史跟踪的普及，数据库中的某个数据可能在任意时刻被其他的设备或同一个设备中使用该数据库的其他进程所删除。开发者不能像之前那样假设自己对数据具备完全的掌控能力。在代码或视图中，如果不为随时可能已被删除的数据做好安全准备，问题将十分地严重。

回到 Xcode 创建的 Core Data 模版代码，我们做如下的尝试，在进入 NavigationLink 后一秒钟删除该数据：

```swift
ForEach(items) { item in
    NavigationLink {
        Text("Item at \(item.timestamp!, formatter: itemFormatter)")
            .onAppear{
                // 在进入 NavigationLink 后一秒钟删除该数据
                DispatchQueue.main.asyncAfter(deadline: .now() + 1){ 
                    viewContext.delete(item)
                    try! viewContext.save()
                }
            }
    } label: {
        Text(item.timestamp!, formatter: itemFormatter)
    }
}
```

![coreData-optional-demo1_2022-12-12_11.16.51.2022-12-12 11_18_34](https://cdn.fatbobman.com/coreData-optional-demo1_2022-12-12_11.16.51.2022-12-12%2011_18_34.gif)

完全没有问题！并没有出现崩溃的情况。难道我们上面的论述都是错误的？

由于在 Core Data 模版代码中，只使用了一行代码来声明次级视图：

```swift
Text("Item at \(item.timestamp!, formatter: itemFormatter)")
```

因此在 ContentView 的 ForEach 中，item 并不会被视为一个可以引发视图更新的 Source of truth （ 通过 Fetch Request 获取的 items 为 Source of truth ）。在删除数据后，即使 item 的内容发生了变化，也并不会引发该行声明语句（ Text ）刷新，从而不会出现强制解包失败的情况。随着 FetchRequest 的内容发生变化，List 将重新刷新，由于 NavigationLink 对应的数据不复存在，因此 NavigationView 自动返回了根视图。

不过，通常我们在子视图中，会用 ObservedObject 来标注托管对象实例，以实时响应数据变动，因此如果我们将代码调整成正常的编写模式就能看出问题所在了：

```swift
struct Cell:View {
    @ObservedObject var item:Item // 响应数据变化
    @Environment(\.managedObjectContext) var viewContext
    var body: some View {
        Text("Item at \(item.timestamp!, formatter: itemFormatter)")
            .onAppear{
                DispatchQueue.main.asyncAfter(deadline: .now() + 1){
                    viewContext.delete(item)
                    try! viewContext.save()
                }
            }
    }
}

List {
    ForEach(items) { item in
        NavigationLink {
            Cell(item: item) // 传递托管对象
        } label: {
            Text(item.timestamp!, formatter: itemFormatter)
        }
    }
    .onDelete(perform: deleteItems)
}
```

![coreData-optional-demo2_2022-12-12_11.29.10.2022-12-12 11_31_10](https://cdn.fatbobman.com/coreData-optional-demo2_2022-12-12_11.29.10.2022-12-12%2011_31_10.gif)

在删除了数据后，托管上下文会将 item 的 manageObjectContext 设置为 nil。此时受 item 的 ObjectWillChangePublisher 驱动，Cell 视图将刷新，强制解包将导致应用崩溃。

只需采用提供备选值的方式，即可避免上述问题的出现。

```swift
Text("Item at \(item.timestamp ?? .now, formatter: itemFormatter)")
```

如果使用我们在 [SwiftUI 与 Core Data —— 数据定义](https://www.fatbobman.com/posts/modern-Core-Data-Data-definition/) 一文中讨论的 ConvertibleValueObservableObject 协议呢？在 convertToValueType 中为属性提供备选值，是否可以避免出现崩溃的情况？答案是，原始的版本仍可能会出现问题。

数据被删除后，托管对象实例的 manageObjectContext 被设置为 nil 。由于 AnyConvertibleValueObservableObject 符合 ObservableObject 协议，一样会引发 Cell 视图的更新，在新的一轮渲染中，如果我们限定 convertToGroup 将转换过程运行于托管对象上下文所在的线程中，由于无法获取上下文信息，转换将失败。假设我们不限定转换过程运行的线程，备选值的方式对于由视图上下文创建的托管对象实例仍将有效（ 但有可能会出现其它的线程错误 ）。

为了让 ConvertibleValueObservableObject 协议能够满足各种场景，我们需要做如下的调整：

```swift
public protocol ConvertibleValueObservableObject<Value>: ObservableObject, Equatable, Identifiable where ID == WrappedID {
    associatedtype Value: BaseValueProtocol
    func convertToValueType() -> Value? // 将返回类型修改为 Value？
}

public extension TestableConvertibleValueObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    ... 
    
    func convertToValueType() -> WrappedValue? { // 修改成返回 Value？
        _wrappedValue
    }
}

public class AnyConvertibleValueObservableObject<Value>: ObservableObject, Identifiable where Value: BaseValueProtocol {
    
    public var wrappedValue: Value? { // 修改成返回 Value？
        _object.convertToValueType()
    }
}
```

如此一来，便可以通过在视图代码使用 `if let` 来保证不会出现上文提到的崩溃问题：

```swift
public struct Cell: View {
    @ObservedObject var item: AnyConvertibleValueObservableObject<Item>
   
    public var body: some View {
        if let item = item.wrappedValue {
           Text("Item at \(item.timestamp, formatter: itemFormatter)")
        }
    }
}
```

为了做到可以支持在任意托管上下文线程中进行转换，convertToValueType 中的实现将为（ 以 Todo 中的 TodoGroup 为例 ）：

```swift
extension C_Group: ConvertibleValueObservableObject {
    public var id: WrappedID {
        .objectID(objectID)
    }

    public func convertToValueType() -> TodoGroup? {
        guard let context = managedObjectContext else { // 判断是否能获取上下文
            return nil
        }
        return context.performAndWait { // 在上下文的线程中执行，保证线程安全
            TodoGroup(
                id: id,
                title: title ?? "",
                taskCount: tasks?.count ?? 0
            )
        }
    }
}
```

由于同步版本的 performAndWait 并不支持返回值，我们需要对其作一定的增强：

```swift
extension NSManagedObjectContext {
    @discardableResult
    func performAndWait<T>(_ block: () throws -> T) throws -> T {
        var result: Result<T, Error>?
        performAndWait {
            result = Result { try block() }
        }
        return try result!.get()
    }

    @discardableResult
    func performAndWait<T>(_ block: () -> T) -> T {
        var result: T?
        performAndWait {
            result = block()
        }
        return result!
    }
}
```

在响应式编程中，开发者不应假设每个部件均能处于理想环境中，需要尽力确保它们能够任何情况下均保证安全稳定，如此才能保证整个系统的稳定运转。

```responser
id:1
```

## 为已删除的托管对象实例提供正确的备选内容

一定会有人对本节的题目感到奇怪，数据已经删除了，还需要提供什么信息？

在上节的演示中，当数据被删除后（ 通过 onAppear 闭包中的延迟操作 ），NavigationView 会自动返回到根视图中。在这种情况下，持有该数据的视图将伴随着数据删除一并消失。

但在非常多的情况下，开发者并不会使用演示中使用的 NavigationLink 版本，为了对视图拥有更强地控制力，开发者通常会选择具备可编程特性的 NavigationLink 版本。此时，当数据被删除后，应用并不会自动退回至根视图。另外，在其他的一些操作中，为了保证模态视图的稳定，我们通常也会将模态视图挂载到 List 的外面。例如：

```swift
@State var item: Item?

List {
    ForEach(items) { item in
        VStack {
            Text("\(item.timestamp ?? .now)")
            Button("Show Detail") {
                self.item = item // 显示模态视图
                // 模拟延迟删除
                DispatchQueue.main.asyncAfter(deadline: .now() + 2){
                    viewContext.delete(item)
                    try! viewContext.save()
                }
            }
            .buttonStyle(.bordered)
        }
    }
    .onDelete(perform: deleteItems)
}
// 模态视图
.sheet(item: $item) { item in
    Cell(item: item)
}

struct Cell: View {
    @ObservedObject var item: Item
    var body: some View {
        // 方便看清楚变化。 当 timestamp 为 nil 时，将显示当前时间
        Text("\((item.timestamp ?? .now).timeIntervalSince1970)")
    }
}
```

运行上面的代码，在数据被删除后，Sheet 视图中的 item 会因 managedObjectContext 为 nil 而使用备选数据，如此一来会让用户感到疑惑。

![coreData-optional-demo3_2022-12-12_14.20.17.2022-12-12 14_21_06](https://cdn.fatbobman.com/coreData-optional-demo3_2022-12-12_14.20.17.2022-12-12%2014_21_06.gif)

我们可以通过保留有效值的方式避免出现上述的问题。

```swift
struct Cell: View {
    let item: Item // 无需使用 ObservedObject
    /*
    如果使用的是 MockableFetchRequest ，则为
    let item: AnyConvertibleValueObservableObject<ItemValue>
    */
    @State var itemValue:ItemValue?
    init(item: Item) {
        self.item = item
        // 初始化时，获取有效值
        self._itemValue = State(wrappedValue: item.convertToValueType())
    }
    var body: some View {
        VStack {
            if let itemValue {
                Text("\((itemValue.timestamp).timeIntervalSince1970)")
            }
        }
        .onReceive(item.objectWillChange){ _ in 
            // item 发生变化后，如果能转换成有效值，则更新视图
            if let itemValue = item.convertToValueType() {
                self.itemValue = itemValue
            }
        }
    }
}

public struct ItemValue:BaseValueProtocol {
    public var id: WrappedID
    public var timestamp:Date
}

extension Item:ConvertibleValueObservableObject {
    public var id: WrappedID {
        .objectID(objectID)
    }

    public func convertToValueType() -> ItemValue? {
        guard let context = managedObjectContext else { return nil}
        return context.performAndWait{
            ItemValue(id: id, timestamp: timestamp ?? .now)
        }
    }
}
```

![coreData-optional-demo4_2022-12-12_14.20.17.2022-12-12 14_21_06](https://cdn.fatbobman.com/coreData-optional-demo4_2022-12-12_14.20.17.2022-12-12%2014_21_06.gif)

## 在视图之外传递值类型

在上节的代码中，我们为子视图传递都是托管对象实例本身（ AnyConvertibleValueObservableObject 也是对托管对象实例的二度包装 ）。但在类 Redux 框架中，为了线程安全（ Reducer 未必运行于主线程，详细请参阅之前的文章 ）我们不会将托管对象实例直接发送给 Reducer，而是传递转换后的值类型。

> 下面的代码来自 Todo 项目中 TCA Target 的 TaskListContainer.swift

![image-20221212162439240](https://cdn.fatbobman.com/image-20221212162439240.png)

尽管值类型帮助我们规避了可能存在的线程风险，但又出现了视图无法对托管对象实例的变化进行实时响应的新问题。通过在视图中获取值类型数据对应的托管对象实例，便可以既保证安全，又保持了响应的实时性。

为了演示方便，仍以普通的 SwiftUI 数据流举例：

```swift
@State var item: ItemValue? // 值类型

List {
    ForEach(items) { item in
        VStack {
            Text("\(item.timestamp ?? .now)")
            Button("Show Detail") {
                self.itemValue = item.convertToValueType() // 传递值类型
                // 模拟延迟修改内容
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    item.timestamp = .now
                    try! viewContext.save()
                }
            }
            .buttonStyle(.bordered)
        }
    }
    .onDelete(perform: deleteItems)
}
.sheet(item: $itemValue) { item in
    Cell(itemValue: item) // 参数为值类型
}

struct Cell: View {
    @State var itemValue: ItemValue // 值类型
    @Environment(\.managedObjectContext) var context

    var body: some View {
        VStack {
            if let itemValue {
                Text("\((itemValue.timestamp).timeIntervalSince1970)")
            }
        }
        // 在视图中获取对应的托管对象实例，并实时响应变化
        .task { @MainActor in
            guard case .objectID(let id) = itemValue.id else {return}
            if let item = try? context.existingObject(with: id) as? Item {
                for await _ in item.objectWillChange.values {
                    if let itemValue = item.convertToValueType() {
                        self.itemValue = itemValue
                    }
                }
            }
        }
    }
}
```

以我个人的经验来说，为了确保线程安全，托管对象只应在视图之间进行传递，同时用于视图显示的数据最好也只在视图之内进行获取。任何可能脱离视图的传递过程都应使用托管对象实例对应的值类型版本。

## 在更改数据时进行二次确认

为了避免对主线程造成过多的影响，我们通常会在私有上下文中进行会对数据产生变化的操作。将操作方法的参数设置为值类型，将迫使开发者在对数据进行操作时（ 添加、删除、更改等 ）首先需要确认对应数据（ 数据库中 ）是否存在。

例如（ 代码来自 Todo 项目中 DB 库中的 CoreDataStack.swift ）：

```swift
@Sendable
func _updateTask(_ sourceTask: TodoTask) async {
    await container.performBackgroundTask { [weak self] context in
        // 首先确认 task 是否存在
        guard case .objectID(let taskID) = sourceTask.id,
              let task = try? context.existingObject(with: taskID) as? C_Task else {
            self?.logger.error("can't get task by \(sourceTask.id)")
            return
        }
        task.priority = Int16(sourceTask.priority.rawValue)
        task.title = sourceTask.title
        task.completed = sourceTask.completed
        task.myDay = sourceTask.myDay
        self?.save(context)
    }
}
```

通过 existingObject ，我们将确保只在数据有效的情况下才进行下一步的操作，如此可以避免操作已被删除的数据而造成的意外崩溃情况。

## 下文介绍

在下篇文章中，我们将探讨有关模块化开发的问题。如何将具体的托管对象类型以及 Core Data 操作从视图、Features 中解耦出来。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ) 或博客的留言板与我进行交流。

**订阅下方的 [邮件列表](https://artisanal-knitter-2544.ck.page/d3591dd1e7)，可以及时获得每周的 Tips 汇总。**
