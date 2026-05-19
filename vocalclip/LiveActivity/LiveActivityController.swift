import Foundation
import ActivityKit

/// 管理 VocalClip Live Activity 的生命周期。
@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()

    private var activity: Activity<VocalClipActivityAttributes>?

    /// 在 App 启动 / 进入前台时调用，确保有一个待命中的 Live Activity。
    func ensureStandby() {
        guard supported else { return }
        if activity != nil { return }
        let attributes = VocalClipActivityAttributes()
        let state = VocalClipActivityAttributes.ContentState(phase: .standby)
        let content = ActivityContent(state: state, staleDate: nil)
        do {
            activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
        } catch {
            // 用户关闭了 Live Activity 权限 / 系统不支持
            #if DEBUG
            print("[LiveActivity] request failed: \(error)")
            #endif
        }
    }

    func update(phase: VocalClipActivityAttributes.ContentState.Phase,
                title: String,
                currentTime: TimeInterval = 0,
                duration: TimeInterval = 0) {
        guard let activity else { return }
        let progress: Double = duration > 0 ? min(1, max(0, currentTime / duration)) : 0
        let state = VocalClipActivityAttributes.ContentState(
            phase: phase,
            title: title,
            progress: progress,
            currentTime: currentTime,
            duration: duration
        )
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func end() {
        guard let activity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        self.activity = nil
    }

    private var supported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }
}
