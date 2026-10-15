import SwiftUI
import Charts

public struct ChartCard: View {
    let title: String
    let legend: String

    public init(title: String, legend: String) {
        self.title = title
        self.legend = legend
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 17))
                .foregroundColor(OffgridTheme.textPrimary)
            Chart {
                // Placeholder chart data
                LineMark(
                    x: .value("Hour", 1),
                    y: .value("Solar", 100)
                )
                .foregroundStyle(OffgridTheme.solar)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .frame(height: 150)
            .padding(.bottom, 8)
            Text(legend)
                .font(.system(size: 13))
                .foregroundColor(OffgridTheme.textSecondary)
        }
        .padding(16)
        .background(OffgridTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: OffgridTheme.tileRadius))
    }
}

struct ChartCard_Previews: PreviewProvider {
    static var previews: some View {
        ChartCard(
            title: "Solar today",
            legend: "Solar production"
        )
    }
}
