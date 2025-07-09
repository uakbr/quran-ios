//
//  Player.swift
//  QueuePlayer
//
//  Created by Afifi, Mohamed on 5/4/19.
//  Copyright © 2019 Quran.com. All rights reserved.
//

import AVFoundation
import Foundation

@MainActor
final class Player {
    // MARK: Lifecycle

    deinit {
        rateObservation?.invalidate()
        timeObservation?.invalidate()
        itemObservation?.invalidate()
    }

    init(url: URL) {
        self.currentFileURL = url
        asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        currentFileIndex = 0

        setupObservations()
    }

    // MARK: Internal

    var onRateChanged: (@Sendable @MainActor (Float) -> Void)?
    var onTimeChanged: (@Sendable @MainActor (Double) -> Void)?
    var onItemCompleted: (@Sendable @MainActor () -> Void)?

    let playerItem: AVPlayerItem
    private(set) var currentFileIndex: Int
    private var currentFileURL: URL

    var currentTime: TimeInterval {
        player.currentTime().seconds
    }

    var duration: TimeInterval {
        asset.duration.seconds
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func stop() {
        player.pause()
        player.seek(to: 0)
    }

    func seek(to timeInSeconds: TimeInterval) {
        pause()
        player.seek(to: timeInSeconds)
        play()
    }
    
    func changeFile(to url: URL) {
        guard url != currentFileURL else { return }
        
        currentFileURL = url
        currentFileIndex += 1
        
        // Create new asset and player item
        asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        playerItem = AVPlayerItem(asset: asset)
        
        // Replace current item
        player.replaceCurrentItem(with: playerItem)
        
        // Re-setup observations for new item
        setupObservations()
    }
    
    func cleanup() {
        rateObservation?.invalidate()
        timeObservation?.invalidate()
        itemObservation?.invalidate()
        player.pause()
    }

    // MARK: Private

    private var asset: AVURLAsset
    private let player: AVPlayer

    private var rateObservation: NSKeyValueObservation? {
        didSet { oldValue?.invalidate() }
    }
    
    private var timeObservation: Any? {
        didSet { 
            if let observer = oldValue {
                player.removeTimeObserver(observer)
            }
        }
    }
    
    private var itemObservation: NSKeyValueObservation? {
        didSet { oldValue?.invalidate() }
    }
    
    private func setupObservations() {
        // Rate observation
        rateObservation = player.observe(\AVPlayer.rate, options: [.new]) { [weak self] _, change in
            if let rate = change.newValue {
                guard let self else { return }
                Task {
                    await self.onRateChanged?(rate)
                }
            }
        }
        
        // Time observation
        let interval = CMTime(seconds: 0.1, preferredTimescale: 1000)
        timeObservation = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            Task {
                await self.onTimeChanged?(time.seconds)
            }
        }
        
        // Item completion observation
        itemObservation = playerItem.observe(\AVPlayerItem.status, options: [.new]) { [weak self] item, _ in
            if item.status == .readyToPlay {
                // Monitor for item end
                NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: item,
                    queue: .main
                ) { [weak self] _ in
                    guard let self else { return }
                    Task {
                        await self.onItemCompleted?()
                    }
                }
            }
        }
    }
}

private extension AVPlayer {
    func seek(to timeInSeconds: TimeInterval) {
        let time = CMTime(seconds: timeInSeconds, preferredTimescale: 1000)
        seek(to: time)
    }
}
