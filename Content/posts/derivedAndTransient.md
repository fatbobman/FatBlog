---
date: 2021-10-26 07:30
description: 使用过 Core Data 的开发者，一定会在编辑 Data Model 时看到过右侧的属性面板中的 Derived 和 Transient 两个属性。关于这两个属性的文档不多，大多的开发者并不清楚该如何使用或在何时使用该属性。文本将结合我的使用体验，对 Derived 和 Transient 两个属性的功能、用法、注意事项等内容作以介绍。
tags: Core Data
title:  如何在 Core Data 中使用 Derived 和 Transient 属性
image: images/derivedAndTransient.png
---
## 前言 ##

使用过 Core Data 的开发者，一定会在编辑 Data Model 时看到过右侧的属性面板中的 Derived 和 Transient 两个属性。关于这两个属性的文档不多，大多的开发者并不清楚该如何使用或在何时使用该属性。文本将结合我的使用体验，对 Derived 和 Transient 两个属性的功能、用法、注意事项等内容作以介绍。

```responser
id:1
```

## Derived ##

### 什么是 Derived 属性 ###

从 iOS 13 开始，苹果在 Core Data 中添加了 Derived（派生属性），它的名称已经表明了该属性的含义—— 该属性的值从一个或多个其他的属性的值派生而来。

通俗地说，就是在创建或修改托管对象实例时，Core Data 将自动为派生属性生成值。值将根据预设的派生表达式（Derived Expression）通过其他的属性值计算而来。

### Derived 属性的功能 ###

下面通过一个具体的例子方便大家理解派生属性的功能。

项目中有两个 Entity，TodoList 和 Item，Todolist 同 Item 是一对多关系（To-many），Item 同 TodoList 之间是一对一关系（To-one）

