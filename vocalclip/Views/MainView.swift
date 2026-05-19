import SwiftUI
import SwiftData
import UIKit

struct MainView: View {
    @EnvironmentObject var reader: ReadingManager
    @EnvironmentObject var settingsStore: SettingsStore
    @Environment(\.modelContext) private var modelContext

    @State private var text: String = ""
    @State private var sidebarOpen: Bool = false
    @State private var dragOffset: CGFloat = 0
    @FocusState private var editorFocused: Bool

    private let sidebarWidth: CGFloat = 300

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                mainContent
                    .offset(x: openOffset(for: geo))
                    .disabled(sidebarOpen)
                    .overlay(
                        sidebarOpen
                        ? Color.black.opacity(0.25)
                            .ignoresSafeArea()
                            .onTapGesture { closeSidebar() }
                        : nil
                    )

                SidebarView(
                    onClose: { closeSidebar() },
                    onSelectHistory: { history in
                        text = history.text
                        reader.resumeFromHistory(history)
                        closeSidebar()
                    }
                )
                .frame(width: sidebarWidth)
                .offset(x: sidebarOffset(for: geo))
                .shadow(color: .black.opacity(sidebarOpen ? 0.2 : 0), radius: 12, x: 4, y: 0)
            }
            .gesture(edgeDragGesture(width: geo.size.width))
            .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.86), value: sidebarOpen)
            .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.86), value: dragOffset)
        }
        .onAppear {
            reader.attach(modelContext: modelContext)
        }
    }

    // MARK: - Main content
    private var mainContent: some View {
        VStack(spacing: 0) {
            topBar
            notepad
            controlBar
        }
        .background(notepadBackground.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack {
            Button {
                openSidebar()
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }
            Spacer()
            Text("VocalClip")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    private var notepad: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .focused($editorFocused)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .font(.system(size: 17))

            if text.isEmpty {
                Text("在这里粘贴或输入要朗读的内容…")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 17))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .allowsHitTesting(false)
            }
        }
    }

    private var controlBar: some View {
        VStack(spacing: 8) {
            if case .error(let message) = reader.phase {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .lineLimit(2)
            }
            if reader.duration > 0 && (reader.phase == .playing || reader.phase == .paused) {
                progressBar
            }

            HStack(alignment: .center, spacing: 24) {
                pasteButton
                playButton
                clearButton
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
            .padding(.top, 4)
        }
    }

    private var progressBar: some View {
        VStack(spacing: 4) {
            ProgressView(value: reader.currentTime, total: max(reader.duration, 0.01))
                .tint(.accentColor)
            HStack {
                Text(format(reader.currentTime))
                Spacer()
                Text(format(reader.duration))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 28)
    }

    private var pasteButton: some View {
        Button {
            if let pasted = UIPasteboard.general.string {
                text = pasted
            }
        } label: {
            actionLabel(icon: "doc.on.clipboard", title: "粘贴")
        }
        .buttonStyle(.plain)
        .frame(width: 72, height: 72)
        .background(Circle().fill(Color(.secondarySystemBackground)))
    }

    private var playButton: some View {
        Button {
            editorFocused = false
            reader.toggleReading(text: text)
        } label: {
            ZStack {
                Circle()
                    .fill(playButtonGradient)
                Image(systemName: playIcon)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
                    .offset(x: playIcon == "play.fill" ? 3 : 0)
            }
            .overlay(
                Group {
                    if case .synthesizing = reader.phase {
                        Circle().strokeBorder(Color.white.opacity(0.7), lineWidth: 2)
                        ProgressView().tint(.white)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .frame(width: 104, height: 104)
        .shadow(color: .accentColor.opacity(0.35), radius: 12, y: 6)
        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && reader.phase == .idle)
    }

    private var clearButton: some View {
        Button {
            text = ""
            reader.stop()
        } label: {
            actionLabel(icon: "trash", title: "清空")
        }
        .buttonStyle(.plain)
        .frame(width: 72, height: 72)
        .background(Circle().fill(Color(.secondarySystemBackground)))
    }

    private var playButtonGradient: LinearGradient {
        LinearGradient(
            colors: [.accentColor, .accentColor.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var playIcon: String {
        switch reader.phase {
        case .playing: return "pause.fill"
        case .paused: return "play.fill"
        case .synthesizing: return "ellipsis"
        default: return "play.fill"
        }
    }

    private func actionLabel(icon: String, title: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
            Text(title)
                .font(.caption2)
        }
        .foregroundStyle(.primary)
    }

    private var notepadBackground: some View {
        Color(red: 0.99, green: 0.97, blue: 0.92)
            .overlay(
                LinearGradient(
                    colors: [Color.white.opacity(0.0), Color.black.opacity(0.03)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    // MARK: - Sidebar geometry
    private func openOffset(for geo: GeometryProxy) -> CGFloat {
        let base = sidebarOpen ? sidebarWidth : 0
        return max(0, base + dragOffset)
    }

    private func sidebarOffset(for geo: GeometryProxy) -> CGFloat {
        let closed: CGFloat = -sidebarWidth
        let opened: CGFloat = 0
        let base = sidebarOpen ? opened : closed
        return min(opened, base + dragOffset)
    }

    private func edgeDragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if sidebarOpen {
                    let delta = min(0, value.translation.width)
                    dragOffset = max(delta, -sidebarWidth)
                } else if value.startLocation.x < 30 {
                    let delta = max(0, value.translation.width)
                    dragOffset = min(delta, sidebarWidth)
                }
            }
            .onEnded { value in
                let threshold = sidebarWidth / 3
                if sidebarOpen {
                    if -dragOffset > threshold {
                        sidebarOpen = false
                    }
                } else if value.startLocation.x < 30 {
                    if dragOffset > threshold {
                        sidebarOpen = true
                    }
                }
                dragOffset = 0
            }
    }

    private func openSidebar() {
        editorFocused = false
        sidebarOpen = true
    }
    private func closeSidebar() {
        sidebarOpen = false
    }

    private func format(_ t: TimeInterval) -> String {
        let total = Int(t.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
