import SwiftUI
import VictronKit

struct ConnectionStatusView: View {
    let state: ConnectionState
    let portalId: String?
    let isUnencryptedWithPassword: Bool

    var body: some View {
        HStack {
            Image(systemName: statusImageName)
                .foregroundColor(statusColor)
            VStack(alignment: .leading) {
                Text(statusText)
                    .font(.headline)
                if let portalId = portalId {
                    Text("Portal ID: " + portalId)
                        .font(.caption)
                }
            }
            Spacer()
            if isUnencryptedWithPassword && state == .connected {
                Label("Not encrypted", systemImage: "lock.open.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
        .padding(.vertical, 8)
    }

    private var statusText: String {
        switch state {
        case .idle:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .reconnecting:
            return "Reconnecting..."
        case .failed(let error):
            return "Failed: " + error.localizedDescription
        }
    }

    private var statusImageName: String {
        switch state {
        case .idle:
            return "network.slash"
        case .connecting:
            return "arrow.2.circlepath.circle.fill"
        case .connected:
            return "checkmark.circle.fill"
        case .reconnecting:
            return "arrow.clockwise.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch state {
        case .idle:
            return .gray
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .reconnecting:
            return .orange
        case .failed:
            return .red
        }
    }
}
