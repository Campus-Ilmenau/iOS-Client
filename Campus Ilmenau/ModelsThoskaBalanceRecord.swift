//
//  ThoskaBalanceRecord.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 27.10.26.
//

import Foundation
import SwiftData

/// Ein gespeicherter Guthaben-Datenpunkt einer Thoska-Karte für den Verlauf.
/// Mehrere Karten werden über `cardId` unterschieden, sodass eine Auswertung
/// pro Karte möglich ist. Wird ausschließlich lokal auf dem Gerät gespeichert.
@Model
final class ThoskaBalanceRecord {
    var cardId: String
    var balance: Double
    var lastTransaction: Double
    var scannedAt: Date

    init(cardId: String, balance: Double, lastTransaction: Double, scannedAt: Date) {
        self.cardId = cardId
        self.balance = balance
        self.lastTransaction = lastTransaction
        self.scannedAt = scannedAt
    }
}

extension ThoskaBalanceRecord {
    convenience init(_ balance: ThoskaBalance) {
        self.init(
            cardId: balance.cardId,
            balance: balance.balance,
            lastTransaction: balance.lastTransaction,
            scannedAt: balance.scannedAt
        )
    }
}
