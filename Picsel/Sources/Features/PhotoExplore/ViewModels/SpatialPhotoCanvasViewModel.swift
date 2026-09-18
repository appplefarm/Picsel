//
//  SpatialPhotoCanvasViewModel.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/28/26.
//

import CoreGraphics
import Observation

/// 공간 사진 탐색의 상태와 사용자 입력 규칙을 관리합니다.
@MainActor
@Observable
final class SpatialPhotoCanvasViewModel {
    enum ScenePhase: Equatable {
        case loading
        case ready(Set<PhotoDestination.ID>)
        case failed
    }

    let places: [SpatialPlaceItem]

    private let selectionPolicy = PhotoSelectionPolicy()
    private let snapNavigation = PhotoSnapNavigation()
    private var gestureOrigin: PhotoCameraState?
    private var activeGesture = PhotoCameraGesture()
    private var snapAnchorID: PhotoDestination.ID?
    private var gestureAnchorID: PhotoDestination.ID?
    private var didPinch = false
    private var hasStartedExploration = false

    private(set) var selectedPlaceID: PhotoDestination.ID?
    private(set) var camera = PhotoCameraState.initial
    private(set) var isInteracting = false
    private(set) var scenePhase = ScenePhase.loading
    private(set) var sceneLoadRequest = 0

    init(places: [SpatialPlaceItem]) {
        var seenIDs: Set<PhotoDestination.ID> = []
        self.places = places.filter { seenIDs.insert($0.id).inserted }
    }

    var selectedPlace: SpatialPlaceItem? {
        availablePlaces.first { $0.id == selectedPlaceID }
    }

    var availablePlaces: [SpatialPlaceItem] {
        guard case let .ready(ids) = scenePhase else { return [] }
        return places.filter { ids.contains($0.id) }
    }

    var canInteract: Bool {
        if case .ready = scenePhase { return true }
        return false
    }

    func beginGesture(at renderedCamera: PhotoCameraState) {
        guard canInteract, !isInteracting else { return }

        hasStartedExploration = true
        camera = renderedCamera
        gestureOrigin = renderedCamera
        gestureAnchorID = snapAnchorID
        activeGesture = PhotoCameraGesture()
        didPinch = false
        isInteracting = true
    }

    func updateGesture(
        _ update: PhotoCameraGestureUpdate,
        in viewportSize: CGSize,
        settings: PhotoInteractionSettings
    ) {
        guard canInteract else { return }
        if gestureOrigin == nil {
            beginGesture(at: camera)
        }

        activeGesture.merge(update)
        if abs(activeGesture.magnification - 1) > 0.02 { didPinch = true }
        camera = (gestureOrigin ?? camera).applying(
            activeGesture,
            in: viewportSize,
            settings: settings
        )
    }

    func sceneWillLoad() {
        finishInteraction()
        scenePhase = .loading
        selectedPlaceID = nil
        snapAnchorID = nil
        hasStartedExploration = false
        camera = .initial
    }

    func sceneDidLoad(availableIDs: Set<PhotoDestination.ID>) {
        guard !availableIDs.isEmpty else {
            scenePhase = .failed
            selectedPlaceID = nil
            return
        }

        scenePhase = .ready(availableIDs)
    }

    func retrySceneLoad() {
        sceneLoadRequest += 1
    }

    /// 초점/마그넷 영역 밖에서 조금만 접근합니다. 특정 사진을 선택하거나 가로·세로로 이동하지 않습니다.
    func startIntroZoom(settings: PhotoInteractionSettings) {
        guard !hasStartedExploration, !isInteracting,
              let nearestDepth = availablePlaces.map({ PhotoSpace.position(for: $0).z }).max() else { return }

        hasStartedExploration = true
        snapAnchorID = nil
        selectedPlaceID = nil
        let initial = PhotoCameraState.initial
        // 확대량을 튜닝해도 가장 가까운 사진에 초점이 붙지 않도록 여유 깊이를 확보합니다.
        let unfocusedDepth = nearestDepth + PhotoSpace.focusDistance
            + max(PhotoSpace.selectionDepthTolerance, Float(settings.magnetDepthTolerance)) + 0.1
        camera = initial
        camera.position.z = min(initial.position.z, max(
            initial.position.z - max(0, Float(settings.initialZoomDistance)),
            unfocusedDepth
        ))
    }

