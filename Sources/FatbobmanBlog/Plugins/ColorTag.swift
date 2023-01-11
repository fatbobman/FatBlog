//
//  ColorfulTags.swift
//
//
//  Created by Zhijin Chen on 2020/01/16.
//
// 让tag多色彩的插件是由 Zhijin Chen 创作的
// 可以在下面的地址获得
// https://github.com/Ze0nC/ColorfulTagsPublishPlugin

import Foundation
import Publish

// MARK: - ItemColorfier

public protocol ItemColorfier {
    associatedtype Item

    var defaultClass: String { get }
    var numberOfVariants: Int { get }
    var variantPrefix: String { get }
    var items: [Item] { get }
}

// MARK: - TagColorfier

public struct TagColorfier: ItemColorfier {
    public let defaultClass: String

    public let numberOfVariants: Int

    public let variantPrefix: String

    public let items: [Tag]

    public typealias Item = Tag

    private static var shared = TagColorfier()

    private init() {
        numberOfVariants = 1
        variantPrefix = ""
        items = [Tag]()
        defaultClass = ""
    }

    private init<T: Website>(
        defaultClass: String, variantPrefix: String, numberOfVariants: Int,
        in context: PublishingContext<T>
    ) {
        self.numberOfVariants = numberOfVariants
        self.variantPrefix = variantPrefix
        items = [Tag](context.allTags).sorted(by: { (tag1, tag2) -> Bool in
            tag1.string.lowercased() < tag2.string.lowercased()
        })
        self.defaultClass = defaultClass
    }

    internal static func setup<T: Website>(
        defaultClass: String, variantPrefix: String, numberOfVariants: Int,
        in context: PublishingContext<T>
    ) {
        shared = TagColorfier(
            defaultClass: defaultClass, variantPrefix: variantPrefix, numberOfVariants: numberOfVariants,
            in: context
        )
    }

    internal static func colorfiedClass(for tag: Tag) -> String {
        if let index = shared.items.firstIndex(of: tag) {
            let residue = shared.items.count % shared.numberOfVariants
            let itemPerColor = shared.items.count / shared.numberOfVariants
            var result: Int
            if index / (itemPerColor + 1) < residue {
                result = index / (itemPerColor + 1)
            } else {
                result = (index - residue) / itemPerColor
            }
            return "\(shared.defaultClass) \(shared.variantPrefix)-\(result)"
        } else {
            return shared.defaultClass
        }
    }
}

public extension Tag {
    var colorfiedClass: String {
        return TagColorfier.colorfiedClass(for: self)
    }
}

public extension Plugin {
    /// Plugin to colorfy Tags.
    /// - Parameters:
    ///   - defaultClass: The default class name for Tag. Example: "tag".
    ///   - variantPrefix: The class prefix in css file. Example: "variant".
    ///   - numberOfVariants: The number of color classes in css.
    static func colorfulTags(
        defaultClass: String, variantPrefix: String, numberOfVariants: Int
    ) -> Self {
        Plugin(name: "ColorfulTags") { context in
            TagColorfier.setup(
                defaultClass: defaultClass, variantPrefix: variantPrefix,
                numberOfVariants: numberOfVariants, in: context
            )
        }
    }
}
