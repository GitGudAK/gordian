// INSIGHTS tab — port of InsightsTabScreen (gut analytics + decision chronology)

import SwiftUI
import SwiftData

struct InsightsView: View {
    var viewModel: SessionViewModel
    @Query(sort: \DecisionLog.timestamp, order: .reverse) private var decisions: [DecisionLog]

    var body: some View {
        if decisions.isEmpty {
            VStack(spacing: 0) {
                Spacer()
                Image(systemName: "chart.bar")
                    .font(.system(size: 60))
                    .foregroundColor(.textMuted.opacity(0.5))
                Spacer().frame(height: 16)
                Text("No decisions logged yet.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                Spacer().frame(height: 8)
                Text("Run a 60-second Gordian decision-making simulation to populate insights and bypass cognitive overload.")
                    .font(.system(size: 12))
                    .foregroundColor(.textMuted)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(24)
        } else {
            let total = decisions.count
            let yesCount = decisions.filter { $0.choice == "YES" }.count
            let noCount = decisions.filter { $0.choice == "NO" }.count
            let reflectCount = decisions.filter { $0.choice == "REFLECT" }.count
            let topSentiment = Dictionary(grouping: decisions, by: \.sentiment)
                .max { $0.value.count < $1.value.count }?.key ?? "UNSURE"

            ScrollView {
                VStack(spacing: 16) {
                    // Stats card
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(text: "GUT ANALYTICS", tracking: 1)

                        HStack {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Total Runs")
                                    .font(.system(size: 11))
                                    .foregroundColor(.textMuted)
                                Text("\(total)")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Yes / No Split")
                                    .font(.system(size: 11))
                                    .foregroundColor(.textMuted)
                                Text("\(yesCount) / \(noCount)")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Dominant Gut State")
                                    .font(.system(size: 11))
                                    .foregroundColor(.textMuted)
                                Text(topSentiment)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.goldPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                        }

                        // Distribution bar
                        GeometryReader { geo in
                            HStack(spacing: 0) {
                                Rectangle().fill(Color.goldPrimary)
                                    .frame(width: geo.size.width * CGFloat(yesCount) / CGFloat(total))
                                Rectangle().fill(Color.redAccent)
                                    .frame(width: geo.size.width * CGFloat(noCount) / CGFloat(total))
                                Rectangle().fill(Color.white.opacity(0.3))
                                    .frame(width: geo.size.width * CGFloat(reflectCount) / CGFloat(total))
                                Rectangle().fill(Color.darkSurfaceVariant)
                            }
                        }
                        .frame(height: 8)
                        .clipShape(Capsule())
                    }
                    .padding(20)
                    .gordianCard()

                    SectionLabel(text: "DECISION CHRONOLOGY", color: .textMuted, tracking: 1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(decisions) { decision in
                        DecisionCard(decision: decision) {
                            viewModel.deleteDecision(decision)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

struct DecisionCard: View {
    let decision: DecisionLog
    let onDelete: () -> Void

    private var choiceColor: Color {
        switch decision.choice {
        case "YES": return .goldPrimary
        case "NO": return .redAccent
        default: return .white
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel(text: decision.simulationTitle.uppercased(), size: 10, tracking: 1)
                    Text(decision.timestamp.formatted(.dateTime.month(.abbreviated).day().hour(.defaultDigits(amPM: .abbreviated)).minute()))
                        .font(.system(size: 10))
                        .foregroundColor(.textMuted)
                }

                Spacer()

                Text(decision.choice)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(choiceColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 8)
                        .fill(decision.choice == "REFLECT" ? Color.white.opacity(0.1) : choiceColor.opacity(0.15)))

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(.textMuted)
                }
            }

            Text("\u{201C}\(decision.question)\u{201D}")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)

            if !decision.reflection.isEmpty && decision.reflection != "None" {
                Text("Reflected: \(decision.reflection)")
                    .font(.system(size: 11).italic())
                    .foregroundColor(.textLight)
            }

            Divider().background(Color.white.opacity(0.05))

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 13))
                    .foregroundColor(.goldPrimary)
                Text(decision.aiAnalysis)
                    .font(.system(size: 11))
                    .lineSpacing(3)
                    .foregroundColor(.textMuted)
            }
        }
        .padding(16)
        .gordianCard(cornerRadius: 20)
    }
}
