import SwiftUI

public struct MetricTile: View {
    let icon: String
    let value: String
    let unit: String
    let label: String
    let tint: Color?

    public init(icon: String, value: String, unit: String, label: String, tint: Color? = nil) {
        self.icon = icon
        self.value = value
        self.unit = unit
        self.label = label
        self.tint = tint
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(tint ?? OffgridTheme.textPrimary)
                Text(label)
                    .font(.system(size: 15))
                    .foregroundColor(OffgridTheme.textSecondary)
            }
            Spacer()
            HStack(alignment: .bottom, spacing: 4) {
                Text(value)
                    .font(OffgridTheme.numberFont(size: 30))
                    .foregroundColor(OffgridTheme.textPrimary)
                Text(unit)
                    .font(.system(size: 16))
                    .foregroundColor(OffgridTheme.textSecondary)
            }
        }
        .padding(16)
        .background(OffgridTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: OffgridTheme.tileRadius))
    }
}

struct MetricTile_Previews: PreviewProvider {
    static var previews: some View {
        MetricTile(
            icon: "sun.max",
            value: "1,250",
            unit: "W",
            label: "Solar",
            tint: OffgridTheme.solar
        )
    }
}
