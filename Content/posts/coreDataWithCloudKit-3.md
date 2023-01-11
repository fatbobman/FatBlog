---
date: 2021-08-09 17:30
description: 本篇文章中，我们将一起研究 CloudKit 仪表台。
tags: CloudKit,Core Data
title: Core Data with CloudKit（三）—— CloudKit 仪表台
---
本篇文章中，我们将一起研究`CloudKit`仪表台。

[Core Data with CloudKit （一） —— 基础](/posts/coreDataWithCloudKit-1/)

[Core Data with CloudKit（二） —— 同步本地数据库到 iCloud 私有数据库](/posts/coreDataWithCloudKit-2/)

[Core Data with CloudKit（三）—— CloudKit 仪表台](/posts/coreDataWithCloudKit-3/)

[Core Data with CloudKit（四）—— 调试、测试、迁移及其他](/posts/coreDataWithCloudKit-4/)

[Core Data with CloudKit（五）—— 同步公共数据库](/posts/coreDataWithCloudKit-5/)

[Core Data with CloudKit （六） —— 创建与多个 iCloud 用户共享数据的应用](/posts/coreDataWithCloudKit-6/)

## 初识仪表台 ##

使用`CloudKit Dashboard`需要开发者拥有 [Apple Developer Program](https://developer.apple.com/programs/) 账号，访问 [https://icloud.developer.apple.com](https://icloud.developer.apple.com) 即可使用。

![image-20210808161150623](https://cdn.fatbobman.com/image-20210808161150623-8410311.png)

最近两年苹果对`CloudKit 仪表台`的布局做过较大的调整，上面的截图是 2021 年中时的样子。

仪表台主要分为三个部分：

* 数据库（`CloudKit Database`）

  数据库`Web`客户端。涵盖管理`Schema`、`Record`、`Zone`、用户权限、容器环境等功能。

* 遥测（`Telemetry`）

  使用直观的可视化效果，深入了解应用程序的服务器端性能以及跨数据库和推送事件的利用率。

* 日志（`Logs`）

  CloudKit 服务器生成实时和历史日志，记录并显示应用程序和服务器之间的交互。

> 在绝大多数使用`Core Data with CloudKit`的场景下，我们仅需要使用仪表板中极少数的功能（环境部署），但利用`CloudKit Dashboard`，我们可以更清楚的了解`Core Data`数据同步背后运作的一些机制。

```responser
id:1
```

## 数据库（CloudKit Database） ##

![image-20210808163319683](https://cdn.fatbobman.com/image-20210808163319683-8411600.png)

在 [Core Data with CloudKit （一） —— 基础](/posts/coreDataWithCloudKit-1/) 中已经对`CKContainer`、`CKDababase`、`CKZone`、`CKSubscription`、`CKRecord`等基础对象做了简单的说明，本文还将介绍`CloudKit`的其他一些对象和功能。

### 环境 ###

`CloudKit`为你的应用程序网络数据分别提供了开发环境（Develpment）和生产环境（Production）。

* 开发环境

  当你的项目仍处于开发阶段时，所有通过`CloudKit`产生的数据都只被保存开发环境中，只有开发团队的成员才能访问该环境中的数据。在开发环境中，你可以随时进行`Schema`结构调整、对`Record Type`的属性进行删除修改等操作。即使这些操作可能会引起不同版本之间数据冲突都没有问题（可以随时重置开发环境）。非常类似`Core Data`的应用程序上线前的状态，即使数据无法正常迁移，只需要删除重装 app 即可。通过开发环境，开发者可以在向用户提供`CloudKit`服务之前对应用程序进行充分的测试。

* 生产环境

  当应用程序完成开发并准备提交应用商店时，需要将开发环境的结构部署到生产环境（`Deploy Schema Changes`）。`Schema`一旦部署到生产环境，则意味着开发者不可以像在开发环境中那样随意对`Schema`进行修改，所有的修改都必须以向前兼容的方式进行。

  原因非常简单，一旦应用程序上线，我们无法控制客户端的更新频率，也就是客户端可能存在任何的结构版本，为了能够让低版本的客户端一样可以访问数据，任何对数据模型的更改都需要向下兼容。

  在`App Store`上销售的应用程序只能访问生产环境。

即使开发者的开发者账户同个人`iCloud`账户一致，开发环境和生产环境也是两个不同的沙盒，数据是互不影响的。当使用`Xcode`调试程序时，应用只能访问开发环境，而通过`Testflight`或`App Store`下载的应用则只能访问生产环境。

在开发环境下，点击`Deploy Schema Changes`将开发环境的`Schema`部署到生产环境。

![image-20210808180259192](https://cdn.fatbobman.com/image-20210808180259192-8416980.png)

部署时，会显示自上次部署后开发环境做出的修改。

即使`Schema`已经部署到生产环境后，我们仍可继续改动开发环境并部署到生产环境，如果模型无法满足兼容条件，`CloudKit`仪表台将会禁止你的部署行为。

![image-20210808175543219](https://cdn.fatbobman.com/image-20210808175543219-8416544.png)

在容器名称下方会显示`Schema`是否已经部署到生产环境。上图是尚未部署的状态，下图是已经部署的状态。

![image-20210808180421055](https://cdn.fatbobman.com/image-20210808180421055-8417062.png)

![image-20210808180014216](https://cdn.fatbobman.com/image-20210808180014216-8416815.png)

在做任何操作之前，要首先确认是否处于正确的环境设定中。

> 鉴于`CloudKit`的环境部署规则，**在采用`Core Data with CloudKit`的项目中设计`Core Data`数据模型时一定要特别小心！**。我个人的原则是**可加、不减、不改**。我将在下篇文章详细讨论该如何对`Core Data with CloudKit`数据模型做版本迁移。

### 安全角色（Security Roles） ###

安全角色仅适用于公共数据库。

`CloudKit`使用基于角色的访问控制（`RBAC`）来管理权限和控制对**公共数据库中**数据的访问（私有数据库对于应用程序的用户是唯一的）。通过`CloudKit`，你可以为一个角色设置权限级别，然后将该角色分配给一个给定的记录类型（`Record Type`）。

权限包括读、写、创建。读权限只允许读取记录，写权限允许读取和写入记录，而创建权限允许读取和写入记录以及创建新纪录。

`CloudKit`包含 3 个预设角色，分别为 World（`_world`）、Authenticated（`_icloud`）和 Creator（`_creator`）。World 表示任何人，无论其是否为 iCloud 用户。Authenticated 适用于任何经过验证的 iCloud 用户。Creator 则是作为记录（`Record`）的创建者。

![image-20210808210401070](https://cdn.fatbobman.com/image-20210808210401070-8427842.png)

默认的设置为，任何人都可以读取数据，只有经过验证的 iCloud 用户才可以创建新纪录，记录的创建者可以更新自己的记录。

![image-20210809062640040](https://cdn.fatbobman.com/image-20210809062640040-8461601.png)

我们可以创建自定义安全角色，但是不能创建用户记录（`User Record`），当用户第一次对容器进行身份验证时时系统会为该用户创建用户记录。我们可以查找现有用户并将其分配给任意的自定义的角色。

安全角色是数据模型（`Schema`）的一部分，每当开发者修改了安全设置后，需要将其部署到生产环境才能在生产环境生效。部署后无法删除安全角色。

> 大多数`Core Data with CloudKit`应用场合，直接使用系统的默认配置即可。

### 索引（Indexes） ###

`CloudKit`的索引分为三种类型：

* 可查询（`queryable`）
* 可搜索（`searchable`）
* 可排序（`sortable`）

当我们通过`CloudKit`创建`Recored Type`后，可以根据需要为每个字段创建所需的索引（只有`NSString`支持可搜索）。索引类型选项是独立的，如果你希望该字段既可查询又可排序，则需要分别创建两个索引。

![image-20210809064449042](https://cdn.fatbobman.com/image-20210809064449042-8462689.png)

**只有为`Record Type`的`recordName`创建了`queryable`索引后，才可以在`Records`中浏览该 Type 的数据。**

![image-20210809065509228](https://cdn.fatbobman.com/image-20210809065509228-8463311.png)

![image-20210809064743215](https://cdn.fatbobman.com/image-20210809064743215-8462864.png)

> `Core Data with CloudKit`会自动为`Core Data`数据模型的每个属性在`CloudKit`上创建需要的索引（不包含`recordName`）。除非你需要在`CloudKit`仪表台上浏览数据，否则我们不需要对索引做任何添加。

### Record Types ###

`Record Type`是开发人员为`CKRecord`指定的类型标识符。你可以直接在代码中创建它，也可以在`CloudKit`仪表盘上对其进行创建、修改。

![image-20210809073043092](https://cdn.fatbobman.com/image-20210809073043092-8465444.png)

在 [基础篇](/posts/coreDataWithCloudKit-1/) 中曾提到`Entity`相较`Record Type`拥有更多的配置信息，但`Record Type`也有一个`Enitity`没有的特性——元数据。

![image-20210809075124786](https://cdn.fatbobman.com/image-20210809075124786-8466685.png)

`CloudKit`为每一个`Record Type`预设了若干元数据字段（即使开发者没有创建任何其他字段），每条数据记录（`CKRecord`）都会包含这些信息，其中绝大多数都是系统自动设定的。

* createdTimestamp

  `CloudKit`首次将记录保存到服务器的时间

* createUserRecordName

  `_creator`的用户记录，该记录保存在`Users`（系统创建）中，每当用户第一次对容器进行身份验证时时系统会为该用户创建用户记录

* _etag

  版本令牌。每次`CloudKit`保存记录时，都会将该记录更新为新值。用于比较网络和本地数据的版本

* modifiedTimestamp

  `CloudKi`t 更新记录的最近时间

* modifiedUserRecordName

  最后更新数据的用户记录

* recordName

  记录的唯一 ID。在创建`CKRcord`时创建，通常会设置为`UUID`字符串

对于一些特殊类型的`Record Type`，系统还会增加一些针对性的元数据，比如`role`,`cloud.shared`等

本文的主题为`Core Data with CloudKit`，因此让我们来看一下`NSPersistentCloudKitContainer`是如何将`Core Data`托管对象的属性转换成`CloudKit`的`Recore Type`字段的。

![image-20210809104558352](https://cdn.fatbobman.com/image-20210809104558352-8477160.png)

![image-20210809104402659](https://cdn.fatbobman.com/image-20210809104402659-8477043.png)

> 上图是我们在 [同步本地数据库到 iCloud 私有数据库](/posts/coreDataWithCloudKit-2/) 中模版项目`Item`在`CloudKit`对应的`Record Type`。`CloudKit`会自动为托管对象实体的每个属性创字段，将属性名称映射到了具有`CD_[attribute.name]`键名的字段。该字段的类型在`Core Data`和`CloudKit`之间可能也会有所不同。`Record Type`名称为`CD_[entity]`。一切的操作都是由系统自动完成的，我们无需干预。另外，还会为`Enitity`生成一个`CD_entityName`的字段，内容为`Entity`的类映射名。

这些以`CD_`为前缀的字符串，在数据同步过程中将不断出现在控制台上，了解了它的构成对调试代码有一定帮助。

`Record Type`部署到生产环境后，字段不可以删除，字段名称也不可以修改。因此一些`Core Data`中的操作在`Core Data with CloudKit`中是不允许的。

**不要对已经上线的应用程序数据模型的`Entity`进行更名，也不要对`Attribute`更名，即使使用 Mapping Model、Renaming ID 都是不行的。在开发阶段如果需要更名的话，可能需要删除 app 重装并重置`CloudKit`的开发环境。**

### Zones ###

每个种类的数据库都有默认`Zone`，只有私有数据库可以自定义`Zone`。

![image-20210809143010363](https://cdn.fatbobman.com/image-20210809143010363-8490611.png)

对于私有数据库中的数据，在创建`CKRecord`时可以为数据指定`Zone`。

```swift
let zone = CKRecordZone(zoneName: "myZone")
let newStudent = CKRecord(recordType: "Student",
                          recordID: CKRecord.ID(recordName: UUID().uuidString,
                                                zoneID: zone.zoneID))

```

`NSPersistentCloudKitContainer`在将托管对象转换成`CKRecord`时，将`ZoneID`统一设置为`com.apple.coredata.cloudkit.zone`。必须切换到正确的`Zone`才能浏览到数据。

![image-20210809143648531](https://cdn.fatbobman.com/image-20210809143648531-8491011.png)

* OWNER RECORD NAME

  用户记录，对应`Zone`的`_creator`

* CHANGE TOKEN

  比对令牌

* ATOMIC

  当 CloudKit 无法更新`Zone`中的一个或多个记录时，如果值为`true`则整个操作失败

### Records ###

用于数据记录的浏览、创建、删除、更改、查询。

![image-20210809150327144](https://cdn.fatbobman.com/image-20210809150327144-8492609.png)

在浏览数据时，需注意以下几点：

* 选择正确的环境（开发环境和生产环境的数据完全不同）
* 选择正确的`Database`、`Zone`
* 确认需要浏览的`Record Type`元数据`recordName`已经添加了`queryable`索引
* 如果需要对字段进行排序或过滤，请给该字段创建对应的索引
* 索引只有在部署后才会在生产环境下起作用

> 在`CloudKit`仪表台中修改`Core Data`的镜像数据，客户端会立即收到远程通知并进行更新。不过并不推荐此种做法。

你也可以在代码中获取到`Core Data`托管对象对应的`CKRecord`：

```swift
func getLastUserID(_ object:Item?) -> CKRecord.ID? {
    guard let item = object else {return nil}
    guard let ckRecord = PersistenceController.shared.container.record(for: item.objectID) else {return nil}
    guard let userID = ckRecord.lastModifiedUserRecordID else {
        print("can't get userID")
        return nil
    }
    return userID
}
```

上面的代码，将获取托管对象记录对应的`CKRecord`的最后修改用户

### Subscriptions ###

浏览在容器上注册的`CKSubscription`。

CKSubscription 是通过代码创建的，在仪表盘上只可以查看或删除。

比如下面的代码将创建一个`CKQuerySubscription`

```swift
        let predicate = NSPredicate(format: "name = 'bob'")
        let subscription = CKQuerySubscription(recordType: "Student",
                                               predicate: predicate,
                                               options: [.firesOnRecordCreation])
        let info = CKSubscription.NotificationInfo()
        info.alertLocalizationKey = "create a new bob"
        info.soundName = "NewAlert.aiff"
        info.shouldBadge = true
        info.alertBody = "hello world"

        subscription.notificationInfo = info

        publicDB.save(subscription) { subscription, error in
            if let error = error {
                print("error:\(error)")
            }
            guard let subscription = subscription else { return }
            print("save subscription successes:\(subscription)")
        }
```

![image-20210809154503445](https://cdn.fatbobman.com/image-20210809154503445-8495104.png)

> `NSPersistentCloudKitContainer`会为`Core Data`镜像的私有数据库注册一个`CKDatabaseSubscription`。当`com.apple.coredata.cloudkit.zone`数据更新时，会推送远程通知。

![image-20210809154946576](https://cdn.fatbobman.com/image-20210809154946576-8495387.png)

### Tokens&Keys ###

设置容器的 API 令牌。

![image-20210809152554058](https://cdn.fatbobman.com/image-20210809152554058-8493955.png)

除了可以通过代码和`CloudKit`仪表台对数据进行操作外，苹果还提供了从网络或其他平台访问`iCloud`数据的手段。在获取令牌后，开发者还可以通过使用 [CloudKit JS](https://developer.apple.com/documentation/cloudkitjs) 或 [CloudKit Web 服务](https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitWebServicesReference/) 与数据进行交互。

已有开发者利用以上服务，开发出可在其他平台访问 iCloud 数据的第三方库，比如 [DroidNubeKit](https://github.com/jaumecornado/DroidNubeKit)（在安卓上访问`CloudKit`）。

> 对于`Core Data`的网络镜像数据，除非你的数据模型足够简单，否则不推荐做这种尝试。`CloudKit Web`服务更适合直接通过`Cloudkit`创建的数据记录。

### Sharing Fallbackd ###

为低版本操作系统（低于 iOS 10、macOS Sierra）提供数据记录共享回调支持。

## 遥测（Telemetry） ##

![image-20210809161022705](https://cdn.fatbobman.com/image-20210809161022705-8496624.png)

通过查看 Telemetry 的指标，方便你在开发或更新应用程序时可视化性能。包括请求数量、错误数量、推送数量、服务器延迟以及平均请求大小等等。通过设定范围，仅显示与你相关的数据，帮助你更好地了解应用程序的流量配置及使用趋势。

## 日志（Logs） ##

![image-20210809162346212](https://cdn.fatbobman.com/image-20210809162346212-8497427.png)

在历史日志中，你可以查看包括时间、客户端平台版本、用户（匿名）、事件、组织、细节等信息。

在提供详尽信息的基础上，`CloudKit`尽可能地保持用户数据的隐秘性。日志显示每个用户记录的服务器事件，但不暴露任何个人身份信息。仅显示匿名的、特定于容器的`CloudKit`用户。

`AppStoreConnect`的分析信息仅来自已同意与 App 开发者共享诊断和使用信息的用户，`CloudKit`日志信息则来自于你的应用程序中所有使用了`CloudKit`服务的用户。两者结合使用，可以获得更好的效果。

## 总结 ##

大多数使用`Core Data with CloudKit`的场景，开发者基本无需使用`CloudKit`仪表盘。不过偶尔研究一下仪表盘上的数据，也是一种不错的乐趣。

下一篇文章，我们将聊一下开发`Core Data with CloudKit`项目经常会碰到的一些情况，比如调试、测试、数据迁移等。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
