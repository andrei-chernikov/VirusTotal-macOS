//
//  ScanPolicy.swift
//  VirusTotal
//

import Foundation

enum ScanPolicy {
    static let defaultUploadEndpoint = "https://www.virustotal.com/api/v3/files"
    static let largeUploadThreshold: Int64 = 33_554_432
    static let maxUploadSize: Int64 = 681_574_400
    static let maxPollingAttempts = 28

    static func isSupportedFileSize(_ fileSize: Int64) -> Bool {
        fileSize > 0 && fileSize <= maxUploadSize
    }

    static func requiresLargeUploadEndpoint(fileSize: Int64) -> Bool {
        fileSize > largeUploadThreshold && isSupportedFileSize(fileSize)
    }

    static func uploadEndpoint(forFileSize fileSize: Int64, largeFileEndpoint: String? = nil) -> String {
        guard isSupportedFileSize(fileSize) else { return "" }
        guard fileSize > largeUploadThreshold else { return defaultUploadEndpoint }
        return largeFileEndpoint ?? defaultUploadEndpoint
    }

    static func shouldContinuePolling(attempt: Int) -> Bool {
        attempt < maxPollingAttempts
    }

    static func isValidAnalysisStats(_ stats: FileAnalysisStats) -> Bool {
        stats.allFlags.sum { $0 } > 0
    }
}
