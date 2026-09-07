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
    private var gestureOrigin: PhotoCameraState?
    private var activeGesture = PhotoCameraGesture()

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
        guard !isInteracting else { return }

        camera = renderedCamera
        gestureOrigin = renderedCamera
        activeGesture = PhotoCameraGesture()
        isInteracting = true
    }

    func updateGesture(
        _ update: PhotoCameraGestureUpdate,
        in viewportSize: CGSize,
        settings: PhotoInteractionSettings
    ) {
        if gestureOrigin == nil {
            beginGesture(at: camera)
        }

        activeGesture.merge(update)
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

    func updateAutomaticSelection(
        for camera: PhotoCameraState,
        in viewportSize: CGSize
    ) {
        let nearestID = nearestPlace(
            from: camera,
            keeping: selectedPlaceID,
            in: viewportSize
        )?.id

        guard nearestID != selectedPlaceID else { return }
        selectedPlaceID = nearestID
    }

    func select(placeID: PhotoDestination.ID, in viewportSize: CGSize) {
        guard let place = availablePlaces.first(where: { $0.id == placeID }),
              selectionPolicy.isSelectable(
                place,
                from: camera,
                viewportSize: viewportSize
              ) else { return }

        commitSelection(place, from: camera)
    }

    func endGesture(
        _ update: PhotoCameraGestureUpdate,
        projectsMomentum: Bool,
        in viewportSize: CGSize,
        settings: PhotoInteractionSettings
    ) {
        let origin = gestureOrigin ?? camera
        activeGesture.merge(update)

        let finalGesture = projectsMomentum
            ? activeGesture.projected(using: settings)
            : activeGesture
        let projectedCamera = origin.applying(
            finalGesture,
            in: viewportSize,
            settings: settings
        )
        let magnetTarget = selectionPolicy.nearestMagnetTarget(
            from: projectedCamera,
            among: availablePlaces,
            viewportSize: viewportSize,
            settings: settings
        )
        let finalCamera = magnetTarget.map {
            selectionPolicy.focusedCamera(from: projectedCamera, on: $0)
        } ?? projectedCamera

        finishInteraction()
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
        finishInteraction()
    }

    func reset(in viewportSize: CGSize) {
        finishInteraction()
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
        selectedPlaceID = place.id
        self.camera = selectionPolicy.focusedCamera(from: camera, on: place)
    }

    private func finishInteraction() {
        gestureOrigin = nil
        activeGesture = PhotoCameraGesture()
        isInteracting = false
    }
}
