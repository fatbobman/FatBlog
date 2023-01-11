---
date: 2022-01-10 08:12
description: 不同于众多的内置控件，SwiftUI 没有采用对 UIGestureRecognizer（或 NSGestureRecognizer）进行包装的形式，而是重构了自己的手势体系。SwiftUI 手势在某种程度上降低了使用门槛，但由于缺乏提供底层数据的 API，严重制约了开发者的深度定制能力。在 SwiftUI 下，我们无法拥有类似构建全新 UIGestureRecongnizer 的能力。所谓的自定义手势，其实只是对系统预置手势的重构而已。本文将通过几个示例，演示如何使用 SwiftUI 提供的原生手段定制所需手势。
tags: SwiftUI
title:  在 SwiftUI 下定制手势
image: images/swiftuiGesture.png
---
不同于众多的内置控件，SwiftUI 没有采用对 UIGestureRecognizer（或 NSGestureRecognizer）进行包装的形式，而是重构了自己的手势体系。SwiftUI 手势在某种程度上降低了使用门槛，但由于缺乏提供底层数据的 API，严重制约了开发者的深度定制能力。在 SwiftUI 下，我们无法拥有类似构建全新 UIGestureRecongnizer 的能力。所谓的自定义手势，其实只是对系统预置手势的重构而已。本文将通过几个示例，演示如何使用 SwiftUI 提供的原生手段定制所需手势。

```responser
id:1
```

## 基础

### 预置手势

SwiftUI 目前提供了 5 种预置手势，分别为点击、长按、拖拽、缩放和旋转。像`onTapGesture`之类的调用方式，实际上是为了便捷而创建的视图扩展。

* 点击（TapGesture）

  可设定点击次数（单击、双击）。是使用频率最高的手势之一。

* 长按（LongPressGesture）

  当按压满足了设定时长后，可触发指定闭包。

* 拖拽（DragGesture）

  SwiftUI 将 Pan 和 Swipe 合二为一，位置变化时，提供拖动数据。

* 缩放（MagnificationGesture）

  两指缩放。

* 旋转（RotationGesture）

  两指旋转。

点击、长按、拖拽仅支持单指。SwiftUI 没有提供手指数设定功能。

除了上述提供给开发者使用的手势外，SwiftUI 其实还有大量的内部（非公开）手势给系统控件使用，例如：ScrollGesture、_ButtonGesture 等。

> Button 内置手势的实现比 TapGesture 更复杂。除了提供了更多的调用时机外，而且支持了对按压区域尺寸的智能处理（提高手指触击成功率）。

### Value

SwiftUI 会依据手势的类型提供不同的数据内容。

* 点击：数据类型为 Void（ SwiftUI 4.0 中，数据类型为 CGPoint，指示了在特定坐标空间中的点击位置 ）
* 长按：数据类型为 Bool，开始按压后提供 true
* 拖拽：提供了最全面的数据信息，包含当前位置、偏移量、事件时间、预测终点、预测偏移量等内容
* 缩放：数据类型为 CGFloat，缩放量
* 旋转：数据类型为 Angle，旋转角度

使用`map`方法，可以将手势提供的数据转换成其他的类型，方便之后的调用。

### 时机

SwiftUI 手势内部没有状态一说，通过设置与指定时机对应的闭包，手势会在适当的时机自动进行调用。

* onEnded

  在手势结束时执行的操作

* onChanged

  当手势提供的值发生变化时执行的操作。只在 Value 符合 Equatable 时提供，因此 TapGesture 不支持。

* updating

  执行时机同 onChanged 相同。对 Value 没有特别约定，相较 onChanged ，增加了更新手势属性（GestureState）和获取 Transaction 的能力。

不同的手势，对时机的关注点有所区别。点击通常只关注 onEnded；onChanged（或 updating）在拖拽、缩放、旋转中作用更大；长按只有在满足了设定时长的情况下，才会调用 onEnded。

### GestureState

专门为 SwiftUI 手势开发的属性包装器类型，可作为依赖项驱动视图更新。相较 State 有如下不同：

* 只能在手势的 updating 方法中修改，在视图其它的地方为只读
* 在手势结束时，与之关联（使用 updating 进行关联）的手势会自动将其内容恢复到它的初始值
* 通过 resetTransaction 可以设置恢复初始数据时的动画状态

