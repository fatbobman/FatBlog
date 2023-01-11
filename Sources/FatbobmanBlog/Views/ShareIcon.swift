//
//  File.swift
//
//
//  Created by Yang Xu on 2022/3/23
//  Copyright © 2022 Yang Xu. All rights reserved.
//
//  Follow me on Twitter: @fatbobman
//  My Blog: https://www.fatbobman.com
//

import Foundation
import Plot
import Publish

// 首页的分享栏

extension Node where Context == HTML.BodyContext {
    static func shareContainer(title: String, url: String) -> Node {
        .div(
            .class("post-actions"),
            .div(
                .class("actionButton"),
                .div(
                    .class("actionButton twitter"),
                    .onclick("window.open('https://twitter.com/intent/tweet?text=\(title)&url=\(url)&via=fatbobman','target','');")
                )
            ),
//            .div(
//                .class("actionButton"),
//                .div(
//                    .class("actionButton weixin"),
//                    .script(
//                        .raw(
//                            """
//                            var weixinButton = $('.actionButton .weixin');
//                            weixinButton.hover(
//                            function(){
//                                $('.actionButton .weixinQcode').css('display','block');
//                            },
//                            function(){
//                                $('.actionButton .weixinQcode').css('display','none');
//                            })
//                            """
//                        )
//                    ),
//                    .div(
//                        .class("actionButton weixinQcode")
//                    )
//                )
//            ),
            .div(
                .class("actionButton"),
                .div(
                    .class("actionButton comment"),
                    .onclick("$('html,body').animate({scrollTop: $('#gitalk-container').offset().top }, {duration: 500,easing:'swing'})"
                    )
                )
            )
//                ,
//            .div(
//                .class("actionButton"),
//                .div(
//                    .class("actionButton donate"),
//                    .script(
//                        """
//                        var donateButton = $('.actionButton .donate');
//                        donateButton.hover(
//                        function(){
//                            $('.actionButton .donateQcode').css('display','block');
//                        },
//                        function(){
//                            $('.actionButton .donateQcode').css('display','none');
//                        })
//                        """
//                    ),
//                    .div(
//                        .class("actionButton donateQcode")
//                    )
//                )
//            )
        )
    }
}
