//
//  SpatialPhotoCanvas.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/28/26.
//

import CoreLocation
import RealityKit
import SwiftUI

/// SwiftUI 입력을 ViewModel과 RealityKit 렌더러에 연결하는 화면입니다.
struct SpatialPhotoCanvas: View {
    private let onConfirm: (PhotoDestination) -> Void
    private let sourceNotice: String?
    private let originLocation: CLLocation?
    private let directionsService: any RouteDirectionsProviding
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
        sourceNotice: String? = nil,
        originLocation: CLLocation? = nil,
        directionsService: any RouteDirectionsProviding = KakaoDirectionsService(),
        onSceneLoadingChange: ((Bool) -> Void)? = nil,
        onConfirm: @escaping (PhotoDestination) -> Void
    ) {
        self.onConfirm = onConfirm
        self.sourceNotice = sourceNotice
        self.originLocation = originLocation
        self.directionsService = directionsService
        self.onSceneLoadingChange = onSceneLoadingChange
        _viewModel = State(
            initialValue: SpatialPhotoCanvasViewModel(
                places: SpatialPlaceItem.compose(from: destinations)
            )
        )
    }

    var body: some View {
        GeometryReader { geometry in
            canvas(in: geometry.size)
        }
        .ignoresSafeArea(edges: .bottom)
        .sensoryFeedback(.selection, trigger: viewModel.selectedPlaceID)
        .fullScreenCover(item: $presentedPlace) { item in
            DestinationDetailView(
                destination: item.destination,
                originLocation: originLocation,
                directionsService: directionsService
            ) {
                onConfirm(item.destination)
            }
        }
    }

    private func interactiveScene(in viewportSize: CGSize) -> some View {
        ZStack {
            PhotoExploreBackground()
            photoScene(in: viewportSize)
            if viewModel.canInteract {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(photoTapGesture(in: viewportSize))
                    .accessibilityHidden(true)
            }
            sceneStatusOverlay
        }
        .contentShape(Rectangle())
        .simultaneousGesture(cameraGesture(in: viewportSize))
        .clipped()
        .onChange(of: viewModel.camera) { _, newCamera in
            withAnimation(standardAnimation) {
                viewModel.updateAutomaticSelection(
                    for: newCamera,
                    in: viewportSize
                )
            }
        }
        .onChange(of: isCameraGestureActive) { wasActive, isActive in
            guard wasActive, !isActive else { return }
            withAnimation(momentumAnimation) { viewModel.cancelGesture() }
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
    }

    private func canvas(in viewportSize: CGSize) -> some View {
        interactiveScene(in: viewportSize)
            .overlay(alignment: .topLeading) {
                if viewModel.canInteract {
                    header
                        .opacity(presentedPlace == nil ? 1 : 0)
                }
            }
            .blur(radius: presentedPlace == nil ? 0 : 5)
            .allowsHitTesting(presentedPlace == nil)
            .accessibilityHidden(presentedPlace != nil)
            .onChange(of: viewModel.scenePhase, initial: true) { _, phase in
                onSceneLoadingChange?(phase == .loading)
            }
            .onChange(of: presentedPlace?.id) { _, id in
                renderer.setPresentedPlaceID(id)
            }
            .toolbar(viewModel.scenePhase == .loading ? .hidden : .visible, for: .navigationBar)
#if DEBUG
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("화면 맞춤", systemImage: "scope") {
                        withAnimation(standardAnimation) {
                            viewModel.reset(in: viewportSize)
                        }
                    }
                    .labelStyle(.iconOnly)
                    .disabled(!viewModel.canInteract)

                    Button("조작 설정", systemImage: "slider.horizontal.3") {
                        isShowingSettings = true
                    }
                    .labelStyle(.iconOnly)
                    .popover(isPresented: $isShowingSettings, arrowEdge: .top) {
                        PhotoInteractionSettingsPanel(settings: $settings)
                    }
                }
            }
#endif
            .task(id: viewModel.sceneLoadRequest) {
                await loadScene()
            }
            .task(id: viewModel.canInteract) {
                guard viewModel.canInteract else { return }
                // 부모 로딩 화면의 페이드아웃 뒤, 기존 초기 카메라에서 천천히 접근합니다.
                if !reduceMotion {
                    do { try await Task.sleep(for: .milliseconds(350)) }
                    catch { return }
                }
                guard !Task.isCancelled else { return }
                withAnimation(introAnimation) {
                    viewModel.startIntroZoom(settings: settings)
                }
            }
    }

    private func photoScene(in viewportSize: CGSize) -> some View {
        let camera = viewModel.camera

        return RealityView { content in
            content.camera = .virtual
            // 사진별 초점 셰이더와 시스템 심도 효과가 중복되지 않게 합니다.
            content.renderingEffects.depthOfField = .disabled
            content.add(renderer.root)
            content.add(renderer.camera)
            renderer.render(
                camera: camera,
                selectedPlaceID: viewModel.selectedPlaceID,
                photoScale: Float(settings.photoScale),
                viewportSize: viewportSize
            )
        } update: { content in
            if viewModel.isInteracting || reduceMotion {
                renderer.render(
                    camera: camera,
                    selectedPlaceID: viewModel.selectedPlaceID,
                    photoScale: Float(settings.photoScale),
                    viewportSize: viewportSize
                )
            } else {
                content.animate {
                    renderer.render(
                        camera: camera,
                        selectedPlaceID: viewModel.selectedPlaceID,
                        photoScale: Float(settings.photoScale),
                        viewportSize: viewportSize
                    )
                }
            }
        }
        .realityViewCameraControls(.none)
        .mask {
            // 사진이 상단 안내를 가리지 않게 공간의 위쪽만 부드럽게 걷어냅니다.
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.12),
                    .init(color: .white, location: 0.28)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var standardAnimation: Animation? {
        reduceMotion ? nil : .default
    }

    private var introAnimation: Animation? {
        // 초반 가속 없이 거의 일정하게 접근하고, 끝으로 갈수록 감속합니다.
        reduceMotion ? nil : .timingCurve(
            0.4, 0.5, 0.8, 1,
            duration: settings.initialZoomDuration
        )
    }

    private var momentumAnimation: Animation? {
        reduceMotion
            ? nil
            : .smooth(duration: settings.settlingDuration, extraBounce: 0)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("사진으로 목적지 고르기")
                .font(PicselFont.title02)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 0) {
                // 실제 거리 필터가 연결되기 전에는 시안의 80km를 고정 표기하지 않습니다.
                Text("마음에 드는 사진을 골라보세요")
                Text("화면을 확대·축소해 둘러보고, 마음에 드는 풍경을 선택해보세요")
            }
            .font(PicselFont.body01)
            .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(PicselColor.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background {
            LinearGradient(
                colors: [PicselColor.surface, PicselColor.surface.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
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

    private func photoTapGesture(in viewportSize: CGSize) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                guard viewModel.canInteract,
                      let id = renderer.placeID(at: value.location, in: viewportSize) else { return }

                if id == viewModel.selectedPlaceID,
                   let selectedPlace = viewModel.selectedPlace {
                    presentedPlace = selectedPlace
                    return
                }

                withAnimation(momentumAnimation) {
                    viewModel.select(placeID: id)
                }
            }
    }

    private func cameraGesture(in viewportSize: CGSize) -> some Gesture {
        // 가벼운 탭이 0pt 드래그로 인식되어 사진 선택을 덮어쓰지 않게 합니다.
        DragGesture(minimumDistance: CGFloat(max(8, settings.dragStartDistance)))
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
