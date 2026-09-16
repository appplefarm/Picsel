//
//  PhotoExploreLoadingVideo.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 9/17/26.
//

import AVFoundation
import SwiftUI

/// 번들 영상만 무음 반복 재생합니다. 재생 컨트롤·타이머·네트워크 요청은 사용하지 않습니다.
struct PhotoExploreLoadingVideo: UIViewRepresentable {
    let isPlaying: Bool

    func makeUIView(context: Context) -> PlayerView {
        PlayerView()
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
        private var wantsToPlay = false

        init() {
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            isAccessibilityElement = false
            backgroundColor = .clear
            playerLayer.opacity = 0
            playerLayer.videoGravity = .resizeAspect

            guard let url = Bundle.main.url(forResource: "PhotoExploreLoading", withExtension: "mp4") else { return }
            let player = AVQueuePlayer()
            player.isMuted = true
            player.preventsDisplaySleepDuringVideoPlayback = false
            player.audiovisualBackgroundPlaybackPolicy = .pauses
            self.player = player
            playerLayer.player = player
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            readiness = playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    // 첫 표시의 검은 깜빡임을 피하고, 준비 전에는 아래의 정지 이미지를 보여줍니다.
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
            player?.pause()
            looper?.disableLooping()
            looper = nil
            player?.removeAllItems()
            playerLayer.player = nil
            player = nil
        }
    }
}
