//
//  MensaMeal.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//  CORRECTED VERSION
//

import Foundation

struct MensaMeal: Identifiable {
    let id: String
    let category: String
    let name: String
    let description: String?
    let price: String
    let allergies: [String]
    let badges: [String]
    let canteenName: String
    let date: Date
}
