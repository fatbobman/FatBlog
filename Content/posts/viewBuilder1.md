---
date: 2022-04-06 08:20
description: 作为一个严重依赖 SwiftUI 的开发者，同视图打交道是最平常不过的事情了。从第一次接触 SwiftUI 的声明式编程方式开始，我便喜欢上了这种写代码的感觉。但接触地越多，碰到的问题也越多。起初，我单纯地将很多问题称之为灵异现象，认为大概率是由于 SwiftUI 的不成熟导致的。随着不断地学习和探索，发现其中有相当部分的问题还是因为自己的认知不够所导致的，完全可以改善或避免。我将通过上下两篇博文，对构建 SwiftUI 视图的 ViewBuilder 进行探讨。本篇将首先介绍 ViewBuilder 背后的实现者 —— result builders 。
tags: SwiftUI
title:  ViewBuilder 研究（上）—— 掌握 Result builders
image: images/viewbuilder_1.png
---
作为一个严重依赖 SwiftUI 的开发者，同视图打交道是最平常不过的事情了。从第一次接触 SwiftUI 的声明式编程方式开始，我便喜欢上了这种写代码的感觉。但接触地越多，碰到的问题也越多。起初，我单纯地将很多问题称之为灵异现象，认为大概率是由于 SwiftUI 的不成熟导致的。随着不断地学习和探索，发现其中有相当部分的问题还是因为自己的认知不够所导致的，完全可以改善或避免。

我将通过上下两篇博文，对构建 SwiftUI 视图的 ViewBuilder 进行探讨。上篇将介绍 ViewBuilder 背后的实现者 —— result builders ; 下篇将通过对 ViewBuilder 的仿制，进一步地探寻 SwiftUI 视图的秘密。

```responser
id:1
```

## 本文希望达成的目标

希望在阅读完两篇文章后能消除或减轻你对下列疑问的困惑：

* 如何让自定义视图、方法支持 ViewBuilder
* 为什么复杂的 SwiftUI 视图容易在 Xcode 上卡死或出现编译超时
* 为什么会出现 “Extra arguments” 的错误提示（仅能在同一层次放置有限数量的视图）
* 为什么要谨慎使用 AnyView
* 如何避免使用 AnyView
* 为什么无论显示与否，视图都会包含所有选择分支的类型信息
* 为什么绝大多数的官方视图类型的 body 都是 Never
* ViewModifier 同特定视图类型的 modifier 之间的区别

## 什么是 Result builders

### 介绍

result builders 允许某些函数通过一系列组件中隐式构建结果值，按照开发者设定的构建规则对组件进行排列。通过对函数语句应用构建器进行转译，result builders 提供了在 Swift 中创建新的领域特定语言（ DSL ）的能力（为了保留原始代码的动态语义，Swift 有意地限制了这些构建器的能力）。

与常见的使用点语法实现的类 DSL 相比，使用 result builders 创建的 DSL 使用更简单、无效内容更少、代码更容易理解（在表述具有选择、循环等逻辑内容时尤为明显），例如：

