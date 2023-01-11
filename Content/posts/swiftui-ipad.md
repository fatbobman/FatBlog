---
date: 2020-10-29 12:00
description: SwiftUI 创建初衷之一便是可以高效、可靠的适配多个苹果的硬件平台。在健康笔记 2.0 开发初始，适配 iPad 便是我本次的设计目标之一。本文并非教程，只是我在进行本次开发中，对于适配 iPad 的一些教训和心得。
tags: SwiftUI
title: 在 SwiftUI 下对 iPad 进行适配
---

SwiftUI 创建初衷之一便是可以高效、可靠的适配多个苹果的硬件平台。在健康笔记 2.0 开发初始，适配 iPad 便是我本次的设计目标之一。本文并非教程，只是我在进行本次开发中，对于适配 iPad 的一些教训和心得。

```responser
id:1
```

## 我是谁 ##

app 中的代码必须能高效、清晰的了解当前设备的状况，时刻搞清楚我是谁，我在哪，在干啥等等。因此在项目开始之初我便做了不少的准备并创建了一系列的代码。

比如，当前的运行设备：

```swift
enum Device {
    //MARK: 当前设备类型 iphone ipad mac
    enum Devicetype{
        case iphone,ipad,mac
    }
    
    static var deviceType:Devicetype{
        #if os(macOS)
        return .mac
        #else
        if  UIDevice.current.userInterfaceIdiom == .pad {
            return .ipad
        }
        else {
            return .iphone
        }
        #endif
 }
```

如果想要具体了解当前运行设备的型号，Github 上有人提供了代码可以返回更精准的信息。

为了能够在 View 中方便的利用这些状态信息应对不同的情况，还需要继续做些准备。

```swift
extension View {
    @ViewBuilder func ifIs<T>(_ condition: Bool, transform: (Self) -> T) -> some View where T: View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    @ViewBuilder func ifElse<T:View,V:View>( _ condition:Bool,isTransform:(Self) -> T,elseTransform:(Self) -> V) -> some View {
        if condition {
            isTransform(self)
        } else {
            elseTransform(self)
        }
    }
}
```

这两段是我使用非常频繁的代码，在 SwiftUI 下，利用类似的代码可以非常容易的利用同一段代码应对各种不同的状况。

例如：

```swift
VStack{
     Text("hello world")
}
.ifIs(Deivce.deviceType == .iphone){
  $0.frame(width:150)
}
.ifIs(Device.deviceType == .ipad){
  $0.frame(width:300)
}
.ifIs(Device.deviceType == .mac){
  $0.frmae(minWidth:200,maxWidth:600)
}
```

只有解决了我是谁的问题，后面的工作才能更好的展开

## 躺着还是站着 ##

因为健康笔记以列表被主要表现形式的 app，最初所以我希望在 iphone 上始终保持 Portrait，在 ipad 上保持 Landscape 的形式。不过最终还是决定让其在 ipad 上同时支持 Portrait 和 Landscape。

