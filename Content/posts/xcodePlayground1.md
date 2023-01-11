---
date: 2021-12-27 08:12
description: 本系列将介绍大量有关 Xcode Playground 的使用技巧，涉及稳定性、第三方库、资源管理、异步处理、文档标注等等方面，让你玩转 Playground，使其成为你工作学习中的利器。
tags: Swift Playgrounds, Playground
title:  玩转 Xcode Playground（上）
image: images/playground1.png
---
在 Swift 语言推出的同一年（2014 年），苹果就在 Xcode 中集成了 Playground 功能。相较标准的 Xcode 项目，Playground 启动更快、使用更轻巧，被广泛应用于 Swift 语言学习、框架 API 测试、快捷数据处理、汇集灵感等众多方面。本系列将介绍大量有关 Xcode Playground 的使用技巧，涉及稳定性、第三方库、资源管理、异步处理、文档标注等等方面，让你玩转 Playground，使其成为你工作学习中的利器。

```responser
id:1
```

## 创建与设置

### .playground vs .playgroundbook

在 Xcode 中创建的 Playground 项目被保存为以`.playground`为后缀的包（可以通过显示包内容查看其中的文件）。`.playground`可以直接在 Xcode 和 Swift Playgrounds 3.x 以上的版本打开。

`.playgroundbook`是 Swift Playgrounds 特有的包格式，相较`.playground`，它包含了很多独有的功能，这些功能主要用于改善 Swift Playgrounds 在教育和娱乐方面的体验。`.playgroundbook`格式只能在 Swift Playgrounds 上打开。

