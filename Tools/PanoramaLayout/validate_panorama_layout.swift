// Runs the production card views on macOS with synthetic images. No API or user data.
import AppKit
import SwiftUI

// Only networking, app models, fonts and device haptics are substituted.
enum PicselColor {
    static let pixelLockedFill = Color.gray
    static let textOnBrand = Color.white
    static let backgroundWarmWhite = Color.white
}
enum PicselFont {
    static let title03 = Font.headline
    static let body02 = Font.body
}
struct RouteStop {
    let name = "파노라마 장소"
    let address: String? = "경상북도 포항시"
    let photoURL: String? = nil
    let trip: TestTrip? = nil
}
struct TestTrip { let id: UUID }
enum ShortAddress { static func make(from value: String?) -> String? { value } }
struct UIImpactFeedbackGenerator {
    enum Style { case medium, rigid }
    init(style: Style) {}
    func impactOccurred() {}
}
@MainActor enum Fixture {
    static var image: CGImage!
    static var photo: Image { Image(decorative: image, scale: 1) }
}
struct AsyncImage<Content: View>: View {
    let content: (AsyncImagePhase) -> Content
    init(url: URL?, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.content = content
    }
    var body: some View { content(.success(Fixture.photo)) }
}
struct RemotePlacePhoto: View {
    let url: URL?
    let tripID: UUID?
    // Deliberately return an unconstrained image to test the card's own boundary.
    var body: some View { Fixture.photo.resizable().scaledToFill() }
}

@main
struct PanoramaLayoutChecks {
    @MainActor static func main() throws {
        var checks = 0
        for ratio: CGFloat in [12, 2.2, 4.0 / 3, 3.0 / 4, 1] {
            let context = CGContext(
                data: nil, width: Int(500 * ratio), height: 500,
                bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            context.setFillColor(CGColor(red: 0, green: 1, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: context.width, height: context.height))
            Fixture.image = context.makeImage()!

            for width: CGFloat in [280, 334, 390] {
                let history = TripHistoryCard(
                    title: "파노라마 여행", travelDate: .now, placeCount: 3,
                    photoURL: URL(string: "https://example.invalid/fixture.jpg")
                )
                let visited = VisitedPlaceCardView(
                    stop: RouteStop(), photoURL: nil, isSelected: true,
                    toggleSelection: {}, onSwipeDown: {}, onSwipeUp: {}
                )
                for (name, card) in [("history", AnyView(history)), ("visited", AnyView(visited))] {
                    let renderer = ImageRenderer(content: card)
                    renderer.proposedSize = ProposedViewSize(width: width, height: nil)
                    guard let image = renderer.cgImage else { fatalError("No render: \(name)") }
                    precondition(image.width == Int(width), "\(name) expanded at ratio \(ratio): \(image.width)")
                    if name == "history" { precondition(image.height == 190) }
                    checks += 1

                    // Padding exposes overflow that a root screenshot would otherwise crop.
                    let padded = ImageRenderer(content: card.frame(width: width).padding(32))
                    let bitmap = NSBitmapImageRep(cgImage: padded.cgImage!)
                    for x in [16, Int(width) + 48] {
                        for y in 32..<(bitmap.pixelsHigh - 32) {
                            let color = bitmap.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
                            precondition(!(color.greenComponent > 0.7 && color.redComponent < 0.3
                                           && color.blueComponent < 0.3 && color.alphaComponent > 0.5),
                                         "\(name) photo bleeds outside its card at ratio \(ratio)")
                        }
                    }
                    checks += 1
                }
            }
        }
        print("PASS: \(checks) actual-card layout/overflow checks (no network)")
    }
}
