import SwiftUI

struct AIStatusView: View {
    let description: String
    let isUsingAI: Bool?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var title: String {
        switch isUsingAI {
        case .some(true): return "Apple Intelligence utilisé"
        case .some(false): return "Mode local de secours"
        case .none: return "Moteur IA"
        }
    }

    private var iconName: String {
        switch isUsingAI {
        case .some(true): return "apple.intelligence"
        case .some(false): return "cpu"
        case .none: return "sparkles"
        }
    }
}
