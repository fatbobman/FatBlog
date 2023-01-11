---
date: 2021-12-31 08:12
description: 本文将对 Xcode Playground 做更进一步的研究，着重于辅助代码、资源管理、使用 Playground 探索软件包和 Xcode 项目等更有深度内容。
tags: Swift Playgrounds, Playground
title:  玩转 Xcode Playground（下）
image: images/playground2.png
---
在 [上文](https://fatbobman.com/posts/xcodePlayground1/) 中，我们介绍了有关 Xcode Playground 在创建、配置、Quick Look、实时视图等方面的知识。本文将对 Xcode Playground 做更进一步的研究，着重于辅助代码、资源管理、使用 Playground 探索软件包和 Xcode 项目等更有深度内容。

```responser
id:1
```

## 辅助代码与资源

### Xcode Playground 的包结构及文件添加

Xcode Playground 项目并不依赖项目配置文件，Page、辅助代码、资源文件、调用权限等均通过`.playground`包内的目录结构来进行管理。

#### 单 Page 情况时

创建一个新的 Xcode Playground 项目后，默认的包文件结构如下（右键点击 Playground 项目文件，选择显示包内容）：

![image-20211230091237554](https://cdn.fatbobman.com/image-20211230091237554.png)

![image-20211230091344661](https://cdn.fatbobman.com/image-20211230091344661.png)

新创建的项目只有一个 Page，Xcode Playground 会将 Page 同 Playground 项目的内容合并显示。Contents.swift 为当前唯一 Page 的主代码内容。尽管在 Xcode 的导航栏中显示了 Sources 和 Resources ，但由于当前两者均没有内容，`.playground` 包中并没有为其创建目录。

Sources 目录是存放辅助代码（也被称为共享代码）的地方。开发者通常将自定义类型、预设方法、测试片段、前文中提到的自定义 Quick Look、自定义实时视图类型等内容，保存成 Swift 代码文件，放置在 Sources 目录中。

辅助代码有多种添加方式，可以直接将代码文件在 Xcode 中拖拽到导航栏的 Sources 项目中；或者在 Finder 里将代码文件拷贝到 Sources 目录中；或者在 Sources 上点击右键，直接创建新的 Swift 代码文件。

Resources 目录是用来存放 Page 的主代码（Contents.swift）以及辅助代码中需要使用到的各类资源文件，例如：图片、声音、JSON、Assets 资产等等。添加的方式同添加辅助代码类似。

*资源文件只能被保存在 Resources 目录或其子目录中，辅助代码也只能被保存在 Sources 目录或其子目录中。*

当我们向 Sources 或 Resources 目录中添加内容后，Playground 将会自动在 `.playground` 包中创建对应的目录。

![image-20211230101032174](https://cdn.fatbobman.com/image-20211230101032174.png)

![image-20211230101053762](https://cdn.fatbobman.com/image-20211230101053762.png)

#### 多 Page 情况时

相对于只有一个 Page 的 Xcode Playground 项目，当包含多个 Page 时，目录结构将发生显著的变化。

![image-20211230101344202](https://cdn.fatbobman.com/image-20211230101344202.png)

为上文创建的 Playground 项目添加新的 Page 后，Playground 项目（NewPlaygrounds）和 Page 将被分开显示。我们将最初的 Page 命名为 Page1，将新的 Page 命名为 Page2。

此时在 Xcode 导航栏中可以看到。在项目层级（NewPlaygrounds）下包含有 Sources 和 Resources，同时在每个 Page 下也包含各自的 Sources 和 Resources。此时。`.playground` 包中的结构将变成如下状态：

![image-20211230101710642](https://cdn.fatbobman.com/image-20211230101710642.png)

原来在根目录下的 Contents.swift 文件不见了，新增了 Pages 目录，并在其中添加了两个与 Page 名称对应的 `.xcplaygroundPage` 包文件。进一步查看 `.xcplaygroundpage` 包内容，可以看到各自拥有一个 Contents.swift（Page 的主代码文件）。

在 Xcode 中为 Page1 添加辅助代码和资源文件，Page1.xcplaygroundpage 包中的内容也将发生改变。

![image-20211230102401629](https://cdn.fatbobman.com/image-20211230102401629.png)

![image-20211230102456108](https://cdn.fatbobman.com/image-20211230102456108.png)

需要注意的是：

* 当添加新的 Page 时，最初在单 Page 状况下添加的辅助代码和资源文件将被保留在项目层级的 Sources 和 Resources 目录中
* 在多 Page 状况删除 Page，即使仅剩一个 Page ，目录结构也不会重新回到 Playground 项目创建时的状态（单 Page），仍将保持多 Page 情况下的目录结构

### 辅助代码的管理和调用

在 Xcode Playground 中，可以将每个 Page 视作一个独立的 mini app（相互之间没有关联），每个 Sources 目录也都被视为一个 Module。

以上文创建的项目为例：

* 项目层级的 Sources 将被编译成 NewPlaygrounds_Sources（项目名称 + `_Sources`）模块，Page1 的 Sources 将被编译成 Page1_PageSources（页面名称 + `_PageSources`）模块。

* Playground 将为 Page1 的辅助代码，隐式导入 NewPlaygrounds_Sources
* Playground 将为 Page1 的主代码（Contents.swift）隐式导入 NewPlaygrounds_Sources 和 Page1_PagesSources 模块

通俗的来说，在全部 Page 的辅助代码中，均可调用项目的辅助代码。在每个 Page 的主代码中，均可调用项目的辅助代码以及当前 Page 的辅助代码。

因为基于了 Module 的方式进行管理，因此，**只有定义为 public 的代码，才能被非本模块的代码所调用**。

在项目层级的 Sources 目录 Helper.swift 文件添加如下方法：

```swift
import Foundation

public func playgroundName() -> String {
    "NewPlaygrounds"
}
```

在 Page1 的 Sources 目录 Page1Code.swift 中添加如下方法：

```swift
import Foundation

public func pageName() -> String {
    playgroundName() + " Page1"
}
```

在 Page1 的主代码中，可以直接调用项目辅助代码模块或 Page1 辅助代码模块的 public 代码：

```swift
let playgourndName = playgroundName()
let currentName = pageName()
```

![image-20211230110445909](https://cdn.fatbobman.com/image-20211230110445909.png)

Playground 会为我们隐式导入所需模块，无需自行 import。当然，你也可以在不同的代码中手动 import 对应的模块以加深理解。

同 Page 的主代码不同，辅助代码并不支持 Playground 的逐行执行、Quick Look 等功能。Playground 在运行 Page 主代码前，会率先完成辅助代码的编译工作（自动）。

其他关于辅助代码需要注意的事项：

* Page 的主代码或辅助代码不可以调用其他 Page 的辅助代码
* 由于每个 Page 可以单独设置运行环境（iOS 或 macOS），因此辅助代码应该与运行环境相兼容，尤其当在一个项目中包含不同运行环境的 Page 时，务必确保项目的辅助代码在不同平台上都可运行。

### 资源文件的组织和注意事项

资源采用同辅助代码一样的目录组织形式，分为 Playground 项目可共享资源和 Page 的专属资源。

保存在项目根目录的 Resource 的资源文件，可以被各个 Page 的主代码及 Page 的辅助代码使用。保存在 Page 的 Resources 目录中的资源，只能被所属 Page 的主代码及辅助代码使用。

Playground 在执行 Page 的代码时，并没有将项目资源和 Page 资源分开存放，而是为每个 Page 创建了一个用来汇总资源的目录，并在其中为该 Page 可用的资源一一创建了链接（替身）。因此，**如果项目资源文件同 Page 专属资源文件重名了，Playground 将无法同时支持两个资源**。

正因为 Playground 将当前 Page 可访问的资源都汇总到一个目录中，因此，无论是项目资源还是 Page 专属资源，在 Page 主代码或 Page 的辅助代码中，都可以使用`Bundle.main`来访问。

下面的代码，可以获取 Page1 可用资源的汇总目录：

```swift
let url = Bundle.main.url(forResource: "pic", withExtension: "png")
```

![image-20211230135813553](https://cdn.fatbobman.com/image-20211230135813553.png)

![image-20211230135933606](https://cdn.fatbobman.com/image-20211230135933606.png)

name.json 是 Page1 的专属资源，pic.png 是项目的资源。都被集中到一起（因此，如果出现重名的话，正常情况下只有专属资源的内容可以被使用）。

Assets 文件（`.xcassets`）略有特殊。每个 Page 只能支持一个 Assets。如果 Page 的专属资源中没有 Assets，则 Page 可以使用项目资源中的 Assets。如果 Page 资源中包含了 Assets，无论项目资源中的 Assets 名称如何，都将被忽略。

> 当前，Playground 在处理资源文件更名和删除上有一个 Bug（至少存在于 Xcode 12、Xcode 13 中）。如果在 Xcode 中对资源文件进行更名，Playground 将在保存替身的目录中为新名称创建一个替身，但并不会删除原来名称的替身。如果将资源文件删除，对应的替身文件并不会删除。因此会出现即使资源名称同代码中调用的名称不符（代码中仍使用原来名称），但仍可获取到文件的情况。目前并没有找到可以重置该替身目录的方法，如需要，可以定位到该目录手动删除无效的替身文件。

在 Swift Playground 中，无法为每个 Page 单独添加资源，所有的资源都会被放置在项目层的 Resources 目录中。如确有为单个 Page 添加资源的需求，可以在 Xcode 或 finder 上添加好后，再于 Swift Playground 中打开。

Playground 会对某些特定格式的资源做预处理（编译），例如`.xcassets`、`.mlmodel`，处理后的资源可以直接在 Playground 中进行配置和管理。

### 如何使用本地化文件（主要用于 Swift Playgrounds）

同 SPM 对于本地化管理方式类似，只需要在资源文件目录中创建所需语言的目录（例如`en.lproj`、`zh-CN.lproj`），便可在目录中添加对应语言的字符串文件和资源文件。

![image-20211230144902042](https://cdn.fatbobman.com/image-20211230144902042.png)

当 Swift Playgrounds 执行 Page 的代码时，将根据当前系统的设定，调用正确的资源。

> Xcode Playground 中并没有提供便捷的运行环境区域设置功能。开发者可以使用 UITraitCollection 来对 Xcode Playground 中的 iOS 模拟器做一定程度的设置。

### 如何测试 Core Data 代码

如果想在 Playground 中学习和测试 Core Data 的各项功能，需要注意如下事项：

* Playground 不支持`.xcdatamodeld`格式的配置文件。需要先在 Xcode 中创建一个 Core Data 项目，编辑好所需的`.xcdatamodeld`文件后，编译该项目。将编译后程序包中的`.momd`拷贝到 Playground 的资源目录中

![image-20211230151310187](https://cdn.fatbobman.com/image-20211230151310187.png)

* Playground 并不支持自动生成托管对象定义。可以在 Xcode 项目中，使用 Create NSManagedObject Subclass 生成对应的代码，并将代码拷贝到 Playground 的辅助代码中（在定义不复杂的情况下，也可以直接手写）。

![image-20211230151034118](https://cdn.fatbobman.com/image-20211230151034118.png)

```responser
id:1
```

## 文档

### 在代码中添加可渲染标注文档

相较标准的 Xcode 项目，Playground 可以对 Page 主代码中特定的标注文档进行渲染。

在 Playground 中添加可渲染标注文档非常简单，只需要在标准的注释标识符后面添加`:`即可。

```swift
import Foundation

/*:
 # Title
 ## Title2
 ### Title3
 * Line 1
 * Line 2
*/

//: **Bold** *Italic*

//:[肘子的 Swift 记事本](https://www.fatbobman.com)

//:![图片，可以设置显示大小](pic.png width="400" height="209")

/*:
    // 代码片段
    func test() -> Stirng {
        print("Hello")
    }

 */

print("Hello world")
```

在 Xcode 中，通过点击右侧的 Render Documentation 来设置是否启用文档渲染功能。

![image-20211230162340492](https://cdn.fatbobman.com/image-20211230162340492.png)

启用后，上面的代码将显示成如下样式：

![image-20211230162519229](https://cdn.fatbobman.com/image-20211230162519229.png)

> 目前尚不支持在文档标准中使用 Assets 中的图片。

Swift Playgrounds 中渲染文档功能将会一直启用，无法关闭。

> 更多关于可渲染标注代码的资料，请参阅苹果的 [官方文档](https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_markup_formatting_ref/index.html#//apple_ref/doc/uid/TP40016497-CH2-SW1)。

### 如何在多个 Page 之间导航

在多 Page 的状况下，可以在 Page 的主代码中，通过标注实现在各个 Page 之间的导航。

#### 前后导航

下面的代码可实现按导航栏顺序的前后跳转。

```swift
//: [Previous](@previous)

import Foundation

var greeting = "Hello, playground"

//: [Next](@next)
```

![image-20211230164205461](https://cdn.fatbobman.com/image-20211230164205461.png)

渲染后的状态

![image-20211230164227785](https://cdn.fatbobman.com/image-20211230164227785.png)

在 Page3 中点击 Previous，将跳转到 Page2。但点击 Next 将不会发生变化（因为 Page3 已经是最后一页）。

#### 导航到指定 Page

可以通过直接指定 Page 名称的方式，跳转到指定的页面

```swift
import Foundation

var greeting = "Hello, playground"

//: [页面 1](Page1)

//: [页面 2](Page2)
```

![image-20211230164542340](https://cdn.fatbobman.com/image-20211230164542340.png)

### 如何隐藏代码（Swift Playgrounds Only）

Swift Playground 具有极强的娱乐和教育属性，提供了若干特殊的标注方法来增强其在课件制作、展示方面的能力。最初这些标注只能用于`.playgroundbook`，目前已经可以用于`.playground`中。

隐藏代码的作用是，只在 Swift Playground 的代码区域中显示需要使用者了解的代码。将其他暂时无需使用者理会的代码隐藏起来（仍会执行，只是不显示）。

```swift
//#-hidden-code
import SwiftUI
import PlaygroundSupport
var text = "Hello world"
let view = Text(text).foregroundColor(.red)
PlaygroundPage.current.setLiveView(view)
//#-end-hidden-code

text = "New World"
```

上面的代码，在 Swift Playground 中只会显示最后一行代码。`//#-hidden-code`和`//#-end-hidden-code`之间的代码将被隐藏。

![image-20211230165753928](https://cdn.fatbobman.com/image-20211230165753928.png)

### 如何设置可编辑代码区域（Swift Playgrounds Only）

通过在 Page 代码中设定可编辑区域，使用者将只能在指定的编辑区域中修改代码。

```swift
//#-hidden-code
import SwiftUI
import PlaygroundSupport
var text = "Hello world"
let view = Text(text).foregroundColor(.red)
PlaygroundPage.current.setLiveView(view)
//#-end-hidden-code

//#-editable-code
text = "New World"
//#-end-editable-code
// 修改字体
view.font(.title)
```

使用`//#-editable-code`和`//#-end-editable-code`来设定可编辑区域。

![image-20211230170228566](https://cdn.fatbobman.com/image-20211230170228566.png)

使用者只能修改矩形框中的代码。可编辑区域外的代码，例如下方的`view.font(.title)`显示但不可修改。

> 隐藏代码和设定修改区域在制作交互式文档中的作用巨大，希望 Xcode Playground 能尽早支持上述的标注。

## 使用 Xcode Playground 探索软件包和项目

从 Xcode 12 开始，苹果将 Playground 和 Xcode 的协作带到了全新的高度。通过两者之间的深度整合，Xcode Playground 可以轻松地实现对 SPM 库、Xcode Project 以及 WorkSpace 中的代码、资源进行调用和测试。

### Playground in SPM

库开发者通过在基于 SPM 管理的库中添加 Playground 项目，提供可交互的文档和范例，帮助使用者快速掌握库的用法。

在 WWDC 的专题中，苹果的 Playground 项目开发人员希望未来 Swift 第三方库都可以附带一个基于 Playground 的交互式文档。

在库中添加 Playground 非常简单，在任意位置添加 Playground 项目（`.playground`）即可。

![image-20211230185815511](https://cdn.fatbobman.com/image-20211230185815511.png)

使用注意事项：

1. 在 Playground 代码中需要引入库文件

2. 只能调用库中标记为 public 的代码

3. 不能调用库中的资源

4. 不能使用库中调用库中资源的代码
5. 在执行 Playground 代码前，需选择正确的 Target（Target 应与 Playground 设置的运行环境相匹配）
6. 启用 Build Active Scheme，在切换 Target 时自动编译库文件

![image-20211230191332517](https://cdn.fatbobman.com/image-20211230191332517.png)

相较于其他几点，第 4 点略微难理解一点。Playground 在执行 Page 代码的时候尽管会率先将库编译完成，但并没有为库设置正确的资源 Bundle，如果库中的代码尝试调用库资源的时候会报错。目前只适用于无需调用库资源文件的代码。

![image-20211230190514926](https://cdn.fatbobman.com/image-20211230190514926.png)

### Playground with Project

使用注意事项：

1. 在不开启 Import App Types 的情况下，必须导入项目才可调用项目中可公开调用的代码（public）
2. 在开启了 Import App types 的情况下，无需导入项目即可调用项目中的代码（非 Private）
3. 可以调用项目中导入的第三方 Package
4. 不可直接使用项目中的资源
5. 可以通过调用项目中使用项目资源的代码，间接获取项目中的资源
6. 在执行 Playground 代码前，需选择正确的 Target（Target 应与 Playground 设置的运行环境相匹配）
7. 启用 Build Active Scheme，在切换 Target 时自动编译库文件
8. 在执行 Playground 代码前，应确保当前 Target 已经编译

相较 Playground in SPM，不同点包括：

* 开启 Import App Type 后，可以直接使用项目中的代码（无需 public ）
* 可以导入当前 Target 中使用到的其他第三方 Package。
* 通过项目中的代码，可以间接调用项目中的资源

![image-20211230193408447](https://cdn.fatbobman.com/image-20211230193408447.png)

下图中，在项目 MyPlayDemo 中，包含有如下代码（方法、变量都非 public）：

```swift
import Foundation
import UIKit

func abc() {
    print("abc")
}

let a = 100

// 读取项目 Assets 中的图片
func getProjectImage() -> UIImage? {
    UIImage(named: "abc")
}
```

在 Playground 中，无需 import 项目名称，可以直接使用项目中的代码（需启用 Import App Types）。

PlaygroundPackageDemo 是当前 Target 中添加的 Package，也可以在 Playground 中直接导入。

![image-20211230193640999](https://cdn.fatbobman.com/image-20211230193640999.png)

### Playground with WorkSpace

有时候，你可能想在工作区中创建 Playground 来测试多个项目或框架。

在 WorkSpace 中使用 Playground 的注意事项：

1. 每个 Page 中只能执行工作区中的一个项目的代码
2. 每个 Page 中可以导入工作区中已编译好且同当前 Page 运行环境兼容的 Package（Package 可以是从不同的的项目中导入）
3. 不可以直接使用项目中的资源
4. 可以通过项目中的代码，间接获取项目中的资源
5. 只能调用具有公开权限的代码（public）
6. 在执行当前 Page 的代码前，需保证当前代码导入的项目、库都已编译完成
7. 在执行当前 Page 的代码前，将 Target 切换到当前代码导入的项目的兼容 Target

![image-20211230204457662](https://cdn.fatbobman.com/image-20211230204457662.png)

上图中，WorkSpace 中有两个项目（DemoiOS 13 和 MyPlayDemo）。

Page1 中导入了 MyPlayDemo 项目，以及 MyPlayDemo 的依赖项 PlaygroundPackageDemo，项目 DemoiOS13，以及 SwiftUIOverlayContainer（项目 DemoiOS 13 的依赖项）。

不过只能执行一个项目中的代码（但是可以执行另一个项目中依赖项的代码）。

Playground in SPM、Projcet、WorkSpace 之间并不冲突，你可以直接执行任何层级的 Playground 项目。

![image-20211230205122196](https://cdn.fatbobman.com/image-20211230205122196.png)

### 在 Swift Playgrounds 中使用第三方库

Swift Playground 并不支持直接为 `.playground` 添加第三方库。但可以通过将第三方库 Source 目录下的代码拷贝到 Playground 的 Sources 目录中，实现对第三方库的部分支持。

此种方式仅适用于不使用库资源的第三方库。

![image-20211230205936953](https://cdn.fatbobman.com/image-20211230205936953.png)

上图中，将 [Plot](https://github.com/JohnSundell/Plot) 库代码拷贝到了 Playground 的项目 Sources 目录中。全部 Page 均可直接调用 Plot API 而无需导入。

## 总结

不要小看 Xcode Playground，它具有远超想象的能力和效率。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。

