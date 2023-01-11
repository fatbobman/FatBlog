/**
 *  Publish
 *  Copyright (c) John Sundell 2019
 *  MIT license, see LICENSE file for details
 */

import Foundation
import Plot
import Publish

public extension Theme {
    /// The default "Foundation" theme that Publish ships with, a very
    /// basic theme mostly implemented for demonstration purposes.
    static var fatTheme: Self {
        Theme(htmlFactory: FatThemeHTMLFactory(), resourcePaths: ["Resources/FatTheme/styles.css"])
    }
}

// MARK: - FatThemeHTMLFactory

private struct FatThemeHTMLFactory<Site: Website>: HTMLFactory {
    // 首页
    func makeIndexHTML(for index: Index, context: PublishingContext<Site>) throws -> HTML {
        HTML(
            .lang(context.site.language),
            .customHeader(for: index, on: context.site),
            .body(
                .class("index"),
                .header(
                    for: context,
                    selectedSection: FatbobmanBlog.SectionID.index as? Site.SectionID
                ),
                .container(
                    .wrapper(
                        .viewContainer(
                            .leftContext(
                                .itemList(for: context.allItems(sortedBy: \.date, order: .descending), on: context.site, limit: 10),
                                .sectionHeader(context: context, showTitle: false)
                            ),
                            .sideNav(
                                .div(
                                    .class("sideTags"),
                                    .ul(
                                        .class("all-tags"),
                                        .forEach(context.allTags.sorted()) { tag in
                                            .li(
                                                .class(tag.colorfiedClass),
                                                .a(
                                                    .href(context.site.path(for: tag)),
                                                    .text("\(tag.string) (\(tag.count))")
                                                )
                                            )
                                        }
                                    )
                                )
                            )
                        )
                    )
                ),
                .footer(for: context.site)
            )
        )
    }

    // 全部文章列表
    func makeSectionHTML(
        for section: Section<Site>,
        context: PublishingContext<Site>
    ) throws -> HTML {
        HTML(
            .lang(context.site.language),
            .customHeader(for: section, on: context.site),
            .body(
                .header(for: context, selectedSection: section.id),
                .container(
                    .wrapper(
                        .viewContainer(
                            .leftContext(
                                //                                .itemList(for: section.items, on: context.site)
                                .archiveView(context: context)
                            ),
                            .sideNav(
                                .div(
                                    .class("sideTags"),
                                    .ul(
                                        .class("all-tags"),
                                        .forEach(context.allTags.sorted()) { tag in
                                            .li(
                                                .class(tag.colorfiedClass),
                                                .a(
                                                    .href(context.site.path(for: tag)),
                                                    .text("\(tag.string) (\(tag.count))")
                                                )
                                            )
                                        }
                                    )
                                )
                            )
                        )
                    )
//                    ,
//                    .itemListSpacer()
                ),
                .footer(for: context.site)
            )
        )
    }

    // 文章页面
    func makeItemHTML(for item: Item<Site>, context: PublishingContext<Site>) throws -> HTML {
        var previous: Item<Site>?
        var next: Item<Site>?

        let items = context.allItems(sortedBy: \.date, order: .descending)
        guard let index = items.firstIndex(where: { $0 == item }) else { return HTML() }

        if index > 0 { previous = items[index - 1] }

        if index < (items.count - 1) { next = items[index + 1] }

        return HTML(
            .lang(context.site.language),
            .customHeader(for: item, on: context.site),
            .body(
                .class("item-page"),
                .header(for: context, selectedSection: item.sectionID),
                .container(
                    .wrapper(
                        .viewContainer(
                            .leftContext(
                                .shareContainer(title: item.title, url: context.site.url.appendingPathComponent(item.path.string).absoluteString),
                                .article(
                                    .div(
                                        .class("post-title"),
                                        .h1(
                                            .text(item.title)
                                        )
                                    ),
                                    .div(
                                        .tagList(for: item, on: context.site, displayDate: true),
                                        .div(.class("content"), .contentBody(item.body)),
                                        .license()
                                    )
                                ),
                                // .shareContainerForMobile(title: item.title, url: context.site.url.appendingPathComponent(item.path.string).absoluteString),
//                                .support(),
                                .itemNavigator(previousItem: previous, nextItem: next),
                                .gitTalk(topicID: item.title)
                            ),
                            .sideNav(
                                .toc()
                            ),
                            // 必须在 文档加载后，才能调用script
                            .tocScript()
                        )
                    ),
                    .footer(for: context.site)
                )
            )
        )
    }

