---
date: 2022-11-08 08:12
description: 随着 SPM（ Swift Package Manager ） 功能的不断完善，越来越多的开发者开始在他的项目中通过创建多个 Package 的方式来分离功能、管理代码。SPM 本身提供了对包中各类资源（ 包括本地化资源 ）的管理能力，但主要局限于在本包中使用这些资源，难以将资源进行共享。在有多个 Target 均需调用同一资源的情况下，原有的方式很难应对。本文将介绍一种在拥有多个 SPM 包的项目中，对资源进行统一管理的方法。
tags: SwiftUI,本地化,Foundation,SPM
title: 在多包项目中统一管理资源
image: images/unified_management_of_resources_in_multi-package_projects.png
---
随着 SPM（ Swift Package Manager ） 功能的不断完善，越来越多的开发者开始在他的项目中通过创建多个 Package 的方式来分离功能、管理代码。SPM 本身提供了对包中各类资源（ 包括本地化资源 ）的管理能力，但主要局限于在本包中使用这些资源，难以将资源进行共享。在有多个 Target 均需调用同一资源的情况下，原有的方式很难应对。本文将介绍一种在拥有多个 SPM 包的项目中，对资源进行统一管理的方法。

## 问题

笔者最近正在使用 TCA（ [The Composable Architecture](https://www.fatbobman.com/posts/the_Composable_Architecture/) ）结合 SwiftUI 做一些开发，在 TCA 中，开发者通常会为一个 Feature 创建一个独立的包或在一个统一的包（ 拥有众多的 Target ）中创建一个单独的 Target。Feature 中通常会包含有关 UI 的逻辑处理代码（ Reducer ）、单元测试代码、与该 Feature 相关的视图代码以及预览代码。每个 Feature 基本上可以被视作一个可独立运行的小应用（ 在注入所需的环境后 ）。最终开发者需要通过在 Xcode 项目中导入所需的 Feature 模块，并通过串联代码将完整的 app 组合出来。在这种情况下，几乎每个 Feature 以及 Xcode 项目代码都需要使用到本地化及其他一些共用资源。

假设将共用资源分别复制到不同模块的 Resource 目录中，那么会造成如下的问题：

* 每个模块中都有重复的资源，应用的尺寸将增大
* 难以管理共用资源，可能会出现更新不同步的情况

如果所有的模块都位于同一个目录下，通过使用相对路径的方式，可以在各自的 Resources 目录中导入共用资源，这样虽然可以避免上述的更新不同步的情况，但仍需面对两个问题：

* 每个模块中都有重复的资源，应用的尺寸将增大
* 模块与资源文件之间的耦合度增加，不利于用多个仓库来分别管理

总之，最好能有一种方式可以做到：

* 资源与模块和 Xcode 项目之间低耦合度
* 可以统一管理资源，不会出现不同步
* 在最终的应用中只需要保留一份资源拷贝，不会造成存储的浪费

```responser
id:1
```

## 思路

Bundle 为代码和资源的组织提供了特定结构，意在**提升开发者的体验**。这个结构不仅允许预测性地加载代码和资源，同时也支持类似于本地化这样的系统性特性。Bundle 在存储上以目录的形式存在，在代码中则需要通过 Foundation 框架中的 Bundle 类来体现。

Xcode 工程项目本身就是在一个 Bundle 之下，开发者可以使用 `Bundle.main` 来获取其中的资源。

在 SPM 中，如果我们为 Target 添加了资源，那么在编译的时候，Xcode 将会自动为该 Target 创建一个 Bundle ，名称为 PackageName_TargetName.bundle（ 非 Mac 平台，尾缀为 resources ）。如果我们可以在其他的 Target 中获取到该 Bundle 的 URL ，并用其创建一个 Bundle 实例，那么就可以用下面的方式使用该 Bundle 中的资源：

```swift
Text("MAIN_APP", bundle: .i18n)
      .foregroundColor(Color("i18nColor", bundle: .i18n))
```

因此，创建一个可以在**任何状态**下指向特定目录的 Bundle 实例便成了解决问题的关键。之所以强调任何状态，是因为，Swift 会视项目的编译需求而将 Bundle 放置在不同的目录层级上（ 例如单独编译 SPM Target 、在 SPM 中进行 Preview、在 Xcode 工程中引入 SPM Target 后编译应用等 ）。

幸运的是，Xcode 为我们提供了一段展示如何创建可应对多种编译状态下 Bundle 实例的示例代码。

在 SPM 中，如果你为 Target 添加了至少一个资源，那么 Xcode 将会为你创建一段辅助代码（ 该段代码并不包含在项目中，只在 Xcode 中起作用 ），生成一个指向该 Target Bundle 的实例：

![Bundle_module_2022-11-06_17.30.46.2022-11-06 17_33_41](https://cdn.fatbobman.com/Bundle_module_2022-11-06_17.30.46.2022-11-06%2017_33_41.gif)

代码如下：

```swift
private class BundleFinder {}

extension Foundation.Bundle {
    /// Returns the resource bundle associated with the current Swift module.
    static let module: Bundle = {
        let bundleName = "BundleModuleDemo_BundleModuleDemo" // PackageName_TargetName

        let overrides: [URL]
        #if DEBUG
        if let override = ProcessInfo.processInfo.environment["PACKAGE_RESOURCE_BUNDLE_URL"] {
            overrides = [URL(fileURLWithPath: override)]
        } else {
            overrides = []
        }
        #else
        overrides = []
        #endif

        let candidates = overrides + [
            // Bundle should be present here when the package is linked into an App.
            Bundle.main.resourceURL,

            // Bundle should be present here when the package is linked into a framework.
            Bundle(for: BundleFinder.self).resourceURL,

            // For command-line tools.
            Bundle.main.bundleURL,
        ]

        for candidate in candidates {
            let bundlePath = candidate?.appendingPathComponent(bundleName + ".bundle")
            if let bundle = bundlePath.flatMap(Bundle.init(url:)) {
                return bundle
            }
        }
        fatalError("unable to find bundle named BundleModuleDemo_BundleModuleDemo")
    }()
}
```

该段代码的基本逻辑是提供了三种可能的 Bundle 存放位置：

* Bundle.main.resourceURL
* Bundle(for: BundleFinder.self).resourceURL
* Bundle.main.bundleURL

在创建 Bundle 实例时，逐个位置查找，直到找到对应的 Bundle 目录后再创建实例。随后，我们就可以在代码中使用这个 Bundle.module 了 ：

```swift
Text("Hello",bundle: .module)
```

很遗憾，上述的代码并没有覆盖全部的可能性，譬如在当前 Target 中运行 SwiftUI 的预览代码，就会出现无法找到对应的 Bundle 的情况。不过这已经为我们指明了道路，只要提供的备选位置足够充分，那么就有在任何场景下都成功创建对应的 Bundle 实例的可能。

## 实践

本节，我们将通过一个具体案例来演示如何在一个拥有多个包的 Xcode 项目中统一管理资源。可以在 [此处](https://github.com/fatbobman/BlogCodes/tree/main/UnifiedLocalizationResources) 获得项目代码。

演示项目中，我们将创建一个名为 UnifiedLocalizationResources 的 Xcode 工程。并在其中创建三个 Package ：

* I18NResource

  保存了项目中所有的资源，另外还包含一段创建 Bundle 实例的代码

* PackageA 

  包含了一段 SwiftUI 视图代码以及一段预览代码，视图中使用了 I18NResource 的资源

* PackageB

  包含了一段 SwiftUI 视图代码以及一段预览代码，视图中使用了 I18NResource 的资源

![image-20221106175122954](https://cdn.fatbobman.com/image-20221106175122954.png)

所有的资源都保存在 I18NResource 的 Resources 目录下，PackageA、PackageB 以及 Xcode 工程代码中都将使用同一份内容。

### I18NResource

* 在 Target 对应的目录下创建 Resources 目录
* 修改 Package.swift，添加 `defaultLocalization: "en",` 启用本地化支持
* 在 I18NResource.swift 中添加如下代码：

```swift
private class BundleFinder {}

public extension Foundation.Bundle {
    static let i18n: Bundle = {
        let bundleName = "I18NResource_I18NResource"
        let bundleResourceURL = Bundle(for: BundleFinder.self).resourceURL
        let candidates = [
            Bundle.main.resourceURL,
            bundleResourceURL,
            Bundle.main.bundleURL,
            // Bundle should be present here when running previews from a different package "…/Debug-iphonesimulator/"
            bundleResourceURL?.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent(),
            bundleResourceURL?.deletingLastPathComponent().deletingLastPathComponent(),
            // other Package
            bundleResourceURL?.deletingLastPathComponent()
        ]

        for candidate in candidates {
            // 对于非 mac 苹果，可以需要使用 resources 尾缀
            let bundlePath = candidate?.appendingPathComponent(bundleName + ".bundle")
            if let bundle = bundlePath.flatMap(Bundle.init(url:)) {
                return bundle
            }
        }
        fatalError("unable to find bundle named \(bundleName)")
    }()
}

```

代码与 Xcode 自动生成的 module 代码很类似（ 就是在其基础上做的修改 ），但增加了三个新的候选项以适应更多的场景。现在只要调用 `Bundle.i18n` ，就可以根据所处环境生成正确的 Bundle 实例了。

* 添加资源文件

  ![image-20221106182644181](https://cdn.fatbobman.com/image-20221106182644181.png)

### PackageA

* 修改 Package.swift

  添加 `defaultLocalization: "en"`, 在 Package 的 dependencies 中添加 `.package(path: "I18NResource")` ，在 PackageA target 的 dependencies 中添加 `.product(name: "I18NResource", package: "I18NResource")`

* 修改 PackageA.swift 代码

```swift
import I18NResource // 导入资源库
import SwiftUI

public struct ViewA: View {
    public init() {}
    public var body: some View {
        Text("HELLO_WORLD", bundle: .i18n) // 使用 Bundle.i18n
            .font(.title)
            .foregroundColor(Color("i18nColor", bundle: .i18n)) // 使用 Bundle.i18n
    }
}

struct ViewAPreview: PreviewProvider {
    static var previews: some View {
        VStack {
            ViewA()
                .environment(\.locale, .init(identifier: "zh-cn"))
            VStack {
                ViewA()
                    .environment(\.locale, .init(identifier: "zh-cn"))
            }
            .environment(\.colorScheme, .dark)
        }
    }
}
```

![image-20221106182759688](https://cdn.fatbobman.com/image-20221106182759688.png)

现在我们已经可以在 PackageA 中使用 I18NResource 中的资源了。

> PackageB 的操作与 PackageA 基本一致

### Xcode 工程

* 为工程导入 PackageA 和 PackageB

![image-20221106183031414](https://cdn.fatbobman.com/image-20221106183031414.png)

* 修改 ContentView.swift

![image-20221106183121557](https://cdn.fatbobman.com/image-20221106183121557.png)

> 无需在 Xcode 工程中单独导入 I18NResource 模块，也可以直接使用其中的资源。

至此，我们便实现了本文的初衷：一个低耦合度、不增加容量、不会出现更新版本错误的统一资源管理方式。

## 总结

开发者不应仅仅将 SPM 视为一种包工具，应将其视为可以让你的项目以及开发能力获得提升的机遇。

> 随着时间的推移，每个模块都可以共享、测试和改进。对我来说，这不仅仅是一个小小的变化——这是一个巨大的飞跃。我的项目在每个级别都有所改进——它更稳定、更可测试，甚至更快。这并不是说 Swift Packages 有一个秘密功能可以让你的项目运行得更好。创建 Swift 包的过程迫使您采取良好和健康的步骤来最终改进您的项目，例如测试、API 设计、依赖注入、文档编写等等。一旦我这样做了，我就意识到模块化我的代码，组织起来，并使用 “API 驱动” 的设计是多么重要。 —— 摘自：Mastering Swift Package Manager

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ) 或博客的留言板与我进行交流。

> 我正以聊天室、Twitter、博客留言等讨论为灵感，从中选取有代表性的问题和技巧制作成 Tips ，发布在 Twitter 上。每周也会对当周博客上的新文章以及在 Twitter 上发布的 Tips 进行汇总，并通过邮件列表的形式发送给订阅者。

**订阅下方的 [邮件列表](https://artisanal-knitter-2544.ck.page/d3591dd1e7)，可以及时获得每周的 Tips 汇总。**
