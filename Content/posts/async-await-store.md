---
date: 2021-09-06 11:05
description: 本文介绍了如何使用 Swift 5.5 版本的 Async/Await 功能重构 SwiftUI 的状态容器代码。
tags: SwiftUI,Architecture
title: 用 Async-Await 重建 SwiftUI 的 Redux-like 状态容器
image: images/redux-like_store.png
---
经过两年多的时间，SwiftUI 发展到当前的 3.0 版本，无论 SwiftUI 的功能还是 Swift 语言本身在这段时间里都有了巨大的提升。是时候使用 Async/Await 来重构我的的状态容器代码了。

```responser
id:1
```

## SwiftUI 的状态容器 ##

我是从王巍的 [SwiftUI 与 Combine 编程](https://objccn.io/products/) 一书中，第一次接触到`Single souce of truth`式的编程思想。整体来说，同 Redux 的逻辑基本一致：

* 将 App 当做状态机，UI 是 App 状态（State）的具体呈现。
* State（值类型）被保存在一个 Store 对象当中，为了在视图中注入方便，Store 需符合`ObservableObject`协议，且为 State 设置`@Published`属性包装，保证 State 的任何变化都将被及时响应。
* View 不能直接修改 State，只能通过发送 Action 间接改变 Store 中的 State 内容
* Store 中的 Reducer 负责处理收到的 Action，并按照 Action 的要求变更 State

![Redux1](https://cdn.fatbobman.com/Redux1.png)

通常，对 State、Store 和 Action 的定义如下：

```swift
struct AppState {
    var name: String = ""
    var age:Int = 10
}

enum AppAction {
    case setName(name:String)
    case setAge(age:Int)
}

final class Store: ObservableObject {
    @Published private(set) var state: AppState
  
    func dispatch(action:Action) {
        reducer(action)
    }
  
    func reducer(action) 
}
```

Reducer 在处理 Action 时，经常会面对带有副作用（side effect）的情况，比如：

* 需从网络查询获得数据后，根据数据修改 State
* 修改 State 后，需要向磁盘或数据库写入数据等

我们无法控制副作用的执行时间（有长有短），并且副作用还可能会通过 Action 继续来改变 State。

对状态（State）的修改必须在主线程上进行，否则视图不会正常刷新。

我们构建的状态容器（Store）需要满足处理上述情况的能力。

## 1.0 版本 ##

在编写 [健康笔记 1.0](https://www.fatbobman.com/healthnotes/) 时，我采用了 [SwiftUI 与 Combine 编程](https://objccn.io/products/) 一书中提出的解决方式。

对于副作用采用从 Reducer 中返回 Command 的方式来处理。Command 采用异步操作，将返回结果通过 Combine 回传给 Store。

```swift
struct LoginAppCommand: AppCommand {
  //...
  func execute(in store: Store) {
    //...
    .sink(
      receiveCompletion: { complete in
        if case .failure(let error) = complete {
          store.dispatch(
            .accountBehaviorDone(result: .failure(error))
          )
        }
      },
      receiveValue: { user in
        store.dispatch(
          .accountBehaviorDone(result: .success(user))
        )
      }
    )
  }
}
```

```swift
func reduce(
  state: AppState, 
  action: AppAction
) -> (AppState, AppCommand?) 
{
  // ...
  case .accountBehaviorDone(let result):
    // 1
    appState.settings.loginRequesting = false
    switch result {
    case .success(let user):
      // 2
      appState.settings.loginUser = user
    case .failure(let error):
      // 3
      print("Error: \(error)")
    }
  }
  
  return (appState, appCommand)
}
```

采用了如下的方式保证了 State 只能在主线程上进行修改：

```swift
    func dispatch(_ action: AppAction) {
        let result = reduce(state: appState, action: action)
        if Thread.isMainThread {
            state = result.0
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.state = result.0
            }
        }
        if let command = result.1 {
            command.execute(in: self)
        }
    }
```

作者自己在书中也说上述代码属于试验性质，因此尽管完全胜任 Store 的工作，但是从逻辑组织上还是比较复杂，尤其对于每个 Command 的处理十分的繁琐。

## 2.0 版本 ##

通过阅读、学习 Majid 的文章 [Redux-like state container in SwiftUI](https://swiftwithmajid.com/2019/09/18/redux-like-state-container-in-swiftui/)，在 [健康笔记](https://www.fatbobman.com/healthnotes/)2.0 中，我重构了 Store 的代码。

Majid 的实现方式最大的提升在于，大大简化了副作用代码的复杂度，将原本需要在副作用中处理的 Publisher 生命周期管理集中到了 Store 中。并且使用 Combine 提供的线程调度，保证了只在主线程上修改 State。

```swift
    func dispatch(_ action: AppAction) {
        let effect = reduce(&state, action, environment)

        var didComplete = false
        let uuid = UUID()

        let cancellable = effect
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] _ in
                    didComplete = true
                    self?.effectCancellables[uuid] = nil
                },
                receiveValue: { [weak self] in self?.send($0) }
            )
        if !didComplete {
            effectCancellables[uuid] = cancellable
        }
    }
```

Reducer

```swift
    private let reduce: Reducer<AppState, AppAction, AppEnvironment> = Reducer { state, action, environment in
        switch action {
        case .editMemo(let memo, let newMemoViewModel):
            return environment.dataHandler.editMemo(memo: memo, newMemoViewModel: newMemoViewModel)

        case .setSelection(let selection):
            state.selection = selection
        }
     return Empty(completeImmediately: true)
            .eraseToAnyPublisher()        
    }                                                                          
```

副作用代码

```swift
func editNote(note: Note, newNoteViewModel: NoteViewModel) -> AnyPublisher<AppAction, Never> {
        _ = _updateNote(note, newNoteViewModel)
        if !_coreDataSave() {
            logDebug("更新 Note 出现错误")
        }
        return Just(AppAction.none).eraseToAnyPublisher()
    }
```

## 3.0 版本 ##

无论 1.0 版本还是 2.0 版本，都可以很好的完成我们对状态容器功能的要求。

两个版本都严重依赖 Combine，都是采用 Combine 来进行异步代码的生命周期管理，并且在 2.0 中又是通过 Combine 提供的`.receive(on: DispatchQueue.main)`来进行的线程调度。

幸好，Combine 很好的完成了这个本来并非它最擅长（管理生命周期，线程调度）的工作。

今年，Swift 5.5 推出了大家期待已久的 Async/Await 功能，在对新功能有了一定的了解后，我便有了用 Async/Await 来实现新的状态容器的想法。

* 使用@MainActore 保证 State 只能在主线程被修改
* dispatch 创建即发即弃的 Task 完成副作用生命周期管理
* 同 2.0 版本类似，在副作用方法中返回`Task<AppAction,Error>`，简化副作用代码

具体的实现：

```swift
@MainActor
final class Store: ObservableObject {
    @Published private(set) var state = AppState()
    private let environment = Environment()

    @discardableResult
    func dispatch(_ action: AppAction) -> Task<Void, Never>? {
        Task {
            if let task = reducer(state: &state, action: action, environment: environment) {
                do {
                    let action = try await task.value
                    dispatch(action)
                } catch {
                    print(error)
                }
            }
        }
    }
}
```

Reducer：

```swift
extension Store {
    func reducer(state: inout AppState, action: AppAction, environment: Environment) -> Task<AppAction, Error>? {
        switch action {
        case .empty:
            break
        case .setAge(let age):
            state.age = age
            return Task {
                await environment.setAge(age: 100)
            }
        case .setName(let name):
            state.name = name
            return Task {
                await environment.setName(name: name)
            }
        }
        return nil
    }
}
```

副作用：

```swift
final class Environment {
    func setAge(age: Int) async -> AppAction {
        print("set age")
        return .empty
    }

    func setName(name: String) async -> AppAction {
        print("set Name")
        await Task.sleep(2 * 1000000000)
        return AppAction.setAge(age: Int.random(in: 0...100))
    }
}
```

由于 Store 声明为@MainActor，我们在代码中须通过如下两种方式之一来引用：

```swift
@main
struct NewReduxTest3AppApp: App {
    @StateObject var store = Store()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
```

或者

```swift
@main
@MainActor
struct NewReduxTest3AppApp: App {
    let store = Store()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
```

新版本的代码不仅易读性更好，而且可以充分享受到 Swift5.5 带来的安全、高效的线程调度能力。

## 总结 ##

通过此次重建状态容器，让我对 Swift 的 Async/Await 有了更多的了解，也认识到它在现代编程中的重要性。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。

