//
//  vocalclipApp.swift
//  vocalclip
//

import SwiftUI
import SwiftData
import UIKit
import Combine

@main
struct vocalclipApp: App {
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var readingManager: ReadingManager
    @Environment(\.scenePhase) private var scenePhase

    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: ReadingHistory.self)
        } catch {
            fatalError("无法初始化 SwiftData ModelContainer: \(error)")
        }
        let store = SettingsStore()
        _settingsStore = StateObject(wrappedValue: store)
        _readingManager = StateObject(wrappedValue: ReadingManager(settingsStore: store))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settingsStore)
                .environmentObject(readingManager)
                .modelContainer(modelContainer)
                .onAppear { onAppStart() }
                .onOpenURL { url in handleURL(url) }
                .onChange(of: scenePhase) { _, new in
                    if new == .active {
                        handlePendingIntent()
                        if settingsStore.settings.enableLiveActivity {
                            LiveActivityController.shared.ensureStandby()
                        }
                    }
                }
        }
    }

    private func onAppStart() {
        readingManager.attach(modelContext: modelContainer.mainContext)
        if settingsStore.settings.enableLiveActivity {
            LiveActivityController.shared.ensureStandby()
        }
        VocalClipIntentBridge.observe {
            handlePendingIntent()
        }
        // 同步播放阶段到灵动岛
        readingManager.objectWillChange.sink { _ in
            DispatchQueue.main.async {
                syncLiveActivityFromReader()
            }
        }
        .store(in: &Self.bag)
    }

    private static var bag: Set<AnyCancellable> = []

    private func syncLiveActivityFromReader() {
        guard settingsStore.settings.enableLiveActivity else { return }
        let phase: VocalClipActivityAttributes.ContentState.Phase
        switch readingManager.phase {
        case .idle: phase = .standby
        case .synthesizing, .playing: phase = .playing
        case .paused: phase = .paused
        case .error: phase = .standby
        }
        let title = readingManager.currentText.isEmpty
            ? "等待粘贴"
            : String(readingManager.currentText.prefix(40))
        LiveActivityController.shared.update(
            phase: phase,
            title: title,
            currentTime: readingManager.currentTime,
            duration: readingManager.duration
        )
    }

    private func handleURL(_ url: URL) {
        if url.host == "read-clipboard" {
            readClipboard()
        }
    }

    private func handlePendingIntent() {
        guard let action = VocalClipIntentBridge.consume() else { return }
        switch action {
        case .readClipboard: readClipboard()
        case .pause: readingManager.pause()
        case .resume: readingManager.resume()
        case .stop: readingManager.stop()
        }
    }

    private func readClipboard() {
        guard let text = UIPasteboard.general.string,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        readingManager.startReading(text: text)
    }
}

