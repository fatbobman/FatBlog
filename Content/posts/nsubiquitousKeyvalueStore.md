---
date: 2021-12-13 08:12
description: NSUbiquitousKeyValueStore 是苹果官方提供的用于在设备间共享键值数据的解决方案。本文将对其用法做以简单介绍，着重探讨如何便捷地在 SwiftUI 中使用 NSUbiquitousKeyValueStore。
tags: SwiftUI,Architecture,CloudKit
title:  在 SwiftUI 下使用 NSUbiquitousKeyValueStore 同步数据
image: images/nsubiquitousKeyvalueStore.png
---
NSUbiquitousKeyValueStore 是苹果官方提供的用于在设备间共享键值数据的解决方案。本文将对其用法做以简单介绍，着重探讨如何便捷地在 SwiftUI 中使用 NSUbiquitousKeyValueStore。

```responser
id:1
```

## 什么是 NSUbiquitousKeyValueStore

NSUbiquitousKeyValueStore 可以理解为 UserDefaults 的网络同步版本。它是 CloudKit 服务项目中的一员，只需简单的配置，就可以实现在不同的设备上共享数据（同一个 iCloud 账户）。

NSUbiquitousKeyValueStore 在大多数场合下表现的同 UserDefaults 十分类似：

* 都是基于键值存储
* 只能使用字符串作为键
* 可以使用任意属性列表对象（Property list object types）作为值
* 使用类似的读取和写入方法
* 都是率先将数据保存在内存中，系统会择机对内存数据进行持久化（此过程开发者通常无需干预）

