//
//  AudioPlayerController.swift
//  Readtard
//

import AVFoundation
import Combine
import Foundation

@MainActor
final class AudioPlayerController: NSObject, ObservableObject {
    @Published private(set) var book: Audiobook?
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var playbackRate: Double = 1
    @Published private(set) var volume: Double = 0.6
    @Published private(set) var loadingError: String?

    var duration: TimeInterval {
        audioPlayer?.duration ?? max(book?.duration ?? 0, 1)
    }

    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?

    deinit {
        progressTimer?.invalidate()
    }

    func load(book: Audiobook) {
        currentTime = 0
        isPlaying = false
        playbackRate = 1
        volume = 0.6
        loadingError = nil

        configureAudioSession()
        self.book = book
        configureAudioPlayer(for: book)
    }

    func unloadBook() {
        stopProgressTimer()
        audioPlayer?.stop()
        audioPlayer = nil
        book = nil
        currentTime = 0
        isPlaying = false
        loadingError = nil
    }

    func togglePlayback() {
        isPlaying ? pause() : play()
    }

    func pausePlayback() {
        pause()
    }

    func skip(by amount: TimeInterval) {
        seek(to: currentTime + amount)
    }

    func seek(to time: TimeInterval) {
        let clampedTime = min(max(time, 0), duration)
        audioPlayer?.currentTime = clampedTime
        currentTime = clampedTime
    }

    func advanceSpeed() {
        let speeds = [1.0, 1.25, 1.5, 1.75, 2.0]
        let currentIndex = speeds.firstIndex(of: playbackRate) ?? 0
        let nextIndex = (currentIndex + 1) % speeds.count
        playbackRate = speeds[nextIndex]
        audioPlayer?.rate = Float(playbackRate)
    }

    func setVolume(_ newValue: Double) {
        volume = newValue
        audioPlayer?.volume = Float(newValue)
    }

    private func play() {
        guard let audioPlayer else {
            return
        }

        audioPlayer.play()
        isPlaying = true
        startProgressTimer()
    }

    private func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopProgressTimer()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }

    private func configureAudioPlayer(for book: Audiobook) {
        guard let audioURL = book.audioURL else {
            audioPlayer = nil
            loadingError = nil
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: audioURL)
            player.enableRate = true
            player.rate = Float(playbackRate)
            player.volume = Float(volume)
            player.prepareToPlay()
            audioPlayer = player
        } catch {
            audioPlayer = nil
        }
    }

    private func startProgressTimer() {
        stopProgressTimer()

        progressTimer = Timer.scheduledTimer(
            timeInterval: 0.25,
            target: self,
            selector: #selector(handleProgressTimerTick),
            userInfo: nil,
            repeats: true
        )
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    @objc private func handleProgressTimerTick() {
        guard let audioPlayer else {
            stopProgressTimer()
            isPlaying = false
            return
        }

        currentTime = audioPlayer.currentTime

        if !audioPlayer.isPlaying {
            isPlaying = false
            stopProgressTimer()
        }
    }
}
