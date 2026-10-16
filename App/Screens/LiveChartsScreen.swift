//
// LiveChartsScreen.swift
//
// Live charts screen showing multi-series time-based charts from rolling buffers
//

import SwiftUI
import VictronKit
import Charts

/// Live charts screen showing real-time data on multi-series charts
public struct LiveChartsScreen: View {
    /// The live data store providing real-time data
    @ObservedObject public var store: LiveDataStore
    
    /// The series recorder (owned by the connection's view model, so it records even while this screen is closed)
    @ObservedObject public var recorder: LiveSeriesRecorder
    
    /// Time range selection
    @State private var timeRange: TimeRange = .fiveMinutes
    
    /// Initialize with data store
    public init(store: LiveDataStore, recorder: LiveSeriesRecorder) {
        self.store = store
        self.recorder = recorder
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Time range selector
                Picker("Time Range", selection: $timeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.displayName)
                            .tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Battery SoC and Power Chart
                VStack(alignment: .leading, spacing: 16) {
                    Text("Battery")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    BatteryChart(recorder: recorder, timeRange: timeRange)
                        .frame(height: 300)
                        .padding(.horizontal)
                }
                .background(OffgridTheme.surface)
                .cornerRadius(OffgridTheme.tileRadius)
                .padding(.horizontal)
                
                // Power Flow Chart
                VStack(alignment: .leading, spacing: 16) {
                    Text("Power Flow")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    PowerFlowChart(recorder: recorder, timeRange: timeRange)
                        .frame(height: 300)
                        .padding(.horizontal)
                }
                .background(OffgridTheme.surface)
                .cornerRadius(OffgridTheme.tileRadius)
                .padding(.horizontal)
            }
            .background(OffgridTheme.background)
            .padding(.vertical)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Live Charts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ShareLink(item: CSVDocument.live(recorder: recorder, timeRange: timeRange), preview: SharePreview("Live data CSV")) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }
}



/// Battery chart showing SoC and Power
private struct BatteryChart: View {
    @ObservedObject var recorder: LiveSeriesRecorder
    let timeRange: TimeRange
    
    var body: some View {
        InteractiveChart(
            recorder: recorder,
            timeRange: timeRange,
            series: .batterySoc,
            seriesName: "Battery SoC",
            color: OffgridTheme.battery,
            showStats: true
        )
    }
}

/// Power flow chart showing PV, AC consumption, and battery power
private struct PowerFlowChart: View {
    @ObservedObject var recorder: LiveSeriesRecorder
    let timeRange: TimeRange
    
    var body: some View {
        InteractiveChart(
            recorder: recorder,
            timeRange: timeRange,
            series: .pvPower,
            seriesName: "PV Power",
            color: OffgridTheme.solar,
            showStats: true
        )
    }
}

// Preview for Xcode
#if DEBUG
struct LiveChartsScreen_Previews: PreviewProvider {
    static var previews: some View {
        let store = populateStoreWithSampleData()
        
        Group {
            LiveChartsScreen(store: store, recorder: LiveSeriesRecorder(store: store))
                .previewDisplayName("Light Mode")
            LiveChartsScreen(store: store, recorder: LiveSeriesRecorder(store: store))
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
            (topic: "N/c0ffee000001/system/0/Ac/ConsumptionOnInput/L1/Power", payload: ["value": 300.0])
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
