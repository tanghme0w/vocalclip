import SwiftUI
import SwiftData

struct UserInfoView: View {
    @Query private var histories: [ReadingHistory]
    @EnvironmentObject var settingsStore: SettingsStore

    var body: some View {
        Form {
            Section {
                HStack {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.accentColor, .accentColor.opacity(0.6)],
                                                  startPoint: .top, endPoint: .bottom))
                            .frame(width: 56, height: 56)
                        Image(systemName: "person.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("本地用户")
                            .font(.headline)
                        Text(settingsStore.settings.appId.isEmpty ? "尚未配置火山引擎" : "App ID · \(maskedAppId)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }

            Section("使用统计") {
                LabeledContent("历史条数", value: "\(histories.count)")
                LabeledContent("累计已朗读时长", value: formatTotalDuration())
            }

            Section("关于") {
                LabeledContent("应用", value: "VocalClip")
                LabeledContent("版本", value: "1.0")
            }
        }
    }

    private var maskedAppId: String {
        let id = settingsStore.settings.appId
        guard id.count > 4 else { return id }
        let prefix = id.prefix(2)
        let suffix = id.suffix(2)
        return "\(prefix)****\(suffix)"
    }

    private func formatTotalDuration() -> String {
        let total = histories.reduce(0.0) { $0 + $1.totalDuration }
        let minutes = Int(total / 60)
        let seconds = Int(total) % 60
        return "\(minutes) 分 \(seconds) 秒"
    }
}
