//
//  RealityPhotoRenderer.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/28/26.
//

import CoreGraphics
import Foundation
import Metal
import RealityKit
import UIKit

/// `SpatialPlaceItem`을 RealityKit 엔티티로 표현하는 렌더링 전용 객체입니다.
@MainActor
final class RealityPhotoRenderer {
    private enum Constants {
        static let entityNamePrefix = "photo:"
        static let minimumOpacity: Float = 0.20
        static let selectionFrameName = "selection-frame"
        static let maximumBlurMipBias: Float = 2
    }

    private struct PhotoEntry {
        let item: SpatialPlaceItem
        let entity: ModelEntity
    }

    private struct LoadedPhoto: @unchecked Sendable {
        let id: PhotoDestination.ID
        let image: CGImage
    }

    let root = Entity()
    let camera = PerspectiveCamera()

    private var entries: [PhotoDestination.ID: PhotoEntry] = [:]
    private var loadGeneration = UUID()
    private let focusShader: CustomMaterial.SurfaceShader?

    init() {
        focusShader = MTLCreateSystemDefaultDevice()?.makeDefaultLibrary().map {
            CustomMaterial.SurfaceShader(named: "photoFocusSurface", in: $0)
        }
        root.name = "photo-scene"
        camera.name = "photo-camera"
        camera.camera = PerspectiveCameraComponent(
            near: 0.01,
            far: 100,
            fieldOfViewInDegrees: PhotoSpace.verticalFieldOfViewDegrees,
            fieldOfViewOrientation: .vertical
        )
    }

    func load(_ items: [SpatialPlaceItem]) async -> Set<PhotoDestination.ID> {
        let generation = UUID()
        loadGeneration = generation
        resetScene()

        for item in items {
            let entity = makePhotoEntity(for: item)
            entries[item.id] = PhotoEntry(item: item, entity: entity)
            root.addChild(entity)
        }

        let remoteIDs = Set(
            items.lazy
                .filter { $0.imageURL != nil }
                .map(\.id)
        )
        let loadedIDs = await loadRemotePhotos(
            for: items,
            generation: generation
        )

        guard !Task.isCancelled, loadGeneration == generation else {
            return []
        }

        for id in remoteIDs.subtracting(loadedIDs) {
            removeEntry(id: id)
        }

        return Set(entries.keys)
    }

    func render(
        camera pose: PhotoCameraState,
        selectedPlaceID: PhotoDestination.ID?,
        photoScale: Float,
        viewportSize: CGSize
    ) {
        updateCamera(pose)
        updateAppearance(
            camera: pose,
            selectedPlaceID: selectedPlaceID,
            photoScale: photoScale,
            viewportSize: viewportSize
        )
    }

    /// 상세 화면과 배경에 같은 사진이 겹치지 않게 하며, 닫으면 기존 공간을 복원합니다.
    func setPresentedPlaceID(_ id: PhotoDestination.ID?) {
        for (placeID, entry) in entries {
            entry.entity.isEnabled = placeID != id
        }
    }

    private func updateCamera(_ pose: PhotoCameraState) {
        camera.position = pose.position
    }

    /// 진행 중인 관성을 현재 프레임에서 멈추고 그 위치를 반환합니다.
    func stopCameraAnimation() -> PhotoCameraState {
        let currentPosition = camera.position
        camera.stopAllAnimations(recursive: false)
        camera.position = currentPosition
        return PhotoCameraState(position: currentPosition)
    }

    private func updateAppearance(
        camera pose: PhotoCameraState,
        selectedPlaceID: PhotoDestination.ID?,
        photoScale: Float,
        viewportSize: CGSize
    ) {
        for (id, entry) in entries {
            let focusAmount = max(
                0,
                1 - (
                    pose.depthError(to: entry.entity.position)
                        / PhotoSpace.focusFadeRange
                )
            )
            let opacity = Constants.minimumOpacity
                + (focusAmount * (1 - Constants.minimumOpacity))

            entry.entity.components.set(OpacityComponent(opacity: opacity))
            entry.entity.findEntity(named: Constants.selectionFrameName)?.isEnabled = id == selectedPlaceID
            updateFocusTransform(on: entry, camera: pose, photoScale: photoScale, viewportSize: viewportSize)
        }
    }

    private func updateFocusTransform(
        on entry: PhotoEntry,
        camera pose: PhotoCameraState,
        photoScale: Float,
        viewportSize: CGSize
    ) {
        guard let bounds = entry.entity.model?.mesh.bounds.extents,
              let focusedScale = PhotoSpace.focusedScale(
                photoSize: SIMD2(bounds.x, bounds.y),
                forwardDepth: pose.position.z - entry.entity.position.z,
                viewportSize: viewportSize
              ) else { return }

        // 선택 ID가 바뀌는 순간이 아닌, 연속적인 초점 깊이를 기준으로 보정합니다.
        let progress = PhotoSpace.focusProgress(depthError: pose.depthError(to: entry.entity.position))
        let scale = photoScale + (focusedScale - photoScale) * progress
        entry.entity.scale = SIMD3(repeating: scale)
        entry.entity.orientation = simd_slerp(
            spatialOrientation(for: entry.item),
            simd_quatf(angle: 0, axis: SIMD3(0, 1, 0)),
            progress
        )
    }

    func placeID(for entity: Entity) -> PhotoDestination.ID? {
        var current: Entity? = entity

        while let candidate = current {
            if candidate.name.hasPrefix(Constants.entityNamePrefix) {
                return String(
                    candidate.name.dropFirst(Constants.entityNamePrefix.count)
                )
            }
            current = candidate.parent
        }

        return nil
    }

