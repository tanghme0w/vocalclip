import Foundation
import ActivityKit

/// 灵动岛 / Live Activity 属性。
/// 同一份定义会被主 App 与 Widget Extension target 引用，
/// 因此该文件需同时加入两个 target 的 membership。
struct VocalClipActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// 朗读状态
        public enum Phase: String, Codable {
            case standby   // 待命：尚未朗读
            case playing
            case paused
            case finished
        }

        public var phase: Phase
        public var title: String        // 当前朗读片段的预览（首行）
        public var progress: Double     // 0~1
        public var currentTime: TimeInterval
        public var duration: TimeInterval

        public init(
            phase: Phase = .standby,
            title: String = "等待粘贴",
            progress: Double = 0,
            currentTime: TimeInterval = 0,
            duration: TimeInterval = 0
        ) {
            self.phase = phase
            self.title = title
            self.progress = progress
            self.currentTime = currentTime
            self.duration = duration
        }
    }

    /// 静态属性 — App 名等，不会随状态变化
    public var appName: String

    public init(appName: String = "VocalClip") {
        self.appName = appName
    }
}
