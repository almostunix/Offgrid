import SwiftUI

public enum StatusKind {
    case demo
    case notEncrypted
    case reconnecting
    case certificateChanged
}

public struct StatusBadge: View {
    let kind: StatusKind

    public init(kind: StatusKind) {
        self.kind = kind
    }

    private var color: Color {
        switch kind {
        case .demo, .notEncrypted, .reconnecting:
            return OffgridTheme.warning
        case .certificateChanged:
            return OffgridTheme.alarm
        }
    }

    private var text: String {
        switch kind {
        case .demo:
            return "Demo"
        case .notEncrypted:
            return "Not encrypted"
        case .reconnecting:
            return "Reconnecting"
        case .certificateChanged:
            return "Certificate changed"
        }
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 12))
            Text(text)
                .font(.system(size: 13))
        }
        .foregroundColor(OffgridTheme.textPrimary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color)
        .clipShape(Capsule())
    }
}

struct StatusBadge_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 8) {
            StatusBadge(kind: .demo)
            StatusBadge(kind: .notEncrypted)
            StatusBadge(kind: .reconnecting)
            StatusBadge(kind: .certificateChanged)
        }
    }
}
