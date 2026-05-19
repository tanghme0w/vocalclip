import Foundation
import SwiftUI
import Combine

struct TTSSettings: Codable, Equatable {
    var provider: TTSProvider = .volcanoBidirectional
    var appId: String = ""
    var accessToken: String = ""
    var resourceId: String = "volc.service_type.10029"
    var voiceType: String = "zh_female_qingxin_mars_bigtts"
    var speedRatio: Double = 1.0
    var enableLiveActivity: Bool = true

    enum TTSProvider: String, Codable, CaseIterable, Identifiable {
        case volcanoBidirectional
        case systemFallback

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .volcanoBidirectional: return "火山引擎大模型语音"
            case .systemFallback: return "系统语音（兜底）"
            }
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    static let key = "vocalclip.settings.v1"

    @Published var settings: TTSSettings {
        didSet { persist() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(TTSSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = TTSSettings()
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}

struct VolcanoVoicePreset: Identifiable, Hashable {
    let id: String
    let displayName: String
}

enum VolcanoVoiceLibrary {
    static let presets: [VolcanoVoicePreset] = [
        VolcanoVoicePreset(id: "zh_female_qingxin_mars_bigtts", displayName: "清新女声 · 默认"),
        VolcanoVoicePreset(id: "zh_male_yangguang_mars_bigtts", displayName: "阳光男声"),
        VolcanoVoicePreset(id: "zh_female_wenrou_mars_bigtts", displayName: "温柔女声"),
        VolcanoVoicePreset(id: "zh_male_M392_conversation_wvae_bigtts", displayName: "对话男声"),
        VolcanoVoicePreset(id: "zh_female_tianmei_mars_bigtts", displayName: "甜美女声"),
        VolcanoVoicePreset(id: "zh_female_shaonv_mars_bigtts", displayName: "少女音"),
        VolcanoVoicePreset(id: "zh_male_baqiqingnian_mars_bigtts", displayName: "霸气青年")
    ]
}
