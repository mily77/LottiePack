import Foundation
import Testing
@testable import LottiePack

/// 核心转换流程测试：验证目录资源能正确产出 `.lottie` 包结构。
struct LottiePackTests {
    /// 构造最小可用样例资源，执行转换并校验归档内容。
    @Test func convertsFolderStyleAnimationToDotLottie() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appending(path: "LottiePackTests-\(UUID().uuidString)")
        let exportDirectory = root.appending(path: "output")
        let animationDirectory = root.appending(path: "Sample")
        let imagesDirectory = animationDirectory.appending(path: "images")

        try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let pngData = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4////fwAJ+wP9KobjigAAAABJRU5ErkJggg==")!
        try pngData.write(to: imagesDirectory.appending(path: "img_0.png"))

        let json: [String: Any] = [
            "v": "5.12.1",
            "fr": 30,
            "ip": 0,
            "op": 60,
            "w": 100,
            "h": 100,
            "nm": "Sample",
            "ddd": 0,
            "assets": [[
                "id": "image_0",
                "w": 1,
                "h": 1,
                "u": "images/",
                "p": "img_0.png",
                "e": 0
            ]],
            "layers": []
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
        let jsonURL = animationDirectory.appending(path: "data.json")
        try jsonData.write(to: jsonURL)

        let importedItem = ImportedAnimationItem(
            displayName: "Sample",
            sourceURL: animationDirectory,
            sourceType: .folder,
            workingDirectory: animationDirectory,
            jsonURL: jsonURL,
            warnings: [],
            cleanupDirectory: nil
        )

        let result = try await DotLottieConverter().convert(
            importedItem: importedItem,
            exportDirectory: exportDirectory,
            autoRenameConflicts: false
        )

        #expect(fileManager.fileExists(atPath: result.outputURL.path))
        let listing = try shell(["/usr/bin/unzip", "-l", result.outputURL.path])
        #expect(listing.contains("manifest.json"))
        #expect(listing.contains("animations/animation.json"))
        #expect(listing.contains("images/image_0.png"))
    }

    /// 执行外部命令并返回合并后的标准输出/错误输出文本。
    private func shell(_ command: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(filePath: command[0])
        process.arguments = Array(command.dropFirst())

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return output
    }
}
