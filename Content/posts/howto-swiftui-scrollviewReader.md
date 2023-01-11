---
date: 2020-07-23 13:00
description: SwiftUI2.0 增加了滚动定位功能，已经可以较轻松的适应大多数场景的应用。实现手段完全不同于之前民间的各种解决方案，并不是通过设置具体的 offset 来进行定位，而是使用 id 来进行位置标记。
tags: SwiftUI,HowTo
title: HowTo —— SwiftUI2.0 使用 ScrollViewReader 定位滚动位置
---

SwiftUI2.0 增加了滚动定位功能，已经可以较轻松的适应大多数场景的应用。实现手段完全不同于之前民间的各种解决方案，并不是通过设置具体的 offset 来进行定位，而是使用 id 来进行位置标记。

```responser
id:1
```

## 基本用法——实现从右向左滚动 ##

```swift
struct ScrollReaderTest: View {
    var body: some View {
        ScrollView(.horizontal) {
            //类似 GeometryReader 的使用方式，设定滚动定位区域
            ScrollViewReader{ proxy in
                Rectangle()
                    .fill(LinearGradient(
                      gradient: Gradient(colors: [.blue,.red]),
                      startPoint: .leading,
                      endPoint: .trailing))
                    .frame(width: 1000, height: 300, alignment: .center)
                    .id("rec") //为 ScrollView 中需要定位的 View 设置 id
                    .onAppear {
                        //滚动到指定 id 的位置，按照 anchor 的设置来对齐
                        proxy.scrollTo("rec",anchor:.trailing)
                  }
            }
        }
    }
}
```

## 通过按钮来滚动到指定位置 ##

```swift
import SwiftUI

struct ScrollReadeTest: View {
    private var list = ScrollItem.items(300)
    @State private var position:Int = 0
    var body: some View {
      NavigationView{
        ScrollView{
            ScrollViewReader{ proxy in
                LazyVStack{
                    ForEach(list,id:\.id){ item in
                        Text(item.title).id(item.id)
                    }
                }
                .onChange(of: position) { positon in
                    switch position{
                    case 1: 
                        let id = list.first!.id
                        withAnimation(Animation.easeInOut){
                            proxy.scrollTo(id,anchor:.top)
                        }
                    case 2:
                        
                        let id = list[Int(list.count / 2)].id
                        withAnimation(Animation.easeInOut){
                            proxy.scrollTo(id,anchor:.center)
                        }
                    case 3:
                        let id = list.last!.id
                        withAnimation(Animation.easeInOut){
                            proxy.scrollTo(id,anchor:.bottom)
                        }
                    default:
                        break
                    }
                }
            }
        }
        .navigationTitle("滚动定位")
        
        .toolbar {
            ToolbarItem(placement:.automatic) {
                HStack{
                    Button("top"){
                        position = 1
                    }
                    Button("mid"){
                        position = 2
                    }
                    Button("end"){
                        position = 3
                    }
                }
            }
         }
      }
   }
}

struct ScrollItem:Identifiable{
    var id = UUID()
    var title:String
    
    static func items(_ count:Int) -> [ScrollItem]{
        var result:[ScrollItem] = []
        for i in 0..<count{
            result.append(ScrollItem(title:String("index:\(i) title:\(Int.random(in: 1000...5000))")))
        }
        return result
    }
}

```

<video src="https://cdn.fatbobman.com/howto-swiftui-scrollviewReader-video.mp4" controls="controls">你的浏览器不支持本视频</video>

## 遗憾 ##

没有简单的手段记录当前的滚动位置。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
