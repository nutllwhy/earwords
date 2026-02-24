//
//  AudioPlayerManagerTests.swift
//  EarWordsTests
//
//  AudioPlayerManager 单元测试
//

import XCTest
import AVFoundation
@testable import EarWords

final class AudioPlayerManagerTests: XCTestCase {
    
    var audioManager: AudioPlayerManager!
    
    override func setUp() {
        super.setUp()
        audioManager = AudioPlayerManager.shared
        audioManager.clearQueue()
    }
    
    override func tearDown() {
        audioManager.clearQueue()
        audioManager.setPlaybackSpeed(1.0)
        super.tearDown()
    }
    
    // MARK: - 初始化测试
    
    func testInitialState() {
        XCTAssertEqual(audioManager.currentState, .idle)
        XCTAssertNil(audioManager.currentItem)
        XCTAssertEqual(audioManager.queue.count, 0)
        XCTAssertEqual(audioManager.currentIndex, 0)
        XCTAssertEqual(audioManager.playbackSpeed, 1.0)
    }
    
    // MARK: - 播放队列测试
    
    func testSetPlaylist_SequentialMode() {
        let words = createMockWords(count: 5)
        
        audioManager.setPlaylist(words: words, mode: .sequential)
        
        XCTAssertEqual(audioManager.queue.count, 5)
        XCTAssertEqual(audioManager.playbackMode, .sequential)
        XCTAssertNotNil(audioManager.currentItem)
    }
    
    func testSetPlaylist_RandomMode() {
        let words = createMockWords(count: 10)
        
        audioManager.setPlaylist(words: words, mode: .random)
        
        XCTAssertEqual(audioManager.queue.count, 10)
        XCTAssertEqual(audioManager.playbackMode, .random)
    }
    
    func testSetPlaylist_SpacedMode() {
        let words = createMockWords(count: 10)
        
        audioManager.setPlaylist(words: words, mode: .spaced)
        
        XCTAssertEqual(audioManager.queue.count, 10)
        XCTAssertEqual(audioManager.playbackMode, .spaced)
        // 队列应该按优先级排序
        XCTAssertFalse(audioManager.queue.isEmpty)
    }
    
    func testClearQueue() {
        let words = createMockWords(count: 5)
        audioManager.setPlaylist(words: words)
        
        audioManager.clearQueue()
        
        XCTAssertEqual(audioManager.queue.count, 0)
        XCTAssertNil(audioManager.currentItem)
        XCTAssertEqual(audioManager.currentIndex, 0)
    }
    
    // MARK: - 播放控制测试
    
    func testPlaybackSpeed() {
        audioManager.setPlaybackSpeed(1.5)
        XCTAssertEqual(audioManager.playbackSpeed, 1.5)
        
        audioManager.setPlaybackSpeed(0.8)
        XCTAssertEqual(audioManager.playbackSpeed, 0.8)
    }
    
    func testNextTrack() {
        let words = createMockWords(count: 5)
        audioManager.setPlaylist(words: words)
        
        let firstItem = audioManager.currentItem
        
        audioManager.nextTrack()
        
        // 顺序模式下应该前进到下一个
        XCTAssertEqual(audioManager.currentIndex, 1)
        XCTAssertNotEqual(audioManager.currentItem?.id, firstItem?.id)
    }
    
    func testPreviousTrack() {
        let words = createMockWords(count: 5)
        audioManager.setPlaylist(words: words)
        
        // 先前进两步
        audioManager.nextTrack()
        audioManager.nextTrack()
        XCTAssertEqual(audioManager.currentIndex, 2)
        
        // 再后退
        audioManager.previousTrack()
        XCTAssertEqual(audioManager.currentIndex, 1)
    }
    
    func testNextTrack_WrapAround() {
        let words = createMockWords(count: 3)
        audioManager.setPlaylist(words: words)
        
        // 前进到末尾
        audioManager.nextTrack()
        audioManager.nextTrack()
        XCTAssertEqual(audioManager.currentIndex, 2)
        
        // 再前进应该回到开头
        audioManager.nextTrack()
        XCTAssertEqual(audioManager.currentIndex, 0)
    }
    
    func testJumpToItem() {
        let words = createMockWords(count: 5)
        audioManager.setPlaylist(words: words)
        
        audioManager.jumpToItem(at: 3)
        
        XCTAssertEqual(audioManager.currentIndex, 3)
    }
    
    func testJumpToItem_InvalidIndex() {
        let words = createMockWords(count: 3)
        audioManager.setPlaylist(words: words)
        
        audioManager.jumpToItem(at: 10) // 越界
        
        // 应该保持当前状态
        XCTAssertEqual(audioManager.currentIndex, 0)
    }
    
    // MARK: - 播放模式切换测试
    
    func testSetPlaybackMode_Sequential() {
        let words = createMockWords(count: 5)
        audioManager.setPlaylist(words: words, mode: .random)
        
        audioManager.setPlaybackMode(.sequential)
        
        XCTAssertEqual(audioManager.playbackMode, .sequential)
    }
    
    func testSetPlaybackMode_Random() {
        let words = createMockWords(count: 10)
        audioManager.setPlaylist(words: words, mode: .sequential)
        let originalOrder = audioManager.queue.map { $0.word.id }
        
        audioManager.setPlaybackMode(.random)
        
        XCTAssertEqual(audioManager.playbackMode, .random)
        // 随机模式下顺序应该改变
        let newOrder = audioManager.queue.map { $0.word.id }
        // 由于随机性，顺序可能相同也可能不同，但至少队列长度不变
        XCTAssertEqual(newOrder.count, originalOrder.count)
    }
    
