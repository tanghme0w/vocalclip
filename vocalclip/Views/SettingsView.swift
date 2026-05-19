import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @State private var showAccessKey: Bool = false
    @State private var cacheSize: Int64 = 0

    var body: some View {
        Form {
            Section("TTS 服务商") {
                Picker("服务", selection: $settingsStore.settings.provider) {
                    ForEach(TTSSettings.TTSProvider.allCases) { p in
                        Text(p.displayName).tag(p)
                    }
                }
            }

            if settingsStore.settings.provider == .volcanoBidirectional {
                Section("火山引擎凭据") {
                    TextField("App ID", text: $settingsStore.settings.appId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    HStack {
                        if showAccessKey {
                            TextField("Access Token", text: $settingsStore.settings.accessToken)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("Access Token", text: $settingsStore.settings.accessToken)
                        }
                        Button {
                            showAccessKey.toggle()
                        } label: {
                            Image(systemName: showAccessKey ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    TextField("Resource ID", text: $settingsStore.settings.resourceId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(.secondary)
                }

                Section("音色") {
                    Picker("音色", selection: $settingsStore.settings.voiceType) {
                        ForEach(VolcanoVoiceLibrary.presets) { preset in
                            Text(preset.displayName).tag(preset.id)
                        }
                    }
                }
            }

            Section("朗读") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("语速")
                        Spacer()
                        Text(String(format: "%.2fx", settingsStore.settings.speedRatio))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settingsStore.settings.speedRatio, in: 0.5...2.0, step: 0.05)
                }
                Toggle("启用灵动岛", isOn: $settingsStore.settings.enableLiveActivity)
            }

            Section("缓存") {
                HStack {
                    Text("音频缓存占用")
                    Spacer()
                    Text(formatBytes(cacheSize))
                        .foregroundStyle(.secondary)
                }
                Button(role: .destructive) {
                    AudioCacheManager.clearAll()
                    refreshCacheSize()
                } label: {
                    Label("清空音频缓存", systemImage: "trash")
                }
            }
        }
        .onAppear { refreshCacheSize() }
    }

    private func refreshCacheSize() {
        cacheSize = AudioCacheManager.totalSize()
    }

    private func formatBytes(_ count: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: count)
    }
}
