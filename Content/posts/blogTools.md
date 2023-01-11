---
date: 2022-05-05 08:20
description: 从 2020 年 4 月开始，截至本月，我的博客【肘子的 Swift 记事本】已创建 2 年了。这期间，使用过不少的工具以协助博客的创作。本文将对我正在使用中的应用工具（包含资料收集整理、文本编辑、截图及录屏、格式转换、图片编辑、图床管理等方面）做以介绍。
tags: Blog
title:  我正在使用中的博客创作工具
image: images/blogTools.png
---
从 2020 年 4 月开始，截至本月，我的博客【肘子的 Swift 记事本】已创建 2 年了。这期间，使用过不少的工具以协助博客的创作。本文将对我正在使用中的应用工具（包含资料收集整理、文本编辑、截图及录屏、格式转换、图片编辑、图床管理等方面）做以介绍。

## 资料收集整理

### 印象笔记

> 高级账户 148 元/年

让我坚持使用 [印象笔记](https://www.yinxiang.com) 的动力便是它提供的 web clipper 工具——[剪藏](https://www.yinxiang.com/product/webclipper1/)。剪藏让用户可以只保存部分的网页内容并且提供了保存自动翻译后的页面能力。我将印象笔记作为网络内容资料库，保存了大量有价值的内容，供日后查询和整理。遗憾的是，剪藏目前并没有提供 iOS 版本插件。

有一点需要吐槽，作为高级账户成员，印象笔记仍总是不断地提示我升级到专业版本，略影响使用感受。如果你每个月保存的内容不太多且无需在超过 2 台设备上登录，免费版应该可以满足大多数人的需求了。

![image-20220429091144548](https://cdn.fatbobman.com/image-20220429091144548.png)

### OneNote

> Office 365 家庭版，不到 400 元/年 （优惠后）

在 Office 365 提供的所有软件中，OneNote 对我来说是最有用的工具。无论是做学习笔记还是知识整理，几年来，我在 OneNote 中记录、整理了不少的内容。遗憾的是 macOS 版本无法使用 markdown 插件，因此我会以截图的方式记录代码片段（此种方式对空间的占用较大，幸好 OneDriver 提供了 1TB 的容量），并将保存完整的源代码文件以附件的形式添加在笔记中。由于 OneNote 对图片内文本的搜索准确度很好，因此并不会带来查找上的困难。

近几年 OneNote 基本上没有增加什么新的功能，不知道是不是微软将更多的精力都放在了即将发布的 Loop 上面。

![image-20220429091230243](https://cdn.fatbobman.com/image-20220429091230243.png)

```responser
id:1
```

## 文本编辑

### Typora

> 89 元

[Typora](https://typora.io) 的最大优势便是沉浸感。作为一个所见即所得的 Markdown 格式编辑器，Typora 为创作者提供了更加专注的写作环境。

Typora 转入收费模式后，在网络上引起了一些讨论，对我而言，当前的价格是对得起它的品质的。

![image-20220429090947550](https://cdn.fatbobman.com/image-20220429090947550.png)

### VSCode

> 免费

由于 Typora 缺乏插件机制以及 Git 版本控制能力（当前的版本管理是基于时间机器的），因此我使用 [VSCode](https://visualstudio.microsoft.com) 作为 markdown 文本的格式校验以及文件管理工具。

有两个 VSCode 的插件对我的帮助很大：

* [markdownlint](https://marketplace.visualstudio.com/items?itemName=DavidAnson.vscode-markdownlint)

  检查 markdown 文件中的语法错误

* [Pangu-Markdown](https://marketplace.visualstudio.com/items?itemName=xlthu.Pangu-Markdown)

  自动为英文添加空格，改善中英文的混排格式

![image-20220429090832604](https://cdn.fatbobman.com/image-20220429090832604.png)

## 截图及录屏

### QuickTime

> 免费

QuickTime 作为 macOS 的内置应用，提供了不错的截图和录屏能力。遗憾的是较少的选项和附加功能限制了它的能力上限。但通过它以原生分辨率（5K、6K）录制的屏幕视频，效果十分惊人。

![image-20220429091343815](https://cdn.fatbobman.com/image-20220429091343815.png)

另外，我也会使用 QuickTime 作为视频的剪裁和格式转换工具。

### iShot

> 29 元 / 年

[iShot](https://www.better365.cn/ishot.html) 是一个十分优秀的国产截屏软件，提供了截屏美化（阴影、设备边框）、即时标注等功能。它是我目前使用率最高的截屏工具。其免费版本提供的功能已经能够满足绝大多数使用者的需求了。本文中的截图都是使用 iShot 来完成的。

![image-20220429091417362](https://cdn.fatbobman.com/image-20220429091417362.png)

### Xcode Simulator

> 免费

在仅需获取模拟器截图或不需要录制设备外框的情况下，Simulator 是非常好的选择。不过由于缺乏定制能力，我几乎不会使用它的 Gif 动图录制功能。

![image-20220429091437825](https://cdn.fatbobman.com/image-20220429091437825.png)

### RocketSim PRO

> 99 美元/年

[RocketSim PRO](https://www.rocketsim.app) 是知名 Swift 博主 [Antoine van der Lee](https://www.avanderlee.com) 开发的工具。最初的版本仅拥有模拟器录屏能力，经过快速的迭代升级（当前为 7.0 版本），目前则是添加了 UI 比对、Deep link 测试、模拟器应用权限设置等众多功能。正常情况下，免费版提供的功能已够不少开发者使用了，之所以购买了收费版本，一是为了获得更好的视频录制能力（可以集成录制设备边框），另外也是对该作者长期以来提供的优秀文章的感谢。

![image-20220429091543718](https://cdn.fatbobman.com/image-20220429091543718.png)

### CodeShot

> 5.99 美元

[CodeShot](https://codeshotapp.com) 是另一位优秀的 Swift 博主 [Sarun](https://sarunw.com) 开发的 mac 应用。它可以将代码片段转换成漂亮的图片以便在文章或社交媒体上分享。虽然已经有提供类似功能的网站，但我更喜欢使用原生的应用版本。

![image-20220429093740171](https://cdn.fatbobman.com/image-20220429093740171.png)

## 格式转换

### Gif Brewery

> 4.99 美元

[GIF Brewery](https://apps.apple.com/us/app/gif-brewery-3-by-gfycat/id1081413713?mt=12&uo=4&app=apps) 是动图网站 gfcat 提供的 Gif 动图制作工具。尽管已经 3 年没有更新了，但即便在当前也难觅敌手。除了可以将视频转换成 Gif 动图外，还支持添加文字、标识编辑、视频录制、动图管理等众多功能。

![image-20220429091657780](https://cdn.fatbobman.com/image-20220429091657780.png)

### handBrake

> 免费且开源

[handBrake](https://handbrake.fr) 是一款支持众多音视频格式的编解码工具。高效、小巧且免费，几乎找不到缺点。

![image-20220429091833320](https://cdn.fatbobman.com/image-20220429091833320.png)

## 图片编辑

### 预览

> 免费

macOS 系统的内置应用——预览是我使用率最高的图片编辑工具。大多数情况下，它都是我更改视图尺寸的首选。

![image-20220429092834814](https://cdn.fatbobman.com/image-20220429092834814.png)

### Figma

> 个人免费版

[Figma](https://www.figma.com) 是我用来制作 Twitter card 和其他出现在博客中的矢量图的主要工具。免费版本已经完全能够满足我的需求。随着国内类似产品的不断完善，我最近正逐步切换到 pixso 上。

![image-20220429092949936](https://cdn.fatbobman.com/image-20220429092949936.png)

### Affinity Photo

> 168 元（疫情打折时价格）

疫情初期购买了 Affinity 的三件套（绝对良心价格 168 * 3）。我主要用 [Affinity Photo](https://affinity.serif.com/en-gb/photo/) 对位图进行编辑和处理。相较于 Pixelmator Pro，Affinity Photo 的功能设定和 UI 布局更接近于 PS 的使用习惯。

![image-20220429093111762](https://cdn.fatbobman.com/image-20220429093111762.png)

## 图床管理

### picGo

[PicGo](https://github.com/Molunerfinn/PicGo) 是一个用于快速上传图片并获取图片 URL 链接的工具，Typora 对其提供了完美的支持。事实上，在 PicGo 中完成了图床的设定后，我就没有再单独地开启过这个软件了。

![image-20220429093145410](https://cdn.fatbobman.com/image-20220429093145410.png)

### kodo Browser

[七牛](https://www.qiniu.com) 提供的官方文件管理器，仅在批量上传图片时使用。

![image-20220429093219705](https://cdn.fatbobman.com/image-20220429093219705.png)

## 总结

工欲善其事，必先利其器。趁手的工具可以帮助使用者做到事半功倍。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
