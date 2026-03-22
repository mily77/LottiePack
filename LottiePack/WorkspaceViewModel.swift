import AppKit
import Combine
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
/// 负责工作区状态管理：导入任务、转换执行、日志与 UI 交互状态。
final class WorkspaceViewModel: ObservableObject {
    @Published var items: [ConversionItemViewData] = []
    @Published var selectedItemID: UUID?
    @Published var exportDirectory: URL?
    @Published var logs: [String] = []
    @Published var isConverting = false
    @Published var isDropTargeted = false
    @Published var alertMessage: String?
    @AppStorage("revealInFinder") var revealInFinder = true
    @AppStorage("autoRenameConflicts") var autoRenameConflicts = true

    private let importService = ImportService()
    private let converter = DotLottieConverter()

    /// 初始化默认导出目录为应用支持目录，避免桌面权限受限导致首次转换失败。
    init() {
        exportDirectory = Self.defaultExportDirectory()
    }

    private static func defaultExportDirectory() -> URL? {
        let fileManager = FileManager.default
        guard let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let directory = appSupportDirectory.appendingPathComponent("LottiePack/Exports", isDirectory: true)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        } catch {
            return fileManager.temporaryDirectory
        }
    }

    var selectedItem: ConversionItemViewData? {
        items.first(where: { $0.id == selectedItemID })
    }

    var canConvert: Bool {
        !isConverting && !items.isEmpty && exportDirectory != nil
    }

    /// 通过系统面板导入文件/目录，并异步解析为可转换任务。
    func importItems() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsOtherFileTypes = false
        panel.allowedContentTypes = [.item]
        panel.prompt = L10n.tr("import.prompt")

        guard panel.runModal() == .OK else { return }

        Task {
            await addImportedURLs(panel.urls)
        }
    }

    /// 选择导出目录，并记录日志以便回溯当前输出位置。
    func selectExportDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = L10n.tr("settings.select_export_prompt")

        guard panel.runModal() == .OK, let url = panel.url else { return }
        exportDirectory = url
        appendLog(L10n.tr("log.export_directory_set", url.path))
    }

    /// 处理来自 NSItemProvider 的拖拽输入（例如跨应用拖拽）。
    func handleDrop(providers: [NSItemProvider]) async {
        let urls = await providers.loadFileURLs()
        await addImportedURLs(urls)
    }

    /// 处理直接给定 URL 的拖拽输入（例如 SwiftUI dropDestination）。
    func handleDroppedURLs(_ urls: [URL]) async {
        await addImportedURLs(urls)
    }

    /// 清空任务列表并删除导入过程产生的临时目录。
    func clearItems() {
        cleanupImportedArtifacts(items)
        items.removeAll()
        selectedItemID = nil
        logs.removeAll()
    }

    /// 顺序执行全部任务转换，逐项更新状态、告警和失败信息。
    func convertAll() async {
        guard let exportDirectory else {
            alertMessage = L10n.tr("error.select_export_directory")
            return
        }

        isConverting = true
        defer { isConverting = false }

        for index in items.indices {
            items[index].status = .converting
            items[index].failureMessage = nil
            items[index].outputURL = nil
        }

        var outputURLs: [URL] = []

        // 按任务顺序串行转换，便于在 UI 中稳定展示状态和日志顺序。
        for index in items.indices {
            let item = items[index]
            do {
                let result = try await converter.convert(
                    importedItem: item.importedItem,
                    exportDirectory: exportDirectory,
                    autoRenameConflicts: autoRenameConflicts
                )
                items[index].status = .success
                items[index].outputURL = result.outputURL
                items[index].warnings = result.warnings
                outputURLs.append(result.outputURL)
                appendLog(L10n.tr("log.convert_success", result.outputURL.lastPathComponent))
            } catch {
                items[index].status = .failed
                items[index].failureMessage = error.localizedDescription
                appendLog(L10n.tr("log.convert_failed", item.displayName, error.localizedDescription))
            }
        }

        if revealInFinder, let lastOutput = outputURLs.last {
            NSWorkspace.shared.activateFileViewerSelecting([lastOutput])
        }
    }

    /// 将输入 URL 解析为导入任务并写入 UI 列表。
    private func addImportedURLs(_ urls: [URL]) async {
        guard !urls.isEmpty else { return }

        do {
            let importedItems = try await importService.importItems(from: urls)
            if importedItems.isEmpty {
                // 导入成功但未识别到可转换 JSON 时，给出明确提示避免用户误判为程序无响应。
                alertMessage = L10n.tr("error.no_convertible_assets")
                return
            }

            let viewData = importedItems.map { item in
                ConversionItemViewData(importedItem: item)
            }

            items.append(contentsOf: viewData)
            if selectedItemID == nil {
                selectedItemID = items.first?.id
            }
            appendLog(L10n.tr("log.imported_count", viewData.count))
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    /// 为日志追加时间戳，方便定位导入/转换时序。
    private func appendLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        logs.insert("[\(formatter.string(from: Date()))] \(message)", at: 0)
    }

    /// 删除导入服务创建的临时目录，防止临时文件累积。
    private func cleanupImportedArtifacts(_ items: [ConversionItemViewData]) {
        for item in items {
            if let cleanupDirectory = item.importedItem.cleanupDirectory {
                try? FileManager.default.removeItem(at: cleanupDirectory)
            }
        }
    }
}

