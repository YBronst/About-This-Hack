//
//  CreateDataFiles.swift
//  About This Hack
//

import Foundation

class CreateDataFiles {
    private final class DataFilesCreatedState: @unchecked Sendable {
        private let lock = NSLock()
        private var value = false

        func get() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return value
        }

        func set(_ newValue: Bool) {
            lock.lock()
            value = newValue
            lock.unlock()
        }
    }

    private static let dataFilesState = DataFilesCreatedState()

    /// Notification name for when data files are created
    static let dataFilesCreatedNotification = Notification.Name("DataFilesCreated")

    static var dataFilesCreated: Bool {
        dataFilesState.get()
    }

    /// Asynchronously creates initial data files
    /// - Parameter completion: Called on completion (main thread)
    static func getInitDataFilesAsync(completion: @Sendable @escaping () -> Void) {
        if dataFilesState.get() {
            DispatchQueue.main.async {
                completion()
            }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            getInitDataFiles()
            DispatchQueue.main.async {
                completion()
                // Post notification that data files are ready
                NotificationCenter.default.post(name: dataFilesCreatedNotification, object: nil)
            }
        }
    }

    static func getInitDataFiles() {
        if dataFilesState.get() {
            return
        }

        let fm = FileManager.default
        let athURL = URL(fileURLWithPath: InitGlobVar.athDirectory, isDirectory: true)

        // Remove any stale directory and recreate it fresh
        try? fm.removeItem(at: athURL)
        do {
            try fm.createDirectory(at: athURL, withIntermediateDirectories: true)
        } catch {
            print("Error: could not create temp directory \(athURL.path): \(error)")
        }

        // /* Product phase  - Uncomment for product phase
        // Use DispatchGroup to run all commands in parallel
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInitiated)

        // Define all file creation commands
        // Note: scrXmlFilePath and syssoftdataFilePath removed - they were never used in the codebase
        // Note: SPDisplaysDataType is run directly (without a file) in HardwareCollector.getAllData()
        let commands = [
            "system_profiler SPHardwareDataType 2>/dev/null > \"\(InitGlobVar.hwFilePath)\"",
            "system_profiler SPMemoryDataType 2>/dev/null | grep -v \"^Memory:$\" > \"\(InitGlobVar.sysmemFilePath)\"",
            "diskutil info / 2>/dev/null > \"\(InitGlobVar.bootvolnameFilePath)\"",
            "diskutil list / 2>/dev/null > \"\(InitGlobVar.bootvollistFilePath)\"",
            "system_profiler SPStorageDataType 2>/dev/null > \"\(InitGlobVar.storagedataFilePath)\"",
        ]

        // Execute all commands concurrently
        for command in commands {
            group.enter()
            queue.async {
                _ = run(command)
                group.leave()
            }
        }

        // Wait for all commands to complete (this is called from a background thread in getInitDataFilesAsync).
        group.wait()
        print("Data files created")
        // */

        /*  Testing phase - Uncomment and modify path for testing phase
         let testDataRep = "~/Downloads/0-ath-issue-N78" // Replace with your test data directory

         createFileIfNeeded(atPath: InitGlobVar.hwFilePath, withCommand: "ln -s \(testDataRep)/hw.txt  \"\(InitGlobVar.hwFilePath)\"")
         // ... Add similar lines for other files
         */

        dataFilesState.set(true)
    }
}
