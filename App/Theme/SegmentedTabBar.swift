import SwiftUI

public struct SegmentedTabBar: View {
    let tabs: [String]
    let selectedIndex: Int
    let onSelect: (Int) -> Void

    public init(tabs: [String], selectedIndex: Int, onSelect: @escaping (Int) -> Void) {
        self.tabs = tabs
        self.selectedIndex = selectedIndex
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: {
                    onSelect(index)
                }) {
                    Text(tabs[index])
                        .font(.system(size: 15))
                        .foregroundColor(selectedIndex == index ? OffgridTheme.textPrimary : OffgridTheme.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .background(
                    selectedIndex == index ? OffgridTheme.surfaceRaised : OffgridTheme.surface
                )
                .clipShape(Capsule())
            }
        }
    }
}

struct SegmentedTabBar_Previews: PreviewProvider {
    static var previews: some View {
        SegmentedTabBar(
            tabs: ["Overview", "Flow", "Devices", "History"],
            selectedIndex: 0,
            onSelect: { _ in }
        )
    }
}
