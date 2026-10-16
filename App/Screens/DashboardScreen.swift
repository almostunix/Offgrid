//
// DashboardScreen.swift
//
// Customizable dashboard with draggable, resizable tiles
//

import SwiftUI
import VictronKit

/// Available tile types for the dashboard
public enum TileType: String, Codable, CaseIterable, Identifiable {
    case batteryStatus
    case powerFlow
    case deviceStates
    case devices
    case alarmLog
    case topicExplorer
    case liveCharts
    case systemOverview
    
    public var id: String { rawValue }
    
    /// Display name for the tile type
    public var displayName: String {
        switch self {
        case .batteryStatus: return "Battery Status"
        case .powerFlow: return "Power Flow"
        case .deviceStates: return "Device States"
        case .devices: return "Devices"
        case .alarmLog: return "Alarm Log"
        case .topicExplorer: return "Topic Explorer"
        case .liveCharts: return "Live Charts"
        case .systemOverview: return "System Overview"
        }
    }
    
    /// Icon for the tile type
    public var icon: String {
        switch self {
        case .batteryStatus: return "battery.100"
        case .powerFlow: return "bolt"
        case .deviceStates: return "network"
        case .devices: return "server.rack"
        case .alarmLog: return "exclamationmark.triangle"
        case .topicExplorer: return "list.bullet"
        case .liveCharts: return "chart.xyaxis.line"
        case .systemOverview: return "house"
        }
    }
}

/// Represents a dashboard tile with its configuration
public struct DashboardTile: Identifiable, Codable, Equatable {
    public let id: String
    public var type: TileType
    public var size: TileSize
    public var position: Int
    
    public init(id: String = UUID().uuidString, type: TileType, size: TileSize = .small, position: Int = 0) {
        self.id = id
        self.type = type
        self.size = size
        self.position = position
    }
}



/// Available tile sizes
public enum TileSize: String, Codable, CaseIterable {
    case small
    case medium
    case large
    
    /// Number of columns this size occupies
    public var columns: Int {
        switch self {
        case .small: return 1
        case .medium: return 2
        case .large: return 3
        }
    }
}

/// Dashboard screen with customizable tiles
public struct DashboardScreen: View {
    /// The live data store providing real-time data
    @ObservedObject public var store: LiveDataStore
    
    /// Records live values for the charts
    public let recorder: LiveSeriesRecorder?
    
    /// Dashboard tiles configuration
    @AppStorage("dashboardTiles") private var tilesData: Data = Data()
    
    /// Computed tiles from stored data
    @State private var tiles: [DashboardTile] = []
    
    /// Whether we're in edit mode
    @Environment(\.editMode) private var editMode
    private var isEditing: Bool { editMode?.wrappedValue.isEditing == true }

    /// Currently dragged tile ID
    @State private var draggedTileId: UUID?
    
    public init(store: LiveDataStore, recorder: LiveSeriesRecorder? = nil) {
        self.store = store
        self.recorder = recorder
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 16)],
                    spacing: 16
                ) {
                    // Only show tiles that fit in the grid
                    ForEach(tiles.filter { $0.position < 100 }) { tile in
                        tileView(for: tile)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
                .padding()
            }
            .background(OffgridTheme.background)
            .scrollContentBackground(.hidden)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .onAppear(perform: loadTiles)
            .onChange(of: tiles) { _ in
                saveTiles()
            }
        }
    }
    
    /// Toolbar content with edit button
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            EditButton()
        }
    }
    
    /// View for a specific tile
    private func tileView(for tile: DashboardTile) -> some View {
        Group {
            switch tile.type {
            case .batteryStatus:
                BatteryStatusView(store: store)
                    .frame(height: tileHeight(for: tile.size))
            case .powerFlow:
                PowerFlowView(store: store)
                    .frame(height: tileHeight(for: tile.size))
            case .deviceStates:
                DeviceStatesView(store: store)
                    .frame(height: tileHeight(for: tile.size))
            case .devices:
                DeviceListPreview(store: store)
                    .frame(height: tileHeight(for: tile.size))
            case .alarmLog:
                AlarmLogPreview(store: store)
                    .frame(height: tileHeight(for: tile.size))
            case .topicExplorer:
                TopicExplorerPreview(store: store)
                    .frame(height: tileHeight(for: tile.size))
            case .liveCharts:
                LiveChartsPreview(store: store)
                    .frame(height: tileHeight(for: tile.size))
            case .systemOverview:
                SystemOverviewView(store: store)
                    .frame(height: tileHeight(for: tile.size))
            }
        }
        .padding()
        .background(OffgridTheme.surface)
        .cornerRadius(OffgridTheme.tileRadius)
        .overlay(alignment: .topTrailing) {
            if isEditing {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.white, OffgridTheme.alarm)
                    .padding(8)
                    .onTapGesture {
                        removeTile(tile)
                    }
            }
        }
        .draggable(tile.id) {
            Image(systemName: tile.type.icon)
                .font(.title)
                .foregroundStyle(OffgridTheme.grid)
                .padding()
                .background(OffgridTheme.surface)
                .cornerRadius(OffgridTheme.buttonRadius)
        }
        .dropDestination(for: String.self, action: { ids, location in
            handleDrop(ids: ids, onto: tile)
            return true
        })
    }
    
    /// Height for a tile based on its size
    private func tileHeight(for size: TileSize) -> CGFloat {
        switch size {
        case .small: return 150
        case .medium: return 250
        case .large: return 350
        }
    }
    
    /// Load tiles from storage
    private func loadTiles() {
        guard let decoded = try? JSONDecoder().decode([DashboardTile].self, from: tilesData) else {
            // Default tiles if none exist
            tiles = [
                DashboardTile(id: UUID().uuidString, type: .batteryStatus, size: .medium, position: 0),
                DashboardTile(id: UUID().uuidString, type: .powerFlow, size: .medium, position: 1),
                DashboardTile(id: UUID().uuidString, type: .devices, size: .medium, position: 2)
            ]
            return
        }
        tiles = decoded
    }
    
    /// Save tiles to storage
    private func saveTiles() {
        guard let encoded = try? JSONEncoder().encode(tiles) else { return }
        tilesData = encoded
    }
    
    /// Remove a tile
    private func removeTile(_ tile: DashboardTile) {
        tiles.removeAll { $0.id == tile.id }
        // Recalculate positions
        for (index, tile) in tiles.enumerated() {
            var mutableTile = tile
            mutableTile.position = index
            tiles[index] = mutableTile
        }
    }
    
    /// Handle drop of tiles
    private func handleDrop(ids: [String], onto targetTile: DashboardTile) -> Bool {
        // Find the tile being dropped
        guard let droppedId = ids.first,
              let droppedTile = self.tiles.first(where: { $0.id == droppedId }) else {
            return false
        }
        
        // Reorder using TileOrder
        self.tiles = TileOrder.move(self.tiles, moving: droppedTile, onto: targetTile)
        
        // Update positions
        for (index, tile) in self.tiles.enumerated() {
            var mutableTile = tile
            mutableTile.position = index
            self.tiles[index] = mutableTile
        }
        
        return true
    }
}

