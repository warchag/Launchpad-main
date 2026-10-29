import SwiftUI

public struct PaginationView: View {
    public let totalPages: Int
    @Binding public var currentPage: Int

    public init(totalPages: Int, currentPage: Binding<Int>) {
        self.totalPages = totalPages
        self._currentPage = currentPage
    }

    public var body: some View {
        if totalPages > 1 {
            HStack(spacing: 12) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Button(action: {
                        if currentPage != index {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                currentPage = index
                            }
                            HapticManager.shared.playPage()
                        }
                    }) {
                        Circle()
                            .fill(currentPage == index ? Color.white : Color.white.opacity(0.35))
                            .frame(width: currentPage == index ? 9 : 7, height: currentPage == index ? 9 : 7)
                            .shadow(color: currentPage == index ? Color.white.opacity(0.6) : Color.clear, radius: 4)
                            .animation(.spring(response: 0.25), value: currentPage)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.2))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
            )
        }
    }
}
