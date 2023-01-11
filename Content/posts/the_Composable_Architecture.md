---
date: 2022-10-18 08:12
description: 本文将聊聊一个与创建复杂的 SwiftUI 应用很契合的框架 ——  The Composable Architecture（ 可组装框架，简称 TCA ）。包括它的特点和优势、最新的进展、使用中的注意事项以及学习路径等问题。
tags: SwiftUI,Architecture
title: 聊一聊可组装框架（ TCA ）
image: images/the_Composable_Architecture.png
---
本文将聊聊一个与创建复杂的 SwiftUI 应用很契合的框架 ——  The Composable Architecture（ 可组装框架，简称 TCA ）。包括它的特点和优势、最新的进展、使用中的注意事项以及学习路径等问题。

## TCA 简介

> 本节的内容来自 TCA 官网说明的中文版本

The Composable Architecture ( 简写为 TCA ) 让你用统一、便于理解的方式来搭建应用程序，它兼顾了组装，测试，以及功效。你可以在 SwiftUI，UIKit，以及其他框架，和任何苹果的平台（ iOS、macOS、tvOS、和 watchOS ）上使用 TCA。

TCA 提供了用于搭建适用于各种目的、复杂度的 app 的一些核心工具，你可以一步步地跟随它去解决很多你在日常开发中时常会碰到的问题，比如：

- **状态管理（State Management）** 
  用简单的值类型来管理应用的状态，以及在不同界面调用这些状态，使一个界面内的变化可以立刻反映在另一个界面中。
- **组装（Composition）** 
  将庞大的功能拆散为小的可以独立运行的组件，然后再将它们重新组装成原来的功能。
- **副作用（Side Effects）** 
  用最可测试和便于理解的方式来让 app 的某些部分与外界沟通。
- **测试（Testing）** 
  除了测试某个功能，还能集成测试它与其他功能组合成为的更复杂的功能，以及用端到端测试来了解副作用如何影响你的应用。这样就可以有力地保证业务逻辑和预期相符。
- **工效（Ergnomics）** 
  用一个有最少概念和可动部分，且简单的 API 来做到上面的一切。

> 本文将不对 State、Action、Reducer、Store 这些概念做进一步的说明

## TCA 的特点和优势

```responser
id:1
```

### 强大的组装能力

既然框架被命名为可组装框架（ The Composable Architecture ），那么必然在组装能力上有其独到之处。

TCA 鼓励开发者将大型功能分解成采用同样开发逻辑的小组件。每个小组件均可进行单元测试、视图预览乃至真机调试，并通过将组件代码提取到独立模块的方式来进一步改善项目的编译速度。

所谓的组装，便是将这些独立的组件按预设的层级、逻辑粘合到一起组成更加完整功能的过程。

组装这一概念在多数的状态管理框架中都存在，而且仅需少量的代码便可以提供一些基础的组装能力。但有限的组装能力限制并影响了开发者对复杂功能的切分意愿，组装的初衷并没有被彻底执行。

TCA 提供了大量的工具来丰富其组装手段，当开发者发现组装已不是难事时，在开发的初始阶段便会从更小的粒度来思考功能的构成，从而创建出更加强壮、易读、易扩展的应用。

TCA 提供的部分用于组装的工具：

#### CasePaths

可以将其理解为 KeyPath 的枚举版本。

在其他 Redux-like 框架中，在组装上下级组件时需要提供两个独立的闭包来映射不同组件之间的 Action ，例如：

