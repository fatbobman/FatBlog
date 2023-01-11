//
//  File.swift
//
//
//  Created by Yang Xu on 2021/2/2.
//

import Foundation
import Plot
import Publish

let css: [Path] = [
    "/images/css/stylesNew.css",
    "/images/css/code.css", // 代码高亮
    "/images/css/toc.css", // 文章正文 toc
    "/images/css/search.css",
    "/images/css/convertkit.css"
]

extension Node where Context == HTML.DocumentContext {
    /// Add an HTML `<head>` tag within the current context, based
    /// on inferred information from the current location and `Website`
    /// implementation.
    /// - parameter location: The location to generate a `<head>` tag for.
    /// - parameter site: The website on which the location is located.
    /// - parameter titleSeparator: Any string to use to separate the location's
    ///   title from the name of the website. Default: `" | "`.
    /// - parameter stylesheetPaths: The paths to any stylesheets to add to
    ///   the resulting HTML page. Default: `styles.css`.
    /// - parameter rssFeedPath: The path to any RSS feed to associate with the
    ///   resulting HTML page. Default: `feed.rss`.
    /// - parameter rssFeedTitle: An optional title for the page's RSS feed.
    static func customHeader<T: Website>(
        for location: Location, on site: T, titleSeparator: String = " | ",
        stylesheetPaths: [Path] = css, rssFeedPath: Path? = .defaultForRSSFeed,
        rssFeedTitle: String? = nil,
        healthNotes: Bool = false
    ) -> Node {
        var title = location.title

        if title.isEmpty { title = site.name } else { title.append(titleSeparator + site.name) }

        var description = location.description

        if description.isEmpty { description = site.description }

        return .head(
            .encoding(.utf8),
            .siteName(site.name),
            .url(site.url(for: location)),
            .title(title),
            .description(description),
            .if(
                location.path == "",
                .twitterCardType(.summaryLargeImage),
                else: .twitterCardType(location.imagePath == nil ? .summary : .summaryLargeImage)
            ),
            .meta(.name("twitter:site"), .content("@fatbobman")),
            .meta(.name("twitter:creator"), .content("@fatbobman")),
            .meta(.name("referrer"), .content("no-referrer")),
            // 只有健康笔记弹出smart bar
            .if(healthNotes,
                .meta(.name("apple-itunes-app"), .content("app-id=1534513553"))),
            .forEach(stylesheetPaths) { .stylesheet($0) }, .viewport(.accordingToDevice),
            .unwrap(site.favicon) { .favicon($0) },
            .unwrap(
                rssFeedPath) { path in let title = rssFeedTitle ?? "Subscribe to \(site.name)"
                    return .rssFeedLink(path.absoluteString, title: title)
                },
            .if(location.path == "",
                .socialImageLink("https://www.fatbobman.com/images/twitterCardImage.png"),
                else:
                .unwrap(
                    location.imagePath ?? site.imagePath) { path in let url = site.url(for: path)
                        return .socialImageLink(url)
                    }),
            .script(.src("/images/css/jquery.min.js")),
            .raw(newGoogleAnalytics),
            .link(.rel(.stylesheet),
                  .href("/images/css/heti.min.css")),
            // 工具栏颜色
            .meta(.name("theme-color"), .content("#C62F1C"))
        )
    }
}

let newGoogleAnalytics = """
<!-- Global site tag (gtag.js) - Google Analytics -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-95XGB44EJH"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());

  gtag('config', 'G-95XGB44EJH');
</script>
"""
