//
// TopicExplorerScreen.swift
//
// Searchable list of all received MQTT topics with raw values and timestamps for diagnostics.
//

import SwiftUI
import VictronKit

/// Topic explorer screen showing all received MQTT topics
public struct TopicExplorerScreen: View {
    /// The live data store providing real-time data
    @ObservedObject public var store: LiveDataStore
    
    /// Search text for filtering topics
    @State private var searchText = ""
    
    // Initialize with data store
    public init(store: LiveDataStore) {
        self.store = store
    }
    
    public var body: some View {
        List {
            ForEach(filteredTopics, id: \.id) { topic in
                TopicRowView(topic: topic)
            }
            
            if filteredTopics.isEmpty && !searchText.isEmpty {
                Text("No topics match your search")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .searchSuggestions({})
        .navigationTitle("Topic Explorer")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    /// Filtered topics based on search text
    private var filteredTopics: [ReceivedTopic] {
        if searchText.isEmpty {
            return store.receivedTopics
        } else {
            return store.receivedTopics.filter { topic in
                topic.topic.localizedCaseInsensitiveContains(searchText) ||
                topic.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

/// Individual topic row view
private struct TopicRowView: View {
    let topic: ReceivedTopic
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Topic name
            Text(topic.topic)
                .font(.subheadline)
                .lineLimit(1)
            
            // Raw value
            Text(topic.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            
            // Timestamp
            Text(topic.timestamp.formatted())
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }
}

// Preview for Xcode
#if DEBUG
struct TopicExplorerScreen_Previews: PreviewProvider {
    static var previews: some View {
        let store = populateStoreWithSampleData()
        
        Group {
            TopicExplorerScreen(store: store)
                .previewDisplayName("Light Mode")
            TopicExplorerScreen(store: store)
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
            (topic: "N/c0ffee000001/battery/279/ProductName", payload: ["value": "SmartShunt 500A"]),
            (topic: "N/c0ffee000001/solarcharger/278/State", payload: ["value": 5]),
            (topic: "N/c0ffee000001/vebus/276/ProductName", payload: ["value": "MultiPlus-II 48/5000"])
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