```swift
func lift<LiftedState, LiftedAction, LiftedEnvironment>(
    keyPath: WritableKeyPath<LiftedState, AppState>,
    extractAction: @escaping (LiftedAction) -> AppAction?, // 将下级组件的 Action 转换为上级组件的 Action
    embedAction: @escaping (AppAction) -> LiftedAction, // 将上级 Action 转换为下级的 Action
    extractEnvironment: @escaping (LiftedEnvironment) -> AppEnvironment
) -> Reducer<LiftedState, LiftedAction, LiftedEnvironment> {
    .init { state, action, environment in
        let environment = extractEnvironment(environment)
        guard let action = extractAction(action) else {
            return Empty(completeImmediately: true).eraseToAnyPublisher()
        }
        let effect = self(&state[keyPath: keyPath], action, environment)
        return effect.map(embedAction).eraseToAnyPublisher()
    }
}

let appReducer = Reducer<AppState,AppAction,AppEnvironment>.combine(
    childReducer.lift(keyPath: \.childState, extractAction: {
        switch $0 {  // 需要为每个子组件的 Action 分别映射
            case .childAction(.increment):
                return .increment
            case .childAction(.decrement):
                return .decrement
            default:
                return .noop
        }
    }, embedAction: {
        switch $0 {
            case .increment:
                return .childAction(.increment)
            case .decrement:
                return .childAction(.decrement)
            default:
                return .noop
        }
    }, extractEnvironment: {$0}),
    parentReducer
)

```