![image-20211025175712406](https://cdn.fatbobman.com/image-20211025175712406.png)

在之前如果我们要查看每个 TodoList 下有多少个 Item，可以使用如下代码：

```swift
let count = todolist.items.count
```

使用 Derived 派生属性后，我们将可以通过如下代码获取Item的个数。

```swift
let count = todolist.count
```

### 如何设置 Derived 属性 ###

通常我们需要在 Core Data 的数据模型编辑器（Data Model Editor）中设置派生属性，如下图，我们为上面的例子中的 TodoList 创建派生属性 count

![image-20211025183247335](https://cdn.fatbobman.com/image-20211025183247335.png)

* 为 TodoList 创建名为 count 的属性
* 选择 Derived
* 将 Derivation 设置为 items.@count （计算 items 关系对应的数据个数）

开发者可以根据需要设定派生属性的类型和派生表达式，目前支持的派生表达式有以下几种形式：

* 仅仅复制内容

  通常使用在 to-one 的关系中，比如上面的例子中，我们可以使用派生表达式`todolist.name`，为 Item 设置一个 todolistName 的 Derived 属性，用于保存该 Item 对应的 TodoList 的名称。复制的属性类型没有特别的限制。

* 将某个属性（类型为字符串）经过变换保存

  仅支持类型为 String 的属性，可以使用在同一个 Entity 中的不同属性或者 to-one 的 Entity 属性中。支持 `uppercase:` 、`lowercase:` 以及 `canonical:` 三种方法。通过保存字符串的变体，提供搜索效率。 例如，保存 TodoList 的 name 的小写版本的派生表达式为`lowercase:(todolist.name)`。

* 计算对多关系的 count 和 sum

  计算对多关系（to-many）对象的个数或计算指定属性的求和值。使用@sum 时，要求对应的属性必须为可计算值类型。例如计算一个实体名称为 Student，属性名为 age 的总和值的表达式为 `student.age.@sum`。

* 当前时间

  保存SQLite更新托管对象对应的数据记录的操作日期。通常用于类似 lastModifiedDate 之类的时间戳。派生表达式为`now()`。

通常我们将 Derived 同 Optional 配合使用，如果不选取 Optional 则需要做一点特殊处理才能让程序正常执行。在下文的注意事项中有具体说明。

如果手动编写 NSManagedObject 代码，Derived 属性的写法同其他属性也完全一致（仍需在 Data Model Editor 中设置），例如上文中的 count 可以使用如下代码定义：

```swift
@NSManaged var count: Int
```

### Derived 数据的更新机制 ###

#### 派生数据的值是谁计算的 ####

派生数据的值是由 SQLite 直接计算并更新的。

Derived 值的计算是 Core Data 中为数不多的几个直接使用 SQLite 内置机制来完成的操作，并非由 Swift（或 Objective - C） 代码计算而来。

例如，now() 的表达式，Core Data 在创建数据表时将产生类似如下的 SQL代码：

```sql
CREATE TRIGGER IF NOT EXISTS Z_DA_ZITEM_Item_update_UPDATE AFTER UPDATE OF Z_OPT ON ZITEM FOR EACH ROW BEGIN UPDATE ZITEM SET ZUPDATE = NSCoreDataNow() WHERE Z_PK = NEW.Z_PK; SELECT NSCoreDataDATriggerUpdatedAffectedObjectValue('ZITEM', Z_ENT, Z_PK, 'update', ZUPDATE) FROM ZITEM WHERE Z_PK = NEW.Z_PK; END'
```

@count 对应的代码：

```swift
UPDATE ZITEM SET ZCOUNT = (SELECT IFNULL(COUNT(ZITEM), 0) FROM ZATTACHEMENT WHERE ZITEM = ZITEM.Z_PK);
```

因此在相同功能的情况下，使用SQL的效率是高于 Swift（或 Objective - C）的。

> Core Data 中，通常需要从持久化存储获取结果后，返回到上下文，再经过计算然后持久化。中间有多次的IO过程，影响了效率。

#### 派生数据什么时候更新 ####

因为是由 SQLite 直接处理的，所以只有在数据持久化时 SQLite 才会更新对应的派生数据。只在上下文中处理不持久化的话是不会获得正确的派生值的。持久化的行为可以是通过使用代码`viewcontext.save()`，或者通过网络同步等方式激发。

### Derived 的优缺点 ###

#### 优点 ####

* 效率高

  由于其特有的更新机制，所以对于值的处理效率更高，且不会有多余的处理动作（只在持久化时才进行更新）。

* 逻辑简洁清晰

  使用得当的情况下，配置所需代码更少，表达更清晰。例如`now()`

#### 缺点 ####

* 支持的表达式有限

  SQLite 能够支持的表达式非常有限，无法满足更复杂的业务需要。

* 对于不了解 Derived 的开发者来说，代码更难阅读

  Derived 的配置是在 Data Model Editor 中进行的，仅阅读代码将无法获悉该数据的来源和处理方式。

### Derived 的替代方案 ###

#### 计算属性 ####

对于使用频率不高的属性值，为托管对象创建计算属性或许是更好的选择，例如上文中计算 TodoList 的 Item 数量。

```swift
extension TodoList {
    var count:Int { items.count }
}
```

#### willSave ####

使用 NSManagedObject 的 willSave 方法，在数据持久化前，为指定属性设置值。例如：

```swift
extension Item {
    override func willSave() {
      super.willSave()
      setPrimitiveValue(Date(), forKey: #keyPath(Item.lastModifiedDate))
  }
}
```

Derived 同上述两种方式均有各自的优缺点，请根据具体的使用场景来选择合适的方案。

### Derived 的注意事项 ###

在配置 Derived 属性时，如果不选择 Optional，直接执行代码的话，在添加数据时会得到类似如下的错误：

```bash
Fatal error: Unresolved error Error Domain=NSCocoaErrorDomain Code=1570 "count is a required value."
```

这是因为，由于该属性并非可选值，所以 Core Data 要求我们为派生属性默认值，但是由于派生属性是只读的，因此我们无法在代码中直接为托管对象实例的派生属性赋值。

解决的方法是，通过在 awakeFromInsert 中为派生属性设置初始化值，即可通过 Core Data 的属性有效性检查。

```swift
extension TodoList {
    override func awakeFromInset(){
        super.awakeFromInsert()
        setPrimitiveValue(0, forKey: #keyPath(Todolist.count)) 
    }
}
```

设置的 value 可以是任意值（需要符合类型要求），因为在持久化时，SQLite 将生成新的值覆盖掉我们的初始化值。

## Transient ##

### 什么是 Transient 属性 ###

Transient（瞬态属性）是一种不可持久化的属性。作为托管对象定义的一部分，Core Data 会跟踪 Transient 属性的变化，并设置对应的托管对象和托管对象上下文状态，但属性中的内容将不会被保存到持久化存储器中，也不会在持久化存储中创建对应的字段。

除了不能持久化外，瞬态属性同其他的 Core Data 属性没有什么区别，支持全部的可用数据类型，以及 Optional，Default Value 等选项。

### 如何设置 Transient 属性 ###

相较于 Derived，瞬态属性设置非常简单，只需要勾选 Transient 即可。

![image-20211025201846952](https://cdn.fatbobman.com/image-20211025201846952.png)

### 为什么使用 Transient ###

既然 Transient 不可持久化，为什么我们要使用 Data Model Editor 来创建它呢？

我们可以通过代码直接为托管对象创建存储属性，例如：

```swift
@objc(Test)
public class Item: NSManagedObject {
  var temp:Int = 0
}

extension Item
    @NSManaged public var createDate: Date?
    @NSManaged public var title: String?

}

let item = Item(context:viewContext)
item.temp = 100
```

上面的代码，无论我们如何修改 item 的 temp 属性，都不会让 Core Data 感知到。

托管对象的托管属性（使用@NSManaged 标示）是由 Core Data 来托管的，Core Data 将持续跟踪托管对象中的托管属性来设置相应的状态。使用 Transient 属性，Core Data 在该属性内容发生变化时将托管对象实例的 hasChanges 以及托管对象上下文的 hasChanges 设置为 true，这样无论是@FetchRequest 还是 NSFetchedResultsController 都将会自动反应数据的变化。

因此，当我们不需要持久化但又要能够 dirty 状态时，Transient 就成了唯一的选择。

### Transient 值的初始化 ###

由于 Transient 属性是不可持久化的，因此每当含有 Transient 属性的托管对象实例出现（Fetch、Create、Undo 等情况）在上下文中时，其瞬态属性都将恢复到初始值。

尽管在 Data Model Editor 中，我们可以为 Transient 设置默认值，但很多场景下，我们需要根据情况或其他数据计算并创建 Transient 的初始值。我们可以选择在如下的时机来设置：

* awakeFromFetch

  为惰值状态（Fault）的实例填充数据时

* awakeFromInsert

  创建托管对象实例时

* awake(fromSnapshotEvents:NSSnapshotEventType)

  从快照中载入实例时

在这些方法中设置 Transient 或其他属性时，应使用原始访问器方法来设置数据，避免触发 KVO 观察器通知。例如：

```swift
setPrimitiveValue("hello",forKey:#keyPath(Movie.title))
```

### Transient 属性使用举例 ###

绝大多数的 Core Data 书籍中，即使提到了 Transient 属性也通常是一带而过。作者通常会表示自己没有遇到合适的 Transient 使用案例。

我也是在不久前，才遇到第一个符合 Transient 特点的应用场景。

在开发 [【健康笔记 3.0】](https://www.fatbobman.com/healthnotes/) 的过程中，我有一处地方需要对一个包含很多关系和记录的托管对象实例进行 Deep Copy（复制其下的全部关系数据），复制后的实例将在复制完成后替换掉原来的实例（为了解决网络数据共享中遇到的特殊需求）。因为使用了@FetchRequest，因此在复制过程中的 1-2 秒钟，UI 列表中会出现两个同样的数据记录，会给使用者带来困惑。

如果使用持久化方案，我可以为该数据创建一个用来表示显示与否的属性，例如 visible。通过在复制操作前后设置该属性并配置 Predicate 来解决列表重复问题。

但由于该场景的使用次数非常少（很多用户可能完全不会使用到），因此创建一个可持久性字段将非常浪费。

因此，我为该托管对象创建了一个名为 visible 的 Transient 属性，既避免了重复显示，同时又不会浪费存储空间。

### 其他关于 Transient 的注意事项 ###

* NSManagedObjectContext 的 refreshAllObjects 将重置 Transient 内容
* 如果仅需要查看托管对象可持久性属性是否有改变可以使用 hasPersistentChangedValues
* 不要在 NSPredicate 中使用 transient 属性作为限制条件

```swift
    @FetchRequest(entity: Test.entity(),
                  sortDescriptors: [NSSortDescriptor(keyPath: \Test.title, ascending: true)],
                  predicate: NSPredicate(format: "visible = true"))
    var tests: FetchedResults<Test>
```

上面代码的使用方式是错误的，如果想仅显示 visible == true 的数据，可以使用如下方式：

```swift
    @FetchRequest(entity: Test.entity(),
                  sortDescriptors: [NSSortDescriptor(keyPath: \Test.title, ascending: true)])

    ForEach(tests) { test in
         if test.visible {
             row(test: test)
         }
    }
```

## 总结 ##

Core Data 作为一个历史悠久的框架，包含了不少非常有用但不被人熟知的功能。即使只是泛泛了解一下这些功能，不仅可以开阔思路，说不定在某个场合它就会成为解决问题的利器。

想阅读更多关于 Core Data 的文章，请查看我的 [Core Data 专栏](https://www.fatbobman.com/tags/core-data/)。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。

