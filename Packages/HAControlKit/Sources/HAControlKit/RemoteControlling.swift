import Foundation

@MainActor
public protocol RemoteControlling: AnyObject {
    var playbackState: PlaybackState { get }
    var brightness: Double { get }
    var albumOptions: [String] { get }
    var currentAlbum: String? { get }
    func pause()
    func resume()
    func setBrightness(_ value: Double) async
    func selectAlbum(_ name: String)
    var onLocalChange: (@MainActor () -> Void)? { get set }
}
