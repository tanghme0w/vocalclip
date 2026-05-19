import Foundation

/// 用于 Widget Extension (AppIntent) 与主 App 之间通过 App Group 通信。
///
/// 在 Xcode 中需要为主 App 和 Widget Extension 同时启用 App Groups capability，
/// 并使用同一个 group 标识。如果未开启，则降级为同进程内存通信。
enum VocalClipIntentBridge {
    static let appGroup = "group.me0w.vocalclip"
    private static let key = "vocalclip.intent.requested-action"
    private static let timestampKey = "vocalclip.intent.requested-action.timestamp"
    private static let darwinNotificationName = "me0w.vocalclip.intent-requested" as CFString

    enum Action: String, Codable {
        case readClipboard
        case pause
        case resume
        case stop
    }

    /// 共享存储；如果 App Group 未配置则回落到 standard。
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static var requestedAction: Action? {
        get {
            guard let raw = defaults.string(forKey: key) else { return nil }
            return Action(rawValue: raw)
        }
        set {
            if let v = newValue {
                defaults.set(v.rawValue, forKey: key)
                defaults.set(Date().timeIntervalSince1970, forKey: timestampKey)
                postNotification()
            } else {
                defaults.removeObject(forKey: key)
                defaults.removeObject(forKey: timestampKey)
            }
        }
    }

    static func consume() -> Action? {
        let action = requestedAction
        requestedAction = nil
        return action
    }

    private static func postNotification() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center,
                                             CFNotificationName(darwinNotificationName),
                                             nil, nil, true)
    }

    /// 主 App 注册回调。
    @MainActor
    static func observe(_ handler: @escaping @MainActor () -> Void) {
        BridgeObserver.shared.handler = handler
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(BridgeObserver.shared).toOpaque()
        CFNotificationCenterAddObserver(
            center,
            observer,
            { _, _, _, _, _ in
                Task { @MainActor in
                    BridgeObserver.shared.handler?()
                }
            },
            darwinNotificationName,
            nil,
            .deliverImmediately
        )
    }
}

@MainActor
private final class BridgeObserver {
    static let shared = BridgeObserver()
    var handler: (@MainActor () -> Void)?
}
