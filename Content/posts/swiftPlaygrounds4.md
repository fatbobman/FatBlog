---
date: 2021-12-20 08:10
description: 赶在 2021 年底，苹果终于发布了 Swift Playgrounds 4，作为近年来最具革命性意义的版本，Swift Playgrounds 4 提供了在 iPad 上开发可发行 app 的能力。本文将对 Swift Playground 4 的新功能做以介绍，并探讨将其作为开发工具的可行性。
tags: SwiftUI, Swift Playgrounds, Playground
title: Swift Playgrounds 4 娱乐还是生产力
image: images/swiftPlaygrounds4.png
---
赶在 2021 年底，苹果终于发布了 Swift Playgrounds 4，作为近年来最具革命性意义的版本，Swift Playgrounds 4 提供了在 iPad 上开发可发行 app 的能力。本文将对 Swift Playgrounds 4 的新功能做以介绍，并探讨将其作为开发工具的可行性。

> 本文中的 Swift Playgrounds 4 特指 iPad 版本。~~MacOS 下的 Swift Playgrounds 4 目前仍采用 3.x 引擎。~~ MacOS 下的 Playgrounds 4.1 版本已经换用了同 iPad 版本相同的内核。

## 关于 Swift Playgrounds

在 Swift 语言发布的两年后，苹果于 WWDC 2016 上推出了 iPad 版本的 Swift Playgrounds。

Swift Playgrounds 提倡以一种有趣的方式学习严肃的代码，它不要求用户具备编程知识，非常适合初学者。采用互动式的教学模式，苹果提供了一系列的课件，以满足 4-15 岁人群的需求。

