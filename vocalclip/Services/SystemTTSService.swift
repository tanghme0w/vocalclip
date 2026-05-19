import Foundation
import AVFoundation

/// 系统语音兜底实现：将 AVSpeechSynthesizer 实时合成的 PCM 拼成 wav 数据。
/// 不接外部 API，断网也能用。注意：返回 wav 而非 mp3。
final class SystemTTSService: NSObject, TTSService, AVSpeechSynthesizerDelegate, @unchecked Sendable {

    func synthesize(
        text: String,
        settings: TTSSettings,
        onProgress: (@Sendable (Data) -> Void)?
    ) async throws -> Data {
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = Float(AVSpeechUtteranceDefaultSpeechRate) * Float(settings.speedRatio)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            var pcmChunks: [AVAudioPCMBuffer] = []
            var outputFormat: AVAudioFormat?
            var finished = false

            synthesizer.write(utterance) { buffer in
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }
                if pcm.frameLength == 0 {
                    guard !finished else { return }
                    finished = true
                    do {
                        let data = try Self.encodeWav(buffers: pcmChunks, format: outputFormat)
                        continuation.resume(returning: data)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                if outputFormat == nil { outputFormat = pcm.format }
                pcmChunks.append(pcm)
            }
        }
    }

    private static func encodeWav(buffers: [AVAudioPCMBuffer], format: AVAudioFormat?) throws -> Data {
        guard let format, let first = buffers.first else {
            throw TTSError.unsupportedAudioFormat
        }
        let channels = Int(format.channelCount)
        let sampleRate = format.sampleRate
        let bitsPerSample = 16

        var pcmData = Data()
        for buffer in buffers {
            guard let int16Channel = buffer.int16ChannelData else {
                // 转换 float32 → int16
                if let floatChannel = buffer.floatChannelData {
                    let frameLen = Int(buffer.frameLength)
                    for frame in 0..<frameLen {
                        for ch in 0..<channels {
                            let sample = floatChannel[ch][frame]
                            let clamped = max(-1.0, min(1.0, sample))
                            var int16 = Int16(clamped * 32767.0)
                            withUnsafeBytes(of: &int16) { pcmData.append(contentsOf: $0) }
                        }
                    }
                }
                continue
            }
            let frameLen = Int(buffer.frameLength)
            for frame in 0..<frameLen {
                for ch in 0..<channels {
                    var sample = int16Channel[ch][frame]
                    withUnsafeBytes(of: &sample) { pcmData.append(contentsOf: $0) }
                }
            }
        }

        // 构造 WAV header
        var wav = Data()
        let byteRate = UInt32(sampleRate) * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = UInt16(channels * (bitsPerSample / 8))
        let dataSize = UInt32(pcmData.count)
        let fileSize = 36 + dataSize

        wav.append("RIFF".data(using: .ascii)!)
        wav.append(uint32LE(fileSize))
        wav.append("WAVE".data(using: .ascii)!)
        wav.append("fmt ".data(using: .ascii)!)
        wav.append(uint32LE(16))                          // Subchunk1Size
        wav.append(uint16LE(1))                           // PCM
        wav.append(uint16LE(UInt16(channels)))
        wav.append(uint32LE(UInt32(sampleRate)))
        wav.append(uint32LE(byteRate))
        wav.append(uint16LE(blockAlign))
        wav.append(uint16LE(UInt16(bitsPerSample)))
        wav.append("data".data(using: .ascii)!)
        wav.append(uint32LE(dataSize))
        wav.append(pcmData)

        _ = first  // silence warning
        return wav
    }

    private static func uint32LE(_ v: UInt32) -> Data {
        var le = v.littleEndian
        return Data(bytes: &le, count: 4)
    }
    private static func uint16LE(_ v: UInt16) -> Data {
        var le = v.littleEndian
        return Data(bytes: &le, count: 2)
    }
}
