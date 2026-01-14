import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ExportView: View {
    @Bindable var viewModel: ExportViewModel
    let session: RecordingSession
    let onDismiss: () -> Void
    
    @State private var showingError = false
    
    var body: some View {
        VStack(spacing: 24) {
            headerSection
            
            if let exportedURL = viewModel.exportedURL {
                successSection(url: exportedURL)
            } else if viewModel.isExporting {
                exportingSection
            } else {
                presetSelectionSection
                
                // Show cursor enhancement only if we have cursor data
                if viewModel.hasCursorData(session: session) {
                    cursorEnhancementSection
                }
                
                // Always show Auto Zoom section
                autoZoomSection
                
                exportButton
            }
        }
        .padding(32)
        .frame(width: 420)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .alert("Export Error", isPresented: $showingError) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.error?.errorDescription ?? "Unknown error")
        }
        .onChange(of: viewModel.error) { _, newValue in
            showingError = newValue != nil
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Export Recording")
                    .font(.headline)
                
                Text(formattedDuration)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var presetSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Preset")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            ForEach(viewModel.availablePresets) { preset in
                presetRow(preset)
            }
        }
    }
    
    private func presetRow(_ preset: ExportPreset) -> some View {
        Button {
            viewModel.selectedPreset = preset
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .font(.body.weight(.medium))
                    
                    Text(presetDescription(preset))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if viewModel.selectedPreset.id == preset.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding(12)
            .background(
                viewModel.selectedPreset.id == preset.id
                    ? Color.blue.opacity(0.1)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Cursor Enhancement Section
    
    private var cursorEnhancementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.vertical, 4)
            
            HStack {
                Label("Cursor Enhancement", systemImage: "cursorarrow.motionlines")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Toggle("", isOn: $viewModel.cursorEnhancementEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            
            if viewModel.cursorEnhancementEnabled {
                cursorEnhancementOptions
            }
        }
    }
    
    private var cursorEnhancementOptions: some View {
        VStack(spacing: 12) {
            // Smoothing Level
            HStack {
                Text("Smoothing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Picker("", selection: $viewModel.smoothingLevel) {
                    ForEach(SmoothingLevel.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            
            // Click Highlight
            HStack {
                Text("Click Highlight")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Toggle("", isOn: $viewModel.highlightEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            
            // Info text
            if viewModel.highlightEnabled {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.blue.opacity(0.5))
                        .frame(width: 8, height: 8)
                    Text("Left click")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Circle()
                        .fill(.blue.opacity(0.5))
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(.blue.opacity(0.3), lineWidth: 1)
                                .frame(width: 12, height: 12)
                        )
                    Text("Double click")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Circle()
                        .fill(.orange.opacity(0.5))
                        .frame(width: 8, height: 8)
                    Text("Right click")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Auto Zoom Section
    
    private var autoZoomSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.vertical, 4)
            
            HStack {
                Label("Auto Zoom", systemImage: "viewfinder.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Toggle("", isOn: $viewModel.autoZoomEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            
            if viewModel.autoZoomEnabled {
                autoZoomOptions
            }
        }
    }
    
    private var autoZoomOptions: some View {
        VStack(spacing: 12) {
            // Preset buttons
            HStack(spacing: 8) {
                ForEach(AutoZoomViewModel.Preset.allCases) { preset in
                    Button {
                        viewModel.applyAutoZoomPreset(preset)
                    } label: {
                        Text(preset.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(autoZoomPresetBackground(for: preset))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Zoom Level
            HStack {
                Text("Zoom")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(String(format: "%.1fx", viewModel.autoZoomLevel))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            
            Slider(
                value: $viewModel.autoZoomLevel,
                in: AutoZoomSettings.zoomLevelRange,
                step: 0.1
            )
            .tint(.blue)
            
            // Follow Cursor toggle (AC-FU-01, AC-FU-02)
            HStack {
                Text("Follow Cursor")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Toggle("", isOn: $viewModel.autoZoomFollowCursor)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            
            // Cursor/Highlight Scale (AC-CE-01)
            HStack {
                Text("Highlight Scale")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(String(format: "%.1fx", viewModel.autoZoomCursorScale))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            
            Slider(
                value: $viewModel.autoZoomCursorScale,
                in: AutoZoomSettings.cursorScaleRange,
                step: 0.1
            )
            .tint(.blue)
            
            // Info text with click count
            let clickCount = session.cursorTrackSession?.clickEvents.count ?? 0
            HStack(spacing: 6) {
                Image(systemName: clickCount > 0 ? "checkmark.circle.fill" : "info.circle")
                    .font(.caption2)
                    .foregroundStyle(clickCount > 0 ? .green : .secondary)
                if clickCount > 0 {
                    Text("\(clickCount) clicks detected")
                        .font(.caption2)
                } else {
                    Text("No clicks detected - need Accessibility permission")
                        .font(.caption2)
                }
            }
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func autoZoomPresetBackground(for preset: AutoZoomViewModel.Preset) -> some ShapeStyle {
        let isSelected: Bool
        switch preset {
        case .subtle:
            isSelected = viewModel.autoZoomLevel == 1.5
        case .normal:
            isSelected = viewModel.autoZoomLevel == 2.0
        case .dramatic:
            isSelected = viewModel.autoZoomLevel == 2.5
        }
        return isSelected ? AnyShapeStyle(.blue.opacity(0.2)) : AnyShapeStyle(.gray.opacity(0.1))
    }
    
    private var exportingSection: some View {
        VStack(spacing: 16) {
            ProgressView(value: viewModel.progress)
                .progressViewStyle(.linear)
            
            HStack {
                Text("Exporting...")
                    .font(.subheadline)
                
                Spacer()
                
                Text("\(Int(viewModel.progress * 100))%")
                    .font(.subheadline.monospacedDigit())
            }
            .foregroundStyle(.secondary)
            
            if viewModel.cursorEnhancementEnabled || viewModel.autoZoomEnabled {
                VStack(spacing: 4) {
                    if viewModel.cursorEnhancementEnabled {
                        HStack(spacing: 6) {
                            Image(systemName: "cursorarrow.motionlines")
                                .font(.caption)
                            Text("Cursor enhancement")
                                .font(.caption)
                        }
                    }
                    if viewModel.autoZoomEnabled {
                        HStack(spacing: 6) {
                            Image(systemName: "viewfinder.circle.fill")
                                .font(.caption)
                            Text("Auto zoom")
                                .font(.caption)
                        }
                    }
                }
                .foregroundStyle(.blue)
            }
            
            Button("Cancel") {
                Task {
                    await viewModel.cancelExport()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 20)
    }
    
    private func successSection(url: URL) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            
            Text("Export Complete!")
                .font(.headline)
            
            Text(url.lastPathComponent)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            
            if viewModel.cursorEnhancementEnabled || viewModel.autoZoomEnabled {
                HStack(spacing: 12) {
                    if viewModel.cursorEnhancementEnabled {
                        HStack(spacing: 4) {
                            Image(systemName: "cursorarrow.motionlines")
                                .font(.caption)
                            Text("Cursor")
                                .font(.caption)
                        }
                    }
                    if viewModel.autoZoomEnabled {
                        HStack(spacing: 4) {
                            Image(systemName: "viewfinder.circle.fill")
                                .font(.caption)
                            Text("Auto Zoom")
                                .font(.caption)
                        }
                    }
                }
                .foregroundStyle(.blue)
            }
            
            HStack(spacing: 12) {
                Button {
                    NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    viewModel.resetExport()
                    onDismiss()
                } label: {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 12)
    }
    
    private var exportButton: some View {
        Button {
            showSavePanel()
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Export")
                
                if viewModel.cursorEnhancementEnabled && viewModel.hasCursorData(session: session) {
                    Text("with Cursor Enhancement")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
    }
    
    private func showSavePanel() {
        let panel = NSSavePanel()
        panel.title = "Export Recording"
        panel.nameFieldStringValue = "Export-\(formatDateForFilename()).\(viewModel.selectedPreset.format.rawValue)"
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.canCreateDirectories = true
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task {
                    await viewModel.export(session: session, to: url)
                }
            }
        }
    }
    
    private func formatDateForFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
    
    // MARK: - Helpers
    
    private var formattedDuration: String {
        let totalSeconds = Int(session.duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func presetDescription(_ preset: ExportPreset) -> String {
        let size = preset.resolution.width == preset.resolution.height
            ? "\(preset.resolution.width)×\(preset.resolution.height)"
            : "\(preset.resolution.width)×\(preset.resolution.height)"
        return "\(size) • \(preset.fps)fps • \(preset.format.rawValue.uppercased())"
    }
}
