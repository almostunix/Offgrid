import SwiftUI
import VictronKit

struct ConnectScreen: View {
    @StateObject private var viewModel = ConnectViewModel()
    @State private var showingAddProfile = false
    @State private var showingEditProfile = false
    @State private var selectedProfile: ConnectionProfile?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.connectionState == .connected {
                    LiveOverviewScreen(store: viewModel.liveDataStore)
                } else {
                    List {
                        // Connection status
                        Section {
                            ConnectionStatusView(state: viewModel.connectionState, portalId: viewModel.portalId)
                        }

                        // Saved connections
                        Section(header: Text("Saved Connections")) {
                            ForEach(viewModel.profiles) { profile in
                                Button(action: {
                                    viewModel.connect(to: profile)
                                }) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(profile.name)
                                            Text("Host: \(profile.host):\(profile.port)")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                        if viewModel.connectedProfile?.id == profile.id {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        viewModel.deleteProfile(profile)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }

                                    Button {
                                        selectedProfile = profile
                                        showingEditProfile = true
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                            }

                            Button(action: { showingAddProfile = true }) {
                                HStack {
                                    Image(systemName: "plus")
                                    Text("Add Connection")
                                }
                            }
                        }

                        // Manual connection
                        Section(header: Text("Manual Connection")) {
                            HStack {
                                TextField("Host", text: $viewModel.host)
                                    .keyboardType(.alphabet)
                                Button(action: { viewModel.connectManually() }) {
                                    Text("Connect")
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(viewModel.host.isEmpty)
                            }

                            HStack {
                                TextField("Port", text: $viewModel.portString)
                                    .keyboardType(.numberPad)
                                Toggle("TLS", isOn: $viewModel.useTLS)
                            }

                            if viewModel.useTLS {
                                Text("TLS connection (requires valid certificate)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Username", text: $viewModel.username)
                                SecureField("Password", text: $viewModel.password)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Cerbo Connection")
            .sheet(isPresented: $showingAddProfile) {
                AddEditProfileView(isPresented: $showingAddProfile, profile: nil, onSave: { profile in
                    viewModel.saveProfile(profile)
                })
            }
            .sheet(item: $selectedProfile) { profile in
                AddEditProfileView(isPresented: .constant(false), profile: profile, onSave: { updatedProfile in
                    viewModel.updateProfile(updatedProfile)
                    selectedProfile = nil
                })
            }
            .onAppear {
                viewModel.loadProfiles()
            }
        }
    }
}

struct ConnectionStatusView: View {
    let state: ConnectionState
    let portalId: String?

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

struct AddEditProfileView: View {
    @Binding var isPresented: Bool
    let profile: ConnectionProfile?
    let onSave: (ConnectionProfile) -> Void

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var portString: String = "1883"
    @State private var useTLS: Bool = false
    @State private var username: String = ""
    @State private var password: String = ""

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
                    SecureField("Password", text: $password)
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
                }
            }
        }
    }

    private func saveProfile() {
        let port = Int(portString) ?? 1883
        let profile = profile?.id == nil ? 
            ConnectionProfile(name: name, host: host, port: port, useTLS: useTLS, username: username.isEmpty ? nil : username) :
            ConnectionProfile(id: profile!.id, name: name, host: host, port: port, useTLS: useTLS, username: username.isEmpty ? nil : username, passwordKeychainReference: profile!.passwordKeychainReference, portalId: profile!.portalId, lastUsed: profile!.lastUsed, createdAt: profile!.createdAt, updatedAt: Date())
        onSave(profile)
        isPresented = false
    }
}

class ConnectViewModel: ObservableObject {
    @Published var profiles: [ConnectionProfile] = []
    @Published var connectionState: ConnectionState = .idle
    @Published var portalId: String?
    @Published var host: String = ""
    @Published var portString: String = "1883"
    @Published var useTLS: Bool = false
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var connectedProfile: ConnectionProfile?

    /// Live data store for the connected Cerbo GX
    let liveDataStore = LiveDataStore()

    private var connectionManager: ConnectionManager?
    private var profileStore: ConnectionProfileStoring

    init() {
        do {
            let secretStore = try KeychainService()
            profileStore = try ConnectionProfileStore(secretStore: secretStore)
        } catch {
            fatalError("Failed to initialize profile store: " + error.localizedDescription)
        }
    }

    func loadProfiles() {
        do {
            profiles = try profileStore.loadAllProfiles()
        } catch {
            print("Failed to load profiles: " + error.localizedDescription)
        }
    }

    func saveProfile(_ profile: ConnectionProfile) {
        do {
            try profileStore.save(profile, password: password.isEmpty ? nil : password)
            loadProfiles()
        } catch {
            print("Failed to save profile: " + error.localizedDescription)
        }
    }

    func updateProfile(_ profile: ConnectionProfile) {
        do {
            try profileStore.updateProfile(profile, password: password.isEmpty ? nil : password)
            loadProfiles()
        } catch {
            print("Failed to update profile: " + error.localizedDescription)
        }
    }

    func deleteProfile(_ profile: ConnectionProfile) {
        do {
            try profileStore.deleteProfile(id: profile.id)
            if connectedProfile?.id == profile.id {
                disconnect()
            }
            loadProfiles()
        } catch {
            print("Failed to delete profile: " + error.localizedDescription)
        }
    }

    func connect(to profile: ConnectionProfile) {
        disconnect()
        do {
            let password = try profileStore.password(for: profile)
            connectionManager = try ConnectionManager(profile: profile, liveDataStore: liveDataStore, password: password)
            setupConnectionManagerCallbacks()
            connectionManager?.connect()
            connectedProfile = profile
            var updatedProfile = profile
            updatedProfile.markAsLastUsed()
            try profileStore.updateProfile(updatedProfile, password: nil)
            loadProfiles()
        } catch {
            print("Failed to connect: " + error.localizedDescription)
            connectionState = .failed(.unknown(error.localizedDescription))
        }
    }

    func connectManually() {
        guard !host.isEmpty else { return }
        disconnect()
        do {
            let port = Int(portString) ?? 1883
            let profile = ConnectionProfile(name: host, host: host, port: port, useTLS: useTLS, username: username.isEmpty ? nil : username)
            connectionManager = try ConnectionManager(profile: profile, liveDataStore: liveDataStore, password: password.isEmpty ? nil : password)
            setupConnectionManagerCallbacks()
            connectionManager?.connect()
            connectedProfile = profile
        } catch {
            print("Failed to connect manually: " + error.localizedDescription)
            connectionState = .failed(.unknown(error.localizedDescription))
        }
    }

    func disconnect() {
        connectionManager?.disconnect()
        connectionManager = nil
        connectionState = .idle
        portalId = nil
        connectedProfile = nil
    }

    private func setupConnectionManagerCallbacks() {
        connectionManager?.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                self?.connectionState = state
            }
        }

        connectionManager?.onPortalIdDetected = { [weak self] portalId in
            DispatchQueue.main.async {
                self?.portalId = portalId
            }
        }
    }
}
