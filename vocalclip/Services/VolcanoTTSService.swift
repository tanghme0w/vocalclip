import Foundation

/// 火山引擎大模型语音合成 · 双向流式 WebSocket 实现
/// 文档参考：openspeech.bytedance.com/api/v3/tts/bidirection
///
/// 二进制协议帧结构：
///   header(4) | event(4) | [session_id_size(4) | session_id] | payload_size(4) | payload
final class VolcanoTTSService: NSObject, TTSService, @unchecked Sendable {
    static let endpoint = URL(string: "wss://openspeech.bytedance.com/api/v3/tts/bidirection")!

    // MARK: - Event codes
    private enum Event: Int32 {
        // client → server
        case startConnection = 1
        case finishConnection = 2
        case startSession = 100
        case cancelSession = 101
        case finishSession = 102
        case taskRequest = 200

        // server → client
        case connectionStarted = 50
        case connectionFailed = 51
        case connectionFinished = 52
        case sessionStarted = 150
        case sessionCanceled = 151
        case sessionFinished = 152
        case sessionFailed = 153
        case ttsSentenceStart = 350
        case ttsSentenceEnd = 351
        case ttsResponse = 352
    }

    /// 当前事件是否携带 session_id
    private static func eventCarriesSession(_ event: Int32) -> Bool {
        switch event {
        case Event.startConnection.rawValue, Event.finishConnection.rawValue,
             Event.connectionStarted.rawValue, Event.connectionFailed.rawValue,
             Event.connectionFinished.rawValue:
            return false
        default:
            return true
        }
    }

    func synthesize(
        text: String,
        settings: TTSSettings,
        onProgress: (@Sendable (Data) -> Void)?
    ) async throws -> Data {
        guard !settings.appId.isEmpty, !settings.accessToken.isEmpty else {
            throw TTSError.missingCredentials
        }

        var request = URLRequest(url: Self.endpoint)
        let connectId = UUID().uuidString
        request.setValue(settings.appId, forHTTPHeaderField: "X-Api-App-Key")
        request.setValue(settings.accessToken, forHTTPHeaderField: "X-Api-Access-Key")
        request.setValue(settings.resourceId, forHTTPHeaderField: "X-Api-Resource-Id")
        request.setValue(connectId, forHTTPHeaderField: "X-Api-Connect-Id")

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: request)
        task.resume()

        let sessionId = UUID().uuidString
        var audioBuffer = Data()
        var sessionStartedReceived = false

        defer {
            task.cancel(with: .goingAway, reason: nil)
            session.invalidateAndCancel()
        }

        // 1. StartConnection
        try await send(task: task, event: .startConnection, sessionId: nil, payload: Data("{}".utf8))

        // 2. 等待 ConnectionStarted
        try await waitForEvent(task: task, expect: .connectionStarted)

        // 3. StartSession
        let startPayload: [String: Any] = [
            "event": Event.startSession.rawValue,
            "namespace": "BidirectionalTTS",
            "req_params": [
                "speaker": settings.voiceType,
                "audio_params": [
                    "format": "mp3",
                    "sample_rate": 24000
                ]
            ]
        ]
        let startData = try JSONSerialization.data(withJSONObject: startPayload)
        try await send(task: task, event: .startSession, sessionId: sessionId, payload: startData)

        // 4. TaskRequest
        let taskPayload: [String: Any] = [
            "event": Event.taskRequest.rawValue,
            "namespace": "BidirectionalTTS",
            "req_params": [
                "text": text,
                "speaker": settings.voiceType,
                "audio_params": [
                    "format": "mp3",
                    "sample_rate": 24000,
                    "speech_rate": Int((settings.speedRatio - 1.0) * 20)
                ]
            ]
        ]
        let taskData = try JSONSerialization.data(withJSONObject: taskPayload)
        try await send(task: task, event: .taskRequest, sessionId: sessionId, payload: taskData)

        // 5. FinishSession
        try await send(task: task, event: .finishSession, sessionId: sessionId, payload: Data("{}".utf8))

        // 6. 接收音频帧直到 SessionFinished
        loop: while true {
            let frame = try await receive(task: task)
            switch frame {
            case .audio(let data):
                audioBuffer.append(data)
                onProgress?(data)
            case .event(let eventCode, _):
                switch eventCode {
                case Event.sessionStarted.rawValue:
                    sessionStartedReceived = true
                case Event.sessionFinished.rawValue:
                    break loop
                case Event.sessionFailed.rawValue, Event.connectionFailed.rawValue:
                    throw TTSError.server(code: "\(eventCode)", message: "会话失败")
                default:
                    break
                }
            case .error(let code, let msg):
                throw TTSError.server(code: code, message: msg)
            }
        }

        _ = sessionStartedReceived  // 保留语义，避免警告

        // 7. FinishConnection（可选，关闭即可）
        try? await send(task: task, event: .finishConnection, sessionId: nil, payload: Data("{}".utf8))

