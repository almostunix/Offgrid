import SwiftUI
import VictronKit

struct ConnectScreenPreview: View {
    var body: some View {
        ConnectScreen()
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Connect Screen")
    }
}

struct ConnectionStatusPreview: View {
    var body: some View {
        List {
            Section {
                ConnectionStatusView(state: .idle, portalId: nil)
                ConnectionStatusView(state: .connecting, portalId: nil)
                ConnectionStatusView(state: .connected, portalId: "c0ffee000001")
                ConnectionStatusView(state: .reconnecting, portalId: "c0ffee000001")
                ConnectionStatusView(state: .failed(.connectionRefused), portalId: nil)
            }
        }
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Connection Status States")
    }
}

struct AddEditProfilePreview: View {
    var body: some View {
        NavigationStack {
            AddEditProfileView(isPresented: .constant(true), profile: nil, onSave: { _ in })
        }
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Add Profile")
    }
}

struct EditProfilePreview: View {
    var body: some View {
        let profile = ConnectionProfile(
            name: "My Cerbo",
            host: "192.168.1.100",
            port: 8883,
            useTLS: true,
            username: "admin"
        )
        NavigationStack {
            AddEditProfileView(isPresented: .constant(true), profile: profile, onSave: { _ in })
        }
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Edit Profile")
    }
}

#Preview {
    ConnectScreenPreview()
    ConnectionStatusPreview()
    AddEditProfilePreview()
    EditProfilePreview()
}
