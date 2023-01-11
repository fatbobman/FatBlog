---
date: 2020-09-04 12:00
description: 我的 app 健康笔记主要是对数据的收集、管理，所以对于表单的实时检查、响应的要求比较高。因此制作一个对用于输入响应及时、反馈准确的 Form 十分重要。本文尝试提出一个 SwiftUI 下的 Form 开发思路。
tags: SwiftUI
title: 如何在 SwiftUI 中创建一个实时响应的 Form
---

我的 app 健康笔记主要是对数据的收集、管理，所以对于表单的实时检查、响应的要求比较高。因此制作一个对用于输入响应及时、反馈准确的 Form 十分重要。本文尝试提出一个 SwiftUI 下的 Form 开发思路。

```responser
id:1
```

## 健康笔记 1.0 的时候 ##

在开发健康笔记 1.0 的使用，当时由于 iOS13 尚不支持 onChange，当时主要使用类似的检查方式：

## 对于简单情况 ##

```swift
@State var name = ""

TextField("name",text:$name)
     .foregroundColor(name.count.isEmpty ? .red : .black)

```

## 稍复杂的情况 ##

```swift
@State var name = ""
@State var age = ""

TextField("name",text:$name)
    .foregroundColor(!checkName() ? .red : .black)
TextField("age",text:$name)
     .keyboardType(.decimalPad)
     .foregroundColor(!checkAge() ? .red : .black)

Button("Save"){
   //保存
}
.disable(!(checkName()&&checkeAge))

func chekcName() -> Bool {
   return name.count > 0 && name.count <= 10 
}

func checkAge() -> Bool {
   guard let age = Double(age) else {return false}
   return age > 10 && age < 20
}
```

其实之前对于很复杂的表单，我也是采用了 Combine 的方式来做验证的。

不过 Publisher 的和 View 的刷新周期之间有一个响应的差距，也就是说，第一个输入的判断需要到第二个输入时才会返回结果。如此一来，只能将判断逻辑都写在 View 中。不过如果需要利用网络验证的部分，仍然是使用 Publisher 来处理的。它的响应由于使用 OnReceive 所以不会出现上面的判断时间差。

## 健康笔记 2.0 的处理方式 ##

在我目前开发的健康笔记 2.0 中，由于 iOS 14 支持了 onChange, 让开发者在 View 有了非常方便的处理逻辑判断的时机。

以下是目前开发中的画面：

![demo](https://cdn.fatbobman.com/swiftui-form-formDemo.gif)

## 用 MVVM 的方式来编写 Form ##

在使用 SwiftUI 进行开发中，我们不仅需要使用 MVVM 的思想来考虑 app 的架构，对于每一个 View 都可以把它当做一个 mini 的 app 来对待。

在下面的例子中，我们需要完成如下的功能：

1. 显示档案、编辑档案、新建档案都使用同一个代码
2. 对于用户的每一次输入都给出及时和准确的反馈
3. 只有用户的数据完全满足需求时（各个输入项都满足检查条件同时在编辑状态下，当前修改数据要与原始数据不同），才允许用户保存。
4. 如果用户已经修改或创建了数据，用户取消时需要二次确认
5. 在用户显示档案时，可以一键切换到编辑模式

*如果你所需要创建的 FormView 功能简单，请千万不要使用下列的方法。下列代码仅在创建较复杂的表单时才会发挥优势。*

完成后的视频如下：

![demo](https://cdn.fatbobman.com/swiftui-form-studentDemo.gif)

下载 （当前代码已和 [在 SwiftUI 中制作可以控制取消手势的 Sheet](https://zhuanlan.zhihu.com/p/245663226) 合并）

[源代码](https://github.com/fatbobman/DismissConfirmSheet)

为输入准备数据源

不同于创建多个@State 数据源来处理数据，我现在将所有需要录入的数据统一放到了一个数据源中

```swift
struct MyState:Equatable{
    var name:String
    var sex:Int
    var birthday:Date
}
```

让 View 响应不同的动作

```swift
enum StudentAction{
    case show,edit,new
}
```

**有了上述的准备，我们便可以创建表单的构造方法了：**

```swift
struct StudentManager: View {
    @EnvironmentObject var store:Store
    @State var action:StudentAction
    let student:Student?
    
    private let defaultState:MyState  //用于保存初始数据，可以用来比较，或者在我的 app 中，可以恢复用户之前的值
    @State private var myState:MyState //数据源
    
    @Environment(\.presentationMode) var presentationMode

init(action:StudentAction,student:Student?){
        _action = State(wrappedValue: action)
        self.student = student
        
        switch action{
        case .new:
            self.defaultState = MyState(name: "",sex:0, birthday: Date())
            _myState = State(wrappedValue: MyState(name: "", sex:0, birthday: Date()))
        case .edit,.show:
            self.defaultState = MyState(name: student?.name ?? "", sex:Int(student?.sex ?? 0) , birthday: student?.birthday ?? Date())
            _myState = State(wrappedValue: MyState(name: student?.name ?? "", sex:Int(student?.sex ?? 0), birthday: student?.birthday ?? Date()))
        }
    }
  
}
```

准备表单显示内容

```swift
func nameView() -> some View{
        HStack{
            Text("姓名：")
            if action == .show {
                Spacer()
                Text(defaultState.name)
            }
            else {
                TextField("学生姓名",text:$myState.name)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
```

合成显示内容

```swift
Form{
             nameView()
             sexView()
             birthdayView()
             errorView()
      }
```

对每个输入项目进行验证

```swift
func checkName() -> Bool {
        if myState.name.isEmpty {
            errors.append("必须填写姓名")
            return false
        }
        else{
            return true
        }
    }
```

处理所有的验证信息

```swift
func checkAll() -> Bool {
        if action == .show {return true}
        errors.removeAll()
        let r1 = checkName()
        let r2 = checkSex()
        let r3 = checkBirthday()
        let r4 = checkChange()
        return r1&&r2&&r3&&r4
    }
```

通过 onChange 来进行校验

```swift
.onChange(of: myState){ _ in
         confirm =  checkAll()
       }
//由于 onChange 必须在数据源发生变化时才会激发，所以在 View 最初显示时便进行一次验证
.onAppear{
     confirm =  checkAll()
   }
```

对 toolbar 的内容进行处理

```swift
ToolbarItem(placement: ToolbarItemPlacement.navigationBarTrailing){
                    if action == .show {
                        Button("编辑"){
                            action = .edit
                            confirm = false
                        }
                    }
                    else {
                    Button("确定"){
                        if action == .new {
                        presentationMode.wrappedValue.dismiss()
                        store.newStudent(viewModel: myState)
                        }
                        if action == .edit{
                            presentationMode.wrappedValue.dismiss()
                            store.editStudent(viewModel: myState, student: student!)
                        }
                    }
                    .disabled(!confirm)
                    }
```

更详尽的内容可以参看 [源代码](https://github.com/fatbobman/DismissConfirmSheet)

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
