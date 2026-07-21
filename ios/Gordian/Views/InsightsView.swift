// LOGS tab — history + stats. Redesigned per design tickets #9/#10/#11:
// honest stats (no legendless chart), question-first cards with the decision line,
// analysis behind a tap, native swipe-to-delete.

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
                Text("No sessions yet.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                Spacer().frame(height: 8)
                Text("Run a 60-second session and your decisions will collect here.")
                    .font(.footnote)
                    .foregroundColor(.textMuted)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(24)
        } else {
            let total = decisions.count
            let split = decisions.filter { $0.choice == "REFLECT" }.count
            let decided = total - split
            let acted = decisions.filter { $0.actedOn == "acted" }.count

            List {
                Section {
                    HStack {
                        statColumn("Sessions", "\(total)", .white)
                        Spacer()
                        statColumn("Decided", "\(decided)", .goldPrimary)
                        Spacer()
                        statColumn("Acted on", "\(acted)", .goldAccent)
                        Spacer()
                        statColumn("Split", "\(split)", .textMuted)
                    }
                    .padding(20)
                    .gordianCard()
                    .listRowStyleGordian()
                } header: {
                    SectionLabel(text: "STATS", tracking: 1)
                        .padding(.leading, 24)
                }

                Section {
                    ForEach(decisions) { decision in
                        DecisionCard(decision: decision)
                            .listRowStyleGordian()
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.deleteDecision(decision)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    SectionLabel(text: "HISTORY", color: .textMuted, tracking: 1)
                        .padding(.leading, 24)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.darkBackground)
        }
    }

    private func statColumn(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.caption)
                .foregroundColor(.textMuted)
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
        }
    }
}

private extension View {
    func listRowStyleGordian() -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 24, bottom: 6, trailing: 24))
    }
}

struct DecisionCard: View {
    let decision: DecisionLog
    @Environment(\.modelContext) private var modelContext
    @State private var expanded = false

    private var outcomeLabel: String {
        decision.choice == "REFLECT" ? "SPLIT" : decision.choice.uppercased()
    }

    private var outcomeColor: Color {
        decision.choice == "REFLECT" ? .textMuted : .goldPrimary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text("\u{201C}\(decision.question)\u{201D}")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(3)
                Spacer()
                Text(outcomeLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(outcomeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 8).fill(outcomeColor.opacity(0.15)))
            }

            if !decision.displayDecision.isEmpty {
                Text(decision.displayDecision)
                    .font(.footnote.weight(.bold))
                    .foregroundColor(.goldPrimary)
            }

            HStack {
                Text(decision.timestamp.formatted(.dateTime.month(.abbreviated).day().hour(.defaultDigits(amPM: .abbreviated)).minute()))
                Text("·")
                Text(decision.reflection)
                if decision.actedOn == "acted" {
                    Text("·")
                    Label("Acted on", systemImage: "checkmark")
                        .foregroundColor(.goldPrimary)
                } else if decision.actedOn == "not_acted" {
                    Text("·")
                    Text("Not yet")
                }
                Spacer()
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
            }
            .font(.caption)
            .foregroundColor(.textMuted)

            if expanded {
                Divider().background(Color.white.opacity(0.05))
                Text(decision.displayAnalysis)
                    .font(.footnote)
                    .lineSpacing(3)
                    .foregroundColor(.textMuted)

                // Close the loop in-app too, not just from the notification
                if decision.actedOn != "acted", decision.choice != "REFLECT" {
                    HStack(spacing: 10) {
                        Text("Did you act on it?")
                            .font(.footnote)
                            .foregroundColor(.textLight)
                        Spacer()
                        actedButton("Not yet", value: "not_acted", filled: false)
                        actedButton("I did", value: "acted", filled: true)
                    }
                }
            }
        }
        .padding(16)
        .gordianCard(cornerRadius: 20)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
        }
        .accessibilityLabel("Session: \(decision.question). Outcome: \(outcomeLabel).")
    }

    private func actedButton(_ label: String, value: String, filled: Bool) -> some View {
        Button {
            decision.actedOn = value
            try? modelContext.save()
            if value == "acted" {
                FollowUpManager.shared.cancelFollowUp(id: decision.followUpID)
            }
        } label: {
            Text(label)
                .font(.footnote.weight(.bold))
                .foregroundColor(filled ? .black : .goldPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(filled ? Color.goldPrimary : Color.darkSurfaceVariant))
                .overlay(Capsule().stroke(Color.goldPrimary.opacity(filled ? 0 : 0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
