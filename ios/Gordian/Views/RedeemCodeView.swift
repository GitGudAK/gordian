// Gordian-styled code redemption. We own the entry UX; the App Store owns the
// transaction: the code is carried (or clipboard-copied) to Apple's redeem
// page, which accepts BOTH subscription offer codes and promo codes — one flow
// for every kind of gift. Entitlements refresh automatically on return via
// Transaction.updates.

import SwiftUI

struct RedeemCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""

    /// Set when the App Store record exists; enables the prefilled redeem link.
    static let appStoreID: String? = nil

    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Capsule()
                    .fill(Color.darkSurfaceVariant)
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)

                Spacer()

                KnotGlyph(color: .goldPrimary)
                    .frame(width: 48, height: 48)

                Text("REDEEM A CODE")
                    .font(.system(size: 18, weight: .heavy))
                    .tracking(2)
                    .foregroundColor(.textLight)

                Text("Enter the code you were given. You'll finish in the App Store, and your access unlocks the moment it goes through.")
                    .font(.system(size: 13))
                    .foregroundColor(.textMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)

                TextField("GORDIAN-XXXX", text: $code)
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .foregroundColor(.goldPrimary)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.darkSurface))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.goldPrimary.opacity(code.isEmpty ? 0.25 : 0.6), lineWidth: 1))

                Button {
                    redeem()
                } label: {
                    Text("Continue in App Store")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(code.isEmpty ? .textMuted : .black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 16)
                            .fill(code.isEmpty ? Color.darkSurfaceVariant : Color.goldPrimary))
                }
                .disabled(code.isEmpty)

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 28)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    private func redeem() {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let url: URL
        if let id = Self.appStoreID {
            url = URL(string: "https://apps.apple.com/redeem?ctx=offercodes&id=\(id)&code=\(trimmed)")!
        } else {
            // No App Store record yet: copy the code and open the generic redeem page.
            UIPasteboard.general.string = trimmed
            url = URL(string: "https://apps.apple.com/redeem")!
        }
        UIApplication.shared.open(url)
        dismiss()
    }
}
