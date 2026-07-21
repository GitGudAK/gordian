// Domain models — port of MainViewModel data types and data/DecisionDatabase.kt

import Foundation
import SwiftData
import SwiftUI

enum ActiveTab {
    case focus, insights, calibrate
}

enum FocusScreenState {
    case home, preparing, activeSession, verdict
}

// How the session's two answer buttons are labeled: NO/YES, or the dilemma's own options
enum AnswerMode: Equatable {
    case yesNo
    case binary(String, String)

    var leftLabel: String {
        switch self {
        case .yesNo: return "No"
        case .binary(let a, _): return a
        }
    }

    var rightLabel: String {
        switch self {
        case .yesNo: return "Yes"
        case .binary(_, let b): return b
        }
    }
}

struct SimulationTopic {
    let title: String
    let description: String
    let defaultQuestions: [String]
}

struct RapidFireAnswer {
    let question: String
    let choice: String
    let reflectionText: String
}

// Room's DecisionLog entity → SwiftData model (same fields, same semantics)
@Model
final class DecisionLog {
    var simulationTitle: String
    var question: String
    var choice: String
    var sentiment: String
    var reflection: String
    var aiAnalysis: String
    var timestamp: Date

    init(simulationTitle: String, question: String, choice: String, sentiment: String,
         reflection: String, aiAnalysis: String, timestamp: Date = Date()) {
        self.simulationTitle = simulationTitle
        self.question = question
        self.choice = choice
        self.sentiment = sentiment
        self.reflection = reflection
        self.aiAnalysis = aiAnalysis
        self.timestamp = timestamp
    }
}

// Curated guides shown on the Calibrate tab (port of CalibrateTabScreen's DecisionGuide list)
struct DecisionGuide: Identifiable {
    let id: Int
    let title: String
    let description: String
    let origin: String
    let readTime: String
    let fullContent: String
    let coreTakeaway: String
    let systemImage: String

    static let all: [DecisionGuide] = [
        DecisionGuide(
            id: 1,
            title: "The Gordian Cut",
            description: "Decisive bold actions that render complex deliberations completely irrelevant.",
            origin: "Ancient Greek Strategy",
            readTime: "2 min read",
            fullContent: "In 333 BC, Alexander the Great confronted the Gordian Knot—an incredibly complex tangle of cornel-bark rope. Ancient prophecy held that whoever untied it would rule Asia. Instead of spending days trying to carefully loosen the knot, Alexander drew his sword and slashed through it with a single stroke.\n\nIn psychology, a 'Gordian Cut' is any decisive, bold action that renders the entire complex problem irrelevant. When stuck in decision loops, we often over-analyze variables that don't matter. \n\nHow to apply it:\n1. Identify the single variable holding you back.\n2. Ask: 'What is the most direct, irreversible action that makes this whole debate unnecessary?'\n3. Execute that action with absolute confidence, accepting that perfection is an illusion.",
            coreTakeaway: "Don't untangle the knot when you can simply slice it in half.",
            systemImage: "scissors"
        ),
        DecisionGuide(
            id: 2,
            title: "The 10/10/10 Rule",
            description: "A powerful heuristic to bypass short-term panic and focus on future consequence.",
            origin: "Suzy Welch (Cognitive Psychology)",
            readTime: "3 min read",
            fullContent: "Our analytical brains are easily hijacked by near-term emotional anxiety. The fear of failure, social rejection, or temporary discomfort makes any decision feel like life or death. The 10/10/10 rule forces immediate cognitive distance.\n\nTo use this framework, look at your primary choice and ask three simple questions:\n1. How will I feel about this choice 10 minutes from now?\n2. How will I feel about it 10 months from now?\n3. How will I feel about it 10 years from now?\n\nTypically, what feels like an agonizingly difficult choice today is completely forgotten in ten months, let alone ten years. This perspective immediately lowers your cortisol levels and allows your gut instinct to speak clearly.",
            coreTakeaway: "Immediate pain is temporary. Future clarity is permanent.",
            systemImage: "clock.arrow.2.circlepath"
        ),
        DecisionGuide(
            id: 3,
            title: "Regret Minimization",
            description: "Aligning your choices with your future elderly self to eliminate fear of failure.",
            origin: "Jeff Bezos (Decisional Architecture)",
            readTime: "2 min read",
            fullContent: "When deciding whether to quit a secure wall street job to start Amazon, Jeff Bezos formulated the Regret Minimization Framework. He projected himself forward to age 80 and looked back on his life.\n\nAt age 80, he realized he wouldn't regret trying and failing to build a startup. But he would absolutely regret never trying at all. That realization instantly bypassed all the complex calculations about short-term compensation, career stability, and business risk.\n\nHow to apply it:\nImagine you are 80 years old, looking back. Which path will you regret not taking? Choose that path.",
            coreTakeaway: "We rarely regret bold failures. We always regret safe inactions.",
            systemImage: "leaf.fill"
        ),
        DecisionGuide(
            id: 4,
            title: "Two-Way Door Principle",
            description: "Speed up decisions by separating irreversible actions from reversible ones.",
            origin: "Type 1 vs. Type 2 Decisions",
            readTime: "3 min read",
            fullContent: "Decisional paralysis often occurs because we treat every decision as a monumental, permanent event. In reality, decisions fall into two categories:\n\nType 1 (One-Way Doors): These decisions are nearly irreversible. If you walk through, you cannot return. Examples: selling a company, signing a long-term commercial lease, or getting a tattoo. These should be made slowly, deliberately, with counsel.\n\nType 2 (Two-Way Doors): These are easily reversible. If you don't like the outcome, you can walk back through the door. Examples: changing a pricing tier, launching a pilot feature, or hiring a contractor. These should be made as rapidly as possible, often with only 70% of the desired information.\n\nBypass rule: If it's a two-way door, stop thinking and ship it immediately. Fail fast and iterate.",
            coreTakeaway: "If you can walk back, don't stand at the door over-thinking.",
            systemImage: "door.left.hand.open"
        )
    ]
}
