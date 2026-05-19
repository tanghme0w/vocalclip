import Foundation
import CryptoKit

enum AudioCacheManager {
    static let directoryName = "AudioCache"

    static func cacheDirectory() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent(directoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func hash(for text: String, voice: String) -> String {
        let combined = "\(voice)::\(text)"
        let digest = SHA256.hash(data: Data(combined.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func fileName(hash: String, ext: String) -> String {
        "\(hash).\(ext)"
    }

    static func url(forFileName name: String) -> URL {
        cacheDirectory().appendingPathComponent(name)
    }

    static func fileExists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: url(forFileName: name).path)
    }

    static func write(_ data: Data, name: String) throws -> URL {
        let dest = url(forFileName: name)
        try data.write(to: dest, options: .atomic)
        return dest
    }

    static func remove(name: String) {
        let p = url(forFileName: name)
        try? FileManager.default.removeItem(at: p)
    }

    static func totalSize() -> Int64 {
        let dir = cacheDirectory()
        guard let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            let attrs = try? url.resourceValues(forKeys: [.fileSizeKey])
            total += Int64(attrs?.fileSize ?? 0)
        }
        return total
    }

    static func clearAll() {
        let dir = cacheDirectory()
        if let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for item in items {
                try? FileManager.default.removeItem(at: item)
            }
        }
    }
}
