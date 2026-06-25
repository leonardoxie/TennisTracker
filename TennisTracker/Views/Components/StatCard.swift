import SwiftUI

/// Reusable stat card component with gradient background
struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let unit: String?
    let gradient: [Color]
    
    init(icon: String, value: String, label: String, unit: String? = nil, gradient: [Color] = [Color(red: 0.15, green: 0.25, blue: 0.15), Color(red: 0.25, green: 0.35, blue: 0.20)]) {
        self.icon = icon
        self.value = value
        self.label = label
        self.unit = unit
        self.gradient = gradient
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 0.78, green: 0.90, blue: 0.20))
                if let unit = unit {
                    Text(unit)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Compact Stat Card (for horizontal layout)

struct CompactStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(1)
        }
        .frame(minWidth: 60)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        HStack(spacing: 12) {
            StatCard(icon: "speedometer", value: "120", label: "平均速度", unit: "km/h")
            CompactStatCard(icon: "target", value: "42", label: "击球", color: .blue)
        }
        .padding()
    }
}
