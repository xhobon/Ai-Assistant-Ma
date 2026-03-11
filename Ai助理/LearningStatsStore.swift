import Foundation
import SwiftUI

final class LearningStatsStore: ObservableObject {
    static let shared = LearningStatsStore()

    private let practiceSessionsKey = "practice_stats_sessions"
    private let practiceCorrectKey = "practice_stats_correct"
    private let practiceTotalKey = "practice_stats_total"
    private let learningMinutesKey = "learning_minutes_total"

    @Published private(set) var practiceSessions: Int
    @Published private(set) var practiceCorrect: Int
    @Published private(set) var practiceTotal: Int
    @Published private(set) var learningMinutes: Int

    private init() {
        practiceSessions = UserDefaults.standard.integer(forKey: practiceSessionsKey)
        practiceCorrect = UserDefaults.standard.integer(forKey: practiceCorrectKey)
        practiceTotal = UserDefaults.standard.integer(forKey: practiceTotalKey)
        learningMinutes = UserDefaults.standard.integer(forKey: learningMinutesKey)
    }

    var accuracy: Double {
        guard practiceTotal > 0 else { return 0 }
        return Double(practiceCorrect) / Double(practiceTotal)
    }

    func recordPracticeSession(correct: Int, total: Int, duration: TimeInterval) {
        practiceSessions += 1
        practiceCorrect += max(0, correct)
        practiceTotal += max(0, total)
        let minutes = Int(max(0, duration) / 60.0)
        learningMinutes += minutes
        persist()
    }

    func addLearningDuration(_ duration: TimeInterval) {
        let minutes = Int(max(0, duration) / 60.0)
        guard minutes > 0 else { return }
        learningMinutes += minutes
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(practiceSessions, forKey: practiceSessionsKey)
        UserDefaults.standard.set(practiceCorrect, forKey: practiceCorrectKey)
        UserDefaults.standard.set(practiceTotal, forKey: practiceTotalKey)
        UserDefaults.standard.set(learningMinutes, forKey: learningMinutesKey)
    }
}

enum DailyTaskType: String, CaseIterable {
    case learnWords
    case practice
    case review

    var id: String { rawValue }
}

struct DailyTask: Identifiable, Hashable {
    let id: String
    let type: DailyTaskType
    let titleKey: String
    let subtitleKey: String
    let targetCount: Int
    var isCompleted: Bool
}

final class DailyTaskStore: ObservableObject {
    static let shared = DailyTaskStore()

    private let completedKey = "daily_tasks_completed"
    private let learnedCountKey = "daily_tasks_learned_count"
    private let streakDatesKey = "learning_streak_dates"

    @Published private(set) var todayTasks: [DailyTask] = []

    private init() {
        refreshTasks(for: Date())
    }

    func refreshTasks(for date: Date) {
        let completed = completedTypes(for: date)
        todayTasks = DailyTaskType.allCases.map { type in
            let task = taskTemplate(for: type)
            return DailyTask(
                id: "\(type.rawValue)-\(dateKey(date))",
                type: type,
                titleKey: task.titleKey,
                subtitleKey: task.subtitleKey,
                targetCount: task.targetCount,
                isCompleted: completed.contains(type.rawValue)
            )
        }
    }

    func toggleTask(_ type: DailyTaskType, date: Date = Date()) {
        var completed = completedTypes(for: date)
        if completed.contains(type.rawValue) {
            completed.remove(type.rawValue)
        } else {
            completed.insert(type.rawValue)
        }
        saveCompletedTypes(completed, for: date)
        refreshTasks(for: date)
        updateStreakIfNeeded(for: date)
    }

    func markCompleted(_ type: DailyTaskType, date: Date = Date()) {
        var completed = completedTypes(for: date)
        guard !completed.contains(type.rawValue) else { return }
        completed.insert(type.rawValue)
        saveCompletedTypes(completed, for: date)
        refreshTasks(for: date)
        updateStreakIfNeeded(for: date)
    }

