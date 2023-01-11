---
date: 2020-10-27 12:00
description: 本文介绍了其中几个在健康笔记开发过程中使用的第三方的开源库
tags: SwiftUI, 健康笔记
title: 介绍几个我在开发健康笔记 2 用到的 Swift 或 SwiftUI 第三方库
---

## [SwiftUIX](https://github.com/SwiftUIX/SwiftUIX) ##

> SwiftUIX 试图弥补仍处于新生阶段的 SwiftUI 框架的空白，提供了广泛的组件，扩展和实用程序套件来补充标准库。 迄今为止，该项目是缺少的 UIKit / AppKit 功能的最完整的移植，力求使其以大多数类似于 Apple 的方式交付。
> 这个项目的目标是补充 SwiftUI 标准库，提供数百种扩展和视图，使开发人员可以轻松地通过 SwiftUI 的革命来构建应用程序。

提供了非常多的苹果本应提供但没有提供的功能扩展。项目的发起者非常年轻，但 mac 的开发经验十分丰富。到目前为止一直保持的较高的更新频率和维护状态。这个库同时支持 UIKit 和 Appkit，对于需要做苹果生态全平台的用户十分友好。由于目前 SwiftUI 的 List 和 LazyVStack 的问题还很多，他自己在开发中也深受其苦，前天在交流中，他已经决定重做 CocoaList 功能，尤其提高对 Fetchrequest 的支持。

对于进行 SwiftUI 开发的朋友，它是十分值得推荐的。

目前的问题是文档太少。不过对我来说也未尝不是一个好事。在研究它的用法过程中，给了我更多的机会阅读并学习它的代码，对 SwiftUI，UIkit 等有了更多的认识和了解。

```responser
id:1
```

## [Charts](https://github.com/danielgindi/Charts) ##

> denielgindi 对著名的安卓图表库 MPAndroidChart 的 Swift 移植。是目前不多的纯 Swift 解决方案。它的优势也是同时支持 UIKit 和 Appkit，同时提供了不错的 Demo 社区活跃度。

不过他的开发者好像不打算在 3.x 版本上在增加太多的功能，非常多目前急需并且已有解决方案的功能并没有被当前版本接受。所以整体的视觉呈现还是比较传统的。社区上对于功能的讨论不少，但合并的极少，4.0 的版本好像也已经开发了不短的时间了，不过进度好像也不是特别理想。

从效率上讲，Charts 应该是非常合格的了。

