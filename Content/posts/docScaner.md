---
date: 2021-11-10 08:20
description: 本文将介绍如何通过 VisionKit、Vision、NaturalLanguage、CoreSpotlight 等系统框架实现与备忘录扫描文稿类似的功能。
tags: Vision,NaturalLanguage
title:  用苹果官方 API 实现 iOS 备忘录的扫描文稿功能
image: images/docScannner.png
---

iOS 系统自带的备忘录（Notes）在其质朴名称下提供了众多强大的功能，扫描文稿是我使用较多的功能之一。很早前便想在【[健康笔记](https://www.fatbobman.com/healthnotes/)】之中提供类似的功能，但考虑到其涉及的知识点较多，迟迟没有下手。最近在空闲时，将近年 WWDC 中涉及该功能实现的专题梳理、学习了一遍，受益匪浅。苹果官方早已为我们准备了所需的一切工具。本文将介绍如何通过 VisionKit、Vision、NaturalLanguage、CoreSpotlight 等系统框架实现与备忘录扫描文稿类似的功能。

```responser
id:1
```

## 用 VisionKit 拍摄适合识别的图片 ##

### VisionKit 介绍 ###

VisionKit 是一个小框架，可以让你的应用程序使用系统的文档扫描仪。使用 VNDocumentCameraViewController 呈现覆盖整个屏幕的相机视图。通过在视图控制器中实现 VNDocumentCameraViewControllerDelegate，接收来自文档相机的回调，例如完成扫描。

通过同备忘录（Notes）一致的文档扫描外观，让开发者获得拍摄及图片处理能力（透视变换、颜色处理等）。

![IMG_1938](https://cdn.fatbobman.com/IMG_1938.jpeg)

### VisionKit 使用方法 ###

VisionKit 框架目标明确、无需配置，使用异常简单。

#### 在 app 中申请相机的使用权限 ####

在 info 中添加 NSCameraUsageDescription 键，填写使用相机的原因。

![image-20211109184955837](https://cdn.fatbobman.com/image-20211109184955837.png)

### 创建 VNDocumentCameraViewController ###

VNDocumentCameraViewController 并没有提供任何的配置选项，只需要声明一个它的实例便可使用。

下面的代码为在 SwiftUI 中使用的方式：

```swift
import VisionKit

struct VNCameraView: UIViewControllerRepresentable {
    @Binding var pages:[ScanPage]
    @Environment(\.dismiss) var dismiss

    typealias UIViewControllerType = VNDocumentCameraViewController

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> VNCameraCoordinator {
        VNCameraCoordinator(pages: $pages,dismiss: dismiss)
    }
}

struct ScanPage: Identifiable {
    let id = UUID()
    let image: UIImage
}
```

#### 实现 VNDocumentCameraViewControllerDelegate ####

VNDocumentCameraViewControllerDelegate 提供了三个回调方法

* documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan)

  告诉委托，用户已成功从文档相机保存扫描的文档

* documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController)

  告诉委托，用户已从文档扫描仪相机中取消。

* documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error)

  告诉委托，当相机视图控制器处于活动状态时，文档扫描失败。

```swift
final class VNCameraCoordinator: NSObject, VNDocumentCameraViewControllerDelegate {
    @Binding var pages:[ScanPage]
    var dismiss:DismissAction

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        for i in 0..<scan.pageCount{
            let scanPage = ScanPage(image: scan.imageOfPage(at: i))
            pages.append(scanPage)
        }
        dismiss()
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        dismiss()
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        dismiss()
    }

    init(pages:Binding<[ScanPage]>,dismiss:DismissAction) {
        self._pages = pages
        self.dismiss = dismiss
    }
}
```

VisionKit 允许使用者连续扫描图片。通过 pageCount 可以查询图片数量，并用 imageOfPage 分别获取。

> 用户应将扫描图片的方向调整到正确的显示状态，便于下一步的文字识别。

#### 在视图中调用 ###

