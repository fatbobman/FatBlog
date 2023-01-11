---
date: 2021-07-31 18:40
description: 本文探讨的是如何优雅、高效、安全地在 SwiftUI 中使用@AppStorage，在不借助第三方库的情况下，解决当前@AppStorage 使用中出现的痛点
tags: SwiftUI,Architecture
title: @AppStorage 研究
---
## 前言 ##

在苹果生态的应用中，开发者或多或少都会使用到 UserDefaults。我个人习惯将可被用户自定义的配置信息（精度、单位、色彩等）保存在 UserDefaults 中。随着配置信息的增加，在 SwiftUI 视图中使用的@AppStorage 越来越多。

在 [【健康笔记 3】](/healthnotes/) 中，我计划开放更多的自定义选项给用户，简单的算下来要有 40-50 项，在配置视图中更会将所有用到的 UserDefaults 内容都注入进代码。

本文探讨的是如何优雅、高效、安全地在 SwiftUI 中使用@AppStorage，在不借助第三方库的情况下，解决当前@AppStorage 使用中出现的痛点：

* 支持的数据类型少
* 声明繁琐
* 声明容易出现拼写错误
* 大量@AppStorage 无法统一注入

```responser
id:1
```

## @AppStorage 基础指南 ##

@AppStorage 是 SwiftUI 框架提供的一个属性包装器，设计初衷是创建一种在视图中保存和读取 UserDefaults 变量的快捷方法。@AppStorage 在视图中的行为同@State 很类似，其值变化时将导致与其依赖的视图无效并进行重新绘制。

@AppStorage 声明时需要指定在 UserDefaults 中保存的键名称（Key）以及默认值。

```swift
@AppStorage("username") var name = "fatbobman"
```

`userName`为键名称，`fatbobman`是为`username`设定的默认值，如果 UserDefaults 中的`username`已经有值，则使用保存值。

如果不设置默认值，则变量的为可选值类型

```swift
@AppStorage("username") var name:String?
```

默认情况下使用的是 UserDefaults.standard，也可以指定其他的 UserDefaults。

```swift
public extension UserDefaults {
    static let shared = UserDefaults(suiteName: "group.com.fatbobman.examples")!
}

@AppStorage("userName",store:UserDefaults.shared) var name = "fat"
```

对 UserDefaults 操作将直接影响对应的@AppStorage

```swift
UserDefaults.standard.set("bob",forKey:"username")
```

上述代码将更新所有依赖`@AppStorage("username")`的视图。

UserDefaults 是一种高效且轻量的持久化方案，它有以下不足：

* 数据不安全

  它的数据相对容易提取，所以不要保存和隐私有关的重要数据

* 持久化时机不确定

  为了效率的考量，UserDefaults 中的数据在发生变化时并不会立即持久化，系统会在认为合适的时机才将数据保存在硬盘中。因此，可能发生数据不能完全同步的情况，严重时有数据彻底丢失的可能。尽量不要在其中保存会影响 App 执行完整性的关键数据，在出现数据丢失的状况下，App 仍可根据默认值正常运行

尽管@AppStorage 是作为 UserDefaults 的属性包装器存在的，但@AppStorage 并没有支持全部的`property list`数据类型，目前仅支持：Bool、Int、Double、String、URL、Data（UserDefaults 支持更多的类型）。

## 增加@AppStorage 支持的数据类型 ##

除了上述的类型外，@AppStorage 还支持符合`RawRepresentable`协议且`RawValue`为`Int`或`String`的数据类型。通过增加`RawRepresentable`协议的支持，我们可以在@AppStorage 中读取存储原本并不支持的数据类型。

下面的代码添加了对`Date`类型的支持：

```swift
extension Date:RawRepresentable{
    public typealias RawValue = String
    public init?(rawValue: RawValue) {
        guard let data = rawValue.data(using: .utf8),
              let date = try? JSONDecoder().decode(Date.self, from: data) else {
            return nil
        }
        self = date
    }

    public var rawValue: RawValue{
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data:data,encoding: .utf8) else {
            return ""
        }
       return result
    }
}
```

使用起来和直接支持的类型完全一致：

```swift
@AppStorage("date") var date = Date()
```

下面的代码添加了对`Array`的支持：

```swift
extension Array: RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data)
        else { return nil }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }
}
```

```swift
@AppStorage("selections") var selections = [3,4,5]
```

对于`RawValue`为`Int`或`String`的枚举类型，可以直接使用，比如：

```swift
enum Options:Int{
    case a,b,c,d
}

@AppStorage("option") var option = Options.a
```

## 安全和便捷的声明（一） ##

@AppStorage 的声明方式有两个令人不悦的地方：

* 每次都要设定 Key（字符串）
* 每次都要设定默认值

而且开发者很难享受到代码自动补全和编译时检查带来的快捷、安全的体验。

较好的解决方案是将@AppStorage 集中声明，并在每个视图中通过引用注入。**鉴于 SwiftUI 的刷新机制，我们必须要在集中声明、单独注入后仍需保留@AppStorage 的`DynamicProperty`特征——当 UserDefaults 的值发生变动时刷新视图。**

下面的代码能满足以上的要求：