![ipadiphone](https://cdn.fatbobman.com/swiftui-ipad-ipadiPhone.png)

为了更灵活的处理，我没有选择在 info.plist 中对其进行设定，而是通过在 delegate 中，针对不同的情况作出响应。

![xcode](https://cdn.fatbobman.com/swiftui-ipad-xcode.png)

因为无需支持多窗口，所以关闭了 multiple windows。另外需要激活 Requires full screen 才能让 delegate 作出响应

```swift
class AppDelegate:NSObject,UIApplicationDelegate{
  func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return Device.deviceType == .ipad
            ? UIInterfaceOrientationMask.all
            : UIInterfaceOrientationMask.portrait
    }
}
```

在 SwiftUI 下如何设置 Delegate 请查看 [SwiftUI2.0 —— App、Scene 及新的代码结构](/posts/swiftui2-new-feature-1/)

如此便可以方便的控制自己想要的 app 呈现形态了。

## 难以控制的 NavigationView ##

SwiftUI 的 NavigationView 本身为了适配做了不少的工作，但效果并不好。

目前它支持两种 style： StackNavigationView、DoubleColumnNavigationViewStyle，三种表现形式：单列、双列、以及三列（sidebar）。虽然看似覆盖了多数的应用，但由于没有提供更多的控制选项，因此用起来并不顺手。

比如，DoubleColumnNavigationViewStyle，在 ipad 上的竖屏和横屏时的呈现是不同的。左上角的隐藏按钮不可更改，不可取消。在包含 sidebar 的三列模式下，逻辑又有不同，不过按钮同样不提供任何替换、取消的能力。

NavigationLink 只能在当前列中响应，另外并不提供控制列宽的能力。

如果想调整双列 NavigationView 的列宽，可以使用 Introspect，参见 [介绍几个我在开发健康笔记 2 用到的 Swift 或 SwiftUI 第三方库](/posts/healthnote2-3rd-package/)

```swift
NavigationView{
  Text("hello")
}
.introspectNavigationController{ navigation in
    navigation.splitViewController?.maximumPrimaryColumnWidth = 360
    navigation.splitViewController?.preferredPrimaryColumnWidth = 500.0
}
```

为了能够让 ipad 在竖屏或横屏状态下都固定呈现双列的模式，并且左侧列不可折叠同时也不能出现我想要的折叠按钮，我使用了一个不得已的手段。伪造了一个双列显示的 NavigationView。

针对不同的设备进入不同的 rootView

```swift
struct HealthNotesApp:APP{
  var body: some Scene{
     rootView()
  }
  
  func rootView()-> some View{
        switch Device.deviceType {
        case .ipad:
            return AnyView(ContentView_iPad())
        default:
            return AnyView(ContentView_iPhone())
        }
    }
}
```

在 ContentView_iPad 中，使用类似代码伪造一个双列形式

```swift
HStack(spacing:0){
      ItemRootView(item: $item)
           .frame(width:height)
       Divider()
       ItemDataRootView()
            .navigationContent()
        }
.edgesIgnoringSafeArea(.all)
```

如此一来便拥有了上面图片中 iPad 的显示效果。状态基本上同 DoubleColumnNavigationViewStyle 的形式是完全一致的。分别都可以设置 Toolbar，并且分割线也可以贯穿屏幕。

```swift
extension View{
    func navigationContent() -> some View{
        NavigationView{
            self
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
```

由于在 Ipad 下右侧列的视图同时被用在 iphone 下，在 iPhone 下它是由 NavigationLink 激活的，所以仍在 NavigationView 中，但在 iPad 下，需要明确的将在放置在 NavigationView 中。通过 .navigationContent，结合上面的 isIf，便可以灵活的控制形态了。

另外需要针对 iPhone 和 ipad 的二级 View 激活进行分别处理，比如

```swift
if Device.deviceType  == .iphone {
                    NavigationLink("", destination: ItemDataRootView(), isActive: $gotoDataList).frame(width:0,height:0)
            }

//在 link 的 button 中
Button("Item1"){
   store.item = item
   if Devie.deviceType == .iphone {
       gotoDataList.toggle()
   }
}

//在 ItemDataRootView 中直接响应 store.item 即可
```

## Bug 还是特别设计？ ##

某些 SwiftUI 的默认控件在 iPad 和 iPhone 下的运行效果和预期有较大差别，

比如 ActionSheet:

当前 AlertSheet 在运行 iOS14 的 ipad 上的显示位置是几乎不可控的。箭头的位置，内容的显示，和预期都有巨大的差别。我不知道以后都会是这样还是目前的 Bug。

个人不推荐当前在 iPad 上使用 ActionSheet。最终只能在 iPad 下使用 Alert 替代了 ActionSheet。如果一定要使用 ActionSheet，popover 或许是更好的选择。

ContextMenu 目前在 iPad 上有响应上的问题，同样的指令在 iPhone 上没有问题，在 iPad 上会出现无法获取值的状况。同样不清楚是 Bug 还是其他原因。

比如

```swift
Text("click")
.contextMenu{
  Button("del"){
     delItem = item
     ShowActionSheet.toggle()
  }
}
.ActionSheet(isPresented:showActionSheet){
    delSheet(item:delItem)
}
```

这段代码在 iphone 上执行没有任何问题，不过在 ipad 上，delsheet 很有可能会无法获取 item。为了避免这个情况，目前只能做些特殊处理

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5){
                  showActionSheet.wrappedValue = true
}
```

类似上述的问题还有一些，只有当代码在 ipad 上跑起来多做测试才会发现其中的问题。

## 布局优化 ##

由于健康笔记 2.0 在 iPad 上显示的左右两列，所以本来在 iphone 下运行没有问题 View, 在 iPad 下就会出现左右不对齐，不对称等问题。所以只要多调试，采用 isIf 多做处理，问题基本上都会比较容易获得解决。

仅举一例：

```swift
List{
   ...
}
.listStyle(InsetGroupedListStyle())
```

当它在 iphone 上作为独占屏幕的 View 时，显示很完美，但当它显示在 IPad 的右侧列时，Group 上方的留空和左侧列的就不对齐，做点处理就 ok 了。

## 结尾 ##

总之使用 SwiftUI 适配 iPhone 和 iPad 总体来说还是比较容易的。能否充分利用好各自设备的特点主要还是要在交互逻辑和 UI 设计上多下功夫，代码上的难度不大。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
