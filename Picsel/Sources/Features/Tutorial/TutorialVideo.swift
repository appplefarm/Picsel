//
//  TutorialVideo.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/17/26.
//

import AVFoundation
import SwiftUI

/// 현재 페이지에서만 생성하는 무음 반복 플레이어입니다.
struct TutorialVideo: UIViewRepresentable {
    let resourceName: String
    let isPlaying: Bool
    let introDuration: TimeInterval
    let onIntroPlayed: () -> Void

    func makeUIView(context: Context) -> PlayerView {
        PlayerView(resourceName: resourceName, introDuration: introDuration, onIntroPlayed: onIntroPlayed)
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.setPlaying(isPlaying)
    }

    static func dismantleUIView(_ uiView: PlayerView, coordinator: ()) {
        uiView.stop()
    }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        private var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private var readiness: NSKeyValueObservation?
        private var introObserver: Any?
        private var hasReportedIntro = false
        private var wantsToPlay = false

        init(resourceName: String, introDuration: TimeInterval, onIntroPlayed: @escaping () -> Void) {
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            backgroundColor = .clear
            playerLayer.opacity = 0
            playerLayer.videoGravity = .resizeAspectFill
            guard let url = Bundle.main.url(forResource: resourceName, withExtension: "mp4") else { return }
            let player = AVQueuePlayer()
            player.isMuted = true
            player.preventsDisplaySleepDuringVideoPlayback = false
            player.audiovisualBackgroundPlaybackPolicy = .pauses
            self.player = player
            playerLayer.player = player
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            // 실제 영상 재생 시간을 기준으로 한 번만 알립니다. 일시정지 시간은 제외합니다.
            introObserver = player.addBoundaryTimeObserver(
                forTimes: [NSValue(time: CMTime(seconds: introDuration, preferredTimescale: 600))],
                queue: .main
            ) { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, self.player != nil, !self.hasReportedIntro else { return }
                    self.hasReportedIntro = true
                    onIntroPlayed()
                }
            }
            readiness = playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    self.playerLayer.opacity = self.playerLayer.isReadyForDisplay ? 1 : 0
                    CATransaction.commit()
                }
            }
        }

        required init?(coder: NSCoder) { return nil }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            setPlaying(wantsToPlay)
        }

        func setPlaying(_ shouldPlay: Bool) {
            wantsToPlay = shouldPlay
            if shouldPlay, window != nil { player?.play() }
            else { player?.pause() }
        }

        func stop() {
            wantsToPlay = false
            readiness = nil
            if let introObserver {
                player?.removeTimeObserver(introObserver)
                self.introObserver = nil
            }
            player?.pause()
            looper?.disableLooping()
            looper = nil
            player?.removeAllItems()
            playerLayer.player = nil
            player = nil
        }
    }
}
