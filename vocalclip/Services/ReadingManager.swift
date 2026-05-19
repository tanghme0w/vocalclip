import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
final class ReadingManager: ObservableObject {
    enum Phase: Equatable {
        case idle
        case synthesizing
        case playing
        case paused
        case error(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var currentText: String = ""
    @Published private(set) var currentHistoryId: UUID?
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published var lastErrorMessage: String?

    let player = AudioPlayer()
    private let settingsStore: SettingsStore
    private var modelContext: ModelContext?
    private var activeTask: Task<Void, Never>?

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore

        player.onProgress = { [weak self] current, duration in
            guard let self else { return }
            self.currentTime = current
            self.duration = duration
            self.persistProgress(current: current, duration: duration)
        }
        player.onFinish = { [weak self] _ in
            guard let self else { return }
            self.phase = .idle
            if let id = self.currentHistoryId {
                self.completeHistory(id: id)
            }
        }
    }

    func attach(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    var isBusy: Bool {
        if case .synthesizing = phase { return true }
        if case .playing = phase { return true }
        return false
    }

    // MARK: - User actions

    func toggleReading(text: String) {
        switch phase {
        case .playing:
            pause()
        case .paused:
            resume()
        case .idle, .error:
            startReading(text: text)
        case .synthesizing:
            cancel()
        }
    }

    func startReading(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        cancel()
        currentText = trimmed
        phase = .synthesizing

        let settings = settingsStore.settings
        let voice = settings.voiceType
        let hash = AudioCacheManager.hash(for: trimmed, voice: voice)

        // 命中缓存 → 直接播放
        let cachedName = existingCacheFile(forHash: hash)
        if let name = cachedName {
            let url = AudioCacheManager.url(forFileName: name)
            let history = upsertHistory(text: trimmed, hash: hash, voice: voice, audioFileName: name)
            currentHistoryId = history.id
            let resumeAt = history.lastPlaybackPosition < (history.totalDuration - 0.5) ? history.lastPlaybackPosition : 0
            do {
                try player.load(url: url, startAt: resumeAt)
                player.play()
                phase = .playing
            } catch {
                phase = .error(error.localizedDescription)
            }
            return
        }

        activeTask = Task { [weak self] in
            guard let self else { return }
            let service: TTSService = settings.provider == .volcanoBidirectional ? VolcanoTTSService() : SystemTTSService()
            do {
                let data = try await service.synthesize(text: trimmed, settings: settings, onProgress: nil)
                try Task.checkCancellation()

                let ext = settings.provider == .volcanoBidirectional ? "mp3" : "wav"
                let fileName = AudioCacheManager.fileName(hash: hash, ext: ext)
                let url = try AudioCacheManager.write(data, name: fileName)

                let history = self.upsertHistory(text: trimmed, hash: hash, voice: voice, audioFileName: fileName)
                self.currentHistoryId = history.id
                let resumeAt = history.lastPlaybackPosition < (history.totalDuration - 0.5) ? history.lastPlaybackPosition : 0
                try self.player.load(url: url, startAt: resumeAt)
                self.player.play()
                self.phase = .playing
            } catch is CancellationError {
                self.phase = .idle
            } catch {
                self.phase = .error(error.localizedDescription)
                self.lastErrorMessage = error.localizedDescription
            }
        }
    }

    func pause() {
        guard case .playing = phase else { return }
        player.pause()
        phase = .paused
    }

    func resume() {
        guard case .paused = phase else { return }
        player.play()
        phase = .playing
    }

    func stop() {
        cancel()
        phase = .idle
    }

    func cancel() {
        activeTask?.cancel()
        activeTask = nil
        if player.state != .idle {
            player.stop()
        }
    }

    /// 从历史记录继续播放
    func resumeFromHistory(_ history: ReadingHistory) {
        cancel()
        guard let fileName = history.audioFileName,
              AudioCacheManager.fileExists(fileName) else {
            // 缓存丢失，重新合成
            startReading(text: history.text)
            return
        }
        currentText = history.text
        currentHistoryId = history.id
        let url = AudioCacheManager.url(forFileName: fileName)
        let resumeAt = history.lastPlaybackPosition < (history.totalDuration - 0.5) ? history.lastPlaybackPosition : 0
        do {
            try player.load(url: url, startAt: resumeAt)
            player.play()
            phase = .playing
        } catch {
            phase = .error(error.localizedDescription)
            lastErrorMessage = error.localizedDescription
        }
    }

    // MARK: - History persistence
    private func existingCacheFile(forHash hash: String) -> String? {
        let mp3 = AudioCacheManager.fileName(hash: hash, ext: "mp3")
        if AudioCacheManager.fileExists(mp3) { return mp3 }
        let wav = AudioCacheManager.fileName(hash: hash, ext: "wav")
        if AudioCacheManager.fileExists(wav) { return wav }
        return nil
    }

    @discardableResult
    private func upsertHistory(text: String, hash: String, voice: String, audioFileName: String) -> ReadingHistory {
        guard let modelContext else {
            return ReadingHistory(text: text, textHash: hash, voiceType: voice, audioFileName: audioFileName)
        }
        let predicate = #Predicate<ReadingHistory> { $0.textHash == hash }
        let descriptor = FetchDescriptor<ReadingHistory>(predicate: predicate)
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.updatedAt = Date()
            existing.audioFileName = audioFileName
            existing.voiceType = voice
            try? modelContext.save()
            return existing
        }
        let history = ReadingHistory(
            text: text,
            textHash: hash,
            voiceType: voice,
            audioFileName: audioFileName
        )
        modelContext.insert(history)
        try? modelContext.save()
        return history
    }

    private var lastPersistAt: Date = .distantPast
    private func persistProgress(current: TimeInterval, duration: TimeInterval) {
        guard let modelContext, let id = currentHistoryId else { return }
        let now = Date()
        guard now.timeIntervalSince(lastPersistAt) > 1.0 else { return }
        lastPersistAt = now
        let predicate = #Predicate<ReadingHistory> { $0.id == id }
        let descriptor = FetchDescriptor<ReadingHistory>(predicate: predicate)
        if let history = try? modelContext.fetch(descriptor).first {
            history.lastPlaybackPosition = current
            history.totalDuration = duration
            history.updatedAt = now
            try? modelContext.save()
        }
    }

    private func completeHistory(id: UUID) {
        guard let modelContext else { return }
        let predicate = #Predicate<ReadingHistory> { $0.id == id }
        let descriptor = FetchDescriptor<ReadingHistory>(predicate: predicate)
        if let history = try? modelContext.fetch(descriptor).first {
            history.lastPlaybackPosition = 0  // 完成后重置，下次默认从头播
            history.updatedAt = Date()
            try? modelContext.save()
        }
    }
}
