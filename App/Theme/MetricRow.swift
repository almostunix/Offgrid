import SwiftUI

public struct MetricRow: View {
    let icon: String
    let label: String
    let value: String
    let unit: String

    public init(icon: String, label: String, value: String, unit: String) {
        self.icon = icon
        self.label = label
        self.value = value
        self.unit = unit
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(OffgridTheme.textSecondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(OffgridTheme.textSecondary)
                HStack(spacing: 4) {
                    Text(value)
                        .font(OffgridTheme.numberFont(size: 17))
                        .foregroundColor(OffgridTheme.textPrimary)
                    Text(unit)
                        .font(.system(size: 15))
                        .foregroundColor(OffgridTheme.textSecondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(OffgridTheme.surface)
        .overlay(
            Divider()
                .frame(height: 1)
                .background(OffgridTheme.hairline)
                .padding(.leading, 52),
            alignment: .bottom
        )
    }
}

struct MetricRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            MetricRow(
                icon: "house",
                label: "Home loads",
                value: "1,250",
                unit: "W"
            )
            MetricRow(
                icon: "bolt",
                label: "Battery",
                value: "50",
                unit: "%"
            )
        }
    }
}
