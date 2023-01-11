---
date: 2022-01-17 08:12
description: 在 Core Data 中，开发者经常需要面对查询记录数量（count），使用 count 作为谓词或排序条件等需求。本文将介绍在 Core Data 下查询和使用 count 的多种方法，适用于不同的场景。
tags: Core Data,小题大做
title:  在 Core Data 中查询和使用 count 的若干方法
image: images/countInCoreData.png
---
在 Core Data 中，开发者经常需要面对查询记录数量（count），使用 count 作为谓词或排序条件等需求。本文将介绍在 Core Data 下查询和使用 count 的多种方法，适用于不同的场景。

```responser
id:1
```

## 一、通过 countResultType 查询 count 数据

本方法为最直接的查询记录条数的方式。通过将 NSFetchQuest 的 resultType 设置为 countResultType，可以直接获取到数据的 count 结果。

```swift
let fetchRequest = NSFetchRequest<NSNumber>(entityName: "Item")
fetchRequest.resultType = .countResultType
let count = (try? viewContext.fetch(fetchRequest).first)?.intValue ?? 0
print(count)
/*
 CoreData: sql: SELECT COUNT(*) FROM ZITEM
 CoreData: annotation: total count request execution time: 0.0002s for count of 190.
 190
 */
```

> 上文代码中的注释部分，为 Core Data 语句对应的 SQL 命令（使用 `-com.apple.CoreData.SQLDebug 1` 生成）。具体的设置方法，请参阅 [Core Data with CloudKit（四）—— 调试、测试、迁移及其他](https://www.fatbobman.com/posts/coreDataWithCloudKit-4/)

## 二、使用托管对象上下文的 count 方法查询 count 数据

方法一的便捷版本。调用托管对象上下文提供的 count 方法，返回值类型为 Int。

```swift
let fetchRequest = NSFetchRequest<Item>(entityName: "Item")
let count = (try? viewContext.count(for: fetchRequest)) ?? 0
print(count)
/*
 CoreData: sql: SELECT COUNT(*) FROM ZITEM
 CoreData: annotation: total count request execution time: 0.0002s for count of 190.
 190
 */
```

方法二和方法一对应着完全一致的 SQL 命令。

> 在仅需获取 count 的情况下（不关心数据的具体内容），方法一和方法二是很好的选择。

## 三、从结果集合中获取 count 数据

有时在获取数据集之后想同时查看数据集的 count，可以直接利用集合的 count 方法来实现。

```swift
let fetchRequest = NSFetchRequest<Item>(entityName: "Item")
fetchRequest.predicate = NSPredicate(format: "%K > %@", #keyPath(Item.timestamp), Date.now as CVarArg)
let items = (try? viewContext.fetch(fetchRequest)) ?? []
let count = items.count
print(count)
/*
 CoreData: sql: SELECT 0, t0.Z_PK, t0.Z_OPT, t0.ZTIMESTAMP FROM ZITEM t0 WHERE  t0.ZTIMESTAMP > ?
 CoreData: annotation: sql connection fetch time: 0.0001s
 CoreData: annotation: total fetch execution time: 0.0002s for 0 rows.
 */
```

调用 count 并不会出发导致数据的惰值填充。

在 SwiftUI 下，使用@FetchRequest 获取的结果集，也可以使用上述方式。

> 如果设置了 fetchLimit ，可能无法获得正确的 count 结果。设置 fetchLimit 后将只返回不超过设定数量的结果。

## 四、获取单条记录某对多关系的 count 数据

如果你的对象模型中设置了对多关系，调用关系属性的 count 方法，可以获取单条记录某对多关系的对象数量。

```swift
let fetchRequest = NSFetchRequest<Item>(entityName: "Item")
let items = (try? viewContext.fetch(fetchRequest)) ?? []
let firstItemTagsCount = items.first?.attachments?.count ?? 0 // 统计关系的数量，将导致本条记录被填充
print(firstItemTagsCount)
/*
 CoreData: sql: SELECT 0, t0.Z_PK, t0.Z_OPT, t0.ZTIMESTAMP FROM ZITEM t0
 CoreData: annotation: sql connection fetch time: 0.0002s
 CoreData: annotation: total fetch execution time: 0.0004s for 190 rows.
 CoreData: sql: SELECT 0, t0.Z_PK FROM Z_1TAGS t1 JOIN ZTAG t0 ON t0.Z_PK = t1.Z_2TAGS WHERE t1.Z_1ITEMS = ?
 CoreData: annotation: sql connection fetch time: 0.0001s
 CoreData: annotation: total fetch execution time: 0.0001s for 0 rows.
 CoreData: annotation: to-many relationship fault "tags" for objectID 0xa7ab2d44ebb9106e <x-coredata://0783522F-1851-4BC7-AE0D-AB4C83489E8B/Item/p1> fulfilled from database.  Got 0 rows
 0
 */
```

上面的代码将获取第一条记录中对多关系 attachments 的 count 数据。此例中，调用 count 方法将会导致 Core Data 为第一条记录填充数据，从而脱离惰值状态。

可以通过设置 relationshipKeyPathsForPrefetching 来调整填充时机。下面的代码，即使调用 count 方法，也并不会对数据进行填充。

```swift
let fetchRequest = NSFetchRequest<Item>(entityName: "Item")
fetchRequest.relationshipKeyPathsForPrefetching = ["attachments"]
let items = (try? viewContext.fetch(fetchRequest)) ?? []
let firstItemTagsCount = items.first?.attachments?.count ?? 0 // 统计关系的数量，提前加载 relationship，将不会导致本条记录被填充。
print(firstItemTagsCount)
/*
 CoreData: sql: SELECT 0, t0.Z_PK, t0.Z_OPT, t0.ZATTACHMENTCOUNT, t0.ZBIRTHOFYEAR, t0.ZTIMESTAMP FROM ZITEM t0
 CoreData: annotation: sql connection fetch time: 0.0003s
 CoreData: annotation: Bound intarray _Z_intarray0
 CoreData: annotation: Bound intarray values.
 CoreData: sql: SELECT 0, t0.Z_PK, t0.Z_OPT, t0.ZTITLE, t0.ZITEM FROM ZATTACHMENT t0 WHERE  t0.ZITEM IN (SELECT * FROM _Z_intarray0)  ORDER BY t0.ZITEM
 CoreData: annotation: sql connection fetch time: 0.0021s
 CoreData: annotation: total fetch execution time: 0.0024s for 1581 rows.
 CoreData: annotation: Prefetching with key 'attachments'.  Got 1581 rows.
 CoreData: annotation: total fetch execution time: 0.0053s for 190 rows.
 */
```

因为在 fetch 的过程中，通过 relationshipKeyPathsForPrefetching 中指定的关系数据的 NSManagedObjectID 已被一并提取。

## 五、使用对多关系的 count 设置谓词

对多关系的 count 也经常被用来作为谓词的条件使用。下面的代码将只返回 attachments（对多关系） count 大于 2 的结果。

```swift
let fetchquest = NSFetchRequest<Item>(entityName: "Item")
fetchquest.predicate = NSPredicate(format: "attachments.@count > 2")
let results = try? viewContext.fetch(fetchquest)
print(results?.count)
/*
 CoreData: sql: SELECT 0, t0.Z_PK, t0.Z_OPT, t0.ZTIMESTAMP FROM ZITEM t0 WHERE (SELECT COUNT(t1.Z_PK) FROM ZATTACHMENT t1 WHERE (t0.Z_PK = t1.ZITEM) ) > ?
 CoreData: annotation: sql connection fetch time: 0.0003s
 CoreData: annotation: total fetch execution time: 0.0006s for 144 rows.
 Optional(144)
 */
```

类似`attachments.@count`的方式只适用于谓词，无法将其作为排序条件。

## 六、通过派生属性记录对多关系的 count 数据

派生属性提供了对多关系 count 结果的预存能力。派生属性将在数据变化时（创建、更新、删除）按照设置，自动填充数据。在对 count 读取需求频繁的情况下，是极为优秀的解决方案

![derived](https://cdn.fatbobman.com/image-20211025183247335.png)

> 完整的派生属性使用方法，请参阅 [如何在 Core Data 中使用 Derived 和 Transient 属性](https://www.fatbobman.com/posts/derivedAndTransient/)。

```responser
id:1
```

## 七、利用派生属性记录的 count 进行排序

下面的代码中的 attachmentCount，是 Item 的派生属性，记录的是对多关系 attachments 的 count 数据。

```swift
let fetchquest = NSFetchRequest<Item>(entityName: "Item")
fetchquest.sortDescriptors = [NSSortDescriptor(keyPath: \Item.attachmentCount, ascending: true)]
let items = (try? viewContext.fetch(fetchquest)) ?? []
print(items.count)
/*
 CoreData: sql: SELECT 0, t0.Z_PK, t0.Z_OPT, t0.ZATTACHMENTCOUNT, t0.ZBIRTHOFYEAR, t0.ZTIMESTAMP FROM ZITEM t0 ORDER BY t0.ZATTACHMENTCOUNT
 CoreData: annotation: sql connection fetch time: 0.0002s
 CoreData: annotation: total fetch execution time: 0.0004s for 190 rows.
 190
 */
```

在通过派生属性预存了 count 数据的情况下，实现方法四的需求将更加简单。

## 八、使用 willSave 记录 count 数据

派生属性使用起来非常方便，但预置的方法有限。重写托管对象的 willSave 方法，可以获得更多的控制力。

比如下面的代码将只记录 attachment 中 title 长度大于 10 的 count 值

```swift
extension Item{
    public override func willSave() {
        super.willSave()
        let count = attachments?.allObjects.filter{
            (($0 as! Attachment).title?.count ?? 0 ) > 10
        }.count ?? 0
        setPrimitiveValue(Int32(count), forKey: "manualCount")
    }
}
```

在 willSave 中，我们可以根据业务的需要对数据进行调整或记录。复杂的逻辑将对数据更改的效率产生一定的影响。

> 为已经上线使用的 CoreData 数据库添加派生属性或 willSave 方法时，需通过 mapping 或迁移代码处理原有数据的新增属性。

## 九、查询某对多关系所有记录的 count 数据

当我们想统计全部记录（符合设定谓词）的某个对多关系的合计值时，在没有使用派生属性或 willSave 的情况下，可以使用下面的代码：

```swift
let fetchquest = NSFetchRequest<NSFetchRequestResult>(entityName: "Item")
let expressDescription = NSExpressionDescription()
fetchquest.resultType = .dictionaryResultType

let name = "totalAttachment"
expressDescription.name = name
expressDescription.resultType = .integer32

let attachmentCount = NSExpression(format: "attachments")
let express = NSExpression(forFunction: "count:", arguments: [attachmentCount])

expressDescription.expression = express
fetchquest.propertiesToFetch = [expressDescription]
let result = (try? viewContext.fetch(fetchquest).first as? [String: Int32]) ?? [:]
print(result[name] ?? 0)

/*
 也可以直接从 Attachment 一侧进行查询
 CoreData: sql: SELECT COUNT( t1.Z_PK) FROM ZITEM t0 LEFT OUTER JOIN ZATTACHMENT t1 ON t0.Z_PK = t1.ZITEM
 CoreData: annotation: sql connection fetch time: 0.0002s
 CoreData: annotation: total fetch execution time: 0.0002s for 1 rows.
 Optional([{
     totalAttachment = 839;
 }])

 */
```

上述代码的要点描述：

* 设置 resultType 为 dictionaryResultType
* NSExpressionDescription 将被用在 propertiesToFetch 中，它的名称和结果将出现在返回字典中
* NSExpression 在 Core Data 中使用的场景很多，例如在 Data Model Editor 中，很多的设定都是通过 NSExpression 完成的
* 此方法中 NSExpression 使用的是 count 方法
* 返回的结果是一个字典数组。需根据 propertiesToFetch，对字典的 Value 进行类型转换

使用此方法，SQLite 将在内部对 attachement 进行计数。

## 十、利用派生属性查询某对多关系所有记录的 count 数据

如果已经为对多关系设置了预存 count 的派生属性，可以使用下面的代码实现方法九的需求。

```swift
let fetchquest = NSFetchRequest<NSFetchRequestResult>(entityName: "Item")
fetchquest.resultType = .dictionaryResultType
let expressDescription = NSExpressionDescription()
let name = "totalAttachment"
expressDescription.name = name
expressDescription.resultType = .integer32

let attachmentCount = NSExpression(format: "%K", #keyPath(Item.attachmentCount))
let express = NSExpression(forFunction: "sum:", arguments: [attachmentCount])

expressDescription.expression = express
fetchquest.propertiesToFetch = [expressDescription]
let result = (try? viewContext.fetch(fetchquest).first as? [String: Int32]) ?? [:]
print(result[name] ?? 0)
/*
 oreData: sql: SELECT total( t0.ZATTACHMENTCOUNT) FROM ZITEM t0
 CoreData: annotation: sql connection fetch time: 0.0001s
 CoreData: annotation: total fetch execution time: 0.0002s for 1 rows.
 1581
 速度快于上面的求和方式
 */

```

因为已经有了预存的 count 值，所以在 NSExpression 中使用的是 sum 方法。

相较于方法九，方法十的查询效率更高。

## 十一、查询分组后的 count 数据

某些场合下，我们需要对数据进行分组，然后获取每组数据的 count。通过设置 propertiesToGroupBy，让 SQLite 为我们完成这个工作。

例如，Item 有一个 birthOfYear 属性，该属性为年份数据（ Int ）。下面的代码，将数据按照 birthOfYear 进行分组，并返回每组的 count 数据：

```swift
let fetchquest = NSFetchRequest<NSFetchRequestResult>(entityName: "Item")
fetchquest.propertiesToGroupBy = ["birthOfYear"]
fetchquest.sortDescriptors = [NSSortDescriptor(keyPath: \Item.birthOfYear, ascending: false)]
fetchquest.resultType = .dictionaryResultType
let expressDescription = NSExpressionDescription()
expressDescription.resultType = .integer32
let name = "count"
expressDescription.name = name
let year = NSExpression(forKeyPath:\Item.birthOfYear)
let express = NSExpression(forFunction: "count:", arguments: [year])
expressDescription.expression = express
fetchquest.propertiesToFetch = ["birthOfYear",expressDescription]
let results = (try? viewContext.fetch(fetchquest) as? [[String:Any]]) ?? []
print(results)
/*
 CoreData: sql: SELECT t0.ZBIRTHOFYEAR, COUNT( t0.ZBIRTHOFYEAR) FROM ZITEM t0 GROUP BY  t0.ZBIRTHOFYEAR
 CoreData: annotation: sql connection fetch time: 0.0002s
 CoreData: annotation: total fetch execution time: 0.0003s for 5 rows.

 [["birthOfYear": 2000, "count": 32], ["birthOfYear": 2001, "count": 36], ["count": 42, "birthOfYear": 2002], ["birthOfYear": 2003, "count": 44], ["birthOfYear": 2004, "count": 36]]
 */

```

由于此实现依赖的是 SQLite 的内部实现，因此将非常高效。

当业务逻辑中有类似的需求时，可以考虑为托管对象预设适合分组的属性。属性的内容也可以通过派生或 willSave 来处理。

## 十二、将分组后的 count 数据用作筛选条件

如果想对方法十一中获取的结果集进行筛选，除了通过代码操作结果数组外，利用 Core Data 对 having 的支持，直接在 SQLite 中进行将更加的高效。下面的代码将只返回 count 大于 40 的结果。

```swift
let fetchquest = NSFetchRequest<NSFetchRequestResult>(entityName: "Item")
fetchquest.propertiesToGroupBy = ["birthOfYear"]
fetchquest.resultType = .dictionaryResultType

let expressDescription = NSExpressionDescription()
expressDescription.resultType = .integer32
let name = "count"
expressDescription.name = name
let year = NSExpression(forKeyPath:\Item.birthOfYear)
let express = NSExpression(forFunction: "count:", arguments: [year])
expressDescription.expression = express

fetchquest.propertiesToFetch = ["birthOfYear",expressDescription]
// 创建变量
let countVariableExpr = NSExpression(forVariable: "count")
// 对 groupby 后的结果再度筛选
fetchquest.havingPredicate = NSPredicate(format: "%@ > 40",countVariableExpr)
let results = (try? viewContext.fetch(fetchquest) as? [[String:Any]]) ?? []
print(results)
/*
 CoreData: sql: SELECT t0.ZBIRTHOFYEAR, COUNT( t0.ZBIRTHOFYEAR) AS __var0 FROM ZITEM t0 GROUP BY  t0.ZBIRTHOFYEAR HAVING __var0 > ?
 CoreData: annotation: sql connection fetch time: 0.0002s
 CoreData: annotation: total fetch execution time: 0.0002s for 2 rows.
 [["birthOfYear": 2002, "count": 42], ["birthOfYear": 2003, "count": 44]]
 */
```

由于结果集中的 count 并非托管对象的属性，无法直接将其使用在 NSPredicate 中。通过 `NSExpression(forVariable: "count")` 可解决该问题。

直接在 SQLite 中处理，效率将高于在代码中对方法十一的结果集数组进行操作。

## 总结

本文介绍的方法，无所谓孰优孰劣，每种方法都有其适合的场景。掌握更多的基础知识、通盘考量，方可实现高效的解决方案。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。