private extension Array where Element == NSItemProvider {
    /// 并发读取每个拖拽项里的 URL，提升多文件拖拽时响应速度。
    func loadFileURLs() async -> [URL] {
        await withTaskGroup(of: URL?.self) { group in
            for provider in self {
                group.addTask {
                    // 不同来源（Finder、浏览器、第三方 App）会声明不同 UTI，按常见类型逐个尝试。
                    let identifiers = [
                        UTType.fileURL.identifier,
                        UTType.folder.identifier,
                        UTType.zip.identifier,
                        UTType.json.identifier,
                        UTType.item.identifier
                    ]

                    for identifier in identifiers where provider.hasItemConformingToTypeIdentifier(identifier) {
                        if let url = await provider.loadURL(forTypeIdentifier: identifier) {
                            return url
                        }
                    }

                    return nil
                }
            }

            var urls: [URL] = []
            for await url in group {
                if let url {
                    urls.append(url)
                }
            }
            return urls
        }
    }
}

private extension NSItemProvider {
    /// 针对单个类型标识符提取 URL，并按 API 能力逐级回退。
    func loadURL(forTypeIdentifier identifier: String) async -> URL? {
        // 先走高层 API，再逐步降级到更底层表示，兼容更多拖拽来源。
        if let objectURL = await loadObjectURL() {
            return objectURL
        }

        if let itemURL = await loadItemURL(forTypeIdentifier: identifier) {
            return itemURL
        }

        return await loadInPlaceURL(forTypeIdentifier: identifier)
    }

    /// 通过 `loadObject` 读取对象级 URL（优先路径）。
    private func loadObjectURL() async -> URL? {
        guard canLoadObject(ofClass: NSURL.self) else { return nil }

        return await withCheckedContinuation { continuation in
            _ = loadObject(ofClass: NSURL.self) { object, _ in
                if let url = object as? URL {
                    continuation.resume(returning: url)
                } else if let url = object as? NSURL {
                    continuation.resume(returning: url as URL)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// 通过 `loadItem` 读取原始 item，并兼容 URL/Data/String 三种表现形式。
    private func loadItemURL(forTypeIdentifier identifier: String) async -> URL? {
        await withCheckedContinuation { continuation in
            loadItem(forTypeIdentifier: identifier, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let url = item as? NSURL {
                    continuation.resume(returning: url as URL)
                } else if let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else if let string = item as? String,
                          let url = URL(string: string) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// 最后回退到 in-place 文件表示，尽可能提高拖拽兼容性。
    private func loadInPlaceURL(forTypeIdentifier identifier: String) async -> URL? {
        await withCheckedContinuation { continuation in
            loadInPlaceFileRepresentation(forTypeIdentifier: identifier) { url, _, _ in
                continuation.resume(returning: url)
            }
        }
    }
}
