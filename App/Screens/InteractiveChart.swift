//
// InteractiveChart.swift
//
// Enhanced chart with pinch-to-zoom, drag-to-pan, scrub crosshair, and min/max/avg bands
//

import SwiftUI
import Charts
import VictronKit

/// Enhanced chart with interactive gestures and statistical overlays
public struct InteractiveChart: View {
    @ObservedObject var recorder: LiveSeriesRecorder
    let timeRange: TimeRange
    let series: LiveSeries
    let seriesName: String
    let color: Color
    let showStats: Bool

    // Gesture state
    @State private var chartSelection: Date?
    @State private var gestureStartLength: TimeInterval? = nil
    @State private var panOffset: CGFloat = 0
    @State private var isZooming = false

    // Chart domain
    @State private var visibleDomainLength: TimeInterval = 300.0 // 5 minutes

    public init(recorder: LiveSeriesRecorder, timeRange: TimeRange, series: LiveSeries, seriesName: String, color: Color, showStats: Bool = true) {
        self.recorder = recorder
        self.timeRange = timeRange
        self.series = series
        self.seriesName = seriesName
        self.color = color
        self.showStats = showStats
    }

    public var body: some View {
        Chart {
            // Main data line
            ForEach(getSamples(), id: \.timestamp) { sample in
                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("Value", sample.value)
                )
                .foregroundStyle(color)
                .interpolationMethod(.catmullRom)
            }

            // Show selection crosshair
            if let selection = chartSelection {
                RuleMark(x: .value("Selection", selection))
                    .foregroundStyle(OffgridTheme.textSecondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))

                // Show value at selection point
                if let selectedValue = getValue(at: selection) {
                    PointMark(
                        x: .value("Selection", selection),
                        y: .value("Value", selectedValue)
                    )
                    .foregroundStyle(color)
                    .symbolSize(60)
                }
            }

