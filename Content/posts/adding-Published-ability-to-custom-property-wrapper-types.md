---
date: 2022-05-17 08:20
description: 本文将对 @Published 与符合 ObservableObject 协议的类实例之间的沟通机制做以介绍，并通过三个示例：@MyPublished（ @Published 的仿制版本 ）、@PublishedObject（包装值为引用类型的 @Published 版本）、@CloudStorage（类似 @AppStorage ，但适用于 NSUbiquitousKeyValueStore ），来展示如何为其他的自定义属性包装类型添加可访问包裹其的类实例的属性或方法的能力。
tags: SwiftUI,Swift
title: 为自定义属性包装类型添加类 @Published 的能力
image: images/addingPublishedAbility.png
---
本文将对 @Published 与符合 ObservableObject 协议的类实例之间的沟通机制做以介绍，并通过三个示例：@MyPublished（ @Published 的仿制版本 ）、@PublishedObject（包装值为引用类型的 @Published 版本）、@CloudStorage（类似 @AppStorage ，但适用于 NSUbiquitousKeyValueStore ），来展示如何为其他的自定义属性包装类型添加可访问包裹其的类实例的属性或方法的能力。

## 何为 @Published 的能力

@Published 是 Combine 框架中最常用到的属性包装器。通过 @Published 标记的属性在发生改变时，其订阅者（通过 `$` 或 `projectedValue` 提供的 Publisher ）将收到即将改变的值。

> 不要被它名称尾缀的 `ed` 所迷惑，它的发布时机是在改变前（ `willSet` ）

```swift
class Weather {
    @Published var temperature: Double
    init(temperature: Double) {
        self.temperature = temperature
    }
}

let weather = Weather(temperature: 20)
let cancellable = weather.$temperature
    .sink() {
        print ("Temperature now: \($0)")
}
weather.temperature = 25

// Temperature now: 20.0
// Temperature now: 25.0
```

而在符合 ObservableObject 协议的类中，通过 @Published 标记的属性在发生改变时，除了会通知自身 Publisher 的订阅者外，也会通过包裹它的类实例的 objectWillChange 来通知类实例（ 符合 ObservableObject 协议）的订阅者。这一特性，也让 @Published 成为 SwiftUI 中最有用的属性包装器之一。

```swift
class Weather:ObservableObject {  // 遵循 ObservableObject
    @Published var temperature: Double
    init(temperature: Double) {
        self.temperature = temperature
    }
}

let weather = Weather(temperature: 20)
let cancellable = weather.objectWillChange // 订阅 weather 实例的 obejctWillChange
    .sink() { _ in
        print ("weather will change")
}
weather.temperature = 25

// weather will change
```

仅从调用包裹其类的 objectWillChange 的时机来讲，下面的代码与上面的代码的表现是一样的，但在 @Published 的版本中，**我们并没有为 @Published 提供包裹其类的实例，它是隐式获得的**。

```swift
class Weather:ObservableObject {
    var temperature: Double{  // 没有使用 @Published 进行标记
        willSet {  // 改变前调用类实例的 objectWillChange 
            self.objectWillChange.send()  // 在代码中明确地引用了 Weahter 实例
        }
    }
    init(temperature: Double) {
        self.temperature = temperature
    }
}

let weather = Weather(temperature: 20)
let cancellable = weather.objectWillChange // 订阅 weather 实例
    .sink() { _ in
        print ("weather will change")
}
weather.temperature = 25

// weather will change
```