> 更多关于最新 Swift Playgrounds 4 的介绍请阅读 [Swift Playgrounds 4 娱乐还是生产力](https://www.fatbobman.com/posts/swiftPlaygrounds4/)

本系列介绍的技巧主要针对 Xcode Playground （也就是`.playground`），多数技巧同时适用于 Xcode 和 Swift Playgrounds，仅适用于单独平台的技巧会做出明确地标注。

### 如何创建 Playground 项目

#### 在 Xcode 中创建 Playground 项目

在 Xcode 中，点击 File -> New -> Playground 即可创建一个格式为`.playground`的 Xcode Playground 项目。

![image-20211223162302918](https://cdn.fatbobman.com/image-20211223162302918.png)

Playground 提供了数种预置模版，模版选择界面的系统设定（ iOS、macOS）仅影响模版代码，并不会自动设置 Page 的运行环境。

![image-20211223164000220](https://cdn.fatbobman.com/image-20211223164000220.png)

Xcode 可以打开 Playground 项目，也可以将 Playground 项目添加到 Project 或 Workspace 中（有助于测试 SPM 或调用 Project 中自定义的类型）。

#### 在 Swift Playgrounds 中创建 Playground 项目

在 Swift Playgrounds 4 中可以直接创建与 Xcode 兼容的 Playground 项目（`.playground`）。点击首页下方的【查看全部】，选择其中的 Xcode Playground。

![image-20211224160807063](https://cdn.fatbobman.com/image-20211224160807063.png)

*请注意：首页下方的 Playground 按钮创建的是 `playgroundbook` 。*

![image-20211223161945374](https://cdn.fatbobman.com/image-20211223161945374.png)

Swift Playgrounds 创建的项目，默认保存在 iCloud 云盘的 Playgrounds 目录中。尽量不要同时在 macOS 的 Xcode 和 iPad 的 Swift Playgrounds 上同时编辑一个项目，容易造成版本冲突。

### 如何创建多个 Playground Page

Playground 鼓励开发者每次只关注一个议题，通过将议题分散到不同的 Page 来帮助开发者组织代码和对应的资源。

新建的 Playground 项目默认只有一个 Page（单 Page 模式下，左侧的导航栏中 Page 和 Playground 项目将合并显示）。每个 Page 都可以设置对应的实时视图。

![image-20211223164606421](https://cdn.fatbobman.com/image-20211223164606421.png)

在 Xcode 中，通过 File 菜单或在导航栏 Playground 项目上点击右键，可以创建新的 Playground Page。

![image-20211223170027028](https://cdn.fatbobman.com/image-20211223170027028.png)

![image-20211223170047358](https://cdn.fatbobman.com/image-20211223170047358.png)

当不只有一个 Page 后，Playground 项目和 Page 将分开显示。

在 Swift Playgrounds 4 中，点击侧边栏的`编辑`按钮，进入编辑模式，点击`+`按钮可创建新的 Page。

![image-20211223175608008](https://cdn.fatbobman.com/image-20211223175608008.png)

可以调整 Page 顺序，并可修改每个 Page 的名称（不仅有助于标识，更方便在不同的 Page 中实现快速跳转）。

在单 Page 模式下，项目中只有一组 Sources 和 Resources 目录。在多 Page 模式下，除了项目根目录下的 Sources 和 Resources 外，每个 Page 也都有自己的 Sources 和 Resources 目录。

![image-20211223170801239](https://cdn.fatbobman.com/image-20211223170801239.png)

每个 Page 都应视为独立的 Module，Page A 中的代码不可被 Page B 调用。

### 如何调试代码

Playground 并不提供设置断点的功能，但是可以通过指定执行结束点或单步执行的方式来满足部分的调试需求。

在 Xcode 中，通过点击代码左侧行数上的执行按钮（需要按钮的颜色为蓝色）来指定当前执行的结束位置。

![image-20211223180328839](https://cdn.fatbobman.com/image-20211223180328839.png)

点击当前结束位置之后的蓝色执行按钮可以继续向下执行。点击代码编辑区域下方的执行按钮，将重新执行全部代码。

在输入新的代码后，可以采用输入 Shift-Return 的方式让 Playground 执行截至本行尚未执行的代码。此种方式在不希望反复执行长耗时代码段的情况下将非常有用（例如机器学习）。

在单步模式下，对于行首为蓝色执行按钮的代码进行修改，无需重置执行。如果修改了已经执行过的代码行（行首显示为灰色），必须重置 Playground （点击代码编辑区域下方的执行按钮）才能反应出你做的更改。

Swift Playgrounds 没有提供设置执行结束位置的功能，但提供了单步执行的设定。点击屏幕下方的仪表按钮，可以设定调试方式。

![image-20211223180913086](https://cdn.fatbobman.com/image-20211223180913086.png)

### 提高 Xcode 下的运行稳定性（Xcode Only）

#### 设置运行环境

在 Xcode 中，可以在右侧的 Playground Settings 中设定 Playground 的运行环境。

![image-20211223144432779](https://cdn.fatbobman.com/image-20211223144432779.png)

在没有必须依赖 iOS 框架代码的情况下，将运行环境设置为 macOS 可以减少因 iOS 模拟器错误引发的不稳定状况。

当有多个 Playground Page 时，可以为每个 Page 单独设置对应的运行环境。

![image-20211223144916673](https://cdn.fatbobman.com/image-20211223144916673.png)

当有多个 Playground Page 时，点击最上方的项目名称，可以为所有 Page 一并设置成统一的运行环境

![image-20211223144934347](https://cdn.fatbobman.com/image-20211223144934347.png)

Swift Playgrounds 仅兼容运行环境为 iOS 的 Playground 项目。

#### 将运行方式改成手动

在运行方式被设置为自动模式时，每当你修改代码后，系统都会自动运行代码并显示结果。自动模式在代码内容较少且简单的情况下表现还不错，不过一旦代码较多且复杂后，自动运行模式将导致系统资源占用较多，且容易出现运行不稳定的情况。

![image-20211223150747157](https://cdn.fatbobman.com/image-20211223150747157.png)

长按代码编辑区域下方的执行按钮，可以在两种模式中进行选择。

在 Xcode 的配置中，可以为 Playground 指定适合的快捷键，提高操作效率。

![image-20211223151240337](https://cdn.fatbobman.com/image-20211223151240337.png)

### 如何查看结果栏

Playground 在 Xcode 中拥有一个独有的显示区域——结果栏，该区域不仅可以显示每行代码的当前值、历史状态，同时也会显示关于调用次数、文件信息等等内容。

![image-20211224091253473](https://cdn.fatbobman.com/image-20211224091253473.png)

例如上图中，55 行显示了图片的尺寸信息，57 行显示了 y 在当前行的值，59 行则显示了在循环中本行的执行次数。

![image-20211224091811968](https://cdn.fatbobman.com/image-20211224091811968.png)

当鼠标靠近右侧的屏幕图标时，将出现眼睛图标。点击眼睛图标将显示该行代码对应的 Quick Look 内容。点击屏幕图标可以将 Quick Look 内容显示在代码编辑区域中（内联显示）。

![image-20211224091947472](https://cdn.fatbobman.com/image-20211224091947472.png)

Quick Look 的内容可以在最新值、历史记录、图表模式间切换（可切换模式的数量将根据类型的不同而有所变化）。

![image-20211224092212674](https://cdn.fatbobman.com/image-20211224092212674.png)

Swift Playgrounds 中对于 Quick Look 的操作与 Xcode 类似，并可通过关闭【启用结果】来提高代码的执行效率。

### 如何创建自定义 Quick Look

苹果已经为不少的系统类型提供了 Playground 下的 Quick Look 支持。通过让其他的系统类型（主要集中于较新的 API）以及我们自定义的类型满足 CustomPlaygroundDisplayConvertible 协议，以提供 Quick Look 支持。

比如说，WWDC 2021 上新推出的 [AttributedString](https://www.fatbobman.com/posts/attributedString/) 目前尚不支持 Quick Look ，但通过在 playgroundDescription 中将其转换为 NSAttributedString，就可以直接在 Playground 中显示正确的 Quick Look 了。

下图为，没有满足 CustomPlaygroundDisplayConvertible 协议的状况。AttributedString 的 Quick Look 为结构体的 Dump 样式。

![image-20211224142839306](https://cdn.fatbobman.com/image-20211224142839306.png)

苹果为 NSAttributedString 提供了正确的 Quick Look 实现，将 AttributedString 转换成 NSAttributedString 以实现更好的显示效果。

```swift
extension AttributedString: CustomPlaygroundDisplayConvertible {
    public var playgroundDescription: Any {
        NSAttributedString(self)
    }
}
```

![image-20211224142915994](https://cdn.fatbobman.com/image-20211224142915994.png)

```responser
id:1
```

## PlaygroundSupport

### 什么是 PlaygroundSupport

PlaygroundSupport 是专门用于扩展 Playground 的框架。提供了在 Playground 中共享数据、管理实时视图、控制 Playground 运行模式等功能。

在需要的 Playground Page 的代码中通过`import PlaygroundSupport`导入框架。

### 如何获得异步执行的结果（Swift Playgrounds Only）

在老版本的 Xcode（Xcode 12、Xcode 13 已经解决了这个问题）以及 Swift Playgrounds 中，如果不经过特别的设定，Playground 并不会等待异步代码的返回结果， 在完成了全部的代码调用后即结束执行。需要将 Playground 设置为无限执行模式后，才会在获得异步执行的结果后方终止运行状态。

在 Swift Playgrounds 中执行下面的代码并不会获得打印结果

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
    print("Hello world")
}
```

需要导入`PlaygroundSupport`，并设置 needsIndefiniteExecution 为 true 。

```swift
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true
DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
    print("Hello world")
}
```

*每个 Page 都需要单独设置，且不能在代码的最后设定。*

### 如何执行 async/await 代码

> 本节内容并不需要 PlaygroundSupport 的支持，但为了同【如何获得异步执行的结果】章节靠近，故放置在此处

在 Playground 中使用新的 async/await 代码时，需要导入`_Concurrency`方可正常运行代码。

```swift
import _Concurrency

Task {
    try await Task.sleep(nanoseconds: 2_000_000_000)
    print("Hello world")
}
```

*在 Swift Playgrounds 中执行上述代码时，需要设置 needsIndefiniteExecution。*

### 如何创建实时视图

你可以使用实时视图来为 Playground 添加互动性，试验不同的用户界面元素，并建立自定义元素。通过导入 PlaygroundSupport 并将当前页面的实时视图设置为你的自定义视图或视图控制器，就可以将一个交互式实时视图添加到 Playground Page 中。

![image-20211224105528272](https://cdn.fatbobman.com/image-20211224105528272.png)

实时视图支持 SwiftUI 视图以及 UIKit（AppKit）的视图和视图控制器。SwiftUI 视图需要通过 setLiveView 来设定。

```swift
import PlaygroundSupport
import UIKit

let lable = UILabel(frame: .init(x: 0, y: 0, width: 200, height: 100))
lable.text = "Hello world"
lable.textAlignment = .center
lable.textColor = .red

//PlaygroundPage.current.setLiveView(lable) UIKit 视图，两种设置方法都可以
PlaygroundPage.current.liveView = lable
```

*在设置了实时视图后，Playground 会自动将 needsIndefiniteExecution 设置为 true。*

如果想通过代码终止执行，可以使用`PlaygroundPage.current.finishExecution()`

> 在 Xcode 中，还可以通过`PlaygroundPage.current.liveTouchBar`来自定义 Touchbar。

### 如何让其他的类型实例在实时视图中显示

任何符合 PlaygroundLiveViewable 协议的类型，都可以被设置为实时视图。

下面的代码让 UIBezierPath 可以直接在动态视图中显示

![image-20211224140536980](https://cdn.fatbobman.com/image-20211224140536980.png)

```swift
import PlaygroundSupport
import UIKit

let path = UIBezierPath()
var point = CGPoint(x: 0, y: 0)
path.move(to: point)
point = CGPoint(x: 100, y: 0)
path.addLine(to: point)
point = CGPoint(x: 200, y: 200)
path.addLine(to: point)

extension UIBezierPath: PlaygroundLiveViewable {
    public var playgroundLiveViewRepresentation: PlaygroundSupport.PlaygroundLiveViewRepresentation {
        let frame = self.bounds
        let view = UIView(frame: frame)
        view.backgroundColor = UIColor(red: 1, green: 0, blue: 0, alpha: 1)
        let layer = CAShapeLayer()
        layer.path = self.cgPath
        view.layer.mask = layer
        return .view(view)
    }
}

PlaygroundPage.current.liveView = path
```

### 获取 Playground 的共享目录 （playgroundSharedDataDirectory）

playgroundSharedDataDirectory 指向一个可以在 Playground Page 之间共享资源的目录。

如果 Playground Page 被设置在 macOS 模式，该目录中的内容可以在不同的 Playground 项目 macOS 模式的 Page 中共享。如果 Playground Page 运行在 iOS 模式，该目录中的内容只能在同一个 Playground 项目的 iOS 模式的 Page 中共享（每个 Playground 项目都有各自对应的 iOS 模拟器，）。

```swift
import PlaygroundSupport
import AppKit

let url = playgroundSharedDataDirectory.appendingPathComponent("playground1.png")
if let data = try? Data(contentsOf: url) {
    _ = NSImage(data: data)
}
```

在 macOS 下，该目录为用户文档目录下的`Shared Playground Data`子目录。系统并不会自动创建该目录，需要手动创建。

playgroundSharedDataDirectory 主要用于在 macOS 下保存多个 Playground 项目共同所需的数据。在单个 Playground 项目中，可以通过项目的 Resource 目录在 Page 间共享数据。

## 总结

在【玩转 Xcode Playground （下）】中，我们将着重介绍有关 SPM、资源管理、辅助代码、文档标注等方面的内容。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。

