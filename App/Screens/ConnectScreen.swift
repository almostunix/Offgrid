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






