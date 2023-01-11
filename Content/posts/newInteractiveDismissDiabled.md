---
date: 2021-09-15 14:30
description: 本文中我们将探讨如何实现一个 SwiftUI 3.0 中新增功能——interactiveDismissDisabled 的增强版；如何创建更 SwiftUI 化的功能扩展。
tags: SwiftUI
title:  如何在 SwiftUI 中实现 interactiveDismissDisabled
image: images/dismissSheet.gif
---

本文中我们将探讨如何实现一个 SwiftUI 3.0 中新增功能——interactiveDismissDisabled 的增强版；如何创建更 SwiftUI 化的功能扩展。

```responser
id:1
```

## 需求 ##

由于 [健康笔记](https://www.fatbobman.com/healthnotes/) 中数据录入都是在 Sheet 中进行的，为了防止用户在录入过程中由于误操作（使用手势取消 Sheet）丢失数据，因此，从最初的版本开始，我就一直使用各种手段加强对 Sheet 的控制。

去年 9 月，我在文章 [【在 SwiftUI 中制作可以控制取消手势的 Sheet】](https://www.fatbobman.com/posts/swiftui-dismiss-sheet/) 中介绍了 [健康笔记 2.0](https://www.fatbobman.com/healthnotes/) 版本的 Sheet 控制实现方法。目标为：

* 通过代码控制是否允许手势取消 Sheet
* 在用户使用手势取消 Sheet 时可以获得通知，进而拥有更多的控制能力

最终实现的效果如下：

![dismissSheet](https://cdn.fatbobman.com/dismissSheet.gif)

当用户有未保存的数据时，通过手势取消 Sheet 将被阻止，用户需明确选择保存或丢弃数据。

最终的效果已经完全满足了我的要求，不过唯一遗憾的是，使用起来不是那么的直观（具体使用方式请查看 [原文](https://www.fatbobman.com/posts/swiftui-dismiss-sheet/)）。

在今年推出的 SwiftUI 3.0 版本中，苹果添加了一个新的 View 扩展：`interactiveDismissDisabled`，该扩展实现了上面的第一个要求——通过代码控制是否允许手势取消 Sheet。

```swift
struct ExampleView: View {
       @State private var show: Bool = false
       
       var body: some View {
           
           Button("Open Sheet") {
               self.show = true
           }
           .sheet(isPresented: $show) {
               print("finished!")
           } content: {
               MySheet()
           }
       }
   }
   
   struct MySheet: View {
       @Environment (\.presentationMode) var presentationMode
       @State var disable = false
       var body: some View {
           Button("Close") {
               self.presentationMode.wrappedValue.dismiss()
           }
           .interactiveDismissDisabled(disable)
       }
   }

```

只需在被控制的视图中添加`interactiveDismissDisabled`，不影响其他地方的代码逻辑。这种实现是我所喜欢的，也给了我很大的启发。

在 [WWDC 2021 观后感](https://www.fatbobman.com/posts/wwdc2021/) 一文中，我们已经探讨过 SwiftUI3.0 将会影响非常多的第三方开发者编写 SwiftUI 扩展的思路和实现方式。

尽管`interactiveDismissDisabled`的实现很优雅，但仍未完成 [健康笔记](https://www.fatbobman.com/healthnotes/) 需要的第二个功能：在用户使用手势取消 Sheet 时可以获得通知，进而拥有更多的控制能力。因此，我决定使用类似的方式实现它。

```responser
id:1
```

## 原理 ##

### 委托 ###

从 iOS 13 开始，苹果调整了模态视图的委托协议（UIAdaptivePresentationControllerDelegate）。其中：

* presentationControllerShouldDismiss(**_** presentationController: UIPresentationController) -> Bool

  决定了是否允许通过手势来 dismiss sheet

* presentationControllerWillDismiss(**_** presentationController: UIPresentationController)

  用户尝试使用手势取消时的执行此方法

当用户使用手势取消 Sheet 时，系统将首先执行 presentationControllerWillDismiss，然后再从 presentationControllerShouldDismiss 中获取是否允许取消。

默认情况下，展示（present）Sheet 的视图控制器（UIViewController）是没有设置委托的。因此，只要将定义好的委托实例在视图中注入给特定的视图控制器即可实现以上需求。

### 注入 ###

创建一个空的 UIView（通过 UIViewRepresentable），在其中查找到持有它的 UIViewController `A`。那么`A`的 presentationController 就是我们需要注入 delegate 的视图控制器。

在之前的 [版本中](https://www.fatbobman.com/posts/swiftui-dismiss-sheet/)，用户使用手势取消时的通知和其他的逻辑是分离的，在使用中不仅繁琐，而且影响代码的观感。本次将一并解决这个问题。

## 实现 ##

### Delegate ###

```swift
final class SheetDelegate: NSObject, UIAdaptivePresentationControllerDelegate {
    var isDisable: Bool
    @Binding var attempToDismiss: UUID

    init(_ isDisable: Bool, attempToDismiss: Binding<UUID> = .constant(UUID())) {
        self.isDisable = isDisable
        _attempToDismiss = attempToDismiss
    }

    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        !isDisable
    }

    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        attempToDismiss = UUID()
    }
}
```

### UIViewRepresentable ###

```swift
struct SetSheetDelegate: UIViewRepresentable {
    let delegate:SheetDelegate

    init(isDisable:Bool,attempToDismiss:Binding<UUID>){
        self.delegate = SheetDelegate(isDisable, attempToDismiss: attempToDismiss)
    }

    func makeUIView(context: Context) -> some UIView {
        let view = UIView()
        return view
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
        DispatchQueue.main.async {
            uiView.parentViewController?.presentationController?.delegate = delegate
        }
    }
}
```

makeUIView 中只需要创建一个空视图（UIView），由于在执行 makeUIView 时，无法保证 Sheet 中的视图已经被正常展示，因此最佳的注入时机为 updateUIView。

为了方便查找持有该 UIView 的 UIController，我们需要对 UIView 进行扩展：

```swift
extension UIView {
    var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = self.next
        while parentResponder != nil {
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
            parentResponder = parentResponder?.next
        }
        return nil
    }
}
```

如此，便可以通过下面的代码为展示 Sheet 的视图控制器注入 delegate 了

```swift
uiView.parentViewController?.presentationController?.delegate = delegate
```

### View Extension ###

使用了与系统相同的方法名

```swift
public extension View{
    func interactiveDismissDisabled(_ isDisable:Bool,attempToDismiss:Binding<UUID>) -> some View{
        background(SetSheetDelegate(isDisable: isDisable, attempToDismiss: attempToDismiss))
    }
}
```

## 结果 ##

使用的方式同原生的功能几乎一样：

```swift
struct ContentView: View {
    @State var sheet = false
    var body: some View {
        VStack {
            Button("show sheet") {
                sheet.toggle()
            }
        }
        .sheet(isPresented: $sheet) {
            SheetView()
        }
    }
}

struct SheetView: View {
    @State var disable = false
    @State var attempToDismiss = UUID()
    var body: some View {
        VStack {
            Button("disable: \(disable ? "true" : "false")") {
                disable.toggle()
            }
            .interactiveDismissDisabled(disable, attempToDismiss: $attempToDismiss)
        }
        .onChange(of: attempToDismiss) { _ in
            print("try to dismiss sheet")
        }
    }
}
```

![dismissSheet2](https://cdn.fatbobman.com/dismissSheet2.gif)

> 本文的代码可以在 [Gist](https://gist.github.com/fatbobman/d248d80d8d1a23b5f8d84ed7544d2ae3) 上查看

## 总结 ##

SwiftUI 已经诞生两年多了，开发者也已经逐渐掌握为 SwiftUI 添加新功能的各种技巧。通过学习和理解原生的 API，可以让我们的实现更加符合 SwiftUI 的风格，整体的代码更加的统一。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。

