//
//  ViewsBibliothekPAIALoginSheet.swift
//  Campus Ilmenau
//
//  Created by Kai Gothe on 27.10.26.
//

import SwiftUI

/// Anmelde-Sheet für die PAIA-Bibliothekssitzung. Wird gezeigt, sobald keine
/// gültige Session besteht (initial oder nach Ablauf/Serverfehler).
struct PAIALoginSheet: View {
    @ObservedObject var service: PAIAService
    var onSuccess: () -> Void

    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoggingIn = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nutzername", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Passwort", text: $password)
                        .textContentType(.password)
                } footer: {
                    Text("Melde dich mit deiner Bibliotheks-Nutzernummer und deinem Passwort an.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Bibliothek anmelden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoggingIn {
                        ProgressView()
                    } else {
                        Button("Anmelden") {
                            login()
                        }
                        .disabled(username.isEmpty || password.isEmpty)
                    }
                }
            }
        }
    }

    private func login() {
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

#Preview {
    PAIALoginSheet(service: PAIAService(), onSuccess: {})
}
