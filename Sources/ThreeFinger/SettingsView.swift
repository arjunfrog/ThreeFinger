import SwiftUI

/// The panel under the menu bar icon, laid out like the system's Wi-Fi and Sound menus.
struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SwitchRow(title: "ThreeFinger", isOn: $model.isOn)
                .fontWeight(.semibold)
                .padding(.vertical, 4)

            if model.needsAttention {
                MenuDivider()
                VStack(alignment: .leading, spacing: 12) {
                    if model.trackpadUnavailable {
                        IssueRow(
                            title: "Can't read the trackpad",
                            detail: "This version of macOS didn't load the multitouch framework, so gestures won't work."
                        )
                    }
                    if !model.canSendKeys {
                        IssueRow(
                            title: "Allow ThreeFinger to press media keys",
                            detail: "Turn on ThreeFinger in Privacy & Security > Accessibility.",
                            button: "Allow…",
                            action: model.requestKeyAccess
                        )
                    }
                    ForEach(model.conflicts) { conflict in
                        IssueRow(title: conflict.title, detail: conflict.fix, button: "Open Settings") {
                            NSWorkspace.shared.open(conflict.settingsURL)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            MenuDivider()
            VStack(alignment: .leading, spacing: 8) {
                SwitchRow(title: "Play or pause", detail: "Tap with three fingers", isOn: $model.playPause)
                SwitchRow(title: "Change volume", detail: "Swipe up or down with three fingers", isOn: $model.volume)
                SwitchRow(title: "Previous or next track", detail: "Swipe left or right with three fingers", isOn: $model.tracks)
                if model.isOn {
                    Text(model.lastGesture.map { "Last gesture: \($0.name.lowercased())" } ?? "Try a gesture to test it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                }
            }
            .padding(.vertical, 4)
            .disabled(!model.isOn)

            MenuDivider()
            VStack(alignment: .leading, spacing: 8) {
                SwitchRow(title: "Open at login", isOn: Binding(
                    get: { model.opensAtLogin },
                    set: { model.setOpensAtLogin($0) }
                ))
                SwitchRow(title: "Show in menu bar", detail: "When hidden, open ThreeFinger to show this panel", isOn: $model.showIcon)
            }
            .padding(.vertical, 4)

            MenuDivider()
            QuitRow()
        }
        .padding(.vertical, 6)
        .frame(width: 300)
    }
}

private struct SwitchRow: View {
    let title: String
    var detail: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .fontWeight(.regular)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityHidden(true)
            Spacer(minLength: 0)
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .accessibilityHint(detail ?? "")
        }
        .padding(.horizontal, 14)
    }
}

private struct IssueRow: View {
    let title: String
    let detail: String
    var button: String?
    var action: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let button {
                Button(button, action: action)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
    }
}

private struct QuitRow: View {
    @State private var isHovered = false

    var body: some View {
        Button { NSApp.terminate(nil) } label: {
            HStack {
                Text("Quit ThreeFinger")
                Spacer()
                Text("⌘Q").foregroundStyle(.secondary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .background(isHovered ? Color.primary.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .keyboardShortcut("q")
        .onHover { isHovered = $0 }
        .padding(.horizontal, 5)
    }
}

private struct MenuDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
    }
}
