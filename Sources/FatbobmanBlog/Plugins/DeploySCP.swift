//
//  File.swift
//
//
//  Created by Yang Xu on 2021/2/2.
//

import Foundation
import Publish
import ShellOut

extension PublishingStep where Site == FatbobmanBlog {
    static func uploadToServer() -> Self {
        step(named: "update files to fatbobman.com") { _ in
            print("uploading......")
            do {
                try shellOut(
                    to: "scp -i ~/.ssh/id_rsa -r  ~/fatbobmanBlog/Output root@111.229.200.169:/var/www")
            } catch {
                print(error)
            }
        }
    }
}
