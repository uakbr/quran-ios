//
//  AudioPlayer.swift
//  QueuePlayer
//
//  Created by Afifi, Mohamed on 4/27/19.
//  Copyright © 2019 Quran.com. All rights reserved.
//

import Foundation
import Timing
import VLogging

@MainActor
class AudioPlayer {
    // MARK: Lifecycle

    init(request: AudioRequest) {
        self.request = request
        audioPlaying = AudioPlaying(request: request, fileIndex: 0, frameIndex: 0)
        player = Player(url: request.files[0].url)
        
        // Use weak reference to prevent retain cycle
        interruptionMonitor.onAudioInterruption = { [weak self] interruption in
            Task { @MainActor in
                self?.onAudioInterruption(type: interruption)
            }
        }
        
        // Setup player callbacks with weak reference
        setupPlayerCallbacks()
    }
    
    deinit {
        Task { @MainActor in
            cleanup()
        }
    }

    // MARK: Internal

    let request: AudioRequest

    private(set) var audioPlaying: AudioPlaying

    var onPlayingChanged: (AudioPlaying) -> Void = { _ in }

    private(set) var isPlaying = false

    // Make actions optional and use class reference
    var actions: QueuePlayerActions? {
        didSet {
            updateActionsCallbacks()
        }
    }
    
    private func updateActionsCallbacks() {
        // This will be called when actions are set
    }

    func play() {
        guard canPlay() else { return }
        player.play()
    }
    
    func startPlaying() {
        play()
    }

    func pause() {
        player.pause()
    }
    
    func resume() {
        play()
    }

    func stop() {
        player.stop()
    }

    func stepForward() -> Bool {
        // Move to next frame/file
        if audioPlaying.framePlaying.frameIndex + 1 < request.files[audioPlaying.filePlaying.fileIndex].frames.count {
            // Move to next frame in current file
            updateAudioPlaying(fileIndex: audioPlaying.filePlaying.fileIndex, frameIndex: audioPlaying.framePlaying.frameIndex + 1)
            return true
        } else if audioPlaying.filePlaying.fileIndex + 1 < request.files.count {
            // Move to next file
            updateAudioPlaying(fileIndex: audioPlaying.filePlaying.fileIndex + 1, frameIndex: 0)
            return true
        }
        return false
    }

    func stepBackward() -> Bool {
        // Move to previous frame/file
        if audioPlaying.framePlaying.frameIndex > 0 {
            // Move to previous frame in current file
            updateAudioPlaying(fileIndex: audioPlaying.filePlaying.fileIndex, frameIndex: audioPlaying.framePlaying.frameIndex - 1)
            return true
        } else if audioPlaying.filePlaying.fileIndex > 0 {
            // Move to previous file
            let previousFileIndex = audioPlaying.filePlaying.fileIndex - 1
            let lastFrameIndex = request.files[previousFileIndex].frames.count - 1
            updateAudioPlaying(fileIndex: previousFileIndex, frameIndex: lastFrameIndex)
            return true
        }
        return false
    }
    
    func stepBackgward() -> Bool {
        return stepBackward()
    }

    // MARK: Private

    private let player: Player
    private let interruptionMonitor = AudioInterruptionMonitor()

    private func setupPlayerCallbacks() {
        // Setup player callbacks with MainActor isolation
        player.onRateChanged = { [weak self] rate in
            Task { @MainActor in
                self?.onRateChanged(rate: rate)
            }
        }
        
        player.onTimeChanged = { [weak self] time in
            Task { @MainActor in
                self?.onTimeChanged(time: time)
            }
        }
        
        player.onItemCompleted = { [weak self] in
            Task { @MainActor in
                self?.onItemCompleted()
            }
        }
    }

    @MainActor
    private func cleanup() {
        player.cleanup()
        interruptionMonitor.cleanup()
    }

    private func canPlay() -> Bool {
        return !request.files.isEmpty && audioPlaying.fileIndex < request.files.count
    }

    private func updateAudioPlaying(fileIndex: Int, frameIndex: Int) {
        guard fileIndex < request.files.count,
              frameIndex < request.files[fileIndex].frames.count else {
            return
        }

        audioPlaying = AudioPlaying(request: request, fileIndex: fileIndex, frameIndex: frameIndex)
        
        // Update player if file changed
        if fileIndex != player.currentFileIndex {
            player.changeFile(to: request.files[fileIndex].url)
        }
        
        onPlayingChanged(audioPlaying)
    }

    private func onRateChanged(rate: Float) {
        isPlaying = rate > 0
        actions?.playbackRateChanged(rate)
    }

    private func onTimeChanged(time: Double) {
        // Update current frame based on time
        let file = request.files[audioPlaying.filePlaying.fileIndex]
        for (index, frame) in file.frames.enumerated() {
            if time >= frame.startTime && time < frame.endTime {
                if index != audioPlaying.framePlaying.frameIndex {
                    updateAudioPlaying(fileIndex: audioPlaying.filePlaying.fileIndex, frameIndex: index)
                    // Call audioFrameChanged with correct parameters
                    actions?.audioFrameChanged(audioPlaying.filePlaying.fileIndex, index, player.playerItem)
                }
                break
            }
        }
    }

    private func onItemCompleted() {
        if !stepForward() {
            // Reached end of playlist
            stop()
            actions?.playbackEnded()
        }
    }

    private func onAudioInterruption(type: AudioInterruption) {
        switch type {
        case .began:
            if isPlaying {
                pause()
            }
        case .endedShouldResume:
            // Resume playback if was playing before interruption
            if !isPlaying {
                play()
            }
        case .endedShouldNotResume:
            // Don't resume playback automatically
            break
        }
    }
}
