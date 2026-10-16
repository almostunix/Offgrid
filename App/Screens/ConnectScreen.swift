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
                if ConnectionUI.showsLiveView(state: viewModel.connectionState, hasConnected: viewModel.connectedProfile != nil) {
                    LiveOverviewScreen(store: viewModel.liveDataStore, recorder: viewModel.liveSeriesRecorder, historyCache: viewModel.isDemo ? viewModel.demoHistoryCache : viewModel.historyCache, isDemo: viewModel.isDemo, isUnencrypted: viewModel.isUnencryptedWithPassword, portalId: viewModel.portalId, onStopDemo: { viewModel.stopDemo() }, onDisconnect: { viewModel.disconnect() }, isReconnecting: viewModel.connectionState == .reconnecting, onRefreshHistory: viewModel.isDemo ? nil : { viewModel.requestHistory() })
                } else {
                    List {
                        // Connection status
                        Section {
                            ConnectionStatusView(state: viewModel.connectionState, portalId: viewModel.portalId, isUnencryptedWithPassword: viewModel.isUnencryptedWithPassword)
                            
                            if viewModel.certificateChanged {
                                Label("This Cerbo's certificate has changed since you trusted it. The app will not connect. If you replaced or reset the Cerbo, delete this connection and add it again.", systemImage: "exclamationmark.shield.fill")
                                    .foregroundStyle(.red)
                                    .font(.callout)
                            }
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

                        // Demo mode
                        Section {
                            Button(action: { viewModel.startDemo() }) {
                                HStack {
                                    Image(systemName: "play.circle.fill")
                                    Text("Try demo mode")
                                }
                            }
                        }
                    }
                    .refreshable { viewModel.requestHistory() }
                }
            }
            .navigationTitle("Cerbo Connection")
            .sheet(isPresented: $showingAddProfile) {
                AddEditProfileView(isPresented: $showingAddProfile, profile: nil, onSave: { profile, password in
                    viewModel.saveProfile(profile, password: password)
                })
            }
            .sheet(item: $selectedProfile) { profile in
                AddEditProfileView(isPresented: .constant(false), profile: profile, onSave: { updatedProfile, password in
                    viewModel.updateProfile(updatedProfile, password: password)
                    selectedProfile = nil
                })
            }
            .sheet(isPresented: $viewModel.showingTrustPrompt) {
                if let host = viewModel.trustPromptHost, 
                   let port = viewModel.trustPromptPort, 
                   let fingerprint = viewModel.trustPromptFingerprint {
                    TrustPromptView(
                        host: host,
                        port: port,
                        fingerprint: fingerprint,
                        onTrust: { viewModel.trustAndConnect() },
                        onCancel: { viewModel.cancelTrustPrompt() }
                    )
                }
            }
            .alert("Not encrypted", isPresented: $viewModel.showingPlaintextWarning) {
                Button("Cancel", role: .cancel) {
                    viewModel.cancelPlaintextWarning()
                }
                Button("Continue", role: .destructive) {
                    viewModel.continuePlaintextConnect()
                }
            } message: {
                Text(plaintextPasswordWarning)
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
        let newProfile = ConnectionProfile(name: name, host: host, port: port, useTLS: useTLS, username: username.isEmpty ? nil : username)
        let profile = profile?.id == nil ? 
            newProfile :
            ConnectionProfile(id: profile!.id, name: name, host: host, port: port, useTLS: useTLS, username: username.isEmpty ? nil : username, passwordKeychainReference: profile!.passwordKeychainReference, portalId: profile!.portalId, lastUsed: profile!.lastUsed, createdAt: profile!.createdAt, updatedAt: Date(), pinnedCertificateSHA256: pinAfterEdit(old: profile!, new: newProfile))
        onSave(profile, password.isEmpty ? nil : password)
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
    @Published var isDemo = false
    @Published var trustPromptHost: String?
    @Published var trustPromptPort: Int?
    @Published var trustPromptFingerprint: String?
    @Published var trustPromptProfile: ConnectionProfile?
    @Published var showingTrustPrompt = false
    @Published var showingPlaintextWarning = false
    @Published private(set) var isUnencryptedWithPassword = false
    
    private var trustAttempt: TrustAttempt?

    var certificateChanged: Bool {
        connectionState == .failed(.untrustedCertificate)
    }

    /// Live data store for the connected Cerbo GX
    let liveDataStore = LiveDataStore()
    /// Records live values for the charts from connect time on (one per connection view model, not per screen).
    lazy var liveSeriesRecorder = LiveSeriesRecorder(store: liveDataStore)
    /// History cache for persistent storage of history data
    let historyCache = HistoryCache()
    /// Demo history cache (in-memory only)
    let demoHistoryCache = HistoryCache(inMemory: true)

    private var connectionManager: ConnectionManager?
    private var profileStore: ConnectionProfileStoring
    private var demoPlayer: DemoPlayer?
    private var demoHistoryStore: HistoryStore?
    private var historySaveWork: DispatchWorkItem?
    private var pendingProfile: ConnectionProfile?
    private var pendingPassword: String?
    private var pendingIsSaved = false   // false for a manual connection (nothing to update in the store)

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

    func saveProfile(_ profile: ConnectionProfile, password: String?) {
        do {
            try profileStore.save(profile, password: password)
            loadProfiles()
        } catch {
            print("Failed to save profile: " + error.localizedDescription)
        }
    }

    func updateProfile(_ profile: ConnectionProfile, password: String?) {
        do {
            try profileStore.updateProfile(profile, password: password)
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
        
        // Reset data stores for new connection
        liveDataStore.reset()
        liveSeriesRecorder.reset()
        
        do {
            let password = try profileStore.password(for: profile)
            
            // Check if plaintext password warning is needed
            if needsPlaintextPasswordWarning(for: profile, password: password) {
                // Store pending connection and show warning
                pendingProfile = profile
                pendingPassword = password
                pendingIsSaved = true
                showingPlaintextWarning = true
                return
            }
            
            // Check if trust prompt is needed
            if needsTrustPrompt(for: profile) {
                startTrustPrompt(for: profile)
            } else {
                // No prompts needed, connect directly
                connectionManager = try ConnectionManager(profile: profile, liveDataStore: liveDataStore, password: password)
                setupConnectionManagerCallbacks()
                connectionManager?.connect()
                connectedProfile = profile
                var updatedProfile = profile
                updatedProfile.markAsLastUsed()
                try profileStore.updateProfile(updatedProfile, password: nil)
                loadProfiles()
            }
        } catch {
            print("Failed to connect: " + error.localizedDescription)
            connectionState = .failed(.unknown(error.localizedDescription))
        }
    }

    /// Trust on first use, shared by saved and manual connections: fetch the server certificate for this one
    /// attempt and show the prompt. A result that arrives after another attempt started is ignored (T-73).
    private func startTrustPrompt(for profile: ConnectionProfile) {
        let attemptId = UUID()
        trustAttempt = TrustAttempt(id: attemptId, profile: profile)
        trustPromptProfile = profile
        guard let port = UInt16(exactly: profile.port), port > 0 else {
            trustAttempt = nil
            trustPromptProfile = nil
            connectionState = .failed(.invalidPort(profile.port))
            return
        }
        ConnectionManager.fetchServerFingerprint(host: profile.host, port: port) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, let attempt = self.trustAttempt, attempt.accepts(resultFor: attemptId) else { return }
                switch result {
                case .success(let fingerprint):
                    let done = attempt.completed(fingerprint: fingerprint)
                    self.trustAttempt = done
                    self.trustPromptFingerprint = done.fingerprint
                    self.trustPromptHost = done.host
                    self.trustPromptPort = done.port
                    self.showingTrustPrompt = true
                case .failure(let error):
                    self.trustAttempt = nil
                    self.trustPromptProfile = nil
                    self.trustPromptFingerprint = nil
                    self.showingTrustPrompt = false
                    self.connectionState = .failed(error)
                }
            }
        }
    }

    /// Pull-to-refresh: ask the Cerbo for the history sub-trees again (T-26). Read-only R/ requests only.
    func requestHistory() {
        connectionManager?.requestHistory()
    }

    func connectManually() {
        guard !host.isEmpty else { return }
        disconnect()
        
        // Reset data stores for new connection
        liveDataStore.reset()
        liveSeriesRecorder.reset()
        
        let port = Int(portString) ?? 1883
        let profile = ConnectionProfile(name: host, host: host, port: port, useTLS: useTLS, username: username.isEmpty ? nil : username)
        
        // Check if trust prompt is needed
        if needsTrustPrompt(for: profile) {
            startTrustPrompt(for: profile)
            return
        }
        
        // Check if plaintext password warning is needed
        if needsPlaintextPasswordWarning(for: profile, password: password.isEmpty ? nil : password) {
            // Store pending connection and show warning
            pendingProfile = profile
            pendingPassword = password.isEmpty ? nil : password
            pendingIsSaved = false
            showingPlaintextWarning = true
            return
        }
        
        do {
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
        isUnencryptedWithPassword = false
    }

    func trustAndConnect() {
        guard let profile = trustPromptProfile, 
              let attempt = trustAttempt, 
              let fingerprint = attempt.pin(for: profile) else {
            // Attempt is stale or host/port changed
            resetTrustPrompt()
            return
        }
        
        // Reset data stores for new connection
        liveDataStore.reset()
        liveSeriesRecorder.reset()
        
        // Update profile with pinned certificate
        var updatedProfile = profile
        updatedProfile.pinnedCertificateSHA256 = fingerprint
        updatedProfile.markAsLastUsed()
        
        do {
            try profileStore.updateProfile(updatedProfile, password: nil)
            loadProfiles()
            
            // Connect with the updated profile
            let password = try profileStore.password(for: updatedProfile)
            connectionManager = try ConnectionManager(profile: updatedProfile, liveDataStore: liveDataStore, password: password)
            setupConnectionManagerCallbacks()
            connectionManager?.connect()
            connectedProfile = updatedProfile
            
            // Clear trust prompt state
            resetTrustPrompt()
        } catch {
            print("Failed to connect after trust: " + error.localizedDescription)
            connectionState = .failed(.unknown(error.localizedDescription))
            resetTrustPrompt()
        }
    }

    func cancelTrustPrompt() {
        resetTrustPrompt()
        connectionState = .idle
    }

    func cancelPlaintextWarning() {
        pendingProfile = nil
        pendingPassword = nil
        showingPlaintextWarning = false
    }

    func continuePlaintextConnect() {
        guard let profile = pendingProfile, let password = pendingPassword else { return }
        
        // Reset data stores for new connection
        liveDataStore.reset()
        liveSeriesRecorder.reset()
        
        do {
            connectionManager = try ConnectionManager(profile: profile, liveDataStore: liveDataStore, password: password)
            setupConnectionManagerCallbacks()
            connectionManager?.connect()
            connectedProfile = profile
            isUnencryptedWithPassword = true
            if pendingIsSaved {
                var updatedProfile = profile
                updatedProfile.markAsLastUsed()
                try? profileStore.updateProfile(updatedProfile, password: nil)
                loadProfiles()
            }
            
            // Clear pending state
            pendingProfile = nil
            pendingPassword = nil
            showingPlaintextWarning = false
        } catch {
            print("Failed to connect after plaintext warning: " + error.localizedDescription)
            connectionState = .failed(.unknown(error.localizedDescription))
            pendingProfile = nil
            pendingPassword = nil
            showingPlaintextWarning = false
        }
    }

    private func resetTrustPrompt() {
        trustPromptHost = nil
        trustPromptPort = nil
        trustPromptFingerprint = nil
        trustPromptProfile = nil
        showingTrustPrompt = false
    }

    func startDemo() {
        // Disconnect any existing real connection first
        disconnect()
        
        stopDemo()
        
        // Reset data stores for demo
        liveDataStore.reset()
        liveSeriesRecorder.reset()
        
        // Create a history store for demo mode
        demoHistoryStore = HistoryStore()
        demoPlayer = DemoPlayer(store: liveDataStore, historyStore: demoHistoryStore)
        
        // Load demo recordings from bundle
        let recordingNames = ["system", "battery", "solarcharger", "vebus", "full_publish_completed", "solarcharger_history", "battery_history", "alarms"]
        var recordings: [Data] = []
        
        for name in recordingNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "json"),
               let data = try? Data(contentsOf: url) {
                recordings.append(data)
            }
        }
        
        do {
            try demoPlayer?.load(recordings)
            demoPlayer?.start()
            isDemo = true
            connectionState = .connected
            portalId = "c0ffee000001" // Demo portal ID
            
            // Store demo history in the demo cache (in-memory only)
            if let store = self.demoHistoryStore, let portalId = self.portalId {
                self.demoHistoryCache.store(store, portalId: portalId, fetchedAt: Date())
            }
        } catch {
            print("Failed to start demo: " + error.localizedDescription)
        }
    }

    func stopDemo() {
        demoPlayer?.stop()
        demoPlayer = nil
        demoHistoryStore = nil
        isDemo = false
        connectionState = .idle
        portalId = nil
        isUnencryptedWithPassword = false
    }

    private func setupConnectionManagerCallbacks() {
        // Capture the current manager to detect if it's been replaced
        let manager = connectionManager
        
        connectionManager?.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                // Only process callbacks from the current manager
                guard let self = self, self.connectionManager === manager else { return }
                self.connectionState = state
            }
        }

        connectionManager?.onPortalIdDetected = { [weak self] portalId in
            DispatchQueue.main.async {
                // Only process callbacks from the current manager
                guard let self = self, self.connectionManager === manager else { return }
                self.portalId = portalId
            }
        }
        
        connectionManager?.onMessage = { [weak self] topic in
            DispatchQueue.main.async {
                // Only process callbacks from the current manager
                guard let self = self, self.connectionManager === manager else { return }
                
                // Check if this is a history message
                if topic.contains("/History/") {
                    // Cancel any pending save
                    self.historySaveWork?.cancel()
                    
                    // Schedule a debounced save on main thread
                    let workItem = DispatchWorkItem { [weak self] in
                        if let store = self?.connectionManager?.historyStore, 
                           let portalId = self?.portalId {
                            self?.historyCache.store(store, portalId: portalId, fetchedAt: Date())
                        }
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
                    self.historySaveWork = workItem
                }
            }
        }
    }
}
