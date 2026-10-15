import SwiftUI

public struct BatteryRing: View {
    let soc: String
    let power: String
    let state: String

    public init(soc: String, power: String, state: String) {
        self.soc = soc
        self.power = power
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(OffgridTheme.surfaceRaised, lineWidth: 4)
                    .frame(width: 120, height: 120)
                Circle()
                    .trim(from: 0, to: CGFloat(Double(soc) ?? 0) / 100)
                    .stroke(OffgridTheme.battery, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                VStack {
                    Text(soc)
                        .font(OffgridTheme.numberFont(size: 30))
                        .foregroundColor(OffgridTheme.textPrimary)
                    Text("%")
                        .font(.system(size: 16))
                        .foregroundColor(OffgridTheme.textSecondary)
                }
            }
            HStack(spacing: 8) {
                Text(state)
                    .font(.system(size: 15))
                    .foregroundColor(OffgridTheme.textSecondary)
                Text(power)
                    .font(OffgridTheme.numberFont(size: 17))
                    .foregroundColor(OffgridTheme.textPrimary)
                Text("W")
                    .font(.system(size: 15))
                    .foregroundColor(OffgridTheme.textSecondary)
            }
        }
    }
}

struct BatteryRing_Previews: PreviewProvider {
    static var previews: some View {
        BatteryRing(
            soc: "85",
            power: "1,250",
            state: "Charging"
        )
    }
}
