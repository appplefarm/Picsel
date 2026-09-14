//
//  SpatialPhotoCanvas.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/28/26.
//

import RealityKit
import SwiftUI

/// SwiftUI 입력을 ViewModel과 RealityKit 렌더러에 연결하는 화면입니다.
struct SpatialPhotoCanvas: View {
    private let onConfirm: (PhotoDestination) -> Void
    /// 전달하면 부모가 목록 조회와 공간 준비를 묶어 로딩 화면을 표시합니다.
    private let onSceneLoadingChange: ((Bool) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel: SpatialPhotoCanvasViewModel
    @State private var renderer = RealityPhotoRenderer()
    @State private var settings = PhotoInteractionSettings.defaults
    @State private var presentedPlace: SpatialPlaceItem?
    @GestureState private var isCameraGestureActive = false

#if DEBUG
    @State private var isShowingSettings = false
#endif

    init(
        destinations: [PhotoDestination],
        onSceneLoadingChange: ((Bool) -> Void)? = nil,
        onConfirm: @escaping (PhotoDestination) -> Void
    ) {
        self.onConfirm = onConfirm
        self.onSceneLoadingChange = onSceneLoadingChange
        _viewModel = State(
            initialValue: SpatialPhotoCanvasViewModel(
                places: SpatialPlaceItem.compose(from: destinations)
            )
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let viewportSize = geometry.size
            let camera = viewModel.camera

            ZStack {
                PhotoExploreBackground()

                RealityView { content in
                    content.camera = .virtual
                    content.renderingEffects.depthOfField = .enabled
                    content.add(renderer.root)
                    content.add(renderer.camera)
                    renderer.render(
                        camera: camera,
                        selectedPlaceID: viewModel.selectedPlaceID,
                        photoScale: Float(settings.photoScale)
                    )
                } update: { content in
                    if viewModel.isInteracting {
                        renderer.render(
                            camera: camera,
                            selectedPlaceID: viewModel.selectedPlaceID,
                            photoScale: Float(settings.photoScale)
                        )
                    } else {
                        content.animate {
                            renderer.render(
                                camera: camera,
                                selectedPlaceID: viewModel.selectedPlaceID,
                                photoScale: Float(settings.photoScale)
                            )
                        }
                    }
                }
                .realityViewCameraControls(.none)

                sceneStatusOverlay
            }
            .contentShape(Rectangle())
            .simultaneousGesture(selectionGesture(in: viewportSize))
            .simultaneousGesture(cameraGesture(in: viewportSize))
            .clipped()
            .onChange(of: camera) { _, newCamera in
                withAnimation(standardAnimation) {
                    viewModel.updateAutomaticSelection(
                        for: newCamera,
                        in: viewportSize
                    )
                }
            }
            .onChange(of: isCameraGestureActive) { wasActive, isActive in
                guard wasActive, !isActive else { return }
                viewModel.cancelGesture()
            }
            .onChange(of: viewportSize) { _, newSize in
                guard viewModel.canInteract else { return }

                withAnimation(standardAnimation) {
                    viewModel.updateAutomaticSelection(
                        for: viewModel.camera,
                        in: newSize
                    )
                }
            }
            .overlay(alignment: .topLeading) {
                if viewModel.canInteract { hint }
            }
            .onChange(of: viewModel.scenePhase, initial: true) { _, phase in
                onSceneLoadingChange?(phase == .loading)
            }
            .toolbar(viewModel.scenePhase == .loading ? .hidden : .visible, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("화면 맞춤", systemImage: "scope") {
                        withAnimation(standardAnimation) {
                            viewModel.reset(in: viewportSize)
                        }
                    }
                    .labelStyle(.iconOnly)
                    .disabled(!viewModel.canInteract)

#if DEBUG
                    Button("조작 설정", systemImage: "slider.horizontal.3") {
                        isShowingSettings = true
                    }
                    .labelStyle(.iconOnly)
                    .popover(isPresented: $isShowingSettings, arrowEdge: .top) {
                        PhotoInteractionSettingsPanel(settings: $settings)
                    }
#endif
                }
            }
            .task(id: viewModel.sceneLoadRequest) {
                await loadScene()
            }
        }
        .sensoryFeedback(.selection, trigger: viewModel.selectedPlaceID)
        .fullScreenCover(item: $presentedPlace) { item in
            DestinationDetailView(
                destination: item.destination,
                info: DestinationDetailInfo(destination: item.destination)
            ) {
                onConfirm(item.destination)
            }
        }
    }

