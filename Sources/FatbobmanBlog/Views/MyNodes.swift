import Foundation
import Plot
import Publish

extension Node where Context == HTML.BodyContext {
    static func license() -> Node {
        .div(
            .class("license"),
            .p(
                .text("本博客文章采用"),
                .a(
                    .text("CC 4.0 协议"),
                    .href("https://creativecommons.org/licenses/by-nc-sa/4.0/"),
                    .target(.blank)
                ),
                .text("，转载需注明出处和作者。")
            ),
            .p(
                // .raw("""
                // <script type="text/javascript" src="https://cdnjs.buymeacoffee.com/1.0.0/button.prod.min.js" data-name="bmc-button" data-slug="fatbobman" data-color="#FFDD00" data-emoji=""  data-font="Bree" data-text="请肘子喝杯咖啡       " data-outline-color="#000000" data-font-color="#000000" data-coffee-color="#ffffff" ></script>
                // """)
                .a(
                    .img(
                        .src("https://cdn.fatbobman.com/support_fatbobman_button.png"),
                        .alt("鼓励作者"),
                        .width(200),
                        .height(53)
                    ),
                    .href("https://www.fatbobman.com/support/")
                )
            )
//            ,
//            .p(
//                .text("转载请注明出处和作者。")
//            )
        )
    }

    static func viewContainer(_ nodes: Node...) -> Node {
        .div(
            .class("viewContainer"),
            .group(nodes)
        )
    }

    // 文章列表Spacer
    static func itemListSpacer() -> Node {
        .group(
            // 窗口变化
            .script(
                .raw(
                    """
                        $(window).resize(function(){
                            setHeight();
                        })
                    """
                )
            ),
            // 设置search-result height
            .script(
                .raw("""
                    var setHeight = function(){
                        var totalHeight = $('.item-list').get(0).offsetHeight + $('footer').get(0).offsetHeight + $('header').get(0).offsetHeight + 50
                        if (totalHeight < window.innerHeight) {
                            $('.wrapper').height( window.innerHeight - 50 - $('footer').get(0).offsetHeight - $('header').get(0).offsetHeight );
                        }
                        else {
                            $('.wrapper').height( $('.item-list').height );
                        }
                     }
                    """
                )
            ),
            .script(
                .raw(
                    """
                    $(document).ready(function(){
                        setHeight();
                    })
                    """
                )
            )
        )
    }

    static func tagDetailSpacer() -> Node {
        .group(
            // 窗口变化
            .script(
                .raw(
                    """
                        $(window).resize(function(){
                            setHeight();
                        })
                    """
                )
            ),
            // 设置search-result height
            .script(
                .raw("""
                    var setHeight = function(){
                        var totalHeight = $('.item-list').get(0).offsetHeight + $('footer').get(0).offsetHeight + $('header').get(0).offsetHeight + 50
                        if (totalHeight < window.innerHeight) {
                            $('.wrapper').height( window.innerHeight - 50 - $('footer').get(0).offsetHeight - $('header').get(0).offsetHeight );
                        }
                        else {
                            $('.wrapper').height( $('.item-list').height );
                        }
                     }
                    """
                )
            ),
            .script(
                .raw(
                    """
                    $(document).ready(function(){
                        setHeight();
                    })
                    """
                )
            )
        )
    }

    static func headerIcons() -> Node {
        .div(
            .div(
                .class("headerIcons"),
//                .a(
//                    .class("icon headIconWeixin"),
//                    .script(
//                        .raw(
//                            """
//                                var weixinHeadButton = $('.headIconWeixin');
//                                weixinHeadButton.hover(
//                                function(){
//                                $('.weixinHeadQcode').css('display','block');
//                                },
//                                function(){
//                                $('.weixinHeadQcode').css('display','none');
//                                })
//                            """
//                        )
//                    )
//                ),
                .a(
                    .class("icon headIconTwitter"),
                    .href("https://www.twitter.com/fatbobman"),
                    .target(.blank),
                    .rel(.nofollow),
                    .rel(.noopener),
                    .rel(.noreferrer)
                ),
                .a(
                    .class("icon headIconEmail"),
                    .href("mailto:xuyang@me.com"),
                    .target(.blank),
                    .rel(.nofollow),
                    .rel(.noopener),
                    .rel(.noreferrer)
                ),
                .a(
                    .class("icon headIconGithub"),
                    .href("https://github.com/fatbobman/"),
                    .target(.blank),
                    .rel(.nofollow),
                    .rel(.noopener),
                    .rel(.noreferrer)
                ),
                .a(
                    .class("icon headIconZhihu"),
                    .href("https://www.zhihu.com/people/fatbobman3000"),
                    .target(.blank),
                    .rel(.nofollow),
                    .rel(.noopener),
                    .rel(.noreferrer)
                ),
                .a(
                    .class("icon headIconRss"),
                    .href("/feed.rss"),
                    .target(.blank),
                    .rel(.nofollow),
                    .rel(.noopener),
                    .rel(.noreferrer)
                )
            )
        )
    }

    static func twitterIntent(title: String, url: String) -> Node {
        .div(
            .class("post-actions"),
            .a(.img(.class("twitterIntent"), .src("/images/twitter.svg")),
               .href("https://twitter.com/intent/tweet?text=\(title)&url=\(url)&via=fatbobman"),
               .target(.blank),
               .rel(.nofollow),
               .rel(.noopener),
               .rel(.noreferrer))
        )
    }

//    static func mobileToc(_ nodes: Node...) -> Node {
//        .div(
//            .class("mobileSidenav"),
//            .div(
//                .group(nodes)
//            )
//        )
//    }
//
//    static func shareContainerForMobile(title: String, url: String) -> Node {
//        .div(
//            .class("post-actions-mobile"),
//            .div(
//                .class("actionButton"),
//                .div(
//                    .class("actionButton twitter"),
//                    .onclick("window.open('https://twitter.com/intent/tweet?text=\(title)&url=\(url)&via=fatbobman','target','');")
//                )
//            ),
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
//            .div(
//                .class("actionButton"),
//                .div(
//                    .class("actionButton comment"),
//                    .onclick("$('html,body').animate({scrollTop: $('#gitalk-container').offset().top }, {duration: 500,easing:'swing'})"
//                    )
//                )
//            ),
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
//        )
//    }

