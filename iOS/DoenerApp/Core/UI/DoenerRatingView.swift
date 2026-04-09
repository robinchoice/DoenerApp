import SwiftUI

/// 1-5 Döner-Bewertung. Ersetzt klassische Sterne durch SF-Symbol `fork.knife.circle.fill`.
/// Falls Robin später ein Custom-PNG liefert, hier zentral ersetzbar.
struct DoenerRatingView: View {
    let value: Int
    var size: CGFloat = 16
    var interactive: Bool = false
    var onChange: ((Int) -> Void)? = nil

    var body: some View {
        HStack(spacing: max(2, size * 0.15)) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= value ? "fork.knife.circle.fill" : "fork.knife.circle")
                    .font(.system(size: size, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(i <= value ? Color.orange : Color.gray.opacity(0.4))
                    .scaleEffect(interactive && i == value ? 1.12 : 1.0)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard interactive else { return }
                        withAnimation(.spring(response: 0.25)) { onChange?(i) }
                    }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        DoenerRatingView(value: 3)
        DoenerRatingView(value: 5, size: 28)
        DoenerRatingView(value: 2, size: 36, interactive: true) { _ in }
    }
    .padding()
}
