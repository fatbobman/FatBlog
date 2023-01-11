---
date: 2020-07-09 13:05
description: SwiftUI2.0 中新增了 Label 控件，方便我们添加由图片和文字组成的标签。
tags: SwiftUI,HowTo
title: HowTo —— SwiftUI2.0 如何使用 Label
---

> SwiftUI2.0 中新增了 Label 控件，方便我们添加由图片和文字组成的标签

## 基本用法 ##

```swift
Label("Hello World",systemImage:"person.badge.plus")
```

![image-20200709174029886](https://cdn.fatbobman.com/howto-swiftui-label1.png)

```responser
id:1
```

## 支持自定义标签风格 ##

```swift
import SwiftUI

struct LabelTest: View {
    var body: some View {
        List(LabelItem.labels(),id:\.id){ label in
            Label(label.title,systemImage:label.image)
                .foregroundColor(.blue)
                .labelStyle(MyLabelStyle(color:label.color))
        }
    }
}

struct MyLabelStyle:LabelStyle{
    let color:Color
    func makeBody(configuration: Self.Configuration) -> some View{
       HStack{
            configuration.icon //View, 不能精细控制
                .font(.title)
                .foregroundColor(color) //颜色是叠加上去的，并不能准确显示
            configuration.title  //View, 不能精细控制
                .foregroundColor(.blue)
            Spacer()
        }.padding(.all, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.yellow)
        )
    }
}

struct LabelItem:Identifiable{
    let id = UUID()
    let title:String
    let image:String
    let color:Color
    static func labels() -> [LabelItem] {
        return [
       LabelItem(title: "Label1", image: "pencil.tip.crop.circle.badge.plus", color: .red),
       LabelItem(title: "df", image: "person.crop.circle.fill.badge.plus", color: .blue),
        ]
    }
}

```

![image-20200709175339008](https://cdn.fatbobman.com/howto-swiftui-label2.png)

## 使用自己的 Label 控件，更多控制力 ##

Label 能够提高开发效率，不过并不能精细控制，下面代码使用自定义 MyLabel，可以支持 SF2.0 提供的彩色符号。

```swift
import SwiftUI

struct LabelTest: View {
    @State var multiColor = true
    var body: some View {
        VStack{
        Toggle("彩色符号", isOn: $multiColor).padding(.horizontal, 20)
        List(LabelItem.labels(),id:\.id){ label in         
              MyLabel(title:label.title,
                      systemImage:label.image,
                      color:label.color,
                      multiColor:multiColor)
        }
    }
}

struct LabelItem:Identifiable{
    let id = UUID()
    let title:String
    let image:String
    let color:Color
    static func labels() -> [LabelItem] {
        return [
       LabelItem(title: "Label1", image: "pencil.tip.crop.circle.badge.plus", color: .red),
       LabelItem(title: "df", image: "person.crop.circle.fill.badge.plus", color: .blue),
        ]
    }
}

struct MyLabel:View{
    let title:String
    let systemImage:String
    let color:Color
    let multiColor:Bool
    
    var body: some View{
        HStack{
            Image(systemName: systemImage)
                .renderingMode(multiColor ? .original : .template)
                .foregroundColor(multiColor ? .clear : color)
            Text(title)
                .bold()
                .foregroundColor(.blue)
            Spacer()
        }
        .padding(.all, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.yellow)
        )
    }
}

```

![image-20200709180353538](https://cdn.fatbobman.com/howto-swiftui-label3.png)

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
