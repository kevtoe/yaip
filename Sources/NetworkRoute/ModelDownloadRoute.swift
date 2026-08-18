import Foundation

enum ModelDownloadConfiguration {
    nonisolated static func standard() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 7_200
        configuration.waitsForConnectivity = true
        return configuration
    }
}
