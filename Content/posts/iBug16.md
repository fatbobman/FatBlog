---
date: 2022-09-27 08:12
description: 到 2022 年，SwiftUI 已经迈入了第四个年头。尽管在之前的版本更新过程中，SwiftUI  也出现了或多或少的问题，但从来也没有像 SwiftUI 4 这么严重。Bug 众多的现象不仅仅表现在 SwiftUI 上，在 iOS、macOS 以及苹果很多其他的产品上都有所体现。
tags: SwiftUI
title: iBug 16 有感
image: images/iBug16.png
---
> 由于在 SwiftUI 4 中，Lazy 容器的表现出现了与以往较大的差异，因此已完成大半的 《 使用 Lazy 容器的注意事项 》一文将暂时搁置，待情况稳定时再更新

到 2022 年，SwiftUI 已经迈入了第四个年头。尽管在之前的版本更新过程中，SwiftUI  也出现了或多或少的问题，但从来也没有像 SwiftUI 4 这么严重。Bug 众多的现象不仅仅表现在 SwiftUI 上，在 iOS、macOS 以及苹果很多其他的产品上都有所体现。

这绝非苹果独有的问题，整个社会目前都处在一种浮躁的发展轨迹中。求快、求变、求成效体现在方方面面，无论是企业还是个人。

```responser
id:1
```

不管消费者是否有购买新品的计划，每当新品诞生时，网络上充斥最多的声音就是“挤牙膏”。这反过来也会影响了企业的经营思路，为了迎合市场，企业会不断地推出新型号，为了变而变，为了不同而不同。

不过，消费者对变化的无限渴望也是由企业的各种措施导致的。当企业痴迷于为产品每年推出新的版本号，用订阅制取代买断制，让消费者在第一时间有感（ 而不是有用 ）成了首要目标。

OTA 这种本来用于某些特定领域的更新手段，被作为思想运用于经营、设计、制造等等领域，令人震惊。不出 Bug、少出 Bug 已变成奢望，高速迭代变成了主流 —— 在迭代中修复 Bug ，在迭代中创造 Bug。

> 自我安慰一下：SwiftUI 4 中出现了大量不可思议的 Bug，例如视图无法持久、task 无法触发、闭包代码无法更新视图（ 某些 Style 下 ）等情况。一方面表明，苹果的开发管理出现了明显的问题，另一方面，也间接地证明了 SwiftUI 4 重写了大量的底层代码，待这些代码稳定后，可能会有不错的结果（ 也许是更多的 Bug ）

我们真的需要走得这么快吗？

![stay_away_from_bugs_lie_down_together](https://cdn.fatbobman.com/stay_away_from_bugs_lie_down_together-4176048.jpeg)

> 我正以 [Twitter](https://twitter.com/fatbobman)、 [Discord 聊天室](https://discord.gg/ApqXmy5pQJ) 、博客留言等讨论为灵感，从中选取有代表性的问题和技巧制作成 Tips ，发布在 Twitter 上。每周也会对当周博客上的新文章以及在 Twitter 上发布的 Tips 进行汇总，并通过邮件列表的形式发送给订阅者。

**订阅下方的 [邮件列表](https://artisanal-knitter-2544.ck.page/d3591dd1e7)，可以及时获得每周的 Tips 汇总。**