    static func support() -> Node {
        let support =
            """
            关注微信公共号[肘子的Swift记事本](/support/)或在推特上关注[@fatbobman](https://twitter.com/fatbobman)，永远不会错过新内容！
            您的[支持和鼓励](/support/)将为我的博客写作增添更多的动力!
            如果您或身边的朋友有健康数据管理的需求，请使用我开发的app[【健康笔记】](/healthnotes/)，正是因为它我才创建了这个博客。
            """
        return .div(
            .class("supporter"),
            .markdown(support),
            .div(
                .class("label"),
                .text("关注")
            )
        )
    }

    static func newsletter() -> Node {
        .raw("""
        <form style="border:1px solid #ccc;padding:3px;text-align:center;" action="https://tinyletter.com/fatbobman" method="post" target="popupwindow" onsubmit="window.open('https://tinyletter.com/fatbobman', 'popupwindow', 'scrollbars=yes,width=800,height=600');return true"><p><label for="tlemail">Enter your email address</label></p><p><input type="text" style="width:140px" name="email" id="tlemail" /></p><input type="hidden" value="1" name="embed"/><input type="submit" value="Subscribe" /><p><a href="https://tinyletter.com" target="_blank">powered by TinyLetter</a></p></form>
        """)
    }

    // ConvertKit newsletter
    static func convertKit() -> Node {
        .raw(
            """
            <script src="/images/css/ck.5.js"></script>
            <form action="https://app.convertkit.com/forms/3144411/subscriptions"class="seva-form formkit-form"method="post"data-sv-form="3144411"data-uid="3d533033dd"data-format="inline"data-version="5"data-options="{&quot;settings&quot;:{&quot;after_subscribe&quot;:{&quot;action&quot;:&quot;message&quot;,&quot;success_message&quot;:&quot;Success! Now check your email to confirm your subscription.&quot;,&quot;redirect_url&quot;:&quot;&quot;},&quot;analytics&quot;:{&quot;google&quot;:null,&quot;fathom&quot;:null,&quot;facebook&quot;:null,&quot;segment&quot;:null,&quot;pinterest&quot;:null,&quot;sparkloop&quot;:null,&quot;googletagmanager&quot;:null},&quot;modal&quot;:{&quot;trigger&quot;:&quot;timer&quot;,&quot;scroll_percentage&quot;:null,&quot;timer&quot;:5,&quot;devices&quot;:&quot;all&quot;,&quot;show_once_every&quot;:15},&quot;powered_by&quot;:{&quot;show&quot;:true,&quot;url&quot;:&quot;https://convertkit.com/features/forms?utm_campaign=poweredby&amp;utm_content=form&amp;utm_medium=referral&amp;utm_source=dynamic&quot;},&quot;recaptcha&quot;:{&quot;enabled&quot;:false},&quot;return_visitor&quot;:{&quot;action&quot;:&quot;show&quot;,&quot;custom_content&quot;:&quot;&quot;},&quot;slide_in&quot;:{&quot;display_in&quot;:&quot;bottom_right&quot;,&quot;trigger&quot;:&quot;timer&quot;,&quot;scroll_percentage&quot;:null,&quot;timer&quot;:5,&quot;devices&quot;:&quot;all&quot;,&quot;show_once_every&quot;:15},&quot;sticky_bar&quot;:{&quot;display_in&quot;:&quot;top&quot;,&quot;trigger&quot;:&quot;timer&quot;,&quot;scroll_percentage&quot;:null,&quot;timer&quot;:5,&quot;devices&quot;:&quot;all&quot;,&quot;show_once_every&quot;:15}},&quot;version&quot;:&quot;5&quot;}"min-width="400 500 600 700 800"><div data-style="clean"><ul class="formkit-alert formkit-alert-error"data-element="errors"data-group="alert"></ul><div data-element="fields"data-stacked="false"class="seva-fields formkit-fields"><div class="formkit-field"><input class="formkit-input"name="email_address"style="color: rgb(0, 0, 0); border-color: rgb(227, 227, 227); border-radius: 4px; font-weight: 400;"aria-label="电子邮件地址"placeholder="电子邮件地址"required=""type="email"></div><button data-element="submit"class="formkit-submit formkit-submit"style="color: rgb(255, 255, 255); background-color: rgb(129, 0, 32); border-radius: 4px; font-weight: 400;"><div class="formkit-spinner"><div></div><div></div><div></div></div><span class="">订阅每周汇总</span></button></div><div class="formkit-powered-by-convertkit-container"><a href="https://convertkit.com/features/forms?utm_campaign=poweredby&amp;utm_content=form&amp;utm_medium=referral&amp;utm_source=dynamic"data-element="powered-by"class="formkit-powered-by-convertkit"data-variant="dark"target="_blank"rel="nofollow">Built with ConvertKit</a></div></div>
            </form>
            """)
    }

    static func substack() -> Node {
        .raw(
            """
            <iframe src="https://fatbobman.substack.com/embed" width="480" height="320" style="border:1px solid #EEE; background:white;" frameborder="0" scrolling="no"></iframe>
            """
        )
    }
}

/*
 <script src="https://f.convertkit.com/ckjs/ck.5.js"></script>
 */
