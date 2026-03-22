import Foundation
import UniformTypeIdentifiers

/// 统一描述单个可转换动画资源及其上下文信息。
struct ImportedAnimationItem: Identifiable, Hashable {
    let id = UUID()
    let displayName: String
    let sourceURL: URL
    let sourceType: ImportSourceType
    let workingDirectory: URL
    let jsonURL: URL
    let warnings: [String]
    let cleanupDirectory: URL?
}

/// 标记导入来源类型，用于 UI 展示和后续处理分支。
enum ImportSourceType: String, Hashable {
    case folder
    case json
    case zip

    var label: String {
        switch self {
        case .folder: L10n.tr("import.source.folder")
        case .json: L10n.tr("import.source.json")
        case .zip: L10n.tr("import.source.zip")
        }
    }
}

/// 导入阶段可能出现的业务错误定义。
enum ImportServiceError: LocalizedError {
    case unzipFailed(String, String)

    var errorDescription: String? {
        switch self {
        case .unzipFailed(let path, let reason):
            return L10n.tr("error.unzip_failed", path, reason)
        }
    }
}

/// 负责把用户输入（目录/JSON/ZIP）解析成标准化的动画任务。
final class ImportService {
    private let fileManager = FileManager.default

    /// 批量导入入口：逐个解析输入 URL，并在最后做去重。
    func importItems(from urls: [URL]) async throws -> [ImportedAnimationItem] {
        var items: [ImportedAnimationItem] = []

        for url in urls {
            items.append(contentsOf: try importItems(from: url))
        }

        return deduplicated(items)
    }

    /// 单个 URL 导入入口：按目录、ZIP、JSON 类型分流。
    private func importItems(from url: URL) throws -> [ImportedAnimationItem] {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .contentTypeKey])

        // 目录视为一个资源集合，递归查找其中可用的 JSON。
        if values.isDirectory == true {
            return try makeItems(fromDirectory: url, sourceURL: url, sourceType: .folder, cleanupDirectory: nil)
        }

        // ZIP 先解压到临时目录，后续流程与目录导入保持一致。
        if values.contentType == .zip || url.pathExtension.lowercased() == "zip" {
            let extractedDirectory = try unzip(url)
            return try makeItems(fromDirectory: extractedDirectory, sourceURL: url, sourceType: .zip, cleanupDirectory: extractedDirectory)
        }

        if values.contentType == .json || url.pathExtension.lowercased() == "json" {
            return [try makeItem(fromJSON: url, sourceURL: url, sourceType: .json, cleanupDirectory: nil)]
        }

        return []
    }

    /// 从目录收集候选 JSON 并映射为导入任务。
    private func makeItems(fromDirectory directory: URL, sourceURL: URL, sourceType: ImportSourceType, cleanupDirectory: URL?) throws -> [ImportedAnimationItem] {
        let jsonFiles = try candidateJSONFiles(in: directory)
        return try jsonFiles.map { jsonURL in
            try makeItem(fromJSON: jsonURL, sourceURL: sourceURL, sourceType: sourceType, cleanupDirectory: cleanupDirectory)
        }
    }

    /// 基于 JSON 文件构建单个任务，并补充展示名与资源告警。
    private func makeItem(fromJSON jsonURL: URL, sourceURL: URL, sourceType: ImportSourceType, cleanupDirectory: URL?) throws -> ImportedAnimationItem {
        let workingDirectory = jsonURL.deletingLastPathComponent()
        let warnings = try validationWarnings(for: jsonURL)
        let displayName = workingDirectory.lastPathComponent == sourceURL.deletingPathExtension().lastPathComponent && sourceType == .json
            ? jsonURL.deletingPathExtension().lastPathComponent
            : workingDirectory.lastPathComponent

        return ImportedAnimationItem(
            displayName: displayName,
            sourceURL: sourceURL,
            sourceType: sourceType,
            workingDirectory: workingDirectory,
            jsonURL: jsonURL,
            warnings: warnings,
            cleanupDirectory: cleanupDirectory
        )
    }

    /// 校验 JSON 中引用的外部图片资源是否存在，生成告警而非直接失败。
    private func validationWarnings(for jsonURL: URL) throws -> [String] {
        let data = try Data(contentsOf: jsonURL)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let assets = object?["assets"] as? [[String: Any]] ?? []
        var warnings: [String] = []

        for asset in assets {
            // data URI 是内联资源，不依赖磁盘文件，无需校验存在性。
            guard let path = asset["p"] as? String, !path.hasPrefix("data:") else {
                continue
            }

            let prefix = asset["u"] as? String ?? ""
            let imageURL = jsonURL.deletingLastPathComponent().appending(path: prefix).appending(path: path)
            if !fileManager.fileExists(atPath: imageURL.path) {
                warnings.append(L10n.tr("warning.missing_image", prefix, path))
            }
        }

        if assets.isEmpty {
            warnings.append(L10n.tr("warning.no_assets"))
        }

        return warnings
    }

    /// 递归遍历目录，收集全部 JSON 文件。
    private func findJSONFiles(in directory: URL) throws -> [URL] {
        let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        var result: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension.lowercased() == "json" {
                result.append(url)
            }
        }
        return result
    }

    /// 选取更可信的 JSON 候选（优先 data.json，排除 manifest）。
    private func candidateJSONFiles(in directory: URL) throws -> [URL] {
        let jsonFiles = try findJSONFiles(in: directory)
        let preferred = jsonFiles.filter { $0.lastPathComponent.lowercased() == "data.json" }

        // Lottie 常见入口为 data.json，命中时优先使用以减少误判。
        if !preferred.isEmpty {
            return preferred
        }

        // 避免把 dotLottie 的 manifest.json 当成动画 JSON 导入。
        return jsonFiles.filter { !$0.lastPathComponent.hasPrefix("manifest") }
    }

    /// 解压 ZIP 到临时目录，供后续目录导入流程复用。
    private func unzip(_ url: URL) throws -> URL {
        let directory = fileManager.temporaryDirectory.appending(path: "LottiePack-\(UUID().uuidString)")
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let extractionError = Pipe()

        let ditto = Process()
        ditto.executableURL = URL(filePath: "/usr/bin/ditto")
        ditto.arguments = ["-x", "-k", url.path, directory.path]
        ditto.standardError = extractionError
        try ditto.run()
        ditto.waitUntilExit()

        // 优先使用 ditto，系统原生命令在 macOS 上兼容性更高。
        if ditto.terminationStatus == 0 {
            return directory
        }

        // ditto 失败时回退 unzip，提升来自不同打包工具 ZIP 的兼容性。
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/unzip")
        process.arguments = ["-oq", url.path, "-d", directory.path]
        process.standardError = extractionError
        process.standardOutput = extractionError
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let reason = String(data: extractionError.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "未知错误"
            throw ImportServiceError.unzipFailed(url.lastPathComponent, reason.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return directory
    }

    /// 对导入结果按 JSON 路径去重，避免同一资源重复入队。
    private func deduplicated(_ items: [ImportedAnimationItem]) -> [ImportedAnimationItem] {
        var seen = Set<String>()
        return items.filter { item in
            // 以 JSON 绝对路径去重，防止同一文件通过多入口（拖拽父目录/子目录）重复入队。
            let key = item.jsonURL.path
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }
    }
}
