//
// CSVDocument.swift
//
// Transferable document for sharing CSV data
//

import Foundation
import UniformTypeIdentifiers
import CoreTransferable

/// A document containing CSV data for sharing
public struct CSVDocument: Transferable {
    /// The filename for the CSV file
    public let filename: String
    
    /// The CSV text content
    public let text: String
    
    /// Initialize a new CSVDocument
    /// - Parameters:
    ///   - filename: The filename for the CSV file
    ///   - text: The CSV text content
    public init(filename: String, text: String) {
        self.filename = filename
        self.text = text
    }
    
    /// Create a CSVDocument for live chart data
    /// - Parameters:
    ///   - recorder: The live series recorder
    ///   - timeRange: The time range to export
    ///   - now: The current date/time (for testing)
    /// - Returns: A CSVDocument containing the live chart data
    public static func live(recorder: LiveSeriesRecorder, timeRange: TimeRange, now: Date = Date()) -> CSVDocument {
        // Build series data for all LiveSeries
        var series: [(name: String, unit: String, samples: [Sample])] = []
        
        for liveSeries in LiveSeries.allCases {
            let window = timeRange.getWindow(for: recorder, series: liveSeries)
            let name = liveSeries.rawValue
            let unit: String
            
            // Determine unit based on series type
            if liveSeries == .batterySoc {
                unit = "%"
            } else {
                unit = "W"
            }
            
            series.append((name: name, unit: unit, samples: window.samples))
        }
        
        let csvText = CSVExporter.csv(series: series)
        let filename = "cerbo-live-" + timeRange.rawValue + ".csv"
        
        return CSVDocument(filename: filename, text: csvText)
    }
    
    /// Create a CSVDocument for history data
    /// - Parameter days: Array of solar day records
    /// - Returns: A CSVDocument containing the history data
    public static func history(_ days: [SolarDayRecord]) -> CSVDocument {
        let csvText = CSVExporter.csv(solarDays: days)
        let filename = "cerbo-history.csv"
        
        return CSVDocument(filename: filename, text: csvText)
    }
    
    /// The data representation for sharing
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { csvDocument in
            Data(csvDocument.text.utf8)
        }
        .suggestedFileName { $0.filename }
    }


}
