---
date: 2021-11-15 08:10
description: 本文将介绍关于在 Core Data 中对 NSManagedObject 进行深拷贝的技术难点、开发思路，以及我的解决方案——MOCloner。
tags: Core Data
title:  如何在 Core Data 中对 NSManagedObject 进行深拷贝
image: images/mocloner.png
---

对 NSMangedObject 进行深拷贝的含义是**为一个 NSManagedObject（托管对象）创建一个可控的副本，副本中包含该托管对象所有关系层级中涉及的所有数据**。

尽管 Core Data 是一个功能强大的对象图管理框架，但本身并没有直接提供托管对象的复制方法。如果开发者想创建某个托管对象的副本，唯一可行的途径就是编写一段特定的代码，将原始对象中属性的内容逐个读出并赋值给新对象。此种方式在托管对象结构简单时比较有效，一旦托管对象结构复杂、关系繁多，代码量将显著增大，且极易出错。

多年来开发者一直在寻找一种便捷且通用的工具来解决深拷贝的问题，不过直到现在并没有一个被广泛认可的方案。

我在开发 [健康笔记](https://www.fatbobman.com/healthnotes/) 新版本时也碰到了这个问题，需要深拷贝一个结构复杂、关系链牵涉大量数据的托管对象。考虑到以后可能还会遇到类似的情况，我决定编写一段使用简单、适用性广的代码方便自己使用。

本文中将探讨在 Core Data 中对 NSManagedObject 进行深拷贝的技术难点、解决思路，并介绍我写的工具——[MOCloner](https://github.com/fatbobman/MOCloner)。

```responser
id:1
```

## 对 NSManagedObject 进行深拷贝的难点 ##

### 复杂的关系结构 ###

下图是 [健康笔记](https://www.fatbobman.com/healthnotes/) 的数据模型图节选。尽管只选取了模型关系的一部分，但实体之间几乎涵盖了所有的关系类型，包含了 one-to-one、one-to-many、many-to-many 等形式。

每当复制一个 Note 对象，同时会涉及关系链条中数百上千个其它对象。实现对所有数据的快速、准确地深拷贝具有相当挑战性。

![image-20211112143836634](https://cdn.fatbobman.com/image-20211112143836634.png)

### 选择性拷贝 ###

当进行深拷贝时，有时我们并不需要复制所有关系层级中的全部数据，可能会想在第 n 个层级忽略某个 n+1 级的关系分支。

或者在复制托管对象某个属性（可选或设有默认值）时，选择性的不复制其内容。

以上工作都最好能在深拷贝时一并处理。

### 数据有效性 ###

托管对中某些属性具有唯一性或即时性，在深拷贝中需特别处理。

例如：

* 上图中 Note 的 id 的类型为 UUID，在深拷贝时不应复制原来的内容而应该为新对象创建新的数据
* Item 中的 NoteID 应该对应的是 Note 的 id，如何在复制过程中保持一致
* ItemDate 的 createDate 应该是记录创建的时间，如何将其设置为深拷贝时的日期

如果无法在深拷贝时一并处理类似的问题，在数据量大的情况下，拷贝后调整将比较吃力。

### 逆向对多关系 ###

上图中 Tag 同 Memo 之间是多对多（many-to-many）关系。当在一个关系链条上出现了逆向对多（Tag）的情况时，需特别谨慎处理。Tag 从业务逻辑上并不属于某个 Note 的具体分支，如何处理此种情况一直都是 Core Data 数据同步时的一个难题。

## 深拷贝的解决思路 ##

尽管需要面对的问题不少，但仍旧可以利用 Core Data 提供的众多手段予以解决。

### 善用 Description ###

在 Xcode 中使用 Data Model Editor 创建的数据模型，会在编译时转换成 momd 文件并保存在 Bundle 中。在创建 NSPersistentContainer 时，NSManagedObjectModel 将通过该文件将模型定义转换为程序实现。代码通过访问 Core Data 提供的各种 Description 可以获取到所需信息。

开发者最常接触的 Description 可能就是 NSPersistentStoreDescription 了，从中可以获取 Config 或者设置 iCloud options（更多资料请参阅 [掌握 Core Data Stack](https://www.fatbobman.com/posts/masteringOfCoreDataStack/)）。

其它的的 Description 还包括但不限于：

* NSEntityDescription

  实体描述

* NSRelationshipDescription

  实体关系的描述

* NSAttributeDescription

  实体 Attribute 的描述

* NSFetchIndexDescription

  索引 Index 的描述

* NSDerivedAttributeDescription

  派生属性的描述

下面的代码将用给定托管对象的 NSEntityDescription，创建一个结构相同的新对象：

```swift
guard let context = originalObject.managedObjectContext else {
    throw CloneNSManagedObjectError.contextError
}

// create clone NSManagedObject
guard let entityName = originalObject.entity.name else {
    throw CloneNSManagedObjectError.entityNameError
}
let cloneObject = NSEntityDescription.insertNewObject(
    forEntityName: entityName,
    into: context
)
```

通过 NSAttributeDescription，获取托管对象的所有属性描述：

```swift
let attributes = originalObject.entity.attributesByName
for (attributeName, attributeDescription) in attributes {
    ...
}
```

通过 NSRelationshipDescription，遍历托管对象的所有关系描述：

```swift
let relationships = originalObject.entity.relationshipsByName

for (relationshipName, relationshipDescription) in relationships {
    ...
}
```

获取逆向关系描述对应的实体：

```swift
let inverseEntity = relationshipDescription.inverseRelationship?.entity
```

这些 Description 是开发 NSManagedObject 深拷贝通用代码的基石。

### 使用 userinfo 传递信息 ###

为解决上文中提到的选择性拷贝、数据有效性等问题，需要在深拷贝时给代码提供足够的信息。

由于这些信息可能分布在整个关系链的各个层级中，最直接、有效的方式是在 Xcode 的数据模型编辑器提供的 User Info 中添加对应的内容。

![image-20211112163510728](https://cdn.fatbobman.com/image-20211112163510728.png)

每个使用过 Xcode 数据模型编辑器的开发者应该都看到过右侧的 User Info 输入框。通过该输入框，我们可以为 Entity、Attribute、Relationship 设置想要传递的信息，并从对应的 Description 中提取出来。

下面的代码将判断 Attribute 的 userinfo 中是否有排除标志：

```swift
if let userInfo = attributeDescription.userInfo {
    // Check if the "exclude" flag is added to this attribute
    // Only detemine whether the Key is "exclude" or note, do not care about the Vlaue
    if userInfo[config.exclude] != nil {
        if attributeDescription.isOptional || attributeDescription.defaultValue != nil {
            continue
        } else {
            throw CloneNSManagedObjectError.attributeExcludeError
        }
    }
}
```

下面的代码将对 userinfo 中包含有 rebuild : uuid 标志的 Attribute（类型为 UUID），创建新的 UUID：

```swift
if let action = userInfo[config.rebuild] as? String {
                    switch action {
                    case "uuid":
                        if attributeDescription.attributeType == NSAttributeType.UUIDAttributeType {
                            newValue = UUID()
                        } else {
                            throw CloneNSManagedObjectError.uuidTypeError
                        }
                    ...
                    default:
                        break
                    }
                }
```

### setPrimitiveValue 和 setValue ###

在 Core Data 开发中，会在不少场合使用 setPrimitiveValue 。比如在 awakeFromInsert 中为属性设置初始值，在 willSave 中用检查属性值的有效性等等。尤其当我们无法直接调用托管对象实例属性时，使用 setPrimitiveValue 可以方便的利用 AttributeName 来设置 Value。

```swift
for (attributeName, attributeDescription) in attributes {
    var newValue = originalObject.primitiveValue(forKey: attributeName)
    cloneObject.setPrimitiveValue(newValue, forKey: attributeName)
}
```

由于 setPrimitiveValue 直接访问托管对象的原始值（跳过快照），因而效率更高，同时不触发 KVO 观察。

setPrimitiveValue 也有其缺点——不会自动处理逆向关系。使用它来设置关系内容，需要在关系的两侧都进行对应的工作，代码量将显著提高。

对于托管对象实例，多数情况下通常会直接采用 Core Data 生成的关系管理方法来进行关系操作，例如：

```swift
@objc(addItemsObject:)
@NSManaged public func addToItems(_ value: Item)

@objc(removeItemsObject:)
@NSManaged public func removeFromItems(_ value: Item)

@objc(addItems:)
@NSManaged public func addToItems(_ values: NSSet)

@objc(removeItems:)
@NSManaged public func removeFromItems(_ values: NSSet)
// Note 和 Item 是 one-to-many 的关系
let note = Note(context: viewContext)
let item = Item(context: viewContext)
note.addToItems(item)
item.note = note
```

在通用型的深拷贝代码中，我们无法直接使用这些系统预置的方法，但可以通过 setValue 来设置关系数据。

setValue 将在内部查找对应的 Setter 来完成双向关系的管理工作。

下面是设置 to-one 关系的代码：

```swift
if !relationshipDescription.isToMany,
   let originalToOneObject = originalObject.primitiveValue(forKey: relationshipName) as? NSManagedObject {
    let newToOneObject = try cloneNSMangedObject(
        originalToOneObject,
        parentObject: originalObject,
        parentCloneObject: cloneObject,
        excludedRelationshipNames: passingExclusionList ? excludedRelationshipNames : [],
        saveBeforeReturn: false,
        root: false,
        config: config
    )
    cloneObject.setValue(newToOneObject, forKey: relationshipName)
}
```

### NSSet 和 NSOrderedSet ###

在 Core Data 中，对多关系在生成的 NSMangedObject Subclass 代码中对应的类型是 NSSet? ，但如果将对多关系设置为有序时，对应的类型将变成 NSOrderedSet? 。

![image-20211112184857192](https://cdn.fatbobman.com/image-20211112184857192.png)

通过判断 NSRelationshipDescription 的 isOrdered ，选择正确的对应类型。例如：

```swift
if relationshipDescription.isOrdered {
    if let originalToManyObjects = (originalObject.primitiveValue(forKey: relationshipName) as? NSOrderedSet) {
        for needToCloneObject in originalToManyObjects {
            if let object = needToCloneObject as? NSManagedObject {
                let newObject = try cloneNSMangedObject(
                    object,
                    parentObject: originalObject,
                    parentCloneObject: cloneObject,
                    excludedRelationshipNames: passingExclusionList ? excludedRelationshipNames : [],
                    saveBeforeReturn: false,
                    root: false,
                    config: config
                )
                newToManyObjects.append(newObject)
            }
        }
    }
}
```

### 逆向关系对多的处理逻辑 ###

沿着关系链向下，如果某个关系的逆向关系为对多，则无论正关系是对一还是对多，在深拷贝时都会形成一个尴尬的局面——逆向关系为对多的实体，服务于全部的正向关系树。

例如，前文图中的 Memo 和 Tag，一个备注可以对应多个标签，同时一个标签也可以对应多个备注。当我们从 Note 向下深拷贝到 Memo 时，如果继续对 Tag 进行复制，则会和 Tag 的设计初衷相违背。

解决方案为，当在关系链中碰到了逆向关系为对多的实体 A，则不再继续向下拷贝。而是将新拷贝的托管对象添加到与 A 的关系中，满足数据模型的设计意图。

![image-20211112192815648](https://cdn.fatbobman.com/image-20211112192815648.png)

```swift
if let inverseRelDesc = relationshipDescription.inverseRelationship, inverseRelDesc.isToMany {
    let relationshipObjects = originalObject.primitiveValue(forKey: relationshipName)
    cloneObject.setValue(relationshipObjects, forKey: relationshipName)
}
```

```responser
id:1
```

## 用 MOCloner 进行深拷贝 ##

综合上面的思路，我写了一个用于在 Core Data 中对 NSManagedObject 进行深拷贝的库 —— [MOCloner](https://github.com/fatbobman/MOCloner)

### MOCloner 说明 ###

MOCloner 是一个很小的库，旨在实现对 NSManagedObject 的可定制深拷贝。支持 one-to-one、one-to-many、many-to-many 关系方式。除了忠于原始数据的拷贝方式外，还提供了选择性拷贝、拷贝时生成新值等功能。

### 基础演示 ###

创建上图中 Note 的深拷贝

```swift
let cloneNote = try! MOCloner().clone(object: note) as! Note
```

从关系链中间部分向下深拷贝（不拷贝关系链向上的部分）

```swift
// 在 excludedRelationshipNames 中添加忽略的关系名称
let cloneItem = try! MOCloner().clone(object: item, excludedRelationshipNames: ["note"]) as! Item
```

### 自定义 ###

MOCloner 采用在 Xcode 的 Data Model Editor 中对 User Info 添加键值的方式对深拷贝过程进行定制。目前支持如下命令：

* exclude

  该键可以设置在 Attribute 或 Relationship 中。只要出现 exclude 键，无论任何值都将启用排除逻辑。

  设置在 Attribute 的 userinfo 时，深拷贝将不复制原始对象属性的值（要求 Attribute 为 Optional 或已经设置了 Default value）。

  设置在 Relationship 的 userinfo 时，深拷贝将忽略此关系分支下的所有关系和数据。

  为了方便某些不适合在 userinfo 中设置的情况（比如从关系链中间进行深拷贝），也可以将需要排除的关系名称添加到 excludedRelationshipNames 参数中（如基础演示 2）。

![image-20211112200648882](https://cdn.fatbobman.com/image-20211112200648882.png)

* rebuild

  用于在深拷贝时动态生成新的数据。仅用于设置 Attribute。目前支持两个 value : uuid 和 now。

  uuid：类型为 UUID 的 Attribute，在深拷贝时为该属性创建新的 UUID

  now：类型为 Date 的 Attribute，在深拷贝时为该属性创建新的当前日期（Date.now）

![image-20211112201348978](https://cdn.fatbobman.com/image-20211112201348978.png)

* followParent

  简化版的 Derived。仅用于设置 Attribute。可以指定关系链下层 Entity 的 Attribute 获取上层关系链对应的托管对象实例的指定 Attribute 值（要求两个 Attribute 类型一致）。下图中，Item 的 noteID 将获得 Note 的 id 值。

![image-20211112205856380](https://cdn.fatbobman.com/image-20211112205856380.png)

* withoutParent

  仅搭配 followParent 使用。处理当从关系链中部进行深拷贝时，设置了 followParent 但无法获取 ParentObject 的情况。

  当 withoutParent 为 keep 时，将保持被复制对象的原值

  当 withoutParent 为 blank 时，将不对其设置值（要求该 Attribute 为 Optional 或设有 Default value）

![image-20211112210330127](https://cdn.fatbobman.com/image-20211112210330127.png)

如果以上 userinfo 的键名称与你的项目中已经使用的键名称冲突，可以通过自定义 MOClonerUserInfoKeyConfig 重新设置。

```swift
let moConfig = MOCloner.MOClonerUserInfoKeyConfig(
    rebuild: "newRebuild", // new Key Name
    followParent: "followParent",
    withoutParent: "withoutParent",
    exclude: "exclude"
)

let cloneNote = try cloner.clone(object: note,config: moConfig) as! Note
```

### 系统需求 ###

MOCloner 最低需求为 macOS 10.13、iOS 11、tvOS 11、watchOS 4 以上的系统。

### 安装 ###

MOCloner 使用 Swift Package Manager 分发。要在另一个 Swift 包中使用它，请在你的 Package.swift 中将其作为一个依赖项添加。

```swift
let package = Package(
    ...
    dependencies: [
        .package(url: "https://github.com/fatbobman/MOCloner.git", from: "0.1.0")
    ],
    ...
)
```

如果想在应用程序中使用 MOCloner，请使用 Xcode 的 File > Add Packages... 将其添加到你的项目中。

```swift
import MOCloner
```

鉴于 MOCloner 只有几百行代码，可以将代码拷贝到你的项目中直接使用。

## 使用 MOCloner 的注意事项 ##

### 在私有上下文中进行 ###

当深拷贝涉及到大量数据时，请在私有上下文中进行操作，避免占用主线程。

最好在深拷贝操作前后使用 NSManagedObjectID 进行数据传递。

### 内存占用 ###

当深拷贝的托管对象牵涉大量的关系数据时，则可能会形成大量的内存占用。在包含二进制类型数据时会尤为明显（比如将大量图片数据保存在 SQLite 中）。可以考虑使用如下的方式控制内存的占用情况：

* 在深拷贝时，将内存占用较高的属性或关系暂时排除。深拷贝后，通过其它的代码再为其逐个添加。
* 深拷贝多个托管对象时，考虑通过 performBackgroundTask 逐个进行。

## 版本与支持 ##

MOCloner 采用 [MIT](https://github.com/fatbobman/MOCloner/blob/main/LICENSE) 协议，你可以自由地在项目中使用它。但请注意，MOCloner 不附带任何官方支持渠道。

Core Data 提供了丰富的功能和选项，开发者可以使用它创建大量不同组合的关系图。MOCloner 只对其中的部分情况做了测试。因此，在开始准备将 MOCloner 用于你的项目之前，强烈建议你花点时间熟悉其实现，并做更多的单元测试，以防遇到任何可能出现的数据错误问题。

如果你发现问题、错误，或者想提出改进建议，请创建 [Issues](https://github.com/fatbobman/MOCloner/issues) 或 [Pull Request](https://github.com/fatbobman/MOCloner/pulls)。

## 总结 ##

对 NSManagedObject 进行深拷贝并非是一个常见的功能需求。但当有了可以轻松完成的解决手段时，或许可以在你的 Core Data 项目中尝试一些新的设计思路。

希望 [MOCloner](https://github.com/fatbobman/MOCloner) 和本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。

