//
//  Prefs.swift
//  Offset Modulator
//
//  Created by Ming Xing Liang on 2020/5/19.
//  Copyright © 2020 Myong Song Ryang. All rights reserved.
//

import Foundation

class Prefs {

    static func value<T>(forKey key: String, defaultValue: T) -> T{

        let preferences = UserDefaults.standard
        return preferences.object(forKey: key) == nil ? defaultValue : preferences.object(forKey: key) as! T
    }

    static func value(forKey key: String, value: Any){

        UserDefaults.standard.set(value, forKey: key)
        UserDefaults.standard.synchronize()
    }

}