### 组合手势的手段

SwiftUI 提供了几个用于手势的组合方法，可以将多个手势连接起来，重构成其他用途的手势。

* simltaneously（同时识别）

  将一个手势与另一个手势相结合，创建一个同时识别两个手势的新手势。例如将缩放手势与旋转手势组合，实现同时对图片进行缩放和旋转。

* sequenced（序列识别）

  将两个手势连接起来，只有在第一个手势成功后，才会执行第二个手势。譬如，将长按和拖拽连接起来，实现只有当按压满足一定时间后才允许拖拽。

* exclusively（排他性识别）

  合并两个手势，但只有其中一种手势可以被识别。系统会优先考虑第一个手势。

组合后的手势，Value 类型也将发生变化。仍可使用 `map` 将其转换成更加易用的数据类型。

### 手势的定义形式

通常开发者会在视图内部创建自定义手势，如此代码量较少，且容易与视图中其它数据结合。例如，下面的代码在视图中创建了一个可同时支持缩放和旋转的手势：

```swift
struct GestureDemo: View {
    @GestureState(resetTransaction: .init(animation: .easeInOut)) var gestureValue = RotateAndMagnify()

    var body: some View {
        let rotateAndMagnifyGesture = MagnificationGesture()
            .simultaneously(with: RotationGesture())
            .updating($gestureValue) { value, state, _ in
                state.angle = value.second ?? .zero
                state.scale = value.first ?? 0
            }

        return Rectangle()
            .fill(LinearGradient(colors: [.blue, .green, .pink], startPoint: .top, endPoint: .bottom))
            .frame(width: 100, height: 100)
            .shadow(radius: 8)
            .rotationEffect(gestureValue.angle)
            .scaleEffect(gestureValue.scale)
            .gesture(rotateAndMagnifyGesture)
    }

    struct RotateAndMagnify {
        var scale: CGFloat = 1.0
        var angle: Angle = .zero
    }
}
```

另外，也可以将手势创建成符合 Gesture 协议的结构体，如此定义的手势，非常适合被反复使用。

通过将手势或手势处理逻辑封装成视图扩展可进一步简化使用难度。

> 为了突显某些方面的功能，下文中提供的演示代码或许看起来比较繁琐。实际使用时，可自行简化。

## 示例一：轻扫

### 1.1 目标

创建一个轻扫（Swipe）手势，着重演示如何创建符合 Gesture 协议的结构体，并对手势数据进行转换。

### 1.2 思路

在 SwiftUI 预置手势中，仅有 DragGesture 提供了可用于判断移动方向的数据。根据偏移量来确定轻扫方向，使用 map 将繁杂的数据转换成简单的方向数据。

### 1.3 实现

```swift
public struct SwipeGesture: Gesture {
    public enum Direction: String {
        case left, right, up, down
    }

    public typealias Value = Direction

    private let minimumDistance: CGFloat
    private let coordinateSpace: CoordinateSpace

    public init(minimumDistance: CGFloat = 10, coordinateSpace: CoordinateSpace = .local) {
        self.minimumDistance = minimumDistance
        self.coordinateSpace = coordinateSpace
    }

    public var body: AnyGesture<Value> {
        AnyGesture(
            DragGesture(minimumDistance: minimumDistance, coordinateSpace: coordinateSpace)
                .map { value in
                    let horizontalAmount = value.translation.width
                    let verticalAmount = value.translation.height

                    if abs(horizontalAmount) > abs(verticalAmount) {
                        if horizontalAmount < 0 { return .left } else { return .right }
                    } else {
                        if verticalAmount < 0 { return .up } else { return .down }
                    }
                }
        )
    }
}

public extension View {
    func onSwipe(minimumDistance: CGFloat = 10,
                 coordinateSpace: CoordinateSpace = .local,
                 perform: @escaping (SwipeGesture.Direction) -> Void) -> some View {
        gesture(
            SwipeGesture(minimumDistance: minimumDistance, coordinateSpace: coordinateSpace)
                .onEnded(perform)
        )
    }
}
```

### 1.4 演示

```swift
struct SwipeTestView: View {
    @State var direction = ""
    var body: some View {
        Rectangle()
            .fill(.blue)
            .frame(width: 200, height: 200)
            .overlay(Text(direction))
            .onSwipe { direction in
                self.direction = direction.rawValue
            }
    }
}
```

