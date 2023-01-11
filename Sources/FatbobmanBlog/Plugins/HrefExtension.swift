//
//  File.swift
//  File
//
//  Created by Yang Xu on 2021/8/29.
//

import Foundation
import Ink
import Sweep

// 对于非本站页面都在新的tab中打开
var hrefOpenNewTab = Modifier(target: .links){ html, markdown in
    guard html.hasPrefix("<a href=\"http") else {return html}
    guard !html.contains("fatbobman.com") else {return html}
    var result = html
    if let index = result.firstIndex(of: ">") {
        result.insert(contentsOf: " target=\"_blank\"", at: index)
    }
    return result
}
