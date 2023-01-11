---
date: 2021-08-23 11:12
description: 本文将通过对 UITextField 的包装来讲解如何在 SwiftUI 中使用 UIKit 视图、如何让你的 UIKit 包装视图具有 SwiftUI 风格、在 SwiftUI 使用 UIKit 视图需要注意的地方
tags: SwiftUI,UIKit
title:  在 SwiftUI 中使用 UIKit 视图
---
已迈入第三个年头的 SwiftUI 相较诞生初始已经提供了更多的原生功能，但仍有大量的事情是无法直接通过原生 SwiftUI 代码来完成的。在相当长的时间中开发者仍需在 SwiftUI 中依赖 UIKit（AppKit）代码。好在，SwiftUI 为开发者提供了便捷的方式将 UIKit（AppKit）视图（或控制器）包装成 SwiftUI 视图。

本文将通过对 UITextField 的包装来讲解以下几点：

* 如何在 SwiftUI 中使用 UIKit 视图
* 如何让你的 UIKit 包装视图具有 SwiftUI 风格
* 在 SwiftUI 使用 UIKit 视图需要注意的地方

> **如果你已经对如何使用`UIViewRepresentable`有所掌握，可以直接从`SwiftUI 风格化`部分阅读**

```responser
id:1
```

## 基础 ##

在具体演示包装代码之前，我们先介绍一些与在 SwiftUI 中使用 UIKit 视图有关的基础知识。

> 无需担心是否能立即理解下述内容，在后续的演示中会有更多的内容帮助你掌握相关知识。

### 生命周期 ###

SwiftUI 同 UIKit 和 AppKit 的主要区别之一是，SwiftUI 的视图（View）是值类型，并不是对屏幕上绘制内容的具体引用。在 SwiftUI 中，开发者为视图创建描述，而并不实际渲染它们。

在 UIKit（或 AppKit）中，视图（或视图控制器）有明确的生命周期节点，比如`vidwDidload`、`loadView`、`viewWillAppear`、`didAddSubView`、`didMoveToSuperview`等方法，它们本质上充当了钩子的角色，让开发者能够通过执行一段逻辑来响应系统给定的事件。

SwiftUI 的视图，本身没有清晰（可适当描述）的生命周期，它们是值、是声明。SwiftUI 提供了几个修改器（modifier）来实现类似 UIKit 中钩子方法的行为。比如`onAppear`同`viewWillAppear`的表现很类似。同 UIKit 的钩子方法的位置有很大的不同，`onAppear`和`onDisappear`是在当前视图的父视图上声明的。

将 UIKit 视图包装成 SwiftUI 的视图时，我们需要了解两者生命周期之间的不同，不要强行试图找到完全对应的方法，要从 SwiftUI 的角度来思考如何调用 UIKit 视图。

### UIViewRepresentable 协议 ###

在 SwiftUI 中包装 UIView 非常简单，只需要创建一个遵守`UIViewRepresentable`协议的结构体就行了。

> `UIViewControllerRepresentable`对应`UIViewController`，`NSViewRepresentable`对应`NSView`，`NSViewControllerRepresentable`对应`NSViewController`。内部的结构和实现逻辑都一致。

`UIViewrepresentable`的协议并不复杂，只包含：`makeUIView`、`updateUIView`、`dismantleUIView`和`makeCoordinator`四个方法。`makeUIView`和`updateUIView`为必须提供实现的方法。

`UIViewRepresentable`本身遵守`View`协议，因此 SwiftUI 会将任何符合该协议的结构体都当作一般的 SwiftUI 视图来对待。不过由于`UIViewRepresentable`的特殊的用途，其内部的生命周期又同标准的 SwiftUI 视图有所不同。

