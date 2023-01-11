---
date: 2022-12-06 08:20
description: 本文中我们将探讨在 SwiftUI 视图中批量获取 Core Data 数据的方式，并尝试创建一个可以使用 mock 数据的 FetchRequest。由于本文会涉及大量前文中介绍的技巧和方法，因此最好一并阅读。
tags: Core Data,SwiftUI
title: SwiftUI 与 Core Data —— 数据获取
image: images/modern-Core-Data-fetcher.png
---
本文中我们将探讨在 SwiftUI 视图中批量获取 Core Data 数据的方式，并尝试创建一个可以使用 mock 数据的 FetchRequest。由于本文会涉及大量 [前文](https://www.fatbobman.com/posts/modern-Core-Data-Data-definition/) 中介绍的技巧和方法，因此最好一并阅读。

* [SwiftUI 与 Core Data —— 问题](https://www.fatbobman.com/posts/modern-Core-Data-Problem/)
* [SwiftUI 与 Core Data —— 数据定义](https://www.fatbobman.com/posts/modern-Core-Data-Data-definition/)

## 创建可使用 Mock 数据的 FetchRequest

### FetchRequest 单向数据流的破坏者？

对于每一个在 SwiftUI 中使用 Core Data 的开发者来说，@FetchRequest 都是绕不开的话题。FetchRequest 极大地简化了在视图中获取 Core Data 数据的难度，配合 @ObservedObject（ 托管对象符合 ObservableObject 协议 ），仅需几行代码，开发者便可以让视图实现对数据变化的实时响应。

但对于采用单向数据流方式的开发者，@FetchRequest 就像悬挂在头顶的达摩克利斯之剑，始终让其介怀。类 Redux 框架通常都建议开发者将整个 app 的状态合成到一个单一的结构实例中（ State ，符合 Equatable 协议 ），视图通过观察状态的变化（ 有些框架支持切片式的观察以改善性能 ）而做出响应。而 @FetchRequest 将 app 中状态构成中的很大一部分从独立的结构实例中分拆出来，散落在多个视图之中。这几年不少开发者也尝试找寻更加符合 Redux 精神的替换方案，但效果都不理解。

```responser
id:1
```

我也做了不少的尝试，但最终发现似乎 FetchRequest 仍是当前 SwiftUI 中的最优解。简单介绍一下我探索过程（ 以 TCA 框架进行举例 ）：

* 在 Reducer 中获取并管理值数据

  在 task（ 或 onAppear ）中通过发送 Action 启动一个长期的 Effect ，创建一个 NSFetchedResultsController 从 Core Data 中获取指定谓词的数据集。在 NSFetchedResultsControllerDelegate 实现中将托管对象转换成对应的值类型，并传递给 Reducer 。

  在 State 中使用 IdentifiedArray 类型保存数据集，以便通过 .forEach 对 Reducer 进行拆分。

  上述做法确实是完全符合 Redux 精神的一种方式，但由于在将托管对象转换到值类型这一过程中我们放弃了 Core Data 的懒加载这一特性，因此一旦数据量较多将导致严重的性能和内存占用问题。因此，只适合数据集较小的使用场景。

* 在 Reducer 中获取并管理 AnyConvertibleValueObservableObject

  类似上面的方法，但省略了转换成值类型的过程，将托管对象包装成 AnyConvertibleValueObservableObject ，直接在 State 中保存引用类型。不过考虑到 TCA 在之后会将 Reducer 移出主线程，从线程安全的角度出发，最终放弃了该方案。

> 由于最终我们需要在视图中使用 AnyConvertibleValueObservableObject（ 托管对象 ），因此数据的获取过程必须是在主线程上下文中进行的（ 数据绑定的上下文是 ViewContext ），Reducer 一旦从主线程中移出的话，意味着 AnyConvertibleValueObservableObject 会被保存在非线程的 State 实例中。尽管在实践中，如果能在确保不访问托管对象的非线程安全属性的前提下，在非创建托管对象的线程中持有托管对象并不会出现崩溃的情况，但出于谨慎的考虑，我最终还是放弃了这种方式。

* 在 Reducer 中获取并管理 WrappedID

  类似上面的方法，仅在 State 中保存线程安全的 WrappedID（ 包装后的 NSManagedObjectID ）。在视图中通过 WrappedID 获取到对应的 AnyConvertibleValueObservableObject 或值类型。尽管会增加一点视图的代码量，但这种方法无论从数据流的处理还是线程安全的角度来说几乎都是完美的。

不过，最终让我放弃上面所有尝试的原因还是因为性能问题。

* 任何 Core Data 数据的变化都将导致 app 的单一 State 发生改变，尽管 TCA 有切分机制，但随着应用复杂程度和数据量的增加，因对 State 进行比对而产生的性能问题将越发严重
* 创建 NSFetchedResultsController 并获取首批数据的操作是从 onAppear 中发起的，由于 TCA 的 Action 处理机制，数据的首次显示有可感知的延迟（ 效果远不如在视图中通过 FetchRequest 获取 ）
* 由于 TCA 的 Reducer 无法与视图的存续期自动绑定，上面的可感知延迟在每次触发 onAppear 时都将出现

最终，我决定放下心结，仍然采用在视图中使用类似 @FetchRequest 的方式来获取数据。通过新创建一个可以使用 Mock 数据的 FetchRequest ，实现了 [SwiftUI 与 Core Data —— 问题](https://www.fatbobman.com/posts/modern-Core-Data-Problem/) 一文中提出的可测试、可预览、可模块化的目标。

### NSFetchedResultsController

NSFetchedResultsController 通过 NSFetchRequest 从 Core Data 中获取特定的数据集，并将数据集发送至符合 NSFetchedResultsControllerDelegate 协议实例中实现方法，以实现在屏幕上显示数据的目的。

简单地来说，NSFetchedResultsController 就是在首次获取数据集（ performFetch ）后，对 NSManagedObjectContextObjectsDidChange 以及 NSManagedObjectContextDidMergeChangesObjectIDs 通知进行响应，并根据通知内容（ insert、delete、update 等 ）自动更新内存中数据集。为了提高 UITableView（ UICollectionView ）的更新效率，NSFetchedResultsController 会将数据的变化分解成特定的动作（ NSFetchRequestResultType ）以方便开发者快速调整 UITableView 的显示内容（ 无需刷新全部的数据 ）。

遗憾的时，NSFetchedResultsController 为 UITableView 准备的基于 NSFetchRequestResultType 优化操作在 SwiftUI 中并不起作用。在 SwiftUI 中，ForEach 会根据数据标识（ Identifier ）自动处理视图的添加、删除等操作，因此，当在 SwiftUI 中使用 NSFetchedResultsController 时，只需要实现 NSFetchedResultsControllerDelegate 中的 `controllerDidChangeContent(_ controller: )` 方法即可。

### 自定义符合 DynamicProperty 协议的类型

在 SwiftUI 中，常见的可以作为 Source of truth 的类型均符合 DynamicProperty 协议。DynamicProperty 协议为数据提供了访问 SwiftUI 托管数据池的能力。通过未公开的 `_makeProperty` 方法，数据可以在 SwiftUI 数据池中申请空间进行保存并读取。这将有两个作用：

* 数据变化后将引发与其绑定的视图进行更新
* 由于底层数据并不保存在视图中，因此在视图存续期中 SwiftUI 可以随时创建新的视图描述实例而无需担心数据丢失

虽然苹果没有公开 `_makeProperty` 方法的具体细节，开发者无法自行向 SwiftUI 申请数据保存地址，但可以通过在自定义的类型中（ 符合 DynamicProperty 协议 ）使用系统提供的符合 DynamicProperty 协议的类型（ 如 State ）实现类似的效果。

在创建自定义 DynamicProperty 类型时，需要注意以下几点：

* 可以在自定义类型中使用环境值或环境对象

  在视图被加载后，视图中所有符合 DynamicProperty 协议的类型也将一并具备访问环境数据的能力。但如果在视图尚未加载或没有提供环境值（ 例如忘记注入环境对象，没有提供正确的视图上下文 ）的情况下访问环境数据，将引发应用崩溃。

* 当 SwiftUI 在视图存续期中重新创建视图描述实例时，自定义类型也将一并重新创建

  在视图存续期中，如果 SwiftUI 创新创建了视图描述实例，那么无论视图描述（ 符合 View 协议的 Struct ）中的属性是否符合 DynamicProperty ，都将被重建。这意味着，必须将需要持久化的数据（ 与视图存续期一致 ）保存在系统提供的 DynamicProperty 类型中。

* 视图被 SwiftUI 加载后才会调用 update 方法

  DynamicProperty 协议唯一公开的方法是 update ，SwiftUI 将在视图首次被加载以及符合 DynamicProperty 类型中的可引发视图更新的数据发生变化后调用该方法。由于类型的实例在视图存续期中可能会反复地被创建，因此对数据的准备（ 例如首次获取 NSFetchedResultsController 数据、创建订阅关系 ）以及更新工作都应在该方法中进行。

* 不可在 update 方法中同步地改变引发视图更新的数据

  与 SwiftUI 在视图中更新 Source of truth 的逻辑一致，在一个视图更新周期中，不能对  Source of truth 再度更新。这意味着，尽管我们只能在 update 方法中更改数据，但必须要想办法错开该更新周期。

### MockableFetchRequest 的使用方法

MockableFetchRequest 提供与 FetchRequest 类似的动态获取数据的能力，但它有如下的特点：

* MockableFetchRequest 返回 AnyConvertibleValueObservableObject 类型的数据

  MockableFetchRequest 中的 NSFetchedResultsController 会将数据直接转换为 AnyConvertibleValueObservableObject 类型，一方面可以在视图中直接享受前文中介绍的各种好处，另一方面也可以避免在视图中声明 MockableFetchRequest 时，使用具体的托管对象类型，有利于模块化开发。

```swift
 @MockableFetchRequest(\ObjectsDataSource.groups) var groups // 代码不会被具体的托管对象类型所污染
```

* 通过环境值切换数据源

  在前文中，我们通过创建符合 TestableConvertibleValueObservableObject 协议的数据为一个包含单个 AnyConvertibleValueObservableObject 对象的视图提供了无需托管环境的预览能力。MockableFetchRequest 则为一个获取数据集的视图提供了无需托管环境预览一组数据的能力。

  首先，我们需要创建一个符合 ObjectsDataSourceProtocol 协议的类型， 通过让属性为 FetchDataSource 类型来指定数据源。

```swift
// MockableFetchRequest 代码中已包含
public enum FetchDataSource<Value>: Equatable where Value: BaseValueProtocol {
    case fetchRequest // 通过 MockableFetchRequest 中的 NSFetchedResultsController 获取数据
    case mockObjects(EquatableObjects<Value>) // 使用提供的 Mock 数据
}

public extension EnvironmentValues {
    var dataSource: any ObjectsDataSourceProtocol {
        get { self[ObjectsDataSourceKey.self] }
        set { self[ObjectsDataSourceKey.self] = newValue }
    }
}

// 开发者需要自定义的代码
public struct ObjectsDataSource: ObjectsDataSourceProtocol {
    public var groups: FetchDataSource<TodoGroup>
}

public struct ObjectsDataSourceKey: EnvironmentKey {
    public static var defaultValue: any ObjectsDataSourceProtocol = ObjectsDataSource(groups: .mockObjects(.init([MockGroup(.sample1).eraseToAny()]))) // 设置默认的数据源来自 mock 数据
}
```

可以在预览的时候对数据进行实时修改（ 详情请参阅 Todo 中的 [GroupListContainer 代码](https://github.com/fatbobman/Todo/blob/main/Todo-PureSwiftUI/Todo-PureSwiftUI/GroupListContianer.swift) ）。

![image-20221203183414864](https://cdn.fatbobman.com/image-20221203183414864.png)

当应用运行于托管环境时，仅需提供正确的视图上下文，并将 dataSource 中的属性值修改成 fetchRequest 即可。

![image-20221203185621897](https://cdn.fatbobman.com/image-20221203185621897.png)

* 允许在构造方法中不提供 NSFetchRequest

  当在视图中使用 @FetchRequest 时，我们必须在声明 FetchRequest 变量时设置 NSFetchRequest（ 或者 NSPredicate ）。如此一来，在将视图提取到一个单独的 Package 时，仍需导入包含具体 Core Data 托管对象定义的库，无法做到完全的解耦。在 MockableFetchRequest 中，无需在声明时提供 NSFetchRequest，可以在视图加载时，动态地为 MockableFetchRequest 提供所需的 NSFetchRequest（ [详细演示代码](https://github.com/fatbobman/Todo/blob/main/ViewLibrary/Sources/ViewLibrary/GroupList.swift) ）。

```swift
public struct GroupListView: View {
    @MockableFetchRequest(\ObjectsDataSource.groups) var groups
    @Environment(\.getTodoGroupRequest) var getTodoGroupRequest

    public var body: some View {
        List {
                ForEach(groups) { group in
                    GroupCell(
                        groupObject: group,
                        deletedGroupButtonTapped: deletedGroupButtonTapped,
                        updateGroupButtonTapped: updateGroupButtonTapped,
                        groupCellTapped: groupCellTapped
                    )
                }
        }
        .task {
            guard let request = await getTodoGroupRequest() else { return } // 在视图加载时通过环境方法获取所需的 Request
            $groups = request // 动态对 MockableFetchRequest 设置
        }
        .navigationTitle("Todo Groups")
    }
}
```

* 避免对不引发 ID 变化的操作更新数据集

当数据集的 ID 顺序或数量没有发生变化时，即使数据的属性值发生变化，MockableFetchRequest 也不会更新数据集。因为 AnyConvertibleValueObservableObject 本身符合 ObservableObject 协议，因此尽管 MockableFetchRequest 没有更新数据集，但视图仍会对 AnyConvertibleValueObservableObject 中的属性变化进行响应。这样可以减少 ForEach 数据集的变化频次，改善 SwiftUI 的视图效率。

* 提供了一个更加轻巧的 Publisher 以监控数据变化

原版的 FetchRequest 提供了一个 Publisher（ 通过投影值 ），会对每次的数据集变化做出响应。不过该 Publisher 的响应过于频繁，即使数据集中仅有一个数据的属性发生改变，也会下发数据集中的所有数据。MockableFetchRequest 对此进行了简化，仅会在数据集发生变化时，下发一个空的通知（ `AnyPublisher<Void, Never>` ）。

```swift
public struct GroupListView: View {
    @MockableFetchRequest(\ObjectsDataSource.groups) var groups

    public var body: some View {
        List {
		   ...
        }
        .onReceive(_groups.publisher){ _ in
            print("data changed")
       }
    }
}
```

> 如果需要实现与 @FetchRequest 一样的效果，仅需提高 sender 属性的权限即可

下图为完全依赖 mock 数据创建的预览演示：

![mockableFetchRequest_demo_2022-12-04_11.12.46.2022-12-04 11_14_21](https://cdn.fatbobman.com/mockableFetchRequest_demo_2022-12-04_11.12.46.2022-12-04%2011_14_21.gif)

```responser
id:1
```

### MockableFetchRequest 代码说明

本节仅对部分代码进行说明，[完整代码请于此处查看](https://github.com/fatbobman/Todo/blob/main/Core/Sources/Core/ModernCoreData/MockableFetchRequest.swift)。

* 如何避免更新数据与 update 周期重合

  在 MockableFetchRequest 中，我们通过一个类型为 `PassthroughSubject<[AnyConvertibleValueObservableObject<Value>], Never>`  的 Publisher，统一管理两个不同的数据源。通过使用 delay 操作符，便可以实现对数据的错峰更新。 如有需要，也可以通过创建 Task 实现对数据的异步更新。

```swift
cancellable.value = sender
    .delay(for: .nanoseconds(1), scheduler: RunLoop.main) // 延迟 1 纳秒即可
    .removeDuplicates {
        EquatableObjects($0) == EquatableObjects($1)
    }
    .receive(on: DispatchQueue.main)
    .sink {
        updateWrappedValue.value($0)
    }
```

* 用引用类型包装需要修改的数据，避免引发视图的不必要的更新

  通过创建一个具有包装用途的引用类型来持有需要修改的数据（ 在 @State 中持有引用 ），便可以达成如下目的：1、让数据的生命周期与视图生存期一致；2、数据可更改；3、更改数据不会引发视图更新。

```swift
  extension MockableFetchRequest {
      // 包装类型
      final class MutableHolder<T> {
          var value: T
          @inlinable
          init(_ value: T) {
              self.value = value
          }
      }
  }
  
  public struct MockableFetchRequest<Root, Value>: DynamicProperty where Value: BaseValueProtocol, Root: ObjectsDataSourceProtocol {
      @State var fetcher = MutableHolder<ConvertibleValueObservableObjectFetcher<Value>?>(nil)
      
      func update() {
          ... 
          // fetcher 是可持久的，修改 fetcher.value 不会引发视图更新
          if let dataSource = dataSource as? Root, case .fetchRequest = dataSource[keyPath: objectKeyPath], fetcher.value == nil {
              fetcher.value = .init(sender: sender)
              if let fetchRequest {
                  updateFetchRequest(fetchRequest)
              }
          }
          ...
      }
  }
```

* 如何比较两个 `[AnyConvertibleValueObservableObject<Value>] ` 是否相同

  由于 Swift 无法直接对包含关联类型的数据进行相等比较，因此创建了一个中间类型 EquatableObjects ，并让其符合 Equatable 协议以方便对两个 `[AnyConvertibleValueObservableObject<Value>]` 数据进行比较，避免不必要的视图刷新。

```swift
  public struct EquatableObjects<Value>: Equatable where Value: BaseValueProtocol {
      public var values: [AnyConvertibleValueObservableObject<Value>]
  
      public static func== (lhs: Self, rhs: Self) -> Bool {
          guard lhs.values.count == rhs.values.count else { return false }
          for index in lhs.values.indices {
              if !lhs.values[index]._object.isEquatable(other: rhs.values[index]._object) { return false }
          }
          return true
      }
  
      public init(_ values: [AnyConvertibleValueObservableObject<Value>]) {
          self.values = values
      }
  }
  
  // in MockableFetchRequest
  if let dataSource = dataSource as? Root, case .mockObjects(let objects) = dataSource[keyPath: objectKeyPath],
     objects != EquatableObjects(_values.wrappedValue)  // 去重
  { 
      sender.send(objects.values)
  }
  
  ...
  
  cancellable.value = sender
      .delay(for: .nanoseconds(1), scheduler: RunLoop.main)
      .removeDuplicates {
          EquatableObjects($0) == EquatableObjects($1) // 去重
      }
      .receive(on: DispatchQueue.main)
      .sink {
          updateWrappedValue.value($0)
      }
```

* 通过操作底层数据解决无法在闭包中引入 self 的问题

  在订阅闭包中使用底层数据，如此就可以绕过无法在结构体中引入 self 的问题。

```swift
let values = _values  // 对应的类型是 State ，也就是 MockableFetchRequest 的 values 属性的底层数据
let firstUpdate = firstUpdate
let animation = animation
updateWrappedValue.value = { data in
    var animation = animation
    if firstUpdate.value {
        animation = nil
        firstUpdate.value = false
    }
    withAnimation(animation) {
        values.wrappedValue = data // 对底层数据进行操作
    }
}
```

### SectionedFetchRequest

我暂时没有对另一个获取数据的方法 SectionedFetchRequest 进行改动。主要的原因是尚未想好要如何地组织返回数据。

当前，SectionedFetchRequest 在数据量较大时会有较严重的性能问题。这是由于一旦 SwiftUI 的惰性容器中出现了多个 ForEach ，惰性容器将丧失对子视图的优化能力。任何数据的变动，惰性容器都将对所有的子视图进行更新而不是仅更新可见部分的子视图。

SectionedFetchRequest 返回的数据类型为 SectionedFetchResults ，可以将其视为一个以 SectionIdentifier 为键的有序字典。读取其数据必然会在惰性容器中使用多个 ForEach ，从而引发性能问题。

```swift
@SectionedFetchRequest<String, Quake>(
    sectionIdentifier: \.day,
    sortDescriptors: [SortDescriptor(\.time, order: .reverse)]
)
private var quakes: SectionedFetchResults<String, Quake>

List {
    ForEach(quakes) { section in
        Section(header: Text(section.id)) {
            ForEach(section) { quake in
                QuakeRow(quake: quake)
            }
        }
    }
}
```

我目前有两种构想：

* 将所有的数据以一个数组进行返回（ sectionIdentifier 为首要排序条件 ），并同时提供每个 Section 在返回数组中对应的起始 offset（ 或对应的 ID ）以及该 Section 中的数据量。
* 将所有的数据以一个数组进行返回（ sectionIdentifier 为首要排序条件 ），在每个 Section 头尾插入特定的 AnyConvertibleValueObservableObject 数据（ 因为 WrappedID 的存在，我们可以很容易创建 mock 数据 ）

无论上述哪种方式，开发者都需放弃使用 SwiftUI 原生的 Section 功能，在惰性容器中，根据提供的附加数据自行对数据做分段显示处理。

> Core Data 本身并不具备直接从 SQLite 中获取分组记录的能力，目前的实现方式是以 sectionIdentifier 为首要排序条件获取所有的数据。然后通过 propertyToGroupBy 对  sectionIdentifier 进行分组，获取每组的数据量（ count ）。通过返回的统计信息，计算每个 Section 的偏移量。

## 本文总结及下文介绍

本文中我们创建了可以支持 mock 数据的 FetchRequest ，并简单介绍了在自定义符合 DynamicProperty 协议的类型时需要注意的事项。

在下一篇文章中，我们将探讨如何在 SwiftUI 中安全地响应数据，如何避免因为数据意外丢失而导致的行为异常以及应用崩溃。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ) 或博客的留言板与我进行交流。

**订阅下方的 [邮件列表](https://artisanal-knitter-2544.ck.page/d3591dd1e7)，可以及时获得每周的 Tips 汇总。**