    // MARK: - Entity construction

    private func makePhotoEntity(for item: SpatialPlaceItem) -> ModelEntity {
        let entity = ModelEntity()
        entity.name = Constants.entityNamePrefix + item.id
        entity.position = PhotoSpace.position(for: item)
        entity.orientation = spatialOrientation(for: item)

        configureVisual(
            on: entity,
            for: item,
            aspectRatio: Float(item.fallbackAspectRatio),
            material: makeMaterial()
        )
        configureAccessibility(on: entity, label: item.name)
        return entity
    }

    private func spatialOrientation(for item: SpatialPlaceItem) -> simd_quatf {
        simd_quatf(
            angle: Float(item.yaw * .pi / 180) * 0.45,
            axis: SIMD3<Float>(0, 1, 0)
        )
    }

    private func loadRemotePhotos(
        for items: [SpatialPlaceItem],
        generation: UUID
    ) async -> Set<PhotoDestination.ID> {
        var loadedIDs: Set<PhotoDestination.ID> = []

        await withTaskGroup(of: LoadedPhoto?.self) { group in
            for item in items {
                guard let url = item.imageURL else { continue }
                let id = item.id

                group.addTask {
                    guard let image = try? await RemotePhotoImageLoader.image(
                        from: url
                    ) else { return nil }

                    return LoadedPhoto(id: id, image: image)
                }
            }

            for await loadedPhoto in group {
                guard !Task.isCancelled, loadGeneration == generation else {
                    group.cancelAll()
                    break
                }
                guard let loadedPhoto else { continue }

                if await apply(loadedPhoto, generation: generation) {
                    loadedIDs.insert(loadedPhoto.id)
                }
            }
        }

        return loadedIDs
    }

    private func apply(
        _ loadedPhoto: LoadedPhoto,
        generation: UUID
    ) async -> Bool {
        guard loadGeneration == generation,
              let entry = entries[loadedPhoto.id] else { return false }

        do {
            let options = TextureResource.CreateOptions(
                semantic: .color,
                mipmapsMode: .allocateAndGenerateAll
            )
            let texture = try await TextureResource(
                image: loadedPhoto.image,
                withName: loadedPhoto.id,
                options: options
            )

            try Task.checkCancellation()
            guard loadGeneration == generation else { return false }

            let aspectRatio = Float(loadedPhoto.image.width)
                / Float(max(loadedPhoto.image.height, 1))
            configureVisual(
                on: entry.entity,
                for: entry.item,
                aspectRatio: aspectRatio,
                material: makeMaterial(texture: texture)
            )
            return true
        } catch {
            return false
        }
    }

    private func configureVisual(
        on entity: ModelEntity,
        for item: SpatialPlaceItem,
        aspectRatio: Float,
        material: any Material
    ) {
        let width = PhotoSpace.width(for: item)
        let validAspectRatio = aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 1
        let height = width / validAspectRatio
        let mesh = MeshResource.generatePlane(
            width: width,
            height: height,
            cornerRadius: 0.01
        )

        entity.model = ModelComponent(mesh: mesh, materials: [material])

        // 흰색 얇은 프레임은 실제 사진 비율에 맞추고 선택된 사진에만 표시합니다.
        let selectionFrame = entity.findEntity(named: Constants.selectionFrameName) as? ModelEntity
            ?? ModelEntity()
        selectionFrame.name = Constants.selectionFrameName
        selectionFrame.model = ModelComponent(
            mesh: .generatePlane(width: width + 0.008, height: height + 0.008, cornerRadius: 0.01),
            materials: [UnlitMaterial(color: .white)]
        )
        selectionFrame.position.z = -0.002
        selectionFrame.isEnabled = false
        if selectionFrame.parent == nil { entity.addChild(selectionFrame) }

        entity.components.set(InputTargetComponent())
        entity.components.set(
            CollisionComponent(
                shapes: [
                    ShapeResource.generateBox(
                        size: SIMD3<Float>(width, height, 0.02)
                    )
                ]
            )
        )
    }

    private func makeMaterial(texture: TextureResource? = nil) -> any Material {
        var material = texture.map(UnlitMaterial.init(texture:))
            ?? UnlitMaterial()
        material.faceCulling = .none
        material.readsDepth = true
        material.writesDepth = true

        // 기존 mipmap을 재사용합니다. 셰이더를 쓸 수 없으면 원본 사진은 그대로 표시합니다.
        guard texture != nil, let focusShader,
              var focusMaterial = try? CustomMaterial(from: material, surfaceShader: focusShader)
        else { return material }

        focusMaterial.custom.value = SIMD4(
            PhotoSpace.focusDistance,
            PhotoSpace.sharpDepthTolerance,
            PhotoSpace.focusFadeRange,
            Constants.maximumBlurMipBias
        )
        return focusMaterial
    }

    private func configureAccessibility(
        on entity: ModelEntity,
        label: String
    ) {
        var accessibility = AccessibilityComponent()
        accessibility.isAccessibilityElement = true
        accessibility.label = LocalizedStringResource(stringLiteral: label)
        accessibility.systemActions = [.activate]
        entity.components.set(accessibility)
    }

    private func removeEntry(id: PhotoDestination.ID) {
        entries[id]?.entity.removeFromParent()
        entries[id] = nil
    }

    private func resetScene() {
        for entry in entries.values {
            entry.entity.removeFromParent()
        }
        entries.removeAll()
    }
}
