//
//  TutorialView.swift
//  Picsel
//

import SwiftUI

struct TutorialView: View {
    private let pages: [TutorialPage]
    private let onCompletion: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedPageIndex = 0
    @State private var isContentVisible = false
    @State private var hasPresentedContent = false

    init(
        pages: [TutorialPage] = TutorialPage.defaultPages,
        onCompletion: @escaping () -> Void
    ) {
        precondition(!pages.isEmpty, "TutorialView에는 한 개 이상의 페이지가 필요합니다.")
        self.pages = pages
        self.onCompletion = onCompletion
    }

    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $selectedPageIndex) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    TutorialPageView(
                        page: page,
                        isSelected: selectedPageIndex == index,
                        bottomInset: geometry.safeAreaInsets.bottom,
                        isContentVisible: isContentVisible,
                        reduceMotion: reduceMotion
                    ) {
                        advance(from: index)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(.container, edges: .vertical)
        }
        .background(PicselColor.surface.ignoresSafeArea())
        .task {
            guard !hasPresentedContent else { return }
            hasPresentedContent = true
            await Task.yield()

            if reduceMotion {
                isContentVisible = true
            } else {
                withAnimation(.easeOut(duration: 0.55)) {
                    isContentVisible = true
                }
            }
        }
    }

    private func advance(from index: Int) {
        guard index < pages.index(before: pages.endIndex) else {
            onCompletion()
            return
        }

        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
            selectedPageIndex = index + 1
        }
    }
}

private struct TutorialPageView: View {
    let page: TutorialPage
    let isSelected: Bool
    let bottomInset: CGFloat
    let isContentVisible: Bool
    let reduceMotion: Bool
    let onContinue: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasPlayedIntro = false

    private var isContinueVisible: Bool {
        reduceMotion || hasPlayedIntro
    }

    var body: some View {
        GeometryReader { geometry in
            let videoScale = geometry.size.width / 402
            let videoFrame = page.videoFrame
            ZStack(alignment: .bottom) {
                page.background

                ZStack {
                    Image(page.posterName)
                        .resizable()
                        .scaledToFill()
                    if isSelected, !reduceMotion {
                        TutorialVideo(
                            resourceName: page.videoName,
                            isPlaying: scenePhase == .active,
                            introDuration: page.continueDelay
                        ) { hasPlayedIntro = true }
                    }
                }
                .frame(width: videoFrame.width * videoScale, height: videoFrame.height * videoScale)
                .clipped()
                .offset(x: videoFrame.minX * videoScale, y: videoFrame.minY * videoScale)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                .accessibilityHidden(true)
                .allowsHitTesting(false)

                tutorialGradient
                    .frame(height: geometry.size.height * page.gradientHeightRatio)

                content
                    .opacity(isContentVisible ? 1 : 0)
                    .offset(y: reduceMotion || isContentVisible ? 0 : 18)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .ignoresSafeArea(.container, edges: .vertical)
    }

    private var tutorialGradient: some View {
        LinearGradient(
            stops: [
                Gradient.Stop(
                    color: page.background.opacity(0),
                    location: 0
                ),
                Gradient.Stop(
                    color: Color(hex: 0x38C07F),
                    location: 0.45
                )
            ],
            startPoint: UnitPoint(x: 0.5, y: 0),
            endPoint: UnitPoint(x: 0.5, y: 1)
        )
        .accessibilityHidden(true)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(page.description)
                    .font(PicselFont.subtitle01)

                Text(page.highlightedText)
                    .font(PicselFont.title02)
                    .padding(.top, 15)

                Text(page.trailingText)
                    .font(PicselFont.subtitle01)
                    .padding(.top, 15)
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 14)

            Button(action: onContinue) {
                Text(page.buttonTitle)
                    .font(PicselFont.label01)
                    .foregroundStyle(PicselColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 66)
                    .background(
                        Color.white.opacity(0.8),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .opacity(isContinueVisible ? 1 : 0)
            .scaleEffect(isContinueVisible ? 1 : 0.86)
            .animation(
                reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.64),
                value: isContinueVisible
            )
            .allowsHitTesting(isContinueVisible)
            .accessibilityHidden(!isContinueVisible)
            .padding(.top, 22)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, max(35, bottomInset + 1))
    }
}

#Preview {
    TutorialView(onCompletion: { })
}

#Preview("공간 갤러리") {
    TutorialView(pages: [.photoExplore], onCompletion: { })
}

#Preview("픽셀맵") {
    TutorialView(pages: [.pixelMap], onCompletion: { })
}
