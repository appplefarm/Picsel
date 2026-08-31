//
//  PhotoSelectionPolicy.swift
//  Picsel
//

import CoreGraphics
import Foundation

/// 렌더링과 분리된 순수 선택 규칙입니다.
struct PhotoSelectionPolicy {
    func isSelectable(
        _ item: SpatialPlaceItem,
        from camera: PhotoCameraState,
        viewportSize: CGSize
    ) -> Bool {
        score(for: item, from: camera, viewportSize: viewportSize) != nil
    }

    func nearestSelectable(
        from camera: PhotoCameraState,
        among items: [SpatialPlaceItem],
        keeping currentID: PhotoDestination.ID?,
        viewportSize: CGSize
    ) -> SpatialPlaceItem? {
        let candidates = items.compactMap { item -> (SpatialPlaceItem, Float)? in
            guard let score = score(
                for: item,
                from: camera,
                viewportSize: viewportSize
            ) else { return nil }

            return (item, score)
        }

        guard let nearest = candidates.min(by: { $0.1 < $1.1 }) else {
            return nil
        }

        if let currentID,
           let current = candidates.first(where: { $0.0.id == currentID }),
           current.1 <= nearest.1 + PhotoSpace.selectionHysteresis {
            return current.0
        }

        return nearest.0
    }

    func nearestMagnetTarget(
        from camera: PhotoCameraState,
        among items: [SpatialPlaceItem],
        viewportSize: CGSize,
        settings: PhotoInteractionSettings
    ) -> SpatialPlaceItem? {
        items.compactMap { item -> (SpatialPlaceItem, Float)? in
            guard let score = magnetScore(
                for: item,
                from: camera,
                viewportSize: viewportSize,
                settings: settings
            ) else { return nil }

            return (item, score)
        }
        .min(by: { $0.1 < $1.1 })?
        .0
    }

    func focusedCamera(
        from camera: PhotoCameraState,
        on item: SpatialPlaceItem
    ) -> PhotoCameraState {
        camera.focused(on: PhotoSpace.position(for: item))
    }

    private func score(
        for item: SpatialPlaceItem,
        from camera: PhotoCameraState,
        viewportSize: CGSize
    ) -> Float? {
        let relativePosition = PhotoSpace.position(for: item) - camera.position
        let forwardDepth = -relativePosition.z
        guard forwardDepth > 0.15 else { return nil }

        let depthError = abs(forwardDepth - PhotoSpace.focusDistance)
        guard depthError <= PhotoSpace.selectionDepthTolerance else { return nil }

        let halfVerticalSpan = forwardDepth * tan(
            PhotoSpace.verticalFieldOfViewDegrees * .pi / 360
        )
        let aspectRatio = Float(viewportSize.width / max(viewportSize.height, 1))
        let halfHorizontalSpan = halfVerticalSpan * aspectRatio
        let horizontalLimit = halfHorizontalSpan * PhotoSpace.selectionViewportMargin
        let verticalLimit = halfVerticalSpan * PhotoSpace.selectionViewportMargin

        guard abs(relativePosition.x) <= horizontalLimit,
              abs(relativePosition.y) <= verticalLimit else { return nil }

        // 화면 중심보다 실제 깊이가 가까운 사진을 우선합니다.
        return depthError
    }

    private func magnetScore(
        for item: SpatialPlaceItem,
        from camera: PhotoCameraState,
        viewportSize: CGSize,
        settings: PhotoInteractionSettings
    ) -> Float? {
        let relativePosition = PhotoSpace.position(for: item) - camera.position
        let forwardDepth = -relativePosition.z
        guard forwardDepth > 0.15 else { return nil }

        let depthError = abs(forwardDepth - PhotoSpace.focusDistance)
        guard depthError <= Float(settings.magnetDepthTolerance) else {
            return nil
        }

        let halfVerticalSpan = forwardDepth * tan(
            PhotoSpace.verticalFieldOfViewDegrees * .pi / 360
        )
        let aspectRatio = Float(viewportSize.width / max(viewportSize.height, 1))
        let halfHorizontalSpan = halfVerticalSpan * aspectRatio
        let horizontalDistance = abs(relativePosition.x)
            / max(halfHorizontalSpan, 0.001)
        let verticalDistance = abs(relativePosition.y)
            / max(halfVerticalSpan, 0.001)

        let viewportMargin = Float(settings.magnetViewportMargin)
        guard horizontalDistance <= viewportMargin,
              verticalDistance <= viewportMargin else {
            return nil
        }

        return depthError + hypot(horizontalDistance, verticalDistance)
    }
}
