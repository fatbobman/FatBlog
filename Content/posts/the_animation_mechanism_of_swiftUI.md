---
date: 2022-05-10 08:20
description: 大多初学者都会在第一时间惊叹于 SwiftUI 轻松实现各种动画效果的能力，但经过一段时间的使用后，他们会发现 SwiftUI 的动画并非像表面上看起来那样容易驾驭。开发者经常需要面对：如何动、怎么动、什么能动、为什么不动、为什么这么动、如何不让它动等等困扰。对 SwiftUI 的动画处理逻辑了解的不够深入是造成上述困扰的主要原因。本文将尝试对 SwiftUI 的动画机制做以介绍，以帮助大家更好地学习、掌握 SwiftUI 的动画，制作出满意的交互效果。
tags: SwiftUI
title:  SwiftUI 的动画机制
image: images/animationMechanismOfSwiftUI.png
---
大多初学者都会在第一时间惊叹于 SwiftUI 轻松实现各种动画效果的能力，但经过一段时间的使用后，他们会发现 SwiftUI 的动画并非像表面上看起来那样容易驾驭。开发者经常需要面对：如何动、怎么动、什么能动、为什么不动、为什么这么动、如何不让它动等等困扰。对 SwiftUI 的动画处理逻辑了解的不够深入是造成上述困扰的主要原因。本文将尝试对 SwiftUI 的动画机制做以介绍，以帮助大家更好地学习、掌握 SwiftUI 的动画，制作出满意的交互效果。

