import Foundation

enum TTSError: LocalizedError {
    case missingCredentials
    case invalidResponse(String)
    case network(Error)
    case server(code: String, message: String)
    case cancelled
    case unsupportedAudioFormat

    var errorDescription: String? {
        switch self {
        case .missingCredentials: return "请先在设置中填写火山引擎 App ID 和 Access Token"
        case .invalidResponse(let detail): return "服务端响应异常：\(detail)"
        case .network(let err): return "网络错误：\(err.localizedDescription)"
        case .server(let code, let message): return "TTS 服务错误（\(code)）：\(message)"
        case .cancelled: return "已取消"
        case .unsupportedAudioFormat: return "音频格式不受支持"
        }
    }
}

protocol TTSService: Sendable {
    /// 一次性合成整段文本，返回完整音频数据（mp3）。
    /// - Parameters:
    ///   - text: 待合成文本
    ///   - settings: 当前设置
    ///   - onProgress: 流式收到音频片段时回调（可选）
    func synthesize(
        text: String,
        settings: TTSSettings,
        onProgress: (@Sendable (Data) -> Void)?
    ) async throws -> Data
}
