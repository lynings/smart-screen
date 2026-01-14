import SwiftUI

struct CursorEnhancerSettingsView: View {
    @Bindable var viewModel: CursorEnhancerViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerSection
            smoothingSection
            highlightSection
        }
        .padding(20)
        .frame(width: 320)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        HStack {
            Image(systemName: "cursorarrow.motionlines")
                .font(.title2)
                .foregroundStyle(.blue)
            
            Text("Cursor Enhancement")
                .font(.headline)
            
            Spacer()
        }
    }
    
    private var smoothingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Smoothing", systemImage: "waveform.path")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                ForEach(SmoothingLevel.allCases, id: \.self) { level in
                    smoothingButton(for: level)
                }
            }
        }
    }
    
    private func smoothingButton(for level: SmoothingLevel) -> some View {
        Button {
            viewModel.smoothingLevel = level
        } label: {
            Text(level.displayName)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    viewModel.smoothingLevel == level
                        ? Color.blue
                        : Color.secondary.opacity(0.2)
                )
                .foregroundStyle(
                    viewModel.smoothingLevel == level
                        ? .white
                        : .primary
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private var highlightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Click Highlight", systemImage: "circle.circle")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            
            Toggle(isOn: $viewModel.highlightEnabled) {
                HStack {
                    Text("Show click animations")
                        .font(.body)
                    
                    Spacer()
                    
                    if viewModel.highlightEnabled {
                        previewDot
                    }
                }
            }
            .toggleStyle(.switch)
            .tint(.blue)
        }
    }
    
    private var previewDot: some View {
        Circle()
            .fill(.blue.opacity(0.5))
            .frame(width: 16, height: 16)
            .overlay(
                Circle()
                    .stroke(.blue, lineWidth: 2)
            )
    }
}

#Preview {
    CursorEnhancerSettingsView(viewModel: CursorEnhancerViewModel())
        .padding()
        .background(Color.black.opacity(0.5))
}
