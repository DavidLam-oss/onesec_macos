import Combine
import SwiftUI

struct ShortcutSettingsState {
    var isVisible: Bool = false
    var opacity: Double = 0
}

// 单个按键显示组件
struct KeyCapView: View {
    let keyName: String
    
    var displayText: String {
        // 简化显示文本，提取符号
        if keyName.contains("Command") || keyName.contains("⌘") {
            "⌘"
        } else if keyName.contains("Option") || keyName.contains("⌥") {
            "⌥"
        } else if keyName.contains("Control") || keyName.contains("⌃") {
            "⌃"
        } else if keyName.contains("Shift") || keyName.contains("⇧") {
            "⇧"
        } else if keyName == "Space" {
            "Space"
        } else if keyName == "Return" {
            "↩"
        } else if keyName == "Delete" {
            "⌫"
        } else if keyName == "Escape" {
            "⎋"
        } else if keyName == "Tab" {
            "⇥"
        } else {
            keyName
        }
    }
    
    var body: some View {
        Text(displayText)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 1),
                    ),
            )
            .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
    }
}

struct ShortcutInputField: View {
    let mode: RecordMode
    @Binding var keyCodes: [Int64]
    @Binding var currentEditingMode: RecordMode?
    @Binding var conflictError: String?
    @State private var cancellables = Set<AnyCancellable>()
    
    var isEditing: Bool {
        currentEditingMode == mode
    }

    var modeColor: Color {
        mode == .normal ? auroraGreen : starlightYellow
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if keyCodes.isEmpty {
                    Text("点击设置")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                } else {
                    ForEach(Array(keyCodes.enumerated()), id: \.offset) { index, keyCode in
                        KeyCapView(keyName: KeyMapper.keyCodeToString(keyCode))
                        
                        if index < keyCodes.count - 1 {
                            Text("+")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                
                Spacer()
                
                if isEditing {
                    Text("等待捷键")
                        .font(.system(size: 10))
                        .foregroundColor(modeColor.opacity(0.8))
                }
            }
            .frame(height: 24)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isEditing ? modeColor.opacity(0.2) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                isEditing ? modeColor.opacity(0.6) : Color.white.opacity(0.2),
                                lineWidth: isEditing ? 2 : 1,
                            ),
                    ),
            )
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isEditing else { return }
                // 清除错误提示
                conflictError = nil
                startEditing()
            }
            .animation(.easeInOut(duration: 0.2), value: isEditing)
            .onAppear {
                setupEventListeners()
            }
            
            // 冲突错误提示
            if let error = conflictError {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundColor(.red.opacity(0.9))
                    .padding(.top, 2)
                    .transition(.opacity)
            }
        }
    }
    
    private func startEditing() {
        currentEditingMode = mode
        EventBus.shared.publish(.hotkeySettingStarted(mode: mode))
    }
    
    private func setupEventListeners() {
        EventBus.shared.events.receive(on: DispatchQueue.main)
            .sink { event in
                switch event {
                case .hotkeySettingUpdated(let eventMode, let combination):
                    guard eventMode == mode else { return }
                    let codes = combination.compactMap { KeyMapper.stringToKeyCodeMap[$0] }
                    keyCodes = codes
                    
                case .hotkeySettingResulted(let eventMode, _, _):
                    guard eventMode == mode else { return }
                    currentEditingMode = nil
                    
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
}

struct ShortcutSettingsCard: View {
    let onClose: () -> Void
    @State private var normalKeyCodes: [Int64] = []
    @State private var commandKeyCodes: [Int64] = []
    @State private var currentEditingMode: RecordMode? = nil
    @State private var normalConflictError: String? = nil
    @State private var commandConflictError: String? = nil
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("快捷键设置")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // 关闭按钮
                Button(action: onClose) {
                    Text("✕")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.1)),
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)
            
            // 主内容区域
            VStack(alignment: .leading, spacing: 16) {
                // 第一行：普通模式
                VStack(alignment: .leading, spacing: 8) {
                    Text("普通模式")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    ShortcutInputField(
                        mode: .normal,
                        keyCodes: $normalKeyCodes,
                        currentEditingMode: $currentEditingMode,
                        conflictError: $normalConflictError,
                    )
                }
                
                // 第二行：命令模式
                VStack(alignment: .leading, spacing: 8) {
                    Text("命令模式")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    ShortcutInputField(
                        mode: .command,
                        keyCodes: $commandKeyCodes,
                        currentEditingMode: $currentEditingMode,
                        conflictError: $commandConflictError,
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
        }
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1),
                ),
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // 点击卡片的任何地方都取消编辑
            cancelEditing()
        }
        .onAppear {
            // 加载快捷键配置
            normalKeyCodes = Config.NORMAL_KEY_CODES
            commandKeyCodes = Config.COMMAND_KEY_CODES
            
            // 监听快捷键设置结果事件
            EventBus.shared.events
                .receive(on: DispatchQueue.main)
                .sink { [self] event in
                    if case .hotkeySettingResulted(let mode, let combination, let isConflict) = event {
                        handleHotkeySettingResulted(mode: mode, combination: combination, isConflict: isConflict)
                    }
                }
                .store(in: &cancellables)
        }
    }
    
    private func cancelEditing() {
        if let mode = currentEditingMode {
            let originalCodes = mode == .normal ? Config.NORMAL_KEY_CODES : Config.COMMAND_KEY_CODES
            let combination = originalCodes.map { KeyMapper.keyCodeToString($0) }
            EventBus.shared.publish(.hotkeySettingResulted(mode: mode, hotkeyCombination: combination))
            currentEditingMode = nil
        }
    }
    
    private func handleHotkeySettingResulted(mode: RecordMode, combination: [String], isConflict: Bool) {
        let newKeyCodes = combination.compactMap { KeyMapper.stringToKeyCodeMap[$0] }
        
        if isConflict {
            // 冲突：恢复原来的快捷键
            let originalCodes = mode == .normal ? Config.NORMAL_KEY_CODES : Config.COMMAND_KEY_CODES
            
            if mode == .normal {
                normalKeyCodes = originalCodes
                normalConflictError = "与命令模式快捷键冲突"
            } else {
                commandKeyCodes = originalCodes
                commandConflictError = "与普通模式快捷键冲突"
            }
            
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if mode == .normal {
                    normalConflictError = nil
                } else {
                    commandConflictError = nil
                }
            }
        } else {
            // 无冲突：更新配置
            if mode == .normal {
                normalKeyCodes = newKeyCodes
                normalConflictError = nil
            } else {
                commandKeyCodes = newKeyCodes
                commandConflictError = nil
            }
        }
    }
}
