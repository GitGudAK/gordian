// GUIDES/CALIBRATE tab — port of CalibrateTabScreen (decision guides + API key + purge)

import SwiftUI

struct CalibrateView: View {
    var viewModel: SessionViewModel
    @State private var expandedGuide: DecisionGuide?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let guide = expandedGuide {
                    guideDetail(guide)
                } else {
                    guideList
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-demoGuide") {
                expandedGuide = DecisionGuide.all[0]
            }
            #endif
        }
        .animation(.easeInOut(duration: 0.2), value: expandedGuide?.id)
    }

    // MARK: - Guide list

    private var guideList: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DECISION-MAKING GUIDES")
                    .font(.system(size: 20, weight: .heavy))
                    .tracking(2)
                    .foregroundColor(.goldPrimary)
                Text("Curated psychologist models and mental frameworks to bypass analytical loops and anxiety.")
                    .font(.system(size: 12))
                    .foregroundColor(.textMuted)
            }
            .padding(.vertical, 12)

            ForEach(DecisionGuide.all) { guide in
                Button {
                    expandedGuide = guide
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: guide.systemImage)
                            .font(.system(size: 17))
                            .foregroundColor(.goldPrimary)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.goldPrimary.opacity(0.1)))
                            .overlay(Circle().stroke(Color.goldPrimary.opacity(0.3), lineWidth: 1))

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(guide.title)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(guide.readTime)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.textMuted)
                            }
                            Text(guide.description)
                                .font(.system(size: 11))
                                .foregroundColor(.textMuted)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .padding(18)
                    .gordianCard(cornerRadius: 20)
                }
            }

        }
    }

    // MARK: - Guide detail

    private func guideDetail(_ guide: DecisionGuide) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                expandedGuide = nil
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                    Text("BACK TO METHODS")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                }
                .foregroundColor(.goldPrimary)
                .padding(.vertical, 4)
            }

            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: guide.origin.uppercased(), size: 10)
                Text(guide.title)
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundColor(.white)
                Text(guide.readTime)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.textMuted)
            }

            VStack(alignment: .leading, spacing: 16) {
                Text(guide.fullContent)
                    .font(.subheadline)
                    .lineSpacing(6)
                    .foregroundColor(.textLight)

                Divider().background(Color.white.opacity(0.05))

                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel(text: "CORE TAKEAWAY", size: 10, tracking: 1)
                    Text(guide.coreTakeaway)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.goldPrimary.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.goldPrimary.opacity(0.2), lineWidth: 1))
            }
            .padding(24)
            .gordianCard()

            Button {
                expandedGuide = nil
            } label: {
                Text("DONE")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.goldPrimary))
            }
        }
        .padding(.vertical, 12)
    }
}
