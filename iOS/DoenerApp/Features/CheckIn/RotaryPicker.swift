import SwiftUI

struct FoodItem: Identifiable {
    let id: String
    let emoji: String
    let label: String

    static let all: [FoodItem] = [
        FoodItem(id: "doener", emoji: "🥙", label: "Döner"),
        FoodItem(id: "yufka", emoji: "🌯", label: "Yufka"),
        FoodItem(id: "lahmacun", emoji: "🫓", label: "Lahmacun"),
        FoodItem(id: "teller", emoji: "🍽️", label: "Teller"),
        FoodItem(id: "pommes", emoji: "🍟", label: "Pommes"),
        FoodItem(id: "falafel", emoji: "🧆", label: "Falafel"),
    ]
}

struct RotaryPicker: View {
    @Binding var selectedIndex: Int
    let items: [FoodItem]
    @State private var dragAngle: Double = 0
    @State private var baseAngle: Double = 0

    private let radius: CGFloat = 110

    private func angleForIndex(_ index: Int) -> Double {
        let count = Double(items.count)
        let itemAngle = (Double(index) / count) * 360.0
        let rotation = -(Double(selectedIndex) / count) * 360.0 + dragAngle
        return itemAngle + rotation
    }

    private func scaleForAngle(_ angle: Double) -> CGFloat {
        // Normalize angle to -180...180
        var a = angle.truncatingRemainder(dividingBy: 360)
        if a > 180 { a -= 360 }
        if a < -180 { a += 360 }
        // Top (0°) = biggest, bottom (180°) = smallest
        let normalized = abs(a) / 180.0
        return 1.4 - normalized * 0.8 // 1.4 at top, 0.6 at bottom
    }

    private func opacityForAngle(_ angle: Double) -> Double {
        var a = angle.truncatingRemainder(dividingBy: 360)
        if a > 180 { a -= 360 }
        if a < -180 { a += 360 }
        let normalized = abs(a) / 180.0
        return 1.0 - normalized * 0.5
    }

    var body: some View {
        ZStack {
            // Items on the wheel
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let angle = angleForIndex(index)
                let radian = angle * .pi / 180
                let x = sin(radian) * Double(radius)
                let y = -cos(radian) * Double(radius)
                let scale = scaleForAngle(angle)

                Text(item.emoji)
                    .font(.system(size: 44))
                    .scaleEffect(scale)
                    .opacity(opacityForAngle(angle))
                    .offset(x: x, y: y)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedIndex)
                    .animation(.interactiveSpring, value: dragAngle)
            }

            // Selected label
            VStack(spacing: 4) {
                Text(items[selectedIndex].label)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .id(selectedIndex)
                    .transition(.scale.combined(with: .opacity))
            }
            .animation(.spring(response: 0.3), value: selectedIndex)
        }
        .frame(width: radius * 2 + 80, height: radius * 2 + 80)
        .contentShape(Circle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    let delta = value.translation.width
                    dragAngle = delta * 0.5
                }
                .onEnded { value in
                    let delta = value.translation.width * 0.5
                    let itemAngle = 360.0 / Double(items.count)
                    let steps = Int(round(delta / itemAngle * -1))
                    var newIndex = (selectedIndex + steps) % items.count
                    if newIndex < 0 { newIndex += items.count }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedIndex = newIndex
                        dragAngle = 0
                    }
                }
        )
    }
}