[航歌](https://www.hangge.com) 上面有非常详细的中文使用教程，对我的学习帮助很大。

为了健康笔记开发的需要，我在当前 3.6 的版本上合并了两个社区上较为成熟的解决方案：

* 圆角 Bar

```swift
  dataSet.roundedCorners = [.topLeft,.topRight]
```

* 渐变色 Bar

```swift
  dataSet.drawBarGradientEnabled = true
              dataSet.colors = [UIColor(named: "barColor1")!, UIColor(named: "barColor1")!, UIColor(named: "barColor2")!]
              dataSet.gradientPositions = [0, 40, 100]
```

由于当前的 Charts 本身并不支持对于图表滚动后停止事件的响应，我自己为它增加了停止响应。

```swift
        //滚动终止时调用
        func chartScrollStop(_ chartView:ChartViewBase){
            print("stopped")
        }
```

修改后的代码 [在此可以获得](https://github.com/fatbobman/Charts)。

## [Introspect](https://github.com/siteline/SwiftUI-Introspect) ##

> Introspect 允许您获取 SwiftUI 视图的基础 UIKit 或 AppKit 元素。
> 例如，使用 Introspect，您可以访问 UITableView 来修改分隔符，或访问 UINavigationController 来自定义选项卡栏。

有一个非常推荐的利器。目前官方对于 SwiftUI 中的控件提供的可控选项很少，如果想做一些深度定制的话，通常就是自己写代码来重新包装 UIkit 控件。不过 introspect 提供了一个非常巧妙的办法通过简单的注入方式便可以对 SwiftUI 控件做更多的调整。

比如：

只有当内容超出显示范围才进行滚动

```swift
ScrollView{
    ....
}
.introspectScrollView{ scrollView in
        crollView.isScrollEnabled = scrollView.contentSize.height > scrollView.frame.height
               }
```

显示 TextField 的 clear 按钮

```swift
TextField("note_noteName",text: $myState.noteName)
          .introspectTextField{ text in
             text.clearButtonMode = .whileEditing
           }
```

对于新的控件它本身还没提供具体支持的也可以方便的注入

修改 SwiftUI2.0 中新提供的 TextEditor 背景色

```swift
TextEditor(text: $text)
                .introspect(selector: TargetViewSelector.sibling){ textView in
                    textView.backgroundColor = .clear
                }
```

等等。类似的用法在我整个的开发中的使用频率是很高的。

## [SwiftDate](https://github.com/malcommac/SwiftDate) ##

> 使用 Swift 编写的时间日期处理库。同时支持苹果平台以及 Linux。

它提供了非常详尽的文档，航哥上也有非常好的中文教程。

由于健康笔记需要对数据进行不少处理，尤其是需要将相同时间粒度的数据进行合并比较。SwiftDate 提供的 Region 方案提供了完美的解决途径。

在 SwiftDate 中，我多数使用它提供的 DateInRegion 来处理日期。通过

```swift
SwiftDate.defaultRegion = region
```

我几乎无需关心日期的本地化问题。而且它也提供了部分的日期时间的本地化显示方案（但并不完美）。

一些使用举例：

除非用户在 app 中设定了特定的时区，否则使用当前设备的默认设置：

```swift
if let data = UserDefaults.standard.data(forKey: "dateRegion"),
           let region = try? JSONDecoder().decode(Region.self, from: data) {
            SwiftDate.defaultRegion = region
        }
        else {
            SwiftDate.defaultRegion = Region(calendar: Calendars.gregorian, zone: Zones.current, locale: Locales.current)
        }
```

判断某个日期和指定日期的天数差（本地时区）：

```swift
let startDate = DateInRegion(datas.first!.viewModel.date1).dateTruncated(at: [.hour,.minute,.second])!
duration = date.difference(in: .day, from: startDate) ?? 0
```

如果你的程序需要对日期进行频繁的处理或者有较多的本地化需求时，SwiftDate 是非常好的选择！

## [SwiftUIOverlayContainer](https://github.com/fatbobman/SwiftUIOverlayContainer) ##

> SwiftUIOverlayContainer 本身并不提供任何预置的视图样式，不过通过它，你有充分的自有度来实现自己需要的视图效果。OverlayContainer 的主要目的在于帮助你完成动画、交互、样式定制等基础工作，使开发者能够将时间和精力仅需投入在视图本身的代码上。

这是我自己写的一个库，这次通过它实现的屏幕侧边滑动菜单。

本来它的用途主要不是做这个的，暂时使用它来完成侧向滑动菜单也是权宜之计，表现尚可。

## [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) ##

> ZIP Foundation 是一个用于创建，读取和修改 ZIP 存档文件的库。
> 它是用 Swift 编写的，基于 Apple 的 libcompression 来实现高性能和高能效。

小巧、高效，使用便捷。健康笔记在数据导入导出时，使用它来完成 zip 文件的操作。

比如解压备份数据：

```swift
//打开沙盒读取权限
   _ = url.startAccessingSecurityScopedResource() 
//解压
   do {
      try FileManager.default.unzipItem(at: url, to: URL(fileURLWithPath: NSTemporaryDirectory()))
        }
        catch {
          
        }
```

## [MarkdownView](https://github.com/keitaoouchi/MarkdownView) ##

> 基于 WKwebView 实现的 Markdown 文件 Viewer。对 md 的解析是通过调用 js 库来完成的。

由于 SwiftUI 的 Text 文本排版能力几乎为零，因此我选择使用 md 格式来保存 app 所需的一些文字显示，比如隐私政策等。

MarkdownView 的渲染效率一般，但我的显示需求并不大，所以感觉不明显。但它的开发者对 js 文件进行了加扰处理，所以如果你想对其中它所调用的例如 mardown-it 进行更多配置的话，就几乎不可能了。

另外，通过 UIViewRepresentable 对其进行封装，在 SwiftUI 下是无法正确获取 frame 的尺寸的，从而无法正确显示。我对于 UIkit 所知甚少，只能做了最简单的修改，勉强让其可以在 SwiftUI 下完成所需要的功能。

修改后的版本可在 [这里下载](https://github.com/fatbobman/MarkdownView)

另外，我在 UIViewRepresentable 包装中增加了一些简单的修改，使其可以方便的将 md 中的图片，替换成 Bundle 中的本地图片。

调用代码 [下载](https://github.com/fatbobman/ShareCode/blob/main/MarkDownView.swift)

## [ExcelExport](https://github.com/avielg/ExcelExport/blob/master/Sources/ExcelExport/ExcelExport.swift) ##

> 生成 XSL 文件的 Swift 代码。

这段代码有一段时间了，不过去年又做了更新，不过我感觉更新后的版本还不如之前的。但它的新版本不支持 Date 的字段导出，老版本导出的 Date 字段格式在 Excel 中也有问题。我合并了两个版本，并且让其在命名上对 SwiftUI 更加友好。

修改后的代码 [下载](https://github.com/fatbobman/ShareCode/blob/main/ExcelExport)

必须对日期做如下处理，日期字段才能被 Excel 顺利识别

```swift
 let date = DateInRegion(memo.viewModel.date).toFormat("yyyy-MM-dd")
 let time = DateInRegion(memo.viewModel.date).toFormat("HH:mm:ss.FFF")
 let dateCell = ExcelCell(date + "T" + time,type: .dateTime)
```

上述的库都被使用在 [健康笔记 2.0](https://apps.apple.com/us/app/health-notes-2/id1534513553) 中。如想查看更多的演示，可以移步

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