![UIViewRepresentableLifeCycle](https://cdn.fatbobman.com/UIViewRepresentableLifeCycle-9614888.png)

* makeCoordinator

  如果我们声明了 Coordinator（协调器）,`UIViewRepresentable`视图会在初始化后首先创建它的实例，以便在其他的方法中调用。Coordinator 默认为`Void`，该方法在`UIViewRepresentable`的生命周期中只会调用一次，因此只会创建一个协调器实例。

* makeUIView

  创建一个用来包装的 UIKit 视图实例。该方法在`UIViewRepresentable`的生命周期中只会调用一次。

* updateUIView

  SwiftUI 会在应用程序的状态（State）发生变化时更新受这些变化影响的界面部分。当`UIViewRepresentable`视图中的注入依赖发生变化时，SwiftUI 会调用`updateUIView`。其调用时机同标准 SwiftUI 视图的`body`一致，最大的不同为，调用`body`为计算值，而调用`updateview`仅为通知`UIViewRepresentable`视图依赖有变化，至于是否需要根据这些变化来做反应，则由开发者来自行处理。

  该方法在`UIViewRepresentable`的生命周期中会多次调用，直到视图被移出视图树（更准确地描述是切换到另一个不包含该视图的视图树分支）。

  **在 makeUIVIew 执行后，updateUIVew 必然会执行一次**

* dismantleUIView

  在`UIViewRepresentable`视图被移出视图树之前，SwiftUI 会调用`dismantleUIView`，通常在此方法中可以执行 u 删除观察器等善后操作。`dismantleUIView`为类型方法。

下面的代码将创建一个同 ProgressView 一样的转圈菊花：

```swift
struct MyProgrssView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let view = UIActivityIndicatorView()
        view.startAnimating()
        return view
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {}
}

struct Demo: View {
    var body: some View {
            MyProgrssView()
    }
}
```

### 黑匣子 ###

SwiftUI 在绘制屏幕时，会从视图树的顶端开始对视图的`body`求值，如果其中还包含子视图则将递归求值，直到获得最终的结果。但 SwiftUI 无法真正进行无限量的调用来绘制视图，因此它必须以某种方式缩短递归。为了结束递归，SwiftUI 包含了很多的原始类型（primitive types）。当 SwiftUI 递归到这些原始类型时，将结束递归，它将不再关心原始类型的`body`，而让原始类型自行对其管理的区域进行处理。

SwiftUI 框架通过将`body`定义为`Never`来标记该`View`为原始类型。`UIViewRepresentable`恰巧也为其中之一（`Text`、`ZStack`、`Color`、`List`等也都是所谓的原始类型）。

```swift
public protocol UIViewRepresentable : View where Self.Body == Never
```

事实上几乎所有的原始类型都是对 UIKit 或 AppKit 的底层包装。

`UIViewRepresentable`作为原始类型，SwiftUI 对其内部所知甚少（因为无需关心）。通常需要开发者在`UIViewRepresentable`视图的 Coordinator（协调器）中做一些的工作，从而保证两个框架（SwiftUI 同 UIKit）代码之间的沟通和联系。

### 协调器 ###

苹果框架很喜欢使用协调器（Coordinator）这个名词，UIKit 开发中有协调器设计模式、Core Data 中有持久化存储协调器。在`UIViewRepresentable`中协调器同它们的概念完全不同，主要起到以下几个方面的作用：

* 实现 UIKit 视图的代理

  UIKit 组件通常依赖代理（delegate）来实现一些功能，“代理”是响应其他地方发生的事件的对象。例如，UIKit 中我们将一个代理对象附加到`Text field`视图上，当用户输入时，当用户按下`return`键时，该代理对象中对应的方法将被调用。通过将协调器声明为 UIKit 视图对应的代理对象，我们就可以在其中实现所需的代理方法。

* 同 SwiftUI 框架保持沟通

  上文中，我们提到`UIViewRepresentable`作为原始类型，需要主动承担更多的同 SwiftUI 框架或其他视图之间的沟通工作。在协调器中，我们可以通过双向绑定（`Binding`），通知中心（`notificationCenter`）或其他例如`Redux`模式的单项数据流等方式，将 UIKit 视图内部的状态报告给 SwiftUI 框架或其他需要的模块。同样也可以通过注册观察器、订阅 Publisher 等方式获取所需的信息。

* 处理 UIKit 视图中的复杂逻辑

  在 UIKit 开发中，通常会将业务逻辑放置在 UIViewController 中，SwiftUI 没有 Controller 这个概念，视图仅是状态的呈现。对于一些实现复杂功能的 UIKit 模组，如果完全按照 SwiftUI 的模式将其业务逻辑彻底剥离是非常困难的。因此将无法剥离的业务逻辑的实现代码放入协调器中，靠近代理方法，便于相互之间的协调和管理。

## 包装 UITextField ##

本节中我们将利用上面的知识实现一个具有简单功能的`UITextField`包装视图——`TextFieldWrapper`。

### 版本 1.0 ###

在第一个版本中，我们要实现一个类似如下原生代码的功能：

```swift
TextField("name:",text:$name)
```

![image-20210822184949860](https://cdn.fatbobman.com/image-20210822184949860-9629391.png)

查看 [源代码](https://gist.github.com/733f3c8ef4c69a1e4ed4bd81bf4750e3.git)

我们在`makeUIView`中创建了`UITextField`的实例，并对其 placeholder 和 text 进行了设定。在右侧的预览中，我们可以看到 placeholder 可以正常显示，如果你在其中输入文字，表现的状态也同`TextField`完全一致。

通过`.border`，我们看到 TextFieldWrapper 的视图尺寸没有符合预期，这是由于 UITextField 在不进行约束的情况下会默认占据全部可用空间。上文关于`UIActivityIndicatorView`的演示代码并没有出现这个情况。因此对于不同的 UIKit 组件，我们需要了解其默认设置，酌情对其进行约束设定。

在`makeUIView`中添加如下语句，此时文本输入框的尺寸就和预期一致了：

```swift
        textfield.setContentHuggingPriority(.defaultHigh, for: .vertical)
        textfield.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
```

稍微调整一下`Demo`视图，在`.padding()`下添加`Text("name:\(name)")`。如果按照`TextField`的正常行为，当我们在其中输入任何文本时，下方的`Text`中应该显示出对应的内容，不过在我们当前的代码版本中，并没有表现出预期的行为。

![image-20210822190605447](https://cdn.fatbobman.com/image-20210822190605447-9630366.png)

让我们再次来分析一下代码。

尽管我们声明了一个`Binding<String>`类型的`text`，并且在`makeUIView`中将其赋值给了`textfield`，不过`UITextField`并不会将我们录入的内容自动回传给`Binding<String>`的`text`，这导致`Demo`视图中的`name`并不会因为文字录入而发生改变。

`UITextfield`在每次录入文字时，都会自动调用`func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool`的代理方法。因此我们需要创建协调器，并在协调器中实现该方法，将录入的内容传递给`Demo`视图中的`name`变量。

创建协调器：

```swift
extension TextFieldWrapper{
    class Coordinator:NSObject,UITextFieldDelegate{
        @Binding var text:String
        init(text:Binding<String>){
            self._text = text
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            if let text = textField.text as NSString? {
                let finaltext = text.replacingCharacters(in: range, with: string)
                self.text = finaltext as String
            }
            return true
        }
    }
}
```

我们需要在`textField`方法中回传数据，因此在`Coordinator`中同样需要使用到`Binding<String>`，如此对`text`的操作即为对`Demo`视图中`name`的操作。

如果`UIViewRepresentable`视图中的`Coordinator`不为`Void`，则必须通过`makeCoordinator`来创建它的实例。在`TextFieldWrapper`中添加如下代码：

```swift
    func makeCoordinator() -> Coordinator {
        .init(text: $text)
    }
```

最后在`makeUIView`中添加：

```swift
    textfield.delegate = context.coordinator
```

UITextField 在发生特定事件后将在协调器中查找并调用对应的代理方法。

![image-20210822191834883](https://cdn.fatbobman.com/image-20210822191834883-9631115.png)

查看 [源代码](https://gist.github.com/cb34b4f96525ac49193a36cd1d5fc135.git)

至此，我们创建的`UITextField`包装已经同原生的`TextField`的表现行为一致了。

**你确定？**

再度修改一下`Demo`视图，将其修改为：

```swift
struct Demo: View {
    @State var name: String = ""
    var body: some View {
        VStack {
            TextFieldWrapper("name:", text: $name)
                .border(.blue)
                .padding()
            Text("name:\(name)")
            Button("Random Name"){
                name = String(Int.random(in: 0...100))
            }
        }
    }
}
```

按照对原生`TextField`的表现预期，当我们按下`Random Name`按钮时，`Text`同`TextFieldWrapper`中的文字都应该变成由`String(Int.random(in: 0...100))`产生的随机数字，但是如果你使用上述代码进行测试，`TextFieldWrapper`中的文字并没有变化。

在`makeUIView`中，我们使用`textfield.text = text`获取了`Demo`视图中`name`的值，但`makeUIView`只会执行一次。当点击`Random Name`引起`name`变化时，SwiftUI 将会调用`updateUIView`，而我们并没有在其中做任何的处理。只需要在`updateUIVIew`中添加如下代码即可：

```swift
    func updateUIView(_ uiView: UIViewType, context: Context) {
        DispatchQueue.main.async {
            uiView.text = text
        }
    }
```

> `makeUIView`方法的参数中有一个`context: Context`，通过这个上下文，我们可以访问到`Coordinator`（自定义协调器）、`transaction`（如何处理状态更新，动画模式）以及`environment`（当前视图的环境值集合）。我们之后将通过实例演示其用法。该`context`同样可以在`updateUIVIew`和`dismantleUIView`中访问。`updataUIView`的参数`_ uiView:UIViewType`为我们在`makeUIVIew`中创建的 UIKit 视图实例。

查看 [源代码](https://gist.github.com/69fb1ff4462192ed318048166aeb9eaf.git)

现在，我们的`TextFieldWrapper`的表现已经确实同`TextField`一致了。

![textFieldWrappertest](https://cdn.fatbobman.com/textFieldWrappertest-9634034.gif)

### 版本 2.0——添加设定 ###

在第一个版本的基础上，我们将为`TextFieldWrapper`添加`color`、`font`、`clearButtonMode`、`onCommit`以及`onEditingChanged`的配置设定。

> 考虑到尽量不将例程复杂化，我们使用`UIColor`、`UIFont`作为配置类型。将 SwiftUI 的`Color`和`Font`转换成 UIKit 版本将增加不小的代码量。

`color`、`font`以及我们新增加的`clearButtonMode`并不需要双向数据流，因此无需采用`Binding`方式，仅需在`updateView`中及时响应它们的变化既可。

`onCommit`和`onEditingChanged`分别对应着 UITextField 代理的`textFieldShouldReturn`、`textFieldDidBeginEditing`以及`textFieldDidEndEditing`方法，我们需要在协调器中分别实现这些方法，并调用对应的`Block`。

首先修改协调器：

```swift
extension TextFieldWrapper {
    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        var onCommit: () -> Void
        var onEditingChanged: (Bool) -> Void
        init(text: Binding<String>,
             onCommit: @escaping () -> Void,
             onEditingChanged: @escaping (Bool) -> Void) {
            self._text = text
            self.onCommit = onCommit
            self.onEditingChanged = onEditingChanged
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            if let text = textField.text as NSString? {
                let finaltext = text.replacingCharacters(in: range, with: string)
                self.text = finaltext as String
            }
            return true
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            onCommit()
            return true
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            onEditingChanged(true)
        }

        func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
            onEditingChanged(false)
        }

    }
}
```

对`TextFieldWrapper`进行修改：

```swift
struct TextFieldWrapper: UIViewRepresentable {
    init(_ placeholder: String,
         text: Binding<String>,
         color: UIColor = .label,
         font: UIFont = .preferredFont(forTextStyle: .body),
         clearButtonMode:UITextField.ViewMode = .whileEditing,
         onCommit: @escaping () -> Void = {},
         onEditingChanged: @escaping (Bool) -> Void = { _ in }
    )
    {
        self.placeholder = placeholder
        self._text = text
        self.color = color
        self.font = font
        self.clearButtonMode = clearButtonMode
        self.onCommit = onCommit
        self.onEditingChanged = onEditingChanged
    }

    let placeholder: String
    @Binding var text: String
    let color: UIColor
    let font: UIFont
    let clearButtonMode: UITextField.ViewMode
    var onCommit: () -> Void
    var onEditingChanged: (Bool) -> Void

    typealias UIViewType = UITextField
    func makeUIView(context: Context) -> UIViewType {
        let textfield = UITextField()
        textfield.setContentHuggingPriority(.defaultHigh, for: .vertical)
        textfield.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textfield.placeholder = placeholder
        textfield.delegate = context.coordinator
        return textfield
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
        DispatchQueue.main.async {
            uiView.text = text
            uiView.textColor = color
            uiView.font = font
            uiView.clearButtonMode = clearButtonMode
        }
    }

    func makeCoordinator() -> Coordinator {
        .init(text: $text,onCommit: onCommit,onEditingChanged: onEditingChanged)
    }
}

```

修改`Demo`视图：

```swift
struct Demo: View {
    @State var name: String = ""
    @State var color: UIColor = .red
    var body: some View {
        VStack {
            TextFieldWrapper("name:",
                             text: $name,
                             color: color,
                             font: .preferredFont(forTextStyle: .title1),
                             clearButtonMode: .whileEditing,
                             onCommit: { print("return") },
                             onEditingChanged: { editing in print("isEditing \(editing)") })
                .border(.blue)
                .padding()
            Text("name:\(name)")
            Button("Random Name") {
                name = String(Int.random(in: 0...100))
            }
            Button("Change Color") {
                color = color == .red ? .label : .red
            }
        }
    }
}

struct TextFieldWrapperPreview: PreviewProvider {
    static var previews: some View {
        Demo()
    }
}
```

查看 [源代码](https://gist.github.com/5604d7bee11a44c2cbdcba12cfe1eda0.git)

![textfieldwrapperdemo2](https://cdn.fatbobman.com/textfieldwrapperdemo2-9639150-9639151.gif)

```responser
id:1
```

## SwiftUI 风格化 ##

我们不仅实现了对字体、色彩的设定，而且增加了原生`TextField`没有的`clearButtonMode`设置。按照上述的方法，可以逐步为其添加更多的设置，让`TextFieldWrapper`获得更多的功能。

**代码好像有点不太对劲？！**

随着功能配置的增加，上面代码在使用中会愈发的不方便。如何实现类似原生`TextFiled`的链式调用呢？譬如：

```swift
        TextFieldWrapper("name:",text:$name)
            .clearMode(.whileEditing)
            .onCommit{print("commit")}
            .foregroundColor(.red)
            .font(.title)
            .disabled(allowEdit)

```

本节中，我们将重写配置代码，实现 UIKit 包装风格 SwiftUI 化。

> 本节以版本 1.0 结束时的代码为基础。

所谓的 SwfitUI 风格化，更确切地说应该是函数式编程的链式调用。将多个操作通过点号（.）链接在一起，增加可读性。作为将函数视为一等公民的 Swift，实现上述的链式调用非常方便。不过有以下几点需要注意：

* 如何改变 View 内的的值（View 是结构）
* 如何处理返回的类型（保证调用链继续有效）
* 如何利用 SwiftUI 框架现有的数据并与之交互逻辑

> 为了更全面的演示，下面的例子，采用了不同的处理方式。在实际使用中，可根据实际需求选择适当的方案。

### foregroundColor ###

我们在 SwiftUI 中经常会用到`foregroundColor`来设置前景色，比如下面的代码：

```swift
            VStack{
                Text("hello world")
                    .foregroundColor(.red)
            }
            .foregroundColor(.blue)
```

不知道大家是否知道上面的两个`foregroundColor`有什么不同。

```swift
extension Text{
    public func foregroundColor(_ color: Color?) -> Text
}

extension View{
    public func foregroundColor(_ color: Color?) -> some View
}
```

方法名一样，但作用的对象不同。`Text`只有在针对本身的`foregroundColor`没有设置的时候，才会尝试从当前环境中获取`foregroundColor`（针对 View）的设定。原生的`TextFiled`没有针对本身的`foregroundColor`，不过我们目前也没有办法获取到 SwiftUI 针对 View 的`foregroundColor`设定的环境值（估计是），因此我们可以使用`Text`的方式，为`TextFieldWrapper`创建一个专属的`foregroundColor`。

为`TextFieldWrapper`添加一个变量

```swift
private var color:UIColor = .label
```

在`updateUIView`中增加

```swift
uiView.textColor = color
```

设置配置方法：

```swift
extension TextFieldWrapper {
    func foregroundColor(_ color:UIColor) -> Self{
        var view = self
        view.color = color
        return view
    }
}
```

查看 [源代码](https://gist.github.com/56f426b29a551c6490062f6daf3e342a.git)

就这么简单。现在我们就可以使用`.foreground(.red)`来设置`TextFieldWrapper`的文字颜色了。

这种写法是为特定视图类型添加扩展的常用写法。有以下两个优点：

* 使用`private`，无需暴露配置变量
* 仍返回特定类型的视图，有利于维持链式稳定

我们几乎可以使用这种方式完成全部的链式扩展。如果扩展较多时，可以采用下面的方式，进一步清晰、简化代码：

```swift
    extension View {
        func then(_ body: (inout Self) -> Void) -> Self {
            var result = self
            body(&result)
            return result
        }
    }

    func foregroundColor(_ color:UIColor) -> Self{
        then{
            $0.color = color
        }
    }
```

### disabled ###

SwiftUI 针对 View 预设了非常多的扩展，其中有相当的部分都是通过环境值`EnvironmentValue`来逐级传递的。通过直接响应该环境值的变化，我们可以在不编写特定`TextFieldWrapper`扩展的情况下，即可为其增加配置功能。

例如，`View`有一个扩展`.disabled`，通常我们会用它来控制交互控件的可操作性（`.disable`对应的`EnviromentValue`为`isEnabled`）。

在`TextFieldWrapper`中添加：

```swift
@Environment(\.isEnabled) var isEnabled
```

在`updateUIView`中添加：

```swift
uiView.isEnabled = isEnabled
```

只需要两条语句，`TextFieldWrapper`便可以直接使用`View`的`disable`扩展来控制其是否可以录入数据。

还记得上文中介绍的`context`吗？我们可以直接通过`context`获取上下文中的环境值。因此支持原生的`View`扩展将一步简化。

**无需**添加`@Environemnt`，只需要在`updateUIView`中添加一条语句既可：

```swift
uiView.isEnabled = context.environment.isEnabled
```

查看 [源代码](https://gist.github.com/e749322c1add66b2f9b8732c62463c89.git)

> 在写本文时，在 iOS15 beta 下运行该代码，会出现`AttributeGraph: cycle detected through attribute`的警告，这个应该是 iOS15 的 Bug，请自行忽略。

通过环境值来设置是一种十分便捷的方式，唯一需要注意的是，它会改变链式结构的返回值。因此，在该节点后的链式方法只能是针对`View`设置的，像之前我们创建的`foregroundColor`就只能放置在这个节点之前。

### font ###

我们也可以自己创建环境值来实现对`TextFieldWrapper`的配置。比如，SwiftUI 提供的`font`环境值的类型为`Font`，本例中我们将创建一个针对`UIFont`的环境值设定。

创建环境值`myFont`：

```swift
struct MyFontKey:EnvironmentKey{
    static var defaultValue: UIFont?
}

extension EnvironmentValues{
    var myFont:UIFont?{
        get{self[MyFontKey.self]}
        set{self[MyFontKey.self] = newValue}
    }
}

```

在`updateUIVIew`中添加：

```swift
uiView.font = context.environment.myFont
```

`font`方法可以有多种写法：

* 同`forgroundColor`一样的对`TextFieldWrapper`进行扩展

```swift
    func font(_ font:UIFont) -> some View{
        environment(\.myFont, font)
    }
```

* 对`View`进行扩展

```swift
extension View {
    func font(_ font:UIFont?) -> some View{
        environment(\.myFont, font)
    }
}
```

两种方式的链式节点的返回值都不再是`TextFieldWrapper`，后面应该接针对`View`的扩展。

查看 [源代码](https://gist.github.com/c9602681774540dbca929e21c99827c7.git)

### onCommit ###

在版本 2 的代码中，我们为`TextFieldWrapper`添加了`onCommit`设置，在用户输入`return`时会触发该段代码。本例中，我们将为`onCommit`添加一个可修改版本，且不需要通过协调器构造函数传递。

本例中的技巧在之前都出现过，唯一需要提醒的是在`updateUIView`中，可以通过

```swift
context.coordinator.onCommit = onCommit
context.coordinator.onEditingChanged = onEditingChanged
```

改变协调器内的变量。这是一种非常有效的在 SwiftUI 和协调器之间进行沟通的手段。

![image-20210823091321562](https://cdn.fatbobman.com/image-20210823091321562.png)

查看 [源代码](https://gist.github.com/716b08616fa6ecbd28589ac94b635706.git)

## 避免滥用 UIKit 包装 ##

尽管在 SwiftUI 中使用 UIKit 或 AppKit 并不麻烦，但是当你打算包装一个 UIKit 控件时（尤其是已有 SwiftUI 官方原生解决方案），请务必三思。

苹果对 SwiftUI 的野心非常大，不仅为开发者带来了声明+响应式的编程体验，同时苹果对 SwiftUI 在跨设备、跨平台上（苹果生态）也做出了巨大的投入了。

苹果为每一个原生控件（比如`TextField`），针对不同的平台（iOS、macOS、tvOS、watchOS）做了大量的优化。这是其他任何人都很难自己完成的。因此，在你打算为了某个特定功能重新包装一个系统控件时，请先考虑以下几点。

### 官方的原生方案 ###

SwiftUI 这几年发展的很快，每个版本都增加了不少新功能，或许你需要的功能已经被添加。苹果最近两年对 SwiftUI 的文档支持提高了不少，但还没到令人满意的地步。作为 SwiftUI 的开发者，我推荐大家最好购买一份 javier 开发的 [A Companion for SwiftUI](https://swiftui-lab.com/companion/)。该 app 提供了远比官方丰富、清晰的 SwiftUI API 指南。使用该 app 你会发现原来 SwiftUI 提供了如此多的功能。

### 用原生方法组合解决 ###

在 SwiftUI 3.0 版本之前，SwiftUI 并不提供`searchbar`，此时会出现两种路线，一种是自己包装一个 UIKit 的`UISearchbar`，另外就是通过使用 SwiftUI 的原生方法来组合一个`searchbar`。在多数情况下，两种方式都能取得满意的效果。不过用原生方法创建的`searchbar`在构图上更灵活，同时支持使用`LocalizedString`作为 placeholder。我个人会更倾向于使用组合的方案。

> SwiftUI 中很多数据类型官方并不提供转换到其他框架类型的方案。比如`Color`、`Font`。不过这两个多写点代码还是可以转换的。`LocalizedString`目前只能通过非正常的手段来转换（使用`Mirror`）, 很难保证可以长久使用该转换方式。

### Introspect for SwiftUI ###

在版本 2 代码中，我们为`TextFieldWrapper`添加了`clearButtonMode`的设置，也是我们唯一增加的目前`TextField`尚不支持的设定。不过，如果我们仅仅是为了添加这个功能就自己包装`UITextField`那就大错特错了。

[Introspect](https://github.com/siteline/SwiftUI-Introspect) 通过自省的方法来尝试查找原生控件背后包装的 UIKit（或 AppKit）组件。目前官方尚未在 SwiftUI 中开放的功能多数可以通过此扩展库提供的方法来解决。

比如：下面的代码将为原生的`TextField`添加`clearButtonMode`设置

```swift
        import Introspect
        extension TextField {
            func clearButtonMode(_ mode:UITextField.ViewMode) -> some View{
                introspectTextField{ tf in
                    tf.clearButtonMode = mode
                }
            }
        }

        TextField("name:",text:$name)
           .clearButtonMode(.whileEditing)
```

## 总结 ##

SwiftUI 与 UIKit 和 AppKit 之间的互操作性为开发者提供了强大的灵活性。学会使用很容易，但想用好确实有一定的难度。在 UIKit 视图和 SwiftUI 视图之间共享可变状态和复杂的交互通常相当复杂，需要我们在这两种框架之间构建各种桥接层。

本文并没有涉及包装具有复杂逻辑代码的协调器同 SwiftUI 或 Redux 模式沟通交互的话题，里面包含的内容过多，或许需要通过另一篇文章来探讨。

希望本文能对你学习和了解如何将 UIKit 组件导入 SwiftUI 提供一点帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
