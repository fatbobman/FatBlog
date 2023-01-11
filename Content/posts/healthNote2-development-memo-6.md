---
date: 2020-10-26 12:00
description: 一晃国庆中秋长假即将结束，距离上次的随笔也有了一段时间。在最近的日子里，我一方面继续着开发的进程，同时还要付出相当的精力同 iOS14 中的各种 Bug 和异常斗智斗勇。本篇随笔主要记录了这段时间碰到的一些问题，以及聊聊 iOS14、Xcode12 以及 SwiftUI2.0 的一些优缺点。想到哪、写到哪，可能逻辑会比较混乱。
tags: SwiftUI, 健康笔记
title: 健康笔记 2.0 开发随笔（六）
---
收尾工作往往是最枯燥的。

最近这 10 几天，主要的工作都是查找 bug，改进性能，反复测试数据的稳定性，以及更加枯燥的文档准备工作。

向 app store 提交反倒异常顺利，中间只出现了一次反复。苹果要我确认是否会滥用用户的数据，在明确回复不会之后就通过了。想想去年底健康笔记 1.0 的上线反复折腾了我 10 多天。

[Core Data with CloudKit （一） —— 基础](/posts/coreDataWithCloudKit-1/)

[Core Data with CloudKit（二） —— 同步本地数据库到 iCloud 私有数据库](/posts/coreDataWithCloudKit-2/)

[Core Data with CloudKit（三）—— CloudKit 仪表台](/posts/coreDataWithCloudKit-3/)

[Core Data with CloudKit（四）—— 调试、测试、迁移及其他](/posts/coreDataWithCloudKit-4/)

[Core Data with CloudKit（五）—— 同步公共数据库](/posts/coreDataWithCloudKit-5/)

[Core Data with CloudKit （六） —— 创建与多个 iCloud 用户共享数据的应用](/posts/coreDataWithCloudKit-6/)

```responser
id:1
```

XCode 12 中的 StoreKit 对于调试应用内的购买实在是太方便了，在开发的最后阶段，我将 app 分成了基础版和专业版。基础版其实已经能应对生活中绝大多数的需求了。通过 StoreKit 的模拟环境，我的应用内购买没有使用任何沙盒测试便一次性的开发调试成功，并且上线后也运行正常。极大的提高了效率！

在本次历时近两个月的开发过程中，基本上没走太多弯路。真正让我消耗精力的反倒是和 iOS 14 以及 SwiftUI 2.0 中的 Bug 斗智斗勇。很多奇怪的问题，在对自己代码反复的检查之后才能基本确认是系统的原因，然后还需要设法用最少的代码重现问题得以最终确认。从 WWDC20 过后，目前已经给苹果提交了 10 几条的 Feedback。其中超过半数在不断的版本升级后得到了修复。

下面是我在这次的开发中使用的第三方库，我最近会对这些库进行详细的介绍：

* SwiftUIX
* Charts
* Introspect
* ZIPFoundation
* SwiftUIOverlayContainer
* SwiftDate
* MarkdownView

iPad 的适配工作量也比想象中的大。尽管 SwiftUI 己经提供了极大的方便，但如果想更好的利用 iPad 的特性的话，还是有不少工作需要完成的。

本地化也是这次开发的一个目标，难度不太大，但工作量不小。
