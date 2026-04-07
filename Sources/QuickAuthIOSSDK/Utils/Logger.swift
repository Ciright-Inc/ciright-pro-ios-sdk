import Foundation
import os.log

/// Internal logger with log-level control.
/// Logs are prefixed with `[QuickAuth]` for easy filtering.
enum QALogger {

    /// Set to `false` to suppress all SDK logs in production builds.
    static var isEnabled: Bool = true

    /// Minimum log level. Messages below this level are suppressed.
    static var minLevel: Level = .info

    enum Level: Int, Comparable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3

        static func < (lhs: Level, rhs: Level) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var prefix: String {
            switch self {
            case .debug:   return "DEBUG"
            case .info:    return "INFO"
            case .warning: return "WARN"
            case .error:   return "ERROR"
            }
        }
    }

    static func debug(_ message: String) {
        log(message, level: .debug)
    }

    static func info(_ message: String) {
        log(message, level: .info)
    }

    static func warning(_ message: String) {
        log(message, level: .warning)
    }

    static func error(_ message: String) {
        log(message, level: .error)
    }

    private static func log(_ message: String, level: Level) {
        guard isEnabled, level >= minLevel else { return }
        let formatted = "[QuickAuth] [\(level.prefix)] \(message)"

        #if DEBUG
        print(formatted)
        #endif

        if #available(iOS 14.0, *) {
            let logger = os.Logger(subsystem: "pro.ciright.quickauth", category: "sdk")
            switch level {
            case .debug:   logger.debug("\(formatted)")
            case .info:    logger.info("\(formatted)")
            case .warning: logger.warning("\(formatted)")
            case .error:   logger.error("\(formatted)")
            }
        }
    }
}