![image-20211219194032374](https://cdn.fatbobman.com/image-20211219194032374.png)

> 上图中的课件内容，核心逻辑同几十年前的 Logo 语言十分类似，非常适合低幼人群。

或许受了“中国古拳法”的“人人有功练”影响，苹果提出了“人人能编程（Everyone Can Code）”计划。通过向美国的公立学校和教师提供大量的 iPad 和 Mac，希望在教育系统中大力推广 Swift 语言。该计划经过几年的运行，取得了一定的成绩，但效果并没有完全达到预期。

与此同时，智能玩具厂商也发现了 Swift Playgrounds 的潜力，推出了与之配合的课件，让 Swift Playgrounds 成为了教育玩具领域的重要工具。

Swift Playgrounds 是典型的寓教于乐型产品，最初的设计目标并不涉及专业开发所需的生产力方面需求。

从 3.x 版本开始，Swift Playgrounds 逐渐添加了一些适合专业开发者的功能，例如：

* 类似于 Xcode Playground 的共享 Swift 文件
* 更好的键鼠支持（随着 iPadOS 的键鼠能力的增强）
* 可以在控制台中显示 print() 语句的输出等

一些 Swift 开发者逐渐尝试使用 Swift Playgrounds 进行一些小规模的开发工作。

随着 iPad 性能的不断提升，尤其当苹果为 iPad Pro 推出了“你的下一台电脑，何必是电脑”的广告语后，不少 Swift 开发者呼吁苹果应该提供一款 iPad 版本的 Xcode。

当苹果在 WWDC 2021 上提出要在 iPad 上提供一款可以像 Xcode 一样开发 app 的应用时，人们都十分震惊并期待其尽早面世。

最终，在 2021 年底，苹果将 WWDC 2021 上展示的功能集成到了 Swift Playground 中，推出 Swift Playground 4.0 版本。

```responser
id:1
```

## Swift Playgrounds 4 的新功能

### 增加了对 Xcode Playground 文件格式的支持

尽管 Swift Playgrounds 的名称明显受到了 Xcode Playground 的影响，但长久以来，它的文件格式并不与 Xcode Playground 兼容。

Swift Playgrounds 采用了一种名为 playgroundbook 的包来管理课件以及开发者自创的代码。开发者很难将其它资源注入其中，限制了在 Swift Playgrounds 中编写代码的灵活性。通过提供 playground 包支持，让开发者以更加熟悉的方式进行工作，汇集并测试灵感，并随时可在 Mac 和 iPad 之间切换。

点击首页下方的【查看全部】，选择其中的 Xcode Playground。

![image-20211224160807063](https://cdn.fatbobman.com/image-20211224160807063.png)

事实上，在 Swift Playgrounds 的 Playground 模式下，除了无法指定代码的结束位置外，使用体验与 Xcode Playground 已经十分接近。

![image-20211219194001850](https://cdn.fatbobman.com/image-20211219194001850.png)

> 或许由于 iPad 下最多只能分两屏的原因，使用 Swift Playgrounds 的 playground 模式调试代码，我获得了比 Mac 上更好的专注度。

### 在 iPad 上开发可上线发行的 iOS 应用程序

Swift Playground 4 中最亮眼的新功能就是提供了直接在 iPad 上通过 Swift Playgrounds 构建应用程序的能力（需要 iPadOS 15.2）。项目采用了与 SPM 结构完全一致的 swiftpm 包。可以在 Xcode 上打开，并进一步编辑。

![image-20211219200232619](https://cdn.fatbobman.com/image-20211219200232619.png)

应用被限定使用 SwiftUI life cycle，提供了响应迅速的预览以及全屏运行模式，支持添加第三方 SPM 库。

![image-20211219195937459](https://cdn.fatbobman.com/image-20211219195937459.png)

开发者可以使用类似 Xcode `+Capablility`的选项来添加应用程序允许调用的系统功能。

![image-20211219200610143](https://cdn.fatbobman.com/image-20211219200610143.png)

在有开发者账户的情况下，可以直接将应用程序提交到 App Store 接受审核。

![image-20211219200946451](https://cdn.fatbobman.com/image-20211219200946451.png)

理论上来说，开发者可以不使用 Mac，仅在 Swift Playgrounds 中即可完成一个上线并发行的 iOS 应用程序。

### 更好的代码补全和帮助

在 4.0 版之前，Swift Playgrounds 采用了一种适合触摸屏方式的代码补全机制：

![image-20211219201452934](https://cdn.fatbobman.com/image-20211219201452934.png)

此种方式并不适用于习惯了专业 IDE 补全机制的开发者。在 4.0 版本中，Swift Playgrounds 在 playground 和 app 模式下，提供了同 Xcode 非常接近的代码补全和提示功能，极大地提高了代码的编写效率。

![image-20211219201734240](https://cdn.fatbobman.com/image-20211219201734240.png)

对于系统文档以及用户创建的 Markdown 注释均提供了良好的支持。

![image-20211219202725921](https://cdn.fatbobman.com/image-20211219202725921.png)

### Swift DocC 的全面支持

苹果为 Swift Playgrounds 4 提供了不少新的课件，主要集中于如何创建 app，如何使用 SwiftUI。苹果放弃了之前惯用的通过 PlaygroundBookTemplate 创建的课件方式，而是利用 Swift DocC 来组织教学内容。

![image-20211219203541692](https://cdn.fatbobman.com/image-20211219203541692.png)

Swift DocC 相较于 PlaygroundBookTemplate 编写更加容易，也更适合高阶的语言教学。另外，只需创建一套 Swift DocC 课件便可同时支持 iPad 和 Mac 两个平台。有鉴于此，相信不久的将来，会有更多官方和第三方的优秀课件涌现。

## Swift Playgrounds 4 的适用人群或场景

既然 Swift Playgrounds 4 已经提供了如此多针对专业开发需求的功能，是否可以将其作为严肃的生产力工具来对待呢？

经过几天来不间断地使用，我认为苹果并没有为了取悦专业开发者而彻底改变 Swift Playgrounds 的定位，现阶段 Swift Playgrounds 仍着重于教育用途，但提供了部分适合专业开发者使用的功能。

Swift Playgrounds 至今已经发展了 5 年，它的大量使用者应该已经掌握了足够的 Swift 编程基本技能，4.0 版本为他们提供了进一步提高的途径和手段。通过更专业的 playground 和 app 模式，将这些原本以娱乐的心态来使用 Swift Playgrounds 的学生转换为更专业的开发人员。

Swift Playgounds 4 在专业开发用途上的一些主要的功能缺失：

* playground 模式下无法导入 SPM（Xcode 下可以通过 project 或 workspace 来导入），目前只能将源码导入 Source 目录来实现对部分 SPM 进行测试
* app 模式下不提供调试功能
* app 模式下，系统功能选项不足，尤其不提供任何与 iCloud 服务相关的功能
* 无法单独开发与 CoreData、SpriteKit、SceneKit 等等有关的项目，类似的项目均需要在 Mac 上做大量的工作
* App Store 提交内容选项明显不足，当前演示的意味更浓（不排除将来苹果推出某种特别类型（例如针对学生）的开发者账户，更便宜、有限的应用定价机制、有限的发行范围）
* 不提供资源管理，不提供本地化资源设置等等

考虑到 Swift Playgrounds 的定位，我认为苹果只会在将来的版本中弥补少量的专业缺失功能。或许在合适的时机，苹果会为专业开发者提供 Xcode 的 iPad 版本（个人认为可能性不大）。

当前的 Swift Playgrounds 适用于如下的人群或场景：

* 对编程感兴趣的孩子和学生（传统优势领域）
* 对智能玩具有编程需要的人
* 掌握了基本的 Swift 编程技巧需要进一步提高的使用者
* 想接触 iOS 及 Swift 编程，但没有 Mac 机的开发者或编程爱好者，通过 Swift Playgrounds 可以用极低的成本进入 iOS 的开发生态（Swift Playgrounds 即使在数年前的 iPad 上也运行的相当流畅）
* 专业的 Swift 开发者用 playground 模式来实现灵感，测试想法（在生产力方面最接近 Mac 下的体验）
* 专业的 Swift 开发者在只有 iPad 的情况下，在 Swift Playgrounds 上继续进行 Mac 上尚未完成的部分工作（需将项目转换成 Swift Playgrounds App 模式）。

## 总结

马上就要寒假了，或许可以让你的孩子在使用 iPad 娱乐之余，通过 Swift Playgrounds 学习一下编程，当将自己开发的 app 共享给其他的同学时，一定可以获得相当的自豪和满足。

专业的 Swift 开发者也不应错过 Swift Playgrounds 这个优秀的工具，更多地挖掘 iPad 的潜力。

Swift Playgrounds 在保留了快乐教育的功能前提下，满足了部分场景下的生产力需求。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
