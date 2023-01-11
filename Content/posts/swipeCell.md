---
date: 2020-08-12 14:00
description: 随着 SwiftUI2.0 的不断完善，我觉得是时候将我的 app 做一个较大的升级了。之前一直想在 app 中实现类似 iOS 邮件程序那样优雅的侧滑菜单效果，在网上也找了一下，实现的较好的是适用于 UIKit 的，基本上没有能够很好的适配 SwiftUI 的项目库。最终自己在 Xcode12 实现了一个。
tags: SwiftUI,Project
title: 用 SwiftUI 实现 iOS mail 程序的侧滑菜单
---

> 随着 SwiftUI2.0 的不断完善，我觉得是时候将我的 app 做一个较大的升级了。之前一直想在 app 中实现类似 iOS 邮件程序那样优雅的侧滑菜单效果，在网上也找了一下，实现的较好的是适用于 UIKit 的，基本上没有能够很好的适配 SwiftUI 的项目库。最终自己在 Xcode12 实现了一个。

SwipeCell 是一个用 Swift 5.3 开发的 SwiftUI 库。目标是为了实现类似 iOS Mail 程序实现的左右滑动菜单功能。SwipeCell 需要 XCode 12 ,iOS 14

```responser
id:1
```

[SwipeCell GitHub](https://github.com/fatbobman/SwipeCell)

<video src="https://cdn.fatbobman.com/SwipeCellDemoVideo.mp4" controls = "controls">你的浏览器不支持本视频</video>

## 配置 Button ##

```swift
let button1 = SwipeCellButton(buttonStyle: .titleAndImage,
                title: "Mark", 
                systemImage: "bookmark",
                titleColor: .white, 
                imageColor: .white, 
                view: nil,   
                backgroundColor: .green,
                action: {bookmark.toggle()},
                feedback:true
                )
//你可以将按钮设置成任意 View 从而实现更复杂的设计以及动态效果
let button3 = SwipeCellButton(buttonStyle: .view, title:"",systemImage: "", view: {
    AnyView(
        Group{
            if unread {
                Image(systemName: "envelope.badge")
                    .foregroundColor(.white)
                    .font(.title)
            }
            else {
                Image(systemName: "envelope.open")
                    .foregroundColor(.white)
                    .font(.title)
            }
        }
    )
}, backgroundColor: .orange, action: {unread.toggle()}, feedback: false)
```

## 配置 Slot ##

```swift
let slot1 = SwipeCellSlot(slots: [button2,button1])
let slot2 = SwipeCellSlot(slots: [button4], slotStyle: .destructive, buttonWidth: 60) 
let slot3 = SwipeCellSlot(slots: [button2,button1],slotStyle: .destructiveDelay)
```

## 装配 ##

```swift
cellView()
    .swipeCell(cellPosition: .left, leftSlot: slot4, rightSlot: nil)
```

更多的配置选项

```swift
cellView()
    .swipeCell(cellPosition: .both, 
                leftSlot: slot1, 
                rightSlot: slot1 ,
                swipeCellStyle: SwipeCellStyle(
                            alignment: .leading,
                            dismissWidth: 20,
                            appearWidth: 20,
                            destructiveWidth: 240, 
                            vibrationForButton: .error, 
                            vibrationForDestructive: .heavy, 
                            autoResetTime: 3)
                            )
```

## 滚动列表自动消除 ##

For List

```swift
List{
    ...
    }
    .dismissSwipeCell()
}
```

For single cell in ScrollView

```swift
ScrollView{
    VStack{
        Text("Mail Title")
            .dismissSwipeCellForScrollView() 
        Text("Mail Content")
        ....
    }
    .frame(maxWidth:.infinity,maxHeight: .infinity)
}
.swipeCell(cellPosition: .both, leftSlot: leftSlot, rightSlot: rightSlot,clip: false)
```

For LazyVStack in ScrollView

```swift
ScrollView{
    LazyVStack{
    ForEach(lists,id:\.self){ item in
       Text("Swipe in scrollView:\(item)")
        .frame(height:80)
        .swipeCell(cellPosition: .both, leftSlot:slot, rightSlot: slot)
        .dismissSwipeCellForScrollViewForLazyVStack()
    }
}
```

- dismissSwipeCell 在 editmode 下支持选择
- dismissSwipeCellForScrollView 用于 ScrollView, 通常用于只有一个 Cell 的场景，比如说 Mail 中的邮件内容显示。参看 Demo 中的演示
- dismissSwipeCellForScrollViewForLazyVStack 用于 ScrollView 中使用 LazyVStack 场景。个别时候会打断滑动菜单出现动画。个人觉得如无特别需要还是使用 List 代替 LazyVStack 比较好。

由于 SwiftUI 没有很好的方案能够获取滚动状态，所以采用了 [Introspect](https://github.com/siteline/SwiftUI-Introspect.git) 实现的上述功能。

destructiveDelay 形式的 button，需要在 action 中添加 dismissDestructiveDelayButton() 已保证在 alter 执行后，Cell 复位

## 当前问题 ##

- 动画细节仍然不足
- EditMode 模式下仍有不足

## 欢迎多提宝贵意见 ##

SwipeCell is available under the [MIT license](https://github.com/fatbobman/SwipeCell/blob/main/LICENSE.md).

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
