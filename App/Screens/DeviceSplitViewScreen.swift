//
// DeviceSplitViewScreen.swift
//
// Device list plus detail panel side by side on iPad, with layouts for portrait and landscape.
//

import SwiftUI
import VictronKit

/// Device split view screen showing device list on sidebar and device detail on detail panel
public struct DeviceSplitViewScreen: View {
    @ObservedObject var store: LiveDataStore
    @State private var selectedDeviceId: String?

    public init(store: LiveDataStore) {
        self.store = store
    }

    public var body: some View {
        NavigationSplitView {
            // Sidebar: Device List
            DeviceListSidebar(store: store, selectedDeviceId: $selectedDeviceId)
                .navigationTitle("Devices")
        } detail: {
            // Detail: Device Detail
            if let id = selectedDeviceId, let row = DeviceListModel.row(id: id, from: store) {
                DeviceDetailScreen(device: row, store: store)
            } else if selectedDeviceId != nil {
                Text("Device no longer available")
            } else {
                ContentUnavailableView("Select a Device",
                                     systemImage: "powercord.batteryapple",
                                     description: Text("Choose a device from the list"))
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

/// Device list sidebar for the split view
private struct DeviceListSidebar: View {
    @ObservedObject var store: LiveDataStore
    @Binding var selectedDeviceId: String?

    var body: some View {
        List(selection: $selectedDeviceId) {
            ForEach(rows) { device in
                DeviceListRow(device: device)
                    .tag(device.id as String?)
            }
        }
        .overlay {
            if rows.isEmpty {
                ContentUnavailableView("No Devices",
                                     systemImage: "powercord.batteryapple",
                                     description: Text("No devices connected"))
            }
        }
    }

    private var rows: [DeviceRow] {
        return DeviceListModel.rows(from: store)
    }
}

// Preview for Xcode
#if DEBUG
struct DeviceSplitViewScreen_Previews: PreviewProvider {
    static var previews: some View {
        let store = populateStoreWithSampleData()

        Group {
            DeviceSplitViewScreen(store: store)
                .previewDisplayName("Light Mode")
            DeviceSplitViewScreen(store: store)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }

    static func populateStoreWithSampleData() -> LiveDataStore {
        let store = LiveDataStore()
        let topicParser = TopicParser()
        let messages = [
            (topic: "N/c0ffee000001/system/0/Dc/Battery/Soc", payload: ["value": 78.5]),
            (topic: "N/c0ffee000001/system/0/Dc/Battery/Power", payload: ["value": -1250.0]),
            (topic: "N/c0ffee000001/system/0/Dc/Pv/Power", payload: ["value": 1500.0]),
            (topic: "N/c0ffee000001/system/0/Ac/ConsumptionOnOutput/L1/Power", payload: ["value": 851.0]),
            (topic: "N/c0ffee000001/system/0/Ac/ConsumptionOnInput/L1/Power", payload: ["value": 300.0]),
            (topic: "N/c0ffee000001/system/0/Dc/Battery/TimeToGo", payload: ["value": 45230.0]),
            (topic: "N/c0ffee000001/battery/279/ProductName", payload: ["value": "SmartShunt 500A"]),
            (topic: "N/c0ffee000001/battery/279/Soc", payload: ["value": 78.5]),
            (topic: "N/c0ffee000001/battery/279/Voltage", payload: ["value": 50.2]),
            (topic: "N/c0ffee000001/battery/279/Current", payload: ["value": -25.0]),
            (topic: "N/c0ffee000001/solarcharger/278/ProductName", payload: ["value": "MPPT 150/70"]),
            (topic: "N/c0ffee000001/solarcharger/278/State", payload: ["value": 5]),
            (topic: "N/c0ffee000001/solarcharger/278/PvVoltage", payload: ["value": 24.5]),
            (topic: "N/c0ffee000001/solarcharger/278/DcVoltage", payload: ["value": 50.1]),
            (topic: "N/c0ffee000001/solarcharger/278/DcCurrent", payload: ["value": 12.5]),
            (topic: "N/c0ffee000001/solarcharger/278/YieldPower", payload: ["value": 1500.0]),
            (topic: "N/c0ffee000001/vebus/276/ProductName", payload: ["value": "MultiPlus-II 48/5000"]),
            (topic: "N/c0ffee000001/vebus/276/State", payload: ["value": 9]),
            (topic: "N/c0ffee000001/vebus/276/AcInputPower", payload: ["value": 300.0]),
            (topic: "N/c0ffee000001/vebus/276/AcOutputPower", payload: ["value": 851.0]),
            (topic: "N/c0ffee000001/vebus/276/Mode", payload: ["value": 3])
        ]

        for messageTuple in messages {
            if let message = topicParser.parseMessage(topic: messageTuple.topic, payload: messageTuple.payload) {
                store.update(with: message)
            }
        }

        return store
    }
}
#endif
