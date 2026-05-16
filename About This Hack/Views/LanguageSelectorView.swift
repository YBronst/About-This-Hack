//
//  LanguageSelectorView.swift
//  About This Hack
//
//  Language selector view with flag emojis (English, Spanish, French, Italian).
//

import SwiftUI

struct LanguageItem: Identifiable {
    let id: String
    let code: String
    let name: String
    let flag: String

    init(code: String, name: String, flag: String) {
        id = code
        self.code = code
        self.name = name
        self.flag = flag
    }
}

struct LanguageSelectorView: View {
    var onDismiss: () -> Void
    @State private var selectedLanguage: String
    @State private var showRestartAlert = false
    private let initialLanguage: String

    /// Available languages
    private let languages: [LanguageItem] = [
        LanguageItem(code: "en", name: "English", flag: "🇬🇧"),
        LanguageItem(code: "es", name: "Español", flag: "🇪🇸"),
        LanguageItem(code: "de", name: "Deutsch", flag: "🇩🇪"),
        LanguageItem(code: "fr", name: "Français", flag: "🇫🇷"),
        LanguageItem(code: "it", name: "Italiano", flag: "🇮🇹"),
    ]

    private var hasLanguageChanged: Bool {
        selectedLanguage != initialLanguage
    }

    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        // Load current language preference from UserDefaults
        let currentLang = UserDefaults.standard.stringArray(forKey: "AppleLanguages")?
            .first?.components(separatedBy: "-").first
            ?? Locale.current.language.languageCode?.identifier
            ?? "en"
        _selectedLanguage = State(initialValue: currentLang)
        initialLanguage = currentLang
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(NSLocalizedString("Language selector title", comment: "Language selector title"))
                .font(.title2)
                .padding(.top)

            List(languages, selection: $selectedLanguage) { language in
                HStack {
                    Text(language.flag)
                        .font(.title2)
                    Text(language.name)
                        .font(.body)
                }
                .tag(language.code)
                .padding(.vertical, 4)
            }
            .scrollContentBackground(.hidden)
            .background(.ultraThinMaterial)
            .frame(width: 222, height: 208)
            .border(Color.gray.opacity(0.3), width: 1)

            HStack(spacing: 12) {
                Button(NSLocalizedString("Cancel", comment: "Cancel button")) {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(NSLocalizedString("OK", comment: "OK button")) {
                    if hasLanguageChanged {
                        saveLanguagePreference()
                        showRestartAlert = true
                    } else {
                        onDismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom)
        }
        .padding()
        .frame(width: 280)
        .background(.ultraThinMaterial, ignoresSafeAreaEdges: .all)
        .alert(
            NSLocalizedString("Language changed alert title", comment: "Language changed alert title"),
            isPresented: $showRestartAlert
        ) {
            Button(NSLocalizedString("OK", comment: "OK button")) {
                onDismiss()
            }
        } message: {
            Text(NSLocalizedString("Language changed message", comment: "Language changed message"))
        }
    }

    private func saveLanguagePreference() {
        UserDefaults.standard.set([selectedLanguage], forKey: "AppleLanguages")
    }
}