    func testRefreshSpacedRepetitionQueue() {
        let words = createMockWords(count: 10)
        audioManager.setPlaylist(words: words, mode: .spaced)
        
        // 记录播放统计
        if var firstItem = audioManager.queue.first {
            firstItem.playCount = 5
            firstItem.lastPlayed = Date()
        }
        
        audioManager.refreshSpacedRepetitionQueue()
        
        // 队列应该重新排序
        XCTAssertEqual(audioManager.queue.count, 10)
    }
    
    // MARK: - 播放状态测试
    
    func testPlayWithoutAudio() {
        // 没有设置播放列表时
        audioManager.play()
        
        // 状态应该保持为 idle 或变为 error
        XCTAssertTrue(audioManager.currentState == .idle || 
                     audioManager.currentState == .error("TTS_FALLBACK"))
    }
    
    func testPause() {
        // 暂停应该安全地处理
        audioManager.pause()
        
        XCTAssertEqual(audioManager.currentState, .paused)
    }
    
    func testStop() {
        let words = createMockWords(count: 3)
        audioManager.setPlaylist(words: words)
        
        audioManager.stop()
        
        XCTAssertEqual(audioManager.currentState, .idle)
        XCTAssertEqual(audioManager.progress, 0)
        XCTAssertEqual(audioManager.currentTime, 0)
    }
    
    func testSeek() {
        let words = createMockWords(count: 3)
        audioManager.setPlaylist(words: words)
        
        // 没有实际音频时的 seek 应该安全
        audioManager.seek(to: 10.0)
        
        // 进度应该被限制在有效范围内
        XCTAssertGreaterThanOrEqual(audioManager.progress, 0)
        XCTAssertLessThanOrEqual(audioManager.progress, 1)
    }
    
    // MARK: - PlaybackQueueItem 测试
    
    func testPlaybackQueueItemEquality() {
        let word = createMockWord(id: 1, word: "test")
        let item1 = PlaybackQueueItem(word: word, priority: 1.0, playCount: 0)
        let item2 = PlaybackQueueItem(word: word, priority: 2.0, playCount: 5)
        
        // 不同属性但同一单词应该被视为不同项（基于 UUID）
        XCTAssertNotEqual(item1.id, item2.id)
        XCTAssertNotEqual(item1, item2)
    }
    
    // MARK: - 辅助方法
    
    private func createMockWords(count: Int) -> [WordEntity] {
        var words: [WordEntity] = []
        for i in 0..<count {
            words.append(createMockWord(id: Int32(i + 1), word: "word\(i + 1)"))
        }
        return words
    }
    
    private func createMockWord(id: Int32, word: String) -> WordEntity {
        // 注意：在实际测试中需要使用 Core Data 上下文创建
        // 这里仅作为占位符，返回 mock 数据
        let context = DataManager.shared.newBackgroundContext()
        let entity = WordEntity(context: context)
        entity.id = id
        entity.word = word
        entity.meaning = "测试"
        entity.phonetic = "/test/"
        entity.pos = "n."
        entity.chapter = "test"
        entity.chapterKey = "01_test"
        entity.difficulty = Int16(id % 5 + 1)
        entity.status = id % 2 == 0 ? "learning" : "new"
        entity.reviewCount = Int16(id % 5)
        entity.easeFactor = 2.5
        entity.interval = Int32(id)
        entity.correctCount = Int16(id)
        entity.incorrectCount = 0
        entity.streak = Int16(id % 3)
        entity.createdAt = Date()
        entity.updatedAt = Date()
        return entity
    }
}

// MARK: - PlaybackMode 测试

final class PlaybackModeTests: XCTestCase {
    
    func testPlaybackModeRawValues() {
        XCTAssertEqual(PlaybackMode.sequential.rawValue, "顺序播放")
        XCTAssertEqual(PlaybackMode.random.rawValue, "随机播放")
        XCTAssertEqual(PlaybackMode.spaced.rawValue, "间隔重复")
    }
    
    func testPlaybackModeCaseIterable() {
        let allCases = PlaybackMode.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.sequential))
        XCTAssertTrue(allCases.contains(.random))
        XCTAssertTrue(allCases.contains(.spaced))
    }
}

// MARK: - PlayerState 测试

final class PlayerStateTests: XCTestCase {
    
    func testPlayerStateEquality() {
        XCTAssertEqual(PlayerState.idle, PlayerState.idle)
        XCTAssertEqual(PlayerState.playing, PlayerState.playing)
        XCTAssertNotEqual(PlayerState.idle, PlayerState.playing)
    }
    
    func testPlayerStateErrorEquality() {
        let error1 = PlayerState.error("Test error")
        let error2 = PlayerState.error("Test error")
        let error3 = PlayerState.error("Different error")
        
        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }
}

// MARK: - TimeInterval 扩展测试

final class TimeIntervalExtensionTests: XCTestCase {
    
    func testFormattedTime() {
        let time1: TimeInterval = 65
        XCTAssertEqual(time1.formatted, "1:05")
        
        let time2: TimeInterval = 125
        XCTAssertEqual(time2.formatted, "2:05")
        
        let time3: TimeInterval = 5
        XCTAssertEqual(time3.formatted, "0:05")
        
        let time4: TimeInterval = 3600
        XCTAssertEqual(time4.formatted, "60:00")
    }
}
