//
//  ModelsPAIANotification.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 28.10.26.
//

import Foundation

/// Eine Benachrichtigung aus dem PAIA-Nutzerkonto
/// (https://gbv.github.io/paia/paia.html#notifications).
struct PAIANotification: Identifiable, Decodable {
    let id: String
    let about: String
    let date: Date
    let item: String?
    let url: String?
}

/// Antwort-Hülle des PAIA core-Endpunkts `/core/{patron}/notifications`.
struct PAIANotificationsResponse: Decodable {
    let notification: [PAIANotification]
}
