//
//  RealityPhotoRenderer.swift
//  Picsel
//
//  Created by Jonghyeon Lee on 8/28/26.
//

import CoreGraphics
import Foundation
import RealityKit

/// `SpatialPlaceItem`을 RealityKit 엔티티로 표현하는 렌더링 전용 객체입니다.
@MainActor
final class RealityPhotoRenderer {
    private enum Constants {
        static let entityNamePrefix = "photo:"
        static let selectedScale: Float = 1.035
        static let minimumOpacity: Float = 0.38
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

    init() {
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
        photoScale: Float
    ) {
        updateCamera(pose)
        updateAppearance(
            camera: pose,
            selectedPlaceID: selectedPlaceID,
            photoScale: photoScale
        )
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
        photoScale: Float
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
            let selectionScale = id == selectedPlaceID
                ? Constants.selectedScale
                : 1
            entry.entity.scale = SIMD3(repeating: photoScale * selectionScale)
        }
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
        entity.orientation = simd_quatf(
            angle: Float(item.yaw * .pi / 180) * 0.45,
            axis: SIMD3<Float>(0, 1, 0)
        )

        configureVisual(
            on: entity,
            for: item,
            aspectRatio: Float(item.fallbackAspectRatio),
            material: makeMaterial()
        )
        configureAccessibility(on: entity, label: item.name)
        return entity
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
        material: UnlitMaterial
    ) {
        let width = PhotoSpace.width(for: item)
        let height = width / max(aspectRatio, 0.2)
        let mesh = MeshResource.generatePlane(
            width: width,
            height: height,
            cornerRadius: 0.06
        )

        entity.model = ModelComponent(mesh: mesh, materials: [material])
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

    private func makeMaterial(texture: TextureResource? = nil) -> UnlitMaterial {
        var material = texture.map(UnlitMaterial.init(texture:))
            ?? UnlitMaterial()
        material.faceCulling = .none
        material.readsDepth = true
        material.writesDepth = true
        return material
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
