//
//  PhotoInteractionSettingsPanel.swift
//  Picsel
//

import SwiftUI

#if DEBUG
struct PhotoInteractionSettingsPanel: View {
    @Binding var settings: PhotoInteractionSettings

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SettingsSlider(
                        "드래그 시작 거리",
                        value: $settings.dragStartDistance,
                        range: 0...20,
                        step: 1,
                        unit: " pt",
                        fractionDigits: 0
                    )
                    SettingsSlider(
                        "핀치 시작 변화량",
                        value: $settings.pinchStartDelta,
                        range: 0...0.05,
                        step: 0.001,
                        fractionDigits: 3
                    )
                } header: {
                    Text("Apple 제스처 인식")
                } footer: {
                    Text("값이 작을수록 손가락 입력에 더 빨리 반응합니다.")
                }

                Section("이동 감도") {
                    SettingsSlider(
                        "드래그 감도",
                        value: $settings.dragSensitivity,
                        range: 0.5...2,
                        step: 0.05,
                        unit: "×"
                    )
                    SettingsSlider(
                        "핀치 감도",
                        value: $settings.zoomSensitivity,
                        range: 0.5...2,
                        step: 0.05,
                        unit: "×"
                    )
                }

                Section("관성") {
                    SettingsSlider(
                        "드래그 관성",
                        value: $settings.dragMomentumRetention,
                        range: 0...0.6,
                        step: 0.02
                    )
                    SettingsSlider(
                        "최대 이동 거리",
                        value: $settings.maximumDragCoast,
                        range: 0...240,
                        step: 10,
                        unit: " pt",
                        fractionDigits: 0
                    )
                    SettingsSlider(
                        "핀치 관성 시간",
                        value: $settings.zoomMomentumDuration,
                        range: 0...0.12,
                        step: 0.005,
                        unit: " s",
                        fractionDigits: 3
                    )
                    SettingsSlider(
                        "최대 핀치 관성",
                        value: $settings.maximumZoomCoast,
                        range: 0...0.3,
                        step: 0.01,
                        unit: "×"
                    )
                    SettingsSlider(
                        "정착 시간",
                        value: $settings.settlingDuration,
                        range: 0.1...0.6,
                        step: 0.02,
                        unit: " s"
                    )
                }

                Section {
                    SettingsSlider(
                        "깊이 범위",
                        value: $settings.magnetDepthTolerance,
                        range: 0.1...0.9,
                        step: 0.02
                    )
                    SettingsSlider(
                        "화면 중심 범위",
                        value: $settings.magnetViewportMargin,
                        range: 0.15...1,
                        step: 0.05
                    )
                } header: {
                    Text("마그넷")
                } footer: {
                    Text("두 조건을 모두 만족할 때 손을 놓으면 사진에 붙습니다.")
                }

                Section("사진") {
                    SettingsSlider(
                        "사진 크기",
                        value: $settings.photoScale,
                        range: 0.75...2.25,
                        step: 0.05,
                        unit: "×"
                    )
                }

                Section {
                    Text("Apple은 3D 탐색용 고정 수치를 제시하지 않습니다. 이 범위는 기기에서 비교 테스트하기 위한 안전 범위입니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("조작 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("기본값") {
                        settings = .defaults
                    }
                }
            }
        }
        .frame(idealWidth: 380, idealHeight: 640)
        .presentationCompactAdaptation(.popover)
    }
}

private struct SettingsSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    let fractionDigits: Int

    init(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        unit: String = "",
        fractionDigits: Int = 2
    ) {
        self.title = title
        _value = value
        self.range = range
        self.step = step
        self.unit = unit
        self.fractionDigits = fractionDigits
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(formattedValue)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: $value, in: range, step: step)
        }
        .accessibilityElement(children: .combine)
    }

    private var formattedValue: String {
        value.formatted(
            .number.precision(.fractionLength(fractionDigits))
        ) + unit
    }
}
#endif