长期以来，我一直将 @Published 调用包裹其类的实例方法的行为视为理所当然，从未认真想过它是如何实现的。直到我发现除了 @Published 外，@AppStorage 也具备同样的行为（参阅 [@AppStorage 研究](https://fatbobman.com/posts/appstorage/)），此时我意识到或许我们可以让其他的属性包装类型具备类似的行为，创建更多的使用场景。

本文中为其他属性包装类型添加的类似 @Published 的能力是指 —— **无需显式设置，属性包装类型便可访问包裹其的类实例的属性或方法**。

```responser
id:1
```

## @Published 能力的秘密

### 从 Proposal 中找寻答案

我之前并不习惯于看 swift-evolution 的 [proposal](https://github.com/apple/swift-evolution/tree/main/proposals)，因为每当 Swift 推出新的语言特性后，很多像例如 [Paul Hudson](https://www.hackingwithswift.com/) 这样的优秀博主会在第一时间将新特性提炼并整理出来，读起来又快又轻松。但为一个语言添加、修改、删除某项功能事实上是一个比较漫长的过程，期间需要对提案不断地进行讨论和修改。proposal 将该过程汇总成文档供每一个开发者来阅读、分析。因此，如果想详细了解某一项 Swift 新特性的来龙去脉，最好还是要认真阅读与其对应的 proposal 文档。

在有关 Property Wrappers 的文档中，对于如何在属性包装类型中引用包裹其的类实例是有特别提及的 —— [Referencing the enclosing 'self' in a wrapper type](https://github.com/apple/swift-evolution/blob/main/proposals/0258-property-wrappers.md#referencing-the-enclosing-self-in-a-wrapper-type)。

提案者提出：通过让属性包装类型提供一个静态下标方法，以实现对包裹其的类实例的自动获取（无需显式设置）。

```swift
// 提案建议的下标方法
public static subscript<OuterSelf>(
        instanceSelf: OuterSelf,
        wrapped: ReferenceWritableKeyPath<OuterSelf, Value>,
        storage: ReferenceWritableKeyPath<OuterSelf, Self>) -> Value
```

虽然此种方式是在 proposal 的未来方向一章中提及的，但 Swift 已经对其提供了支持。不过，文档中的代码与 Swift 当前的实现并非完全一致，幸好有人在 stackoverflow 上提供了该下标方法的正确参数名称：

```swift
public static subscript<OuterSelf>(
        _enclosingInstance: OuterSelf, // 正确的参数名为 _enclosingInstance
        wrapped: ReferenceWritableKeyPath<OuterSelf, Value>,
        storage: ReferenceWritableKeyPath<OuterSelf, Self>
    ) -> Value
```

@Published 就是通过实现了该下标方法从而获得了“特殊”能力。

### 属性包装器的运作原理

考虑到属性包装器中的包装值（ wrappedValue ）众多的变体形式，Swift 社区并没有采用标准的 Swift 协议的方式来定义属性包装器功能，而是让开发者通过声明属性 @propertyWrapper 来自定义属性包装类型。与 [掌握 Result builders](https://www.fatbobman.com/posts/viewBuilder1/) 一文中介绍的 @resultBuilder 类似，编译器在最终编译前，首先会对用户自定义的属性包装类型代码进行转译。

```swift
struct Demo {
    @State var name = "fat"
}
```

上面的代码，编译器将其转译成：

```swift
struct Demo {
    private var _name = State(wrappedValue: "fat")
    var name: String {
        get { _name.wrappedValue }
        set { _name.wrappedValue = newValue }
    }
}
```

可以看出 propertyWrapper 没有什么特别的魔法，就是一个语法糖。上面的代码也解释了为什么在使用了属性包装器后，无法再声明相同名称（前面加下划线）的变量。

```swift
// 在使用了属性包装器后，无法再声明相同名称（前面加下划线）的变量。
struct Demo {
    @State var name = "fat"
    var _name:String = "ds"  // invalid redeclaration of synthesized property '_name'
}
// '_name' synthesized for property wrapper backing storage
```

当属性包装类型仅提供了 wrappedValue 时（比如上面的 State ），转译后的 getter 和 setter 将直接使用 wrappedValue ，不过一旦属性包装类型实现了上文介绍的静态下标方法，转译后将变成如下的代码：

```swift
class Test:ObservableObject{
    @Published var name = "fat"
}

// 转译为
class Test:ObservableObject{
    private var _name = Published(wrappedValue: "fat")
    var name:String {
        get {
            Published[_enclosingInstance: self,
                                 wrapped: \Test.name,
                                 storage: \Test._name]
        }
        set {
            Published[_enclosingInstance: self,
                                 wrapped: \Test.name,
                                 storage: \Test._name] = newValue
        }
    }
}
```

> 当属性包装器实现了静态下标方法且被**类**所包裹时，编译器将**优先使用静态下标方法**来实现 getter 和 setter 。

下标方法的三个参数分别为：

* _enclosingInstance

  包裹当前属性包装器的类实例

* wrapped

  对外计算属性的 KeyPath （上面代码中对应 name 的 KeyPath ）

* storage

  内部存储属性的 KeyPath （上面代码中对应 _name 的 KeyPath ）

> 在实际使用中，我们只需使用 _enclosingInstance 和 storage 。尽管下标方法提供了 wrapped 参数，但我们目前无法调用它。读写该值都将导致应用锁死

通过上面的介绍，我们可以得到以下结论：

* @Published 的“特殊”能力并非其独有的，与特定的属性包装类型无关
* 任何实现了该静态下标方法的属性包装类型都可以具备本文所探讨的所谓“特殊”能力
* 由于下标参数 wrapped 和 storage 为 ReferenceWritableKeyPath 类型，因此只有在属性包装类型被类包裹时，编译器才会转译成下标版本的 getter 和 setter

> 可以在此处获得 [本文的范例代码](https://github.com/fatbobman/BlogCodes/tree/main/Published)

## 从模仿中学习 —— 创建 @MyPublished

实践是检验真理的唯一标准。本节我们将通过对 @Published 进行复刻来验证上文中的内容。

因为代码很简单，所以仅就以下几点做以提示：

* @Published 的 projectedValue 的类型为 `Published.Publisher<Value,Never>`
* 通过对 CurrentValueSubject 的包装，即可轻松地创建自定义 Publisher
* 调用包裹类实例的 objectWillChange 和给 projectedValue 的订阅者发送信息均应在更改 wrappedValue 之前

```swift
@propertyWrapper
public struct MyPublished<Value> {
    public var wrappedValue: Value {
        willSet {  // 修改 wrappedValue 之前
            publisher.subject.send(newValue)
        }
    }

    public var projectedValue: Publisher {
        publisher
    }

    private var publisher: Publisher

    public struct Publisher: Combine.Publisher {
        public typealias Output = Value
        public typealias Failure = Never

        var subject: CurrentValueSubject<Value, Never> // PassthroughSubject 会缺少初始话赋值的调用

        public func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
            subject.subscribe(subscriber)
        }

        init(_ output: Output) {
            subject = .init(output)
        }
    }

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
        publisher = Publisher(wrappedValue)
    }

    public static subscript<OuterSelf: ObservableObject>(
        _enclosingInstance observed: OuterSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<OuterSelf, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<OuterSelf, Self>
    ) -> Value {
        get {
            observed[keyPath: storageKeyPath].wrappedValue
        }
        set {
            if let subject = observed.objectWillChange as? ObservableObjectPublisher {
                subject.send() // 修改 wrappedValue 之前
                observed[keyPath: storageKeyPath].wrappedValue = newValue
            }
        }
    }
}
```

现在，@MyPublished 拥有与 @Published 完全一样的功能与行为表现：

```swift
class T: ObservableObject {
    @MyPublished var name = "fat" // 将 MyPublished 替换成 Published 将获得同样的结果 
    init() {}
}

let object = T()

let c1 = object.objectWillChange.sink(receiveValue: {
    print("object will changed")
})
let c2 = object.$name.sink{
    print("name will get new value \($0)")
}

object.name = "bob"

// name will get new value fat
// object will changed
// name will get new value bob
```

> 下文中我们将演示如何将此能力应用到其他的属性包装类型

## @PublishedObject —— @Published 的引用类型版本

@Published 只能胜任包装值为**值类型**的场景，当 wrappedValue 为引用类型时，仅改变包装值的属性内容并不会对外发布通知。例如下面的代码，我们不会收到任何提示：

```swift
class RefObject {
    var count = 0
    init() {}
}

class Test: ObservableObject {
    @Published var ref = RefObject()
}

let test = Test()
let cancellable = test.objectWillChange.sink{ print("object will change")}

test.ref.count = 100
// 不会有提示
```

为此，我们可以实现一个适用于引用类型的 @Published 版本 —— @PublishedObject

提示：

* @PublishedObject 的 wrappedValue 为遵循 ObservableObject 协议的引用类型
* 在属性包装器中订阅 wrappedValue 的 objectWillChange ，每当 wrappedValue 发生改变时，将调用指定的闭包
* 在属性包装器创建后，系统**会立刻调用静态下标的 getter 一次**，选择在此时机完成对 wrappedValue 的订阅和闭包的设置

```swift
@propertyWrapper
public struct PublishedObject<Value: ObservableObject> { // wrappedValue 要求符合 ObservableObject
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public static subscript<OuterSelf: ObservableObject>(
        _enclosingInstance observed: OuterSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<OuterSelf, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<OuterSelf, Self>
    ) -> Value where OuterSelf.ObjectWillChangePublisher == ObservableObjectPublisher {
        get {
            if observed[keyPath: storageKeyPath].cancellable == nil {
                // 只会执行一次
                observed[keyPath: storageKeyPath].setup(observed)
            }
            return observed[keyPath: storageKeyPath].wrappedValue
        }
        set {
            observed.objectWillChange.send() // willSet
            observed[keyPath: storageKeyPath].wrappedValue = newValue
        }
    }

    private var cancellable: AnyCancellable?
    // 订阅 wrappedvalue 的 objectWillChange 
    // 每当 wrappedValue 发送通知时，调用 _enclosingInstance 的 objectWillChange.send。
    // 使用闭包对 _enclosingInstance 进行弱引用
    private mutating func setup<OuterSelf: ObservableObject>(_ enclosingInstance: OuterSelf) where OuterSelf.ObjectWillChangePublisher == ObservableObjectPublisher {
        cancellable = wrappedValue.objectWillChange.sink(receiveValue: { [weak enclosingInstance] _ in
            (enclosingInstance?.objectWillChange)?.send()
        })
    }
}
```

@PublishedObject 为我们提供了更加灵活的能力来驱动 SwiftUI 的视图，比如我们可以这样使用 @PublishedObject ：

```swift
@objc(Event)
public class Event: NSManagedObject { // Core Data 的托管对象符合 ObservableObject 协议
    @NSManaged public var timestamp: Date?
}

class Store: ObservableObject {
    @PublishedObject var event = Event(context: container.viewContext)

    init() {
        event.timestamp = Date().addingTimeInterval(-1000)
    }
}

struct DemoView: View {
    @StateObject var store = Store()
    var body: some View {
        VStack {
            Text(store.event.timestamp, format: .dateTime)
            Button("Now") {
                store.event.timestamp = .now
            }
        }
        .frame(width: 300, height: 300)
    }
}
```

![publishedObject_demo1_2022-05-15_09.28.41.2022-05-15 09_29_23](https://cdn.fatbobman.com/publishedObject_demo1_2022-05-15_09.28.41.2022-05-15%2009_29_23.gif)

## @CloudStorage —— @AppStorage 的 CloudKit 版本

在 [@AppStorage 研究](https://fatbobman.com/posts/appstorage/) 一文中，我介绍过，除了 @Published 外，@AppStorage 也同样具备引用包裹其的类实例的能力。因此，我们可以使用如下的代码在 SwiftUI 中统一管理 UserDefaults ：

```swift
class Defaults: ObservableObject {
    @AppStorage("name") public var name = "fatbobman"
    @AppStorage("age") public var age = 12
}
```

Tom Lokhorst 写了一个类似 @AppStorage 的第三方库 —— @CloudStorage ，实现了在 NSUbiquitousKeyValueStore 发生变化时可以驱动 SwiftUI 视图的更新：

```swift
struct DemoView: View {
    @CloudStorage("readyForAction") var readyForAction: Bool = false
    @CloudStorage("numberOfItems") var numberOfItems: Int = 0
    var body: some View {
        Form {
            Toggle("Ready", isOn: $readyForAction)
                .toggleStyle(.switch)
            TextField("numberOfItems",value: $numberOfItems,format: .number)
        }
        .frame(width: 400, height: 400)
    }
}
```

我们可以使用本文介绍的方法为其添加了类似 @Published 的能力。

> 在撰写 [在 SwiftUI 下使用 NSUbiquitousKeyValueStore 同步数据](https://www.fatbobman.com/posts/nsubiquitousKeyvalueStore/) 一文的时候，我尚未掌握本文介绍的方法。当时只能采用一种比较笨拙的手段来与包裹 @CloudStorage 的类实例进行通信。现在我已用本文介绍的方式重新修改了 @CloudStorage 代码。由于 @CloudeStorage 的作者尚未将修改后的代码合并，因此大家目前可以暂时使用我 [修改后的 Fork 版本](https://github.com/fatbobman/CloudStorage)。

代码要点：

* 由于设置的 projectValue 和 _setValue 的工作是在 CloudStorage 构造器中进行的，此时只能捕获为 nil 的闭包 sender ，通过创建一个类实例 holder 来持有闭包，以便可以通过下标方法为 sender 赋值。
* 注意 `holder?.sender?()` 的调用时机，应与 willSet 行为一致

```swift
@propertyWrapper public struct CloudStorage<Value>: DynamicProperty {
    private let _setValue: (Value) -> Void

    @ObservedObject private var backingObject: CloudStorageBackingObject<Value>

    public var projectedValue: Binding<Value>

    public var wrappedValue: Value {
        get { backingObject.value }
        nonmutating set { _setValue(newValue) }
    }

    public init(keyName key: String, syncGet: @escaping () -> Value, syncSet: @escaping (Value) -> Void) {
        let value = syncGet()

        let backing = CloudStorageBackingObject(value: value)
        self.backingObject = backing
        self.projectedValue = Binding(
            get: { backing.value },
            set: { [weak holder] newValue in
                backing.value = newValue
                holder?.sender?() // 注意调用时机
                syncSet(newValue)
                sync.synchronize()
            })
        self._setValue = { [weak holder] (newValue: Value) in
            backing.value = newValue
            holder?.sender?()
            syncSet(newValue)
            sync.synchronize()
        }

        sync.setObserver(for: key) { [weak backing] in
            backing?.value = syncGet()
        }
    }

    // 因为设置的 projectValue 和 _setValue 的工作是在构造器中进行的，无法仅捕获闭包 sender（当时还是 nil），创建一个类实例来持有闭包，以便可以通过下标方法配置。
    class Holder{
        var sender: (() -> Void)?
        init(){}
    }

    var holder = Holder()

    public static subscript<OuterSelf: ObservableObject>(
        _enclosingInstance observed: OuterSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<OuterSelf, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<OuterSelf, Self>
    ) -> Value {
        get {
            // 设置 holder 的时机和逻辑与 @PublishedObject 一致
            if observed[keyPath: storageKeyPath].holder.sender == nil {
                observed[keyPath: storageKeyPath].holder.sender = { [weak observed] in
                    (observed?.objectWillChange as? ObservableObjectPublisher)?.send()
                }
            }
            return observed[keyPath: storageKeyPath].wrappedValue
        }
        set {
            if let subject = observed.objectWillChange as? ObservableObjectPublisher {
                subject.send()
                observed[keyPath: storageKeyPath].wrappedValue = newValue
            }
        }
    }
}
```

使用修改后的代码，可以将 @AppStorage 和 @CloudStorage 统一管理，以方便在 SwiftUI 视图中使用：

```swift
class Settings:ObservableObject {
       @AppStorage("name") var name = "fat"
       @AppStorage("age") var age = 5
       @CloudStorage("readyForAction") var readyForAction = false
       @CloudStorage("speed") var speed: Double = 0
}

struct DemoView: View {
    @StateObject var settings = Settings()
    var body: some View {
        Form {
            TextField("Name", text: $settings.name)
            TextField("Age", value: $settings.age, format: .number)
            Toggle("Ready", isOn: $settings.readyForAction)
                .toggleStyle(.switch)
            TextField("Speed", value: $settings.speed, format: .number)
            Text("Name: \(settings.name)")
            Text("Speed: ") + Text(settings.speed, format: .number)
            Text("ReadyForAction: ") + Text(settings.readyForAction ? "True" : "False")
        }
        .frame(width: 400, height: 400)
    }
}
```

![cloudStorage_demo_2022-05-15_09.41.31.2022-05-15 09_42_28](https://cdn.fatbobman.com/cloudStorage_demo_2022-05-15_09.41.31.2022-05-15%2009_42_28.gif)

## 总结

很多东西在我们对其不了解时，常将其视为黑魔法。但只要穿越其魔法屏障就会发现，或许并没有想象中的那么玄奥。

希望本文能够对你有所帮助。
