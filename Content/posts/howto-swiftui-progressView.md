---
date: 2020-07-12 13:00
description: SwiftUI2.0 新增了一些便捷的内置控件，比如说 Label、ProgressView 等。其基本形态都很普通，不过都支持自定义 style。官方的意图也比较明显，通过内置控件，规范代码、提高原型编写速度，如需要更精细控制可通过扩展 style 来完成。
tags: SwiftUI,HowTo
title: HowTo —— SwiftUI2.0 使用 ProgressView 显示进度条
---

SwiftUI2.0 新增了一些便捷的内置控件，比如说 Label、ProgressView 等。其基本形态都很普通，不过都支持自定义 style。官方的意图也比较明显，通过内置控件，规范代码、提高原型编写速度，如需要更精细控制可通过扩展 style 来完成。

```responser
id:1
```

## 经典小菊花 ##

```swift
ProgressView()
```

![progress1](https://cdn.fatbobman.com/howto-swiftui-progressView-progress1.png)

## 线性进度条 ##

```swift
ProgressView("完成量", value: 50, total: 100)
```

![截屏 2020-07-11 下午 4.09.34](https://cdn.fatbobman.com/howto-swiftui-progressView-progress2.png)

## 代码示例 ##

```swift
import SwiftUI

struct ProgressTest: View {
    @State var timer = Timer.TimerPublisher(interval: 0.03, runLoop: .main, mode: .common).autoconnect()
    @State var value:Double = 0.0
    var body: some View {
        List{
            //无法定义颜色
            ProgressView()
            
            //无法隐藏 Label
            ProgressView("完成量", value: value, total: 100)
                .accentColor(.red)
            //自定义 Style
            ProgressView("工程进度",value: value, total: 100)
                .progressViewStyle(MyProgressViewStyle())
        }
        .onAppear {
            timer = Timer.TimerPublisher(interval: 0.03, runLoop: .main, mode: .common).autoconnect()
        }
        .onReceive(timer) { _ in
            if value < 100 {
                value += 2
            }
        }
    }
}

//定义方法都大同小异。
struct MyProgressViewStyle:ProgressViewStyle{
    let foregroundColor:Color
    let backgroundColor:Color
    init(foregroundColor:Color = .blue,backgroundColor:Color = .orange){
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
    }
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader{ proxy in
            ZStack(alignment:.topLeading){
            backgroundColor
            Rectangle()
                .fill(foregroundColor)
                .frame(width:proxy.size.width * CGFloat(configuration.fractionCompleted ?? 0.0))
            }.clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                    configuration.label
                        .foregroundColor(.white)
            )
        }
    }
}

```

<video src="https://cdn.fatbobman.com/howto-swiftui-progressView-video.mov" controls = "controls">你的浏览器不支持本视频</video>

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
