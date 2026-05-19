import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    enum State: Equatable {
        case idle
        case playing
        case paused
        case finished
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var displayLink: CADisplayLink?

    /// 播放完成 / 异常 / 主动停止时的回调
    var onFinish: ((Bool) -> Void)?
    /// 进度变更（节流后）
    var onProgress: ((TimeInterval, TimeInterval) -> Void)?

    func load(url: URL, startAt position: TimeInterval = 0) throws {
        stopDisplayLink()
        try configureSession()
        let p = try AVAudioPlayer(contentsOf: url)
        p.delegate = self
        p.prepareToPlay()
        self.player = p
        self.duration = p.duration
        if position > 0, position < p.duration {
            p.currentTime = position
            self.currentTime = position
        } else {
            self.currentTime = 0
        }
    }

    func play() {
        guard let player else { return }
        player.play()
        state = .playing
        startDisplayLink()
    }

    func pause() {
        guard let player else { return }
        player.pause()
        state = .paused
        stopDisplayLink()
    }

    func stop() {
        player?.stop()
        state = .idle
        stopDisplayLink()
        onFinish?(false)
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        player.currentTime = max(0, min(time, player.duration))
        currentTime = player.currentTime
    }

    func currentPosition() -> TimeInterval {
        player?.currentTime ?? 0
    }

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [])
        try session.setActive(true, options: [])
    }

    // MARK: - Progress
    private func startDisplayLink() {
        stopDisplayLink()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 2, maximum: 10, preferred: 4)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        guard let player else { return }
        currentTime = player.currentTime
        onProgress?(currentTime, duration)
    }

    // MARK: - Delegate
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.state = .finished
            self.stopDisplayLink()
            self.currentTime = self.duration
            self.onFinish?(flag)
        }
    }
}