    // Pages,不属于Section
    func makePageHTML(for page: Page, context: PublishingContext<Site>) throws -> HTML {
        return HTML(
            .lang(context.site.language),
            .customHeader(for: page, on: context.site),
            .body(
                // 需要特殊处理.在publish中是当做page来显示的.为了nav的选中显示正常
                .if(
                    page.path == Path("about"),
                    .header(
                        for: context,
                        selectedSection: FatbobmanBlog.SectionID.about as? Site.SectionID
                    ),
                    else:
                    .if(
                        page.path == Path("tips"),
                        .header(
                            for: context,
                            selectedSection: FatbobmanBlog.SectionID.tips as? Site.SectionID
                        ),
                       else:
                       .header(
                        for: context,
                        selectedSection: nil
                    )
                    )
                    
                ),
                .container(
                    .wrapper(
                        .div(.class("about"),
                             .article(
                                 //                                .div(
//                                    .class("post-title"),
//                                    .h1(
//                                       .text(page.title)
//                                    )
//                                ),
                                 .div(
                                     .class("content"),
                                     .contentBody(page.body)
                                 )
                             ))
                    )
                ),
                .footer(for: context.site)
            )
        )
    }

    // Tag列表
    func makeTagListHTML(for page: TagListPage, context: PublishingContext<Site>) throws -> HTML? {
        return HTML(
            .lang(context.site.language),
//            .searchHead(for: page, on: context.site),
            .customHeader(for: page, on: context.site),
            .body(
                .header(for: context, selectedSection: FatbobmanBlog.SectionID.tags as? Site.SectionID),
                .container(
                    .wrapper(
                        .div(
                            .class("searchContent"),
                            .searchInput(),
                            .ul(
                                .class("all-tags"),
                                .forEach(page.tags.sorted()) { tag in
                                    .li(
                                        .class(tag.colorfiedClass),
                                        .a(
                                            .href(context.site.path(for: tag)),
                                            .text("\(tag.string) (\(tag.count))")
                                        )
                                    )
                                }
                            ),
                            .searchResult()
                        ) // ,
                        // .spacer()
                    )
                ),
                .footer(for: context.site)
            )
        )
    }

    func makeTagDetailsHTML(
        for page: TagDetailsPage,
        context: PublishingContext<Site>
    ) throws -> HTML? {
        HTML(
            .lang(context.site.language),
            .customHeader(for: page, on: context.site),
            .body(
                .header(for: context, selectedSection: FatbobmanBlog.SectionID.tags as? Site.SectionID),
                .container(
                    .wrapper(
                        .div(
                            .class("tagResultContent"),
                            .ul(
                                .class("all-tags"),
                                .forEach(context.allTags.sorted()) { tag in
                                    .li(
                                        .class(((tag == page.tag) ? "selectedTag " : "") + tag.colorfiedClass),
                                        .a(
                                            .href(context.site.path(for: tag)),
                                            .text("\(tag.string) (\(tag.count))")
                                        )
                                    )
                                }
                            )
                        ),
                        .div(
                            .class("tagResult"),
                            .itemList(
                                for: context.items(
                                    taggedWith: page.tag,
                                    sortedBy: \.date,
                                    order: .descending
                                ),
                                on: context.site
                            )
                        )
                    ),
                    .tagDetailSpacer()
                ),
                .footer(for: context.site)
            )
        )
    }
}

extension Node where Context == HTML.BodyContext {
    fileprivate static func wrapper(_ nodes: Node...) -> Node {
        .div(.class("wrapper"), .group(nodes))
    }

    // 页面头部.
    fileprivate static func header<T: Website>(
        for context: PublishingContext<T>,
        selectedSection: T.SectionID?
    ) -> Node {
        let sectionIDs = T.SectionID.allCases
        return .header(
            .wrapper(
                // .div(.class("logo"), .a(.href("/"), .h2("肘子的SWIFT记事本"))),
                .div(.class("logo"), .a(.href("/"), .img(.src("/images/title_version2.svg")))),
                .headerIcons(),
                .if(sectionIDs.count > 1, nav(for: context, selectedSection: selectedSection))
            )
        )
    }

    fileprivate static func nav<T: Website>(
        for context: PublishingContext<T>,
        selectedSection: T.SectionID?
    ) -> Node {
        let sectionIDs = T.SectionID.allCases
        return .nav(
            .ul(
                .forEach(sectionIDs) { section in
                    .li(
                        .a(
                            .if(
                                section as! FatbobmanBlog.SectionID
                                    == FatbobmanBlog.SectionID.about,
                                .class("selected")
                            ),
                            .if(
                                section as! FatbobmanBlog.SectionID
                                    == FatbobmanBlog.SectionID.tips,
                                .class("selected")
                            ),
                            .class(section == selectedSection ? "selected" : ""),
                            .if(
                                section as! FatbobmanBlog.SectionID
                                    == FatbobmanBlog.SectionID.index,
                                .href(context.index.path),
                                else:
                                .href(context.sections[section].path)
                                // .if(
                                //     section as! FatbobmanBlog.SectionID == FatbobmanBlog.SectionID.healthNotes,
                                //     .href("https://www.fatbobman.com/tips"),
                                //     else: .href(context.sections[section].path)
                                // )
                            ),
                            .text(context.sections[section].title)
                        )
                    )
                }
            ),
            .div(
                .class("weixinHeadQcode"),
                .onclick(
                    """
                    $('.weixinHeadQcode').css('display','none');
                    """
                )
            )
        )
    }

