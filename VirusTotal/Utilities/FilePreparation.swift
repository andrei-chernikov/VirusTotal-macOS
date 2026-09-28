//
//  FilePreparation.swift
//  VirusTotal
//

import Foundation

enum FilePreparation {
    private static let archiveRootDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("VirusTotalAppArchives", isDirectory: true)

    static func scanFileURL(for fileURL: URL) async throws -> URL {
        guard try needsZipArchive(for: fileURL) else {
            return fileURL
        }

        cleanupOldTemporaryArchives()
        return try await makeZipArchive(for: fileURL)
    }

    static func cleanupPreparedFile(at fileURL: URL) {
        guard let directoryURL = ownedArchiveDirectory(for: fileURL) else { return }
        try? FileManager.default.removeItem(at: directoryURL)
    }

    static func needsZipArchive(for fileURL: URL) throws -> Bool {
        try fileURL.isAppBundle
    }

    static func preparedFileName(for fileURL: URL) throws -> String {
        try needsZipArchive(for: fileURL)
            ? fileURL.lastPathComponent + ".zip"
            : fileURL.lastPathComponent
    }

    private static func makeZipArchive(for appBundleURL: URL) async throws -> URL {
        try Task.checkCancellation()
        let archiveTask = Task.detached(priority: .userInitiated) {
            try createZipArchive(for: appBundleURL)
        }

        return try await withTaskCancellationHandler {
            try await archiveTask.value
        } onCancel: {
            archiveTask.cancel()
        }
    }

    /// Reading a directory with `.forUploading` makes `NSFileCoordinator` zip it,
    /// the same way Finder's Compress does. The zip only lives for the duration
    /// of the block, so it is moved into a directory this type owns.
    private static func createZipArchive(for appBundleURL: URL) throws -> URL {
        try Task.checkCancellation()
        let archiveDirectory = archiveRootDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: archiveDirectory, withIntermediateDirectories: true)

        let archiveURL = archiveDirectory
            .appendingPathComponent(appBundleURL.lastPathComponent)
            .appendingPathExtension("zip")
        var shouldKeepArchive = false
        defer {
            if !shouldKeepArchive {
                try? FileManager.default.removeItem(at: archiveDirectory)
            }
        }

        var coordinatorError: NSError?
        var moveError: Error?
        NSFileCoordinator().coordinate(readingItemAt: appBundleURL,
                                       options: .forUploading,
                                       error: &coordinatorError) { zipURL in
            do {
                try FileManager.default.moveItem(at: zipURL, to: archiveURL)
            } catch {
                moveError = error
            }
        }
        if let error = coordinatorError ?? moveError {
            throw error
        }
        // The archiving itself cannot be interrupted, so a cancellation that
        // arrived meanwhile is honoured here and the archive is discarded.
        try Task.checkCancellation()

        shouldKeepArchive = true
        return archiveURL
    }

    private static func cleanupOldTemporaryArchives() {
        guard let archiveDirectories = try? FileManager.default.contentsOfDirectory(
            at: archiveRootDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let expirationDate = Date().addingTimeInterval(-24 * 60 * 60)
        for archiveDirectory in archiveDirectories {
            let creationDate = (try? archiveDirectory.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            if creationDate < expirationDate {
                try? FileManager.default.removeItem(at: archiveDirectory)
            }
        }
    }

    /// Only `<root>/<UUID>/<name>.zip`, the shape `createZipArchive` makes,
    /// counts as ours. Anything else under the root is left alone.
    private static func ownedArchiveDirectory(for fileURL: URL) -> URL? {
        let standardizedURL = fileURL.standardizedFileURL
        let directoryURL = standardizedURL.deletingLastPathComponent()
        guard standardizedURL.pathExtension == "zip",
              UUID(uuidString: directoryURL.lastPathComponent) != nil,
              directoryURL.deletingLastPathComponent().path == archiveRootDirectory.standardizedFileURL.path
        else { return nil }

        return directoryURL
    }
}

private extension URL {
    var isAppBundle: Bool {
        get throws {
            guard pathExtension.localizedCaseInsensitiveCompare("app") == .orderedSame else {
                return false
            }

            let resourceValues = try resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            return resourceValues.isDirectory == true || resourceValues.isPackage == true
        }
    }
}
