//
//  File.swift
//
//
//  Created by Yang Xu on 2021/2/2.
//

import Foundation
import Plot
import Publish

public extension Node where Context == HTML.BodyContext {
    static func searchResult() -> Node {
        .div(
            .id("local-search-result"),
            .class("local-search-result-cls")
        )
    }

    static func searchInput() -> Node {
        .div(
            .class("searchform"),
            .form(
                .class("site-search-form"),
                .input(
                    .class("st-search-input"),
                    .attribute(named: "type", value: "text"),
                    .id("local-search-input"),
                    .required(true),
                    .placeholder("请输入你要搜索的内容...")
                ),
                .a(
                    .class("clearSearchInput"),
                    .href("javascript:"),
                    .onclick("""
                    document.getElementById('local-search-input').value = '';
                    """)
                )
            ),
            .script(
                .id("local.search.active"),
                .raw(
                    """
                        var inputArea  = document.querySelector("#local-search-input");
                        inputArea.onclick   = function(){
                            getSearchFile();
                            this.onclick = null
                        }
                        inputArea.onkeydown = function(){
                            if(event.keyCode == 13) return false
                        }
                    """
                )
            ),
            .script(
                .raw(searchJS)
            ),
            // 窗口变化
            .script(
                .raw(
                    """
                        var resizeTimer = null;

                        $(window).resize(function(){
                            setHeight();
                        // if(resizeTimer){
                        //     clearTimeout(resizeTimer);
                        // }
                        // resizeTimer = setTimeout(function(){
                        //     setHeight();
                        // },100)
                        })
                    """
                )
            ),
            // 设置search-result height
            .script(
                .raw("""
                    var setHeight = function(){
                        // swiftlint:disable line_length
                        var totalHeight = $('.local-search-result-cls').get(0).offsetHeight + $('.site-search-form').get(0).offsetHeight + $('.all-tags').get(0).offsetHeight + $('footer').get(0).offsetHeight + $('header').get(0).offsetHeight + 70
                        var padding = parseInt($('.wrapper').css('padding-top')) + parseInt($('.wrapper').css('padding-bottom')) ;
                        if (totalHeight < window.innerHeight) {
                            $('.wrapper').height( window.innerHeight - 50 - $('footer').get(0).offsetHeight - $('header').get(0).offsetHeight );
                        }
                        else {
                            $('.wrapper').height( $('.local-search-result-cls').get(0).offsetHeight + $('.site-search-form').get(0).offsetHeight + $('.all-tags').get(0).offsetHeight + 20);
                        }
                     }
                    """
                )
            ),
            .script(
                .raw(
                    """
                    $(document).ready(function(){
                        var emote_list = document.getElementById('local-search-result');
                        emote_list.addEventListener('DOMSubtreeModified', function () {
                           setHeight()
                        }, false);
                    })
                    """
                )
            ),
            .script(
                .raw(
                    """
                    $(document).ready(function(){
                      //setTimeout(function(){
                            setHeight();
                      //  },100)
                    })
                    """
                )
            )
        )
    }
}