    func updateAutomaticSelection(
        for camera: PhotoCameraState,
        in viewportSize: CGSize
    ) {
        guard !isInteracting else { return }
        if let snapAnchorID {
            selectedPlaceID = snapAnchorID
            return
        }
        let nearestID = nearestPlace(
            from: camera,
            keeping: selectedPlaceID,
            in: viewportSize
        )?.id

        guard nearestID != selectedPlaceID else { return }
        selectedPlaceID = nearestID
    }

    func select(placeID: PhotoDestination.ID) {
        guard let place = availablePlaces.first(where: { $0.id == placeID }) else { return }
        // 직접 탭한 사진은 깊이와 마그넷 연결 관계에 상관없이 선택합니다.
        commitSelection(place, from: camera)
    }

    func endGesture(
        _ update: PhotoCameraGestureUpdate,
        projectsMomentum: Bool,
        in viewportSize: CGSize,
        settings: PhotoInteractionSettings
    ) {
        guard canInteract, isInteracting else { return }
        let origin = gestureOrigin ?? camera
        activeGesture.merge(update)
        if abs(activeGesture.magnification - 1) > 0.02 { didPinch = true }

        let finalGesture = projectsMomentum
            ? activeGesture.projected(using: settings)
            : activeGesture
        if !didPinch, let anchor = availablePlaces.first(where: { $0.id == gestureAnchorID }) {
            let target = snapNavigation.target(
                from: anchor,
                translation: finalGesture.translation,
                among: availablePlaces,
                minimumDistance: CGFloat(settings.snapDragThreshold)
            )
            commitSelection(target, from: camera)
            return
        }

        let projectedCamera = origin.applying(
            finalGesture,
            in: viewportSize,
            settings: settings
        )
        // 의도적인 줌아웃은 즉시 되붙이지 않고 전체 공간을 둘러보게 합니다.
        let magnetTarget = activeGesture.magnification < 0.98 ? nil : selectionPolicy.nearestMagnetTarget(
            from: projectedCamera,
            among: availablePlaces,
            viewportSize: viewportSize,
            settings: settings
        )
        let finalCamera = magnetTarget.map {
            selectionPolicy.focusedCamera(from: projectedCamera, on: $0)
        } ?? projectedCamera

        finishInteraction()
        snapAnchorID = magnetTarget?.id
        camera = finalCamera

        guard let nearest = magnetTarget ?? nearestPlace(
            from: finalCamera,
            keeping: selectedPlaceID,
            in: viewportSize
        ) else {
            selectedPlaceID = nil
            return
        }

        selectedPlaceID = nearest.id
    }

    func cancelGesture() {
        guard isInteracting else { return }
        finishInteraction()
        if let anchor = availablePlaces.first(where: { $0.id == snapAnchorID }) {
            commitSelection(anchor, from: camera)
        }
    }

    func reset(in viewportSize: CGSize) {
        finishInteraction()
        hasStartedExploration = true
        snapAnchorID = nil
        camera = .initial
        selectedPlaceID = nearestPlace(
            from: .initial,
            keeping: nil,
            in: viewportSize
        )?.id
    }

    private func nearestPlace(
        from camera: PhotoCameraState,
        keeping selectedID: PhotoDestination.ID?,
        in viewportSize: CGSize
    ) -> SpatialPlaceItem? {
        selectionPolicy.nearestSelectable(
            from: camera,
            among: availablePlaces,
            keeping: selectedID,
            viewportSize: viewportSize
        )
    }

    private func commitSelection(
        _ place: SpatialPlaceItem,
        from camera: PhotoCameraState
    ) {
        finishInteraction()
        hasStartedExploration = true
        snapAnchorID = place.id
        selectedPlaceID = place.id
        self.camera = selectionPolicy.focusedCamera(from: camera, on: place)
    }

    private func finishInteraction() {
        gestureOrigin = nil
        gestureAnchorID = nil
        didPinch = false
        activeGesture = PhotoCameraGesture()
        isInteracting = false
    }
}
