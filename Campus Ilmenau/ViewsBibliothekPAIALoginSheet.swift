//
//  ViewsBibliothekPAIALoginSheet.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 27.10.26.
//

import SwiftUI
import VisionKit

/// Anmelde-Sheet für die PAIA-Bibliothekssitzung. Wird gezeigt, sobald keine
/// gültige Session besteht (initial oder nach Ablauf/Serverfehler).
/// Diese Hülle kümmert sich um Service und Zustand, die Oberfläche steckt in `PAIALoginContent`.
struct PAIALoginSheet: View {
    @ObservedObject var service: PAIAService
    var onSuccess: () -> Void
    var onOpenCatalog: () -> Void

    @State private var username: String
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoggingIn = false
    @Environment(\.dismiss) private var dismiss

    init(service: PAIAService, onSuccess: @escaping () -> Void, onOpenCatalog: @escaping () -> Void = {}) {
        self.service = service
        self.onSuccess = onSuccess
        self.onOpenCatalog = onOpenCatalog
        // Nach Ablauf steht die Benutzernummer noch im Speicher; nach manuellem Abmelden bleibt das Feld leer.
        _username = State(initialValue: service.sessionExpired ? (service.lastUsername ?? "") : "")
    }

    var body: some View {
        PAIALoginContent(
            reason: service.sessionExpired ? .expired : .missing,
            username: $username,
            password: $password,
            errorMessage: errorMessage,
            isLoggingIn: isLoggingIn,
            onLogin: login,
            onCancel: { dismiss() },
            onOpenCatalog: onOpenCatalog
        )
        // Der Fehlerkasten verschwindet, sobald man weitertippt.
        .onChange(of: username) { errorMessage = nil }
        .onChange(of: password) { errorMessage = nil }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func login() {
        guard !isLoggingIn else { return }
        isLoggingIn = true
        errorMessage = nil

        Task {
            do {
                try await service.login(username: username, password: password)
                isLoggingIn = false
                onSuccess()
            } catch {
                isLoggingIn = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// Oberfläche des Login-Sheets nach `BibLogin.dc.html`, ohne Service, damit alle Zustände als Preview möglich sind.
struct PAIALoginContent: View {
    /// Warum das Sheet erscheint: nie angemeldet bzw. abgemeldet, oder Sitzung abgelaufen.
    enum Reason {
        case missing
        case expired
    }

    private enum Field: Hashable {
        case username
        case password
    }

    let reason: Reason
    @Binding var username: String
    @Binding var password: String
    let errorMessage: String?
    let isLoggingIn: Bool
    let onLogin: () -> Void
    let onCancel: () -> Void
    let onOpenCatalog: () -> Void
    /// Der Button „Scannen“ erscheint nur auf Geräten, die Barcodes mit der Kamera lesen können (nicht im Simulator).
    var scanSupported: Bool = DataScannerViewController.isSupported
    /// Nur für Previews: Nummer, die so erscheint, als käme sie schon vom Scanner.
    var initiallyScanned: String?

    @State private var showsPassword = false
    @State private var showsScanner = false
    /// Nummer, die der Scanner gelesen hat. Solange das Feld sie unverändert zeigt, steht „Von deiner Thoska übernommen“.
    @State private var scannedNumber: String?
    /// Wohin der Fokus nach dem Schließen des Scanners geht.
    @State private var focusAfterScanner: Field?
    @FocusState private var focus: Field?

    private var canLogin: Bool {
        !isLoggingIn && !username.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    private var isExpired: Bool { reason == .expired }

    private var isFromThoska: Bool {
        scannedNumber != nil && scannedNumber == username
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header

                        if isExpired {
                            notice
                        }
                        if let errorMessage {
                            errorBox(errorMessage)
                        }

                        usernameField
                        passwordField

                        PrimaryButton("Anmelden", isLoading: isLoggingIn, action: onLogin)
                            .disabled(!canLogin)
                            .accessibilityLabel(isLoggingIn ? "Anmelden, bitte warten" : "Anmelden")

                        Button(action: onOpenCatalog) {
                            Text("Ohne Anmeldung im Katalog suchen")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color(.accent))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }

                        Spacer(minLength: 8)

                        Text("Anmeldung über die PAIA-Schnittstelle der Universitätsbibliothek. Benutzernummer und Passwort werden nicht gespeichert – nach einem Neustart der App meldest du dich neu an.")
                            .font(.caption)
                            .foregroundStyle(Color(.textTertiary))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                    // Fußnote steht am unteren Rand, solange der Inhalt kürzer ist als der Bildschirm.
                    .frame(minHeight: proxy.size.height, alignment: .top)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .background(Color(.background))
            .navigationTitle("Bibliothek")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen", action: onCancel)
                        .foregroundStyle(Color(.accent))
                }
            }
        }
        .onChange(of: errorMessage) { _, newValue in
            if let newValue {
                AccessibilityNotification.Announcement("Anmeldung fehlgeschlagen. \(newValue)").post()
            }
        }
    }

    // MARK: - Teile

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isExpired ? "Bitte erneut anmelden" : "Bei der Bibliothek anmelden")
                .display(size: 28, relativeTo: .title)
                .foregroundStyle(Color(.textPrimary))
                .accessibilityAddTraits(.isHeader)
            Text(isExpired
                 ? "Dann siehst du deine Ausleihen wieder und kannst verlängern."
                 : "Um deine Ausleihen und Vormerkungen zu sehen und Leihfristen zu verlängern.")
                .foregroundStyle(Color(.textSecondary))
        }
    }

    private var notice: some View {
        messageBox(
            systemImage: "clock",
            background: Color(.warningSoft),
            foreground: Color(.warning)
        ) {
            Text("Sitzung abgelaufen, bitte erneut anmelden.")
                .font(.subheadline.weight(.semibold))
        }
    }

    private func errorBox(_ message: String) -> some View {
        messageBox(
            systemImage: "exclamationmark.circle",
            background: Color(.dangerSoft),
            foreground: Color(.danger)
        ) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Anmeldung fehlgeschlagen")
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.subheadline)
            }
        }
    }

    private func messageBox<Content: View>(
        systemImage: String,
        background: Color,
        foreground: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .accessibilityHidden(true)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(foreground)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var usernameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Benutzernummer")
            inputBox(highlight: isFromThoska) {
                TextField("z. B. 0001234567", text: $username)
                    .focused($focus, equals: .username)
                    .textContentType(.username)
                    // Ziffern zuerst, aber mit Return-Taste und ohne Sperre für Buchstaben.
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .onSubmit { focus = .password }
                    .padding(.vertical, 14)

                if scanSupported {
                    scanButton
                }
            }
            Text(isFromThoska ? "Von deiner Thoska übernommen." : "Steht als Barcode auf der Rückseite deiner Thoska.")
                .font(.caption)
                .foregroundStyle(Color(.textTertiary))
                .padding(.horizontal, 2)
        }
        // Sobald man selbst tippt, geht „Von deiner Thoska übernommen“ und der grüne Rand zurück.
        .onChange(of: username) { _, newValue in
            if let scannedNumber, scannedNumber != newValue { self.scannedNumber = nil }
        }
        .onAppear {
            if scannedNumber == nil { scannedNumber = initiallyScanned }
        }
        .fullScreenCover(isPresented: $showsScanner, onDismiss: applyFocusAfterScanner) {
            BenutzernummerScannerView(
                onScanned: { number in
                    scannedNumber = number
                    username = number
                    focusAfterScanner = .password
                    showsScanner = false
                },
                onCancel: { showsScanner = false },
                onEnterManually: {
                    focusAfterScanner = .username
                    showsScanner = false
                }
            )
        }
    }

    /// Kleiner Button im Feld: Symbol und „Scannen“, 36 pt hoch, die Tippfläche bleibt 44 pt.
    private var scanButton: some View {
        Button {
            focus = nil
            showsScanner = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "barcode.viewfinder")
                    .accessibilityHidden(true)
                Text("Scannen")
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color(.textPrimary))
            .padding(.horizontal, 10)
            .frame(minHeight: 36)
            .background(Color(.surfaceSecondary), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .padding(.trailing, 3)
        .accessibilityLabel("Benutzernummer mit der Kamera scannen")
    }

    /// Nach dem Schließen des Scanners: Passwort (nach Treffer) bzw. Benutzernummer (nach „selbst eingeben“) fokussieren.
    private func applyFocusAfterScanner() {
        guard let target = focusAfterScanner else { return }
        focusAfterScanner = nil
        DispatchQueue.main.async { focus = target }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Passwort")
            inputBox {
                Group {
                    if showsPassword {
                        TextField("Passwort", text: $password)
                    } else {
                        SecureField("Passwort", text: $password)
                    }
                }
                .focused($focus, equals: .password)
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .onSubmit { if canLogin { onLogin() } }
                .padding(.vertical, 14)

                Button {
                    let hadFocus = focus == .password
                    showsPassword.toggle()
                    // Das Umschalten tauscht das Textfeld aus, dabei geht der Fokus sonst verloren.
                    if hadFocus {
                        DispatchQueue.main.async { focus = .password }
                    }
                } label: {
                    Image(systemName: showsPassword ? "eye.slash" : "eye")
                        .font(.title3)
                        .foregroundStyle(Color(.textSecondary))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(showsPassword ? "Passwort verbergen" : "Passwort anzeigen")
            }
        }
    }

    private func fieldLabel(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color(.textSecondary))
            .padding(.horizontal, 2)
    }

    /// Eingabefeld: `surface` mit feiner Kontur, Ecken 12, mindestens 50 pt hoch.
    /// Mit `highlight` (Nummer vom Scanner) bekommt es einen grünen Rand mit zarter Aura.
    private func inputBox<Content: View>(highlight: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 4) {
            content()
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .frame(minHeight: 50)
        .background(Color(.surface), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .background {
            if highlight {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(.green).opacity(0.25), lineWidth: 6)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(highlight ? Color(.green) : Color(.separator), lineWidth: 1)
        }
    }
}
