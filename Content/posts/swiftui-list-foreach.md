---
date: 2020-08-24 12:00
description: 在 SwiftUI 中使用 List 可以非常方便快速的制作各种列表。List 其实就是对 UITableView 进行的封装。
tags: SwiftUI
title: 聊一下 SwiftUI 中的 List 和 ForEach
---

在 SwiftUI 中使用 List 可以非常方便快速的制作各种列表。List 其实就是对 UITableView 进行的封装（更多 List 的具体用法请参阅 [List 基本用法](https://zhuanlan.zhihu.com/p/110749923)).

在 List 中添加动态内容，我们可以使用两种方式

```responser
id:1
```

### 直接使用 List 自己提供的动态内容构造方法 ###

```swift
  List(0..<100){ i in
    Text("id:\(id)")
  }
```

### 在 List 中使用 ForEach ###

```swift
  List{
    ForEach(0..<100){ i in
      Text("id:\(id)")
    }
  }
```

在碰到我最近出现的问题之前，我一直以为上述两种用法除了极个别的区别外，基本没有什么不同。

当时知道的区别：

### 使用 ForEach 可以在同一 List 中，添加多个动态源，且可添加静态内容 ###

```swift
  List{
    ForEach(items,id:\.self){ item in
      Text(item)
    }
    Text("其他内容")
    ForEach(0..<10){ i in
      Text("id:\(i)")
    }
  }
```

### 使用 ForEach 对于动态内容可以控制版式 ###

```swift
  List{
    ForEach(0..<10){ i in
      Rectangle()
        .listRowInsets(EdgeInsets()) //可以控制边界 insets
    }
  }
  
  List(0..<10){ i in
     Rectangle()
        .listRowInsets(EdgeInsets()) 
        // 不可以控制边界 insets.   .listRowInsets(EdgeInsets()) 在 List 中只对静态内容有效
  }
```

基于以上的区别，我在大多数的时候均采用 ForEach 在 List 中装填列表内容，并且都取得了预想的效果。

但是在最近我在开发一个类似于 iOS 邮件 app 的列表时发生了让我无语的状态——列表卡顿到完全无法忍耐。

通过下面的视频可以看到让我痛苦的 app 表现

<video src="https://cdn.fatbobman.com/swiftui-list-foreach-10ForEach.mp4" controls = "controls"></video>

只有十条记录时的状态。非常丝滑

```swift
 List{
    ForEach(0..<10000){ i in
        Cell(id: i)
          .listRowInsets(EdgeInsets())
          .swipeCell(cellPosition: .both, leftSlot: slot1, rightSlot: slot1)
        }
    }
```

<video src="https://cdn.fatbobman.com/swiftui-list-foreach-10000MyList.mp4" controls = "controls"></video>
10000 条记录的样子

在 10 条记录时一切都很完美，但当记录设置为 10000 条时，完全卡成了 ppt 的状态。尤其是 View 初始化便占有了大量的时间。

起初我认为可能是我写的滑动菜单的问题，但在自己检查代码后排出了这个选项。为了更好的了解在 List 中 Cell 的生命周期状态，写了下面的测试代码。

```swift
    struct Cell:View{
        let id:Int
        @StateObject var t = Test()
        init(id:Int){
            self.id = id
            print("init:\(id)")
        }
        var body: some View{
            Rectangle()
                .fill(Color.blue)
                .overlay(
                    Text("id:\(id)")
                )
                .onAppear{
                    t.id = id
                }
        }
        
        class Test:ObservableObject{
            var id:Int = 0{
                didSet{
                    print("get value \(id)")
                }
            }
            init(){
                print("init object")
            }
            deinit {
                print("deinit:\(id)")
            }
        }
    }
    
    class Store:ObservableObject{
        @Published var currentID:Int = 0
    }
```

执行后，发现了一个奇怪的现象：**在 List 中，如果用 ForEach 处理数据源，所有的数据源的 View 竟然都要在 List 创建时进行初始化，这完全违背了 tableView 的本来意图**.

将上面的代码的数据源切换到 List 的方式进行测试

```swift
 List(0..<10000){ i in
        Cell(id: i)
          .listRowInsets(EdgeInsets())
          .swipeCell(cellPosition: .both, leftSlot: slot1, rightSlot: slot1)
    }
```

<video src="https://cdn.fatbobman.com/swiftui-list-foreach-10000withoutForEach.mp4" controls = "controls"></video>

熟悉的丝滑又回来了。

**ForEach 要预先处理所有数据，提前准备 View. 并且初始化后，并不自动释放这些 View（即使不可见）! **具体可以使用上面的测试代码通过 Debug 来分析。

不流畅的原因已经找到了，不过由于 List 处理的数据源并不能设置 listRowInsets, 尤其在 iOS14 下，苹果非常奇怪的屏蔽了不少通过 UITableView 来设置 List 的属性的途径，所以为了既能保证性能，又能保证显示需求，只好通过自己包装 UITableView 来同时满足上述两个条件。

好在我一直使用 [SwiftUIX](https://github.com/SwiftUIX/SwiftUIX) 这个第三方库，节省了自己写封装代码的时间。将代码做了进一步调整，当前的问题得以解决。

```swift
 CocoaList(item){ i in
           Cell(id: i)
           .frame(height:100)
           .listRowInsets(EdgeInsets())
           .swipeCell(cellPosition: .both, leftSlot: slot1, rightSlot: slot1)
       }.edgesIgnoringSafeArea(.all)
```

<video src="https://cdn.fatbobman.com/swiftui-list-foreach-10000MyList.mp4" controls = "controls"></video>

通过这次碰到的问题，我知道了可以在什么情况下使用 ForEach. 通过这篇文章记录下来，希望其他人少走这样的弯路。

**后记：**

我已经向苹果反馈了这个问题，希望他们能够进行调整吧（最近苹果对于开发者的 feedback 回应还是挺及时的，Xcode12 发布后，我提交了 5 个 feedback, 已经有 4 个获得了反馈，3 个在最新版得到了解决）.

**遗憾：**

目前的解决方案使我失去了使用 ScrollViewReader 的机会。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
