// ZipImportService.swift
// Safe ZIP archive inspection and extraction (Phase 5 / Phase 7 foundation).
import Foundation

struct ZipEntry: Identifiable {
    let id = UUID()
    let name: String
    let method: UInt16
    let compressedSize: UInt64
    let uncompressedSize: UInt64
}

enum ZipImportError: LocalizedError {
    case notAZipArchive
    case cannotReadArchive
    case endOfCentralDirectoryNotFound
    case pathTraversal([String])
    case unsupportedCompression([String])
    case extractionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAZipArchive:
            return "Không phải file ZIP hợp lệ."
        case .cannotReadArchive:
            return "Không thể đọc file ZIP."
        case .endOfCentralDirectoryNotFound:
            return "Không tìm thấy cấu trúc ZIP trung tâm."
        case .pathTraversal(let names):
            return "Từ chối giải nén: các mục có đường dẫn không an toàn: \(names.joined(separator: ", "))."
        case .unsupportedCompression(let names):
            return "Không giải nén được (cần thư viện giải nén): \(names.joined(separator: ", "))."
        case .extractionFailed(let msg):
            return "Giải nén thất bại: \(msg)."
        }
    }
}

private enum ZipSignature: UInt32 {
    case localFileHeader = 0x04034b50
    case centralDirectory  = 0x02014b50
    case endOfCentralDirectory = 0x06054b50
}

final class ZipImportService {

    func inspectArchive(at url: URL) -> Result<[ZipEntry], ZipImportError> {
        guard let data = try? Data(contentsOf: url) else {
            return .failure(.cannotReadArchive)
        }
        guard let eocd = findEndOfCentralDirectory(in: data) else {
            return .failure(.endOfCentralDirectoryNotFound)
        }

        let totalEntries = Int(readUInt16LE(data, at: eocd + 10) ?? 0)
        let centralDirectoryOffset = Int(readUInt32LE(data, at: eocd + 16) ?? 0)

        var entries: [ZipEntry] = []
        var offset = centralDirectoryOffset
        for _ in 0..<totalEntries {
            guard offset + 46 <= data.count,
                  readUInt32LE(data, at: offset) == UInt64(ZipSignature.centralDirectory.rawValue) else {
                return .failure(.cannotReadArchive)
            }
            let method = readUInt16LE(data, at: offset + 10) ?? 0
            let compressedSize = readUInt32LE(data, at: offset + 20) ?? 0
            let uncompressedSize = readUInt32LE(data, at: offset + 24) ?? 0
            let nameLen = Int(readUInt16LE(data, at: offset + 28) ?? 0)

            let nameEnd = offset + 46 + nameLen
            guard nameEnd <= data.count else { return .failure(.cannotReadArchive) }
            let name = String(data: data[offset + 46 ..< nameEnd], encoding: .utf8) ?? ""

            entries.append(ZipEntry(name: name, method: UInt16(method), compressedSize: compressedSize, uncompressedSize: uncompressedSize))
            offset = nameEnd + Int(readUInt16LE(data, at: offset + 30) ?? 0)
        }

        return .success(entries)
    }

    func extractArchive(at url: URL, to destination: URL) -> Result<[URL], ZipImportError> {
        guard let data = try? Data(contentsOf: url) else {
            return .failure(.cannotReadArchive)
        }
        guard let eocd = findEndOfCentralDirectory(in: data) else {
            return .failure(.endOfCentralDirectoryNotFound)
        }

        let totalEntries = Int(readUInt16LE(data, at: eocd + 10) ?? 0)
        let centralDirectoryOffset = Int(readUInt32LE(data, at: eocd + 16) ?? 0)

        var entries: [(name: String, method: UInt16, compressedSize: UInt64,
                        localHeaderOffset: Int, nameLen: Int, extraLen: Int)] = []
        var traversal: [String] = []
        var deflated: [String] = []
        var offset = centralDirectoryOffset

        for _ in 0..<totalEntries {
            guard offset + 46 <= data.count,
                  readUInt32LE(data, at: offset) == UInt64(ZipSignature.centralDirectory.rawValue) else {
                return .failure(.cannotReadArchive)
            }
            let method = readUInt16LE(data, at: offset + 10) ?? 0
            let compressedSize = readUInt32LE(data, at: offset + 20) ?? 0
            let nameLen = Int(readUInt16LE(data, at: offset + 28) ?? 0)
            let extraLen = Int(readUInt16LE(data, at: offset + 30) ?? 0)
            let localHeaderOffset = Int(readUInt32LE(data, at: offset + 42) ?? 0)

            let nameEnd = offset + 46 + nameLen
            guard nameEnd <= data.count else { return .failure(.cannotReadArchive) }
            let name = String(data: data[offset + 46 ..< nameEnd], encoding: .utf8) ?? ""

            if hasPathTraversal(name) { traversal.append(name) }
            if method == 8 { deflated.append(name) }

            entries.append((name: name, method: UInt16(method), compressedSize: compressedSize,
                            localHeaderOffset: localHeaderOffset, nameLen: nameLen, extraLen: extraLen))
            offset = nameEnd + extraLen + Int(readUInt16LE(data, at: offset + 32) ?? 0)
        }

        if !traversal.isEmpty {
            return .failure(.pathTraversal(traversal))
        }
        if !deflated.isEmpty {
            return .failure(.unsupportedCompression(deflated))
        }

        var extracted: [URL] = []
        for entry in entries {
            let dataStart = entry.localHeaderOffset + 30 + entry.nameLen + entry.extraLen
            guard dataStart + Int(entry.compressedSize) <= data.count else {
                return .failure(.extractionFailed("entry \"\(entry.name)\" exceeds archive bounds"))
            }
            let entryData = data[dataStart ..< dataStart + Int(entry.compressedSize)]
            let fileURL = destination.appendingPathComponent(entry.name, isDirectory: false)
            do {
                try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true, attributes: nil)
                try entryData.write(to: fileURL)
                extracted.append(fileURL)
            } catch {
                return .failure(.extractionFailed(error.localizedDescription))
            }
        }
        return .success(extracted)
    }

    // MARK: - Private helpers

    private func findEndOfCentralDirectory(in data: Data) -> Int? {
        let eocdSig = Data([0x50, 0x4b, 0x05, 0x06])
        let eocdFixedSize = 22
        let maxComment = 65535
        let searchStart = max(0, data.count - eocdFixedSize - maxComment)
        var i = data.count - eocdFixedSize
        while i >= searchStart {
            if data[i ..< i + 4] == eocdSig { return i }
            i -= 1
        }
        return nil
    }

    private func hasPathTraversal(_ name: String) -> Bool {
        if name.hasPrefix("/") || name.hasPrefix("\\") { return true }
        if name.contains("..") { return true }
        return false
    }

    private func readUInt16LE(_ data: Data, at offset: Int) -> UInt64? {
        guard offset + 2 <= data.count else { return nil }
        return UInt64(data[offset]) | UInt64(data[offset + 1]) << 8
    }

    private func readUInt32LE(_ data: Data, at offset: Int) -> UInt64? {
        guard offset + 4 <= data.count else { return nil }
        return UInt64(data[offset]) | UInt64(data[offset + 1]) << 8
            | UInt64(data[offset + 2]) << 16 | UInt64(data[offset + 3]) << 24
    }
}
