//
//  ThoskaCardReader.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 26.10.26.
//

import Foundation
import Combine
import CoreNFC

/// Guthaben, das von einer Thoska-Chipkarte per NFC ausgelesen wurde.
struct ThoskaBalance {
    let cardId: String
    let balance: Double
    let lastTransaction: Double
    let scannedAt: Date
}

enum ThoskaCardReaderError: LocalizedError {
    case nfcNotAvailable
    case unsupportedCardType

    var errorDescription: String? {
        switch self {
        case .nfcNotAvailable:
            return "Dieses Gerät unterstützt kein NFC."
        case .unsupportedCardType:
            return "Dieser Kartentyp wird nicht unterstützt."
        }
    }
}

/// Liest das Guthaben einer Thoska-/Mensa-Chipkarte (MIFARE DESFire) per NFC aus.
///
/// Die Karte wird über das native DESFire-Kommandoset angesprochen, das als
/// Pseudo-APDU verpackt wird (CLA 0x90). App-ID und Datei-ID sind feste,
/// kartenseitig vorgegebene Werte der Studentenwerke, nötig für die
/// Interoperabilität mit der Kartenhardware.
@MainActor
final class ThoskaCardReader: NSObject, ObservableObject {
    @Published private(set) var isScanning = false
    @Published private(set) var balance: ThoskaBalance?
    @Published var errorMessage: String?

    private static let applicationIdentifier: [UInt8] = [0x5F, 0x84, 0x15]
    private static let balanceFileId: UInt8 = 0x01

    /// Hält die laufende Session am Leben — ohne diese Referenz würde ARC sie
    /// direkt nach Rückkehr aus scan() wieder freigeben.
    private var activeSession: NFCTagReaderSession?

    func scan() {
        guard NFCTagReaderSession.readingAvailable else {
            errorMessage = ThoskaCardReaderError.nfcNotAvailable.localizedDescription
            return
        }

        guard let session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self, queue: nil) else {
            errorMessage = ThoskaCardReaderError.nfcNotAvailable.localizedDescription
            return
        }

        errorMessage = nil
        isScanning = true
        activeSession = session

        session.alertMessage = "Halte deine Thoska-Karte an die Rückseite des iPhones."
        session.begin()
    }
}

extension ThoskaCardReader: NFCTagReaderSessionDelegate {
    nonisolated func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        Task { @MainActor in
            isScanning = false
            activeSession = nil
            if let readerError = error as? NFCReaderError,
               readerError.code == .readerSessionInvalidationErrorUserCanceled {
                return
            }
            errorMessage = error.localizedDescription
        }
    }

    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else { return }
        Task {
            do {
                let result = try await Self.readBalance(session: session, tag: tag)
                await MainActor.run {
                    self.balance = result
                    self.isScanning = false
                }
                session.invalidate()
            } catch {
                let message = error.localizedDescription
                await MainActor.run {
                    self.errorMessage = message
                    self.isScanning = false
                }
                session.invalidate(errorMessage: message)
            }
        }
    }

    private static func readBalance(session: NFCTagReaderSession, tag: NFCTag) async throws -> ThoskaBalance {
        try await session.connect(to: tag)

        let transport = try CardTransport(tag: tag)
        let cardId = transport.identifier.hexString

        _ = try await transport.send(desfireCommand(.selectApplication, parameter: applicationIdentifier))
        let valueResponse = try await transport.send(desfireCommand(.getValue, parameter: [balanceFileId]))
        let settingsResponse = try await transport.send(desfireCommand(.getFileSettings, parameter: [balanceFileId]))

        return ThoskaBalance(
            cardId: cardId,
            balance: parseBalance(from: valueResponse),
            lastTransaction: parseLastTransaction(from: settingsResponse),
            scannedAt: Date()
        )
    }

    // MARK: - DESFire-Kommandos

    private enum DESFireCommand: UInt8 {
        case selectApplication = 0x5A
        case getValue = 0x6C
        case getFileSettings = 0xF5
    }

    /// Verpackt ein natives DESFire-Kommando als Pseudo-APDU (CLA 0x90).
    private static func desfireCommand(_ command: DESFireCommand, parameter: [UInt8]) -> Data {
        var bytes: [UInt8] = [0x90, command.rawValue, 0x00, 0x00, UInt8(parameter.count)]
        bytes.append(contentsOf: parameter)
        bytes.append(0x00)
        return Data(bytes)
    }

    /// Die Value-Antwort besteht aus einem little-endian Int32 (in Tausendstel der Währung) + 2 Statusbytes.
    private static func parseBalance(from data: Data) -> Double {
        let rawValue = data.prefix(4).reversed().reduce(0) { ($0 << 8) | Int($1) }
        return Double(rawValue) / 1000
    }

    /// Der zuletzt gebuchte Betrag steht an einem festen Offset innerhalb der File-Settings-Antwort.
    private static func parseLastTransaction(from data: Data) -> Double {
        let bytes = [UInt8](data)
        guard bytes.count > 13 else { return 0 }
        let rawValue = (Int(bytes[13]) << 8) | Int(bytes[12])
        return Double(rawValue) / 1000
    }
}

/// Vereinheitlicht den Zugriff auf MIFARE- und ISO7816-NFC-Tags, je nachdem wie sich die Karte meldet.
private enum CardTransport {
    case miFare(NFCMiFareTag)
    case iso7816(NFCISO7816Tag)

    init(tag: NFCTag) throws {
        switch tag {
        case .miFare(let mifareTag):
            self = .miFare(mifareTag)
        case .iso7816(let isoTag):
            self = .iso7816(isoTag)
        default:
            throw ThoskaCardReaderError.unsupportedCardType
        }
    }

    var identifier: Data {
        switch self {
        case .miFare(let tag): return tag.identifier
        case .iso7816(let tag): return tag.identifier
        }
    }

    func send(_ apdu: Data) async throws -> Data {
        switch self {
        case .miFare(let tag):
            return try await withCheckedThrowingContinuation { continuation in
                tag.sendMiFareCommand(commandPacket: apdu) { data, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: data)
                    }
                }
            }
        case .iso7816(let tag):
            guard let command = NFCISO7816APDU(data: apdu) else {
                throw ThoskaCardReaderError.unsupportedCardType
            }
            return try await withCheckedThrowingContinuation { continuation in
                tag.sendCommand(apdu: command) { data, _, _, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: data)
                    }
                }
            }
        }
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

private extension NFCTagReaderSession {
    func connect(to tag: NFCTag) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.connect(to: tag) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
