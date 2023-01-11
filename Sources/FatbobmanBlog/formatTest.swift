//
//  File.swift
//
//
//  Created by Yang Xu on 2021/2/9.
//

import Foundation

// MARK: - TEST

public class TEST {
    let name: String = ""
}

func abvest13(
    fat: String,
    name: String,
    easdf: String?
) -> String {
    print(fat)

    #if os(iOS)
        print("ios")
    #else
        print("abc")
    #endif
    let cddd = easdf!
    print(cddd)

    if cddd.count > 3, name.count < 2 {
        print("df")
    }

    return "abc"
        .uppercased().lowercased()
}

extension String {
    func name() -> String {
        self + "name"
    }
}
