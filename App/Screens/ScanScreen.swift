//
// ScanScreen.swift
//

import SwiftUI
import VictronKit

struct ScanScreen<Advanced: View>: View {
    @ObservedObject var viewModel: ConnectViewModel
    let discovery: DeviceDiscovering
    @ViewBuilder let advanced: () -> Advanced
    @State private var found: [DiscoveredDevice] = []
    @State private var showingSaveSheet = false
    @State private var selectedDevice: DiscoveredDevice?
    @State private var useTLS = true
    @State private var password: String = ""
    @State private var localNetworkStatus: LocalNetworkStatus = .unknown

    var body: some View {
        List {
            // Saved connections section
            Section(header: Text("Saved")) {
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
                }
            }

            // Found devices section
            if !found.isEmpty {
                Section(header: Text("Found on your network")) {
                    ForEach(ScanModel.foundRows(found: found, saved: viewModel.profiles)) { device in
                        if ScanModel.canConnect(device) {
                            Button(action: {
                                selectedDevice = device
                                useTLS = true
                                showingSaveSheet = true
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(device.name)
                                        Text("Host: \(device.host)")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                }
                            }
                        } else {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(device.name)
                                    Text("Host: \(device.host)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text("MQTT is off on this Cerbo. Turn it on in the Cerbo's settings to use Offgrid.")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                Spacer()
                            }
                            .foregroundColor(.gray)
                        }
                    }
                }
            } else {
                // Empty state
                Section {
                    Text("No Cerbo found. Make sure your phone is on the same Wi-Fi as the Cerbo and that MQTT is on. You can also add it by hand under Advanced.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }

            // Add another Cerbo row
            Section {
                NavigationLink("Add another Cerbo") {
                    advanced()
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
        .navigationTitle("Cerbo Connection")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink("Advanced") {
                    advanced()
                }
            }
        }
        .sheet(isPresented: $showingSaveSheet) {
            if let device = selectedDevice {
                VStack(spacing: 20) {
                    Text("Save Connection")
                        .font(.headline)
                        .padding(.top)

                    Form {
                        Section {
                            TextField("Name", text: .constant(device.name))
                                .disabled(true)

                            TextField("Host", text: .constant(device.host))
                                .disabled(true)

                            Toggle("TLS", isOn: $useTLS)

                            SecureField("Password (optional)", text: $password)
                        }
                    }

                    HStack {
                        Button("Cancel", role: .cancel) {
                            showingSaveSheet = false
                        }

                        Button("Save & Connect") {
                            let profile = ScanModel.profile(for: device, useTLS: useTLS)
                            viewModel.saveProfile(profile, password: password.isEmpty ? nil : password)
                            // Connect with the stored copy: only it carries the Keychain reference for the password
                            if let stored = viewModel.profiles.first(where: { $0.id == profile.id }) {
                                viewModel.connect(to: stored)
                            }
                            password = ""
                            showingSaveSheet = false
                        }
                        .disabled(device.name.isEmpty || device.host.isEmpty)
                    }
                    .padding()
                }
                .presentationDetents([.height(300)])
            }
        }
        .onAppear {
            discovery.start { list in
                DispatchQueue.main.async {
                    found = list
                }
            }
        }
        .onDisappear {
            discovery.stop()
        }
        .refreshable {
            discovery.stop()
            discovery.start { list in
                DispatchQueue.main.async {
                    found = list
                }
            }
        }
    }
}
