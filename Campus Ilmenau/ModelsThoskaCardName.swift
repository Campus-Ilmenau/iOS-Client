//
//  ThoskaCardName.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 27.10.26.
//

import Foundation
import SwiftData

/// Vom Nutzer vergebener Anzeigename für eine Karten-ID. Wird beim ersten
/// Speichern eines Datensatzes für diese Karte automatisch mit der Karten-ID
/// als Platzhalter angelegt und kann später umbenannt werden.
@Model
final class ThoskaCardName {
    @Attribute(.unique) var cardId: String
    var name: String

    init(cardId: String, name: String) {
        self.cardId = cardId
        self.name = name
    }
}
