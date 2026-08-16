//
//  ScanPolicyTests.swift
//  VirusTotalTests
//

import Foundation
import Testing
@testable import VirusTotal

@Suite("Scan policy")
struct ScanPolicyTests {
    @Test("650 MB upload limit is enforced")
    func uploadSizeLimitIsEnforced() {
        #expect(!ScanPolicy.isSupportedFileSize(0))
        #expect(ScanPolicy.isSupportedFileSize(ScanPolicy.maxUploadSize - 1))
        #expect(ScanPolicy.isSupportedFileSize(ScanPolicy.maxUploadSize))
        #expect(!ScanPolicy.isSupportedFileSize(ScanPolicy.maxUploadSize + 1))
    }

    @Test("Upload endpoint selection uses the large endpoint only above threshold")
    func uploadEndpointSelection() {
        #expect(ScanPolicy.uploadEndpoint(forFileSize: 1) == ScanPolicy.defaultUploadEndpoint)
        #expect(ScanPolicy.uploadEndpoint(forFileSize: ScanPolicy.largeUploadThreshold) == ScanPolicy.defaultUploadEndpoint)
        #expect(ScanPolicy.requiresLargeUploadEndpoint(fileSize: ScanPolicy.largeUploadThreshold + 1))
        #expect(ScanPolicy.uploadEndpoint(
            forFileSize: ScanPolicy.largeUploadThreshold + 1,
            largeFileEndpoint: "https://upload.example.test"
        ) == "https://upload.example.test")
        #expect(ScanPolicy.requiresLargeUploadEndpoint(fileSize: ScanPolicy.maxUploadSize))
        #expect(ScanPolicy.uploadEndpoint(
            forFileSize: ScanPolicy.maxUploadSize,
            largeFileEndpoint: "https://upload.example.test"
        ) == "https://upload.example.test")
        #expect(ScanPolicy.uploadEndpoint(forFileSize: ScanPolicy.maxUploadSize + 1) == "")
    }

    @Test("Polling stops after configured retry count")
    func pollingLimit() {
        #expect(ScanPolicy.shouldContinuePolling(attempt: 0))
        #expect(ScanPolicy.shouldContinuePolling(attempt: ScanPolicy.maxPollingAttempts - 1))
        #expect(!ScanPolicy.shouldContinuePolling(attempt: ScanPolicy.maxPollingAttempts))
    }

    @Test("Empty analysis stats are treated as in-progress")
    func emptyAnalysisStatsAreInvalid() {
        let emptyStats = FileAnalysisStats(
            malicious: 0,
            suspicious: 0,
            undetected: 0,
            harmless: 0,
            timeout: 0,
            confirmedTimeout: 0,
            failure: 0,
            typeUnsupported: 0
        )
        let completeStats = FileAnalysisStats(
            malicious: 1,
            suspicious: 0,
            undetected: 0,
            harmless: 0,
            timeout: 0,
            confirmedTimeout: 0,
            failure: 0,
            typeUnsupported: 0
        )

        #expect(!ScanPolicy.isValidAnalysisStats(emptyStats))
        #expect(ScanPolicy.isValidAnalysisStats(completeStats))
    }
}
