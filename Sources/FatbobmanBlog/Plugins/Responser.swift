//
//  File.swift
//
//
//  Created by Yang Xu on 2021/10/9.
//

import Foundation
import Ink
import Plot
import Sweep

var responser = Modifier(target: .codeBlocks) { html, markdown in
    guard let content = markdown.firstSubstring(between: .prefix("```responser\n"), and: "\n```") else { return html }
    var id = "1"
    content.scan(using: [
        Matcher(identifier: "id: ", terminator: "\n", allowMultipleMatches: false) { match, _ in id = String(match) }
    ])

    let start = "<Div id = \"responser\" class = \"responser\" ><div class = \"adsContent\">"
    let end = "</div><div class='label'>推荐</div></Div>"
    return start + healthAds1 + end + adsScript
}

func getResponser(_ id: String) -> String {
    switch id {
    // 健康笔记
    case "1":
        return healthAds1
    default:
        return " Hello world "
    }
}

let adsScript = """
<script type="text/javascript">
$(document).ready(function() {
   var banners = [];
   var index = 0;
   $("#responser").on("click",function(){
    window.location.href = "https://www.fatbobman.com/healthnotes/"
});
  });
</script>
"""

// MARK: - 广告数据

// 健康笔记
let healthAds1 =
    """
    <style>
    .adsImage {
       content:url("https://cdn.fatbobman.com/BlogHealthNotesAdsPic.png")
    }
    @media (prefers-color-scheme: dark) {
      .adsImage {
           content:url("https://cdn.fatbobman.com/BlogHealthNotesAdsDarkPic.png")
      }
    }
    </style>
    <div class = "HStack">
    <img class = "adsImage"></img>
    <div class = "textContainer">
    <div class = "title">健康笔记 - 全家人的健康助手 </div>
    <div class = "document"><p>健康笔记适用于任何有健康管理需求的人士。提供了强大的自定义数据类型功能，可以记录生活中绝大多数的健康项目数据。你可以为每个家庭成员创建各自的记录笔记，或者针对某个特定项目、特定时期创建对应的笔记。</p>
    </div>
    </div>
    </div>
    """.replacingOccurrences(of: "\n", with: "")

let healthAds =
    """
    <div><img src = "https://cdn.fatbobman.com/healthnotesPromotion3.png"></img>
    </div>
    """.replacingOccurrences(of: "\n", with: "")

let healthURL = "https://www.fatbobman.com/healthnotes/"

let style =
    """
    <style type="text/css">
    .responser .subtitle {

    }

    .responser .title {
    }

    .responser .document {
    }

    .responser .content {
    }
    </style>
    """

let healthNotesContent =
    """
    <div class = "hstack">
    <img src = "https://cdn.fatbobman.com/healthnotesLogoRespnser.png"></img>
    <div class = "content">
    <div class = "subtitle">欢迎使用肘子开发的作品</div>
    <div class = "title">健康笔记 - 全家人的健康助手</div>
    <div class = "document">健康笔记提供了强大的自定义数据类型功能，可以满足记录生活中绝大多数的健康项目数据的需要。</div>
    </div>
    </div>
    """
