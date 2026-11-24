//
//  CampusWidgetsBundle.swift
//  CampusWidgets
//
//  Created by Kai Gothe on 07.11.26.
//

import WidgetKit
import SwiftUI

@main
struct CampusWidgetsBundle: WidgetBundle {
    init() {
        // Texte in der Sprache, die in der App unter „Mehr“ gewählt ist (die Wahl liegt in der App Group).
        AppLanguage.installieren()
    }

    var body: some Widget {
        MensaWidget()
        AbendWidget()
        if #available(iOS 18.0, *) {
            ThoskaSteuerelement()
            KatalogSteuerelement()
        }
    }
}
