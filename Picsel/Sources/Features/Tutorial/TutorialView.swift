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
        TabView(selection: $selectedPageIndex) {
            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                TutorialPageView(
                    page: page,
                    isContentVisible: isContentVisible,
                    reduceMotion: reduceMotion
                ) {
                    advance(from: index)
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color.white.ignoresSafeArea())
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

        withAnimation(.easeInOut(duration: 0.3)) {
            selectedPageIndex = index + 1
        }
    }
}

private struct TutorialPageView: View {
    let page: TutorialPage
    let isContentVisible: Bool
    let reduceMotion: Bool
    let onContinue: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.white
                .ignoresSafeArea()

            tutorialGradient

            content
                .opacity(isContentVisible ? 1 : 0)
                .offset(y: reduceMotion || isContentVisible ? 0 : 18)
        }
    }

    private var tutorialGradient: some View {
        LinearGradient(
            stops: [
                Gradient.Stop(
                    color: Color(red: 0.95, green: 0.95, blue: 0.95),
                    location: 0
                ),
                Gradient.Stop(
                    color: Color(red: 0.22, green: 0.75, blue: 0.5),
                    location: 0.45
                )
            ],
            startPoint: UnitPoint(x: 0.5, y: 0),
            endPoint: UnitPoint(x: 0.5, y: 1)
        )
        .frame(maxWidth: .infinity)
        .frame(height: 331)
        .ignoresSafeArea(edges: .bottom)
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
            }
            .buttonStyle(.plain)
            .background(Color.white.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.top, 22)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 1)
    }
}

#Preview {
    TutorialView(onCompletion: { })
}