```swift
struct ContentView: View {
    @State var scanPages = [ScanPage]()
    @State var scan = false
    var body: some View {
        VStack {
            Button("Scan") {
                scan.toggle()
            }
            List {
                ForEach(scanPages, id: \.id) { page in
                    HStack{
                    Image(uiImage: page.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 100)
                    }
                }
            }
            .fullScreenCover(isPresented: $scan) {
                VNCameraView(pages: $scanPages)
                    .ignoresSafeArea()
            }
        }
    }
}
```

至此，你已经获得了同 Notes 完全一致的拍摄扫描图片的功能。

## 用 Vision 进行文字识别 ##

### Vision 介绍 ###

相较 VisionKit 的小巧，Vision 则是一个功能强大、使用范围广泛的大型框架。它应用了计算机视觉算法，对输入的图像和视频执行各种任务。

Vision 框架可以执行人脸和人脸特征点检测、文本检测、条形码识别、图像配准和目标跟踪。Vision 还允许使用自定义的 Core ML 模型来完成分类或物体检测等任务。

在本例中，我们仅需使用 Vision 提供的文本检测（text detection）功能。

### 如何使用 Vision 进行文字识别 ###

Vision 能够检测和识别图像中的多语言文本，识别过程完全在设备本地进行，保证了用户的隐私。Vision 提供了两种文本的检测路径（算法），分别为 Fast（快速）和 Accurate（精确）。快速非常适合实时读取号码之类的场景，在本例中，由于我们需要对整个文档进行文字处理，选择使用神经网络算法的精确路径更加合适。

在 Vision 中无论进行哪个种类的识别计算，大致的流程都差不太多。

* 为 Vision 准备输入图像

  Vision 使用 VNImageRequestHandler 处理基于图像的请求，并假定图像是直立的，所以在传递图像时要考虑到方向。在本例中，我们将使用 VNDocumentCameraViewController 提供的图像进行处理。

* 创建 Vision Request

  首先使用要处理的图像创建一个 VNImageRequestHandler 对象。

  接下来创建 VNImageBasedRequest 提出识别需求（request）。针对每种识别类型都有对应的 VNImageBasedRequest 子类，本例中，识别文本对应的 request 为 VNRecognizeTextRequest。

  可以对同一张图片提出多个 request，只需创建并捆绑所有的请求到 VNImageRequestHandler 的实例即可。

* 解释检测结果

  可以通过两种方式访问检测结果：一、调用 perform 后检查 results 属性。二、在创建 request 对象时，设置回调方法检索识别信息。回调结果可能包含多个观察结果（observations），需要循环观察数组以处理每个观察结果。

大概的代码如下：

```swift
import Vision

func processImage(image: UIImage) -> String {
    guard let cgImage = image.cgImage else {
        fatalError()
    }
    var result = ""
    let request = VNRecognizeTextRequest { request, _ in
        guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
        let recognizedStrings = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }
        result = recognizedStrings.joined(separator: " ")
    }
    request.recognitionLevel = .accurate // 采用精确路径
    request.recognitionLanguages = ["zh-Hans", "en-US"] // 设置识别的语言

    let requestHandler = VNImageRequestHandler(cgImage: cgImage)
    do {
        try requestHandler.perform([request])
    } catch {
        print("error:\(error)")
    }
    return result
}
```

每个被识别的文本段可能包含多个识别结果，通过 topCandidates(n) 设置最多返回几个候选结果。

recognitionLanguages 定义了语言处理和文本识别过程中语言的使用顺序，识别中文时，需将中文设置在首位。

需要识别的文档：