            // Show min/max/avg bands if enabled
            if showStats, let window = getRollingWindow() {
                if let minValue = window.min, let maxValue = window.max {
                    // Min/Max reference lines
                    let samples = window.samples
                    if let firstTimestamp = samples.first?.timestamp,
                       let lastTimestamp = samples.last?.timestamp {
                        // Min reference line (start and end points)
                        LineMark(
                            x: .value("Min", firstTimestamp),
                            y: .value("Min", minValue)
                        )
                        .foregroundStyle(color.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        
                        LineMark(
                            x: .value("Min", lastTimestamp),
                            y: .value("Min", minValue)
                        )
                        .foregroundStyle(color.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        
                        // Max reference line (start and end points)
                        LineMark(
                            x: .value("Max", firstTimestamp),
                            y: .value("Max", maxValue)
                        )
                        .foregroundStyle(color.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        
                        LineMark(
                            x: .value("Max", lastTimestamp),
                            y: .value("Max", maxValue)
                        )
                        .foregroundStyle(color.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                    }
                }

                if let avgValue = window.avg {
                    // Average line (dashed) spanning the entire time range
                    let samples = window.samples
                    if let firstTimestamp = samples.first?.timestamp,
                       let lastTimestamp = samples.last?.timestamp {
                        // Start point
                        LineMark(
                            x: .value("Average", firstTimestamp),
                            y: .value("Avg", avgValue)
                        )
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                        
                        // End point
                        LineMark(
                            x: .value("Average", lastTimestamp),
                            y: .value("Avg", avgValue)
                        )
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    }
                }
            }
        }
        .chartXScale(domain: getXDomain())
        .chartXVisibleDomain(length: visibleDomainLength)
        .chartScrollableAxes(.horizontal)
        .chartXSelection(value: $chartSelection)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(OffgridTheme.background).contentShape(Rectangle())
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                isZooming = true
                                let start = gestureStartLength ?? visibleDomainLength
                                gestureStartLength = start
                                
                                // Convert to time interval based on current visible range
                                let timeRange = timeRange.getWindow(for: recorder, series: series)
                                let samples = timeRange.samples
                                
                                if !samples.isEmpty {
                                    let timeSpan = samples.last!.timestamp.timeIntervalSince(samples.first!.timestamp)
                                    let minLength: TimeInterval = max(60.0, timeSpan / 20.0) // Minimum 1 minute
                                    let maxLength: TimeInterval = max(timeSpan, 3600.0) // Maximum 1 hour
                                    
                                    visibleDomainLength = ChartZoom.visibleLength(start: start, magnification: value.magnification, min: minLength, max: maxLength)
                                }
                            }
                            .onEnded { _ in
                                gestureStartLength = nil
                                isZooming = false
                            }
                    )
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic)
        }
        .chartYAxis {
            AxisMarks(values: .automatic)
        }
        .onChange(of: timeRange) { oldRange, newRange in
            // Reset zoom when time range changes
            visibleDomainLength = newRange == .fiveMinutes ? 300.0 : 3600.0
        }
        .onAppear {
            // Set initial visible domain length based on time range
            visibleDomainLength = timeRange == .fiveMinutes ? 300.0 : 3600.0
        }
        .overlay(alignment: .top) {
            // Crosshair readout
            if let selection = chartSelection, let value = getValue(at: selection) {
                CrosshairReadout(selection: selection, value: value)
                    .padding(.top, 8)
            }
        }
    }

    private func getSamples() -> [Sample] {
        let window = timeRange.getWindow(for: recorder, series: series)
        return window.samples.filter { $0.value >= 0 }
    }

    private func getRollingWindow() -> RollingWindow? {
        let window = timeRange.getWindow(for: recorder, series: series)
        return window.samples.isEmpty ? nil : window
    }

    private func getValue(at date: Date) -> Double? {
        let samples = getSamples()
        guard !samples.isEmpty else { return nil }
        
        // Find the closest sample to the selection date
        let sortedSamples = samples.sorted { $0.timestamp < $1.timestamp }
        
        if sortedSamples.count == 1 {
            return sortedSamples[0].value
        }
        
        // Binary search for the closest sample
        var left = 0
        var right = sortedSamples.count - 1
        
        while left <= right {
            let mid = (left + right) / 2
            let midDate = sortedSamples[mid].timestamp
            
            if midDate == date {
                return sortedSamples[mid].value
            } else if midDate < date {
                left = mid + 1
            } else {
                right = mid - 1
            }
        }
        
        // Return the closest sample
        if left == 0 {
            return sortedSamples[0].value
        } else if left >= sortedSamples.count {
            return sortedSamples.last?.value
        } else {
            let prev = sortedSamples[left - 1]
            let next = sortedSamples[left]
            
            // Return the closer one
            let prevDiff = date.timeIntervalSince(prev.timestamp)
            let nextDiff = next.timestamp.timeIntervalSince(date)
            
            return prevDiff < nextDiff ? prev.value : next.value
        }
    }

    private func getXDomain() -> ClosedRange<Date> {
        let samples = getSamples()
        guard !samples.isEmpty else {
            let now = Date()
            let fiveMinutesAgo = Calendar.current.date(byAdding: .minute, value: -5, to: now) ?? now
            return fiveMinutesAgo ... now
        }
        
        let now = Date()
        return samples.first!.timestamp ... now
    }
}

/// Crosshair readout showing time and value
private struct CrosshairReadout: View {
    let selection: Date
    let value: Double

    var body: some View {
        VStack {
            Text("Time: \(selection.formatted(date: .omitted, time: .standard))")
            Text("Value: \(String(format: "%.1f", value))")
        }
        .font(OffgridTheme.numberFont(size: 12))
        .padding(8)
        .background(OffgridTheme.surface)
        .foregroundStyle(OffgridTheme.textPrimary)
        .cornerRadius(OffgridTheme.tileRadius)
    }
}
