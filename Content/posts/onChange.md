---
date: 2021-10-29 12:00
description: 从 iOS 14 开始，SwiftUI 为视图提供了 onChange 修饰器，通过使用 onChange，我们可以在视图中对特定的值进行观察，并在其更改时触发操作。本文将对 onChange 的特点、用法、注意事项以及替代方案做以介绍。
tags: SwiftUI
title: 了解 SwiftUI 的 onChange
image: images/onChange.png
---
从 iOS 14 开始，SwiftUI 为视图提供了 onChange 修饰器，通过使用 onChange，我们可以在视图中对特定的值进行观察，并在其更改时触发操作。本文将对 onChange 的特点、用法、注意事项以及替代方案做以介绍。

```responser
id:1
```

## 如何使用 onChange ##

onChange 的定义如下：

```swift
func onChange<V>(of value: V, perform action: @escaping (V) -> Void) -> some View where V : Equatable
```

onChange 在发现特定值发生变化时，将调用闭包中的操作。

```swift
struct OnChangeDemo:View{
    @State var t = 0
    var body: some View{
        Button("change"){
            t += 1
        }
        .onChange(of: t, perform: { value in
            print(value)
        })
    }
}
```

点击 Button，t 将加一，onChange 将对 t 值进行比较，如果值发生改变，将调用闭包打印新值。

在闭包中可以进行副作用操作，或者修改视图中的其他可变内容。

传递到闭包中的值（例如上面的 value）是不可变的，如果需要修改，请直接更改视图中的可变值（t）。

onChange 的闭包是运行在主线程上的，应避免在闭包中执行运行时间长的任务。

## 如何获取被观察值的 OldValue ##

onChange 允许我们通过闭包捕获的方式获取被观察值的旧值（oldValue）。例如：

```swift
struct OldValue: View {
    @State var t = 1
    var body: some View {
        Button("change") {
            t = Int.random(in: 1...5)
        }
        .onChange(of: t) { [t] newValue in
            let oldValue = t
            if newValue % oldValue == 2 {
                print("余值为 2")
            } else {
                print("不满足条件")
            }
        }
    }
}
```

由于闭包中捕获了 t，因此需使用`self.t`方能调用视图中的 t。

对于结构类型，捕获时需使用结构实例，而不能直接捕获结构中的属性，例如：

```swift
struct OldValue1:View{
    @State var data = MyData()
    var body: some View{
        Button("change"){
            data.t = Int.random(in: 1...5)
        }
        .onChange(of: data.t){ [data] newValue in
            let oldValue = data.t
            if newValue % oldValue == 2 {
                print("余值为 2")
            } else {
                print("不满足条件")
            }
        }
    }
}

struct MyData{
    var t = 0
}
```

换成 [data.t] 将提示如下错误：

```bash
Fields may only be captured by assigning to a specific name
```

对于引用类型，捕获时需添加`weak`。

## onChange 可以观察哪些值 ##

任何符合 Equatable 协议的类型都可被 onChange 所观察。对于可选值，只要 Wrapped 符合 Equatable 即可。

通常我们会使用 onChange 来观察@State，@StateObject 或@ObservableObject 包装数据的变化。但在某些特定的场景下，我们也可以用 onChange 来观察并非为视图 Source of truth 的数据。例如：

```swift
struct NonStateDemo: View {
    let store = Store.share
    @State var id = UUID()
    var body: some View {
        VStack {
            Button("refresh") {
                id = UUID()
            }
            .id(id)
            .onChange(of: store.date) { value in
                print(value)
            }
        }
    }
}

class Store {
    var date = Date()
    var cancellables = Set<AnyCancellable>()
    init(){
        Timer.publish(every: 3,  on: .current, in: .common)
            .autoconnect()
            .assign(to: \.date, on: self)
            .store(in: &cancellables)
    }

    static let share = Store()
}
```

Store 并非可以引发视图刷新的元素，通过点击 Button 改变 id 来刷新视图。

本例看起来有些无厘头，但它为揭示 onChange 的特点提供了很好的启示。

## onChange 的特点 ##

在 onChange 推出之际，大多数人将其视为@State 的 didSet 实现。但事实上两者间有很大的差异。

