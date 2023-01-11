//
//  File.swift
//  File
//
//  Created by Yang Xu on 2021/8/24.
//

import Files
import Foundation
import Plot
import Publish
import Sweep

public extension PublishingStep {
    static func generateShortRSSFeed(
        including includedSectionIDs: Set<Site.SectionID>,
        itemPredicate: Predicate<Item<Site>>? = nil,
        config: RSSFeedConfiguration = .default,
        date: Date = Date()
    ) -> Self {
        guard !includedSectionIDs.isEmpty else { return .empty }

        return step(named: "Generate RSS feed") { context in
            let generator = ShortRSSFeedGenerator(
                includedSectionIDs: includedSectionIDs,
                itemPredicate: itemPredicate,
                config: config,
                context: context,
                date: date
            )

            try generator.generate()
        }
    }
}

struct ShortRSSFeedGenerator<Site: Website> {
    let includedSectionIDs: Set<Site.SectionID>
    let itemPredicate: Predicate<Item<Site>>?
    let config: RSSFeedConfiguration
    let context: PublishingContext<Site>
    let date: Date

    func generate() throws {
        let outputFile = try context.createOutputFile(at: config.targetPath)
        let cacheFile = try context.cacheFile(named: "feed")
        let oldCache = try? cacheFile.read().decoded() as Cache
        var items = [Item<Site>]()

        for sectionID in includedSectionIDs {
            items += context.sections[sectionID].items
        }

        items.sort { $0.date > $1.date }

        if let predicate = itemPredicate?.inverse() {
            items.removeAll(where: predicate.matches)
        }

        if let date = context.lastGenerationDate, let cache = oldCache {
            if cache.config == config, cache.itemCount == items.count {
                let newlyModifiedItem = items.first { $0.lastModified > date }

                guard newlyModifiedItem != nil else {
                    return try outputFile.write(cache.feed)
                }
            }
        }

        let feed = makeFeed(containing: items).render(indentedBy: config.indentation)

        let newCache = Cache(config: config, feed: feed, itemCount: items.count)
        try cacheFile.write(newCache.encoded())
        try outputFile.write(feed)
    }
}

extension ShortRSSFeedGenerator {
    struct Cache: Codable {
        let config: RSSFeedConfiguration
        let feed: String
        let itemCount: Int
    }

    func makeFeed(containing items: [Item<Site>]) -> RSS {
        RSS(
            .title(context.site.name),
            .description(context.site.description),
            .link(context.site.url),
            .language(context.site.language),
            .lastBuildDate(date, timeZone: context.dateFormatter.timeZone),
            .pubDate(date, timeZone: context.dateFormatter.timeZone),
            .ttl(Int(config.ttlInterval)),
            .atomLink(context.site.url(for: config.targetPath)),
            .forEach(items.prefix(config.maximumItemCount)) { item in
                .item(
                    .guid(for: item, site: context.site),
                    .title(item.rssTitle),
                    .description(item.description),
                    .link(item.rssProperties.link ?? context.site.url(for: item)),
                    .pubDate(item.date, timeZone: context.dateFormatter.timeZone),
                    .shortContent(for: item, site: context.site)
                )
            }
        )
    }
}

// 导入的扩展

private extension Item {
    var rssTitle: String {
        let prefix = rssProperties.titlePrefix ?? ""
        let suffix = rssProperties.titleSuffix ?? ""
        return prefix + title + suffix
    }
}

public struct Predicate<Target> {
    let matches: (Target) -> Bool

    /// Initialize a new predicate instance using a given matching closure.
    /// You can also create predicates based on operators and key paths.
    /// - parameter matcher: The matching closure to use.
    public init(matcher: @escaping (Target) -> Bool) {
        matches = matcher
    }
}

public extension Predicate {
    /// Create a predicate that matches any candidate.
    static var any: Self { Predicate { _ in true } }

    /// Create an inverse of this predicate - that is one that matches
    /// all candidates that this predicate does not, and vice versa.
    func inverse() -> Self {
        Predicate { !self.matches($0) }
    }
}

extension Node where Context: RSSItemContext {
    static func guid<T>(for item: Item<T>, site: T) -> Node {
        return .guid(
            .text(item.rssProperties.guid ?? site.url(for: item).absoluteString),
            .isPermaLink(item.rssProperties.guid == nil && item.rssProperties.link == nil)
        )
    }

    static func shortContent<T>(for item: Item<T>, site: T) -> Node {
        let baseURL = site.url
        let prefixes = (href: "href=\"", src: "src=\"")

        var html = item.rssProperties.bodyPrefix ?? ""
        // 添加了截取设置
        html.append(item
            .body
            .htmlDescription(words: 450, keepImageTag: false, ellipsis: "<a href=\(baseURL)/\(item.path)>...></a>"))
        html.append(item.rssProperties.bodySuffix ?? "")

        var links = [(url: URL, range: ClosedRange<String.Index>, isHref: Bool)]()

        html.scan(using: [
            Matcher(
                identifiers: [
                    .anyString(prefixes.href),
                    .anyString(prefixes.src),
                ],
                terminators: ["\""],
                handler: { url, range in
                    guard url.first == "/" else {
                        return
                    }

                    let absoluteURL = baseURL.appendingPathComponent(String(url))
                    let isHref = (html[range.lowerBound] == "h")
                    links.append((absoluteURL, range, isHref))
                }
            ),
        ])

        for (url, range, isHref) in links.reversed() {
            let prefix = isHref ? prefixes.href : prefixes.src
            html.replaceSubrange(range, with: prefix + url.absoluteString + "\"")
        }

        html.append(contentsOf: "<br><br><h3><a href=\(baseURL)/\(item.path)>查看全文</a></h3>")

        return content(html)
    }
}
