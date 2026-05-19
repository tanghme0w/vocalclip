import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

struct VocalClipLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VocalClipActivityAttributes.self) { context in
            // 锁屏 / Lock Screen / Banner
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: iconForPhase(context.state.phase))
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.duration > 0 {
                        Text(timeString(context.state.currentTime) + " / " + timeString(context.state.duration))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        if context.state.phase == .standby {
                            Button(intent: ReadClipboardIntent()) {
                                Label("朗读剪贴板", systemImage: "doc.on.clipboard")
                            }
                            .tint(Color.accentColor)
                            .buttonStyle(.borderedProminent)
                        } else {
                            if context.state.phase == .playing {
                                Button(intent: PauseReadingIntent()) {
                                    Label("暂停", systemImage: "pause.fill")
                                }
                                .tint(.orange)
                            } else {
                                Button(intent: ResumeReadingIntent()) {
                                    Label("继续", systemImage: "play.fill")
                                }
                                .tint(.green)
                            }
                            Button(intent: StopReadingIntent()) {
                                Label("停止", systemImage: "stop.fill")
                            }
                            .tint(.red)
                        }
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
            } compactLeading: {
                Image(systemName: iconForPhase(context.state.phase))
                    .foregroundStyle(Color.accentColor)
            } compactTrailing: {
                if context.state.duration > 0 {
                    Text(timeString(context.state.currentTime))
                        .font(.caption2.monospacedDigit())
                } else {
                    Text("待命")
                        .font(.caption2)
                }
            } minimal: {
                Image(systemName: iconForPhase(context.state.phase))
                    .foregroundStyle(Color.accentColor)
            }
            .widgetURL(URL(string: "vocalclip://read-clipboard"))
            .keylineTint(Color.accentColor)
        }
    }

    private func iconForPhase(_ phase: VocalClipActivityAttributes.ContentState.Phase) -> String {
        switch phase {
        case .standby: return "waveform"
        case .playing: return "speaker.wave.2.fill"
        case .paused: return "pause.circle.fill"
        case .finished: return "checkmark.circle.fill"
        }
    }

    private func timeString(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

private struct LockScreenView: View {
    let state: VocalClipActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                Text("VocalClip")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(phaseText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(state.title)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(2)
            if state.duration > 0 {
                ProgressView(value: state.progress)
                    .tint(Color.accentColor)
            }
        }
        .padding()
    }

    private var phaseText: String {
        switch state.phase {
        case .standby: return "待命中"
        case .playing: return "朗读中"
        case .paused: return "已暂停"
        case .finished: return "已完成"
        }
    }
}

// MARK: - App Intents (灵动岛按钮)

struct ReadClipboardIntent: AppIntent {
    static var title: LocalizedStringResource = "朗读剪贴板"
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // 打开 App，由 App 监听到该 Intent 后从剪贴板取内容朗读。
        // 由于沙盒限制，剪贴板必须在前台读取；openAppWhenRun=true 已经触发前台。
        VocalClipIntentBridge.requestedAction = .readClipboard
        return .result()
    }
}

struct PauseReadingIntent: AppIntent {
    static var title: LocalizedStringResource = "暂停朗读"
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        VocalClipIntentBridge.requestedAction = .pause
        return .result()
    }
}

struct ResumeReadingIntent: AppIntent {
    static var title: LocalizedStringResource = "继续朗读"
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        VocalClipIntentBridge.requestedAction = .resume
        return .result()
    }
}

struct StopReadingIntent: AppIntent {
    static var title: LocalizedStringResource = "停止朗读"
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        VocalClipIntentBridge.requestedAction = .stop
        return .result()
    }
}
