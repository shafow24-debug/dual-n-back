import SwiftUI

/// Selector tipo cápsula blanca para el nivel N (1 a 9) con botones circulares naranjas `◀` y `▶`
struct NLevelSelector: View {
    @Binding var level: Int
    var leadingLabel: String? = "N ="
    var hapticsEnabled: Bool = true
    
    var body: some View {
        HStack(spacing: 14) {
            if let leadingLabel, !leadingLabel.isEmpty {
                Text(leadingLabel)
                    .font(Theme.font(.title2, weight: .bold))
                    .foregroundColor(.white)
            }
            
            HStack(spacing: 20) {
                Button {
                    if level > 1 {
                        level -= 1
                        HapticsManager.shared.playSelectionTap(enabled: hapticsEnabled)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Theme.accentOrange)
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "arrowtriangle.left.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: -1)
                    }
                    .opacity(level > 1 ? 1.0 : 0.45)
                }
                .buttonStyle(.plain)
                .disabled(level <= 1)
                .accessibilityLabel("Disminuir nivel N")
                
                Text("\(level)")
                    .font(Theme.font(size: 28, weight: .heavy))
                    .foregroundColor(Theme.primaryBlue)
                    .frame(minWidth: 32)
                    .animation(.none, value: level)
                
                Button {
                    if level < 9 {
                        level += 1
                        HapticsManager.shared.playSelectionTap(enabled: hapticsEnabled)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Theme.accentOrange)
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "arrowtriangle.right.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: 1)
                    }
                    .opacity(level < 9 ? 1.0 : 0.45)
                }
                .buttonStyle(.plain)
                .disabled(level >= 9)
                .accessibilityLabel("Aumentar nivel N")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white)
                    .softShadow()
            )
        }
    }
}
