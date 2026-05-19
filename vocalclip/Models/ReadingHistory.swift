import Foundation
import SwiftData

@Model
final class ReadingHistory {
    @Attribute(.unique) var id: UUID
    var text: String
    var textHash: String
    var createdAt: Date
    var updatedAt: Date
    var lastPlaybackPosition: TimeInterval
    var totalDuration: TimeInterval
    var voiceType: String
    var audioFileName: String?

    init(
        id: UUID = UUID(),
        text: String,
        textHash: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastPlaybackPosition: TimeInterval = 0,
        totalDuration: TimeInterval = 0,
        voiceType: String = "",
        audioFileName: String? = nil
    ) {
        self.id = id
        self.text = text
        self.textHash = textHash
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastPlaybackPosition = lastPlaybackPosition
        self.totalDuration = totalDuration
        self.voiceType = voiceType
        self.audioFileName = audioFileName
    }

    var previewTitle: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "（空）" }
        let firstLine = trimmed.split(whereSeparator: \.isNewline).first.map(String.init) ?? trimmed
        return String(firstLine.prefix(40))
    }

    var progressFraction: Double {
        guard totalDuration > 0 else { return 0 }
        return min(1, max(0, lastPlaybackPosition / totalDuration))
    }
}