    private var standardAnimation: Animation? {
        reduceMotion ? nil : .default
    }

    private var momentumAnimation: Animation? {
        reduceMotion
            ? nil
            : .snappy(duration: settings.settlingDuration, extraBounce: 0)
    }

    private var hint: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("관광사진 \(viewModel.places.count)장을 둘러보세요")
                .font(.subheadline)
            Text("스와이프하고 손가락으로 핀치해 깊이를 이동하세요")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 4)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var sceneStatusOverlay: some View {
        switch viewModel.scenePhase {
        case .loading:
            if onSceneLoadingChange == nil {
                PhotoExploreLoadingView()
            }

        case .failed:
            ContentUnavailableView {
                Label(
                    "사진을 표시하지 못했어요",
                    systemImage: "photo.badge.exclamationmark"
                )
            } description: {
                Text("사진 주소 또는 네트워크 상태를 확인해주세요.")
            } actions: {
                Button("다시 시도", action: viewModel.retrySceneLoad)
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.regularMaterial)

        case .ready:
            EmptyView()
        }
    }

    private func selectionGesture(in viewportSize: CGSize) -> some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                guard viewModel.canInteract,
                      let id = renderer.placeID(for: value.entity) else { return }

                if id == viewModel.selectedPlaceID,
                   let selectedPlace = viewModel.selectedPlace {
                    presentedPlace = selectedPlace
                    return
                }

                withAnimation(standardAnimation) {
                    viewModel.select(placeID: id, in: viewportSize)
                }
            }
    }

    private func cameraGesture(in viewportSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: CGFloat(settings.dragStartDistance))
            .simultaneously(
                with: MagnifyGesture(
                    minimumScaleDelta: CGFloat(settings.pinchStartDelta)
                )
            )
            .updating($isCameraGestureActive) { _, state, _ in
                guard viewModel.canInteract else { return }
                state = true
            }
            .onChanged { value in
                guard viewModel.canInteract else { return }

                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    if !viewModel.isInteracting {
                        viewModel.beginGesture(
                            at: renderer.stopCameraAnimation()
                        )
                    }

                    viewModel.updateGesture(
                        Self.cameraUpdate(from: value),
                        in: viewportSize,
                        settings: settings
                    )
                }
            }
            .onEnded { value in
                guard viewModel.canInteract else { return }

                withAnimation(momentumAnimation) {
                    viewModel.endGesture(
                        Self.cameraUpdate(from: value),
                        projectsMomentum: !reduceMotion,
                        in: viewportSize,
                        settings: settings
                    )
                }
            }
    }

    private typealias CameraGestureValue = SimultaneousGesture<
        DragGesture,
        MagnifyGesture
    >.Value

    private static func cameraUpdate(
        from value: CameraGestureValue
    ) -> PhotoCameraGestureUpdate {
        PhotoCameraGestureUpdate(
            translation: value.first?.translation,
            predictedTranslation: value.first?.predictedEndTranslation,
            magnification: value.second?.magnification,
            magnificationVelocity: value.second?.velocity
        )
    }

    private func loadScene() async {
        guard !viewModel.canInteract else { return }

        viewModel.sceneWillLoad()
        let availableIDs = await renderer.load(viewModel.places)

        guard !Task.isCancelled else { return }
        withAnimation(standardAnimation) {
            viewModel.sceneDidLoad(availableIDs: availableIDs)
        }
    }
}
