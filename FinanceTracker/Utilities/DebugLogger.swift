import Foundation

struct DebugLogger {
    static func log(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        #if DEBUG
        print(items.map { "\($0)" }.joined(separator: separator), terminator: terminator)
        #endif
    }
}