    fileprivate static func itemList<T: Website>(for items: [Item<T>], on site: T, limit: Int = .max) -> Node {
        return .ul(
            .class("item-list"),
            .forEach(items.prefix(limit)) { item in
                .li(
                    .article(
                        .h1(.class("itme-list-title"), .a(.href(item.path), .text(item.title))),
                        .tagList(for: item, on: site, displayDate: true),
                        .p(.text(item.description))
                    )
                )
            }
        )
    }

    static func tagList<T: Website>(
        for item: Item<T>,
        on site: T,
        displayDate: Bool = false
    ) -> Node {
        return .ul(
            .class("tag-list"),
            .forEach(item.tags) { tag in
                .li(.class(tag.colorfiedClass), .a(.href(site.path(for: tag)), .text(tag.string)))
            },
            .li(.class("tag tagdate"), .if(displayDate, .text(formatter.string(from: item.date))))
        )
    }

    static func tagAndDate(tags: Node, date: Date) -> Node {
        return .div(
            .class("publishDate"),
            .table(.tr(.td(tags), .td(.text(formatter.string(from: date)))))
        )
    }

    static func toc() -> Node {
        .group(
            .div(
                .class("sidebar")
            )
        )
    }

    static func tocScript() -> Node {
        .raw("""
                <script src="/images/toc.js"></script>
            """
        )
    }

    // static func toc(_ nodes: Node<HTML.BodyContext>...) -> Node {
    //     .element(named: "sidebar", nodes: nodes)
    // }

    static func container(_ nodes: Node...) -> Node {
        .div(
            .class("container"),
            .group(nodes)
        )
    }

    static func sideNav(_ nodes: Node...) -> Node {
        .div(
            .class("side-nav"),
            .group(nodes)
        )
    }

    static func leftContext(_ nodes: Node...) -> Node {
        .div(
            .class("leftContent"),
            .group(nodes)
        )
    }

    /*
     <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/gitalk@1/dist/gitalk.css">
     */
    static func gitTalk(topicID: String) -> Node {
        .raw("""
        <div id="gitalk-container"></div>
        <link rel="stylesheet" href="https://cdn.fatbobman.com/gitalk_new.css">
        <script src="https://cdn.jsdelivr.net/npm/gitalk@1/dist/gitalk.min.js"></script>
        <script type="text/javascript">
        var gitalk = new Gitalk({
        clientID: 'fcf61195c7f73253dc8b',
        clientSecret: '0ac2907be08248a1fcb5312e27480ad535c682e5',
        repo: 'blogComments',
        owner: 'fatbobman',
        admin: ['fatbobman'],
        id: '\(topicID)'.split("/").pop().substring(0, 49),      // Ensure uniqueness and length less than 50
        distractionFreeMode: true,  // Facebook-like distraction free mode
        createIssueManually: true,
        language: 'zh-CN'
        });

        gitalk.render('gitalk-container');

        </script>
        """)
    }

    fileprivate static func footer<T: Website>(for _: T) -> Node {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return .footer(
            .convertKit(),
            // .substack(),
            .p(
                .text("Copyright &copy; 东坡肘子 (Fatbobman) \(formatter.string(from: Date())) "),
                .a(.text("辽ICP备20006550"), .href("http://beian.miit.gov.cn"))
            ),
            .p(
                .text("Generated using "),
                .a(.text("Publish"), .href("https://github.com/johnsundell/publish"),
                   .target(.blank))
            ),
            .ul(
                .class("icon"),
                .li(
                    .a(
                        //                    .text("Twitter"),
                        .img(.class("twitter"), .src("/images/twitter.svg")),
                        .href("https://twitter.com/fatbobman"),
                        .target(.blank)
                    )
                ),
                .li(
                    .a(
                        // .text("Github"),
                        .img(.src("/images/github.svg")),
                        .href("https://github.com/fatbobman/"),
                        .target(.blank)
                    )
                ),
                .li(
                    .a(
                        //                        .text("知乎"),
                        .img(.src("/images/zhihu.svg")),
                        .href("https://www.zhihu.com/people/fatbobman3000"),
                        .target(.blank)
                    )
                ),
                .li(
                    .a(
                        //                    .text("RSS"),
                        .img(.src("/images/rss.svg")),
                        .href("/feed.rss")
                    )
                )

            ),
            .raw(googleAndBaidu)
        )
    }
}

let googleAndBaidu = """
<script>
    // dynamic User by Hux
    var _gaId = 'UA-165296388-1';
    var _gaDomain = 'fatbobman.com';

    // Originial
    (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
    (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
    m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
    })(window,document,'script','//www.google-analytics.com/analytics.js','ga');

    ga('create', _gaId, _gaDomain);
    ga('send', 'pageview');
</script>
"""

var formatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "发布于yyyy年MM月dd日"
    return formatter
}

/*
 <!-- Baidu Tongji -->

 <script>
     // dynamic User by Hux
     var _baId = '14e5d60a3ea6276655f9d14c58b1fcd0';

     // Originial
     var _hmt = _hmt || [];
     (function() {
       var hm = document.createElement("script");
       hm.src = "//hm.baidu.com/hm.js?" + _baId;
       var s = document.getElementsByTagName("script")[0];
       s.parentNode.insertBefore(hm, s);
     })();
 </script>
 */
