import SwiftUI

public struct SearchBarView: View {
    @ObservedObject private var settings: AppSettings = .shared
    @Binding var text: String
    @FocusState private var isFocused: Bool
    public let onSubmit: () -> Void
    public let onEscape: () -> Void

    public init(
        text: Binding<String>,
        onSubmit: @escaping () -> Void,
        onEscape: @escaping () -> Void
    ) {
        self._text = text
        self.onSubmit = onSubmit
        self.onEscape = onEscape
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.75))

            TextField(settings.tr("ค้นหาแอป...", "Search"), text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.white)
                .focused($isFocused)
                .onSubmit {
                    onSubmit()
                }

            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.65))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
                )
        )
        .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 5)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = settings.autoFocusSearch
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .launchpadDidPresent)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isFocused = settings.autoFocusSearch
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .launchpadFocusSearch)) { _ in
            isFocused = true
        }
    }
}