> 阅读本文前，读者最好已拥有在 SwiftUI 中使用动画编程的经历，或对 SwiftUI 动画的基本使用方法有一定的了解。可以在 [此处获取本文的全部代码](https://github.com/fatbobman/BlogCodes/tree/main/Animation)

## SwiftUI 的动画是什么？

SwiftUI 采用了声明式语法来描述不同状态下的 UI 呈现，动画亦是如此。官方文档将 SwiftUI 的动画（Animations）定义为：创建从一个状态到另一个状态的平滑过渡。

在 SwiftUI 中，我们不能命令某个视图从一个位置移动到另一个位置，为了实现上述效果，我们需要声明该视图在状态 A 时所处的位置以及状态 B 时所处的位置，当由状态由 A 转到 B 时，SwiftUI 将使用指定的算法函数，为特定部件（如果该部件是可动画的话）提供用于生成平滑过渡而需的数据。

在 SwiftUI 中，实现一个动画需要以下三个要素：

* 一个时序曲线算法函数
* 将状态（特定依赖项）同该时序曲线函数相关联的声明
* 一个依赖于该状态（特定依赖项）的可动画部件

![animationThreeElements](https://cdn.fatbobman.com/animationThreeElements-1627470.png)

```responser
id:1
```

## 令人疑惑的 Animation 命名

### 时序曲线函数

SwiftUI 为时序曲线算法函数取了一个令人困惑的名字 —— Animation。或许用时序曲线或动画曲线来命名会更加贴切（譬如 Core Animation 中的 CAMediaTimingFunction）。

该函数将动画的节奏定义为一条计时曲线，将起点数据沿计时曲线变换为终点数据。

```swift
Text("Hello world")
    .animation(.linear(duration: 0.3), value: startAnimation)
    .opacity(startAnimation ? 0 : 1)
```

时序曲线函数（ Animation ）`linear(duration:0.3)` 意味着在 0.3 秒中对数据进行线性的转换（本例中为从 0 到 1）。

![linear_value_sheet](https://cdn.fatbobman.com/linear_value_sheet.png)

![image-20220504111032123](https://cdn.fatbobman.com/image-20220504111032123.png)

时序曲线函数（ Animation ）`easeInOut(duration:0.3)`对应的数值变化：

![easeInOut_value_sheet](https://cdn.fatbobman.com/easeInOut_value_sheet.png)

![image-20220504110821144](https://cdn.fatbobman.com/image-20220504110821144.png)

时序曲线函数的工作仅为对数据进行插值变换，至于如何利用插值数据则是可动画部件的工作。

### VectorArithmetic

只有符合 VectorArithmetic 协议的数据类型方可被应用于时序曲线函数。SwiftUI 为我们提供了几种开箱即用的数据类型，例如：Float、Double、CGFloat 等。

```swift
Text("Hello world")
    .animation(.linear(duration: 0.3), value: startAnimation)
    .opacity(startAnimation ? 0 : 1) // Double 类型，符合 VectorArithmetic 协议
```

其他的数据类型通过实现 VectorArithmetic 协议的要求，也可以为可动画部件提供动画数据。

Majid 的 [The magic of Animatable values in SwiftUI](https://swiftwithmajid.com/2020/06/17/the-magic-of-animatable-values-in-swiftui/) 一文中，展示了如何让自定义类型满足 VectorArithmetic 协议。

## 将时序曲线函数与状态关联

只有通过某种形式将时序曲线函数（Animation）与某个（或多个）依赖项关联后，SwiftUI 才会在状态（ 被关联的依赖项 ）变化时为动画生成插值数据。关联的方式有：视图修饰符 `animation` 或全局函数 `withAnimation`  。

SwiftUI 的动画异常（与开发者的预期不符）很多情况下均与错误的关联方式、错误关联位置等因素有关。

### 将修饰符 animation 放置在正确的位置上

代码一：

```swift
@State var animated = false

VStack {
    Text("Hello world")
        .offset(x: animated ? 200 : 0)
        .animation(.easeInOut, value: animated) // animation 的作用域为当前视图层次及其子视图

    Text("Fat")
        .offset(x: animated ? 200 : 0)
}
```

![single_animation_2022-05-04_14.08.25.2022-05-04 14_09_34](https://cdn.fatbobman.com/single_animation_2022-05-04_14.08.25.2022-05-04%2014_09_34.gif)

代码二：

```swift
VStack {
    Text("Hello world")
        .offset(x: animated ? 200 : 0)

    Text("Fat")
        .offset(x: animated ? 200 : 0)
}
.animation(.easeInOut, value: animated)
```

![both_animation_2022-05-04_14.05.54.2022-05-04 14_06_58](https://cdn.fatbobman.com/both_animation_2022-05-04_14.05.54.2022-05-04%2014_06_58.gif)

上述两段代码，因为 `animation` 在代码中的位置不同，导致了在其所关联的依赖项（ `animated`）发生改变时，动画的行为产生了差异。在代码一中，只有 `Hello world` 会产生平滑的动画；代码二中 `Hello world` 和 `Fat` 两者都将产生平滑的动画。

同所有 SwiftUI 的视图修饰符一样，在代码中所处的位置决定了修饰符的作用对象和范围。 `animation` 的作用对象仅限于它所在视图层次及该层次的子节点。

上面两段代码没有对错之分。在某些场景下，我们可能需要在某一个依赖项（状态）发生改变时，所有依赖于该项目的内容都产生平滑动画（例如代码二），在其他场景中，可能又仅需部分内容产生平滑动画（例如代码一），通过调整 `animation` 的位置，就可以获得想要的效果。

### 只使用指定特定依赖项的 animation 版本

SwiftUI 提供了两个版本的 `animation` 修饰符：

```swift
// 版本一，不指定特定依赖项
func animation(_ animation: Animation?) -> some View

// 版本二，指定特定的依赖项，上节代码中采用的方式
func animation<V>(_ animation: Animation?, value: V) -> some View where V : Equatable
```

第一种方式在 SwiftUI 3.0 中已被标注弃用，它是在老版本 SwiftUI 中导致动画异常的元凶之一。此版本的 `animation` 会与所在视图层次和该视图层次的子节点的**所有依赖项**进行状态关联。视图和它子节点中的任何依赖项发生变化，都将满足启用动画插值计算的条件，并动画数据传递给作用范围内（视图和它子节点）的所有可动画部件。

比如，由于下面代码中的 `animation` 没指定特定的依赖项，因此，点击按钮后，位置与颜色都会产生平滑动画。

```swift
struct Demo2: View {
    @State var x: CGFloat = 0
    @State var red = false
    var body: some View {
        VStack {
            Spacer()
            Circle()
                .fill(red ? .red : .blue)
                .frame(width: 30, height: 30)
                .offset(x: x)
                .animation(.easeInOut(duration: 1)) // 同时关联了 x 和 red 两个依赖项
//                .animation(.easeInOut(duration: 1), value: x)  // 推荐采用分别关联的方式
//                .animation(.easeInOut(duration: 1), value: red)

            Spacer()
            Button("Animate") {  // 闭包中改变了两个依赖项的值
                if x == 0 {
                    x = 100
                } else {
                    x = 0
                }
                red.toggle()
            }
        }
        .frame(width: 500, height: 300)
    }
}
```

通过使用 `animation<V>(_ animation: Animation?, value: V)` 版本，我们可以只让位置或颜色两者之一产生平滑动画。在一次性修改多个依赖项时，`animation(_ animation: Animation?)` 极易产生不必要的动画，这也是它被废弃的主要原因。

在本例中，使用 `withAnimation` 也可以达到同样的效果，通过在 `withAnimation` 的闭包中修改特定的依赖项从而实现单独的动画控制。

```swift
struct Demo2: View {
    @State var x: CGFloat = 0
    @State var red = false
    var body: some View {
        VStack {
            Spacer()

            Circle()
                .fill(red ? .red : .blue)
                .frame(width: 30, height: 30)
                .offset(x: x)
            Spacer()
            Button("Animate") {
                if x == 0 {
                    x = 100
                } else {
                    x = 0
                }
                withAnimation(.easeInOut(duration: 1)) { // 只有颜色会平滑过渡
                    red.toggle()
                }
            }
        }
        .frame(width: 500, height: 300)
    }
}
```

### 为不同的依赖项关联不同的时序曲线函数

细心的朋友可能会发现，在上文中，当对时序曲线函数进行关联时，我使用的词语是“依赖项”而不是“状态”，这是因为视图的状态是它拥有的全部依赖项的总体呈现。`witAnimation` 允许我们为同一个可动画部件的不同的依赖项设定不同的时序曲线函数。

```swift
struct Demo4: View {
    @State var x: CGFloat = 0
    @State var y: CGFloat = 0
    var body: some View {
        VStack {
            Spacer()
            Circle()
                .fill(.orange)
                .frame(width: 30, height: 30)
                .offset(x: x, y: y) // x、y 分别关联了不同的时序曲线函数
            Spacer()
            Button("Animate") {
                withAnimation(.linear) { 
                    if x == 0 { x = 100 } else { x = 0 }
                }
                withAnimation(.easeInOut) {
                    if y == 0 { y = 100 } else { y = 0 }
                }
            }
        }
        .frame(width: 500, height: 500)
    }
}
```

![dual_timing_function_2022-05-04_15.25.59.2022-05-04 15_27_18](https://cdn.fatbobman.com/dual_timing_function_2022-05-04_15.25.59.2022-05-04%2015_27_18.gif)

因为 `offset(x: x, y: y)` 中的 x 和 y 通过 `withAnimation` 关联了不同的时序曲线函数，因此在动画的过程中，横轴和纵轴的运动方式是不同的（ x 是线性的，y 是缓进出的）。

> 目前 `animation<V>(_ animation: Animation?, value: V)` 尚不支持对同一个可动画部件的不同的依赖项关联不同的时序曲线函数

除了可以关联种类不同的时序曲线函数外，SwiftUI 还允许关联的时序曲线函数拥有不同的作用时长。对同一个动画部件的不同依赖项关联不同时长函数时（ duration 不一致或启用了 repeatForever ），插值的计算逻辑将会变得更加复杂，不同的组合会有不同的结果，需慎重使用。

```swift
Button("Animate") {
    withAnimation(.linear) {
        if x == 0 { x = 100 } else { x = 0 }
    }
    withAnimation(.easeInOut(duration: 1.5)) {
        if y == 0 { y = 100 } else { y = 0 }
    }
}
```

![different_duration_2022-05-09_12.44.24.2022-05-09 12_45_01](https://cdn.fatbobman.com/different_duration_2022-05-09_12.44.24.2022-05-09%2012_45_01.gif)

### 谨慎使用 withAnimation

在 SwiftUI 没有提供 `animation<V>(_ animation: Animation?, value: V)` （与特定依赖项关联）修饰符时，`withAnimation` 相较于 `animation(_ animation: Animation?)` 或许是更好的选择，至少它可以明确的将特定的依赖项与时序曲线函数关联起来。

不过现在除非有必要（例如需要关联不同的时序曲线函数），应优先考虑使用 `animation<V>(_ animation: Animation?, value: V)` 。这是因为尽管 `withAnimation` 可以指定依赖项，但它缺乏 `animation(_ animation: Animation?, value: V)` 的代码位置维度， `withAnimation` 会影响显示中的所有与该依赖项关联的视图，比如，很难用 `withAnimation` 实现代码一的效果。

另外需要注意的是，使用 `withAnimation` 时，必须明确地让依赖项出现在闭包中，否则 `withAnimation` 将不起作用。例如：

```swift
struct Demo3: View {
    @State var items = (0...3).map { $0 }
    var body: some View {
        VStack {
            Button("In withAnimation") {
                withAnimation(.easeInOut) {
                    items.append(Int.random(in: 0...1000))
                }
            }
            Button("Not in withAnimation") { // 使用 Array 的扩展方法
                items.appendWithAnimation(Int.random(in: 0...1000), .easeInOut)
            }
            List {
                ForEach(items, id: \.self) { item in
                    Text("\(item)")
                }
            }
            .frame(width: 500, height: 300)
        }
    }
}

extension Array {
    mutating func appendWithAnimation(_ newElement: Element, _ animation: Animation?) {
        withAnimation(animation) {
            append(newElement)
        }
    }
}
```

虽然，在 Array 的扩展方法 `appendWithAnimation` 中使用了 `withAnimation` ，但由于 `withAnimation` 的闭包中没有包含特定的依赖项，因此并不会激活 SwiftUI 的动画机制。

## 让你的视图元素可动画（Animatable）

将时序曲线函数与特定的依赖进行关联，仅是完成了设置动画开启条件（特定依赖项发生改变）和指定插值算法这一步骤。至于如何利用这些动画数据（插值数据）生成动画，则是由与特定依赖项关联的可动画部件决定的。

通过遵循 Animatable 协议，可以让 View 或 ViewModifier 具备获得动画数据的能力（ AnimatableModifier 已被弃用）。很多 SwiftUI 的官方部件都已预先满足了该协议，例如：`offset`、`frame`、`opacity`、`fill` 等。

Animatable 协议的要求非常简单，只需实现一个计算属性 `animatableData`

```swift
public protocol Animatable {

    /// The type defining the data to animate.
    associatedtype AnimatableData : VectorArithmetic

    /// The data to animate.
    var animatableData: Self.AnimatableData { get set }
}
```

请注意，协议中规定 `animatableData` 的类型必须满足 VectorArithmetic 协议，这是因为时序曲线函数只能对满足 VectorArithmetic 协议的类型进行插值计算。

当可动画部件关联的依赖项发生变化时，SwiftUI 将通过指定的时序曲线函数进行插值计算，并持续调用与该依赖项关联的可动画部件的 `animatableData` 属性。

```swift
struct AnimationDataMonitorView: View, Animatable {
    static var timestamp = Date()
    var number: Double
    var animatableData: Double { // SwiftUI 在渲染时发现该视图为 Animatable，则会在状态已改变后，依据时序曲线函数提供的值持续调用 animableData
        get { number }
        set { number = newValue }
    }

    var body: some View {
        let duration = Date().timeIntervalSince(Self.timestamp).formatted(.number.precision(.fractionLength(2)))
        let currentNumber = number.formatted(.number.precision(.fractionLength(2)))
        let _ = print(duration, currentNumber, separator: ",")

        Text(number, format: .number.precision(.fractionLength(3)))
    }
}

struct Demo: View {
    @State var startAnimation = false
    var body: some View {
        VStack {
            AnimationDataMonitorView(number: startAnimation ? 1 : 0) // 声明两种状态下的形态
                .animation(.linear(duration: 0.3), value: startAnimation) // 关联依赖项和时序曲线函数
            Button("Show Data") {
                AnimationDataMonitorView.timestamp = Date() 
                startAnimation.toggle() // 改变依赖项
            }
        }
        .frame(width: 300, height: 300)
    }
}
```

上面这段代码清晰的展现了这个过程。

声明过程：

* 指定时序曲线函数 —— linear
* 将依赖项 startAnimation 与 linear 相关联
* AnimationDataMonitorView （可动画部件）符合 Animatable 且依赖了 startAnimation

动画处理过程：

* 点击按钮改变依赖项 startAnimation 的值
* SwiftUI 会立即完成对 startAnimation 值的改变（依赖值的改变发生在动画开始前，比如本例中，true 将立刻变成 false ）
* SwiftUI 发现 AnimationDataMonitorView 符合 Animatable 协议，使用 linear 进行插值计算
* SwiftUI 将按照设备的刷新率（ 60 fps/sec 或 120 fps/sec）持续使用 linear 的计算结果设置 AnimationDataMonitorView 的 animatableData 属性，并对 AnimationDataMonitorView 的 body 求值、渲染

通过设置在 body 中的打印语句，我们可以看到不同时间节点的的插值数据：

![animatable_data_demo_2022-05-04_17.32.01.2022-05-04 17_34_12](https://cdn.fatbobman.com/animatable_data_demo_2022-05-04_17.32.01.2022-05-04%2017_34_12.gif)

> 上文中的时序曲线函数数值变化表便由此代码生成

推荐几篇介绍 Animatable 用法的博文：

[Advanced SwiftUI Animations – Part 1: Paths](https://swiftui-lab.com/swiftui-animations-part1/)

[AnimatableModifier in SwiftUI](https://swiftwithmajid.com/2021/01/11/animatablemodifier-in-swiftui/)

当可动画元素有多个可变依赖项时，需将 `animatableData` 设置为 AnimatablePair 类型，以便 SwiftUI 可以传递分属于不同依赖项的动画插值数据。

> AnimatablePair 类型符合 VectorArithmetic 协议，同时要求其包装的数值类型也需符合 VectorArithmetic 协议

下面的代码演示了 AnimatablePair 的使用方法，以及如何查看两个不同的时序曲线函数插值数据：

```swift
struct AnimationDataMonitorView: View, Animatable {
    static var timestamp = Date()
    var number1: Double // 会发生变化
    let prefix: String
    var number2: Double // 会发生变化

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(number1, number2) }
        set {
            number1 = newValue.first
            number2 = newValue.second
        }
    }

    var body: some View {
        let duration = Date().timeIntervalSince(Self.timestamp).formatted(.number.precision(.fractionLength(2)))
        let currentNumber1 = number1.formatted(.number.precision(.fractionLength(2)))
        let currentNumber2 = number2.formatted(.number.precision(.fractionLength(2)))
        let _ = print(duration, currentNumber1, currentNumber2, separator: ",")

        HStack {
            Text(prefix)
                .foregroundColor(.green)
            Text(number1, format: .number.precision(.fractionLength(3)))
                .foregroundColor(.red)
            Text(number2, format: .number.precision(.fractionLength(3)))
                .foregroundColor(.blue)
        }
    }
}

struct Demo: View {
    @State var startNumber1 = false
    @State var startNumber2 = false
    var body: some View {
        VStack {
            AnimationDataMonitorView(
                number1: startNumber1 ? 1 : 0,
                prefix: "Hi:",
                number2: startNumber2 ? 1 : 0
            )
            Button("Animate") {
                AnimationDataMonitorView.timestamp = Date()
                withAnimation(.linear) {
                    startNumber1.toggle()
                }
                withAnimation(.easeInOut) {
                    startNumber2.toggle()
                }
            }
        }
        .frame(width: 300, height: 300)
    }
}
```

![animatable_dual_data_demo_2022-05-04_18.17.39.2022-05-04 18_18_51](https://cdn.fatbobman.com/animatable_dual_data_demo_2022-05-04_18.17.39.2022-05-04%2018_18_51.gif)

SwiftUI 在传递插值数据时非常聪明，只会将发生变化的依赖项通过 `animatableData` 传递给可动画元素。比如在上面的代码中，参数 `prefix` 不发生变化，因此在合成 `AnimatablePair` 数据时会自动跳过，只合成 `number1` 和 `number2`。

当需要传递更多的参数时，可嵌套使用 AnimatablePair 类型，如：

```swift
AnimatablePair<CGFloat, AnimatablePair<Float, AnimatablePair<Double, CGFloat>>>
// newValue.second.second.first.
```

## 使用 Transaction 进行更精细的控制

用 SwiftUI 的官方语言来描述【将时序曲线函数与状态关联的过程】应该是：为视图声明事务（ Transaction）。事务提供了更加灵活的曲线函数类型设置方式以及动画开关和临时状态标识。

无论是修饰符 `animation` 还是全局函数 `withAnimation` ，实际上都是在视图中声明 Transaction 的快捷方法，内部分别对应着 `transaction` 和 `withTransaction`。

比如，`withAnimation` 实际上对应的是：

```swift
withAnimation(.easeInOut){
    show.toggle()
}
// 对应为
let transaction = Transaction(animation: .easeInOut)
withTransaction(transaction) {
    show.toggle()
}
```

`animation(_ animation: Animation?)` 同样是通过 Transaction 来实现的：

```swift
// 代码来自于 swiftinterface
extension SwiftUI.View {
    @_disfavoredOverload @inlinable public func animation(_ animation: SwiftUI.Animation?) -> some SwiftUI.View {
        return transaction { t in
            if !t.disablesAnimations {
                t.animation = animation
            }
        }
    }
}
```

Transaction 提供的 disablesAnimations 和 isContinuous 可以帮助开发者更好的进行动画控制，例如：

* 动态选择需要关联的时序曲线函数

```swift
Text("Hi")
    .offset(x: animated ? 100 : 0)
    .transaction {
        if position < 0 || position > 100 {
            $0.animation = .easeInOut
        } else {
            $0.animation = .linear
        }
    }
```

> `transaction` 的作用范围与关联的依赖项与不指定特定依赖项版本的 `animation` 是一样的，**它不具备与特定依赖项关联的能力**。

```swift
// 并不表示仅与 x 关联，作用域范围内的其他依赖项发生变化，同样会产生动画
.transaction {
    if x == 0 {
        $0.animation = .linear
    } else {
        $0.animation = nil
    }
}

// 相当于
.animation(x == 0 ? .linear : nil)
```

* disablesAnimations

```swift
struct Demo: View {
    @State var position: CGFloat = 40
    var body: some View {
        VStack {
            Text("Hi")
                .offset(x: position, y: position)
                .animation(.easeInOut, value: position)

            Slider(value: $position, in: 0...150)
            Button("Animate") {
                var transaction = Transaction() // 没有指定时序曲线函数，将保留原有设置（本例为 easeInOut）
                if position < 100 { transaction.disablesAnimations = true }
                withTransaction(transaction) { // withTransaction 可以禁止原有事务的时序曲线函数（由 animation 相关联），但无法屏蔽由 transaction 关联的时序曲线函数
                    position = 0
                }
            }
        }
        .frame(width: 400, height: 500)
    }
}
```

> `withTransaction` （通过设置 disablesAnimations 来屏蔽动画）+ `animation<V>(_ animation: Animation?, value: V)` 是比较成熟的搭配。

* isContinuous

```swift
struct Demo: View {
    @GestureState var position: CGPoint = .zero
    var body: some View {
        VStack {
            Circle()
                .fill(.orange)
                .frame(width: 30, height: 50)
                .offset(x: position.x, y: position.y)
                .transaction {
                    if $0.isContinuous {
                        $0.animation = nil // 拖动时，不设置时序曲线函数
                    } else {
                        $0.animation = .easeInOut(duration: 1)
                    }
                }
                .gesture(
                    DragGesture()
                        .updating($position, body: { current, state, transaction in
                            state = .init(x: current.translation.width, y: current.translation.height)
                            transaction.isContinuous = true // 拖动时，设置标识
                        })
                )
        }
        .frame(width: 400, height: 500)
    }
}
```

![isContinuous_2022-05-06 11.26.20.2022-05-06 11_27_42](https://cdn.fatbobman.com/isContinuous_2022-05-06%2011.26.20.2022-05-06%2011_27_42.gif)

> 官方文档中表示，部分控件如 Slider 会在拖动中自动设置 isContinuous ，但实测同描述并不相符。但我们可以自己在代码中利用它来设置临时状态。

另外，在某些场景下，可以通过 Transaction 来获取或设置有关动画的信息，如：

* UIViewRepresentableContext
* AsyncImage
* GestureState
* Binding 等

比如，为 Binding 设置 Transaction ：

```swift
struct Demo: View {
    @State var animated = false
    let animation: Animation?

    var animatedBinding: Binding<Bool> { // 生成包含指定 Transaction 的 Binding 类型
        let transaction = Transaction(animation: animation)
        return $animated.transaction(transaction)
    }

    var body: some View {
        VStack {
            Text("Hi")
                .offset(x: animated ? 100 : 0)

            Toggle("Animated", isOn: animatedBinding) // 点击时会自动产生动画效果
        }
        .frame(width: 400, height: 500)
    }
}

PlaygroundPage.current.setLiveView(Demo(animation: .easeInOut))
```

![binding_transaction_2022-05-06_11.33.10.2022-05-06 11_34_38](https://cdn.fatbobman.com/binding_transaction_2022-05-06_11.33.10.2022-05-06%2011_34_38.gif)

```responser
id:1
```

## 更多有关时序曲线函数与状态关联的注意事项

* SwiftUI 只会使用与可动画部件位置最近的关联（时序曲线函数和依赖）声明。

```swift
Circle()
    .fill(red ? .red : .blue)
    .animation(.easeInOut(duration: 1), value: red)  // 使用它
    .animation(.linear(duration: 3), value: red)

```

* withAnimation（ withTransaction ）指定的时序曲线函数并不能更改 animation 中关联的函数

```swift
Circle()
    .fill(red ? .red : .blue)
    .animation(.easeInOut(duration: 1), value: red)  // 使用它

Button("Change red"){
    withAnimation(.linear(duration:3)){  // 作用域最大，意味着距离动画部件最远
        red.toggle()
    }
}
```

* animation 和 withAnimation 应该二选一

* withTransaction 可以屏蔽 animation 关联的时序曲线函数

  通过设置 disablesAnimations 可以禁用事务中原有的时序曲线函数（不可更改），详情见上节

* 采取恰当的动态设置时序曲线函数的方式

```swift
// 方式一，与特定依赖关联，在仅有两种情况时比较适用
.animation(red ? .linear : .easeIn , value: red) 

// 方式二， 可以处理更多的逻辑，但不与特定依赖关联
.transaction{
    switch status{
        case .one:
            $0.animation = .linear
        case .two:
            $0.animation = .easeIn
        case .three:
            $0.animation = nil
    }
}

// 方式三，支持复杂逻辑，且与特定状态关联
var animation:Animation?{
    // 即使闭包中出现多个不同的依赖项，也不会影响 animation 仅与指定的依赖相关联的特性
    switch status{
        case .one:
            $0.animation = .linear
        case .two:
            $0.animation = .easeIn
        case .three:
            $0.animation = nil
    }
}

.animation(animation , value: status)

// 方式四，作用域大
var animation:Animation?{
    switch status{
        case .one:
            $0.animation = .linear
        case .two:
            $0.animation = .easeIn
        case .three:
            $0.animation = nil
    }
}

withAnimation(animation){
    ...
}

// 方式五，作用域大
var animation:Animation?{
    switch status{
        case .one:
            $0.animation = .linear
        case .two:
            $0.animation = .easeIn
        case .three:
            $0.animation = nil
    }
}
var transaction = Transaction(animation:animation)
withTransaction(transaction){
    ...
}

// 等等
```

## 转场（ Transition ）

### 转场是什么

SwiftUI 的转场类型（ AnyTransition ）是对可动画部件的再度包装。当状态的改变导致**视图树的分支**发生变化时，SwiftUI 将使用其包裹的可动画部件对视图进行动画处理。

使用转场同样需要满足 SwiftUI 动画的三要素。

```swift
struct TransitionDemo: View {
    @State var show = true
    var body: some View {
        VStack {
            Spacer()
            Text("Hello")
            if show {
                Text("World")
                    .transition(.slide) // 可动画部件（包装在其中）
            }
            Spacer()
            Button(show ? "Hide" : "Show") {
                show.toggle() 
            }
        }
        .animation(.easeInOut(duration:3), value: show) // 创建关联依赖、设定时序曲线函数
        .frame(width: 300, height: 300)
    }
}
```

因此，同所有的 SwiftUI 动画元素一样，转场也支持可中断动画。比如，在出场动画进行中时，将状态 show 恢复成 true ，SwiftUI 将会保留当前的分支状态（不会重新创建视图，参见本文附带的范例）。

### 自定义转场

在 SwiftUI 中实现自定义转场并不困难，除非需要创建炫酷的视觉效果，大多数情况下都可以通过使用 SwiftUI 已提供的可动画部件组合而成。

```swift
struct MyTransition: ViewModifier { // 自定义转场的包装对象要求符合 ViewModifier 协议
    let rotation: Angle
    func body(content: Content) -> some View {
        content
            .rotationEffect(rotation) // 可动画部件
    }
}

extension AnyTransition {
    static var rotation: AnyTransition {
        AnyTransition.modifier(
            active: MyTransition(rotation: .degrees(360)),
            identity: MyTransition(rotation: .zero)
        )
    }
}

struct CustomTransitionDemo: View {
    @State var show = true
    var body: some View {
        VStack {
            VStack {
                Spacer()
                Text("Hello")
                if show {
                    Text("World")
                        .transition(.rotation.combined(with: .opacity))
                }
                Spacer()
            }
            .animation(.easeInOut(duration: 2), value: show) // 在这里声明，Button 的文字将没有动画效果
            Button(show ? "Hide" : "Show") {
                show.toggle()
            }
        }
//        .animation(.easeInOut(duration: 2), value: show) // 如果在这里声明，对 Button 的文字同样有影响，结果如下图
        .frame(width: 300, height: 300)
        .onChange(of: show) {
            print($0)
        }
    }
}
```

![custom_transition_2022-05-04_19.55.51.2022-05-04 19_56_55](https://cdn.fatbobman.com/custom_transition_2022-05-04_19.55.51.2022-05-04%2019_56_55.gif)

虽然 MyTransition 表面上并不符合 Animatable 协议，但其中的 `rotationEffect` （可动画 ViewModifier ）帮助我们实现了动画效果。

另外，我们也可以使用符合 Animatable 的 GeometryEffect（ 符合 ViewModifier 和 Animatable ）来创建复杂的转场效果。

更炫酷的转场定制方法请阅读 Javier 的文章 [Advanced SwiftUI Transitions](https://swiftui-lab.com/advanced-transitions/) 。

## 状态、视图标识、动画

既然 SwiftUI 的动画是创建从一个状态到另一个状态的平滑过渡，那么我们必须对状态（依赖项）的改变可能导致的结果有正确的认识。

SwiftUI 对视图采用两种标识方式：结构性标识和显式标识。对于动画来讲，采用不同的标识方式所需注意的点不太一样。

### 结构性标识

下面两段代码尽管都是采用了结构性视图标识（ 以所在的视图层次位置和类型进行标识 ），但它们的意图是完全不同的。

```swift
// 代码一
if show {
    Text("Hello")  // 分支一
} else {
    Text("Hello")  // 分支二
      .offset(y : 100)
}

// 代码二
Text("Hello")
    .offset(y : show ? 100 : 0)  // 同一视图两种状态声明
```

代码一描述了在依赖项 show 发生变化时，SwiftUI 将在分支一和分支二中进行切换。此种情况下，我们可以通过 transition 来分别设定分支一和分支二的进出场动画（ 也可以在分支选择的外侧统一设定 Transition ），但无法要求分支一移动到分支二上面。

```swift
// 代码一
VStack{  //  使用布局容器
    if !show {
        Text("Hello")  // 分支一
           .transition(.scale)
    } else {
        Text("Hello")  // 分支二
          .offset(y : 100)
          .transition(.move(edge: .bottom))
    }
}
.animation(.easeIn, value: show)
```

![status_for_transition_2022-05-09_15.11.26.2022-05-09 15_12_10](https://cdn.fatbobman.com/status_for_transition_2022-05-09_15.11.26.2022-05-09%2015_12_10.gif)

上面的代码有两个需要注意的地方：

* 必须在条件判断语句的外侧使用 `animation` ，因为只有在 `if - else` 的外侧声明，作用域才会对 `show` 的判断有效
* 应使用布局容器（ VStack、ZStack、HStack 视图 ）包裹条件判断语句（ 不要使用 Group ）。由于两个分支视图在转场时会同时出现，因此只有在布局容器中才会正确的处理转场动画。Group 只能对其子元素进行统一设置，不具备处理两个分支视图同时出现的情况（会有一个视图分支的转场丢失）。

代码二描述了在 show 发生变化时同一个视图的不同状态（ `offset` 的 y 数值不同）。因此，在对时序曲线函数关联后，视图将从状态一（ y : 0 ）的位置移动到状态二（ y : 100）的位置。

```swift
// 代码二
Text("Hello")
    .offset(y : show ? 100 : 0)  // 同一视图两种状态声明
    .animation(.spring(), value: show)
```

![status_offset_2022-05-09_15.14.12.2022-05-09 15_14_45](https://cdn.fatbobman.com/status_offset_2022-05-09_15.14.12.2022-05-09%2015_14_45.gif)

> 有关视图的结构性标识的内容可以参阅 [ViewBuilder 研究（下） —— 从模仿中学习](https://www.fatbobman.com/posts/viewBuilder2/)

### 显式标识

在 SwiftUI 中，为视图设置显式识别有两种方式：ForEach 和 id 修饰符。

* 给 ForEach 提供一个稳定且唯一的的 KeyPath 作为标识。

```swift
struct Demo: View {
    @State var items = (0...100).map { $0 }
    var body: some View {
        VStack {
            List {
                ForEach(items, id: \.self) { item in // id: \.self 使用 element 作为 identifier
                    Text("\(item)")
                }
            }
            .animation(.easeInOut, value: items)
            Button("Remove Second") {
                items.remove(at: 1)
            }
            Button("add Second") {  // 在 items 中会出现相同的元素，破坏了标识的唯一性
                items.insert(Int.random(in: 0...100), at: 1)
            }
        }
        .frame(width: 400, height: 500)
    }
}
```

items 是整数数组。上面的代码中使用了 `\.self` 作为标识依据。这意味着，当数组中出现了两个同样的元素（点击添加按钮），SwiftUI 将无法正确识别我们的意图 —— 究竟是想对那个元素（值相同意味着标识也相同）进行操作。因此有很大的可能因为对视图的识别错误，而产生动画异常。下面的动图中，当出现相同元素时，SwiftUI 给出了警告提示。

![foreach_id_error_2022-05-09_16.41.18.2022-05-09 16_43_22](https://cdn.fatbobman.com/foreach_id_error_2022-05-09_16.41.18.2022-05-09%2016_43_22.gif)

为 ForEach 提供具有唯一标识的数据源可有效避免因此而产生的动画异常。

```swift
struct Item: Identifiable, Equatable {
    let id = UUID() // 唯一标识
    let number: Int
}

struct Demo: View {
    @State var items = (0...100).map { Item(number: $0) }
    var body: some View {
        VStack {
            List {  // 目前无法为 List 里的 item 指定 transition ，又一个没有在原始控件中很好兼容 SwiftUI 动画的例子。换成 ScrollView 可以支持指定 item 的转场
                ForEach(items, id: \.id) { item in
                    Text("\(item.number)")
                }
            }
            .animation(.easeInOut, value: items) // List 使用该关联来处理动画，而不是 ForEach
            Button("Remove Second") {
                items.remove(at: 1)
            }
            Button("add Second") {
                items.insert(Item(number: Int.random(in: 0...100)), at: 1)
            }
        }
        .frame(width: 400, height: 500)
    }
}
```

* 修饰符 id 需要使用转场

修饰符 `id` 是另一种为视图提供显示标识的方式。当修饰符 id 的值发生变化时，SwiftUI 将其作用的视图从当前的视图结构中移除，并创建新的视图添加到原先所在的视图层次位置。因此，可以影响到它的动画部件也是 AnyTransaction 。

```swift
struct Demo: View {
    @State var id = UUID()
    var body: some View {
        VStack {
            Spacer()
            Text("Hello \(UUID().uuidString)")
                .id(id) // id 发生变化时 原视图移除，新视图移入
                .transition(.slide) 
                .animation(.easeOut, value: id)
            Button("Update id") {
                id = UUID()
            }
            Spacer()
        }
        .frame(width: 300, height: 300)
    }
}
```

![id_transition_2022-05-09_16.58.42.2022-05-09 16_59_17](https://cdn.fatbobman.com/id_transition_2022-05-09_16.58.42.2022-05-09%2016_59_17-2086776.gif)

SwiftUI 目前在处理因 `id` 值变化而产生的视图转换的逻辑不太统一，如发现使用 `animation` 无法激活的转场（ 比如 opacity ），可以尝试使用 `withAnimation`。

> 有关显性标识方面的内容可以参阅 [优化在 SwiftUI List 中显示大数据集的响应效率](https://www.fatbobman.com/posts/optimize_the_response_efficiency_of_List/) 一文

## 遗憾与展望

理论上，一旦你掌握了 SwiftUI 的动画机制，就应该能轻松地驾驭代码，自由地控制动画。但现实是残酷的。由于 SwiftUI 是一个年轻的框架，很多的底层实现仍依赖对其他框架 API 的封装，因此不少场景下的使用体验仍充斥着割裂感。

### 控件的动画问题

SwiftUI 中的不少控件是采用对 UIKit（ AppKit ）控件进行封装实现的，当前的动画处理并不到位。

在 [ViewBuilder 研究（下） —— 从模仿中学习](https://www.fatbobman.com/posts/viewBuilder2/) 一文中，我们展示了 SwiftUI 的 Text 是如何处理它的扩展方法的。尽管 UIViewRepresentableContext 已经为底层控件提供了动画控制所需的 Transaction 信息，但是当前 SwiftUI 的官方控件并没有对此进行响应。譬如说下面的代码是无法实现平滑过渡的。

```swift
Text("Hello world")
    .foregroundColor(animated ? .red : .blue) // 基于 UIKit（AppKit）封装的控件的扩展几乎都无法实现动画控制
    .font(animated ? .callout : .title3)
```

虽然我们可以通过一些方法来解决这些问题，但不仅会加大工作量，同时也会损失部分性能。

Paul Hudson 在 [How to animate the size of text](https://www.hackingwithswift.com/quick-start/swiftui/how-to-animate-the-size-of-text) 一文中演示了如何创建字体尺寸的平滑过渡动画。

下面的代码可以帮助 Text 实现文本颜色的平滑过渡。

```swift
extension View {
    func animatableForeground(_ color: Color) -> some View {
        self
            .overlay(Rectangle().fill(color))
            .mask {
                self
                    .blendMode(.overlay)
            }
    }
}

struct Demo: View {
    @State var animated = false
    var body: some View {
        VStack {
            Button("Animate") {
                animated.toggle()
            }
            Text("Hello world")
                .font(.title)
                .animatableForeground(animated ? .green : .orange)
                .animation(.easeInOut(duration: 1), value: animated)
        }
    }
}
```

![animatable_color_of_text_2022-05-05_14.35.19.2022-05-05 14_36_15](https://cdn.fatbobman.com/animatable_color_of_text_2022-05-05_14.35.19.2022-05-05%2014_36_15.gif)

> 2022 年 6 月更新：SwiftUI 4.0 的 Text 通过新增的内容转场，提供了对上述方案的支持

为了区别 SwiftUI 原有的 Transition 概念，SwiftUI 4.0 将这种控件内部的动画转场称之为 content transition（ 内容转场 ）。开发者可以通过 `.contentTransition` 设定内容转场模式：

```swift
// SwiftUI 4.0 (iOS 16+, macOS 13+)
struct ContentTransitionDemo: View {
    @State var change = false
    var body: some View {
        VStack{
            Button("Change"){
                change.toggle()
            }
            .buttonStyle(.bordered)
            Spacer()
            Text("Hello, World!")
                .font(change ? .body : .largeTitle)
                .foregroundStyle( change ? Color.red.gradient : Color.blue.gradient)
                .fontWeight(change ? .thin : .heavy)
                .animation(.easeInOut, value: change)
        }
        .frame(height:100)
    }
}
```

![contentTransition_demo1_2022-06-10_09.07.48.2022-06-10 09_08_58](https://cdn.fatbobman.com/contentTransition_demo1_2022-06-10_09.07.48.2022-06-10%2009_08_58.gif)

启用内容转场（ content transition ）仍需遵循 SwiftUI 动画的三要素，必须为动画设置时序曲线函数 。

```swift
Text("Hello, World!")
                .font(change ? .body : .largeTitle)
                .foregroundStyle( change ? Color.red.gradient : Color.blue.gradient)
                .fontWeight(change ? .thin : .heavy)
                .animation(.easeInOut, value: change)
                .contentTransition(.opacity)  // 设置内容转场模式，默认为 interpolate
```

当前支持的 contentTransition 模式有：

* interpolate （ 默认值 ）

  演示效果如上图。自动绘制插值动画。实现的逻辑和效果基本等同于上文中我们的自定义动画 Text

* opacity

![contentTransition_demo2_2022-06-10_09.18.06.2022-06-10 09_19_47](https://cdn.fatbobman.com/contentTransition_demo2_2022-06-10_09.18.06.2022-06-10%2009_19_47.gif)

* identity

![contentTransition_demo3_2022-06-10_09.25.27.2022-06-10 09_26_04](https://cdn.fatbobman.com/contentTransition_demo3_2022-06-10_09.25.27.2022-06-10%2009_26_04.gif)

也可以通过环境值来完成内容转场模式的设置：

```swift
            Text("Hello, World!")
                .font(change ? .body : .largeTitle)
                .foregroundStyle(change ? Color.red.gradient : Color.blue.gradient)
                .fontWeight(change ? .thin : .heavy)
                .animation(.easeInOut, value: change)
                .environment(\.contentTransition, .opacity)  // 使用环境值设定
                .environment(\.contentTransitionAddsDrawingGroup, true) // 启用 GPU 加速
```

如果想让你的自定义组件（ 对 UIKit 或 AppKit 组件的包装 ）也支持内容转场，需要在定义中查看环境值的设定，例如：

```swift
struct CustomComponent: UIViewRepresentable {
    @Environment(\.contentTransition) var contentTransition
    @Environment(\.contentTransitionAddsDrawingGroup) var drawingGroup // 是否启用 GPU 加速渲染模式
    
    func makeUIView(context: Context) -> some UIView {
        switch contentTransition {
        case .opacity:
            break
        case .identity:
            break
        case .interpolate:
            break
        default:
            break
        }

        if drawingGroup {

        }
        return UIView()
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {}
}
```

所有显式或隐式使用到 Text 的组件均可以从 content transition 中受益，例如：

```swift
Button("Click Me") {}
          .font(change ? .body : .largeTitle)
          .foregroundStyle(change ? Color.red.gradient : Color.blue.gradient)
          .fontWeight(change ? .thin : .heavy)
          .animation(.easeInOut, value: change)
```

### 控制器的动画问题

相较于控件动画，控制器的动画问题则更加难以解决。NavigationView、TabView、Sheet 等部件完全找不到原生的动画控制解决手段，即使调用 UIKit（ AppKit ） 代码，也只能对动画做细微的调整（比如控制动画开启）。手段与效果均与 SwiftUI 的原生动画能力有巨大的差距。

迫切地希望 SwiftUI 能在此方面有所突破。除了动画逻辑可以更 SwiftUI 化外，最好也能将 AnyTransition 用于控制器的过渡设定。

### 动画性能问题

响应式动画的反应略逊于命令式动画几乎是必然的。SwiftUI 在优化动画性能方面已经做出了一些努力（比如：Canvas、drawingGroup ）。希望随着代码的不断优化以及硬件的不断提升，会让这种差距的感知越来越小。

## 总结

* 动画是创建从一个状态到另一个状态的平滑过渡
* 声明一个动画需要三要素
* 掌握状态的变化所能导致的结果 —— 同一个视图的不同状态还是不同的视图分支
* 时序曲线函数与依赖的关联越精准，产生异常动画的可能性就越小
* 唯一且稳定的视图标识（无论是结构性标识还是显式标识）有助于避免动画异常

SwiftUI 的动画机制设计的还是相当优秀的，相信随着完成度的不断提高，开发者可以用更少的代码获得更加优秀的交互效果。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
