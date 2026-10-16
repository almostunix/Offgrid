//
// LocalNetworkDeniedView.swift
//

import SwiftUI
import VictronKit

struct LocalNetworkDeniedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "network.slash")
                .font(.system(size: 60))
                .foregroundColor(OffgridTheme.textSecondary)
                .padding(.top, 40)

            Text("Offgrid can't search your network.")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("Turn on Local Network for Offgrid in Settings > Privacy & Security > Local Network.")
                .font(.subheadline)
                .foregroundColor(OffgridTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }) {
                Text("Open Settings")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 20)
            .background(OffgridTheme.background)
            }
    }
}

struct LocalNetworkDeniedView_Previews: PreviewProvider {
    static var previews: some View {
        LocalNetworkDeniedView()
    }
}
