---
date: 2021-02-01 16:20
description: 拥用强大的主题系统是一个静态网站生成器能否成功的重要原因之一。Publish 采用 Plot 作为主题的开发工具，让开发者在高效编写主题的同时享受到了 Swift 的类型安全的优势。本文将从 Plot 开始介绍，让读者最终学会如何创建 Publish 主题。
tags: Swift,Publish,Plot
title: 用 Publish 创建博客（二）——主题开发
---
拥用强大的主题系统是一个静态网站生成器能否成功的重要原因之一。[Publish](https://github.com/JohnSundell/Publish) 采用 [Plot](https://github.com/JohnSundell/Plot) 作为主题的开发工具，让开发者在高效编写主题的同时享受到了 Swift 的类型安全的优势。本文将从 Plot 开始介绍，让读者最终学会如何创建 Publish 主题。

```responser
id:1
```

## Plot ##

### 简介 ###

想要开发 Publish 的`Theme`主题，就不能不从 Plot 说起。

在 Swift 社区中，有不少优秀的项目致力于使用 Swift 生成 HTML：比如 Vapor 的 [Leaf](https://github.com/vapor/leaf)，Point-Free 的 [swift-html](https://github.com/pointfreeco/swift-html) 等，Plot 也是其中的一员。Plot 最初是由 [John Sundell](https://swiftbysundell.com) 编写的并作为 Publish 套件的一部分，它主要的关注点是 Swift 的静态网站 HTML 生成，以及创建建站所需的其他格式文档，包括`RSS`、`podcast`、`Sitemap`。它与 Publish 紧密集成但同时也作为一个独立项目存在。

Plot 使用了一种被称作`Phantom Types`的技术，该技术将类型用作编译器的“标记”，从而能够通过泛型约束来强制类型安全。Plot 使用了非常轻量级的 API 设计，最大限度的减少外部参数标签，从而减少渲染文档所需的语法量，使其呈现了具有“类似 DSL”的代码表现。

### 使用 ###

#### 基础 ####

* Node

  是任何 Plot 文档中所有元素和属性的核心构件。它可以表示元素和属性，以及文本内容和节点组。每个节点都被绑定到一个 Context 类型，它决定了它可以访问哪种 DSL API（例如`HTML.BodyContext`用于放置在 HTML 页面`<body>`中的节点）。

* Element
代表一个元素，可以使用两个独立的标签打开和关闭（比如`<body></body>`），也可以自闭（比如`<img/>`）。当使用 Plot 时，你通常不需要与这个类型进行交互，基础 Node 中会创建它的实例。
  
* Attribute

  表示附加在元素上的属性，例如` <a> `元素的 href，或者`<img>` 元素的 src。你可以通过它的初始化器来构造`Attribute`值，也可以通过 DSL，使用`.attribute()`命令来构造。
  
* Document 和 DocumentFormat
  
  给定格式的文档，如 HTML、RSS 和 PodcastFeed。这些都是最高级别的类型，你可以使用 Plot 的 DSL 来开始一个文档构建会话。

#### 类 DSL 语法 ####

```swift
import Plot

let html = HTML(
    .head(
        .title("My website"),
        .stylesheet("styles.css")
    ),
    .body(
        .div(
            .h1("My website"),
            .p("Writing HTML in Swift is pretty great!")
        )
    )
)
```

上面的 Swift 代码将生成下面的 HTML 代码。代码形式同 DSL 非常类似，代码污染极少。

```html
<!DOCTYPE html>
<html>
    <head>
        <title>My website</title>
        <meta name="twitter:title" content="My website"/>
        <meta name="og:title" content="My website"/>
        <link rel="stylesheet" href="styles.css" type="text/css"/>
    </head>
    <body>
        <div>
            <h1>My website</h1>
            <p>Writing HTML in Swift is pretty great!</p>
        </div>
    </body>
</html>
```

有些时候，感觉上 Plot 只是将每个函数直接映射到一个等效的 HTML 元素上——至少上面的代码看起来如此，但其实 Plot 还会自动插入许多非常有价值的元数据，在后面我们还将看到 Plot 更多的功能。

#### 属性 ####

属性的应用方式也可以和添加子元素的方式完全一样，只需在元素的逗号分隔的内容列表中添加另一个条目即可。例如，下面是如何定义一个同时具有 CSS 类和 URL 的锚元素。属性、元素和内联文本都是以同样的方式定义的，这不仅使 Plot 的 API 更容易学习，也让输入体验非常流畅--因为你可以在任何上下文中简单地键入`.`来不断定义新的属性和元素。

```swift
let html = HTML(
    .body(
        .a(.class("link"), .href("https://github.com"), "GitHub")
    )
)
```

#### 类型安全 ####

Plot 大量使用了 Swift 的高级泛型能力，不仅使采用原生代码编写 HTML 和 XML 成为可能，并在这一过程中实现了完全的类型安全。Plot 的所有元素和属性都是作为上下文绑定的节点来实现的，这既能强制执行有效的 HTML 语义，也能让 Xcode 和其他 IDE 在使用 Plot 的 DSL 编写代码时提供丰富的自动补全信息。

```swift
let html = HTML(.body(
    .p(.href("https://github.com"))
))
```

比如，`<herf>`是不能直接被放置在`<p>`中的，当输入`.p`的时候自动补全是不会提示的（因为上下文不匹配），代码也将在编译时报错。

这种高度的类型安全既带来了非常愉快的开发体验，也使利用 Plot 创建的 HTML 和 XML 文档在语义上正确的几率大大增加--尤其是与使用原始字符串编写文档和标记相比。

对于笔者这种 HTML 知识极度匮乏的人来说，在 Plot 下我也没有办法写出下面的错误代码（无法通过）。

```swift
let html = HTML(.body)
    .ul(.p("Not allowed"))
))
```

#### 自定义组件 ####

同样的，上下文绑定的 Node 架构不仅赋予了 Plot 高度的类型安全，也使得可以定义更多更高层次的组件，然后将这些自定义组件与 Plot 本身定义的元素灵活地混合使用。

例如，我们要为网站添加一个 advertising 组件，该组件绑定在 HTML 文档的`<body>`上下文中。

```swift
extension Node where Context: HTML.BodyContext { //严格的上下文绑定
    static func advertising(_ slogan: String,herf:String) -> Self {
        .div(
            .class("avertising"),
            .a(
                .href(herf),
                .text(slogan)
            )
        )
    }
}
```

现在可以使用与内置元素完全相同的语法来使用`advertising`。

```swift
let html = HTML(
    .body(
        .div(
            .class("wrapper"),
            .article(
               .... 
            ),
            .advertising("肘子的 Swift 记事本", herf: "https://fatbobman.com")
        )
    ))
```

#### 控制流程 ####

尽管 Plot 专注于静态站点生成，但它还是附带了几种控制流机制，可让您使用其 DSL 的内联逻辑。 目前支持的控制命令有 `.if( )`，`.if(_,else:)`，`unwrap()`以及`forEach()`。

```swift
var books:[Book] = getbooks()
let show:Bool = true
let html = HTML(.body(
    .h2("Books"),
    .if(show,
    .ul(.forEach(books) { book in
        .li(.class("book-title"), .text(book.title))
    })
    ,else:
        .text("请添加书库")
    )
))
```

使用上述控制流机制，尤其是与自定义组件结合使用时，可以使你以类型安全的方式构建真正灵活的主题，创建所需的文档和 HTML 页面。

#### 自定义元素和属性 ####

尽管 Plot 旨在涵盖与其支持的文档格式相关的尽可能多的标准，但你仍可能会遇到 Plot 尚不具备的某种形式的元素或属性 。我们可以非常容易的在 Plot 中自定义元素和属性，这一点在生成 XML 的时候尤为有用。

```swift
extension Node where Context == XML.ProductContext {
    static func name(_ name: String) -> Self {
        .element(named: "name", text: name)
    }

    static func isAvailable(_ bool: Bool) -> Self {
        .attribute(named: "available", value: String(bool))
    }
}
```

#### 文档渲染 ####

```swift
let header = Node.header(
    .h1("Title"),
    .span("Description")
)

let string = header.render()
```

还可以对输出缩排进行控制

```swift
html.render(indentedBy: .tabs(4))
```

#### 其他支持 ####

Plot 还支持生成 RSS feeds，podcasting，site maps 等。Publish 中对应的部分同样由 Plot 实现。

## Publish 主题 ##

阅读下面内容前，最好已阅读 [用 Publish 创建博客（一）——入门](/posts/publish-1/)，。

文中提到范例模板可以在 [GIthub](https://github.com/fatbobman/PublishThemeForFatbobmanBlog) 处下载。

### 自定义主题 ###

在 Publish 中，主题需要遵循`HTMLFactory`协议。如下代码可以定义一个新主题：

```swift
import Foundation
import Plot
import Publish

extension Theme { 
    public static var myTheme: Self {
        Theme(
            htmlFactory: MyThemeHTMLFactory<MyWebsite>(),
            resourcePaths: ["Resources/MyTheme/styles.css"]
        )
    }
}

private struct MyThemeHTMLFactory<Site: Website>: HTMLFactory {
        // ... 具体的页面，需实现六个方法
}

private extension Node where Context == HTML.BodyContext {
        // Node 的定义，比如 header，footer 等
}
```

在 pipeline 中使用如下代码指定主题

```swift
.generateHTML(withTheme:.myTheme ), //使用自定义主题      
```

HTMLFactory 协议要求我们必须全部实现六个方法，对应着六种页面，分别是：

* `makeIndexHTML(for index: Index,context: PublishingContext<Site>)`

  网站首页，通常是最近文章、热点推荐等等，默认主题中是显式全部`Item`列表

* `makeSectionHTML(for section: Section<Site>,context: PublishingContext<Site>)`

  当`Section`作为`Item`容器时的页面。通常显示隶属于该`Section`的`Item`列表

* `makeItemHTML(for item: Item<Site>, context: PublishingContext<Site>)`

  单篇文章（`Item`）的显示页面

* `makePageHTML(for page: Page,context: PublishingContext<Site>)`

  自由文章（`Page`）的显示页面，当 Section 不作为容器时，它的 index.md 也是作为`Page`渲染的

* `makeTagListHTML(for page: TagListPage,context: PublishingContext<Site>)`

  `Tag`列表的页面。通常会在此显示站点文章中出现过的全部`Tag`

* `makeTagDetailsHTML(for page: TagDetailsPage,context: PublishingContext<Site>)`

  通常为拥有该`Tag`的`Item`列表

我们在 MyThemeHTMLFactory 每个方法中，按照上文介绍的 Plot 表述方式进行编写即可。比如：

```swift
func makePageHTML(for page: Page,
                 context: PublishingContext<Site>) throws -> HTML {
    HTML(
        .lang(context.site.language),
        .head(for: page, on: context.site),
        .body(
            .header(for: context, selectedSection: nil), 
            .wrapper(.contentBody(page.body)),
            .footer(for: context.site)
            )
        )
    }
```

`header`、`wrapper`、`footer`都是自定义的`Node`

### 生成机制 ###

Publish 采用工作流机制，通过 [范例代码](https://github.com/fatbobman/PublishThemeForFatbobmanBlog) 来了解一下数据是如何在`Pipeline`中操作的。

```swift
try FatbobmanBlog().publish(
    using: [
        .installPlugin(.highlightJS()), //添加语法高亮插件。此插件在 markdown 解析时被调用
        .copyResources(), //拷贝网站所需资源，Resource 目录下的文件
        .addMarkdownFiles(), 
        /*逐个读取 Content 下的 markdown 文件，对 markdown 文件进行解析，
        1：解析 metadata，将元数据保存在对应的 Item
        2：对文章中的 markdown 语段逐个解析并转换成 HTML 数据
        3：当碰到 highlightJS 要求处理的 (codeBlocks) 文字块时调用该插件
        4：所有的处理好的内容保存到 PublishingContext 中
        */
        .setSctionTitle(), //修改 section 的显示标题
        .installPlugin(.setDateFormatter()), //为 HTML 输出设置时间显示格式
        .installPlugin(.countTag()), //通过注入，为 tag 增加 tagCount 属性，计算每个 tag 下有几篇文章
        .installPlugin(.colorfulTags(defaultClass: "tag", variantPrefix: "variant", numberOfVariants: 8)), //通过注入，为每 tag 增加 colorfiedClass 属性，返回 css 文件中对应的色彩定义
        .sortItems(by: \.date, order: .descending), //所有文章降序
        .generateHTML(withTheme: .fatTheme), //指定自定义的主题，并在 Output 目录中生成 HTML 文件
        /*
        使用主题模板，逐个调用页面生成方法。
        根据每个方法要求的参数不同，传递对应的 PublishingContext，Item，Scetion 等
        主题方法根据数据，使用 Plot 渲染成 HTML
        比如 makePageHTML 中，显示 page 文章的内容便是通过 page.body 来获取的
        */
        .generateRSSFeed(
            including: [.posts,.project],
            itemPredicate: nil
        ), //使用 Plot 生成 RSS
        .generateSiteMap(), //使用 Plot 生成 Sitemap
    ]
)
```

从上面的代码可以看出，使用主题模板生成 HTML 并保存是在整个 Pipeline 的末段，通常情况下，当主题方法调用给定的数据时，数据已经是准备好的。不过由于 Publish 的主题并非描述文件而是标准的程序代码，我们仍可以在最终`render`前，对数据再处理。

尽管 Publish 目前提供的页面种类并不多，但即使我们仅使用上述的种类仍可对不同的内容作出完全不同渲染结果。比如：

```swift
func makeSectionHTML(for section: Section<Site>,
                         context: PublishingContext<Site>) throws -> HTML {
    //如果 section 是 posts，则显示完全不同的页面
    if section.id as! Myblog.SectionID == .posts {
            return HTML(
                postSectionList(for section: Section<Site>,
                context: PublishingContext<Site>)
            )
    }
    else {
           return HTML(
                otherSctionList(for section: Section<Site>,
                context: PublishingContext<Site>)
            )
       }
   }
```

也可以使用 Plot 提供的控制命令来完成，下面的代码和上面是等效的

```swift
func makeSectionHTML(for section: Section<Site>,
                         context: PublishingContext<Site>) throws -> HTML {
      HTML(
        .if(section.id as! Myblog.SectionID  == .posts,
              postSectionList(for section: Section<Site>,
                context: PublishingContext<Site>)
            ,
            else:
              otherSctionList(for section: Section<Site>,
                context: PublishingContext<Site>)
           )
        )
    }
```

总之在 Publish 中用着写普通程序的思路来处理网页即可，**主题不仅仅是描述文件**。

### 和 CSS 的配合 ###

主题代码定义了对应页面的基本布局和逻辑，更具体的布局、尺寸、色彩、效果等都要在`CSS`文件中进行设定。`CSS`文件在定义主题时指定（可以有多个）。

如果你是一个有经验的 CSS 使用者，通常没有什么难度。但笔者几乎完全不会使用 CSS，在此次用 Publish 重建 Blog 的过程中，在 CSS 上花费的时间最长、精力最多。

> 请帮忙推荐一个能够整理 css 的工具或者 vscode 插件，由于我在 css 上没有经验所以代码写的很乱，是否有可能将同一层级或类似的 tag class 自动调整到一起，便于查找。

### 实战 ###

接下来通过修改两个主题方法来体验一下的开发过程。

#### 准备工作 ####

一开始完全重建所有的主题代码是不太现实的，所以我推荐先从 Publish 自带的默认主题`foundation`入手。

完成 [Publish 创建博客（一）——入门](/posts/publish-1/) 中的安装工作

修改`main.swift`

```swift
enum SectionID: String, WebsiteSectionID {
        // Add the sections that you want your website to contain here:
        case posts
        case about //添加一项，为了演示上方导航条
    }
```

```bash
$http://cdn myblog
$publish run
```

访问`http://localhost:8000`，页面差不多这样

![publis-2-defaultIndex](https://cdn.fatbobman.com/publis-2-defaultIndex.png)

在`Resource`目录中创建`MyTheme`目录。在 XCode 中将 Publish 库中的两个文件`styles.css`、`Theme+Foundation.swift`拷贝到 `MyTheme`目录，也可以在 MyTheme 目录中新创建文件后粘贴代码。

```
Publish--Resources--FoundatioinTheme-- styles.css
```

```bash
Publish--Sources--Publish--API-- Theme+Foundation.swift
```

将 `Theme+Foundation.swift` 改名为 `MyTheme.swift`, 并编辑内容

将：

```swift
private struct FoundationHTMLFactory<Site: Website>: HTMLFactory {
```

改成：

```swift
private struct MyThemeHTMLFactory<Site: Website>: HTMLFactory {
```

将
```swift
 static var foundation: Self {  
        Theme(
            htmlFactory: FoundationHTMLFactory(),
            resourcePaths: ["Resources/FoundationTheme/styles.css"]
        )
 }
```

改为

```swift
static var myTheme: Self {  
        Theme(
            htmlFactory: MyThemeHTMLFactory(),
            resourcePaths: ["Resources/MyTheme/styles.css"]
        )
}
```

在`main.swift`中

将

```swift
try Myblog().publish(withTheme: .foundation)
```

改为

```swift
try Myblog().publish(withTheme: .myTheme)
```

随便在 `Content`的`posts`目录下创建几个`.md`文件。比如

```markdown
---
date: 2021-01-30 19:58
description: 第二篇
tags: second, article
title: My second post
---

hello world
...
```

至此准备完毕，页面看起来差不多是这个样子，创建当前显示页面的是`makeIndexHTML`方法。

![publish-2-defaultindex2](https://cdn.fatbobman.com/publish-2-defaultindex2.png)

#### 例子 1：在 makeIndexHTML 中改变 Item Row 的显示内容 ####

当前的 makeIndexHTML 的代码如下：

```swift
func makeIndexHTML(for index: Index,
                       context: PublishingContext<Site>) throws -> HTML {
        HTML(
            .lang(context.site.language),  //<html lang="en"> language 可以在 main.swift 中修改
            .head(for: index, on: context.site), //<head>内容，title 及 meta
            .body(
                .header(for: context, selectedSection: nil), //上部网站名称 Site.name 及 nav 导航 SectionID
                .wrapper(
                    .h1(.text(index.title)), // Welcome to MyBlog! 对应 Content--index.md 的 title
                    .p(
                        .class("description"),  //在 styels.css 对应 .description
                        .text(context.site.description) //对应 main.swift 中的 Site.description
                    ),
                    .h2("Latest content"),
                    .itemList(  //自定义 Node，显示 Item 列表，目前 makeIndex makeSection makeTagList 都使用这一个
                        for: context.allItems(
                            sortedBy: \.date, //按创建时间降序，根据 metatdata date
                            order: .descending
                        ),
                        on: context.site
                    )
                ),
                .footer(for: context.site) //自定义 Node，显示下部版权信息
            )
        )
    }
```

在`makeIndexHTML`中做如下修改

```swift
.itemList(
```

改为

```swift
.indexItemList(
```

在后添加`.h2("Latesht content")`，变成如下代码

```swift
       .h2("Latesht content"),
       .unwrap(context.sections.first{ $0.id as! Myblog.SectionID == .posts}){ posts in
              .a(
                  .href(posts.path),
                  .text("显示全部文章")
                 )
              },
```

在 `extension Node where Context == HTML.BodyContext`中进行添加：

```swift
    static func indexItemList<T: Website>(for items: [Item<T>], on site: T) -> Node {
        let limit:Int = 2 //设置 index 页面最多显示的 Item 条目数
        let items = items[0...min((limit - 1),items.count)]
        return .ul(
            .class("item-list"),
            .forEach(items) { item in
                .li(.article(
                    .h1(.a(
                        .href(item.path),
                        .text(item.title)
                    )),
                    .tagList(for: item, on: site),
                    .p(.text(item.description)),
                    .p(item.content.body.node) //添加显示 Item 全文 
                ))
            }
        )
    }
```

现在 Index 变成如下状态：

![image-20210201135111053](https://cdn.fatbobman.com/publish-2-index-finish.png)

#### 例子 2：为 makeItemHTML 添加临近文章的导航 ####

本例，我们将在 makeItemHTML 上添加文章导航功能，类似效果如下：

![image-20210201105104706](https://cdn.fatbobman.com/publish-2-item-navigatore-demo.png)

点击进入任意 Item（文章）

```swift
    func makeItemHTML(for item: Item<Site>,
                      context: PublishingContext<Site>) throws -> HTML {
        HTML(
            .lang(context.site.language),
            .head(for: item, on: context.site),
            .body(
                .class("item-page"),
                .header(for: context, selectedSection: item.sectionID),
                .wrapper(
                    .article( //<article>标签
                        .div(
                            .class("content"), //css .content
                            .contentBody(item.body) //.raw(body.html) 显示 item.body.html 文章正文
                        ),
                        .span("Tagged with: "), 
                        .tagList(for: item, on: context.site) //下方 tag 列表，forEach(item.tags) 
                    )
                ),
                .footer(for: context.site)
            )
        )
    }
```

在代码`HTML(`前添加如下内容：

```swift
        var previous:Item<Site>? = nil //前一篇 Item
        var next:Item<Site>? = nil //下一篇 Item

        let items = context.allItems(sortedBy: \.date,order: .descending) //获取全部 Item
        /*
        我们当前是获取全部的 Item，可以在获取时对范围进行限定，比如：
        let items = context.allItems(sortedBy: \.date,order: .descending)
                           .filter{$0.tags.contains(Tag("article"))}
        */
        //当前 Item 的 index
        guard let index = items.firstIndex(where: {$0 == item}) else {
            return HTML()
        }

        if index > 0 {
            previous = items[index - 1]
        }

        if index < (items.count - 1) {
            next = items[index + 1]
        }

        return HTML( 
          ....
```

在`.footer`前添加

```swift
.itemNavigator(previousItem:previous,nextItem:next),
.footer(for: context.site)
```

在`extension Node where Context == HTML.BodyContext`中添加自定义 Node`itemNavigator`

```swift
   static func itemNavigator<Site: Website>(previousItem: Item<Site>?, nextItem: Item<Site>?) -> Node{
        return
            .div(
                .class("item-navigator"),
                .table(
                    .tr(
                        .td(
                            .unwrap(previousItem){ item in
                                .a(
                                    .href(item.path),
                                    .text(item.title)
                                )
                            }
                        ),
                        .td(
                            .unwrap(nextItem){ item in
                                .a(
                                    .href(item.path),
                                    .text(item.title)
                                )
                            }
                        )
                    )
                )
            )
    }
```

在`styles.css`中添加

```css
.item-navigator table{
    width:100%;
}

.item-navigator td{
    width:50%;
}
```

以上代码仅作为概念演示。结果如下：

![publish-2-makeitem-with-navigator](https://cdn.fatbobman.com/publish-2-makeitem-with-navigator.png)

## 总结 ##

如果你有 SwiftUI 的开发经验，你会发现使用方式非常相似。在 Publish 主题中，你有充足的手段来组织、处理数据，并布局视图（把`Node`当做`View`）。

Publish 的`FoundationHTMLFactory`目前仅定义了六个页面种类，如果想增加新的种类目前有两种方法：

1. Fork Publish，直接扩展它的代码

   这种方式最彻底，但维护起来比较麻烦。

2. 在 Pipeline 执行过`.generateHTML`后，再执行自定义的 generate Step

   无需改动核心代码。
   可能会有冗余动作，并且需要在`FoundationHTMLFactory`内置方法中做一点处理以便和我们新定义的页面做连接。比如，目前`index`，`section list`都不支持分页（只会输出一个 HTML 文件），我们可以在内置的`makeIndex`之后，再重新生成一组分页的`index`，并覆盖掉原来的。

在本篇中，我们介绍了如何使用 [Plot](https://github.com/JohnSundell/Plot)，以及如何在 [Publish](https://github.com/JohnSundell/Publish) 中定制自己的主题。在下一篇文章中，我们要探讨如何在不改动 Publish 核心代码的情况下，增加各种功能的手段（不仅仅是 Plugin）。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。
