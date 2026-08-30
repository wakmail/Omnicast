// SPDX-License-Identifier: GPL-3.0-or-later

import OmnicastCore
import SwiftUI

public struct AISettingsView: View {
    @ObservedObject private var store: SettingsStore
    private let keyStore: AIKeyStore
    @State private var keys: [AIProviderIdentifier: String] = [:]
    @State private var errorMessage: String?
    @Environment(\.colorScheme) private var colorScheme

    public init(store: SettingsStore, keyStore: AIKeyStore) {
        self.store = store
        self.keyStore = keyStore
    }

    public var body: some View {
        Form {
            Picker("Default provider", selection: providerBinding) {
                ForEach(AIProviderIdentifier.allCases) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }

            TextField("Default model", text: modelBinding)

            Section("Provider API Keys") {
                keyRow(.openAI)
                keyRow(.anthropic)
                keyRow(.gemini)
                keyRow(.openAICompatible)
            }

            Section("OpenAI Compatible Provider") {
                Toggle("Enable Custom Endpoint", isOn: compatibleEnabledBinding)
                TextField("Base URL", text: compatibleURLBinding)
                    .disabled(!store.settings.openAICompatibleEnabled)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(LauncherTheme.Typography.footerTitle)
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .padding(LauncherTheme.Metrics.searchHorizontalPadding)
        .task { loadKeys() }
    }

    private func keyRow(_ provider: AIProviderIdentifier) -> some View {
        HStack {
            SecureField(provider.displayName, text: keyBinding(provider))
            Button("Save") { saveKey(provider) }
                .buttonStyle(.bordered)
        }
    }

    private var providerBinding: Binding<AIProviderIdentifier> {
        Binding(
            get: { store.settings.defaultAIProvider },
            set: { value in update { $0.defaultAIProvider = value } }
        )
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { store.settings.defaultAIModel },
            set: { value in update { $0.defaultAIModel = value } }
        )
    }

    private var compatibleEnabledBinding: Binding<Bool> {
        Binding(
            get: { store.settings.openAICompatibleEnabled },
            set: { value in update { $0.openAICompatibleEnabled = value } }
        )
    }

    private var compatibleURLBinding: Binding<String> {
        Binding(
            get: { store.settings.openAICompatibleBaseURL },
            set: { value in update { $0.openAICompatibleBaseURL = value } }
        )
    }

    private func keyBinding(_ provider: AIProviderIdentifier) -> Binding<String> {
        Binding(
            get: { keys[provider] ?? "" },
            set: { keys[provider] = $0 }
        )
    }

    private func loadKeys() {
        do {
            for provider in AIProviderIdentifier.allCases where provider != .ollama {
                keys[provider] = try keyStore.apiKey(for: provider) ?? ""
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveKey(_ provider: AIProviderIdentifier) {
        do {
            try keyStore.setAPIKey(keys[provider] ?? "", for: provider)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func update(_ change: (inout AppSettings) -> Void) {
        do {
            try store.update(change)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
