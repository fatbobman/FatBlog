//
//  File.swift
//
//
//  Created by Yang Xu on 2021/1/30.
//

import Foundation
import Publish

extension Plugin {
    static func test() -> Self {
        Plugin(name: "test") { content in
            for section in content.sections {
                print(section.content)
                //                section.items.first!.tag
            }
        }
    }
}
