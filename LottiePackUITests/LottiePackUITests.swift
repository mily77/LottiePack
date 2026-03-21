//
//  LottiePackUITests.swift
//  LottiePackUITests
//
//  Created by Emily Huang on 2026/3/20.
//

import XCTest

/// UI 冒烟测试集合：覆盖应用启动与基础交互可达性。
final class LottiePackUITests: XCTestCase {

    /// 每个 UI 用例前重置失败策略，确保失败时尽早停止。
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    /// 每个 UI 用例后的清理钩子。
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    /// 基础启动用例：确认应用可正常拉起。
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    /// 启动性能用例：度量应用冷启动耗时。
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
