import Foundation

@main
struct SnapChecks {
    struct Failed: Error { let message: String }
    static var count = 0
    static let viewport = CGSize(width: 393, height: 852)
    static let settings = PhotoInteractionSettings.defaults
    static let places = SpatialPlaceItem.compose(from: (1...7).map {
        PhotoDestination(id: "photo-\($0)", name: "Photo \($0)")
    })

    static func check(_ condition: Bool, _ message: String) throws {
        guard condition else { throw Failed(message: message) }
        count += 1
    }

    static func ready(_ available: [SpatialPlaceItem] = places) -> SpatialPhotoCanvasViewModel {
        let vm = SpatialPhotoCanvasViewModel(places: places)
        vm.sceneDidLoad(availableIDs: Set(available.map(\.id)))
        return vm
    }

    static func drag(from a: SpatialPlaceItem, to b: SpatialPlaceItem, length: CGFloat = 90) -> CGSize {
        let x = a.position.x - b.position.x, y = a.position.y - b.position.y
        let distance = hypot(x, y)
        return CGSize(width: x * length / distance, height: y * length / distance)
    }

    static func swipe(_ vm: SpatialPhotoCanvasViewModel, to target: SpatialPlaceItem, momentum: Bool = false) {
        let translation = drag(from: vm.selectedPlace!, to: target)
        vm.beginGesture(at: vm.camera)
        vm.updateGesture(.init(translation: translation), in: viewport, settings: settings)
        vm.endGesture(.init(translation: translation, predictedTranslation: translation),
                      projectsMomentum: momentum, in: viewport, settings: settings)
    }

    // 사용자가 직접 사진의 초점 깊이까지 이동한 뒤 마그넷이 붙는 경로로 준비합니다.
    static func focus(_ vm: SpatialPhotoCanvasViewModel, on place: SpatialPlaceItem = places[0]) {
        vm.beginGesture(at: PhotoCameraState.initial.focused(on: PhotoSpace.position(for: place)))
        vm.endGesture(.init(), projectsMomentum: false, in: viewport, settings: settings)
    }

