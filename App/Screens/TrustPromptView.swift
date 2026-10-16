//
// TrustPromptView.swift
//
// Trust-on-first-use certificate pinning prompt
//

import SwiftUI
import VictronKit

struct TrustPromptView: View {
    let host: String
    let port: Int
    let fingerprint: String
    let onTrust: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 40))
                .foregroundColor(OffgridTheme.warning)
                .padding(.bottom, 8)

            Text("Trust this Cerbo?")
                .font(.headline)
                .padding(.bottom, 4)

            Text("The certificate for this connection is not yet trusted.")
                .font(.subheadline)
                .foregroundColor(OffgridTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 4) {
                Text("Host:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(host):\(port)")
                    .font(.body)
                    .monospaced()

                Text("Certificate fingerprint:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                Text(formatFingerprint(forDisplay: fingerprint))
                    .font(.body)
                    .monospaced()
                    .padding(.top, 4)
            }
            .padding()
            .background(OffgridTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: OffgridTheme.tileRadius))

            HStack(spacing: 20) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.bordered)

                Button(action: onTrust) {
                    Text("Trust")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: 400)
        .background(OffgridTheme.background)
    }
}