使用点语法（ [Plot](https://github.com/JohnSundell/Plot) ）：

```swift
.div(
    .div(
        .forEach(archiveItems.keys.sorted(by: >)) { absoluteMonth in
            .group(
                .ul(
                    .forEach(archiveItems[absoluteMonth]) { item in
                        .li(
                            .a(
                                .href(item.path),
                                .text(item.title)
                            )
                        )
                    }
                ),
                .if( show, 
                    .text("hello"), 
                  else: .text("wrold")
                 ),
            )
        }
    )
)
```

通过 result builders 创建的构建器 ( [swift-html](https://github.com/BinaryBirds/swift-html) )：

```swift
Div {
    Div {
        for i in 0..<100 {
            Ul {
                for item in archiveItems[i] {
                    li {
                        A(item.title)
                            .href(item.path)
                    }
                }
            }
            if show {
                Text("hello")
            } else {
                Text("world")
            }
        }
    }
}
```

### 历史与发展

自 Swift 5.1 开始，result builders 便随着 SwiftUI 的推出隐藏在 Swift 语言之中（当时名为 function builder）。随着 Swift 与 SwiftUI 的不断进化，最终被正式纳入到 Swift 5.4 版本之中。目前苹果在 SwiftUI 框架中大量地使用了该功能，除了最常见的视图构建器（ViewBuilder）外，其他还包括：AccessibilityRotorContentBuilder、CommandsBuilder、LibraryContentBuilder、SceneBuilder、TableColumnBuilder、TableRowBuilder、ToolbarContentBuilder、WidgetBundleBuilder 等。另外，在最新的 Swift 提案中，已出现了 [Regex builder DSL](https://forums.swift.org/t/pitch-regex-builder-dsl/56007) 的身影。其他的开发者利用该功能也创建了不少的 [第三方库](https://github.com/carson-katri/awesome-result-builders#html)。

### 基本用法

#### 定义构建器类型

一个结果构建器类型必须满足两个基本要求。

* 它必须通过`@resultBuilder`进行标注，这表明它打算作为一个结果构建器类型使用，并允许它作为一个自定义属性使用。

* 它必须至少实现一个名为`buildBlock`的类型方法

例如：

```swift
@resultBuilder
struct StringBuilder {
    static func buildBlock(_ parts: String...) -> String {
        parts.map{"⭐️" + $0 + "🌈"}.joined(separator: " ")
    }
}
```

通过上面的代码，我们便创建了一个具有最基本功能的结果构建器。使用方法如下：

```swift
@StringBuilder
func getStrings() -> String {
    "喜羊羊"
    "美羊羊"
    "灰太狼"
}

// ⭐️喜羊羊🌈 ⭐️美羊羊🌈 ⭐️灰太狼🌈
```

#### 为构建器类型提供足够的结果构建方法子集

* `buildBlock(_ components: Component...) -> Component`

  用来构建语句块的组合结果。每个结果构建器至少要提供一个它的具体实现。

* `buildOptional(_ component: Component?) -> Component`

  用于处理在特定执行中可能或不可能出现的部分结果。当一个结果构建器提供了 `buildOptional(_:)` 时，转译后的函数可以使用没有 `else` 的 `if` 语句，同时也提供了对 `if let` 的支持。

* `buildEither(first: Component) -> Component`和`buildEither(second: Component) -> Component`

  用于在选择语句的不同路径下建立部分结果。当一个结果构建器提供这两个方法的实现时，转译后的函数可以使用带有`else` 的 `if`语句以及 `switch` 语句。

* `buildArray(_ components: [Component]) -> Component`

  用来从一个循环的所有迭代中收集的部分结果。在一个结果构建器提供了 `buildArray(_:)` 的实现后，转译后的函数可以使用 `for...in` 语句。

* `buildExpression(_ expression: Expression) -> Component`

  它允许结果构建器区分`表达式`类型和`组件`类型，为语句表达式提供上下文类型信息。

* `buildFinalResult(_ component: Component) -> FinalResult`

  用于对最外层的 `buildBlock` 结果的再包装。例如，让结果构建器隐藏一些它并不想对外的类型（转换成可对外的类型）。

* `buildLimitedAvailability(_ component: Component) -> Component`

  用于将 `buildBlock` 在受限环境下（例如`if #available`）产生的部分结果转化为可适合任何环境的结果，以提高 API 的兼容性。

> 结果构建器采用 ad hoc 协议，这意味着我们可以更灵活的重载上述方法。然而，在某些情况下，结果构建器的转译过程会根据结果构建器类型是否实现了某个方法来改变其行为。

之后会通过示例对上述的方法逐一做详尽介绍。下文中，会将“结果构建器”简称为“构建器”。

## 范例一：AttributedStringBuilder

本例中，我们将创建一个用于声明 AttributedString 的构建器。对 AttributedString 不太熟悉的朋友，可以阅读我的另一篇博文 [AttributedString——不仅仅让文字更漂亮](https://www.fatbobman.com/posts/attributedString/)。

> 范例一的完整代码可以在 [此处](https://github.com/fatbobman/BlogCodes/tree/main/AttributedStringBuilder/AttributedStringBuilderDemo.playground) 获取（ Demo1 ）

本例结束后，我们将可以用如下的方式来声明 AttributedString ：

```swift
@AttributedStringBuilder
var text: Text {
    "_*Hello*_"
        .localized()
        .color(.green)

    if case .male = gender {
        " Boy!"
            .color(.blue)
            .bold()

    } else {
        " Girl!"
            .color(.pink)
            .bold()
    }
}
```

![image-20220331202541444](https://cdn.fatbobman.com/image-20220331202541444.png)

### 创建构建器类型

```swift
@resultBuilder
public enum AttributedStringBuilder {
    // 对应 block 中没有走 component 的情况
    public static func buildBlock() -> AttributedString {
        .init("")
    }

    // 对应 block 中有 n 个 component 的情况（ n 为正整数 ）
    public static func buildBlock(_ components: AttributedString...) -> AttributedString {
        components.reduce(into: AttributedString("")) { result, next in
            result.append(next)
        }
    }
}
```

我们首先创建了一个名为 AttributedStringBuilder 的构建器，并为其实现了两个 `buildBlock` 方法。构建器在转译时会自动地选择对应的方法。

现在，可以为 block 提供任意数量的 component （  AttributedString ） ，`buildBlock` 会将其转换成指定的结果（AttributedString）。

在实现 `buildBlock` 方法时，components 与 block 的返回数据类型应根据实际需求定义，无需一致。

### 使用构建器转译 Block

可以采用显式的方式来调用构建器，例如：

```swift
@AttributedStringBuilder // 明确标注
var myFirstText: AttributedString {
    AttributedString("Hello")
    AttributedString("World")
}
// "HelloWorld"

@AttributedStringBuilder
func mySecondText() -> AttributedString {} // 空 block ，将调用 buildBlock() -> AttributedString
// ""
```

也可以采用隐式的方式调用构建器：

```swift
// 在 API 端标注
func generateText(@AttributedStringBuilder _ content: () -> AttributedString) -> Text {
    Text(content())
}

// 在客户端隐式调用
VStack {
    generateText {
        AttributedString("Hello")
        AttributedString(" World")
    }
}

struct MyTest {
    var content: AttributedString
    // 在构造方法中标注
    init(@AttributedStringBuilder _ content: () -> AttributedString) {
        self.content = content()
    }
}

// 隐式调用
let attributedString = MyTest {
    AttributedString("ABC")
    AttributedString("BBC")
}.content
```

无论以何种方式，如果在 block 的最后使用了 `return` 关键字来返回结果，则构建器将自动忽略转译过程。例如：

```swift
@AttributedStringBuilder 
var myFirstText: AttributedString {
    AttributedString("Hello") // 该语句将被忽略
    return AttributedString("World") // 仅返回 World
}
// "World"
```

> 为了在 block 中使用构建器不支持的语法，开发者会尝试使用 `return` 来返回结果值，应避免出现这种情况。因为这会导致开发者将失去通过构建器进行转译所带来的灵活性。

下面的代码在使用构建器转译时和不使用构建器转译时的状态完全不同：

```swift
// 构建器自动转译，block 只返回最终的合成结果，代码可正常执行
@ViewBuilder
func blockTest() -> some View {
    if name.isEmpty {
        Text("Hello anonymous!")
    } else {
        Rectangle()
            .overlay(Text("Hello \(name)"))
    }
}

// 构建器的转译行为因 return 而被忽略。 block 中的选择语句两个分支返回了两种不同的类型，无法满足必须返回同一类型的要求（some View），编译无法通过。
@ViewBuilder
func blockTest() -> some View {
    if name.isEmpty {
        return Text("Hello anonymous!")
    } else {
        return Rectangle()
            .overlay(Text("Hello \(name)"))
    }
}
```

在 block 中使用如下的方式调用代码，可以在不影响构建器转译过程的情况下完成其他的工作：

```swift
@AttributedStringBuilder 
var myFirstText: AttributedString {
    let _ = print("update") // 声明语句不会影响构建器的转译
    AttributedString("Hello") 
    AttributedString("World")
}
```

### 添加 modifier

在继续完善构建器其他的方法之前，我们先为 AttributedStringBuilder 添加一些类似 SwiftUI 的 ViewModifier 功能，从而像 SwiftUI 那样方便的修改 AttributedString 的样式。添加下面的代码：

```swift
public extension AttributedString {
    func color(_ color: Color) -> AttributedString {
        then {
            $0.foregroundColor = color
        }
    }

    func bold() -> AttributedString {
        return then {
            if var inlinePresentationIntent = $0.inlinePresentationIntent {
                var container = AttributeContainer()
                inlinePresentationIntent.insert(.stronglyEmphasized)
                container.inlinePresentationIntent = inlinePresentationIntent
                let _ = $0.mergeAttributes(container)
            } else {
                $0.inlinePresentationIntent = .stronglyEmphasized
            }
        }
    }

    func italic() -> AttributedString {
        return then {
            if var inlinePresentationIntent = $0.inlinePresentationIntent {
                var container = AttributeContainer()
                inlinePresentationIntent.insert(.emphasized)
                container.inlinePresentationIntent = inlinePresentationIntent
                let _ = $0.mergeAttributes(container)
            } else {
                $0.inlinePresentationIntent = .emphasized
            }
        }
    }

    func then(_ perform: (inout Self) -> Void) -> Self {
        var result = self
        perform(&result)
        return result
    }
}
```

由于 AttributedString 是值类型，因此我们需要创建一个新的拷贝，并在其上修改属性。modifier 的使用方法如下：

```swift
@AttributedStringBuilder
var myFirstText: AttributedString {
    AttributedString("Hello")
         .color(.red)
    AttributedString("World")
         .color(.blue)
         .bold()
}
```

虽然只编写了很少的代码，但目前已经逐渐有了点 DSL 的感觉了。

### 简化表达

由于 block 只能接收特定类型的 component （ AttributedString ），因此每行代码都需要添加 AttributedString 的类型前缀，导致工作量大，同时也影响了阅读体验。通过使用 `buildExpression` 可以简化这一过程。

添加下面的代码：

```swift
public static func buildExpression(_ string: String) -> AttributedString {
    AttributedString(string)
}
```

构建器会将 String 首先转换成 AttributedString，然后再将其传入到 buildBlock 中。添加上述代码后，我们直接使用 String 替换掉 AttributedString：

```swift
@AttributedStringBuilder
var myFirstText: AttributedString {
    "Hello"
    "World"
}
```

不过，现在我们又面临了新问题 —— 无法在 block 中混合使用 String 和 AttributedString。这是因为，如果我们不提供自定义的 `buildExpression` 实现，构建器会通过 `buildBlock`推断出 component 的类型是 AttributedString 。一旦我们提供了自定义的 `buildExpression` ，构建器将不再使用自动推断。解决的方法就是为 AttributedString 也创建一个 `buildExpression` :

```swift
public static func buildExpression(_ attributedString: AttributedString) -> AttributedString {
    attributedString
}
```

现在就可以在 block 中混用两者了。

```swift
@AttributedStringBuilder
var myFirstText: AttributedString {
    "Hello"
    AttributedString("World")
}
```

另一个问题是，我们无法直接在 String 下使用我们之前创建的 modifier 。因为之前的 modifier 是针对 AttributedString 的，点语法将只能使用针对 String 的方法。解决方式有两种：一是扩展 String ，将其转换成 AttributedString，二是为 String 添加上 modifier 转换器。我们暂时先采用第二种较繁琐的方式：

```swift
public extension String {
    func color(_ color: Color) -> AttributedString {
        AttributedString(self)
            .color(color)
    }

    func bold() -> AttributedString {
        AttributedString(self)
            .bold()
    }
    
    func italic() -> AttributedString {
        AttributedString(self)
            .italic()
    }
}
```

现在，我们已经可以快速、清晰地进行声明了。

```swift
@AttributedStringBuilder
var myFirstText: AttributedString {
    "Hello"
         .color(.red)
    "World"
         .color(.blue)
         .bold()
}
```

AttributedString 提供了对本地化字符串以及部分 Markdown 语法的支持，但仅适用于通过 String.LocalizationValue 类型构造的 AttributedString ，可以通过如下的方式来解决这个问题：

```swift
public extension String {
    func localized() -> AttributedString {
        .init(localized: LocalizationValue(self))
    }
}
```

将字符串转换成采用 String.LocalizationValue 构造的 AttributedString，转换后将可直接使用为 AttributedString 编写的 modifier（你也可以对 String 采用类似的方式，从而避免为 String 重复编写 modifier）。

```swift
@AttributedStringBuilder
var myFirstText: AttributedString {
    "Hello"
         .color(.red)
    "~**World**~"
         .localized()
         .color(.blue)
         //.bold()    通过 Markdown 语法来描述粗体。当前在使用 Markdown 语法的情况下，直接对 inlinePresentationIntent 进行设置会有冲突。
}
```

![image-20220401090042983](https://cdn.fatbobman.com/image-20220401090042983.png)

### 构建器转译的逻辑

了解构建器是如何转译的，将有助于之后的学习。

```swift
@AttributedStringBuilder
var myFirstText: AttributedString {
    "Hello"
    AttributedString("World")
         .color(.red)
}
```

构建器在处理上面的代码时，将会转译成下面的代码：

```swift
var myFirstText: AttributedString {
    let _a = AttributedStringBuilder.buildExpression("Hello")  // 调用针对 String 的 buildExpression
    let _b = AttributedStringBuilder.buildExpression(AttributedString("World").color(.red)) // 调用针对 AtributedString 的 buildExpression
    return AttributedStringBuilder.buildBlock(_a,_b) // 调用支持多参数的 buildBloack
}
```

上下两段代码完全等价，Swift 会在幕后自动帮我们完成了这个过程。

> 在学习创建构建器时，通过在构建器方法的实现内部添加打印命令，有助于更好地掌握每个方法的调用时机。

### 添加选择语句支持（ 不带 else 的 if ）

result builders 在处理 `包含` 和 `不包含`  else 的选择语句时，采用了完全不同的内部处理机制。对于不包含 `else` 的 `if` 只需要实现下面的方法即可：

```swift
public static func buildOptional(_ component: AttributedString?) -> AttributedString {
    component ?? .init("")
}
```

构建器在调用该方法时，将视条件是否达成传入不同的参数。条件未达成时，传入 `nil` 。使用方法为：

```swift
var show = true
@AttributedStringBuilder
var myFirstText: AttributedString {
    "Hello"
    if show {
        "World"
    }
}
```

在添加了 `buildOptional` 的实现后，构建器也将同时支持 `if let` 语法，例如：

```swift
var name:String? = "fat"
@AttributedStringBuilder
var myFirstText: AttributedString {
    "Hello"
    if let name = name {
        " \(name)"
    }
}
```

`buildOptional` 对应的转译代码为：

```swift
// 上面的 if 代码对应的逻辑
var myFirstText: AttributedString {
    let _a = AttributedStringBuilder.buildExpression("Hello")
    var vCase0: AttributedString?
    if show == true {
        vCase0 = AttributedStringBuilder.buildExpression("World")
    }
    let _b = AttributedStringBuilder.buildOptional(vCase0)
    return AttributedStringBuilder.buildBlock(_a, _b)
}

// 上面的 if let 代码对应的逻辑
var myFirstText: AttributedString {
    let _a = AttributedStringBuilder.buildExpression("Hello")
    var vCase0:AttributedString?
    if let name = name {
        vCase0 = AttributedStringBuilder.buildExpression(name)
    }
    let _b = AttributedStringBuilder.buildOptional(vCase0)
    return AttributedStringBuilder.buildBlock(_a,_b)
}
```

这就是为什么只需要实现 `buildOptional` 即可同时支持 `if` ( 不包含 `else` ) 和 `if let`的原因。

```responser
id:1
```

### 添加对多分支选择的支持

对于 `if else` 以及 `switch` 语法，则需要实现 `buildEither(first:)` 和 `buildEither(second:)` 两个方法:

```swift
// 对条件为真的分支调用 （左侧分支）
public static func buildEither(first component: AttributedString) -> AttributedString {
    component
}

// 对条件为否的分支调用 （右侧分支）
public static func buildEither(second component: AttributedString) -> AttributedString {
    component
}
```

 使用方法如下：

```swift
var show = true
@AttributedStringBuilder
var myFirstText: AttributedString {
    if show {
        "Hello"
    } else {
        "World"
    }
}
```

对应的转译代码为：

```swift
var myFirstText: AttributedString {
    let vMerged: AttributedString
    if show {
        vMerged = AttributedStringBuilder.buildEither(first: AttributedStringBuilder.buildExpression("Hello"))
    } else {
        vMerged = AttributedStringBuilder.buildEither(second: AttributedStringBuilder.buildExpression("World"))
    }
    return AttributedStringBuilder.buildBlock(vMerged)
}
```

在包含 `else` 语句时，构建器在转译时将产生一个二叉树，每个结果都被分配到其中的一个叶子上。对于在 `if else` 中出现的不使用 `else` 的分支部分，构建器仍将通过 `buildOptional` 来处理，例如：

```swift
var show = true
var name = "fatbobman"
@AttributedStringBuilder
var myFirstText: Text {
    if show {
        "Hello"
    } else if name.count > 5 {
        name
    }
}
```

转译后的代码为：

```swift
// 转译后的代码
var myFirstText: AttributedString {
    let vMerged: AttributedString
    if show {
        vMerged = AttributedStringBuilder.buildEither(first: AttributedStringBuilder.buildExpression("Hello"))
    } else {
        // 首先使用 buildOptional 处理不包含 else 的情况
        var vCase0: AttributedString?
        if name.count > 5 {
            vCase0 = AttributedStringBuilder.buildExpression(name)
        }
        let _a = AttributedStringBuilder.buildOptional(vCase0)
        // 右侧分支最终汇总到 vMerged 上
        vMerged = AttributedStringBuilder.buildEither(second: _a)
    }
    return AttributedStringBuilder.buildBlock(vMerged)
}
```

对于 `switch` 的支持也是采用同样的方式。构建器在转译时，将递归地应用上述规则。

> 或许大家会奇怪， `buildEither` 的实现如此简单，并没有太大的意义。在 result builders 提案过程中也有不少人有这个疑问。其实 Swift 的这种设计有其相当合适的应用领域。在下一篇【 复制 ViewBuilder 】中，我们将看到 ViewBuilder 是如何通过 `buildEither` 来保存所有分支的类型信息。

### 支持 for...in 循环

`for...in` 语句将所有迭代的结果一并收集到一个数组中，并传递给 `buildArray`。提供 `buildArray` 的实现即可让构建器支持循环语句。

```swift
// 本例中，我们将所有的迭代结果直接连接起来，生成一个 AttributedString
public static func buildArray(_ components: [AttributedString]) -> AttributedString {
    components.reduce(into: AttributedString("")) { result, next in
        result.append(next)
    }
}
```

使用方式：

```swift
@AttributedStringBuilder
func test(count: Int) -> Text {
    for i in 0..<count {
        " \(i) "
    }
}
```

对应的转译代码：

```swift
func test(count: Int) -> AttributedString {
    var vArray = [AttributedString]()
    for i in 0..<count {
        vArray.append(AttributedStringBuilder.buildExpression(" \(i)"))
    }
    let _a = AttributedStringBuilder.buildArray(vArray)
    return AttributedStringBuilder.buildBlock(_a)
}
```

### 提高版本兼容性

如果提供了 `buildLimitedAvailability` 的实现，构建器提供了对 API 可用性检查（如 `if #available(..)`）的支持。这种情况在 SwiftUI 中很常见，例如某些 View 或 modifier 仅支持较新的平台，我们需要为不支持的平台提供其他的内容。

```swift
public static func buildLimitedAvailability(_ component: AttributedString) -> AttributedString {
    component
}
```

该方法并不会独立存在，它会和 `buildOptional` 或 `buildEither` 一并使用。当 API 可用性检查满足条件后， result builders 会调用该实现。在 SwiftUI 中，为了固定类型，使用了 AnyView 对类型进行了抹除。

使用方法：

```swift
// 创建一个当前平台不支持的方法
@available(macOS 13.0, iOS 16.0,*)
public extension AttributedString {
    func futureMethod() -> AttributedString {
        self
    }
}

@AttributedStringBuilder
var text: AttributedString {
    if #available(macOS 13.0, iOS 16.0, *) {
        AttributedString("Hello macOS 13")
            .futureMethod()
    } else {
        AttributedString("Hi Monterey")
    }
}
```

对应的转译逻辑为：

```swift
var text: AttributedString {
    let vMerge: AttributedString
    if #available(macOS 13.0, iOS 16.0, *) {
        let _temp = AttributedStringBuilder
            .buildLimitedAvailability( // 对类型或方法进行抹除
                AttributedStringBuilder.buildExpression(AttributedString("Hello macOS 13").futureMethod())
            )
        vMerge = AttributedStringBuilder.buildEither(first: _temp)
    } else {
        let _temp = AttributedStringBuilder.buildExpression(AttributedString("Hi Monterey"))
        vMerge = AttributedStringBuilder.buildEither(second: _temp)
    }
    return = AttributedStringBuilder.buildBlock(vMerge)
}
```

### 对结果再包装

如果我们提供了 `buildFinalResult` 的实现，构建器将在转译的最后，对结果使用 `buildFinalResult` 再度转换，并以 `buildFinalResult` 的返回值为最终的结果。

绝大多数情况下，我们无需实现 `buildFinalResult`，构建器会将 `buildBlock` 的返回作为最终的结果。

```swift
public static func buildFinalResult(_ component: AttributedString) -> Text {
    Text(component)
}
```

为了演示，本例中我们将 AttributedString 通过 `buildFinalResult` 转换为 Text ，使用方法：

```swift
@AttributedStringBuilder
var text: Text {  // 最终的结果类型已转译为 Text
    "Hello world"
}
```

对应的转译逻辑：

```swift
var text: Text {
    let _a = AttributedStringBuilder.buildExpression("Hello world")
    let _blockResult = AttributedStringBuilder.buildBlock(_a)
    return AttributedStringBuilder.buildFinalResult(_blockResult)
}
```

至此，我们已经实现了本节开始设定的目标。不过当前的实现仍无法为我们提供创建例如 SwiftUI 各种容器的可能性，这个问题将在范例二中得以解决。

## 范例二：AttributedTextBuilder

> 范例二的完整代码可以在 [此处](https://github.com/fatbobman/BlogCodes/tree/main/AttributedStringBuilder/AttributedStringBuilderDemo.playground) 获取（ Demo2 ）

### 版本一的不足

* 只能对 component（AttributedString、String）逐个添加 modifier，无法统一配置
* 无法动态布局，`buildBlock` 将所有的内容连接起来，想换行也只能通过单独添加 `\n` 来实现

### 使用协议代替类型

上述问题产生的主要原因为：上面的 `buildBlock` 的 component 是特定的 AttributedString 类型，限制了我们创建容器（其他的 component ）的能力。可以参照 SwiftUI View 的方案来解决上述不足，使用协议取代特定的类型，同时让 AttributedString 也符合该协议。

首先，我们将创建一个新的协议 —— AttributedText ：

```swift
public protocol AttributedText {
    var content: AttributedString { get }
    init(_ attributed: AttributedString)
}

extension AttributedString: AttributedText {
    public var content: AttributedString {
        self
    }

    public init(_ attributed: AttributedString) {
        self = attributed
    }
}
```

让 AttributedString 符合该协议：

```swift
extension AttributedString: AttributedText {
    public var content: AttributedString {
        self
    }

    public init(_ attributed: AttributedString) {
        self = attributed
    }
}
```

创建一个新的构建器 —— AttributedTextBuilder，它的最大变化就是将所有 component 的类型都改成了 AttributedText 。

```swift
@resultBuilder
public enum AttributedTextBuilder {
    public static func buildBlock() -> AttributedString {
        AttributedString("")
    }

    public static func buildBlock(_ components: AttributedText...) -> AttributedString {
        let result = components.map { $0.content }.reduce(into: AttributedString("")) { result, next in
            result.append(next)
        }
        return result.content
    }

    public static func buildExpression(_ attributedString: AttributedText) -> AttributedString {
        attributedString.content
    }

    public static func buildExpression(_ string: String) -> AttributedString {
        AttributedString(string)
    }

    public static func buildOptional(_ component: AttributedText?) -> AttributedString {
        component?.content ?? .init("")
    }

    public static func buildEither(first component: AttributedText) -> AttributedString {
        component.content
    }

    public static func buildEither(second component: AttributedText) -> AttributedString {
        component.content
    }

    public static func buildArray(_ components: [AttributedText]) -> AttributedString {
        let result = components.map { $0.content }.reduce(into: AttributedString("")) { result, next in
            result.append(next)
        }
        return result.content
    }

    public static func buildLimitedAvailability(_ component: AttributedText) -> AttributedString {
        .init("")
    }
}
```

为 AttributedText 创建 modifier ：

```swift
public extension AttributedText {
    func transform(_ perform: (inout AttributedString) -> Void) -> Self {
        var attributedString = self.content
        perform(&attributedString)
        return Self(attributedString)
    }

    func color(_ color: Color) -> AttributedText {
        transform {
            $0 = $0.color(color)
        }
    }

    func bold() -> AttributedText {
        transform {
            $0 = $0.bold()
        }
    }

    func italic() -> AttributedText {
        transform {
            $0 = $0.italic()
        }
    }
}
```

至此我们便拥有了类似在 SwiftUI 中创建自定义视图控件的能力。

### 创建 Container

Container 类似 SwiftUI 中的 Group ，不改变布局，方便对 Container 内的元素统一设置 modifier。

```swift
public struct Container: AttributedText {
    public var content: AttributedString

    public init(_ attributed: AttributedString) {
        content = attributed
    }

    public init(@AttributedTextBuilder _ attributedText: () -> AttributedText) {
        self.content = attributedText().content
    }
}
```

由于 Container 也符合 AttributedText 协议，因此将被视为 component，并且可以对其应用 modifier 。使用方法：

```swift
@AttributedTextBuilder
var attributedText: AttributedText {
    Container {
        "Hello "
            .localized()
            .color(.red)
            .bold()

        "~World~"
            .localized()
    }
    .color(.green)
    .italic()
}
```

此时执行上面的代码，你会发现，原来红色的 Hello 也变成了绿色的，这与我们预期的不一样。在 SwiftUI 中，内层的设定应优先于外层的设定。为了解决这个问题，我们需要对 AttributedString 的 modifier 做一些修改。

```swift
public extension AttributedString {
    func color(_ color: Color) -> AttributedString {
        var container = AttributeContainer()
        container.foregroundColor = color
        return then {
            for run in $0.runs {
                $0[run.range].mergeAttributes(container, mergePolicy: .keepCurrent)
            }
        }
    }

    func bold() -> AttributedString {
        return then {
            for run in $0.runs {
                if var inlinePresentationIntent = run.inlinePresentationIntent {
                    var container = AttributeContainer()
                    inlinePresentationIntent.insert(.stronglyEmphasized)
                    container.inlinePresentationIntent = inlinePresentationIntent
                    let _ = $0[run.range].mergeAttributes(container)
                } else {
                    $0[run.range].inlinePresentationIntent = .stronglyEmphasized
                }
            }
        }
    }

    func italic() -> AttributedString {
        return then {
            for run in $0.runs {
                if var inlinePresentationIntent = run.inlinePresentationIntent {
                    var container = AttributeContainer()
                    inlinePresentationIntent.insert(.emphasized)
                    container.inlinePresentationIntent = inlinePresentationIntent
                    let _ = $0[run.range].mergeAttributes(container)
                } else {
                    $0[run.range].inlinePresentationIntent = .emphasized
                }
            }
        }
    }

    func then(_ perform: (inout Self) -> Void) -> Self {
        var result = self
        perform(&result)
        return result
    }
}
```

通过遍历 AttributedString 的 run 视图，我们实现了同一属性的内层设定优先于外层设定。

### 创建 Paragraph

Paragraph 会在其中内容的首尾创建换行。

```swift
public struct Paragraph: AttributedText {
    public var content: AttributedString
    public init(_ attributed: AttributedString) {
        content = attributed
    }

    public init(@AttributedTextBuilder _ attributedText: () -> AttributedText) {
        self.content = "\n" + attributedText().content + "\n"
    }
}
```

通过将协议作为 component ，为构建器提供了更多的可能性。

## Result builders 的改进与不足

### 已完成的改进

从 Swift 5.1 开始，result builders 已经过几个版本的改进，增加了部分功能同时也解决了部分的性能问题：

* 添加了`buildOptional` 并取消了 `buildeIf`，在保留了对 `if` （不包含 `else` ）支持的同时，增加了对 `if let` 的支持
* 从 SwiftUI 2.0 版本开始支持了 `switch` 关键字
* 修改了 Swift 5.1 版本的 `buildBlock` 的语法转译机制。禁止了参数类型的“向后”传播。这是导致早期 SwiftUI 视图代码总出现“ expression too complex to be solved in a reasonable time ” 编译错误的首要原因

### 当前的不足

* 欠缺部分选择和控制能力，如： guard 、break 、continue

* 缺乏将命名限制在构建器上下文内能力

  对于 DSL 来说，引入速记词是很常见的情况，当前为构建器创建 component ，只能采用创建新的数据类型（例如上文中的：Container、Paragraph ）或全局函数的形式。希望将来可以让这些命名仅限制在上下文之内，不将其引入全局范围。

## 后续

Result builders 的基本功能非常简单，上文中，我们仅有少量的代码是有关构建器方法的。但想创建一个好用、易用的 DSL 则需要付出巨大的工作量，开发者应根据自己的实际需求来衡量使用 result builders 的得失。

在下篇中，我们将尝试复制一个与 ViewBuilder 基本形态一致的构建器，相信复制的过程能让你对 ViewBuilder 以及 SwiftUI 视图有更深的理解和认识。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。