```swift
enum Configuration{
    static let name = AppStorage(wrappedValue: "fatbobman", "name")
    static let age = AppStorage(wrappedValue: 12, "age")
}
```

在视图中使用方法如下：

```swift
let name = Configuration.name
var body:some View{
     Text(name.wrappedValue)
     TextField("name",text:name.projectedValue)
}
```

`name`和直接在代码中通过@AppStorage 声明的效果类似。不过付出的代价就是需要将`wrappedValue`和`projectedValue`明确标注出来。

> 是否有不标注`wrappedValue`和`projectedValue`又能达到上述结果的实现方案呢？在**安全和便捷的声明（二）**中我们将尝试使用另一种解决途径。

## 集中注入 ##

在介绍另一种便捷声明方式之前，我们先聊一下集中注入的问题。

【健康笔记 3】目前面临着前言中所描述的情况，配置信息内容很多，如果单独注入会很麻烦。我需要找到一种可以集中声明、一并注入的方式。

在**安全和便捷的声明（一）**中使用的方法对于单独注入的情况是满足的，但如果我们想统一注入的话就需要其他的手段了。

> 我并不打算将配置数据汇总到一个结构体中并通过支持`RawRepresentable`协议统一保存。除了数据转换导致的性能损失外，另一个重要问题是，如果出现数据丢失的情况，逐条保存的方式还是可以保护绝大多数的用户设定的。

在基础指南**中，我们提到@AppStorage 在视图中的表现同@State 非常类似；不仅如此，@AppStorage 还有一个官方文档从没提到的神奇特质，**在 ObservableObject 中具有同@Published 一样的特性——其值发生变化时会触发`objectWillChange`**。这个特性只发生在@AppStorage 身上，@State、@SceneStorage 都不具备这个能力。

~~目前我无法从文档或暴露的代码中找到这一特性原因，因此以下的代码并不能获得官方的长期保证~~

> 2022 年 5 月更新：关于 @AppStorage 和 @Published 调用包裹其的类实例的 objectWillChange 的原理，请参阅[为自定义属性包装类型添加类 @Published 的能力](https://www.fatbobman.com/posts/adding-Published-ability-to-custom-property-wrapper-types/)。

```swift
class Defaults: ObservableObject {
    @AppStorage("name") public var name = "fatbobman"
    @AppStorage("age") public var age = 12
}
```

视图代码：

```swift
@StateObject var defaults = Defaults()
...
Text(defaults.name)
TextField("name",text:defaults.$name)
```

不仅代码整洁了许多，而且由于只需要在`Defaults`中声明一次，极大的降低了由于字符串拼写错误而出现的不易排查的 Bug。

> `Defaults`中使用的是`@AppStorage`的声明方式，而`Configuration`中使用的是`AppStorage`的原始构造形式。变化的目的是为了能够保证视图更新机制的正常运作。

## 安全和便捷的声明（二） ##

**集中注入**中提供的方法已经基本解决了我在当前使用@AppStorage 中碰到的不便，不过我们还可以尝试另一种优雅、有趣的逐条声明注入的方式。

首先修改一下`Defaults`的代码

```swift
public class Defaults: ObservableObject {
    @AppStorage("name") public var name = "fatbobman"
    @AppStorage("age") public var age = 12
    public static let shared = Defaults()
}
```

创建一个新的属性包装器`Default`

```swift
@propertyWrapper
public struct Default<T>: DynamicProperty {
    @ObservedObject private var defaults: Defaults
    private let keyPath: ReferenceWritableKeyPath<Defaults, T>
    public init(_ keyPath: ReferenceWritableKeyPath<Defaults, T>, defaults: Defaults = .shared) {
        self.keyPath = keyPath
        self.defaults = defaults
    }

    public var wrappedValue: T {
        get { defaults[keyPath: keyPath] }
        nonmutating set { defaults[keyPath: keyPath] = newValue }
    }

    public var projectedValue: Binding<T> {
        Binding(
            get: { defaults[keyPath: keyPath] },
            set: { value in
                defaults[keyPath: keyPath] = value
            }
        )
    }
}
```

现在我们可以在视图中采用如下代码来逐个声明注入了：

```swift
@Default(\.name) var name
Text(name)
TextField("name",text:$name)
```

逐个注入且无需标注`wrappedValue`和`projectedValue`。由于使用`keyPath`，避免了可能出现的字符串拼写错误问题。

鱼和熊掌不可兼得，上述的方法还是不十分完美——会出现过度依赖的情况。即使你只在视图中注入了一个 UserDefaults 键值（比如`name`），但当`Defaults`中其他未注入的键值内容发生变动时（`age`发生变化），依赖`name`的视图也同样会被刷新。

不过由于通常情况下配置数据的变化频率很低，所以并不会对 App 造成什么性能负担。

## 总结 ##

本文提出了几个在不采用第三方库的情况下，解决@AppStorage 痛点的方案。为了保证视图的刷新机制，分别采用的不同的实现方式。

SwiftUI 中即使一个不起眼的环节也有不少乐趣值的我们探索。

*如果想实现完美的逐条注入方式（自动补全、编译器检查、不过度依赖）可以通过创建自己的 UserDefaults 响应代码来实现，这已超出了本文对于@AppStorage 的探讨范围。*

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