![截屏 2021-11-09 下午 4.37.28](https://cdn.fatbobman.com/%E6%88%AA%E5%B1%8F2021-11-09%20%E4%B8%8B%E5%8D%884.37.28.png)

> 此类文档并不适合进行自然语言处理（除非进行大量的深度学习），但健康笔记中将主要保存的此种类型的内容。

识别结果：

```
InBody 身体水分 TinBody770) ID 15904113359 身高 年𠳕 性别 75 男性 测式日期/时间 (（透析）） 172cm 
(1946.07.10） 2021,10.09. 16:39 身体水分组成 身体水分组成 身体水分含量（(L） 60 0O 100 110 120 130 
100 170 32.5 身体总水分 32 5t 30 0AA . 细胞内水分 (） 70 10 GO 100 10 ％ 網舶内水分 19 9L 22 7-277 
19.9 细胞外水分 12.6L (13 号 170 細胞外水分 (L) HOF 00 100 110 120 13o 140 160 170 % 节段水分分析 
12.6 右上肢 1.80 L ( 201-279 细胞外水分比率分析 左上肢 2.00 L 2 07-2 79 低每准 魃干 16 8t 17 4 213 
细胞外水分比事 0.320 0.340 0360 0 380 0.300 0.400 0410 0 420 0.430 0 440 0 450 右下胶 5.65L ( 6 
08-743 0.390 左下肢 5.72 L ( 6 08-743 节段水分分析 人体成分分析 蛋白质 8.7 kg ( 9B~120 标准 无机盐 
2.83 hg 3.38~4 14 右上肢 (L) 70 85 100 15 130 45 160 175 1G0 205 1.80 体脂肪 30.0 xg ( 7.8-156 
左上肢 (L) 55 70 85 100 115 130 145 175 去脂体重 44.0 Mg ( 49 8~00 9 2.00 骨矿物质含量 2.37 kg ( 
279~3.41 躯干 (L) 70 80 90 100 110 120 130 40 150 160 170 肌肉脂肪分析 16.8 体重 74.0 xg 55 3-
74.9 右下肢 (L) 80 90 100 110 120 130 40 150 160 170 % 5.65 骨骼肌含量 23.9 kg 27 8-34 0 肌肉量 
41.6 kg 47.0-57 4 左下肢 (L) 70 80 90 100 110 120 130 140 150 160 170 ％ 5.72 体脂肪含量 30.0 
kg ( 7.8~156 肥胖分析 节段细胞外水分比率分析 BMI 25.0 kg/m ( 18.5~25 .0 体脂百分比 40.5% (10.0~200 
0 43 0.42 研究项目- 浮肿 基础代谢宰 1321 kcal ( 1593~1865 腰臀比 1.07 0.80~0.90 0.395 腹围 102.1 
cm 轻度浮肿 0 39 0.389 0.393 内脏脂肪面积 171.8 cm3 肥胖度 90~110 0 38 0.379 114 % 正常 0.376 身体
细胞量 28.5 kg ( 32.5~39.7 0 37 上臂围度 32.4 cm 0 36 上臂肌肉围度 27.5 cm 右上肢 左上肢 躯干 右下肢 
左下肢 TBW/FFM 73.9% 去脂体重指数 身体水分历史记录 14.9 kg/m' 脂肪量指数 10.1 kg/m' 体重 (kg) 86.1 
79.1 81.0 79.3 73.5 74.0 全身相位角 ¢( 50xz] 4.6 身体总水分 39.9 35.8 37.1 43.6 35. 32.5 生物电阻
抗- 细胞内水分 (L) 23.7 22.0 22.9 26.2 右上肢 左上肢躯千 右下肢 左下胶 21.1 19.9 ZQ) 1 MHlz/438.4 
383.5 35.6 331.9 323.0 5 g.428.0 374.7 34.4 324.1 315.2 细胞外水分（L） 16.2 13.8 14.2 17.4 
14.0 50 k1/ 377.9 334.7 31.0 294.0 285.0 12.6 250 H12/345.4 306.2 27.2 275.1 265.0 500 MHz 
334.7 296.9 25.8 270.1 259.4 细胞外水分比率 0.406 0.386 0.383 0.400 0.398 0.390 1000 &H2/ 
328.6. 291.3 23.9 265.7 255.3 ：最近 口全部 1903 28 20 01.22: 20.05 20  20 08 24 21 07 01:21 
10.09 129 11 13 11.34 16.31 ：1639 Ver Lookin Body120 32a6- SN. C71600359 Copyrgh(g 1296-by 
InBody Co. Lat Au Pghs resaned BR-Chinese-00-B-140129
```

> 识别的结果同文档打印品质、拍摄角度、光线质量有密切关系。

## 用 NaturalLanguage 对文本进行关键字提取 ##

健康笔记是一个以记录数据为核心的 app。为其添加文稿扫描功能是为了满足使用者对检查的纸质结果进行集中归档、整理的需要。因此，只需要从识别的文字中提取适量的查询关键字保存即可。

### NaturalLanguage 介绍 ###

NaturalLanguage 是用于分析自然语言文本并推断其特定语言元数据的框架。它提供各种自然语言处理（NLP）功能，支持许多不同的语言和脚本。使用该框架将自然语言文本分割成段落、句子或单词，并对这些片段的信息进行标记，如词性、词汇类别、词组、脚本和语言。

使用这个框架可以执行如下任务：

* 语言识别（Language identification）

  自动检测一段文本的语言

* 分词（Tokenization）

  将一段文本分解成语言单位或代号

* 词性标注（Parts-of-speech tagging）

  用词性标记单个单词

* 词性还原（Lemmatization）

  根据词形分析推导出词干

* 实体识别（Named entity recognition）

  将标记物识别为人名、地名或组织名称

### 提取关键字的思路 ###

在本例中，身体检查报告的版式对文本识别不很友好（使用者将提交各种样式的报告结果，很难做有针对性的深度学习），对识别结果做词性标注、或实体识别也比较困难。因此我只做了以下几个步骤：

* 预处理

  去除掉影响 Tokenization 的符号。本例中由于文字是从 VNRecognizeTextRequest 中获得，因此并不存在可能导致 tokenization 崩溃的控制字符。

* Tokenization（分词同时去除无用的信息）

  创建 NLTokenizer 实例，进行分词。大致的代码如下：

```swift
  let tokenizer = NLTokenizer(unit: .word) // 分词器操作的粒度级别
  tokenizer.setLanguage(.simplifiedChinese) // 设置要分词的文本的语言
  tokenizer.string = text
  var tokenResult = [String]()
  tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, attribute in
      let str = String(text[tokenRange])
      if attribute != .numeric, stopWords[str] == nil, str.count > 1 {
                tokenResult.append(str)
      }
      return true
  }
```

* 去重

  去除重复的内容。

  经过以上操作，上文中的图片最后获得如下内容（为Spotlight优化）：

```bash
inbody 身体水分身高性别男性日期时间透析组成含量细胞hof 分析上肢比率右下下肢人体成分蛋白质标准无机盐脂肪
体重矿物质躯干肌肉骨骼bmi 百分比研究项目浮肿基础代谢腹围轻度内脏面积肥胖度正常上臂围度tbw ffm 指数历史
记录全身相位生物电阻左下mhlz 最近全部ver lookin copyrgh lat pghs resaned chinese 
```

> 本人并没有 NLP 方面的知识和经验，上述的处理过程仅凭自己的感觉，如有错误，欢迎指正。通过优化文本的识别行高、丰富 stopWords 和 customWords、以及搭配词性判断，应该可以获得更好的结果。**扫描图片的质量对最终结果影响最大**。

## 用 CoreSpotlight 实现全文检索 ##

除了可以将文本保存在 Core Data 中进行检索外，我们也可以将其添加到系统索引中方便用户使用 Spotlight 进行搜索。

关于如何将数据添加至 Spotlight 以及如何在 app 中调用 Spotlight 进行检索的内容，请参阅我的另一篇文章 [在 Spotlight 中展示应用中的 Core Data 数据](https://www.fatbobman.com/posts/spotlight/)。

## 总结 ##

一个看似并不容易的功能，即使开发者没有相关的知识和经验储备，仅通过使用系统提供的 API 也可以实现的有模有样。官方 API 已可以应对一般的场景需求，值得为苹果的付出点赞。

> 有朋友在看到本文后关心以上功能对程序容量的影响。我的测试程序在使用了 VisionKit、Vision、NaturalLanguage、SwiftUI 框架功能后容量为330KB，对容量的影响可以忽略不计。这也是使用系统API给我们带来的另一大优势。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ)或下方的留言板与我进行交流。

