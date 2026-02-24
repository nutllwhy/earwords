//
//  EarWordsUITests.swift
//  EarWordsUITests
//
//  UI 自动化测试
//

import XCTest

final class EarWordsUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-data"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - 引导页测试
    
    func testOnboardingFlow() throws {
        // 验证引导页显示
        XCTAssertTrue(app.staticTexts["EarWords 听词"].exists)
        
        // 点击下一步
        app.buttons["下一步"].tap()
        
        // 验证第二页
        XCTAssertTrue(app.staticTexts["SM-2 记忆算法"].exists)
        
        // 点击下一步
        app.buttons["下一步"].tap()
        
        // 验证第三页
        XCTAssertTrue(app.staticTexts["设置每日目标"].exists)
        
        // 调整目标
        let slider = app.sliders.element(boundBy: 0)
        slider.adjust(toNormalizedSliderPosition: 0.5)
        
        // 点击开始学习
        app.buttons["开始学习"].tap()
        
        // 验证进入主界面
        XCTAssertTrue(app.tabBars.element.exists)
    }
    
    func testOnboardingSkip() throws {
        // 验证引导页显示
        XCTAssertTrue(app.staticTexts["EarWords 听词"].exists)
        
        // 点击跳过
        app.buttons["跳过"].tap()
        
        // 验证进入主界面
        XCTAssertTrue(app.tabBars.element.exists)
    }
    
    // MARK: - 主界面导航测试
    
    func testTabNavigation() throws {
        skipOnboardingIfNeeded()
        
        let tabBar = app.tabBars.element
        XCTAssertTrue(tabBar.exists)
        
        // 测试学习 Tab
        tabBar.buttons["学习"].tap()
        XCTAssertTrue(app.navigationBars["学习"].exists)
        
        // 测试磨耳朵 Tab
        tabBar.buttons["磨耳朵"].tap()
        XCTAssertTrue(app.navigationBars["磨耳朵"].exists)
        
        // 测试统计 Tab
        tabBar.buttons["统计"].tap()
        XCTAssertTrue(app.navigationBars["统计"].exists)
        
        // 测试词库 Tab
        tabBar.buttons["词库"].tap()
        XCTAssertTrue(app.navigationBars["词库"].exists)
        
        // 测试设置 Tab
        tabBar.buttons["设置"].tap()
        XCTAssertTrue(app.navigationBars["设置"].exists)
    }
    
    // MARK: - 学习流程测试
    
    func testStudyFlow() throws {
        skipOnboardingIfNeeded()
        
        // 进入学习页面
        app.tabBars.buttons["学习"].tap()
        
        // 点击开始学习
        if app.buttons["开始学习"].exists {
            app.buttons["开始学习"].tap()
        }
        
        // 等待单词卡片出现
        let wordCard = app.otherElements["WordCard"]
        let exists = wordCard.waitForExistence(timeout: 5)
        XCTAssertTrue(exists, "单词卡片应该出现")
        
        // 点击评分按钮（假设有5个评分选项）
        if app.buttons["完全忘记"].exists {
            app.buttons["完全忘记"].tap()
        } else if app.buttons["认识"].exists {
            app.buttons["认识"].tap()
        }
        
        // 验证进度更新
        XCTAssertTrue(app.progressIndicators.element.exists)
    }
    
    func testAudioReviewMode() throws {
        skipOnboardingIfNeeded()
        
        // 进入磨耳朵页面
        app.tabBars.buttons["磨耳朵"].tap()
        
        // 点击开始播放
        if app.buttons["开始播放"].exists {
            app.buttons["开始播放"].tap()
        }
        
        // 验证播放控制存在
        XCTAssertTrue(app.buttons["play.fill"].exists || app.buttons["pause.fill"].exists)
    }
    
    // MARK: - 搜索功能测试
    
    func testWordSearch() throws {
        skipOnboardingIfNeeded()
        
        // 进入词库页面
        app.tabBars.buttons["词库"].tap()
        
        // 点击搜索
        let searchField = app.searchFields.element
        if searchField.exists {
            searchField.tap()
            searchField.typeText("test")
            
            // 等待搜索结果
            sleep(1)
            
            // 验证搜索结果显示
            let cells = app.cells
            XCTAssertGreaterThan(cells.count, 0, "应该显示搜索结果")
        }
    }
    
    // MARK: - 设置测试
    
    func testSettingsChange() throws {
        skipOnboardingIfNeeded()
        
        // 进入设置页面
        app.tabBars.buttons["设置"].tap()
        
        // 查找每日目标设置
        if app.staticTexts["每日目标"].exists {
            // 修改目标值
            let stepper = app.steppers.element(boundBy: 0)
            if stepper.exists {
                stepper.buttons["Increment"].tap()
            }
        }
        
        // 验证设置存在
        XCTAssertTrue(app.tables.element.exists)
    }
    
    // MARK: - 辅助方法
    
    private func skipOnboardingIfNeeded() {
        // 如果在引导页，点击跳过
        if app.staticTexts["EarWords 听词"].exists {
            if app.buttons["跳过"].exists {
                app.buttons["跳过"].tap()
            } else if app.buttons["开始学习"].exists {
                app.buttons["开始学习"].tap()
            }
            
            // 等待主界面加载
            sleep(1)
        }
    }
}

// MARK: - 性能 UI 测试

final class EarWordsUIPerformanceTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
    
    func testStudyViewRendering() throws {
        app.launch()
        skipOnboardingIfNeeded()
        
        measure {
            // 多次切换学习视图
            app.tabBars.buttons["学习"].tap()
            app.tabBars.buttons["统计"].tap()
            app.tabBars.buttons["学习"].tap()
        }
    }
    
    private func skipOnboardingIfNeeded() {
        if XCUIApplication().staticTexts["EarWords 听词"].exists {
            if XCUIApplication().buttons["跳过"].exists {
                XCUIApplication().buttons["跳过"].tap()
            }
        }
    }
}
