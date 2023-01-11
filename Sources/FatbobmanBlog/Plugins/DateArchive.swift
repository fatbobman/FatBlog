//
//  File.swift
//
//
//  Created by Yang Xu on 2021/2/3.
//

import Foundation
import Plot
import Publish

extension PublishingStep where Site == FatbobmanBlog {
    static func makeDateArchive() -> Self {
        step(named: "Date Archive") { content in
            var doc = Content()
            doc.title = "时间线"
            let archiveItems = dateArchive(items: content.allItems(sortedBy: \.date, order: .descending))
            let html = Node.div(
                .forEach(archiveItems.keys.sorted(by: >)) { absoluteMonth in
                    .group(
                        .h3(.text("\(absoluteMonth.monthAndYear.year)年\(absoluteMonth.monthAndYear.month)月")),
                        .ul(
                            .forEach(archiveItems[absoluteMonth]!) { item in
                                .li(
                                    .a(
                                        .href(item.path),
                                        .text(item.title)
                                    )
                                )
                            }
                        )
                    )
                }
            )
            doc.body.html = html.render()
            let page = Page(path: "archive", content: doc)
            content.addPage(page)
        }
    }

    fileprivate static func dateArchive(items: [Item<Site>]) -> [Int: [Item<Site>]] {
        let result = Dictionary(grouping: items, by: { $0.date.absoluteMonth })
        return result
    }
}

extension Date {
    var absoluteMonth: Int {
        let calendar = Calendar.current
        let component = calendar.dateComponents([.year, .month], from: self)
        return component.year! * 12 + component.month!
    }
}

extension Int {
    var monthAndYear: (year: Int, month: Int) {
        var month = self % 12
        var year = self / 12
        if month == 0 {
            month = 12
            year -= 1
        }
        return (year, month)
    }
}
