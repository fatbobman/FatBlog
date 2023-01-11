---
date: 2021-10-12 13:30
description: SwiftUI 的 TextField 可能是开发者在应用程序中最常使用的文本录入组件了。作为 UITextField（NSTextField）的 SwiftUI 封装，苹果为开发者提供了众多的构造方法和修饰符以提高其使用的便利性、定制性。但 SwiftUI 在封装中也屏蔽了不少的高级接口和功能，增加了开发者实现某些特定需要的复杂性。本文为【SwiftUI 进阶】系列文章中的一篇，在本文中，我将介绍如何在 TextField 中实现如下功能：屏蔽无效字符、判断录入的内容是否满足特定条件、对录入的文本实时格式化显示。
tags: SwiftUI
title: SwiftUI TextField 进阶——格式与校验
image: images/textfieldDemo1.gif
---
SwiftUI 的 TextField 可能是开发者在应用程序中最常使用的文本录入组件了。作为 UITextField（NSTextField）的 SwiftUI 封装，苹果为开发者提供了众多的构造方法和修饰符以提高其使用的便利性、定制性。但 SwiftUI 在封装中也屏蔽了不少的高级接口和功能，增加了开发者实现某些特定需要的复杂性。本文为【SwiftUI 进阶】系列文章中的一篇，在本文中，我将介绍如何在 TextField 中实现如下功能：

* 屏蔽无效字符
* 判断录入的内容是否满足特定条件
* 对录入的文本实时格式化显示

