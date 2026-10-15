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
                .background(.regularMaterial)
                .cornerRadius(16)
                .shadow(radius: 3)
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
                .background(.regularMaterial)
                .cornerRadius(16)
                .shadow(radius: 3)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Live Charts")
        .navigationBarTitleDisplayMode(.inline)
    }
}



/// Battery chart showing SoC and Power
private struct BatteryChart: View {
    @ObservedObject var recorder: LiveSeriesRecorder
    let timeRange: TimeRange
    
    var body: some View {
        Chart {
            // SoC line
            ForEach(getBatterySocSamples(), id: \.timestamp) { sample in
                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("SoC", sample.value)
                )
                .foregroundStyle(by: .value("Series", "SoC"))
                .interpolationMethod(.catmullRom)
            }
            
            // Power line
            ForEach(getBatteryPowerSamples(), id: \.timestamp) { sample in
                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("Power", sample.value)
                )
                .foregroundStyle(by: .value("Series", "Power"))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXScale(domain: getXDomain())
        .chartYScale(domain: getYDomain())
        .chartXAxis {
            AxisMarks(values: .automatic)
        }
        .chartYAxis {
            AxisMarks(values: .automatic)
        }
        .chartLegend(position: .top, alignment: .center)
    }
    
    private func getBatterySocSamples() -> [Sample] {
        let window = timeRange.getWindow(for: recorder, series: .batterySoc)
        return window.samples.filter { $0.value >= 0 }
    }
    
    private func getBatteryPowerSamples() -> [Sample] {
        let window = timeRange.getWindow(for: recorder, series: .batteryPower)
        return window.samples.filter { $0.value >= 0 }
    }
    
    private func getXDomain() -> ClosedRange<Date> {
        guard let firstSample = getBatterySocSamples().first else {
            let now = Date()
            let fiveMinutesAgo = Calendar.current.date(byAdding: .minute, value: -5, to: now) ?? now
            return fiveMinutesAgo ... now
        }
        
        let now = Date()
        return firstSample.timestamp ... now
    }
    
    private func getYDomain() -> ClosedRange<Double> {
        let socSamples = getBatterySocSamples()
        let powerSamples = getBatteryPowerSamples()
        
        let socMin = socSamples.min(by: { $0.value < $1.value })?.value ?? 0
        let socMax = socSamples.max(by: { $0.value < $1.value })?.value ?? 100
        let powerMin = powerSamples.min(by: { $0.value < $1.value })?.value ?? 0
        let powerMax = powerSamples.max(by: { $0.value < $1.value })?.value ?? 1000
        
        let minValue = min(socMin, powerMin)
        let maxValue = max(socMax, powerMax)
        
        // Add some padding
        let padding = maxValue * 0.1
        return max(0, minValue - padding) ... (maxValue + padding)
    }
}

/// Power flow chart showing PV, AC consumption, and battery power
private struct PowerFlowChart: View {
    @ObservedObject var recorder: LiveSeriesRecorder
    let timeRange: TimeRange
    
    var body: some View {
        Chart {
            // PV Power line
            ForEach(getPvPowerSamples(), id: \.timestamp) { sample in
                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("PV Power", sample.value)
                )
                .foregroundStyle(by: .value("Series", "PV Power"))
                .interpolationMethod(.catmullRom)
            }
            
            // AC Consumption line
            ForEach(getAcConsumptionSamples(), id: \.timestamp) { sample in
                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("AC Consumption", sample.value)
                )
                .foregroundStyle(by: .value("Series", "AC Consumption"))
                .interpolationMethod(.catmullRom)
            }
            
            // Battery Power line
            ForEach(getBatteryPowerSamples(), id: \.timestamp) { sample in
                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("Battery Power", sample.value)
                )
                .foregroundStyle(by: .value("Series", "Battery Power"))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXScale(domain: getXDomain())
        .chartYScale(domain: getYDomain())
        .chartXAxis {
            AxisMarks(values: .automatic)
        }
        .chartYAxis {
            AxisMarks(values: .automatic)
        }
        .chartLegend(position: .top, alignment: .center)
    }
    
    private func getPvPowerSamples() -> [Sample] {
        let window = timeRange.getWindow(for: recorder, series: .pvPower)
        return window.samples.filter { $0.value >= 0 }
    }
    
    private func getAcConsumptionSamples() -> [Sample] {
        let window = timeRange.getWindow(for: recorder, series: .acConsumption)
        return window.samples.filter { $0.value >= 0 }
    }
    
    private func getBatteryPowerSamples() -> [Sample] {
        let window = timeRange.getWindow(for: recorder, series: .batteryPower)
        return window.samples.filter { $0.value >= 0 }
    }
    
    private func getXDomain() -> ClosedRange<Date> {
        guard let firstSample = getPvPowerSamples().first else {
            let now = Date()
            let fiveMinutesAgo = Calendar.current.date(byAdding: .minute, value: -5, to: now) ?? now
            return fiveMinutesAgo ... now
        }
        
        let now = Date()
        return firstSample.timestamp ... now
    }
    
    private func getYDomain() -> ClosedRange<Double> {
        let pvSamples = getPvPowerSamples()
        let acSamples = getAcConsumptionSamples()
        let batterySamples = getBatteryPowerSamples()
        
        let pvMin = pvSamples.min(by: { $0.value < $1.value })?.value ?? 0
        let pvMax = pvSamples.max(by: { $0.value < $1.value })?.value ?? 1000
        let acMin = acSamples.min(by: { $0.value < $1.value })?.value ?? 0
        let acMax = acSamples.max(by: { $0.value < $1.value })?.value ?? 1000
        let batteryMin = batterySamples.min(by: { $0.value < $1.value })?.value ?? 0
        let batteryMax = batterySamples.max(by: { $0.value < $1.value })?.value ?? 1000
        
        let minValue = min(pvMin, acMin, batteryMin)
        let maxValue = max(pvMax, acMax, batteryMax)
        
        // Add some padding
        let padding = maxValue * 0.1
        return max(0, minValue - padding) ... (maxValue + padding)
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
