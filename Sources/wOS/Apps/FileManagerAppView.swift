// FileManagerAppView.swift
// Real file manager for the app's Documents directory (Phase 5).
// Replaces the hard-coded demo list with the actual app container: browse,
// import via system file picker, create, rename, delete — real FileManager
// operations with real errors, nothing simulated.
import SwiftUI
import UniformTypeIdentifiers

private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

struct FileItem: Identifiable, Equatable {
    let id: URL
    var name: String { lastPathComponent }
    let url: URL
    let isDirectory: Bool
    let size: Int64
    let fileType: String
}

struct FileManagerAppView: View {
    @State private var files: [FileItem] = []
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var selected: FileItem?
    @State private var showDeleteConfirm = false
    @State private var renameTarget: FileItem?
    @State private var renameText = ""
    @State private var isCreating = false
    @State private var newFileName = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Tệp").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                Spacer()
                Button(action: { isCreating = true }) {
                    HStack(spacing: 4) { Image(systemName: "plus"); Text("Tạo tệp") }.foregroundColor(.wosAccent)
                }
                .buttonStyle(.borderless)
                Button(action: { isImporting = true }) {
                    HStack(spacing: 4) { Image(systemName: "square.and.arrow.down"); Text("Nhập") }.foregroundColor(.wosAccent)
                }
                .buttonStyle(.borderless)
                .fileImporter(isPresented: $isImporting, allowedContentTypes: [UTType.item], allowsMultipleSelection: true, onCompletion: handleImport)
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)

            HStack {
                Image(systemName: "folder.fill").font(.system(size: 11)).foregroundColor(Color(hex: "666666"))
                Text(documentsDirectory.path).font(.system(size: 12)).foregroundColor(Color(hex: "666666"))
            }
            .padding(.horizontal, 16).padding(.vertical, 8).background(Color(hex: "111111"))

            ScrollView {
                if files.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "folder").font(.system(size: 44)).foregroundColor(Color(hex: "444444"))
                        Text("Thư mục trống").font(.system(size: 15)).foregroundColor(Color(hex: "888888"))
                        Text("Bấm \"Nhập\" hoặc \"Tạo tệp\".").font(.system(size: 12)).foregroundColor(Color(hex: "666666"))
                    }
                    .padding(.top, 60)
                } else {
                    VStack(spacing: 0) {
                        ForEach(files) { file in
                            fileRow(file)
                                .overlay(Divider().background(Color(hex: "111111")), alignment: .bottom)
                                .onTapGesture { selected = file }
                                .onLongPressGesture { beginRename(file) }
                        }
                    }
                }
            }

            if let errorMessage {
                HStack {
                    Image(systemName: "xmark.octagon.fill").foregroundColor(.wosDanger)
                    Text(errorMessage).font(.system(size: 13)).foregroundColor(.white)
                    Spacer()
                    Button("Đóng") { self.errorMessage = nil }.font(.system(size: 12)).foregroundColor(.wosAccent)
                }
                .padding(12).background(Color.wosDanger.opacity(0.15)).cornerRadius(10)
                .padding(.horizontal, 16).padding(.top, 8)
            }
        }
        .background(Color.wosBackground)
        .onAppear(perform: loadFiles)
        .alert("Xóa \(selected?.name ?? "")?", isPresented: Binding(get: { selected != nil && showDeleteConfirm }, set: { if !$0 { showDeleteConfirm = false } })) {
            Button("Hủy", role: .cancel) { selected = nil }
            Button("Xóa", role: .destructive) { if let file = selected { deleteFile(file) }; selected = nil }
        } message: {
            Text("Không thể hoàn tác. \(selected.map { "Kích thước: \($0.size.formattedSize)" } ?? "")")
        }
        .alert("Đổi tên", isPresented: Binding(get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } })) {
            TextField("Tên mới", text: $renameText)
            Button("Hủy", role: .cancel) { }
            Button("Lưu") { performRename() }
        } message: {
            Text("Nhập tên mới cho \(renameTarget?.name ?? "")")
        }
        .alert("Tạo tệp mới", isPresented: $isCreating) {
            TextField("Tên tệp (ví dụ: note.txt)", text: $newFileName)
            Button("Hủy", role: .cancel) { newFileName = "" }
            Button("Tạo") { createTextFile() }
        } message: {
            Text("Tệp văn bản trong thư mục Tệp của W OS.")
        }
    }

    private func fileRow(_ file: FileItem) -> some View {
        HStack {
            Image(systemName: file.isDirectory ? "folder.fill" : icon(for: file.fileType))
                .font(.system(size: 18)).foregroundColor(file.isDirectory ? .wosAccent : Color(hex: "8ab4ff")).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name).font(.system(size: 14)).foregroundColor(.white).lineLimit(1)
                Text(file.isDirectory ? "Thư mục" : "\(file.size.formattedSize) • \(file.fileType)").font(.system(size: 11)).foregroundColor(Color(hex: "555555"))
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(Color(hex: "333333"))
        }
        .padding(.horizontal, 16).padding(.vertical, 12).contentShape(Rectangle())
    }
    // MARK: - Actions

    private func loadFiles() {
        errorMessage = nil
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: documentsDirectory,
                                                                       includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .typeIdentifierKey],
                                                                       options: [.skipsHiddenFiles])
            files = contents.compactMap { url in
                guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .typeIdentifierKey]) else { return nil }
                return FileItem(id: url, url: url, isDirectory: values.isDirectory ?? false,
                                size: values.fileSize ?? 0, fileType: values.typeIdentifier ?? "file")
            }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        } catch {
            errorMessage = "Không thể đọc thư mục: \(error.localizedDescription)"
        }
    }

    private func handleImport(_ result: [Result<URL, Error>]) {
        for item in result {
            switch item {
            case .success(let importedURL):
                do { try importFile(at: importedURL) }
                catch { errorMessage = "Nhập tệp thất bại: \(error.localizedDescription)" }
            case .failure(let err):
                errorMessage = "Chọn tệp thất bại: \(err.localizedDescription)"
            }
        }
        loadFiles()
    }

    private func importFile(at importedURL: URL) throws {
        guard importedURL.startAccessingSecurityScopedResource() else {
            throw FileManagerError.accessDenied
        }
        defer { importedURL.stopAccessingSecurityScopedResource() }
        let unique = uniqueURL(for: documentsDirectory.appendingPathComponent(importedURL.lastPathComponent))
        try FileManager.default.copyItem(at: importedURL, to: unique)
    }

    private func deleteFile(_ file: FileItem) {
        do {
            try FileManager.default.removeItem(at: file.url)
            loadFiles()
        } catch {
            errorMessage = "Không thể xóa: \(error.localizedDescription)"
        }
    }

    private func beginRename(_ file: FileItem) {
        renameTarget = file
        renameText = file.name
    }

    private func performRename() {
        guard let target = renameTarget, !renameText.isEmpty else { return }
        let newURL = target.url.deletingLastPathComponent().appendingPathComponent(renameText)
        let unique = uniqueURL(for: newURL, preservingExtension: true)
        do {
            try FileManager.default.moveItem(at: target.url, to: unique)
            loadFiles()
        } catch {
            errorMessage = "Không thể đổi tên: \(error.localizedDescription)"
        }
        renameTarget = nil
        renameText = ""
    }

    private func createTextFile() {
        let name = newFileName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { newFileName = ""; return }
        let url = uniqueURL(for: documentsDirectory.appendingPathComponent(name), preservingExtension: true)
        do {
            try Data().write(to: url)
            loadFiles()
        } catch {
            errorMessage = "Không thể tạo tệp: \(error.localizedDescription)"
        }
        newFileName = ""
        isCreating = false
    }

    // MARK: - Helpers

    /// Returns a URL that does not collide with an existing file by appending
    /// " (1)", " (2)", ... before the extension. Never overwrites user data.
    private func uniqueURL(for url: URL, preservingExtension: Bool = false) -> URL {
        var candidate = url
        var counter = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            let base = preservingExtension ? url.deletingPathExtension().lastPathComponent : url.lastPathComponent
            let ext = preservingExtension ? url.pathExtension : ""
            let suffix = ext.isEmpty ? " (\(counter))" : " (\(counter)).\(ext)"
            candidate = url.deletingLastPathComponent().appendingPathComponent(base + suffix)
            counter += 1
        }
        return candidate
    }

    private func icon(for typeIdentifier: String) -> String {
        switch typeIdentifier {
        case "public.text": return "doc.text"
        case "public.json": return "curlybraces"
        case "public.swift-source": return "chevron.left.slash.chevron.right"
        case "public.css": return "paintpalette"
        case "public.folder": return "folder.fill"
        case "public.zip-archive": return "archivebox"
        case "public.image": return "photo"
        case "public.audio": return "music.note"
        case "public.video": return "video"
        case "public.pdf": return "doc.fill"
        default: return "doc"
        }
    }
}

extension Int64 {
    var formattedSize: String {
        if self < 1024 { return "\(self) B" }
        if self < 1_048_576 { return String(format: "%.1f KB", Double(self) / 1024) }
        return String(format: "%.1f MB", Double(self) / 1_048_576)
    }
}

enum FileManagerError: LocalizedError {
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .accessDenied: return "Không thể truy cập tệp đã chọn."
        }
    }
}


