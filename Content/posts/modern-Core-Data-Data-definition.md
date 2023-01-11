---
date: 2022-11-29 08:20
description: 在上文中，我列举了一些在 SwiftUI 中使用 Core Data 所遇到的困惑及期许。在今后的文章中我们将尝试用新的思路来创建一个 SwiftUI + Core Data 的 app，看看能否避免并改善之前的一些问题。本文将首先探讨如何定义数据。
tags: Core Data,SwiftUI
title: SwiftUI 与 Core Data —— 数据定义
image: images/modern-Core-Data-Data-definition.png
---
在上文中，我列举了一些在 SwiftUI 中使用 Core Data 所遇到的困惑及期许。在今后的文章中我们将尝试用新的思路来创建一个 SwiftUI + Core Data 的 app，看看能否避免并改善之前的一些问题。本文将首先探讨如何定义数据。

## 从 Todo 开始

Todo 是我为这个系列文章准备的一个演示应用。我尽量让这个功能简单的 app 能够触及较多的 SwiftUI + Core Data 的开发场景。使用者可以在 Todo 中创建将要完成的工作（ Task ），并可以通过 Task Group 以实现更好地管理。

> 可以在 [此处](https://github.com/fatbobman/Todo) 获得 Todo 的代码。代码仍在更新中，可能会出现与文章中不完全一致的情况。

![Todo_demo_iPhone_14_Pro_2022-11-28_10.29.20.2022-11-28 10_35_07](https://cdn.fatbobman.com/Todo_demo_iPhone_14_Pro_2022-11-28_10.29.20.2022-11-28%2010_35_07.gif)

Todo 的代码有如下特点：

* 采用模块化开发方式，数据定义、视图、DB 实现均处于各自的模块中
* 除了用于串联的视图外，所有的细节视图均实现了与应用的数据流解耦。无需更改代码便可以适应不同的框架（ 纯 SwiftUI 驱动、TCA 或其他的 Redux 框架 ）
* 所有的视图均可以实现在不使用任何 Core Data 代码的情况下进行预览，并可对 Mock 数据进行动态响应

![image-20221128114700448](https://cdn.fatbobman.com/image-20221128114700448.png)

```responser
id:1
```

## 先有鸡还是先有蛋

Core Data 通过托管对象的方式来呈现数据（ 定义的工作是在数据模型编辑器中进行的 ）。如此一来，开发者可以用自己熟悉的方式来操作数据而无需了解持久化数据的具体结构和组织方式。遗憾的是，托管对象对于以值类型为主的 SwiftUI 来说并不算友好，因此，不少开发者都会在视图中将托管对象实例转换成一个结构体实例以方便接下来的操作（ [如何在 Xcode 下预览含有 Core Data 元素的 SwiftUI 视图](https://www.fatbobman.com/posts/coreDataInPreview/#为_SwiftUI_预览提供_Core_Data_数据)）。

因此，在传统的 Core Data 应用开发方式中，开发者为了创建上图中 Group Cell 视图，通常需要进行如下的步骤（ 以 Todo 应用中的 Task Group 举例 ）：

![image-20221128130041823](https://cdn.fatbobman.com/image-20221128130041823.png)

* 在 Xcode 的数据模型编辑器中创建实体 `C_Group`（ 包括与之有关系的其他实体 `C_Task` ）

![image-20221128124420013](https://cdn.fatbobman.com/image-20221128124420013.png)

* 如有必要可以通过更改托管对象 `C_Group` 代码（ 或添加计算属性 ）的方式改善托管对象的类型兼容度
* 定义方便在 SwiftUI 环境中使用的结构，并为托管对象创建扩展方法以实现转换

```swift
struct TodoGroup {
    var title: String
    var taskCount: Int // 当前 Group 中包含的 Task 数量
}

extension C_Group {
    func convertToGroup() -> TodoGroup {
        .init(title: title ?? "", taskCount: tasks?.count ?? 0)
    }
}
```

* 创建 GroupCell 视图

```swift
struct GroupCellView:View {
    @ObservedObject var group:C_Group
    var body: some View {
        let group = group.convertToGroup()
        HStack {
            Text(group.title)
            Text("\(group.taskCount)")
        }
    }
}
```

根据上述流程，即使我们不进行最初的建模工作，仅依靠结构体 TodoGroup 已经完全可以满足进行视图开发的需要。如此一来，流程顺序将改变为：

* 定义 TodoGroup 结构体
* 构建视图

此时视图可以简化为：

```swift
struct GroupCellView:View {
    let group: TodoGroup
    var body: some View {
        HStack {
            Text(group.title)
            Text("\(group.taskCount)")
        }
    }
}
```

在开发的过程中，我们可以根据需要随时调整 TodoGroup ，而无需过分考虑如何在 Core Data 以及数据库中组织数据（ 仍需要开发者有一定的 Core Data 编程基础，避免创建完全不切实际的数据格式 ）。在最后阶段（ 视图及其他逻辑处理都完成后 ）才进行 Core Data 数据的建模以及转换工作。

这一看似简单的转换 —— 从鸡（ 托管对象 ）到蛋（ 结构体 ）转换至从鸡（ 结构体 ）到蛋（ 托管对象 ），将完全颠覆我们之前习惯的开发流程。

## 托管对象的其他优势

在视图中用结构体直接表示数据固然方便，但我们仍不能忽略托管对象的其他优势。对于 SwiftUI 来说，托管对象具备两个非常显著的特点：

* 懒加载

  托管对象的所谓托管是指：该对象被托管上下文所创建并持有。仅在需要的时候，才从数据库（ 或行缓存 ）中加载所需的数据。配合 SwiftUI 的懒加载容器（ List、LazyStack、LazyGrid ），可以完美地在性能与资源占用间取得平衡

* 实时响应变化

  托管对象（ NSManagedObject ）符合 ObservableObject 协议，当数据发生变化时，可以通知视图进行刷新

因此无论如何，我们都应该在视图中保留托管对象的上述优点，如此，上面的代码将会演变成下面的模样：

```swift
struct GroupCellViewRoot:View {
    @ObservedObject var group:C_Group
    var body:some View {
        let group = group.convertToGroup()
        GroupCellView(group:group)
    }
}
```

很遗憾，好像一切又回到了原点。

为了保留 Core Data 的优势，我们不得不在视图中引入托管对象，引入了托管对象就不得不先建模，再转换。

是否可以创建一种既可保留托管对象优势同时又不用在代码中显式引入特定托管对象的方式呢？

## 面向协议编程

面向协议编程是贯穿 Swift 语言的基本思想，也是其主要特点之一。通过让不同的类型遵守相同的协议，开发者便可以从具体的类型中解放出来。

### BaseValueProtocol

回到 TodoGroup 这个类型。这个类型除了用于为 SwiftUI 的视图提供数据外，同时也会被用于为其他的数据流提供有效信息，例如，在类 Redux 框架中，通过 Action 为 Reducer 提供所需数据。因此，我们可以为所有的类似数据创建一个统一的协议 —— BaseValueProtocol。

```swift
public protocol BaseValueProtocol: Equatable, Identifiable, Sendable {}
```

越来越多的类 Redux 框架要求 Action 符合 Equatable 协议，因此作为可能作为某个 Action 的关联参数的类型，也必须遵循该协议。同时考虑到未来 Reducer 有被移出主线程的趋势，让数据符合 Sendable 也能避免出现多线程方面的问题。由于每个结构体实例势必需要对应一个托管对象实例，让结构体类型符合 Identifiable 也能更好地为两者之间创建联系。

现在我们首先让 TodoGroup 来遵守这个协议：

```swift
struct TodoGroup: BaseValueProtocol {
    var id: NSManagedObjectID // 一个可以联系两种之间的纽带，目前暂时用 NSManagedObjectID 代替
    var title: String
    var taskCount: Int
}
```

在上面的实现中，我们用 NSManagedObjectID 作为 TodoGroup 的 id 类型，但由于 NSManagedObjectID 同样需要在托管环境中才能创建，因此在下文中，它将会被其他的自定义类型所取代。

### ConvertibleValueObservableObject

无论是首先定义数据模型还是首先定义结构体，最终我们都需要为托管对象提供转换至对应结构体的方法，因此我们可以认为所有能够转换成指定结构体（ 符合 BaseValueProtocol ）的托管对象应该都可以遵循下面的协议：

```swift
public protocol ConvertibleValueObservableObject<Value>: ObservableObject, Identifiable {
    associatedtype Value: BaseValueProtocol
    func convertToValueType() -> Value
}
```

例如：

```swift
extension C_Group: ConvertibleValueObservableObject {
    public func convertToValueType() -> TodoGroup {
        .init(
            id: objectID, // 相互间对应的标识
            title: title ?? "",
            taskCount: tasks?.count ?? 0
        )
    }
}
```

### 两者间的纽带 —— WrappedID

由于 NSManagedObjectID 的存在，上面的两个协议仍无法脱离托管环境（ 并非指 Core Data 框架 ）。因此我们需要创建一种可以在托管环境和非托管环境中均能运行的中间类型用作两者的标识。

```swift
public enum WrappedID: Equatable, Identifiable, Sendable, Hashable {
    case string(String)
    case integer(Int)
    case uuid(UUID)
    case objectID(NSManagedObjectID)

    public var id: Self {
        self
    }
}
```

同样出于该类型可能被用于 Action 的关联参数以及作为 ForEach 中视图的显式标识，我们需要让该类型符合 Equatable、Identifiable、Sendable,、Hashable 这些协议。

由于 WrappedID 需要符合 Sendable ，因此上面的代码在编译时将出现如下警告（ NSManagedObjectID 不符合 Sendable ）：

![image-20221128142739129](https://cdn.fatbobman.com/image-20221128142739129.png)

庆幸的是，NSManagedObjectID 是线程安全的，可以被标注为 Sendable（ [这点已经在 Ask Apple 10 月的问答中得到了官方的确认](https://www.fatbobman.com/posts/Core-Data-of-Ask-Apple-2022/#是否可以使用_@unchecked_Sendable_标注_NSManagedObjectID) ）。添加如下代码即可消除上面的警告：

```swift
extension NSManagedObjectID: @unchecked Sendable {}
```

让我们对之前的 BaseValueProtocol 和 ConvertibleValueObservableObject 进行调整：

```swift
public protocol BaseValueProtocol: Equatable, Identifiable, Sendable {
    var id: WrappedID { get }
}

public protocol ConvertibleValueObservableObject<Value>: ObservableObject, Identifiable where ID == WrappedID {
    associatedtype Value: BaseValueProtocol
    func convertToValueType() -> Value
}
```

截至目前我们创建了两个协议和一个新类型 —— BaseValueProtocol、ConvertibleValueObservableObject、WrappedID ，不过好像看不出它们有什么具体的作用。

```responser
id:1
```

### 为 Mock 数据准备的协议 —— TestableConvertibleValueObservableObject

还记得我们最初的宗旨吗？在不创建 Core Data 模型的情况下，完成绝大多数的视图和逻辑代码。因此，我们必须能够让 GroupCellViewRoot 视图接受一种仅从结构体（ TodoGroup ）即可创建的与托管对象行为类似的通用类型。TestableConvertibleValueObservableObject 便是完成这一目标的基石：

```swift
@dynamicMemberLookup
public protocol TestableConvertibleValueObservableObject<WrappedValue>: ConvertibleValueObservableObject {
    associatedtype WrappedValue where WrappedValue: BaseValueProtocol
    var _wrappedValue: WrappedValue { get set }
    init(_ wrappedValue: WrappedValue)
    subscript<Value>(dynamicMember keyPath: WritableKeyPath<WrappedValue, Value>) -> Value { get set }
}

public extension TestableConvertibleValueObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    subscript<Value>(dynamicMember keyPath: WritableKeyPath<WrappedValue, Value>) -> Value {
        get {
            _wrappedValue[keyPath: keyPath]
        }
        set {
            self.objectWillChange.send()
            _wrappedValue[keyPath: keyPath] = newValue
        }
    }

    func update(_ wrappedValue: WrappedValue) {
        self.objectWillChange.send()
        _wrappedValue = wrappedValue
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs._wrappedValue == rhs._wrappedValue
    }

    func convertToValueType() -> WrappedValue {
        _wrappedValue
    }

    var id: WrappedValue.ID {
        _wrappedValue.id
    }
}
```

让我们定义一个 Mock 数据类型来检验成果：

```swift
public final class MockGroup: TestableConvertibleValueObservableObject {
    public var _wrappedValue: TodoGroup
    public required init(_ wrappedValue: TodoGroup) {
        self._wrappedValue = wrappedValue
    }
}
```

现在，在 SwiftUI 的视图中，MockGroup 将具备与 C_Group 几乎一样的能力，唯一不同的是，它是通过一个 TodoGroup 实例构建的。

```swift
let group1 = TodoGroup(id: .string("Group1"), title: "Group1", taskCount: 5)
let mockGroup = MockGroup(group1)
```

由于 WrappedID 的存在，mockGroup 可以在没有托管环境的情况下使用。

### AnyConvertibleValueObservableObject

考虑到 @ObservedObject 只能接受具体类型的数据（ 无法使用 any ConvertibleValueObservableObject ），因此我们需要创建一个类型擦除容器，让 C_Group 和 MockGroup 都能在 GroupCellViewRoot 视图中使用。

```swift
public class AnyConvertibleValueObservableObject<Value>: ObservableObject, Identifiable where Value: BaseValueProtocol {
    public var _object: any ConvertibleValueObservableObject<Value>
    public var id: WrappedID {
        _object.id
    }

    public var wrappedValue: Value {
        _object.convertToValueType()
    }

    init(object: some ConvertibleValueObservableObject<Value>) {
        self._object = object
    }

    public var objectWillChange: ObjectWillChangePublisher {
        _object.objectWillChange as! ObservableObjectPublisher
    }
}

public extension ConvertibleValueObservableObject {
    func eraseToAny() -> AnyConvertibleValueObservableObject<Value> {
        AnyConvertibleValueObservableObject(object: self)
    }
}
```

现在对 GroupCellViewRoot 视图进行如下调整：

```swift
struct GroupCellViewRoot:View {
    @ObservedObject var group:AnyConvertibleValueObservableObject<TodoGroup>
    var body:some View {
        let group = group.wrappedValue
        GroupCellView(group:group)
    }
}
```

我们已经完成了第一个与托管环境解耦的视图链条。

## 创建预览

```swift
let group1 = TodoGroup(id: .string("Group1"), title: "Group1", taskCount: 5)
let mockGroup = MockGroup(group1)

struct GroupCellViewRootPreview: PreviewProvider {
    static var previews: some View {
        GroupCellViewRoot(group: mockGroup.eraseToAny())
            .previewLayout(.sizeThatFits)
    }
}
```

![image-20221128145609968](https://cdn.fatbobman.com/image-20221128145609968.png)

或许会有人觉得，用了如此多的代码，最终仅为实现可以接受 Mock 数据的预览十分不划算。如果仅为达成此目的，直接对 GroupCellView 视图进行预览就好了，为什么要如此大费周章？

如果没有 AnyConvertibleValueObservableObject ，开发者仅能对应用中的部分视图进行预览（ 在不创建托管环境的情况下 ），而通过 AnyConvertibleValueObservableObject ，我们则可以实现将所有的视图代码均从托管环境中解放出来的愿望。通过结合之后介绍的与 Core Data 数据操作进行解耦的方法，无需编写任何 Core Data 代码，就可以实现完成应用中所有视图和数据操作逻辑代码的目标。而且全程可预览，可交互，可测试。

## 回顾

不要被上面的代码所迷惑，使用本文介绍的方式后，重新梳理的开发流程如下：

* 定义 TodoGroup 结构体

```swift
struct TodoGroup: BaseValueProtocol {
    var id: WrappedID
    var title: String
    var taskCount: Int // 当前 Group 中包含的 Task 数量
}
```

* 创建 TodoGroupView（ 此时已无需 TodoGroupViewRoot ）

```swift
struct TodoGroupView:View {
    @ObservedObject var group:AnyConvertibleValueObservableObject<TodoGroup>
    var body:some View {
        let group = group.wrappedValue
        HStack {
            Text(group.title)
            Text("\(group.taskCount)")
        }
    }
}
```

* 定义 MockGroup 数据类型

```swift
public final class MockGroup: TestableConvertibleValueObservableObject {
    public var _wrappedValue: TodoGroup
    public required init(_ wrappedValue: TodoGroup) {
        self._wrappedValue = wrappedValue
    }
}

let group1 = TodoGroup(id: .string("id1"), title: "Group1", taskCount: 5)
let mockGroup = MockGroup(group1)
```

* 创建预览视图

```swift
struct GroupCellViewPreview: PreviewProvider {
    static var previews: some View {
        GroupCellView(group: mockGroup.eraseToAny())
    }
}
```

## 下文介绍

在下篇文章中，我们将介绍如何在视图从 Core Data 中获取数据的操作这一过程中实现与托管环境解耦，创建一个可以接受 Mock 数据的自定义 FetchRequest 类型。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ) 或博客的留言板与我进行交流。

**订阅下方的 [邮件列表](https://artisanal-knitter-2544.ck.page/d3591dd1e7)，可以及时获得每周的 Tips 汇总。**