/// System overview view for the dashboard
private struct SystemOverviewView: View {
    @ObservedObject var store: LiveDataStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("System Overview")
                .font(.headline)
            
            HStack(spacing: 32) {
                // SoC
                VStack(alignment: .leading, spacing: 8) {
                    Text("State of Charge")
                        .font(.subheadline)
                        .foregroundStyle(OffgridTheme.textSecondary)
                    
                    if let soc = store.system.batterySoc {
                        let formatted = MetricFormat.percent(soc)
                        Text(formatted.value)
                            .font(OffgridTheme.numberFont(size: 32))
                            .foregroundColor(OffgridTheme.textPrimary)
                    } else {
                        Text("–")
                            .font(OffgridTheme.numberFont(size: 32))
                            .foregroundColor(OffgridTheme.textPrimary)
                    }
                }
                
                // PV Power
                VStack(alignment: .leading, spacing: 8) {
                    Text("Solar Input")
                        .font(.subheadline)
                        .foregroundStyle(OffgridTheme.textSecondary)
                    
                    if let power = store.system.pvPower {
                        let formatted = MetricFormat.watts(power)
                        Text(formatted.value)
                            .font(OffgridTheme.numberFont(size: 32))
                            .foregroundColor(OffgridTheme.solar)
                    } else {
                        Text("–")
                            .font(OffgridTheme.numberFont(size: 32))
                            .foregroundColor(OffgridTheme.solar)
                    }
                }
            }
            
            // Time to Go
            VStack(alignment: .leading, spacing: 8) {
                Text("Time to Go")
                    .font(.subheadline)
                    .foregroundStyle(OffgridTheme.textSecondary)
                
                if let timeToGo = store.system.timeToGo, timeToGo > 0 {
                    Text(TimeFormatter.formatTimeToGo(timeToGo))
                        .font(OffgridTheme.numberFont(size: 24))
                        .foregroundColor(OffgridTheme.textPrimary)
                } else {
                    Text("–")
                        .font(OffgridTheme.numberFont(size: 24))
                        .foregroundColor(OffgridTheme.textPrimary)
                }
            }
        }
    }
}

// MARK: - Array Extension
private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}

// Preview for Xcode
#if DEBUG
struct DashboardScreen_Previews: PreviewProvider {
    static var previews: some View {
        let store = populateStoreWithSampleData()
        
        Group {
            DashboardScreen(store: store)
                .previewDisplayName("Light Mode")
            DashboardScreen(store: store)
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
            (topic: "N/c0ffee000001/solarcharger/278/ProductName", payload: ["value": "MPPT 150/70"]),
            (topic: "N/c0ffee000001/solarcharger/278/State", payload: ["value": 5]),
            (topic: "N/c0ffee000001/vebus/276/ProductName", payload: ["value": "MultiPlus-II 48/5000"]),
            (topic: "N/c0ffee000001/vebus/276/State", payload: ["value": 9])
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
