import Foundation

public protocol TimeSource {
    var now: Date { get }
}

public struct SystemTime: TimeSource {
    public init() {}
    public var now: Date { Date() }
}
