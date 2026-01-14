import SwiftUI

struct RecordingView: View {
    @State private var viewModel: RecordingViewModel
    @State private var cursorViewModel: CursorEnhancerViewModel
    @State private var selectedMode: CaptureMode = .fullScreen
    @State private var showingPermissionAlert = false
    @State private var showingError = false
    @State private var showingExport = false
    @State private var showingCursorSettings = false
    @State private var lastSession: RecordingSession?
    @State private var exportViewModel: ExportViewModel
    @State private var recordingSeconds: Int = 0
    @State private var timer: Timer?
    
    init(captureEngine: CaptureEngineProtocol = ScreenCaptureEngine()) {
        _viewModel = State(initialValue: RecordingViewModel(captureEngine: captureEngine))
        _cursorViewModel = State(initialValue: CursorEnhancerViewModel())
        _exportViewModel = State(initialValue: ExportViewModel(exportEngine: ExportEngine()))
    }
    
    var body: some View {
        ZStack {
            backgroundGradient
            
            VStack(spacing: 24) {
                headerSection
                
                Spacer()
                
                mainContent
                
                Spacer()
                
                controlButtons
                
                footerSection
            }
            .padding(32)
            
            if showingExport, let session = lastSession {
                exportOverlay(session: session)
            }
        }
        .animation(.spring(duration: 0.3), value: showingExport)
        .alert("Screen Recording Permission Required", isPresented: $showingPermissionAlert) {
            Button("Open System Settings") { openScreenRecordingSettings() }
            Button("Cancel", role: .cancel) { viewModel.clearError() }
        } message: {
            Text("SmartScreen needs screen recording permission.\n\nGo to System Settings > Privacy & Security > Screen Recording and enable SmartScreen.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.error?.errorDescription ?? "Unknown error")
        }
        .onChange(of: viewModel.error) { _, newValue in
            if let error = newValue {
                if error == .permissionDenied {
                    showingPermissionAlert = true
                } else {
                    showingError = true
                }
            }
        }
        .onChange(of: viewModel.isRecording) { _, isRecording in
            if isRecording {
                startTimer()
            } else {
                stopTimer()
            }
        }
    }
    
    // MARK: - Main Content
    
    @ViewBuilder
    private var mainContent: some View {
        if viewModel.isRecording {
            recordingStatusSection
        } else if let session = lastSession {
            completedSection(session: session)
        } else {
            readySection
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.06, blue: 0.10),
                Color(red: 0.10, green: 0.06, blue: 0.14)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "record.circle.fill")
                    .font(.title2)
                    .foregroundStyle(viewModel.isRecording ? .red : .white.opacity(0.7))
                    .symbolEffect(.pulse, isActive: viewModel.isRecording)
                
                Text("Smart Screen")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            }
            
            Spacer()
            
            // Cursor enhancement settings button
            Button {
                showingCursorSettings.toggle()
            } label: {
                Image(systemName: "cursorarrow.motionlines")
                    .font(.title3)
                    .foregroundStyle(cursorViewModel.highlightEnabled ? .blue : .white.opacity(0.5))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingCursorSettings) {
                CursorEnhancerSettingsView(viewModel: cursorViewModel)
            }
            
            if viewModel.isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                    Text("REC")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.red)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.red.opacity(0.15))
                .clipShape(Capsule())
            }
        }
    }
    
    // MARK: - Ready Section
    
    private var readySection: some View {
        VStack(spacing: 20) {
            Image(systemName: "display")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.6))
            
            Text("Ready to Record")
                .font(.title2.weight(.medium))
                .foregroundStyle(.white)
            
            Text("Full Screen Mode")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(32)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Recording Status
    
    private var recordingStatusSection: some View {
        VStack(spacing: 16) {
            // Duration
            Text(formatTime(recordingSeconds))
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundStyle(.white)
                .monospacedDigit()
            
            // Status
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isPaused ? .orange : .red)
                    .frame(width: 10, height: 10)
                
                Text(viewModel.isPaused ? "Paused" : "Recording...")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Completed Section
    
    private func completedSection(session: RecordingSession) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)
            
            Text("Recording Complete")
                .font(.title3.weight(.medium))
                .foregroundStyle(.white)
            
            Text(formatTime(Int(session.duration)))
                .font(.headline)
                .foregroundStyle(.white.opacity(0.6))
            
            HStack(spacing: 12) {
                Button {
                    showingExport = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                
                Button {
                    lastSession = nil
                    recordingSeconds = 0
                } label: {
                    Label("New", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }
        }
        .padding(24)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Control Buttons
    
    private var controlButtons: some View {
        HStack(spacing: 16) {
            if viewModel.isRecording {
                // Pause/Resume
                Button {
                    Task {
                        if viewModel.isPaused {
                            await viewModel.resumeRecording()
                        } else {
                            await viewModel.pauseRecording()
                        }
                    }
                } label: {
                    Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                        .font(.title3)
                        .frame(width: 50, height: 50)
                        .background(.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                
                // Stop
                Button {
                    Task {
                        if let session = await viewModel.stopRecording() {
                            lastSession = session
                        }
                    }
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .frame(width: 64, height: 64)
                        .background(.red)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                
            } else if lastSession == nil {
                // Start
                Button {
                    Task {
                        let config = createCaptureConfig()
                        await viewModel.startRecording(config: config)
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isStarting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                            Text("Starting...")
                                .font(.headline)
                        } else {
                            Image(systemName: "record.circle")
                                .font(.title2)
                            Text("Start Recording")
                                .font(.headline)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(viewModel.isStarting ? .gray : .red)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .disabled(viewModel.isStarting)
            }
        }
    }
    
    // MARK: - Footer
    
    private var footerSection: some View {
        Text("Recording saves to Documents folder")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.3))
    }
    
    // MARK: - Export Overlay
    
    private func exportOverlay(session: RecordingSession) -> some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    // Only dismiss if not exporting and no success state
                    if !exportViewModel.isExporting && exportViewModel.exportedURL == nil {
                        showingExport = false
                    }
                }
            
            ExportView(
                viewModel: exportViewModel,
                session: session,
                onDismiss: {
                    exportViewModel.resetExport()
                    showingExport = false
                }
            )
        }
        .transition(.opacity)
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func createCaptureConfig() -> CaptureConfig {
        let source: CaptureSource = .fullScreen(displayID: CGMainDisplayID())
        
        // Use screen's actual pixel resolution to avoid scaling offset issues
        let resolution: Resolution
        if let screen = NSScreen.main {
            let pixelWidth = Int(screen.frame.width * screen.backingScaleFactor)
            let pixelHeight = Int(screen.frame.height * screen.backingScaleFactor)
            resolution = .custom(width: pixelWidth, height: pixelHeight)
        } else {
            resolution = .p1080
        }
        
        return CaptureConfig(source: source, resolution: resolution)
    }
    
    private func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        recordingSeconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
            Task { @MainActor in
                if !viewModel.isPaused {
                    recordingSeconds += 1
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Supporting Types

enum CaptureMode: String, CaseIterable, Identifiable {
    case fullScreen
    case window
    case region
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .fullScreen: return "Full Screen"
        case .window: return "Window"
        case .region: return "Region"
        }
    }
    
    var icon: String {
        switch self {
        case .fullScreen: return "rectangle.dashed"
        case .window: return "macwindow"
        case .region: return "crop"
        }
    }
}

#Preview {
    RecordingView()
        .frame(width: 360, height: 420)
}