    static func main() throws {
        let policy = PhotoSnapNavigation()
        let hub = places[0]
        let ring = [2, 7, 3, 4, 6, 5]
        try check(places.map(\.placementNumber) == Array(1...7), "Stable one-based placement numbers")
        try check(policy.neighbors(of: hub, among: places).count == 6, "Hub connects to every outer photo")
        for (index, slot) in ring.enumerated() {
            let current = places[slot - 1]
            let neighbors = Set(policy.neighbors(of: current, among: places).map(\.placementNumber))
            try check(neighbors == Set([1, ring[(index + 5) % 6], ring[(index + 1) % 6]]), "Ring adjacency for \(slot)")
        }
        for source in places {
            for target in policy.neighbors(of: source, among: places) {
                let result = policy.target(from: source, translation: drag(from: source, to: target),
                                           among: places, minimumDistance: 32)
                try check(result.id == target.id, "Directional edge \(source.placementNumber) → \(target.placementNumber)")
            }
        }
        let vm = ready()
        try check(vm.camera == .initial, "Ready scene retains original overview before intro")
        vm.startIntroZoom(settings: settings)
        let introCamera = vm.camera
        try check(settings.initialZoomDuration == 4, "Intro preserves the tuned four-second duration")
        try check(abs(PhotoCameraState.initial.position.z - introCamera.position.z - 0.8) < 0.0001,
                  "Intro approaches by the increased distance")
        try check(introCamera.position.x == 0 && introCamera.position.y == 0 && vm.selectedPlaceID == nil,
                  "Intro does not center or select a photo")
        for step in 0...10 {
            let progress = Float(step) / 10
            let camera = PhotoCameraState(position: PhotoCameraState.initial.position
                + (introCamera.position - PhotoCameraState.initial.position) * progress)
            vm.updateAutomaticSelection(for: camera, in: viewport)
            try check(vm.selectedPlaceID == nil && places.allSatisfy {
                camera.depthError(to: PhotoSpace.position(for: $0)) > PhotoSpace.selectionDepthTolerance
            }, "Entire intro stays outside photo focus at step \(step)")
        }
        vm.startIntroZoom(settings: settings)
        try check(vm.camera == introCamera, "Intro is one-shot")
        let exaggerated = ready()
        var largeZoom = settings
        largeZoom.initialZoomDistance = 10
        exaggerated.startIntroZoom(settings: largeZoom)
        try check(places.allSatisfy {
            exaggerated.camera.depthError(to: PhotoSpace.position(for: $0)) > Float(settings.magnetDepthTolerance)
        }, "Intro zoom amount is capped outside magnet depth")
        focus(vm)
        let initialFocus = vm.camera
        try check(vm.selectedPlaceID == hub.id, "User focus starts hub navigation")
        vm.select(placeID: places[1].id)
        for slot in [7, 3, 4, 6, 5, 2] {
            swipe(vm, to: places[slot - 1], momentum: true)
            try check(vm.selectedPlace?.placementNumber == slot, "Clockwise ring visit \(slot)")
        }
        for slot in [5, 6, 4, 3, 7, 2] {
            swipe(vm, to: places[slot - 1])
            try check(vm.selectedPlace?.placementNumber == slot, "Counterclockwise ring visit \(slot)")
        }
        for place in places where place.id != hub.id {
            let connected = ready()
            focus(connected)
            swipe(connected, to: place)
            try check(connected.selectedPlaceID == place.id, "Hub swipe reaches \(place.placementNumber)")
            swipe(connected, to: hub)
            try check(connected.selectedPlaceID == hub.id, "Outer swipe returns to hub")
        }

        // 직접 탭은 연결 고리와 거리 제한 없이 이동합니다.
        vm.select(placeID: places[3].id)
        try check(vm.selectedPlace?.placementNumber == 4, "Direct tap reaches an unconnected photo")
        let distant = ready()
        distant.select(placeID: places[3].id)
        try check(distant.selectedPlace?.placementNumber == 4, "Direct tap works from initial distant camera")
        vm.select(placeID: places[1].id)
        vm.beginGesture(at: vm.camera)
        vm.updateGesture(.init(translation: .init(width: 4, height: 3)), in: viewport, settings: settings)
        vm.endGesture(.init(), projectsMomentum: false, in: viewport, settings: settings)
        try check(vm.selectedPlace?.placementNumber == 2, "Short drag returns to current photo")
        vm.beginGesture(at: vm.camera)
        vm.updateGesture(.init(translation: .init(width: -2_000, height: 2_000)), in: viewport, settings: settings)
        vm.updateAutomaticSelection(for: vm.camera, in: viewport)
        try check(vm.selectedPlace?.placementNumber == 2, "Free drag cannot replace graph source mid-gesture")
        vm.endGesture(.init(), projectsMomentum: true, in: viewport, settings: settings)
        try check(Set([2, 1, 5, 7]).contains(vm.selectedPlace!.placementNumber), "Large flick remains one hop")
        let afterDrag = vm.camera
        vm.startIntroZoom(settings: settings)
        try check(vm.camera == afterDrag, "Reappearance does not replay intro")

        let tapped = ready()
        focus(tapped)
        tapped.beginGesture(at: tapped.camera)
        tapped.select(placeID: places[1].id)
        tapped.endGesture(.init(), projectsMomentum: false, in: viewport, settings: settings)
        try check(tapped.selectedPlace?.placementNumber == 2, "Zero-distance drag does not swallow connected tap")

        let pinched = ready()
        focus(pinched)
        pinched.beginGesture(at: pinched.camera)
        pinched.updateGesture(.init(magnification: 0.5), in: viewport, settings: settings)
        pinched.endGesture(.init(), projectsMomentum: false, in: viewport, settings: settings)
        try check(pinched.camera.position.z > initialFocus.position.z + 0.5, "Pinch-out is not immediately snapped back")
        pinched.reset(in: viewport)
        pinched.startIntroZoom(settings: settings)
        try check(pinched.camera == .initial, "Overview reset does not replay intro")

        let interrupted = ready()
        interrupted.beginGesture(at: .initial)
        interrupted.startIntroZoom(settings: settings)
        try check(interrupted.camera == .initial && interrupted.selectedPlaceID == nil, "User input cancels delayed intro")
        let cancelled = ready()
        focus(cancelled)
        cancelled.beginGesture(at: cancelled.camera)
        cancelled.updateGesture(.init(translation: .init(width: 90, height: 80)), in: viewport, settings: settings)
        cancelled.cancelGesture()
        try check(cancelled.camera == initialFocus && !cancelled.isInteracting, "Gesture cancellation returns to anchor")

        let missing = places.filter { ![1, 7].contains($0.placementNumber) }
        let missingVM = ready(missing)
        missingVM.startIntroZoom(settings: settings)
        try check(missingVM.selectedPlaceID == nil && missingVM.camera.position.z < PhotoCameraState.initial.position.z,
                  "Missing hub still starts with an unfocused overview")
        try check(Set(policy.neighbors(of: places[1], among: missing).map(\.placementNumber)) == Set([3, 5]),
                  "Missing ring photo is skipped without changing placement numbers")
        let single = ready([places[1]])
        single.startIntroZoom(settings: settings)
        try check(single.selectedPlaceID == nil && policy.neighbors(of: places[1], among: [places[1]]).isEmpty,
                  "Single remaining photo has no invalid edge")
        let empty = ready([])
        empty.startIntroZoom(settings: settings)
        try check(empty.scenePhase == .failed && empty.selectedPlaceID == nil, "No loaded photos retains retry screen")
        print("PASS: \(count) photo snap navigation checks (no network / renderer)")
    }
}
