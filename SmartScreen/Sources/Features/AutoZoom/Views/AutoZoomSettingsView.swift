import SwiftUI

/// Settings view for Auto Zoom configuration
struct AutoZoomSettingsView: View {
    @Bindable var viewModel: AutoZoomViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "viewfinder.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                Text("Auto Zoom")
                    .font(.headline)
                
                Spacer()
                
                Toggle("", isOn: $viewModel.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            
            if viewModel.isEnabled {
                Divider()
                
                // Presets
                VStack(alignment: .leading, spacing: 8) {
                    Text("Presets")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 8) {
                        ForEach(AutoZoomViewModel.Preset.allCases) { preset in
                            Button {
                                viewModel.applyPreset(preset)
                            } label: {
                                Text(preset.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(presetBackground(for: preset))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Divider()
                
                // Zoom Level
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Zoom Level")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.1fx", viewModel.zoomLevel))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    
                    Slider(
                        value: $viewModel.zoomLevel,
                        in: AutoZoomSettings.zoomLevelRange,
                        step: 0.1
                    )
                    .tint(.blue)
                }
                
                // Duration (total segment duration)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Segment Duration")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.1fs", viewModel.duration))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    
                    Slider(
                        value: $viewModel.duration,
                        in: AutoZoomSettings.durationRange,
                        step: 0.1
                    )
                    .tint(.blue)
                    
                    Text("25% zoom in • 50% hold • 25% zoom out")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                
                // Easing
                Picker("Easing", selection: $viewModel.easing) {
                    ForEach(EasingCurve.allCases, id: \.self) { curve in
                        Text(curve.displayName).tag(curve)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding()
        .frame(width: 280)
    }
    
    private func presetBackground(for preset: AutoZoomViewModel.Preset) -> some ShapeStyle {
        let isSelected: Bool
        switch preset {
        case .subtle:
            isSelected = viewModel.zoomLevel == 1.5 && viewModel.duration == 1.0
        case .normal:
            isSelected = viewModel.zoomLevel == 2.0 && viewModel.duration == 1.2
        case .dramatic:
            isSelected = viewModel.zoomLevel == 2.5 && viewModel.duration == 1.5
        }
        return isSelected ? AnyShapeStyle(.blue.opacity(0.2)) : AnyShapeStyle(.gray.opacity(0.1))
    }
}

#Preview {
    AutoZoomSettingsView(viewModel: AutoZoomViewModel())
}
