import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section(settings.t("settings_appearance")) {
                Picker(settings.t("settings_appearance"), selection: $settings.appearanceRaw) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(settings.t(mode.titleKey)).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section(settings.t("settings_language")) {
                Picker(settings.t("settings_language"), selection: $settings.languageRaw) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang == .system ? settings.t("language_system") : lang.nativeName)
                            .tag(lang.rawValue)
                    }
                }
                .labelsHidden()
            }

            // Exemple de secret stocké dans le Keychain. Adapte ou supprime.
            Section(settings.t("settings_apikey")) {
                SecureField(settings.t("apikey_placeholder"), text: $settings.apiKey)
                Text(settings.apiKeyConfigured
                     ? settings.t("apikey_present")
                     : settings.t("apikey_absent"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(settings.t("apikey_help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(settings.t("settings_about")) {
                Text(settings.t("settings_about_text"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .frame(width: 460, height: 420)
        #endif
    }
}