didSet 在**值发生改变**即调用闭包中的操作，无论新值与旧值是否不同。例如

```swift
class MyStore{
    var i = 0{
        didSet {
            print("oldValue:\(oldValue),newValue:\(i)")
        }
    }
}

let store = MyStore()
store.i = 0

//oldValue:0,newValue:0
```

 onChange 有其自身的运行逻辑。

在上节的例子中，尽管 Store 中的 date 每三秒会发生一次改变，但并不会引起视图的重新绘制。通过点击按钮强制重绘视图，onChange 才会被触发。

如果在三秒之内多次点击按钮，控制台并不会打印更多的时间信息。

**被观察值的变化并不会触发 onChange，只有在每次视图重绘时 onChnage 才会触发。onChange 触发后会比较被观察值的变化，只有新旧值不一致时，才会调用 onChange 闭包中的操作。**

## 关于 onChange 的 FAQ ##

### 视图中可以放置多少个 onChange ###

任意多个。不过由于 onChange 的闭包运行在主线程中，因此最好限制 onChange 的使用量，避免影响视图的渲染效率。

### 多个 onChange 的执行顺行 ###

严格按照视图树的渲染顺序，下面的代码中，onChange 的执行顺序为从内到外：

```swift
struct ContentView: View {
    @State var text = ""
    var body: some View {
        VStack {
            Button("Change") {
                text += "1"
            }
            .onChange(of: text) { _ in
                print("TextField1")
            }
            .onChange(of: text) { _ in
                print("TextField2")
            }
        }
        .onChange(of: text, perform: { _ in
            print("VStack")
        })
    }
}

// Output:
// TextField1
// TextField2
// VStack
```

### 多个 onChange 观察同一个值 ###

在一个渲染周期内，观察同一个值的 onChange，**无论顺序与否，获得的被观察值的新旧值均相同**。不会因为更早顺序前的 onChange 对值的内容进行更改而变化。

```swift
struct InOneLoop: View {
    @State var t = 0
    var body: some View {
        VStack {
            Button("change") {
                t += 1 // t = 1
            }
            // onChange1
            .onChange(of: t) { [t] newValue in
                print("onChange1: old:\(t) new:\(newValue)")
                    self.t += 1
            }
            // onChange2
            .onChange(of: t) { [t] newValue in
                print("onChange2 old:\(t) new:\(newValue)")
            }
        }
    }
}
```

输出为：

```bash
render loop
onChange1: old:3 new:4
onChange2 old:3 new:4
render loop
onChange1: old:4 new:5
onChange2 old:4 new:5
render loop
onChange(of: Int) action tried to update multiple times per frame.
```

在每个 loop 循环中，onChange2 的内容并没有因为 onChange1 对 t 进行了修改而变化。

### 为什么 onChange 会报错 ###

在上面的代码中，在输出的最后，我们获得了`onChange(of: Int) action tried to update multiple times per frame.`的错误提示。

这是因为，由于我们在 onChange 中对被观察值进行了修改，而修改将再次刷新视图，从而导致了无限循环。SwiftUI 为了避免 app 锁死而采取的保护机制——强制中断了 onChange 的继续执行。

至于允许的循环次数没有明确的约定，上面例子中由 Button 激发的变化通常会限制在 2 次，而由 onAppear 激发的变化则可能在 6-7 次。

```swift
struct LoopTest: View {
    @State var t = 0
    var body: some View {
        let _ = print("frame")
        VStack {
            Text("\(t)")
                .onChange(of: t) { _ in
                    t += 1
                    print(t)
                }
                .onAppear(perform: { t += 1 })
        }
    }
}
```

输出：

```bash
 frame
 2
 frame
 3
 frame
 4
 frame
 5
 frame
 6
 frame
 7
 frame
 onChange(of: Int) action tried to update multiple times per frame.
```

因此我们需要尽量避免在 onChange 中对被观察值进行修改，如确有必要，请使用条件判断语句来限制更改次数，保证程序按预期执行。

## onChange 的替代方案 ##

本节中我们将介绍几个同 onChange 类似的实现，它们同 onChange 的行为并不完全一样，有各自的特点和合适的场景。

### task(id:) ###

