import Foundation
import UIKit

/// Collects device metadata sent to the backend for session tracking.
struct DeviceInfo {
    let deviceId: String
    let appId: String
    let platform: String
    let sdkVersion: String
}

enum DeviceHelper {

    static let sdkVersion = "1.0.0"

    static func collect() -> DeviceInfo {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let appId = Bundle.main.bundleIdentifier ?? "unknown"

        return DeviceInfo(
            deviceId: deviceId,
            appId: appId,
            platform: "ios",
            sdkVersion: sdkVersion
        )
    }
}
