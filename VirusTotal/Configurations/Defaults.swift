//
//  Defaults.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-23.
//

import Defaults
import Foundation

extension Defaults.Keys {

    // Cache quota usage for HomeView
    static let hourlyQuota = Key<UserQuota>("hourlyQuota",
                                            default: UserQuota(used: 0, allowed: 240))
    static let dailyQuota = Key<UserQuota>("dailyQuota",
                                           default: UserQuota(used: 0, allowed: 500))
    static let monthlyQuota = Key<UserQuota>("monthlyQuota",
                                             default: UserQuota(used: 0, allowed: 15_500))

    // Store VT API Key and Username
    static let apiKey = Key<String>("apiKey", default: "")
    static let userName = Key<String>("userName", default: "")

    // Onboarding
    static let appFirstLaunch = Key<Bool>("appFirstLaunch", default: true)

    // General Settings
    static let cleanURL = Key<Bool>("cleanURL", default: false)
    static let startPage = Key<NavigationItem>("startPage", default: .home)
    static let enableNotification = Key<Bool>("enableNotification", default: true)
    static let appLanguage = Key<AppLanguage>("appLanguage", default: AppLanguage.defaultLanguage)
    static let showMainWindowOnNextLaunch = Key<Bool>("showMainWindowOnNextLaunch", default: false)

    // Advanced Settings
    static let miniMode = Key<Bool>("miniMode", default: false)
}

enum NavigationItem: String, CaseIterable, Identifiable, Defaults.Serializable {
    case home, file, url, fileBatch
    var id: Self { self }
}

enum AppLanguage: String, CaseIterable, Identifiable, Defaults.Serializable {
    case english = "en"
    case czech = "cs"
    case simplifiedChinese = "zh-Hans"
    case russian = "ru"

    var id: Self { self }

    static var defaultLanguage: AppLanguage {
        preferredSupportedLanguage(from: Locale.preferredLanguages) ?? .english
    }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .czech:
            return "Čeština"
        case .simplifiedChinese:
            return "简体中文"
        case .russian:
            return "Русский"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    /// Seeds the stored preference from the system language on first launch,
    /// then applies whatever is stored.
    static func synchronizePreference() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "appLanguage") == nil {
            let preferredLanguages = defaults.stringArray(forKey: "AppleLanguages") ?? Locale.preferredLanguages
            Defaults[.appLanguage] = preferredSupportedLanguage(from: preferredLanguages) ?? defaultLanguage
        }

        Defaults[.appLanguage].apply()
    }

    /// Looks a key up in the selected language, so text built outside of
    /// SwiftUI follows the picker without waiting for a relaunch.
    func localizedString(forKey key: String, table: String? = nil) -> String {
        if let path = Bundle.main.path(forResource: rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            let value = bundle.localizedString(forKey: key, value: nil, table: table)
            if value != key {
                return value
            }
        }

        return String(localized: String.LocalizationValue(key))
    }

    func apply() {
        UserDefaults.standard.set([rawValue], forKey: "AppleLanguages")
    }

    private static func preferredSupportedLanguage(from languageIdentifiers: [String]) -> AppLanguage? {
        languageIdentifiers.compactMap(AppLanguage.init(languageIdentifier:)).first
    }

    private init?(languageIdentifier: String) {
        let normalizedIdentifier = languageIdentifier.replacingOccurrences(of: "_", with: "-")
        guard let language = AppLanguage.allCases.first(where: {
            normalizedIdentifier == $0.rawValue || normalizedIdentifier.hasPrefix("\($0.rawValue)-")
        }) else {
            return nil
        }

        self = language
    }
}
