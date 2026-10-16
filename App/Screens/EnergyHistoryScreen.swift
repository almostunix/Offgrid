//
// EnergyHistoryScreen.swift
//
// Energy history charts showing daily solar yield
//

import SwiftUI
import Charts
import VictronKit

/// Energy history screen showing daily solar yield charts
public struct EnergyHistoryScreen: View {
    /// The history cache providing cached history data
    @ObservedObject public var historyCache: HistoryCache
    
    /// Whether demo mode is active
    public var isDemo: Bool = false
    
    /// The portal ID for filtering data
    public var portalId: String?
    
    /// Number of days to display
    @State private var lastDays: Int = 7
    
    /// Action to refresh history data
    public var onRefresh: (() -> Void)? = nil
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Title and picker
                VStack(alignment: .leading, spacing: 16) {
                    Text("Energy History")
                        .font(.largeTitle)
                        .bold()
                    
                    Picker("Time period", selection: $lastDays) {
                        Text("Last 7 days").tag(7)
                        Text("Last 30 days").tag(30)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }
                .padding()
                
                // Data source caption
                Text(dataSourceCaption)
                    .font(.caption)
                    .foregroundStyle(OffgridTheme.textSecondary)
                    .padding(.horizontal)
                
                // Chart
                if let portalId = portalId, let firstInstance = getFirstSolarChargerInstance() {
                    SolarYieldChart(historyCache: historyCache, portalId: portalId, instance: firstInstance, lastDays: lastDays)
                        .frame(height: 400)
                        .padding()
                } else {
                    VStack {
                        Image(systemName: "chartbar.xaxis")
                            .font(.largeTitle)
                            .foregroundStyle(OffgridTheme.textSecondary)
                        Text("No solar charger data available")
                            .foregroundStyle(OffgridTheme.textSecondary)
                    }
                    .frame(height: 400)
                    .padding()
                }
            }
            .background(OffgridTheme.background)
            .refreshable {
                onRefresh?()
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Energy History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let portalId = portalId, let firstInstance = getFirstSolarChargerInstance() {
                let start = Calendar.current.date(byAdding: .day, value: -(lastDays - 1), to: Calendar.current.startOfDay(for: Date())) ?? .distantPast
                let days = historyCache.days(portalId: portalId, instance: firstInstance).filter { $0.date >= start }
                ShareLink(item: CSVDocument.history(days), preview: SharePreview("Solar history CSV")) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
    }
    
    private var dataSourceCaption: String {
        if isDemo {
            return "Daily solar history from demo data, cached on this device"
        } else {
            return "Daily solar history from the Cerbo, cached on this device"
        }
    }
    
    /// Get the first solar charger instance ID from the cache
    private func getFirstSolarChargerInstance() -> String? {
        guard let portalId = portalId else { return nil }
        return historyCache.instances(portalId: portalId).first
    }
}

/// Solar yield chart showing daily kWh values
private struct SolarYieldChart: View {
    @ObservedObject var historyCache: HistoryCache
    let portalId: String
    let instance: String
    let lastDays: Int
    
    var body: some View {
        Chart {
            ForEach(bars, id: \.date) { bar in
                BarMark(
                    x: .value("Date", bar.date),
                    y: .value("kWh", bar.kWh)
                )
                .foregroundStyle(OffgridTheme.solar)
            }
            
            if let maxValue = bars.map(\.kWh).max() {
                RuleMark(
                    y: .value("Max", maxValue)
                )
                .foregroundStyle(OffgridTheme.textSecondary.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel()
            }
        }
        .chartPlotStyle { 
            $0.background(OffgridTheme.surface)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var bars: [(date: Date, kWh: Double)] {
        let records = historyCache.days(portalId: portalId, instance: instance)
        return EnergyHistoryModel.bars(from: records, lastDays: lastDays, now: Date())
    }
}

// Preview for Xcode
#if DEBUG
struct EnergyHistoryScreen_Previews: PreviewProvider {
    static var previews: some View {
        let cache = loadPreviewData()
        
        Group {
            EnergyHistoryScreen(historyCache: cache, isDemo: false, portalId: "c0ffee000001")
                .previewDisplayName("Light Mode")
            EnergyHistoryScreen(historyCache: cache, isDemo: false, portalId: "c0ffee000001")
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
    
    static func loadPreviewData() -> HistoryCache {
        let cache = HistoryCache(inMemory: true)
        
        // Add some test data using fixture
        if let url = Bundle.main.url(forResource: "solarcharger_history", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let messages = json["messages"] as? [[String: Any]] {
                let store = HistoryStore()
                for message in messages {
                    if let topic = message["topic"] as? String,
                       let payload = message["payload"] as? [String: Any] {
                        if let payloadData = try? JSONSerialization.data(withJSONObject: payload) {
                            store.handle(topic: topic, payload: payloadData)
                        }
                    }
                }
                cache.store(store, portalId: "c0ffee000001", fetchedAt: Date())
            }
        }
        
        return cache
    }
}
#endif
