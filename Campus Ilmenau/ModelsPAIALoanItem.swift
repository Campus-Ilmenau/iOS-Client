//
//  ModelsPAIALoanItem.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 27.10.26.
//

import Foundation

/// Ein ausgeliehenes, vorgemerktes oder bestelltes Medium aus dem
/// PAIA-Nutzerkonto (https://gbv.github.io/paia/paia.html#items).
struct PAIALoanItem: Identifiable, Decodable {
    let item: String?
    let edition: String?
    let about: String?
    let label: String?
    let queue: Int?
    let renewals: Int?
    let reminder: Int?
    let starttime: Date?
    let endtime: Date?
    let cancancel: Bool?
    let canrenew: Bool?
    let storage: String?
    let storageid: String?
    let comment: String?
    let status: PAIAItemStatus

    var id: String { item ?? about ?? UUID().uuidString }

    /// Erzeugt eine Kopie mit aktualisierter Fälligkeit nach einer erfolgreichen
    /// Verlängerung (PAIA core/{patron}/renew).
    func renewed(newEndtime: Date?, newStatus: PAIAItemStatus?) -> PAIALoanItem {
        PAIALoanItem(
            item: item,
            edition: edition,
            about: about,
            label: label,
            queue: queue,
            renewals: (renewals ?? 0) + 1,
            reminder: reminder,
            starttime: starttime,
            endtime: newEndtime ?? endtime,
            cancancel: cancancel,
            canrenew: canrenew,
            storage: storage,
            storageid: storageid,
            comment: comment,
            status: newStatus ?? status
        )
    }
}

/// Die fünf laut PAIA-Spezifikation zulässigen Status-Werte eines Items.
enum PAIAItemStatus: Int, Decodable {
    case none = 0
    case reserved = 1
    case ordered = 2
    case held = 3
    case provided = 4
    case rejected = 5

    var label: String {
        switch self {
        case .none: return "Kein Status"
        case .reserved: return "Vorgemerkt"
        case .ordered: return "Bestellt"
        case .held: return "Ausgeliehen"
        case .provided: return "Bereitgestellt"
        case .rejected: return "Abgelehnt"
        }
    }
}

/// Antwort-Hülle des PAIA core-Endpunkts `/core/{patron}/items`.
struct PAIAItemsResponse: Decodable {
    let doc: [PAIALoanItem]
}
