---
date: 2020-05-17 12:00
description: 本文试图探讨并分析 SwiftUI 中 @State 的实现方式和运行特征；最后提供了一个有关扩展@State 功能的思路及例程。读者需要对 SwiftUI 的响应式编程有基本概念。
tags: SwiftUI,Architecture
title: @state 研究
---
> 本文试图探讨并分析 SwiftUI 中 @State 的实现方式和运行特征；最后提供了一个有关扩展@State 功能的思路及例程。读者需要对 SwiftUI 的响应式编程有基本概念。

## 研究的意义何在 ##

我在去年底使用了 SwiftUI 写了第一个 iOS app **健康笔记**，这是我第一次接触响应式编程概念。在有了些基本的认识和尝试后，深深的被这种编程的思路所打动。不过，我在使用中也发现了一些奇怪的问题。就像之前在  [老人新兵](https://zhuanlan.zhihu.com/p/103822455) 中说的那样，我发现在视图（View）数量达到一定程度，随着数据量的增加，整个 app 的响应有些开始迟钝，变得有粘滞感、不跟手。app 响应出现了问题一方面肯定和我的代码效率、数据结构设计欠佳有关；不过随着继续分析，发现其中也有很大部分原因来自于 SwiftUI 中所使用的响应式的实现方式。不恰当的使用，可能导致响应速度会随着数据量及 View 量的增加而大幅下降。通过一段时间的研究和分析，我打算用两篇文章来阐述这方面的问题，并尝试提供一个现阶段的使用思路。

```responser
id:1
```

## 数据（状态）驱动 ##

在 SwiftUI 中，视图是由数据（状态）驱动的。按照苹果的说法，视图是状态的函数，而不是事件的序列（The views are a function of state, not a sequence of events）。每当视图在创建或解析时，都会为该视图和与该视图中使用的状态数据之间创建一个依赖关系，每当状态的信息发生变化是，有依赖关系的视图则会马上反应出这些变化并重绘。SwiftUI 中提供了诸如 @State ObservedObject EnvironmentObject 等来创建应对不同类型、不同作用域的状态形式。

![类型及作用域](https://cdn.fatbobman.com/state-study-image.jpg)

<center>图片来自于 SwiftUI for Absoloute Beginners</center>

其中@State 只能用于当前视图，并且其对应的数据类型为值类型（如果非要对应引用类型的话则必须在每次赋值时重新创建新的实例才可以）。

```swift
struct DemoView:View{
  @State var name = "肘子"
  var body:some View{
    VStack{
      Text(name)
      Button("改名"){
        self.name = "大肘子"
      }
    }
  }
}
```

通过执行上面代码，我们可以发现两个情况：

1. 通过使用@State，我们可以在未使用 mutating 的情况下修改结构中的值

2. 当状态值发生变化后，视图会自动重绘以反应状态的变化。

## @State 如何工作的 ##

在分析@State 如何工作之前，我们需要先了解几个知识点

### 属性包装器 ###

作为 swift 5.1 的新增功能之一，[属性包装器在管理属性如何存储和定义属性的代码之间添加了一个分割层](https://swiftgg.gitbook.io/swift/swift-jiao-cheng/10_properties#property-wrappers)。通过该特性，可以在对值校验、持久化、编解码等多个方面获得收益。

它的实现也很简单，下面的例子定义了一个包装器用来确保它包装的值始终小于等于 12。如果要求它存储一个更大的数字，它则会存储 12 这个数字。呈现值（投射值）则返回当前包装值是否为偶数

```swift
@propertyWrapper
struct TwelveOrLess {
    private var number: Int
    init() { self.number = 0 }
    var wrappedValue: Int {
        get { return number }
        set { number = min(newValue, 12) }
    }
    var projectedValue: Bool {
        self.number % 2 == 0
    }
}
```

更多的具体资料请查阅 [官方文档](https://swiftgg.gitbook.io/swift/swift-jiao-cheng/10_properties#property-wrappers)

### Binding ###

Binding 是数据的一级引用，在 SwiftUI 中作为数据（状态）双向绑定的桥梁，允许在不拥有数据的情况下对数据进行读写操作。我们可以绑定到多种类型，包括 State ObservedObject 等，甚至还可以绑定到另一个 Binding 上面。Binding 本身就是一个 Getter 和 Setter 的封装。

### State 的定义 ###

```swift
@frozen @propertyWrapper public struct State<Value> : DynamicProperty {

    /// Initialize with the provided initial value.
    public init(wrappedValue value: Value)

    /// Initialize with the provided initial value.
    public init(initialValue value: Value)

    /// The current state value.
    public var wrappedValue: Value { get nonmutating set }

    /// Produces the binding referencing this state value
    public var projectedValue: Binding<Value> { get }
}

```

### DynamicProperty 的定义 ###

```swift
public protocol DynamicProperty {

    /// Called immediately before the view's body() function is
    /// executed, after updating the values of any dynamic properties
    /// stored in `self`.
    mutating func update()
}
```

### 工作原理 ###

前面我们说过 @State 有两个作用

1. 通过使用@State，我们可以在未使用 mutating 的情况下修改结构中的值
2. 当状态值发生变化后，视图会自动重绘以反应状态的变化。

让我们根据上面的知识点来分析如何才能实现以上功能。

- @State 本身包含 @propertyWrapper, 意味着他是一个属性包装器。

- public var wrappedValue: Value { get nonmutating set } 意味着他的包装值并没有保存在本地。

- 它的呈现值（投射值）为 Binding 类型。也就是只是一个管道，对包装数据的引用

- 遵循 DynamicProperty 协议，该协议完成了创建数据（状态）和视图的依赖操作所需接口。现在只暴露了很少的接口，我们暂时无法完全使用它。

在了解了以上几点后，我们来尝试使用自己的代码来构建一个@State 的***半成品***

```swift
@propertyWrapper
struct MyStates:DynamicProperty{
    init(wrappedValue:String){
        UserDefaults.standard.set(wrappedValue, forKey: "myString")
    }
    
    var wrappedValue:String{
        nonmutating set{UserDefaults.standard.set(newValue, forKey: "myString")}
        get{UserDefaults.standard.string(forKey: "myString") ?? ""}
    }
    
    var projectedValue:Binding<String>{
        Binding<String>(
            get:{String(self.wrappedValue)},
            set:{
                self.wrappedValue = $0
        }
        )
    }
    
    func update() {
        print("重绘视图")
    }
}

```

这是一个可以用来包装 String 类型的 State。

我们使用 UserDefault 将数据包装后保存到本地。读取包装数据也是从本地的 UserDefault 里读取的。

为了能够包装其他的类型的数据，同时也为了能够提高存储效率，进一步的可以修改成如下代码：

```swift
@propertyWrapper
struct MyState<Value>:DynamicProperty{
    private var _value:Value
    private var _location:AnyLocation<Value>?
    
    init(wrappedValue:Value){
        self._value = wrappedValue
        self._location = AnyLocation(value: wrappedValue)
    }
    
    var wrappedValue:Value{
        get{ _location?._value.pointee ?? _value}
        nonmutating set{ _location?._value.pointee = newValue}
    }
    
    var projectedValue:Binding<Value>{
        Binding<Value>(
            get:{self.wrappedValue},
            set:{self._location?._value.pointee = $0}
        )
    }
    
    func update() {
        print("重绘视图")
    }
}

class AnyLocation<Value>{
    let _value = UnsafeMutablePointer<Value>.allocate(capacity: 1)
    init(value:Value){
        self._value.pointee = value
    }
}
```

至此，我们完成了这个@MyState 的半成品。

之所以说是半成品，因为尽管我们也遵循了 DynamicProperty 协议，但我们自己编写的这段代码并不能和视图建立依赖。我们可以和使用@State 一样来使用@MyState，同样支持绑定、修改，除了视图不会自动刷新😂。

但至少我们可以大概了解@State 是如何让我们在视图中修改、绑定数据的。

### 什么时候建立的依赖？ ###

我目前无法找到任何关于 SwiftUI 建立依赖的更具体的资料或实现线索。不过我们可以通过下面两段代码来猜测编译器是如何处理数据和视图之间的依赖关联时机的。

```swift
struct MainView: View {
    @State var date: String = Date().description
    var body: some View {
        print("mainView")
        return Form {
            SubView(date: $date)
            Button("修改日期") {
                self.date = Date().description
            }
        }
    }
}

struct SubView: View {
    @Binding var date: String
    var body: some View {
        print("subView")
        return Text(date)
    }
}

```

执行这段代码，我们点击**修改日期** ，我们会得到如下输出

```bash
mainView
subView
...
```

虽然我们在 MainView 中使用@State 声明了 date，并且在 MainView 中修改了 date 的值，但由于我们并没有在 MainView 中使用 date 的值来进行显示或者判断，所以无论我们如何修改 date 值，MainView 都不会重绘。我推测@State 同视图的依赖是在 ViewBuilder 解析时进行的。编译器在解析我们的 body 时，会判断 date 的数据变化是否会对当前视图造成改变。如果没有则不建立依赖关联。

我们可以用另一段代码来分析编译器对 ObservedObject 的反应。

```swift
struct MainView: View {
    @ObservedObject var store = AppStore()
    
    var body: some View {
        print("mainView")
        return Form {
            SubView(date: $store.date)
            Button("修改日期") {
                self.store.date = Date().description
            }
        }
    }
}

struct SubView: View {
    @Binding var date: String
    var body: some View {
        print("subView")
        return Text(date)
    }
}

class AppStore:ObservableObject{
    @Published var date:String = Date().description
}

```

执行后输出如下：

```bash
mainView
subView
mainView
subView
...
```

我们把@State 换成了@ObservedObject ，同样在 MainView 中并没有显示 store.date 的值或者用其来做判断，但是只要我们改变了 store 里的 date 值，MainView 便会刷新重绘。由此可以推测，SwiftUI 对于 ObservedObject 采用了不同的依赖创建时机，只要声明，无论 body 里是否有需要，在 ObservableObject 的 objectWillChange 产生 send 后，都会进行重绘。因此 ObservedObject 很可能是在初始化 MainView 的时候建立的依赖关系。

之所以花气力来判断这个问题，**因为这两种创建依赖的时机的不同会导致 View 更新效率的巨大差异。这个差异也正是我下一篇文章要重点探讨的地方**。

## 打造适合自己的增强型 @State ##

@State 使用属性包装器这个特性来实现了它既定的功能，不过属性包装器还被广泛用于数据验证、副作用等众多领域，我们能否将众多功能属性集于一身？

本文我们自己通过代码打造的@State 半成品并不能创建和视图的依赖，我们如何才能完成这种依赖关联的创建？

@State 不仅可以被用于对属性的包装，同时 State 本身也是一个标准的结构体。它通过内部没有暴露的功能接口完成了同视图的依赖创建。

以下两种使用方式是等效的：

```swift
@State var name = ""
self.name = "肘子"
```

```swift
var name = State<String>(wrappedValue:"")
self.name.wrappedValue = "肘子"
```

因此我们可以通过将 State 作为包装值类型，创建新的属性包装器，来实现我们的最终目标 —— 完整功能、可任意扩展的增强型@State。

```swift
@propertyWrapper
struct MyState<Value>:DynamicProperty{
    typealias Action = (Value) -> Void
    
    private var _value:State<Value>
    private var _toAction:Action?
    
    init(wrappedValue value:Value){
        self._value = State<Value>(wrappedValue: value)
    }
    
    init(wrappedValue value:Value,toAction:@escaping Action){
        self._value = State<Value>(wrappedValue: value)
        self._toAction = toAction
    }
    
    public var wrappedValue: Value {
        get {self._value.wrappedValue}
        nonmutating set {self._value.wrappedValue = newValue}
    }
    
    public var projectedValue: Binding<Value>{
        Binding<Value>(
            get: {self._value.wrappedValue},
            set: {
                self._value.wrappedValue = $0
                self._toAction?($0)
        }
        )
    }
    
    public func update() {
       print("视图重绘")
    }
    
}
```

这段代码仅作为一个例子，可以根据自己的需求任意创建自己所需的功能。

```swift
@MyState var name = "hello"  //实现和标准@State 一样的功能
```

```swift
@MyState<String>(
  wrappedValue: "hello", 
  toAction: {print($0)}
) var name
//在每次赋值后（包括通过 Binding 修改）执行 toAction 定义的函数
```

## 接下来？ ##

在响应式编程开始流行的今天，越来越多的人都在使用单一数据源（Single Souce of Truth）的构架方式进行设计和开发。如何使用@State 这种作用域范围仅限于当前视图的特性？仅从命名来看，苹果给了他最本质的名称——State。State 属于 SwiftUI 架构，ObservableObject 属于 Combine 架构，SwiftUI 明显对于 State 的优化要好于 ObservableObject。如何在满足单一数据源的情况下最大限度享受 SwiftUI 的优化便利？我将在下一篇文章中进行进一步探讨。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
