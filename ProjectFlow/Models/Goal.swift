import Foundation
import SwiftData

@Model
final class Goal {
    var title: String
    var targetHours: Double
    var periodRaw: String
    var createdAt: Date
    var isActive: Bool

    init(title: String, targetHours: Double, period: GoalPeriod, isActive: Bool = true) {
        self.title = title
        self.targetHours = targetHours
        self.periodRaw = period.rawValue
        self.createdAt = Date()
        self.isActive = isActive
    }

    var period: GoalPeriod {
        get { GoalPeriod(rawValue: periodRaw) ?? .daily }
        set { periodRaw = newValue.rawValue }
    }
}
