---
date: 2020-07-10 13:00
description: SwiftUI2.0 提供了原生的打开 URL scheme 的功能，我们可以十分方便的在代码中调用其他的 app。
tags: SwiftUI,HowTo
title: HowTo —— SwiftUI2.0 使用 Link 或 openURL 打开 URL scheme
---

SwiftUI2.0 提供了原生的打开 URL scheme 的功能，我们可以十分方便的在代码中调用其他的 app。

```responser
id:1
```

## Link ##

类似于 NavigationLink , 直接打开 URL scheme 对应的 app

```swift
Link("openURL",destination:safariUrl)
```

## openURL ##

本次在 SwiftUI2.0 中，苹果提供了若干个通过 Environment 注入的调用系统操作的方法。比如 exportFiles,importFiles,openURL 等。

```swift
@Environment(\.openURL) var openURL
openURL.callAsFunction(url)
```

## 代码范例 ##

```swift
struct URLTest: View {
    @Environment(\.openURL) var openURL
    let safariUrl = URL(string:"http://www.apple.com")!
    let mailUrl = URL(string:"mailto:foo@example.com?cc=bar@example.com&subject=Hello%20Wrold&body=Testing!")!
    let phoneURl = URL(string:"tel:12345678")!
    
    var body: some View {
        List{
            Link("使用 safari 打开网页",destination:safariUrl)
            Button("发送邮件"){
                openURL.callAsFunction(mailUrl){ result in
                    print(result)
                }
            }
            Link(destination: phoneURl){
                Label("拨打电话",systemImage:"phone.circle")
            }
        }
    }
}
```

> 模拟器仅支持极少数的 URL，最好使用真机测试
> [苹果官方提供的一些 URL scheme](https://developer.apple.com/library/archive/featuredarticles/iPhoneURLScheme_Reference/PhoneLinks/PhoneLinks.html#//apple_ref/doc/uid/TP40007899-CH6-SW1)

<video src="https://cdn.fatbobman.com/howto-swiftui-openurl-video.mp4" controls = "controls">你的浏览器不支持本视频</video>

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