![swipeGestureDemo2](https://cdn.fatbobman.com/swipeGestureDemo2.gif)

### 1.5 说明

* 为什么使用 AnyGesture

  在 Gesture 协议中，需要实现一个隐藏的类型方法：`_makeGesture`。苹果目前并没有提供应该如何实现它的文档，好在 SwiftUI 提供了一个含有约束的默认实现。当我们不在结构体中使用自定义的 Value 类型时，SwiftUI 可以推断出 `Self.Body.Value`，此时可以将 body 声明为`some Gesture`。但由于本例中使用了自定义 Value 类型，因此必须将 body 声明为`AnyGesture<Value>`，方可满足启用`_makeGesture`默认实现的条件。

```swift
  extension Gesture where Self.Value == Self.Body.Value {
    public static func _makeGesture(gesture: SwiftUI._GraphValue<Self>, inputs: SwiftUI._GestureInputs) -> SwiftUI._GestureOutputs<Self.Body.Value>
  }
```

### 1.6 不足与改善方法

本例中并没有对手势的持续时间、移动速度等因素进行综合考量，当前的实现严格意义上并不能算是真正轻扫。如果想实现严格意义上的轻扫可以采用如下的实现方法：

* 改成示例 2 的方式，用 ViewModifier 来包装 DragGesture
* 用 State 记录滑动时间
* 在 onEnded 中，只有满足速度、距离、偏差等要求的情况下，才回调用户的闭包，并传递方向

```responser
id:1
```

## 示例二：计时按压

### 2.1 目标

实现一个可以记录时长的按压手势。手势在按压过程中，可以根据指定的时间间隔进行类似 onChanged 的回调。本例程着重演示如何通过视图修饰器包装手势的方法以及 GestureState 的使用。

### 2.2 思路

通过计时器在指定时间间隔后向闭包传递当前按压的持续时间。使用 GestureState 保存点击开始的时间，按压结束后，上次按压的起始时间会被手势自动清除。

### 2.3 实现

```swift
public struct PressGestureViewModifier: ViewModifier {
    @GestureState private var startTimestamp: Date?
    @State private var timePublisher: Publishers.Autoconnect<Timer.TimerPublisher>
    private var onPressing: (TimeInterval) -> Void
    private var onEnded: () -> Void

    public init(interval: TimeInterval = 0.016, onPressing: @escaping (TimeInterval) -> Void, onEnded: @escaping () -> Void) {
        _timePublisher = State(wrappedValue: Timer.publish(every: interval, tolerance: nil, on: .current, in: .common).autoconnect())
        self.onPressing = onPressing
        self.onEnded = onEnded
    }

    public func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .updating($startTimestamp, body: { _, current, _ in
                        if current == nil {
                            current = Date()
                        }
                    })
                    .onEnded { _ in
                        onEnded()
                    }
            )
            .onReceive(timePublisher, perform: { timer in
                if let startTimestamp = startTimestamp {
                    let duration = timer.timeIntervalSince(startTimestamp)
                    onPressing(duration)
                }
            })
    }
}

public extension View {
    func onPress(interval: TimeInterval = 0.016, onPressing: @escaping (TimeInterval) -> Void, onEnded: @escaping () -> Void) -> some View {
        modifier(PressGestureViewModifier(interval: interval, onPressing: onPressing, onEnded: onEnded))
    }
}
```

### 2.4 演示

```swift
struct PressGestureView: View {
    @State var scale: CGFloat = 1
    @State var duration: TimeInterval = 0
    var body: some View {
        VStack {
            Circle()
                .fill(scale == 1 ? .blue : .orange)
                .frame(width: 50, height: 50)
                .scaleEffect(scale)
                .overlay(Text(duration, format: .number.precision(.fractionLength(1))))
                .onPress { duration in
                    self.duration = duration
                    scale = 1 + duration * 2
                } onEnded: {
                    if duration > 1 {
                        withAnimation(.easeInOut(duration: 2)) {
                            scale = 1
                        }
                    } else {
                        withAnimation(.easeInOut) {
                            scale = 1
                        }
                    }
                    duration = 0
                }
        }
    }
}
```

![pressGestureDemo.2022-01-08 13_50_59](https://cdn.fatbobman.com/pressGestureDemo.2022-01-08%2013_50_59.gif)

### 2.5 说明

* GestureState 数据的复原时间在 onEnded 之前，在 onEnded 中，startTimestamp 已经恢复为 nil
* DragGesture 仍是最好的实现载体。TapGesture、LongPressGesture 均在满足触发条件后会自动终止手势，无法实现对任意时长的支持

### 2.6 不足及改善方法

当前的解决方案没有提供类似 LongPressGesture 按压中位置偏移限定设置，另外尚未在 onEnded 中提供本次按压的总持续时长。

* 在 updating 中对偏移量进行判断，如果按压点的偏移超出了指定的范围，则中断计时。并在 updating 中，调用用户提供的 onEnded 闭包，并进行标记
* 在手势的 onEnded 中，如果用户提供的 onEnded 闭包已经被调用，则不会再此调用
* 使用 State 替换 GestureState，这样就可以在手势的 onEnded 中提供总持续时间。需自行编写 State 的数据恢复代码
* 由于使用了 State 替换 GestureState，逻辑判断就可以从 updating 移动到 onChanged 中

## 示例三：附带位置信息的点击

> SwiftUI 4.0 提供了新的 Gesture —— SpatialTapGesture , 使用它可以直接获得点击位置。onTapGesture 也获得提升，onChange 和 onEnd 中 value 将表示在特定坐标空间中的点击位置（ CGPoint ）

### 3.1 目标

实现提供触摸位置信息的点击手势（支持点击次数设定）。本例主要演示 simultaneously 的用法以及如何选择合适的回调时间点（onEnded）。

### 3.2 思路

手势的响应感觉应与 TapGesture 完全一致。使用 simultaneously 将两种手势联合起来，从 DrageGesture 中获取位置数据，从 TapGesture 中退出。

### 3.3 实现

```swift
public struct TapWithLocation: ViewModifier {
    @State private var locations: CGPoint?
    private let count: Int
    private let coordinateSpace: CoordinateSpace
    private var perform: (CGPoint) -> Void

    init(count: Int = 1, coordinateSpace: CoordinateSpace = .local, perform: @escaping (CGPoint) -> Void) {
        self.count = count
        self.coordinateSpace = coordinateSpace
        self.perform = perform
    }

    public func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: coordinateSpace)
                    .onChanged { value in
                        locations = value.location
                    }
                    .simultaneously(with:
                        TapGesture(count: count)
                            .onEnded {
                                perform(locations ?? .zero)
                                locations = nil
                            }
                    )
            )
    }
}

public extension View {
    func onTapGesture(count: Int = 1, coordinateSpace: CoordinateSpace = .local, perform: @escaping (CGPoint) -> Void) -> some View {
        modifier(TapWithLocation(count: count, coordinateSpace: coordinateSpace, perform: perform))
    }
}

```

### 3.4 演示

```swift
struct TapWithLocationView: View {
    @State var unitPoint: UnitPoint = .center
    var body: some View {
        Rectangle()
            .fill(RadialGradient(colors: [.yellow, .orange, .red, .pink], center: unitPoint, startRadius: 10, endRadius: 170))
            .frame(width: 300, height: 300)
            .onTapGesture(count:2) { point in
                withAnimation(.easeInOut) {
                    unitPoint = UnitPoint(x: point.x / 300, y: point.y / 300)
                }
            }
    }
}
```

![TapWithLocationDemo](https://cdn.fatbobman.com/TapWithLocationDemo.gif)

### 3.5 说明

* 当 DragGesture 的 minimumDistance 设置为 0 时，其第一条数据的产生时间一定早于 TapGesture(count:1) 的激活时间
* 在 simultaneously 中，一共有三个 onEndend 时机。手势 1 的 onEnded，手势 2 的 onEnded，以及合并后手势的 onEnded。在本例中，我们选择在 TapGesture 的 onEnded 中回调用户的闭包

## 总结

当前 SwiftUI 的手势，暂处于使用门槛低但能力上限不足的状况，仅使用 SwiftUI 的原生手段无法实现非常复杂的手势逻辑。将来找时间我们再通过其它的文章来研究有关手势之间的优先级、使用 GestureMask 选择性失效，以及如何同 UIGestureRecognizer 合作创建复杂手势等议题。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
