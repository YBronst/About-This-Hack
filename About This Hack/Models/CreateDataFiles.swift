import Foundation

class CreateDataFiles {
    private static var _dataFilesCreated: Bool = false
    private static let lock = NSLock()

    /// Notification name for when data files are created
    static let dataFilesCreatedNotification = Notification.Name("DataFilesCreated")

    static var dataFilesCreated: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _dataFilesCreated
    }

    /// Asynchronously creates initial data files
    /// - Parameter completion: Called on completion (main thread)
    static func getInitDataFilesAsync(completion: @escaping () -> Void) {
        lock.lock()
        if _dataFilesCreated {
            lock.unlock()
            DispatchQueue.main.async {
                completion()
            }
            return
        }
        lock.unlock()

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
        lock.lock()
        if _dataFilesCreated {
            lock.unlock()
            return
        }
        lock.unlock()

        _ = run("rm -rf " + InitGlobVar.athDirectory + " 2>/dev/null")
        _ = run("mkdir " + InitGlobVar.athDirectory + " 2>/dev/null")

        // /* Product phase  - Uncomment for product phase
        // Use DispatchGroup to run all commands in parallel
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInitiated)

        // Define all file creation commands
        // Note: scrXmlFilePath and syssoftdataFilePath removed - they were never used in the codebase
        // Note: SPDisplaysDataType is run directly (without a file) in HardwareCollector.getAllData()
        let commands = [
            "system_profiler SPHardwareDataType > \"\(InitGlobVar.hwFilePath)\"",
            "system_profiler SPMemoryDataType | grep -v \"^Memory:$\" > \"\(InitGlobVar.sysmemFilePath)\"",
            "diskutil info / > \"\(InitGlobVar.bootvolnameFilePath)\"",
            "diskutil list / > \"\(InitGlobVar.bootvollistFilePath)\"",
            "system_profiler SPStorageDataType > \"\(InitGlobVar.storagedataFilePath)\"",
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

        lock.lock()
        _dataFilesCreated = true
        lock.unlock()
    }
}
