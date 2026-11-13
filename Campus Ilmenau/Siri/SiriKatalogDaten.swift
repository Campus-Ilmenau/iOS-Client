import Foundation

/// Lädt für „Suche im Katalog“ und „Merkliste“ die Daten aus der Katalog-API und gibt sie an die Logik in `Shared/`
/// (`SiriKatalog`, `SiriMerkliste`). Ohne Anmeldung: Es gibt keinen Zugriff auf PAIA und kein Bibliotheks-Token,
/// nur auf den öffentlichen Service `LibraryCatalogService` und die Merkliste auf dem Gerät.
@MainActor
enum SiriKatalogDaten {
    /// Die Suche im Bestand der UB. Siri soll nie ewig warten.
    nonisolated static let suchlimit: Duration = .seconds(6)
    /// Der Status der ersten 3 Treffer. Ist das zu langsam, erscheinen die Treffer ohne Chip.
    nonisolated static let statuslimit: Duration = .seconds(3)
    /// Suche und Status zusammen bleiben unter etwa 8 Sekunden: Was die Suche übrig lässt, ist das Limit für den Status.
    /// Reicht es nicht mehr (die Suche war langsam), kommen die Treffer ohne Chip, ohne den Status abzufragen.
    nonisolated static let gesamtlimit: Duration = .seconds(8)
    /// Weniger Zeit als das lohnt sich für den Status nicht.
    nonisolated static let mindestZeitFuerStatus: Duration = .milliseconds(250)
    /// `/availability` für die Merkliste.
    nonisolated static let merklistenlimit: Duration = .seconds(4)

    // MARK: Suche

    /// Freitextsuche wie in der App („Gedruckt“), aber nur im Bestand der UB (`in=local`) und ohne die langsame
    /// Gesamtkatalog-Abfrage.
    /// - Parameters:
    ///   - service: Vorgabe ist der Katalog der App; Tests geben einen mit Stub.
    ///   - clock: Die Uhr für alle Limits. Tests geben eine, die nur vorläuft, wenn sie es sagen.
    static func suche(
        _ begriff: String, service: LibraryCatalogService? = nil, suchlimit: Duration = SiriKatalogDaten.suchlimit,
        statuslimit: Duration = SiriKatalogDaten.statuslimit, gesamtlimit: Duration = SiriKatalogDaten.gesamtlimit,
        mindestZeitFuerStatus: Duration = SiriKatalogDaten.mindestZeitFuerStatus,
        clock: any Clock<Duration> = ContinuousClock()
    ) async -> SiriKatalogAntwort {
        let text = begriff.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = LibrarySearchQuery(text: text, scope: .local, mediaType: .printBook)
        guard query.validate().isEmpty else { return SiriKatalog.ungueltig }

        let service = service ?? LibraryCatalogService()
        var gefunden: LibrarySearchResponse?
        let verstrichen = await clock.measure {
            gefunden = await heuteMitZeitlimit(min(suchlimit, gesamtlimit), clock: clock) { try await service.search(query).value }
        }
        guard let antwort = gefunden else { return SiriKatalog.nichtErreichbar }

        let medien = Array(antwort.items.prefix(SiriKatalog.maxTreffer))
        // Der Status kommt nur für diese Treffer und nur, wenn er rechtzeitig da ist.
        let ids = medien.map(\.id)
        let uebrig = gesamtlimit - verstrichen
        let limit = min(statuslimit, uebrig)
        let verfuegbar = ids.isEmpty || limit < mindestZeitFuerStatus
            ? nil
            : await heuteMitZeitlimit(limit, clock: clock) { try await service.availability(ids: ids).value }

        let treffer = medien.map { medium in
            SiriKatalogTreffer(
                id: medium.id, titel: medium.title, meta: medium.metaLine, status: status(verfuegbar?[medium.id])
            )
        }
        let korrigiert = antwort.correctedQuery?.trimmingCharacters(in: .whitespacesAndNewlines)
        return SiriKatalog.antwort(SiriKatalogErgebnis(
            begriff: text,
            korrigiert: korrigiert?.isEmpty == false && korrigiert != text ? korrigiert : nil,
            gesamt: antwort.totalCount, treffer: treffer
        ))
    }

    /// Der Chip eines Treffers, wie die Suche ihn zeigt. Unbekannt oder noch nicht da: kein Chip.
    static func status(_ verfuegbarkeit: LibraryAvailability?) -> SiriKatalogStatus? {
        guard let verfuegbarkeit else { return nil }
        let art: SiriKatalogStatus.Art
        switch verfuegbarkeit.status {
        case .available: art = .ausleihbar
        case .referenceOnly: art = .nurVorOrt
        case .onLoan: art = .ausgeliehen
        case .online: art = .online
        case .unknown: return nil
        }
        let rueckgabe = verfuegbarkeit.earliestDueDate
        return SiriKatalogStatus(
            art: art, chipText: verfuegbarkeit.status.displayText(dueDate: rueckgabe), rueckgabe: art == .ausgeliehen ? rueckgabe : nil
        )
    }

    // MARK: Merkliste

    /// Die Merkliste auf dem Gerät mit frischem `/availability`. Kommt der Stand nicht rechtzeitig, bleibt er unbekannt.
    static func merkliste(
        _ eintraege: [GemerkterTitel], service: LibraryCatalogService? = nil, limit: Duration = SiriKatalogDaten.merklistenlimit,
        clock: any Clock<Duration> = ContinuousClock()
    ) async -> SiriMerklisteAntwort {
        guard !eintraege.isEmpty else { return SiriMerkliste.leer }
        let service = service ?? LibraryCatalogService()
        let stand = BibMerklisteStatus()
        let ids = eintraege.map(\.id)
        _ = await heuteMitZeitlimit(limit, clock: clock) {
            await stand.load(ids: ids, using: service)
            return true
        }
        return SiriMerkliste.antwort(eintraege.map { eintrag in
            // „Gefunden“ am Regal steht in der Merkliste der App; Gefundene zählen nicht „im Regal“, sie stehen im Fuß.
            SiriMerklisteEintrag(
                id: eintrag.id, titel: eintrag.anzeigeTitel,
                stand: merklisteStand(status: stand.status(for: eintrag.id), exemplar: stand.exemplar(for: eintrag.id)),
                gefunden: eintrag.istGefunden
            )
        })
    }

    /// Im Regal ist, was ausleihbar oder nur vor Ort ist und einen Standort hat; alles andere steht „nicht im Regal“.
    static func merklisteStand(status: LibraryAvailabilityStatus?, exemplar: BibMerklisteExemplar?) -> SiriMerklisteStand {
        switch status {
        case .available, .referenceOnly:
            guard let standort = exemplar?.standort else { return .unbekannt }
            return .imRegal(standort: standort, signatur: exemplar?.signatur)
        case .onLoan: return .ausgeliehen
        case .online: return .online
        case .unknown, nil: return .unbekannt
        }
    }
}
