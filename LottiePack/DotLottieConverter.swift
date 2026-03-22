import Foundation

/// 表示一次转换任务的输出结果。
struct ConversionResult {
    let outputURL: URL
    let warnings: [String]
}

/// 转换任务在 UI 中的生命周期状态。
enum ConversionStatus: Equatable {
    case pending
    case converting
    case success
    case failed

    var label: String {
        switch self {
        case .pending: L10n.tr("status.pending")
        case .converting: L10n.tr("status.converting")
        case .success: L10n.tr("status.success")
        case .failed: L10n.tr("status.failed")
        }
    }

    var icon: String {
        switch self {
        case .pending: "clock"
        case .converting: "arrow.triangle.2.circlepath"
        case .success: "checkmark.circle.fill"
        case .failed: "xmark.octagon.fill"
        }
    }
}

/// 面向 UI 的任务视图模型，包装导入信息与转换结果。
struct ConversionItemViewData: Identifiable {
    let id = UUID()
    let importedItem: ImportedAnimationItem
    var status: ConversionStatus = .pending
    var warnings: [String]
    var outputURL: URL?
    var failureMessage: String?

    init(importedItem: ImportedAnimationItem) {
        self.importedItem = importedItem
        self.warnings = importedItem.warnings
    }

    var displayName: String { importedItem.displayName }
    var sourceURL: URL { importedItem.sourceURL }
    var sourceTypeLabel: String { importedItem.sourceType.label }
}

/// 转换阶段可能出现的业务错误定义。
enum DotLottieConversionError: LocalizedError {
    case invalidJSON
    case zipFailed

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return L10n.tr("error.invalid_json")
        case .zipFailed:
            return L10n.tr("error.zip_failed")
        }
    }
}

/// 负责将导入动画资源打包为 `.lottie` 文件。
final class DotLottieConverter {
    private let fileManager = FileManager.default

    /// 执行单个任务转换：重写资源路径、生成清单并打包归档。
    func convert(importedItem: ImportedAnimationItem, exportDirectory: URL, autoRenameConflicts: Bool) async throws -> ConversionResult {
        let sourceData = try Data(contentsOf: importedItem.jsonURL)
        guard var root = try JSONSerialization.jsonObject(with: sourceData) as? [String: Any] else {
            throw DotLottieConversionError.invalidJSON
        }

        let packageDirectory = fileManager.temporaryDirectory.appending(path: "LottiePack-Build-\(UUID().uuidString)")
        let animationsDirectory = packageDirectory.appending(path: "animations")
        let imagesDirectory = packageDirectory.appending(path: "images")
        try fileManager.createDirectory(at: animationsDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)

        var warnings = importedItem.warnings
        if var assets = root["assets"] as? [[String: Any]] {
            for index in assets.indices {
                guard let originalPath = assets[index]["p"] as? String else { continue }
                if originalPath.hasPrefix("data:") { continue }

                let prefix = assets[index]["u"] as? String ?? ""
                let sourceImageURL = importedItem.workingDirectory.appending(path: prefix).appending(path: originalPath)
                guard fileManager.fileExists(atPath: sourceImageURL.path) else {
                    warnings.append(L10n.tr("warning.skip_missing_image", prefix, originalPath))
                    continue
                }

                let ext = sourceImageURL.pathExtension.isEmpty ? "png" : sourceImageURL.pathExtension
                let imageName = "image_\(index).\(ext)"
                let outputImageURL = imagesDirectory.appending(path: imageName)
                if fileManager.fileExists(atPath: outputImageURL.path) {
                    try fileManager.removeItem(at: outputImageURL)
                }
                try fileManager.copyItem(at: sourceImageURL, to: outputImageURL)

                // 将原始相对路径统一重写为 dotLottie 包内路径，确保跨平台加载一致。
                assets[index]["u"] = "/images/"
                assets[index]["p"] = imageName
                assets[index]["e"] = 0
            }
            root["assets"] = assets
        }

        let animationData = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try animationData.write(to: animationsDirectory.appending(path: "animation.json"))

        let manifest: [String: Any] = [
            "version": "1",
            "generator": "LottiePack",
            "author": "LottiePack",
            "animations": [["id": "animation"]]
        ]
        // dotLottie 最小结构: manifest.json + animations/ + images/。
        let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        try manifestData.write(to: packageDirectory.appending(path: "manifest.json"))

        let outputURL = try resolvedOutputURL(for: importedItem, exportDirectory: exportDirectory, autoRenameConflicts: autoRenameConflicts)
        let tempArchiveURL = packageDirectory.deletingLastPathComponent().appending(path: "\(UUID().uuidString).zip")

        let process = Process()
        process.currentDirectoryURL = packageDirectory
        process.executableURL = URL(filePath: "/usr/bin/zip")
        process.arguments = ["-qr", tempArchiveURL.path, "manifest.json", "animations", "images"]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw DotLottieConversionError.zipFailed
        }

        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }
        // 先生成 zip 再原子移动到目标路径，避免用户看到半成品文件。
        try fileManager.moveItem(at: tempArchiveURL, to: outputURL)
        try? fileManager.removeItem(at: packageDirectory)

        return ConversionResult(outputURL: outputURL, warnings: Array(Set(warnings)).sorted())
    }

    /// 解析输出文件路径；开启自动重名时避免覆盖已存在文件。
    private func resolvedOutputURL(for item: ImportedAnimationItem, exportDirectory: URL, autoRenameConflicts: Bool) throws -> URL {
        let baseName = sanitizedFileName(item.displayName.isEmpty ? "animation" : item.displayName)
        var candidate = exportDirectory.appending(path: "\(baseName).lottie")
        guard autoRenameConflicts else { return candidate }

        // 与 Finder 行为一致，重名时按 -1/-2 递增，避免覆盖现有文件。
        var suffix = 1
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = exportDirectory.appending(path: "\(baseName)-\(suffix).lottie")
            suffix += 1
        }
        return candidate
    }

    /// 清洗非法文件名字符，确保输出名可在文件系统中安全创建。
    private func sanitizedFileName(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let parts = name.components(separatedBy: invalidCharacters).filter { !$0.isEmpty }
        return parts.joined(separator: "-")
    }
}
