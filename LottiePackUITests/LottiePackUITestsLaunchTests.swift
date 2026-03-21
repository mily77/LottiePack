//
//  LottiePackUITestsLaunchTests.swift
//  LottiePackUITests
//
//  Created by Emily Huang on 2026/3/20.
//

import XCTest

/// 启动快照测试：记录首次启动画面用于回归比较。
final class LottiePackUITestsLaunchTests: XCTestCase {

    /// 指示该测试应在每种 UI 配置下分别执行。
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    /// 每次启动测试前，配置失败即停止策略。
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    /// 启动应用并保存启动屏截图为测试附件。
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