即使你没有使用过 UserDefaults，只需花几分钟阅读一下 [官方文档](https://developer.apple.com/documentation/foundation/nsubiquitouskeyvaluestore) 便可以掌握其基本用法。

### 同 UserDefaults 之间的不同

* NSUbiquitousKeyValueStore 不提供注册默认值的方法

  使用 UserDefaults 时，开发者可以使用 `register(defaults:[String:Any])` 为键设置默认值，NSUbiquitousKeyValueStore 并没有提供类似的手段。对于不返回可选值的类型，应避免使用简便方法来获取值。

  例如，可以使用类似下面的代码获取键名为"count"的整数值：

```swift
func getInt(key: String, defaultValue: Int) -> Int {
    guard let result = NSUbiquitousKeyValueStore.default.object(forKey: key) as? Int else {
        return defaultValue
    }
    return result
}

let count = getInt(key: "count", defaultValue: 30)

// longLong 的返回值不是可选值，应避免使用类似下方的简便方式获取值
// NSUbiquitousKeyValueStore.default.longLong(forKey: "count") 默认值为 0
```

* NSUbiquitousKeyValueStore 有更多的限制

  苹果并**不推荐使用 NSUbiquitousKeyValueStore 保存数据量大、变化频繁且对 app 运行至关重要的数据**。

  NSUbiquitousKeyValueStore 最大的存储容量为 1MB（每个用户），存储的键值对不得超过 1024 对。

  NSUbiquitousKeyValueStore 网络同步的效率一般，在顺畅的情况下，一个键值对的数据可以在 10-20 秒左右完成同步。如果数据变化频繁，iCloud 会自动降低同步频率，同步时间可能会被延长至数分钟。开发者在进行测试时，由于会在短时间内多次修改数据，极大概率会出现同步缓慢的情况。

  尽管 NSUbiquitousKeyValueStore 没有提供数据同步的原子支持，但在绝大多数情况下，NSUbiquitousKeyValueStore 会尽量保证在用户切换 iCloud 账户、重新登录 iCloud 账户、无网络后重新连接等状况下的数据完整性。但在个别情况下仍会出现数据不更新，设备之间不同步的情况，例如：

  当 app 在正常运行过程中，用户在系统设置中选择关闭 app 的 iCloud 同步。此后 app 中所有对 NSUbiquitousKeyValueStore 的修改，即使在用户恢复 app 的 iCloud 同步功能后，都不会上传到服务器中。

* NSUbiquitousKeyValueStore 需要有开发者账户

  需要拥有开发者账户才能启用 iCloud 同步功能。

* NSUbiquitousKeyValueStore 尚未提供 SwiftUI 下的便捷使用方法

  从 iOS 14 开始，苹果为 SwiftUI 提供了 AppStorage，同对待@State 一样，通过@AppStorage，视图可以对 UserDefaults 中值的变化做出及时响应。

> 在多数情况下，我们可以将@AppStorage 看作是 UserDefaults 的 SwiftUI 包装，但在个别情况下，@AppStorage 并不完全与 UserDefaults 的行为保持一致（不仅仅指支持的数据类型方面）。

### 配置

在代码中使用 NSUbiquitousKeyValueStore 之前，我们首先需要对项目进行一定的配置以启用 iCloud 的键值存储功能。

* 在项目 TARGET 的 Signing&Capabilities 中，设置正确的 Team

![image-20211209174459745](https://cdn.fatbobman.com/image-20211209174459745.png)

* 在 Signing&Capabilities 中，点击左上角 `+Capability` 添加 iCloud 功能

![image-20211209174535198](https://cdn.fatbobman.com/image-20211209174535198.png)

* 在 iCloud 功能中，选中 Key-value storage

![image-20211209174907203](https://cdn.fatbobman.com/image-20211209174907203.png)

在选择键值存储后，Xcode 将为项目自动创建 entitlements 文件。并为`iCloud Key-Value Store`设置好对应的值`$(TeamIdentifierPrefix)$(CFBundleIdentifier)`

![image-20211209175258618](https://cdn.fatbobman.com/image-20211209175258618.png)

TeamIdentifierPrefix 是你的开发者 Team（在最后需要添加`.`），可以从 [开发者账户 Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/certificates/list) 的右上角获取（由字母数字和点组成`XXXXXXXX.`）：

![image-20211209184208635](https://cdn.fatbobman.com/image-20211209184208635.png)

CFBundleIdentifier 就是 app 的的 Bundle Identifier。

如果想在其他的 app 或扩展上使用同一个 iCloud Key-value Store，可以手动修改 entitlements 文件中对应的内容。

获取其他 app 的 iCloud Key-value Store 最方便的方法是，在 plist 添加值为`$(TeamIdentifierPrefix)$(CFBundleIdentifier)`的键，通过`Bundle.main.object(forInfoDictionaryKey:)`进行查看。

> 可以确定的是，在同一个开发者账号下，只要指向同一个 iCloud Key-Value Store，无论是在不同的 app、还是 app extension 之间都可以同步数据（同一个 iCloud 账户）。我无法对不同的开发者账号指向同一个 iCloud Key-Value Store 的情况进行测试，请有条件的朋友帮忙测试一下并告知我，谢谢。

## 在 SwiftUI 视图中使用 NSUbiquitousKeyValueStore

本节中，我们将在不使用任何第三方库的情况下，实现 SwiftUI 视图对 NSUbiquitousKeyValueStore 的变化实时响应。

NSUbiquitousKeyValueStore 的基本工作流程如下：

* 将键值对保存到 NSUbiquitousKeyValueStore 中
* NSUbiquitousKeyValueStore 首先将键值数据保存在内存中
* 系统择机将数据持久化到磁盘上（开发者可以通过调用`synchronize()`显式调用该操作）
* 系统择机将变化的数据发送到 iCloud 上
* iCloud 和其他设备择机对变更后的数据进行同步
* 设备将网络同步的数据持久化到本地
* 同步完成后，会发送`NSUbiquitousKeyValueStore.didChangeExternallyNotification`通知，提醒开发者

除了网络同步的步骤外，工作流程同 UserDefaults 几乎一样。

在不使用第三方库的情况下，在 SwiftUI 视图中可以通过桥接@State 数据的形式，将 NSUbiquitousKeyValueStore 的变化同视图联系起来。

下面的代码将在 NSUbiquitousKeyValueStore 创建一个键名称为 text 的字符串，并将其同视图中的变量 text 关联起来：

```swift
struct ContentView: View {
    @State var text = NSUbiquitousKeyValueStore().string(forKey: "text") ?? "empty"

    var body: some View {
        TextField("text:", text: $text)
            .textFieldStyle(.roundedBorder)
            .padding()
            .task {
                for await _ in NotificationCenter.default.notifications(named: NSUbiquitousKeyValueStore.didChangeExternallyNotification) {
                    if let text = NSUbiquitousKeyValueStore.default.string(forKey: "text") {
                        self.text = text
                    }
                }
            }
            .onChange(of: text, perform: { value in
                NSUbiquitousKeyValueStore.default.set(value, forKey: "text")
            })
    }
}
```

task 中的代码的作用与下方的代码等同，想了解具体的用法，可以参看 [聊聊 Combine 和 async/await 之间的合作](https://www.fatbobman.com/posts/combineAndAsync/) 一文：

```swift
.onReceive(NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)) { _ in
    if let text = NSUbiquitousKeyValueStore.default.string(forKey: "text") {
        self.text = text
    }
}
```

在 didChangeExternallyNotification 的 userinfo 中还含有一些其他的信息，比如消息提示原因以及本次变更的键名称等。

事实上，我们不可能对于每个 NSUbiquitousKeyValueStore 的键都采用上述的方式来驱动视图，在下文章我们将尝试使用更加方便的方法来完成同 SwiftUI 的集成工作。

## 像@AppStorage 一样使用 NSUbiquitousKeyValueStore

尽管上节中的代码有些繁琐，但它已经指明了 NSUbiquitousKeyValueStore 同视图联动的方向——将 NSUbiquitousKeyValueStore 的变化同一个可以导致视图刷新的数据（State、ObservableObject 等）关联起来，就可以实现同@AppStorage 一样的效果。

原理上并不复杂，但是为了能够支持全部的类型仍需要做大量细致的工作。好在 Tom Lokhorst 已经为我们实现了这一切，使用他开发的 [CloudStorage](https://github.com/tomlokhorst/CloudStorage) 库，我们可以十分轻松地在视图中使用 NSUbiquitousKeyValueStore。

上节中的代码在使用 CloudStorage 库后将变成：

```swift
@CloudStorage("text") var text = "empty"
```

使用方式同@AppStorage 完全一样。

> 很多开发者在选择支持 NSUbiquitousKeyValueStore 的第三方库时，可能会率先想到 [Zephyr](https://github.com/ArtSabintsev/Zephyr)。Zephyr 在处理 UserDefaults 同 NSUbiquitousKeyValueStore 之间的联动方面做的很不错，但由于@AppStorage 的独特性（并非真正意义上的 UserDefaults 完整包装），Zephyr 对于@AppStorage 的支持目前是有问题的，笔者并不推荐使用。

## 集中管理 NSUbiquitousKeyValueStore 的键值

随着 app 中创建的 UserDefaults、NSUbiquitousKeyValueStore 键值对的不断增加，逐个在视图中引入的方式将让数据变得难以管理。因此需要寻找一种适合 SwiftUI 的方式，将键值对统一配置、集中管理。

在 [@AppStorage 研究](https://www.fatbobman.com/posts/appstorage/) 一文中，我介绍过如何对@AppStorage 进行统一管理、集中注入的方法。例如：

```swift
class Defaults: ObservableObject {
    @AppStorage("name") public var name = "fatbobman"
    @AppStorage("age") public var age = 12
}

// 在视图中，集中注入
@StateObject var defaults = Defaults()
...
Text(defaults.name)
TextField("name",text:defaults.$name)
```

那么，是否可以沿用这个思路将@CloudStorage 纳入进来呢？

> 2022 年 5 月更新：我按照 @Published 的实现方式重新修改了 @CloudStorage 。现在 @CloudStorage 的行为已经与 @AppStorage 完全一致了。详细内容请参阅[为自定义属性包装类型添加类 @Published 的能力](https://www.fatbobman.com/posts/adding-Published-ability-to-custom-property-wrapper-types/)。

~~遗憾的是，我至今仍没搞清@AppStorage 是如何从代码层面实现类似@Published 行为的原理。因此，我们只能采用一点相对笨拙的方式来达到目的~~。

~~我对 CloudStrorage 进行了一点修改，在几个数据更改的时机点上添加了通知机制，通过在符合 ObservableObject 的类中，响应该通知并调用`objectWillChange.send()`来模拟@AppStorage 的特性。~~

可以在此下载 [修改后的 CloudStorage 代码](https://github.com/fatbobman/CloudStorage)。

```swift
class Settings:ObservableObject {
       @AppStorage("name") var name = "fat"
       @AppStorage("age") var age = 5
       @CloudStorage("readyForAction") var readyForAction = false
       @CloudStorage("speed") var speed: Double = 0
}

struct DemoView: View {
    @StateObject var settings = Settings()
    var body: some View {
        Form {
            TextField("Name",text: $settings.name)
            TextField("Age", value: $settings.age, format: .number)
            Toggle("Ready", isOn: $settings.readyForAction)
                .toggleStyle(.switch)
            TextField("Speed",value: $settings.speed,format: .number)
        }
        .frame(width: 400, height: 400)
    }
}
```

由于 SwiftUI 系统组件包装的特殊性，采用上述的方式统一管理@AppStorage 和@CloudStorage 数据时，**请特别注意在视图中调用@CloudStorage Binding 数据的方式**。

只能使用`$storage.cloud`的方式，`stroage.$cloud`将会导致 binding 数据无法刷新 wrappedValue 情况，从而出现视图上数据更新不完整的情况。

## 总结

NSUbiquitousKeyValueStore 正如它的名称一样，让 app 的数据无处不在。只需很少的配置就可以为你的 app 添加该项功能，有需求的朋友可以行动起来了！

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
