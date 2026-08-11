import Foundation

enum BackupError: LocalizedError {
    case emptyFile
    case invalidBackup

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "That backup file was empty."
        case .invalidBackup:
            return "That file does not look like a Moonay backup."
        }
    }
}
