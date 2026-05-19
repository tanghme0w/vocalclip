import SwiftUI
import SwiftData

struct HistoryListView: View {
    @Query(sort: \ReadingHistory.updatedAt, order: .reverse) private var items: [ReadingHistory]
    @Environment(\.modelContext) private var modelContext

    var onSelect: (ReadingHistory) -> Void

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "暂无历史",
                    systemImage: "clock.badge.questionmark",
                    description: Text("朗读过的内容会出现在这里。")
                )
            } else {
                List {
                    ForEach(items) { item in
                        Button {
                            onSelect(item)
                        } label: {
                            row(for: item)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.plain)
            }
        }
    }

    private func row(for item: ReadingHistory) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.previewTitle)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            HStack(spacing: 8) {
                Text(format(date: item.updatedAt))
                    .foregroundStyle(.secondary)
                if item.totalDuration > 0 {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("\(formatTime(item.lastPlaybackPosition)) / \(formatTime(item.totalDuration))")
                        .foregroundStyle(.secondary)
                }
                if item.progressFraction > 0.01 && item.progressFraction < 0.99 {
                    Text("· 继续")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .font(.caption2)
            if item.progressFraction > 0 && item.progressFraction < 1 {
                ProgressView(value: item.progressFraction)
                    .tint(Color.accentColor)
            }
        }
        .padding(.vertical, 4)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let item = items[index]
            if let fileName = item.audioFileName {
                AudioCacheManager.remove(name: fileName)
            }
            modelContext.delete(item)
        }
        try? modelContext.save()
    }

    private func format(date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let total = Int(t.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
