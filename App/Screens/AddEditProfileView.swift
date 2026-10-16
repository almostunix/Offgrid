import SwiftUI
import VictronKit

struct AddEditProfileView: View {
    @Binding var isPresented: Bool
    let profile: ConnectionProfile?
    let onSave: (ConnectionProfile, String?) -> Void

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var portString: String = "1883"
    @State private var useTLS: Bool = false
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var portalId: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Connection Details")) {
                    TextField("Name", text: $name)
                    TextField("Host", text: $host)
                    TextField("Port", text: $portString)
                        .keyboardType(.numberPad)
                    Toggle("Use TLS", isOn: $useTLS)
                }

                Section(header: Text("Credentials")) {
                    TextField("Username", text: $username)
                    SecureField(profile?.passwordKeychainReference != nil ? "Password saved" : "Password", text: $password)
                }

                Section(header: Text("Advanced")) {
                    TextField("Portal ID (VRM ID)", text: $portalId)
                }
            }
            .navigationTitle(profile == nil ? "Add Connection" : "Edit Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(name.isEmpty || host.isEmpty || portString.isEmpty)
                }
            }
            .onAppear {
                if let profile = profile {
                    name = profile.name
                    host = profile.host
                    portString = String(profile.port)
                    useTLS = profile.useTLS
                    username = profile.username ?? ""
                    portalId = profile.portalId ?? ""
                }
            }
        }
    }

    private func saveProfile() {
        let port = Int(portString) ?? 1883
        // Optional portal ID: trimmed, lower-cased, and dropped unless it is a valid portal ID
        let typedPortalId = portalId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let portalIdToSave: String? = ReadOnlyPublisher.isValidPortalId(typedPortalId) ? typedPortalId : nil
        var newProfile = ConnectionProfile(name: name, host: host, port: port, useTLS: useTLS, username: username.isEmpty ? nil : username)
        newProfile.portalId = portalIdToSave
        let profile = profile?.id == nil ? 
            newProfile :
            ConnectionProfile(id: profile!.id, name: name, host: host, port: port, useTLS: useTLS, username: username.isEmpty ? nil : username, passwordKeychainReference: profile!.passwordKeychainReference, portalId: portalIdToSave, lastUsed: profile!.lastUsed, createdAt: profile!.createdAt, updatedAt: Date(), pinnedCertificateSHA256: pinAfterEdit(old: profile!, new: newProfile))
        onSave(profile, password.isEmpty ? nil : password)
        isPresented = false
    }
}
