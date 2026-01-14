import Foundation

protocol ExportEngineProtocol: AnyObject, Sendable {
    var progress: Double { get async }
    var isExporting: Bool { get async }
    
    func export(session: RecordingSession, preset: ExportPreset, to url: URL) async throws
    func cancel() async
}
