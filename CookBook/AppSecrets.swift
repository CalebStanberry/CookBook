//
//  AppSecrets.swift
//  CookBook
//
//  Created by Caleb Stanberry on 1/15/26.
//

import Foundation

struct AppSecrets {
    static var appToken: String {
        Bundle.main.infoDictionary?["APP_TOKEN"] as? String ?? ""
    }
}
