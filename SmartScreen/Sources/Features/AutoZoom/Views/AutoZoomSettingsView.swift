import SwiftUI

/// Settings view for Auto Zoom 2.0 configuration
struct AutoZoomSettingsView: View {
    @Bindable var viewModel: AutoZoomViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "viewfinder.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                Text("Auto Zoom 2.0")
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
                    Text("预设")
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
                        Text("缩放级别")
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
                
                // Idle Timeout
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("光标静止超时")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.1f秒", viewModel.idleTimeout))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    
                    Slider(
                        value: $viewModel.idleTimeout,
                        in: AutoZoomSettings.idleTimeoutRange,
                        step: 0.5
                    )
                    .tint(.blue)
                    
                    Text("光标静止超过此时间后自动缩小")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                
                // Dynamic Zoom Toggle
                Toggle(isOn: $viewModel.dynamicZoomEnabled) {
                    Text("动态缩放（边缘更大）")
                        .font(.subheadline)
                }
                
                // Keyboard Zoom Out Toggle
                Toggle(isOn: $viewModel.zoomOutOnKeyboard) {
                    Text("键盘输入时缩小")
                        .font(.subheadline)
                }
                
                // Easing
                Picker("缓动曲线", selection: $viewModel.easing) {
                    ForEach(EasingCurve.allCases, id: \.self) { curve in
                        Text(curve.displayName).tag(curve)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding()
        .frame(width: 300)
    }
    
    private func presetBackground(for preset: AutoZoomViewModel.Preset) -> some ShapeStyle {
        let isSelected: Bool
        switch preset {
        case .subtle:
            isSelected = viewModel.zoomLevel == 1.5 && viewModel.idleTimeout == 4.0
        case .normal:
            isSelected = viewModel.zoomLevel == 2.0 && viewModel.idleTimeout == 3.0
        case .dramatic:
            isSelected = viewModel.zoomLevel == 2.5 && viewModel.idleTimeout == 2.5
        }
        return isSelected ? AnyShapeStyle(.blue.opacity(0.2)) : AnyShapeStyle(.gray.opacity(0.1))
    }
}

#Preview {
    AutoZoomSettingsView(viewModel: AutoZoomViewModel())
}