    func recordLearnedWord(date: Date = Date()) {
        let key = dateKey(date)
        var stored = UserDefaults.standard.dictionary(forKey: learnedCountKey) as? [String: Int] ?? [:]
        let count = (stored[key] ?? 0) + 1
        stored[key] = count
        UserDefaults.standard.set(stored, forKey: learnedCountKey)
        if count >= 10 {
            markCompleted(.learnWords, date: date)
        }
    }

    func currentStreakDays() -> Int {
        let dates = streakDates().sorted()
        guard !dates.isEmpty else { return 0 }
        let calendar = Calendar.current
        var streak = 0
        var current = calendar.startOfDay(for: Date())
        var index = dates.count - 1
        while index >= 0 {
            let date = dates[index]
            if calendar.isDate(date, inSameDayAs: current) {
                streak += 1
                current = calendar.date(byAdding: .day, value: -1, to: current) ?? current
                index -= 1
            } else {
                break
            }
        }
        return streak
    }

    private func updateStreakIfNeeded(for date: Date) {
        let completed = completedTypes(for: date)
        guard completed.count == DailyTaskType.allCases.count else { return }
        var dates = streakDates()
        let day = Calendar.current.startOfDay(for: date)
        if !dates.contains(where: { Calendar.current.isDate($0, inSameDayAs: day) }) {
            dates.append(day)
            saveStreakDates(dates)
        }
    }

    private func taskTemplate(for type: DailyTaskType) -> (titleKey: String, subtitleKey: String, targetCount: Int) {
        switch type {
        case .learnWords:
            return ("daily_task_learn_title", "daily_task_learn_subtitle", 10)
        case .practice:
            return ("daily_task_practice_title", "daily_task_practice_subtitle", 1)
        case .review:
            return ("daily_task_review_title", "daily_task_review_subtitle", 5)
        }
    }

    private func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func completedTypes(for date: Date) -> Set<String> {
        let key = dateKey(date)
        let stored = UserDefaults.standard.dictionary(forKey: completedKey) as? [String: [String]] ?? [:]
        return Set(stored[key] ?? [])
    }

    private func saveCompletedTypes(_ types: Set<String>, for date: Date) {
        let key = dateKey(date)
        var stored = UserDefaults.standard.dictionary(forKey: completedKey) as? [String: [String]] ?? [:]
        stored[key] = Array(types)
        UserDefaults.standard.set(stored, forKey: completedKey)
    }

    private func streakDates() -> [Date] {
        let stored = UserDefaults.standard.array(forKey: streakDatesKey) as? [TimeInterval] ?? []
        return stored.map { Date(timeIntervalSince1970: $0) }
    }

    private func saveStreakDates(_ dates: [Date]) {
        let values = dates.map { $0.timeIntervalSince1970 }
        UserDefaults.standard.set(values, forKey: streakDatesKey)
    }
}

struct WrongBookItem: Identifiable, Hashable, Codable {
    let id: String
    let itemId: String
    let mode: LearningMode
    let type: PracticeQuestionType
    var lastWrongAt: Date
}

final class WrongBookStore: ObservableObject {
    static let shared = WrongBookStore()

    private let key = "wrong_book_items"

    @Published private(set) var items: [WrongBookItem] = []

    private init() {
        items = load()
    }

    func addWrong(itemId: String, mode: LearningMode, type: PracticeQuestionType) {
        var all = items
        if let index = all.firstIndex(where: { $0.itemId == itemId && $0.mode == mode && $0.type == type }) {
            all[index].lastWrongAt = Date()
        } else {
            all.append(WrongBookItem(id: UUID().uuidString, itemId: itemId, mode: mode, type: type, lastWrongAt: Date()))
        }
        save(all)
    }

    func remove(itemId: String, mode: LearningMode, type: PracticeQuestionType) {
        var all = items
        all.removeAll { $0.itemId == itemId && $0.mode == mode && $0.type == type }
        save(all)
    }

    func clear() {
        save([])
    }

    private func save(_ list: [WrongBookItem]) {
        items = list.sorted { $0.lastWrongAt > $1.lastWrongAt }
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() -> [WrongBookItem] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([WrongBookItem].self, from: data) else { return [] }
        return decoded.sorted { $0.lastWrongAt > $1.lastWrongAt }
    }
}