![textfieldDemo1](https://cdn.fatbobman.com/textfieldDemo1-3998601.gif)

> 本文的目的并非提供一个通用的解决方案，而是通过探讨几种思路，让读者可以在面对类似需求时有迹可循。

```responser
id:1
```

## 为什么不自己封装新的实现 ##

对于很多从 UIKit 转到 SwiftUI 的开发者，当遇到 SwiftUI 官方 API 功能无法满足某些需求的情况下，非常自然地会想通过 UIViewRepresentable 来封装自己的实现（参阅 [在 SwiftUI 中使用 UIKit 视图](https://www.fatbobman.com/posts/uikitInSwiftUI/) 了解更多内容）。在 SwiftUI 早期，这确实是十分有效的手段。不过随着 SwiftUI 的逐渐成熟，苹果为 SwiftUI 的 API 提供了大量独有功能。如果仅为了某些需求而放弃使用官方的 SwiftUI 方案有些得不偿失。

因此，在最近几个月的时间里，我逐渐抛弃了通过自行封装或使用其他第三方扩展库来实现某些需求思路。在为 SwiftUI 增加新功能时，要求自己尽量遵守以下原则：

* 优先考虑能否在 SwiftUI 原生方法中找到解决手段
* 如确需采用非原生方法，尽量采用非破坏性的实现，新增功能不能以牺牲原有功能为代价（需兼容官方的 SwiftUI 修饰方法）

以上原则，在 [SheetKit——SwiftUI 模态视图扩展库](https://www.fatbobman.com/posts/sheetKit/) 和 [用 NavigationViewKit 增强 SwiftUI 的导航视图](https://www.fatbobman.com/posts/NavigationViewKit/) 中均有体现。

## 如何在 TextField 中实现格式化显示 ##

### 现有格式化方法 ###

在 SwiftUI 3.0 中，TextField 新增了使用新老两种 Formatter 的构造方法。开发可以直接使用非 String 类型的数据（如整数、浮点数、日期等），通过 Formatter 来格式化录入的内容。例如：

```swift
struct FormatterDemo:View{
    @State var number = 100
    var body: some View{
        Form{
            TextField("inputNumber",value:$number,format: .number)
        }
    }
}
```

![textFieldDemo2](https://cdn.fatbobman.com/textFieldDemo2.gif)

不过非常遗憾的是，尽管我们可以设置最终格式化的样式，但是 TextField 并不能在文字录入过程中对文本进行格式化显示。只有当触发 submit 状态（commit）或失去焦点时，才会对文本进行格式化。行为与我们的最初的需求有一定差距。

### 可能的格式化解决思路 ###

* 在录入过程中激活 TextField 内置的 Formatter，让其能够在文本发生变化时对内容进行格式化
* 在文本发生变化时调用自己实现的 Format 方法，对内容进行实时格式化

对于第一种思路，目前我们可以采用一种非正常手段即可激活实时格式化——替换或取消掉当前的 TextFiled 的 delegate 对象。

```swift
            TextField("inputNumber",value:$number,format: .number)
                .introspectTextField{ td in
                    td.delegate = nil
                }
```

上面的代码通过 [SwiftUI-Introspect](https://github.com/siteline/SwiftUI-Introspect) 实现了对指定的 TextField 身后对应的 UITextField 的 delegate 替换，即可完成实时格式化的激活工作。本文的方案一便是这种思路的具体实现。

第二种思路，则是不使用黑魔法，仅通过 SwiftUI 的原生方式，在录入文本发生变化时，对文本进行格式化。本文的方案二是该思路的具体实现。

## 如何在 TextField 中屏蔽无效字符 ##

### 现有屏蔽字符方法 ###

在 SwiftUI 中，可以通过设置仅使用特定的键盘类型来实现一定程度上的录入限制。比如，下面的代码将仅允许用户录入数字：

```swift
TextField("inputNumber",value:$number,format: .number)
    .keyboardType(.numberPad)
```

然而，上述方案还是有相当的局限性的。

* 只支持部分类型的设备
* 支持的键盘类型有限

例如在 iPad 下 keyboardType 是无效的，在苹果鼓励应用程序对多设备类型支持的今天，让用户在不同的设备上享受到相同的体验至关重要。

另外，由于其支持键盘类型有限，在很多的应用场合都捉襟见肘。最典型的例子就是`numberPad`是不支持`负号`的，意味着它仅能适用于正整数。有些开发者可以通过自定义键盘或添加`inputAccessoryView`来解决，但对于其他没有能力或精力的开发者来说，如果能直接对录入的无效字符进行屏蔽则也是不错的解决方案。

### 可能的屏蔽字符解决思路 ###

* 使用 UITextFieldDelegate 的`textField`方法
* 在 SwiftUI 的视图中，使用`onChange`在录入发生变化时进行判断并修改

第一种思路，仍需使用 Introspect 之类的方式，对 TextField 身后的 UITextField 进行侵入，替换掉它原有的`textField`方法，在其中进行字符判断。实践中，这种方式是最高效的手段，因为该判断发生在字符被 UITextField 确认之前，如果我们发现新添加的`string`不满足我们的设定的录入要求，可以直接返回 false，则最近录入的字符将不会显示在录入框中。

```swift
func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // 检查 string 是否满足条件
        if 满足条件 { return true } // 将新增字符添加到输入框
        else { return false}
 }
```

但是通过 Delegate 的方法，我们并不能选择保留部分字符，也就是说要不全部接受、要不都不接受（如果自行包装 UITextField，我们可以实现任何逻辑）。方案一采用了本思路。

第二种思路我们是支持选择性保存的，但是其也有局限性。由于 TextField 的 Formatter 构造方法采用了特别的包装方式，我们无法获得绑定值不是`String`时（例如整数、浮点数、日期等）的录入框内容的。因此，采用这种思路，我们只能使用字符串作为绑定类型，将无法享受到 SwiftUI 新的构造方法带来的便捷性。方案二采用了该思路。

## 如何在 TextField 中检查内容是否符合指定条件 ##

相较上述两个目标，在 SwiftUI 中检查 TextField 内容是否符合指定条件是相当方便的。例如：

```swift
TextField("inputNumber", value: $number, format: .number)
                .foregroundColor(number < 100 ? .red : .primary)
```

*上面的代码在录入的数字小于 100 时会将文字显示颜色设置为红色。*

当然，我么也可以延续上面方案的思路，在 delegate 的`textfield`方法中对文本进行判断。不过这种方式对类型的适用性不强（非`String`类型需转换）。

## 其他需要注意的问题 ##

在使用上面的思路进行实际编程前，我们还需要考虑其他几个问题：

### 本地化 ###

本文提供的 [演示代码](https://github.com/fatbobman/TextFieldFomatAndValidateDemo) 中实现了对`Int`和`Double`两种类型的实时处理。尽管这两种类型基本上都是以数字为主，但在处理时仍需注意本地化问题。

对于不同地区的数字，其小数点和组分隔符可能是不一样的，例如：

```swift
1,000,000.012 // 大多数地区
1 000 000,012 // fr
```

因此，在判断有效字符时，我们需要通过 Locale 来获取该地区的`decimalSeparator`和`groupingSeparator`。

如果你需要判断的是日期或其他自定义格式数据，最好也在代码中提供针对本地化字符的处理过程。

### Formatter ###

SwiftUI 的 TextField 目前对新老两种 Formatter 都提供了对应的构造方法。我倾向于使用新的 Formatter API。其为旧 Formatter API 的 Swift 原生实现，提供了更便捷、更安全的的声明方式。关于新 Formatter 的更多资料请阅读 [WWDC 2021 新 Formatter API：新老比较及如何自定义](https://www.fatbobman.com/posts/newFormatter/)。

不过，TextField 对新 Formatter 的支持目前仍有部分问题，因此在编写代码时需特别注意。例如

```swift
@State var number = 100 
TextField("inputNumber", value: $number, format: .number)
```

在绑定值为`Int`的情况下，当录入的数字超多 19 个字符将产生溢出，导致程序崩溃（已提交 FB，估计之后的版本会有修正）。好在本文的演示代码中，提供了对录入字符数量的限制，可以暂时解决这个问题。

### 易用性 ###

如果仅实现本文最初设定的目标其实并不复杂，不过实现方式最好能提供方便的调用手段并减少对原有代码的污染。

例如，下面的代码为方案一和方案二的调用方式。

```swift
// 方案一
let intDelegate = ValidationDelegate(type: .int, maxLength: 6)

TextField("0...1000", value: $intValue, format: .number)
       .addTextFieldDelegate(delegate: intDelegate)
       .numberValidator(value: intValue) { $0 < 0 || $0 > 1000 }

// 方案二
@StateObject var intStore = NumberStore(text: "",
                                        type: .int,
                                        maxLength: 5,
                                        allowNagative: true,
                                        formatter: IntegerFormatStyle<Int>())

TextField("-1000...1000", text: $intStore.text)
       .formatAndValidate(intStore) { $0 < -1000 || $0 > 1000 }
```

以上调用方法仍有很大的优化和集成的空间，例如对 TextField 二度包装（采用 View），在方案二使用属性包装器对数字和字符串进行桥接等。

## 方案一 ##

> 可以在 [Github](https://github.com/fatbobman/TextFieldFomatAndValidateDemo) 上下载本文的 Demo 代码。文章中仅对部分代码进行说明，完整的实现请参照源代码。

方案一使用 TextField 的新 Formatter 构造方法：

```swift
public init<F>(_ titleKey: LocalizedStringKey, value: Binding<F.FormatInput>, format: F, prompt: Text? = nil) where F : ParseableFormatStyle, F.FormatOutput == String
```

通过替换 delegate 来激活 TextField 内置的 Format 机制，在 delegte 的`textfield`方法中屏蔽无效字符。

屏蔽无效字符：

```swift
func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let text = textField.text ?? ""
        return validator(text: text, replacementString: string)
    }

private func validator(text: String, replacementString string: String) -> Bool {
        // 判断有效字符
        guard string.allSatisfy({ characters.contains($0) }) else { return false }
        let totalText = text + string

        // 检查小数点
        if type == .double, text.contains(decimalSeparator), string.contains(decimalSeparator) {
            return false
        }

        // 检查负号
        let minusCount = totalText.components(separatedBy: minusCharacter).count - 1

        if minusCount > 1 {
            return false
        }
        if minusCount == 1, !totalText.hasPrefix("-") {
            return false
        }

        // 检查长度
        guard totalText.count < maxLength + minusCount else {
            return false
        }
        return true
}
```

其中需要注意的是，不同的 Locale 将提供不同的有效字符集（`characters`）。

添加 View 扩展

```swift
extension View {
    // 根据是否满足指定条件调整文字颜色
    func numberValidator<T: Numeric>(value: T, errorCondition: (T) -> Bool) -> some View {
        foregroundColor(errorCondition(value) ? .red : .primary)
    }
    // 替换 delegate
    func addTextFieldDelegate(delegate: UITextFieldDelegate) -> some View {
        introspectTextField { td in
            td.delegate = delegate
        }
    }
}
```

## 方案二 ##

方案二，采用了 SwiftUI 原生的方法来实现同样的目标，由于无法利用 TextField 内置的 Formatter、原始文本等功能，因此实现上要比方案一复杂一些。另外，为了能够实时校验录入字符，因此只能采用字符串类型作为 TextField 的绑定类型，在调用上也比方案一略显复杂（可以通过再次包装做进一步简化）。

为了保存一些暂存数据，我们需要创建一个符合 ObservableObejct 的类，来对数据进行统一管理

```swift
class NumberStore<T: Numeric, F: ParseableFormatStyle>: ObservableObject where F.FormatOutput == String, F.FormatInput == T {
    @Published var text: String
    let type: ValidationType
    let maxLength: Int
    let allowNagative: Bool
    private var backupText: String
    var error: Bool = false
    private let locale: Locale
    let formatter: F

    init(text: String = "",
         type: ValidationType,
         maxLength: Int = 18,
         allowNagative: Bool = false,
         formatter: F,
         locale: Locale = .current)
    {
        self.text = text
        self.type = type
        self.allowNagative = allowNagative
        self.formatter = formatter
        self.locale = locale
        backupText = text
        self.maxLength = maxLength == .max ? .max - 1 : maxLength
    }
```

formatter 传递给`NumberStore`，并在`getValue`中调用。

```swift
// 返回验证后的数字
    func getValue() -> T? {
        // 特殊处理（无内容、只有负号、浮点数首字母为小数点）
        if text.isEmpty || text == minusCharacter || (type == .double && text == decimalSeparator) {
            backup()
            return nil
        }

        // 用去除组分隔符后的字符串判断字符是否有效
        let pureText = text.replacingOccurrences(of: groupingSeparator, with: "")
        guard pureText.allSatisfy({ characters.contains($0) }) else {
            restore()
            return nil
        }

        // 处理多个小数点情况
        if type == .double {
            if text.components(separatedBy: decimalSeparator).count > 2 {
                restore()
                return nil
            }
        }

        // 多个负号情况
        if minusCount > 1 {
            restore()
            return nil
        }

        // 负号必须为首字母
        if minusCount == 1, !text.hasPrefix("-") {
            restore()
            return nil
        }

        // 判断长度
        guard text.count < maxLength + minusCount else {
            restore()
            return nil
        }

        // 将文字转换成数字，然后再转换为文字（保证文字格式正确）
        if let value = try? formatter.parseStrategy.parse(text) {
            let hasDecimalCharacter = text.contains(decimalSeparator)
            text = formatter.format(value)
            // 保护最后的小数点（不特别处理的话，转换回来的文字可能不包含小数点）
            if hasDecimalCharacter, !text.contains(decimalSeparator) {
                text.append(decimalSeparator)
            }
            backup()
            return value
        } else {
            restore()
            return nil
        }
    }

```

在方案二中，除了需要屏蔽无效字符外，我们还需要自己处理 Format 的实现。新的 Formatter API 对字符串的容错能力非常好，因此，将文本先通过 parseStrategy 转换成数值，然后再转换成标准的字符串将能够保证 TextField 中的文字始终保持正确的显示。

另外，需要考虑到首字符为`-`以及最后字符为小数点的情况，因为 parseStrategy 会在转换后丢失这些信息，我们需要在最终的转换结果中重现这些字符。

View 扩展

```swift
extension View {
    @ViewBuilder
    func formatAndValidate<T: Numeric, F: ParseableFormatStyle>(_ numberStore: NumberStore<T, F>, errorCondition: @escaping (T) -> Bool) -> some View {
        onChange(of: numberStore.text) { text in
            if let value = numberStore.getValue(),!errorCondition(value) {
                numberStore.error = false // 通过 NumberStore 转存校验状态
            } else if text.isEmpty || text == numberStore.minusCharacter {
                numberStore.error = false
            } else { numberStore.error = true }
        }
        .foregroundColor(numberStore.error ? .red : .primary)
        .disableAutocorrection(true)
        .autocapitalization(.none)
        .onSubmit { // 处理只有一个小数点的情况
            if numberStore.text.count > 1 && numberStore.text.suffix(1) == numberStore.decimalSeparator {
                numberStore.text.removeLast()
            }
        }
    }
}
```

同方案一将处理逻辑分散到多个的代码部分不同，方案二中，所有的逻辑都是在`onChange`中激发调用的。

由于`onChange`是在文字发生变化后才会调用，因此，方案二会导致视图二度刷新，不过考虑到文字录入的应用场景，性能损失可以忽略（ 如使用属性包装器进一步对数值同字符串进行链接，可能会进一步增加视图的刷新次数）。

> 可以在 [Github](https://github.com/fatbobman/TextFieldFomatAndValidateDemo) 上下载本文的 Demo 代码。

## 两种方案的比较 ##

* 效率

  由于方案一在每次录入时仅需刷新一次视图，因此理论上其执行效率要高于方案二，不过在实际使用中，二者都可以提供流畅、及时的交互效果。

* 支持的类型种类

  方案一可以直接使用多种数据类型，方案二中需在 TextField 的构造方法中将原始数值转换成对应格式的字符串。方案二的演示代码中，可以通过`result`获取字符串对应的数值。

* 可选值支持

  方案一采用的 TextField 构造方法（支持 formatter）并不支持可选值类型，必须要提供初始值。不利于判断用户是否录入新的信息（更多的信息可参阅 [如何在 SwiftUI 中创建一个实时响应的 Form](https://www.fatbobman.com/posts/swiftui-input-form/)）。

  方案二中允许不提供初始值，支持可选值。

  另外，在方案一中如果将所有的字符都清空，绑定变量仍将有数值（原 API 行为），容易造成用户在录入时的困惑。

* 可持续性（SwiftUI 向后兼容性）

  方案二由于完全采用 SwiftUI 方式编写，因此其可持续性从理论上应强于方案一。不过除非 SwiftUI 对背后的实现逻辑进行了较大修改，否则方案一在最近几个版本中仍会正常运行，而且方案一可以支持更早版本的 SwiftUI。

* 对其他修饰方法的兼容性

  无论方案一还是方案二都满足了本文之前提出的对官方 API 的完全兼容，在没有损失的情况下获得了其他功能的提升。

## 总结 ##

每个开发者都希望为用户提供一个高效、优雅的交互环境。本文仅涉及了 TextField 的部分内容，在【SwiftUI TextField 进阶】的其他篇幅中，我们将探讨更多的技巧和思路，让开发者在 SwiftUI 中创建不一样的文本录入体验。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。