[CasePaths](https://github.com/pointfreeco/swift-case-paths) 为这一转换过程提供了自动处理的能力，我们仅需在上级组件的 Action 中定义一个包含下级 Action 的 case 即可：

```swift
enum ParentAction {
    case ...
    case childAction(ChildAction)
}

let appReducer = Reducer<AppState,AppAction,AppEnvironment>.combine(
  counterReducer.pullback(
    state: \.childState,
    action: /ParentAction.childAction, // 通过 CasePaths 直接完成映射
    environment: { $0 }
  ),
  parentReducer
)
```

#### IdentifiedArray

[IdentifiedArray](https://github.com/pointfreeco/swift-identified-collections) 是一个具备字典特征的类数组类型。它具备数组的全部功能和接近的性能，要求其中的元素必须符合 Identifiable 协议，且 id 在 identifiedArray 唯一。如此一来，开发者就可以不依赖 index ，直接以字典的方式，通过元素的 id 访问数据。

IdentifiedArray 确保了将父组件中状态（ State ）中的某个序列属性切分成独立的子组件状态时的系统稳定性。避免出现因使用 index 修改元素而导致的异常甚至应用崩溃的情况。

如此一来，开发者在对序列状态进行拆分时将更有信心，操作也更加方便。

例如：

```swift
struct ParentState:Equatable {
    var cells: IdentifiedArrayOf<CellState> = []
}

enum ParentAction:Equatable {
    case cellAction(id:UUID,action:CellAction) // 在父级组件上创建用于映射子 Action 的 case，使用元素的 id 作为标识
    case delete(id:UUID)
}

struct CellState:Equatable,Identifiable { // 元素符合 Idntifiable 协议
    var id:UUID
    var count:Int
    var name:String
}

enum CellAction:Equatable{
    case increment
    case decrement
}

let parentReducer = Reducer<ParentState,ParentAction,Void>{ state,action,_ in
    switch action {
        case .cellAction:
            return .none
        case .delete(id: let id):
            state.cells.remove(id:id) // 使用类似字典的方式操作 IdentifiedArray ，避免出现 index 对应错误或超出范围的情况
            return .none
    }
}

let childReducer = Reducer<CellState,CellAction,Void>{ state,action,_ in
    switch action {
        case .increment:
            state.count += 1
            return .none
        case .decrement:
            state.count -= 1
            return .none
    }
}

lazy var appReducer = Reducer<ParentState,ParentAction,Void>.combine(
    // 
    childReducer.forEach(state: \.cells, action: /ParentAction.cellAction(id:action:), environment: { _ in () }),
    parentReducer
)

// 在视图中，可以直接采用 ForEachStore 来进行切分
ForEachStore(store.scope(state: \.cells,action: ParentAction.cellAction(id: action:))){ store in
    CellVeiw(store:store)
}
```

#### WithViewStore

除了应用于 Reducer、Store 上的各种组装、切分方法外，TCA 还特别针对 SwiftUI 提供了在视图内进行进一步细分的工具 —— WithViewStore 。

通过 WithViewStore ，开发者可以在视图中进一步控制当前视图所要关注的状态以及操作，不仅改善了视图中代码的纯粹性，也在一定程度减少了不必要的视图刷新，提高了性能。例如：

```swift
struct TestCellView:View {
    let store:Store<CellState,CellAction>
    var body: some View {
        VStack {
            WithViewStore(store,observe: \.count){ viewState in // 只关注 count 的变化，即使 cellState 中的 name 属性发生变化，本视图也不会重新刷新
                HStack {
                    Button("-"){viewState.send(.decrement)}
                    Text(viewState.state,format: .number)
                    Button("-"){viewState.send(.increment)}
                }
            }
        }
    }
}
```

> 类似的工具还有不少，更多资料请阅读 TCA 的官方文档

### 完善的副作用管理机制

在现实的应用中，不可能要求所有的 Reducer 都是纯函数，对于保存数据、获取数据、网络连接、记录日志等等操作都将被视为副作用（ TCA 中称之为 Effect ）。

对于副作用，框架主要提供两种服务：

* **依赖注入**

  在 [0.41.0](https://github.com/pointfreeco/swift-composable-architecture/releases/tag/0.41.0) 版本之前，TCA 对于外部环境的注入方式与大多其他的框架类似，并没有什么特别之处，但在新版本中，依赖注入的方式有了巨大的变动，下文中会有更详细的说明。

* **副作用的包装和管理**

  在 TCA 中，Reducer 处理任何一个 Action 之后都需要返回一个 Effect，开发者可以通过在 Effect 中生成或返回新的 Action 从而形成一个 Action 链路。

  在 [0.40.0](https://github.com/pointfreeco/swift-composable-architecture/releases/tag/0.40.0) 版本之前，开发者需要将副作用的处理代码包装成 Publisher ，从而转换成 TCA 可接受的 Effect。从 0.40.0 版本开始，我们可以通过一些预设的 Effect 方法（ run、task、fireAndForget 等 ）直接使用基于 async/await 语法的异步代码，极大地降低了副作用的包装成本。

  另外，TCA 还提供了不少预设的 Effect ，以方便开发者应对包含复杂且大量副作用的使用场景，例如：timer、cancel、debounce、merge、concatenate 等。

总之，TCA 提供了完善的副作用管理机制，仅需少量的代码，便可以在 Reducer 中应对不同的场景需求。

### 便利的测试工具

相较其在组装方面的表现，TCA 对测试方面的关注与支持也是它另一大特点。这方面它拥有了其他中小框架所不具备的能力。

在 TCA 或类似的框架中，副作用都是以异步的方式运行的。这意味着，如果我们想测试一个组件的完整功能，通常无法避免都要涉及异步操作的测试。

而对于 Redux-like 类型的框架来说，开发者通常无需在测试功能逻辑时进行真正的副作用操作，只需让 Action -> Reducer -> State 的逻辑准确地运行即可。

为此，TCA 提供了一个专门用于测试的 TestStore 类型以及对应的 DispatchQueue 扩展，通过 TestStore ，开发者可以在一条虚拟的时间线上，进行发送 Action，接收 mock Action，比对 State 变化等操作。不仅稳定了测试环境，而且在某些情况下，可以将异步测试转换为同步测试，从而极大地缩短了测试的时间。例如（ 下面的代码采用 0.41.0 版本的 Protocol 方式编写 ）：

```swift
struct DemoReducer: ReducerProtocol {
    struct State: Equatable {
        var count: Int
    }

    enum Action: Equatable {
        case onAppear
        case timerTick
    }

    @Dependency(\.mainQueue) var mainQueue // 注入依赖

    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    while !Task.isCancelled {
                        try await mainQueue.sleep(for: .seconds(1)) // 使用依赖提供的 queue，方便测试
                        await send(.timerTick)
                    }
                }
            case .timerTick:
                state.count += 1
                return .none
            }
        }
    }
}

@MainActor
final class TCA_DemoReducerTests: XCTestCase {
    func testDemoStore() async {
        // 创建 TestStore
        let testStore = TestStore(initialState: DemoReducer.State(count: 0), reducer: DemoReducer())
        // 创建测试 queue ，TestSchedulerOf<DispatchQueue> 是 TCA 为了方便单元测试编写的 DispatchQueue 扩展，支持时间调整功能
        let queue = DispatchQueue.test
        testStore.dependencies.mainQueue = queue.eraseToAnyScheduler() // 修改成测试用的依赖
        let task = await testStore.send(.onAppear) // 发送 onAppear Action
        await queue.advance(by:.seconds(3))  // 时间向前推移 3 秒中（ 测试中并不会占用 3 秒的时间，会以同步的方式进行）
        _ = await testStore.receive(.timerTick){ $0.count = 1} // 收到 3 次 timerTick Action，并比对 State 的变化
        _ = await testStore.receive(.timerTick){ $0.count = 2}
        _ = await testStore.receive(.timerTick){ $0.count = 3}
        await task.cancel() // 结束任务
    }
}
```

上述代码，让我们无需等待，便可以测试一个本来需要执行三秒才能获得结果的单元测试。

除了 TestStore 外，TCA 还为测试提供了 XCTUnimplemented（ 声明未实现的依赖方法 ）、若干用于测试的新断言以及方便开发者创建截图的 [SnapshotTesting](https://github.com/pointfreeco/swift-snapshot-testing) 工具。

如此一来，开发者将可以通过 TCA 构建更加复杂、稳定的应用。

### 活跃的社区与详尽的资料

TCA 目前应该是受欢迎程度最高的基于 Swift 语言开发的该类型框架。截至本文写作时，[TCA](https://github.com/pointfreeco/swift-composable-architecture) 在 GitHub 上的 Star 已经达到了 7.2K 。它拥有一个相当活跃的社区，问题的反馈和解答都十分迅速。

TCA 是从 [Point Free](https://www.pointfree.co) 的视频课程中走出来的，Point Free 中有相当多的视频内容都与 TCA 有关，涉及当前开发中所面对的问题、解决思路、规划方案、实施细节等等方面。几乎没有其他的框架会有如此多详尽的伴生内容。这些内容可以除了起到了推广 TCA 的作用外，也让广大开发者逐步了解并掌握了 TCA 的各个环节，更加容易投入到 TCA 的社区贡献中。两者之间起到了非常好的相互促进作用。

## TCA 的最新变化（ from 0.40.0 ）

```responser
id:1
```

最近一段时间，TCA 进行了两次拥有重大意义的升级（ 0.40.0、0.41.0 ），本节将对部分的升级内容做以介绍。

### 更好的异步支持

在 0.40.0 之前的版本中，开发者需要将副作用的包装成 Publisher ，如此一来不仅代码量较多，也不利于使用目前日益增多的基于 async/await 机制的 API。本次更新后，开发者将可以在 Reducer 的 Effect 中直接使用这些新式的 API ，在减少了代码量的同时，也可以享受到 Swift 语言提供的更好的线程协调机制。

通过使用 SwiftUI 的 task 修饰器，TCA 实现了对需要长时间运行的 Effect 的生命周期进行自动管理。

> 由于 onAppear 和 onDisappear 在某些场合会在视图的存续期中多处出现，因此使用 task 保持的 Effect 生命周期并不一定与视图一致

例如，下面的代码，在 0.40.0 版本之后，将更加地清晰和自然：

```swift
// 老版本
switch action {
  case .userDidTakeScreenshotNotification:
    state.screenshotCount += 1
    return .none

  case .onAppear:
    return environment.notificationCenter
      .publisher(for: UIApplication.userDidTakeScreenshotNotification)
      .map { _ in LongLivingEffectsAction.userDidTakeScreenshotNotification }
      .eraseToEffect()
      .cancellable(id: UserDidTakeScreenshotNotificationId.self)

  case .onDisappear:
    return .cancel(id: UserDidTakeScreenshotNotificationId.self)
  }

// in View

Text("Hello")
    .onAppear { viewStore.send(.onAppear) }
    .onDisappear { viewStore.send(.onDisappear) }
```

使用 Task 模式：

```swift
 switch action {
    case .task:
      return .run { send in
        for await _ in await NotificationCenter.default.notifications(named: UIApplication.userDidTakeScreenshotNotification).values { // 从 AsyncStream 中读取
          await send(.userDidTakeScreenshotNotification)
        }
      }

    case .userDidTakeScreenshotNotification:
      state.screenshotCount += 1
      return .none
    }
  }

// in View
Text("Hello")
    .task { await viewStore.send(.task).finish() } // 在 onDisappear 的时候自动结束
```

另一方面，通过新的 TaskResult（ 类似 Result 的机制 ）类型，TCA 对 Task 的返回结果进行了巧妙地包装，让用户无需在 Reducer 中使用以前 Catch 的方式来处理错误。

### Reducer Protocol —— 用声明视图的方式来编写 Reducer

从 0.41.0 开始，开发者可以用全新的 ReducerProtocol 的方式来声明 Reducer（ 上文中介绍测试工具中展示的代码 ），并可通过 Dependency 的方式，跨层级的在 Reducer 中引入依赖。

Reducer Protocol 将带来如下优势：

* **更容易理解的定义逻辑**

  每个 Feature 都拥有自己的命名空间，其中包含它所需的 State、Action 以及引入的依赖，代码的组织更加合理。

* **更加友好的 IDE 支持**

  在未使用 Protocol 模式之前，Reducer 是通过一个拥有三个泛型参数的闭包生成的，在此种模式下，Xcode 的代码补全功能将不起作用，开发者只能通过记忆来编写代码，效率相当低下。使用了 ReducerProtocol 后，由于所有的需要用到的类型都声明在一个命名空间中，开发者将可以充分利用 Xcode 的自动补全高效地进行开发

* **与 SwiftUI 视图类似的定义模式**

  通过使用 [result builder](https://www.fatbobman.com/posts/viewBuilder1/) 重构了 Reducer 的组装机制，开发者将采用与声明 SwiftUI 视图一样的方式来声明 Reducer，更加地简洁和直观。由于调整了 Reducer 组装的构成角度，将从子 Reducer pullback 至父 Reducer 的方式修改为从父 Reducer 上 scope 子 Reducer 的逻辑。不仅更加易懂，而且也避免了一些容易出现的组装错误（ 因父子 Reducer 组装时错误的摆放顺序所导致 ）

* **更好的 Reducer 性能**

  新的声明方式，对 Swift 语言编译器更加地友好，将享受到更多的性能优化。在实践中，对同一个 Action 的调用，采用 Reducer Protocol 的方式所创建的调用栈更浅

* **更加完善的依赖管理**

  采用了全新的 DependencyKey 方式来声明依赖（ 与 SwiftUI 的 EnvironmentKey 非常相似），从而实现了同 EnvironmentValue 一样的可以跨 Reducer 层级的依赖引入。并且，在 DependencyKey 中，开发者可以同时定义用于 live、test、preview 三种场景分别对应的实现，进一步简化了在不同场景下调整依赖的需求

## 注意事项

### 学习成本

同其他具备强大功能的框架一样，TCA 的学习成本是不低的。尽管了解 TCA 的用法并不需要太多的时间，但如果开发者无法真正地掌握其内在的组装逻辑，很难写出让人满意的代码。

貌似 TCA 为开发者提供了一种从下至上的开发途径，但如果没有对完整功能进行良好地构思，到最后会发现无法组装出预想的效果。

TCA 对开发者的抽象和规划能力要求较高，切记不要简单学习后就投入到开发具备复杂需求的生产实践中。

### 性能

在 TCA 中，State、Action 都被要求符合 Equatable 协议，并且同很多 Redux like 解决方案一样，TCA 无法提供对引用值类型状态的支持。这意味着，在必须使用引用类型的一些场景，如果仍想保持单一 State 的逻辑，需要对引用类型进行值转换，在此种情况下，将有一定的性能损失。

另外，采用 WithViewStore 关注特定属性的机制在内部都是通过 Combine 来进行的。当 Reducer 的层级较多时，TCA 也需要付出不小的成本进行切分和比对的工作。一旦其所付出的代价超出了优化的结果，便会出现性能问题。

最后，TCA 目前仍无法应对高频次的 Action 调用，如果你的应用可能会产生高频次的 Action （ 每秒几十次 ），那么就需要对事件源进行一定的限制或调整。否则就会出现状态不同步的情况。

## 如何学习 TCA

尽管 TCA 在很大程度上减少了在视图中使用其他依赖项（ 符合 DynamicProperty 协议 ）的机会，但开发者仍应对 SwiftUI 提供的原生依赖方案有深刻的认识和掌握。一方面在很多轻量开发中，我们不需要使用如此重量级的框架，另一方面，即使在使用 TCA 的时候，开发者仍需要利用这些原生依赖作为 TCA 的补充。在 TCA 提供的 CaseStudies 代码中，已经充分地展示了这一点。 

如果你是 SwiftUI 的初学者，并且对 Redux 或 Elm 也没有多少了解，可以先尝试使用一些比较轻量级的 Redux-like 框架。在对这种开发模式有了一定的熟悉后，再学习 TCA 。我推荐大家可以阅读 Majid 创作的有关 Redux-like 的 [系列文章](https://swiftwithmajid.com/2019/09/18/redux-like-state-container-in-swiftui/)。

王巍有关 TCA 的系列文章 —— [TCA - SwiftUI 的救星？](https://onevcat.com/2021/12/tca-1/) 也是极好的入门资料，建议对 TCA 感兴趣的开发者进行阅读。

TCA 项目中提供了不少的范例代码，从最简单的 [Reducer 创建](https://github.com/pointfreeco/swift-composable-architecture/tree/0.35.0/Examples) 到功能完善的 [上架应用](https://github.com/pointfreeco/isowords)。这些范例代码也随着 TCA 的版本更新而不断变化，其中不少已经使用 Reducer Protocol 进行了重构。

当然，想了解有关 TCA 最新、最深入的内容还是需要观看 Point Free 网站上的视频课程。这些视频课程都提供了完整的文字版本以及对应的代码，即使你的听力有限也能通过文字版本掌握所有的内容。

如果你有订阅 Point Free 课程的打算，可以考虑使用我的 [指引链接](https://www.pointfree.co/subscribe/personal?ref=BPQh8JGm)。

## 总结

按照计划，TCA 在不久之后将使用 async/await 代码替换掉当前剩余的 Combine 代码（ Apple 的闭源代码 ）。这样它将可以成为一个支持多平台的框架。没准届时 TCA 将有机会被移植到其他语言。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ) 或博客的留言板与我进行交流。

> 我正以聊天室、Twitter、博客留言等讨论为灵感，从中选取有代表性的问题和技巧制作成 Tips ，发布在 Twitter 上。每周也会对当周博客上的新文章以及在 Twitter 上发布的 Tips 进行汇总，并通过邮件列表的形式发送给订阅者。

**订阅下方的 [邮件列表](https://artisanal-knitter-2544.ck.page/d3591dd1e7)，可以及时获得每周的 Tips 汇总。**