        if audioBuffer.isEmpty {
            throw TTSError.invalidResponse("未收到音频数据")
        }
        return audioBuffer
    }

    // MARK: - Frame send
    private func send(
        task: URLSessionWebSocketTask,
        event: Event,
        sessionId: String?,
        payload: Data
    ) async throws {
        var frame = Data()
        // header: ver=1, header_size=1 (4 bytes), msg_type=1 (full client), flags=4 (with event),
        // serialization=1 (JSON), compression=0
        frame.append(0x11)
        frame.append(0x14)
        frame.append(0x10)
        frame.append(0x00)

        // event code
        frame.append(uint32BE(UInt32(bitPattern: event.rawValue)))

        // session_id (if applicable)
        if Self.eventCarriesSession(event.rawValue) {
            let sid = sessionId ?? ""
            let sidBytes = Data(sid.utf8)
            frame.append(uint32BE(UInt32(sidBytes.count)))
            frame.append(sidBytes)
        }

        // payload
        frame.append(uint32BE(UInt32(payload.count)))
        frame.append(payload)

        do {
            try await task.send(.data(frame))
        } catch {
            throw TTSError.network(error)
        }
    }

    // MARK: - Frame receive
    private enum DecodedFrame {
        case audio(Data)
        case event(code: Int32, payload: Data)
        case error(code: String, message: String)
    }

    private func receive(task: URLSessionWebSocketTask) async throws -> DecodedFrame {
        let message: URLSessionWebSocketTask.Message
        do {
            message = try await task.receive()
        } catch {
            throw TTSError.network(error)
        }
        switch message {
        case .data(let data):
            return try decodeFrame(data)
        case .string(let s):
            throw TTSError.invalidResponse("非预期文本帧：\(s.prefix(80))")
        @unknown default:
            throw TTSError.invalidResponse("未知 WS 帧")
        }
    }

    private func waitForEvent(task: URLSessionWebSocketTask, expect: Event) async throws {
        while true {
            let frame = try await receive(task: task)
            switch frame {
            case .event(let code, _) where code == expect.rawValue:
                return
            case .event(let code, _) where code == Event.connectionFailed.rawValue
                                          || code == Event.sessionFailed.rawValue:
                throw TTSError.server(code: "\(code)", message: "握手失败")
            case .error(let code, let msg):
                throw TTSError.server(code: code, message: msg)
            default:
                continue
            }
        }
    }

    private func decodeFrame(_ data: Data) throws -> DecodedFrame {
        guard data.count >= 4 else {
            throw TTSError.invalidResponse("帧过短")
        }
        let header0 = data[0]
        let header1 = data[1]
        let headerSize = Int(header0 & 0x0F) * 4
        guard data.count >= headerSize else {
            throw TTSError.invalidResponse("header 不完整")
        }
        let msgType = (header1 >> 4) & 0x0F
        var cursor = headerSize

        // 错误帧
        if msgType == 0x0F {
            guard data.count >= cursor + 8 else {
                throw TTSError.invalidResponse("error 帧不完整")
            }
            let errCode = readUInt32BE(data, at: cursor); cursor += 4
            let msgSize = Int(readUInt32BE(data, at: cursor)); cursor += 4
            let msgEnd = min(cursor + msgSize, data.count)
            let msg = String(data: data.subdata(in: cursor..<msgEnd), encoding: .utf8) ?? ""
            return .error(code: String(errCode), message: msg)
        }

        // 事件帧（msg_type=4）
        guard data.count >= cursor + 4 else {
            throw TTSError.invalidResponse("event 不完整")
        }
        let eventCode = Int32(bitPattern: readUInt32BE(data, at: cursor)); cursor += 4

        if Self.eventCarriesSession(eventCode) {
            guard data.count >= cursor + 4 else { throw TTSError.invalidResponse("session id 长度不完整") }
            let sidLen = Int(readUInt32BE(data, at: cursor)); cursor += 4
            cursor += sidLen
        }

        guard data.count >= cursor + 4 else { throw TTSError.invalidResponse("payload 长度不完整") }
        let payloadLen = Int(readUInt32BE(data, at: cursor)); cursor += 4
        let payloadEnd = min(cursor + payloadLen, data.count)
        let payload = data.subdata(in: cursor..<payloadEnd)

        if eventCode == Event.ttsResponse.rawValue {
            return .audio(payload)
        }
        return .event(code: eventCode, payload: payload)
    }

    // MARK: - bytes
    private func uint32BE(_ v: UInt32) -> Data {
        var be = v.bigEndian
        return Data(bytes: &be, count: 4)
    }

    private func readUInt32BE(_ data: Data, at offset: Int) -> UInt32 {
        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1])
        let b2 = UInt32(data[offset + 2])
        let b3 = UInt32(data[offset + 3])
        return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
    }
}
