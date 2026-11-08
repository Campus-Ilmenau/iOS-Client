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
    var body: some Widget {
        MensaWidget()
        AbendWidget()
        if #available(iOS 18.0, *) {
            ThoskaSteuerelement()
            KatalogSteuerelement()
        }
    }
}
