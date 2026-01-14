import XCTest
@testable import SmartScreen

@MainActor
final class ExportViewModelTests: XCTestCase {
    
    // MARK: - Fixtures
    
    private func makeSUT(
        exportEngine: MockExportEngine = MockExportEngine()
    ) -> (sut: ExportViewModel, engine: MockExportEngine) {
        let viewModel = ExportViewModel(exportEngine: exportEngine)
        return (viewModel, exportEngine)
    }
    
    private func makeSession() -> RecordingSession {
        RecordingSession(
            outputURL: URL(fileURLWithPath: "/tmp/test.mp4"),
            duration: 60
        )
    }
    
    // MARK: - Initial State
    
    func test_should_not_be_exporting_initially() {
        // given
        let (sut, _) = makeSUT()
        
        // then
        XCTAssertFalse(sut.isExporting)
        XCTAssertNil(sut.error)
        XCTAssertEqual(sut.selectedPreset, .web)
    }
    
    func test_should_have_all_built_in_presets() {
        // given
        let (sut, _) = makeSUT()
        
        // then
        XCTAssertEqual(sut.availablePresets.count, 5)
    }
    
    // MARK: - Export
    
    func test_should_export_with_selected_preset() async {
        // given
        let (sut, engine) = makeSUT()
        let session = makeSession()
        sut.selectedPreset = .highQuality
        
        // when
        await sut.export(session: session)
        
        // then
        XCTAssertEqual(engine.exportCallCount, 1)
        XCTAssertEqual(engine.lastPreset, .highQuality)
    }
    
    func test_should_show_error_when_export_fails() async {
        // given
        let (sut, engine) = makeSUT()
        engine.shouldFail = true
        engine.failureError = .exportFailed(reason: "Disk full")
        let session = makeSession()
        
        // when
        await sut.export(session: session)
        
        // then
        XCTAssertFalse(sut.isExporting)
        XCTAssertEqual(sut.error, .exportFailed(reason: "Disk full"))
    }
    
    // MARK: - Cancel
    
    func test_should_cancel_export() async {
        // given
        let (sut, engine) = makeSUT()
        
        // when
        await sut.cancelExport()
        
        // then
        XCTAssertEqual(engine.cancelCallCount, 1)
    }
    
    // MARK: - Clear Error
    
    func test_should_clear_error() async {
        // given
        let (sut, engine) = makeSUT()
        engine.shouldFail = true
        await sut.export(session: makeSession())
        XCTAssertNotNil(sut.error)
        
        // when
        sut.clearError()
        
        // then
        XCTAssertNil(sut.error)
    }
}
