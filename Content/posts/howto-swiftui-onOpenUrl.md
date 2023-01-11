---
date: 2020-07-11 13:00
description: SwiftUI2.0 由于可以采用新的代码架构（Life Cycle SwiftUI App）来组织 app, 因此提供了 onOpenURL 来处理 Univeresal Links。不同于在 AppDelegate 或 SceneDelegate 中的解决方案，onOpenURL 作为一个 view modifier，你可以在任意 View 上注册你的 app 的 URL 处理机制。
tags: SwiftUI,HowTo
title: HowTo —— 使用 onOpenURL 处理 Universal Links
---

SwiftUI2.0 由于可以采用新的代码架构（Life Cycle SwiftUI App）来组织 app, 因此提供了 onOpenURL 来处理 Univeresal Links。不同于在 AppDelegate 或 SceneDelegate 中的解决方案，onOpenURL 作为一个 view modifier，你可以在任意 View 上注册你的 app 的 URL 处理机制。关于如何为自己的 app 创建 URL Scheme，请参阅 [苹果的官方文档](https://developer.apple.com/documentation/uikit/inter-process_communication/allowing_apps_and_websites_to_link_to_your_content/defining_a_custom_url_scheme_for_your_app)。

```responser
id:1
```

## 基本用法 ##

```swift
VStack{
   Text("Hello World")
}
.onOpenURL{ url in
    //做点啥
}
```

## 示例代码 ##

首先在项目中设置 URL

![URL](https://cdn.fatbobman.com/howto-swiftui-onOpenURL-URL.png)

```swift
import SwiftUI

struct ContentView: View {
    @State var tabSelection:TabSelection = .news
    @State var show = false
    var body: some View {
        TabView(selection:$tabSelection){
            Text("News")
                .tabItem {Image(systemName: "newspaper")}
                .tag(TabSelection.news)
            Text("Music")
                .tabItem {Image(systemName: "music.quarternote.3")}
                .tag(TabSelection.music)
            Text("Settings")
                .tabItem {Image(systemName: "dial.max")}
                .tag(TabSelection.settings)
        }
        .sheet(isPresented: $show) {
            Text("URL 调用参数错误")
        }
        .onOpenURL { url in
            let selection = url.host
            switch selection{
            case "news":
                tabSelection = .news
            case "music":
                tabSelection = .music
            case "settings":
                tabSelection = .settings
            default:
                show = true
            }
        }
    }
}

enum TabSelection:Hashable{
    case news,music,settings
}
```

> macOS 目前暂不支持，应该会在正式版本提供。

<video src="https://cdn.fatbobman.com/howto-swiftui-onOpenURL-video.mp4" controls = "controls">你的浏览器不支持本视频</video>

## 特别注意 ##

* onOpenURL 只有在项目采用 Swift App 的方式管理 Life Cycle 才会响应

* 在代码中可以添加多个 onOpenURL，注册在不同的 View 上，当采用 URL 访问时，每个闭包都会响应。这样可以针对不同的 View 做出各自需要的调整。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