SwiftUI 3.0 中新增了 task 修饰器，task 将在视图出现时以异步的方式运行闭包中的内容，同时在 id 值发生变化时，重启任务。

在 task 闭包中的任务单元足够简单时，其表现同 onChange 类似，相当于 onAppear + onChange 的组合。

```swift
struct AsyncTest: View {
    @State var t: CGFloat = 0
    var body: some View {
        let _ = print("frame")
        VStack {
            Text("\(t)")
                .task(id: t) {
                    t += 1
                    print(t)
                }
        }
    }
}
```

输出：

```bash
frame
1.0
frame
2.0
...
```

但有一点需要特别注意，由于 task 的闭包是异步运行的，理论上其并不会对视图的渲染造成影响，因此 SwiftUI 将不会限制它的执行次数。本例中，task 的闭包中的任务将不断运行，Text 中的内容也将不断变化（如果将 task 换成 onChange 则会被 SwiftUI 自动中断）。

### Combine 版本的 onChange ###

在 onChange 没有推出之前，多数人会利用 Combine 框架来实现类似 onChange 的效果。

```swift
import Combine
struct CombineVersion: View {
    @State var t = 0
    var body: some View {
        VStack {
            Button("change") {
                t += 1
            }
        }
        .onAppearAndOnChange(of: t, perform: { value in
            print(value)
        })
    }
}

public extension View {
    func onAppearAndOnChange<V>(of value: V, perform action: @escaping (_ newValue: V) -> Void) -> some View where V: Equatable {
        onReceive(Just(value), perform: action)
    }
}
```

它的行为类似 onAppear + onChange 的组合。最大的不同是，此种方案并不会比较被观察值是否发生改变（新旧值不一样）。

```swift
struct CombineVersion: View {
    @State var t = 0
    @State var n = 0
    var body: some View {
        VStack {
            Text("\(n)")
            Button("change n"){
                n += 1
                t += 0
            }
        }
        .onAppearAndOnChange(of: t, perform: { value in
            print("combine \(t)")
        })
        .onChange(of: t){ value in
            print("onChange \(t)")
        }
    }
}
```

onChange 的闭包因为 t 的内容没有发生变化将不会被调用，而 onAppearAndOnChange 的闭包将在每次 t 赋值时均被调用。

有的时候，这种行为恰是我们所需的。

### Binding 版本的 onChange ###

此种方式只能针对 Binding 类型的数据，通过在 Binding 的 Set 中添加一层逻辑，实现对内容变化的响应。

```swift
extension Binding {
    func didSet(_ didSet: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(get: { wrappedValue },
                set: { newValue in
                    self.wrappedValue = newValue
                    didSet(newValue)
                })
    }
}

struct BindingVersion2: View {
    @State var text = ""
    var body: some View {
        Form {
            TextField("text:", text: $text.didSet { print($0) })
        }
    }
}
```

可能你会觉得多此一举，完全可以使用 onChange 来实现，但采用 Binding 的方式让我们有了在**数据修改前**进行判断操作的可能，使用得当将极大地减少视图的刷新。

例如，我们还可以对新数据进行提前判断以决定是否更改原值：

```swift
extension Binding {
    func conditionSet(_ condition: @escaping (Value) -> Bool) -> Binding<Value> {
        Binding(get: { wrappedValue },
                set: { newValue in
                    if condition(newValue) {
                        self.wrappedValue = newValue
                    }
                })
    }
}
```

请注意，此种方式并不能同支持 Binding 的系统控件很好的配合使用，因为系统控件并不会因为我们限制了数值的修改而产生对应的效果（系统控件中还保留了一套自己的数据，除非强制刷新视图，否则并不会保证同外部的数据完全同步）。例如下面的代码，表现同你预期的行为会有出入。

```swift
struct BindingVersion3: View {
    @State var text = ""
    var body: some View {
        Form {
            Text(text)
            TextField("text:", text: $text.conditionSet { text in
                return text.count < 5
            })
        }
    }
}
```

## 总结 ##

onChange 为我们在视图中进行逻辑处理提供了便利，了解它的特点与限制，选择合适的场景使用它。在必要的情况下，将逻辑处理与视图分离，以保证视图的渲染效率。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。

