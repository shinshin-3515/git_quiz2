//
//  BlueGradientBackground.swift
//  git_quiz
//
//  Created by 松田慎 on 2025/12/29.
//


//
//  KeibaiStudy_OneFile.swift
//  競売スタディ（1ファイル版）
//
//  Created by 松田慎 on 2025/12/29.
//

import SwiftUI
import Combine
import Foundation

// =========================================================
// MARK: - Background (Blue Gradient)
// =========================================================

struct BlueGradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.55, green: 0.82, blue: 1.00),
                Color(red: 0.22, green: 0.56, blue: 0.98),
                Color(red: 0.10, green: 0.34, blue: 0.86)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// =========================================================
// MARK: - Readability Helpers（白地寄りカード）
// =========================================================

private struct GlassCardModifier: ViewModifier {
    let padding: CGFloat
    private let fill = Color.white.opacity(0.92)
    private let stroke = Color.black.opacity(0.08)

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
}

private extension View {
    func glassCard(padding: CGFloat = 12) -> some View {
        self.modifier(GlassCardModifier(padding: padding))
    }
}

// List行の白地寄り背景（任意）
private struct ListRowGlassBackground: View {
    var body: some View { Rectangle().fill(Color.white.opacity(0.88)) }
}

private extension View {
    func listRowGlassBackground() -> some View {
        self.listRowBackground(ListRowGlassBackground())
    }
}

// =========================================================
// MARK: - Models
// =========================================================

struct Question: Identifiable {
    let id: String
    let category: String
    let number: Int
    let prompt: String
    let choices: [String]
    let correctIndex: Int
    let explanation: String
}

struct JSONQuestion: Decodable {
    let field: String
    let number: Int
    let question: String
    let correct: String
    let wrong: [String]
    let explanation: String
}

enum AnswerStatus: String, Codable {
    case unanswered
    case correct
    case wrong
}

// =========================================================
// MARK: - Notifications
// =========================================================

extension Notification.Name {
    static let historyDidChange = Notification.Name("historyDidChange")
    static let bookmarkDidChange = Notification.Name("bookmarkDidChange")
    static let studyDatesDidChange = Notification.Name("studyDatesDidChange")
}

// =========================================================
// MARK: - Stores
// =========================================================

final class AnswerHistoryStore {
    static let shared = AnswerHistoryStore()
    private init() { load() }

    private let key = "answer_history_v1"
    private(set) var map: [String: AnswerStatus] = [:]

    private let dateKey = "study_dates_v1"
    private(set) var studyDateKeys: Set<String> = []

    func status(for questionID: String) -> AnswerStatus {
        map[questionID] ?? .unanswered
    }

    func setStatus(_ status: AnswerStatus, for questionID: String) {
        map[questionID] = status
        recordStudy(for: Date())
        save()
        NotificationCenter.default.post(name: .historyDidChange, object: nil)
        NotificationCenter.default.post(name: .studyDatesDidChange, object: nil)
    }

    func recordStudy(for date: Date) {
        let k = Self.dayKey(for: date)
        studyDateKeys.insert(k)
        save()
        NotificationCenter.default.post(name: .studyDatesDidChange, object: nil)
    }

    func clearAll() {
        map.removeAll()
        studyDateKeys.removeAll()
        save()
        NotificationCenter.default.post(name: .historyDidChange, object: nil)
        NotificationCenter.default.post(name: .studyDatesDidChange, object: nil)
    }

    struct Summary {
        let totalAnswered: Int
        let correct: Int
        let wrong: Int
        let unanswered: Int

        var accuracyRate: Double {
            totalAnswered == 0 ? 0.0 : Double(correct) / Double(totalAnswered)
        }
    }

    func summarize(questions: [Question]) -> Summary {
        var answered = 0
        var correct = 0
        var wrong = 0
        var unanswered = 0

        for q in questions {
            switch status(for: q.id) {
            case .unanswered:
                unanswered += 1
            case .correct:
                answered += 1
                correct += 1
            case .wrong:
                answered += 1
                wrong += 1
            }
        }

        return Summary(totalAnswered: answered, correct: correct, wrong: wrong, unanswered: unanswered)
    }

    func hasStudy(on date: Date) -> Bool {
        studyDateKeys.contains(Self.dayKey(for: date))
    }

    static func dayKey(for date: Date) -> String {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month, .day], from: date)
        let y = c.year ?? 1970
        let m = c.month ?? 1
        let d = c.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(map)
            UserDefaults.standard.set(data, forKey: key)

            let dateData = try JSONEncoder().encode(Array(studyDateKeys))
            UserDefaults.standard.set(dateData, forKey: dateKey)
        } catch {
            print("AnswerHistoryStore save error:", error)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key) {
            do {
                map = try JSONDecoder().decode([String: AnswerStatus].self, from: data)
            } catch {
                print("AnswerHistoryStore load error:", error)
                map = [:]
            }
        }

        if let dateData = UserDefaults.standard.data(forKey: dateKey) {
            do {
                let arr = try JSONDecoder().decode([String].self, from: dateData)
                studyDateKeys = Set(arr)
            } catch {
                print("AnswerHistoryStore load dates error:", error)
                studyDateKeys = []
            }
        }
    }
}

final class BookmarkStore {
    static let shared = BookmarkStore()
    private init() { load() }

    private let key = "bookmark_ids_v1"
    private(set) var ids: Set<String> = []

    func isBookmarked(_ questionID: String) -> Bool {
        ids.contains(questionID)
    }

    func toggle(_ questionID: String) {
        if ids.contains(questionID) {
            ids.remove(questionID)
        } else {
            ids.insert(questionID)
        }
        save()
        NotificationCenter.default.post(name: .bookmarkDidChange, object: nil)
    }

    func clearAll() {
        ids.removeAll()
        save()
        NotificationCenter.default.post(name: .bookmarkDidChange, object: nil)
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(Array(ids))
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("BookmarkStore save error:", error)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        do {
            let arr = try JSONDecoder().decode([String].self, from: data)
            ids = Set(arr)
        } catch {
            print("BookmarkStore load error:", error)
            ids = []
        }
    }
}

// 総学習時間（前面滞在時間の積算）
@MainActor
final class StudyTimeStore: ObservableObject {
    static let shared = StudyTimeStore()
    private init() { load() }

    private let totalKey = "study_total_seconds_v1"

    @Published private(set) var totalSeconds: Int = 0
    private var sessionStart: Date? = nil

    func startSession() {
        guard sessionStart == nil else { return }
        sessionStart = Date()
    }

    func endSession() {
        guard let start = sessionStart else { return }
        let elapsed = max(0, Int(Date().timeIntervalSince(start)))
        totalSeconds += elapsed
        sessionStart = nil
        save()
    }

    func reset() {
        totalSeconds = 0
        sessionStart = nil
        save()
    }

    var formattedTotal: String {
        let s = totalSeconds
        let h = s / 3600
        let m = (s % 3600) / 60
        if h > 0 { return "\(h)時間\(m)分" }
        return "\(m)分"
    }

    private func save() {
        UserDefaults.standard.set(totalSeconds, forKey: totalKey)
    }

    private func load() {
        totalSeconds = UserDefaults.standard.integer(forKey: totalKey)
    }
}

final class QuestionStore {
    static let shared = QuestionStore()
    private init() {}

    private var cachedJSON: [JSONQuestion]?

    private let jsonFileName = "quiz"
    private let jsonFileExt  = "json"

    private let embeddedJSON: String = """
    [
      {
        "field": "基礎知識",
        "number": 1,
        "question": "競売不動産の情報開示資料である3点セットに含まれないものは____である。",
        "correct": "登記済権利証",
        "wrong": ["物件明細書", "現況調査報告書", "評価書"],
        "explanation": "3点セットは物件明細書・現況調査報告書・評価書で構成される。"
      }
    ]
    """

    func loadAllJSONQuestions() throws -> [JSONQuestion] {
        if let cachedJSON { return cachedJSON }

        if let url = Bundle.main.url(forResource: jsonFileName, withExtension: jsonFileExt) {
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode([JSONQuestion].self, from: data)
                self.cachedJSON = decoded
                return decoded
            } catch {
                print("quiz.json decode error:", error)
            }
        } else {
            print("quiz.json not found in bundle. Check Target Membership / Copy Bundle Resources.")
        }

        guard let fallbackData = embeddedJSON.data(using: .utf8) else {
            throw NSError(domain: "Quiz", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "quiz.jsonが見つからず、フォールバックJSONのUTF-8変換にも失敗しました。"
            ])
        }

        let fallbackDecoded = try JSONDecoder().decode([JSONQuestion].self, from: fallbackData)
        self.cachedJSON = fallbackDecoded
        return fallbackDecoded
    }

    func categories(order: [String] = ["基礎知識","法理論と実務","民法","その他法令","税金"]) -> [String] {
        guard let raw = try? loadAllJSONQuestions() else { return [] }
        let set = Set(raw.map { $0.field })
        return order.filter { set.contains($0) } + set.subtracting(order).sorted()
    }

    func questions(for categoryName: String,
                   shuffleChoices: Bool = true,
                   shuffleQuestions: Bool = false) -> [Question] {

        guard let raw = try? loadAllJSONQuestions() else { return [] }

        let filtered = raw
            .filter { $0.field == categoryName }
            .sorted { $0.number < $1.number }

        var mapped: [Question] = []
        mapped.reserveCapacity(filtered.count)

        for q in filtered {
            var choices = [q.correct] + q.wrong
            if choices.count < 4 {
                while choices.count < 4 { choices.append("（選択肢不足）") }
            } else if choices.count > 4 {
                choices = Array(choices.prefix(4))
            }

            if shuffleChoices { choices.shuffle() }

            let correctIndex = choices.firstIndex(of: q.correct) ?? 0
            let fixedID = "\(q.field)#\(q.number)"

            mapped.append(
                Question(
                    id: fixedID,
                    category: q.field,
                    number: q.number,
                    prompt: q.question,
                    choices: choices,
                    correctIndex: correctIndex,
                    explanation: q.explanation
                )
            )
        }

        if shuffleQuestions { mapped.shuffle() }
        return mapped
    }

    func reloadFromBundle() {
        cachedJSON = nil
    }
}

// =========================================================
// MARK: - ViewModels
// =========================================================

@MainActor
final class QuizViewModel: ObservableObject {

    @Published private(set) var questions: [Question] = []
    @Published private(set) var currentIndex: Int = 0

    @Published private(set) var selectedIndex: Int? = nil
    @Published private(set) var isAnswered: Bool = false
    @Published private(set) var didSkip: Bool = false

    @Published private(set) var correctCount: Int = 0
    @Published private(set) var answeredCount: Int = 0

    @Published var isShuffled: Bool = true

    var currentQuestion: Question? {
        guard questions.indices.contains(currentIndex) else { return nil }
        return questions[currentIndex]
    }

    var progressText: String {
        "\(min(currentIndex + 1, questions.count)) / \(questions.count)"
    }

    var isLastQuestion: Bool {
        !questions.isEmpty && currentIndex == (questions.count - 1)
    }

    func loadFromQuestions(_ questions: [Question], startIndex: Int) {
        self.questions = questions
        restart(resetScore: true)
        if self.questions.indices.contains(startIndex) {
            self.currentIndex = startIndex
        }
    }

    func answer(_ index: Int) {
        guard let q = currentQuestion else { return }
        guard !isAnswered else { return }

        selectedIndex = index
        isAnswered = true
        didSkip = false
        answeredCount += 1

        if index == q.correctIndex {
            correctCount += 1
            AnswerHistoryStore.shared.setStatus(.correct, for: q.id)
        } else {
            AnswerHistoryStore.shared.setStatus(.wrong, for: q.id)
        }
    }

    func dontKnow() {
        guard !isAnswered else { return }
        isAnswered = true
        didSkip = true
        selectedIndex = nil
        answeredCount += 1
        AnswerHistoryStore.shared.recordStudy(for: Date())
    }

    func next() {
        guard !questions.isEmpty else { return }
        guard currentIndex + 1 < questions.count else { return }
        currentIndex += 1
        selectedIndex = nil
        isAnswered = false
        didSkip = false
    }

    func prev() {
        guard !questions.isEmpty else { return }
        guard currentIndex - 1 >= 0 else { return }
        currentIndex -= 1
        selectedIndex = nil
        isAnswered = false
        didSkip = false
    }

    func restart(resetScore: Bool) {
        selectedIndex = nil
        isAnswered = false
        didSkip = false
        currentIndex = 0

        if resetScore {
            correctCount = 0
            answeredCount = 0
        }
    }
}

// =========================================================
// MARK: - Small UI Parts
// =========================================================

struct DonutProgressView: View {
    let progress: Double
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 10)

                Circle()
                    .trim(from: 0, to: max(0, min(1, progress)))
                    .stroke(.primary, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 96, height: 96)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

// =========================================================
// MARK: - Month Calendar (Scrollable Months)
// =========================================================

struct MonthCalendarPagerView: View {
    let markedDayKeys: Set<String>

    private let monthsBack: Int = 12
    @State private var pageIndex: Int = 0
    private let cal = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            TabView(selection: $pageIndex) {
                ForEach(0...monthsBack, id: \.self) { idx in
                    MonthGridView(
                        monthStart: monthStart(offsetMonths: -idx),
                        markedDayKeys: markedDayKeys
                    )
                    .tag(idx)
                    .padding(.top, 2)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 190)
        }
    }

    private var header: some View {
        let start = monthStart(offsetMonths: -pageIndex)
        return HStack(spacing: 10) {
            Button {
                pageIndex = max(0, pageIndex - 1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 32, height: 28)
            }
            .disabled(pageIndex == 0)
            .opacity(pageIndex == 0 ? 0.35 : 1.0)

            Text(monthTitle(for: start))
                .font(.subheadline)
                .fontWeight(.semibold)

            Spacer()

            Button {
                pageIndex = min(monthsBack, pageIndex + 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 32, height: 28)
            }
            .disabled(pageIndex == monthsBack)
            .opacity(pageIndex == monthsBack ? 0.35 : 1.0)
        }
    }

    private func monthStart(offsetMonths: Int) -> Date {
        let now = Date()
        let base = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        return cal.date(byAdding: .month, value: offsetMonths, to: base) ?? base
    }

    private func monthTitle(for date: Date) -> String {
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        return "\(y)年\(m)月"
    }
}

private struct MonthGridView: View {
    let monthStart: Date
    let markedDayKeys: Set<String>

    private let cal = Calendar.current

    var body: some View {
        let days = gridDays(for: monthStart)
        let weekSymbols = weekdaySymbols()

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                ForEach(weekSymbols, id: \.self) { s in
                    Text(s)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
                ForEach(0..<days.count, id: \.self) { i in
                    dayCell(date: days[i])
                }
            }
        }
    }

    private func dayCell(date: Date?) -> some View {
        let isInMonth: Bool = {
            guard let date else { return false }
            let a = cal.dateComponents([.year, .month], from: date)
            let b = cal.dateComponents([.year, .month], from: monthStart)
            return a.year == b.year && a.month == b.month
        }()

        let dayNumber: String = {
            guard let date else { return "" }
            return "\(cal.component(.day, from: date))"
        }()

        let isToday: Bool = {
            guard let date else { return false }
            return cal.isDateInToday(date)
        }()

        let isMarked: Bool = {
            guard let date else { return false }
            return markedDayKeys.contains(AnswerHistoryStore.dayKey(for: date))
        }()

        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(isToday ? Color.white.opacity(0.25) : Color.clear)

            VStack(spacing: 3) {
                Text(dayNumber)
                    .font(.caption)
                    .foregroundStyle(isInMonth ? Color.primary : Color.secondary.opacity(0.35))

                Circle()
                    .fill(isMarked ? Color.primary : Color.clear)
                    .frame(width: 6, height: 6)
            }
            .padding(.vertical, 4)
        }
        .frame(height: 28)
    }

    private func weekdaySymbols() -> [String] {
        let syms = cal.shortStandaloneWeekdaySymbols
        let first = cal.firstWeekday - 1
        return Array(syms[first...] + syms[..<first]).map { String($0.prefix(1)) }
    }

    private func gridDays(for monthStart: Date) -> [Date?] {
        let range = cal.range(of: .day, in: .month, for: monthStart) ?? 1..<2
        let numDays = range.count

        let firstWeekdayIndex = weekdayIndex(date: monthStart)
        var cells: [Date?] = Array(repeating: nil, count: firstWeekdayIndex)

        for day in 1...numDays {
            if let d = cal.date(byAdding: .day, value: day - 1, to: monthStart) {
                cells.append(d)
            }
        }

        let target = cells.count <= 35 ? 35 : 42
        if cells.count < target {
            cells.append(contentsOf: Array(repeating: nil, count: target - cells.count))
        }
        return cells
    }

    private func weekdayIndex(date: Date) -> Int {
        let weekday = cal.component(.weekday, from: date)
        let first = cal.firstWeekday
        return (weekday - first + 7) % 7
    }
}

// =========================================================
// MARK: - BottomBar Button Style
// =========================================================

private struct BottomBarButtonModifier: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        content
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.black)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(isEnabled ? 0.95 : 0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.18), lineWidth: 1)
            )
            .shadow(radius: isEnabled ? 2 : 0)
            .opacity(isEnabled ? 1.0 : 0.55)
    }
}

private extension View {
    func bottomBarButtonStyle(isEnabled: Bool) -> some View {
        self.modifier(BottomBarButtonModifier(isEnabled: isEnabled))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// =========================================================
// MARK: - Views
// =========================================================

struct RootView: View {
    @AppStorage("splashDuration") private var splashDuration: Double = 1.2
    @State private var showSplash = true

    var body: some View {
        Group {
            if showSplash {
                SplashView()
            } else {
                NavigationStack {
                    HomeView()
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + max(0.0, splashDuration)) {
                withAnimation(.easeInOut) { showSplash = false }
            }
        }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            BlueGradientBackground()

            VStack(spacing: 14) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 54, weight: .semibold))

                Text("競売不動産取扱主任者")
                    .font(.title)
                    .fontWeight(.bold)

                Text("スタディアプリ")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ProgressView()
                    .padding(.top, 10)
            }
            .padding()
            .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 22)
        }
    }
}

struct HomeView: View {
    @State private var allQuestions: [Question] = []
    @State private var summary = AnswerHistoryStore.Summary(totalAnswered: 0, correct: 0, wrong: 0, unanswered: 0)
    @State private var studyDates: Set<String> = []

    var body: some View {
        ZStack {
            BlueGradientBackground()

            // 上側はスクロール可（横向きでも下メニューを押し出さない）
            ScrollView {
                VStack(spacing: 14) {
                    learningStatsCard
                }
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 230) // 下固定メニュー分の余白
            }
        }
        .safeAreaInset(edge: .bottom) {
            menuArea
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .background(Color.white.opacity(0.12))
        }
        .navigationTitle("競売不動産取扱主任者")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
            }
        }
        .onAppear { reloadAllAndSummarize() }
        .onReceive(NotificationCenter.default.publisher(for: .historyDidChange)) { _ in
            reloadAllAndSummarize()
        }
        .onReceive(NotificationCenter.default.publisher(for: .studyDatesDidChange)) { _ in
            studyDates = AnswerHistoryStore.shared.studyDateKeys
        }
    }

    private func reloadAllAndSummarize() {
        let categories = QuestionStore.shared.categories()
        var all: [Question] = []
        for cat in categories {
            all.append(contentsOf: QuestionStore.shared.questions(for: cat, shuffleChoices: false, shuffleQuestions: false))
        }
        allQuestions = all
        summary = AnswerHistoryStore.shared.summarize(questions: allQuestions)
        studyDates = AnswerHistoryStore.shared.studyDateKeys
    }

    // 要求仕様の「学習実績」カード
    private var learningStatsCard: some View {
        let totalQuestions = allQuestions.count
        let answered = summary.totalAnswered
        let correct = summary.correct
        let wrong = summary.wrong

        let progressRate: Double = totalQuestions == 0 ? 0 : Double(answered) / Double(totalQuestions)
        let accuracyRate: Double = answered == 0 ? 0 : Double(correct) / Double(answered)

        let studyDays = studyDates.count
        let totalStudyTime = StudyTimeStore.shared.formattedTotal

        return VStack(alignment: .leading, spacing: 12) {
            Text("学習実績")
                .font(.headline)

            // 進捗率 / 正答率（円）
            HStack(alignment: .top, spacing: 14) {
                DonutProgressView(
                    progress: progressRate,
                    title: "進捗率",
                    subtitle: "\(answered) / \(totalQuestions) 問"
                )

                DonutProgressView(
                    progress: accuracyRate,
                    title: "正答率",
                    subtitle: "\(correct) / \(answered) 問"
                )

                Spacer(minLength: 0)
            }

            Divider()

            // 総問題数 / 正解 / 不正解
            HStack(spacing: 10) {
                statTile(title: "総問題数", value: "\(totalQuestions)")
                statTile(title: "正解", value: "\(correct)")
                statTile(title: "不正解", value: "\(wrong)")
            }

            // 総学習時間 / 学習日数
            HStack(spacing: 10) {
                statTile(title: "総学習時間", value: totalStudyTime)
                statTile(title: "学習日数", value: "\(studyDays)日")
            }

            Divider()

            // カレンダー（前月/前々月もスワイプで確認）
            MonthCalendarPagerView(markedDayKeys: studyDates)
                .glassCard(padding: 12)
        }
        .glassCard(padding: 14)
    }

    private func statTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    // 下固定メニュー（横向きでも画面外に行かない）
    private var menuArea: some View {
        VStack(spacing: 6) {
            NavigationLink { RecommendView() } label: {
                menuButtonLabel(title: "おまかせ", systemImage: "star")
            }

            NavigationLink { CategorySelectView() } label: {
                menuButtonLabel(title: "問題一覧", systemImage: "list.bullet.rectangle")
            }

            NavigationLink { ReviewView() } label: {
                menuButtonLabel(title: "振り返り", systemImage: "arrow.clockwise")
            }

            NavigationLink { BookmarkView() } label: {
                menuButtonLabel(title: "ブックマーク", systemImage: "bookmark")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func menuButtonLabel(title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: 34)

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

// =========================================================
// MARK: - Lists / Browsing
// =========================================================

struct CategorySelectView: View {
    @State private var categories: [String] = []
    @State private var categoryProgress: [String: (answered: Int, total: Int)] = [:]

    var body: some View {
        ZStack {
            BlueGradientBackground()

            List {
                Section("カテゴリーを選択") {
                    ForEach(categories, id: \.self) { name in
                        NavigationLink {
                            QuestionListView(categoryName: name)
                        } label: {
                            categoryRow(name)
                        }
                    }
                }
            }
            .listRowGlassBackground()
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("カテゴリー")
        .onAppear {
            categories = QuestionStore.shared.categories()
            rebuildProgress()
        }
        .onReceive(NotificationCenter.default.publisher(for: .historyDidChange)) { _ in
            rebuildProgress()
        }
    }

    private func rebuildProgress() {
        var map: [String: (answered: Int, total: Int)] = [:]
        for cat in categories {
            let qs = QuestionStore.shared.questions(for: cat, shuffleChoices: false, shuffleQuestions: false)
            let s = AnswerHistoryStore.shared.summarize(questions: qs)
            map[cat] = (answered: s.totalAnswered, total: qs.count)
        }
        categoryProgress = map
    }

    private func categoryRow(_ name: String) -> some View {
        let info = categoryProgress[name] ?? (answered: 0, total: 0)
        let rate: Double = info.total == 0 ? 0 : Double(info.answered) / Double(info.total)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name)
                Spacer()
                Text("\(info.answered) / \(info.total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: rate)
        }
        .padding(.vertical, 6)
    }
}

struct QuestionListView: View {
    let categoryName: String
    @State private var questions: [Question] = []

    var body: some View {
        ZStack {
            BlueGradientBackground()

            List {
                Section("\(categoryName)（\(questions.count)問）") {
                    ForEach(Array(questions.enumerated()), id: \.element.id) { index, q in
                        NavigationLink {
                            QuizView(categoryName: categoryName, startIndex: index, preloaded: questions)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("No.\(q.number)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(q.prompt)
                                        .lineLimit(2)
                                }
                                Spacer()
                                StatusBadge(status: AnswerHistoryStore.shared.status(for: q.id))
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
            .listRowGlassBackground()
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("問題一覧")
        .onAppear { reload() }
        .onReceive(NotificationCenter.default.publisher(for: .historyDidChange)) { _ in
            reload()
        }
    }

    private func reload() {
        questions = QuestionStore.shared.questions(
            for: categoryName,
            shuffleChoices: true,
            shuffleQuestions: false
        )
    }
}

struct StatusBadge: View {
    let status: AnswerStatus

    var body: some View {
        switch status {
        case .unanswered:
            Text("未回答")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.92))
                .overlay(Capsule().stroke(.quaternary, lineWidth: 1))
                .clipShape(Capsule())
        case .correct:
            Text("正解")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.18))
                .clipShape(Capsule())
        case .wrong:
            Text("不正解")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.18))
                .clipShape(Capsule())
        }
    }
}

// =========================================================
// MARK: - Completion View
// =========================================================

struct QuizCompletionView: View {
    let categoryName: String
    let total: Int
    let answered: Int
    let correct: Int

    let onRetry: () -> Void
    let onCloseToHome: () -> Void

    private var accuracyText: String {
        guard answered > 0 else { return "0%" }
        let rate = Double(correct) / Double(answered)
        return "\(Int((rate * 100).rounded()))%"
    }

    var body: some View {
        ZStack {
            BlueGradientBackground()

            VStack(spacing: 14) {
                Spacer()

                VStack(spacing: 10) {
                    Image(systemName: "party.popper.fill")
                        .font(.system(size: 44, weight: .semibold))

                    Text("解答完了！")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("\(categoryName) を最後まで解きました")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .glassCard(padding: 16)
                .padding(.horizontal, 18)

                VStack(spacing: 10) {
                    statRow(title: "回答数", value: "\(answered) / \(total)")
                    statRow(title: "正解数", value: "\(correct)")
                    statRow(title: "正答率", value: accuracyText)
                }
                .glassCard(padding: 14)
                .padding(.horizontal, 18)

                VStack(spacing: 10) {
                    Button { onRetry() } label: {
                        Text("もう一度（最初から）")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.plain)
                    .bottomBarButtonStyle(isEnabled: true)

                    Button { onCloseToHome() } label: {
                        Text("ホームへ戻る")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.plain)
                    .bottomBarButtonStyle(isEnabled: true)
                }
                .padding(.horizontal, 18)

                Spacer()
            }
            .padding(.vertical, 18)
        }
    }

    private func statRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
}

// =========================================================
// MARK: - Quiz View
// =========================================================

struct QuizView: View {
    let categoryName: String
    let startIndex: Int
    let preloaded: [Question]

    @StateObject private var vm = QuizViewModel()
    @State private var bookmarkRefreshToken = UUID()

    @State private var showCompletion = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            BlueGradientBackground()

            VStack(spacing: 14) {
                header

                if let q = vm.currentQuestion {
                    questionCard(q)
                    feedbackArea(q)

                    Spacer(minLength: 8)

                    choicesArea(q)

                    bottomBar
                } else {
                    Text("問題がありません。")
                        .foregroundStyle(.secondary)
                        .glassCard(padding: 14)
                    Spacer()
                }
            }
            .padding()
        }
        .navigationTitle(categoryName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let q = vm.currentQuestion {
                    Button {
                        BookmarkStore.shared.toggle(q.id)
                    } label: {
                        Image(systemName: BookmarkStore.shared.isBookmarked(q.id) ? "bookmark.fill" : "bookmark")
                    }
                    .id(bookmarkRefreshToken)
                }
            }
        }
        .onAppear {
            vm.loadFromQuestions(preloaded, startIndex: startIndex)
        }
        .onReceive(NotificationCenter.default.publisher(for: .bookmarkDidChange)) { _ in
            bookmarkRefreshToken = UUID()
        }
        .fullScreenCover(isPresented: $showCompletion) {
            QuizCompletionView(
                categoryName: categoryName,
                total: vm.questions.count,
                answered: vm.answeredCount,
                correct: vm.correctCount,
                onRetry: {
                    showCompletion = false
                    vm.restart(resetScore: true)
                },
                onCloseToHome: {
                    showCompletion = false
                    dismiss()
                }
            )
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("進捗: \(vm.progressText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("正解: \(vm.correctCount) / \(vm.answeredCount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .glassCard(padding: 12)
    }

    private func questionCard(_ q: Question) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("問題")
                .font(.headline)
            Text(q.prompt)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 14)
    }

    private func choicesArea(_ q: Question) -> some View {
        VStack(spacing: 10) {
            ForEach(q.choices.indices, id: \.self) { i in
                Button {
                    vm.answer(i)
                } label: {
                    HStack {
                        Text(label(i) + "  " + q.choices[i])
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if vm.isAnswered, !vm.didSkip {
                            Image(systemName: iconName(for: i, correctIndex: q.correctIndex))
                                .foregroundStyle(iconColor(for: i, correctIndex: q.correctIndex))
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(bgChoice(for: i, correctIndex: q.correctIndex))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.black.opacity(0.10), lineWidth: 1))
                .disabled(vm.isAnswered)
            }
        }
    }

    private func feedbackArea(_ q: Question) -> some View {
        Group {
            if vm.isAnswered {
                VStack(alignment: .leading, spacing: 8) {
                    if vm.didSkip {
                        Text("未判定（わからない）")
                            .font(.headline)
                        Text("解説: \(q.explanation)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if let sel = vm.selectedIndex {
                        Text(sel == q.correctIndex ? "正解" : "不正解")
                            .font(.headline)
                        Text("解説: \(q.explanation)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .glassCard(padding: 14)
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 15) {
            Button { vm.prev() } label: {
                Label("前へ", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .bottomBarButtonStyle(isEnabled: vm.currentIndex != 0)
            .disabled(vm.currentIndex == 0)

            Button { vm.dontKnow() } label: {
                Text("わからない")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .bottomBarButtonStyle(isEnabled: !vm.isAnswered)
            .disabled(vm.isAnswered)

            Button {
                if vm.isLastQuestion {
                    showCompletion = true
                } else {
                    vm.next()
                }
            } label: {
                Label(vm.isLastQuestion ? "完了" : "次へ",
                      systemImage: vm.isLastQuestion ? "checkmark" : "chevron.right")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .bottomBarButtonStyle(isEnabled: vm.isAnswered)
            .disabled(!vm.isAnswered)
        }
        .padding(.top, 6)
    }

    private func label(_ index: Int) -> String {
        ["A","B","C","D"][safe: index] ?? "\(index + 1)"
    }

    private func bgChoice(for index: Int, correctIndex: Int) -> some ShapeStyle {
        let base = AnyShapeStyle(Color.white.opacity(0.92))

        guard vm.isAnswered else { return base }
        if vm.didSkip { return base }

        if index == correctIndex { return AnyShapeStyle(Color.green.opacity(0.18)) }
        if let sel = vm.selectedIndex, sel == index, sel != correctIndex {
            return AnyShapeStyle(Color.red.opacity(0.18))
        }
        return base
    }

    private func iconName(for index: Int, correctIndex: Int) -> String {
        if index == correctIndex { return "checkmark.circle.fill" }
        if let sel = vm.selectedIndex, sel == index, sel != correctIndex { return "xmark.circle.fill" }
        return "circle"
    }

    private func iconColor(for index: Int, correctIndex: Int) -> Color {
        if index == correctIndex { return .green }
        if let sel = vm.selectedIndex, sel == index, sel != correctIndex { return .red }
        return .clear
    }
}

// =========================================================
// MARK: - Recommend / Review / Settings / Bookmark
// =========================================================

struct RecommendView: View {
    @State private var questions: [Question] = []
    @State private var startIndex: Int = 0

    var body: some View {
        ZStack {
            BlueGradientBackground()

            Group {
                if questions.isEmpty {
                    VStack(spacing: 12) {
                        Text("おまかせ")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("出題できる問題がありません。")
                            .foregroundStyle(.secondary)
                    }
                    .glassCard(padding: 16)
                    .padding()

                    Spacer()
                } else {
                    QuizView(categoryName: "おまかせ", startIndex: startIndex, preloaded: questions)
                }
            }
        }
        .navigationTitle("おまかせ")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { prepare() }
    }

    private func prepare() {
        let categories = QuestionStore.shared.categories()
        var all: [Question] = []
        for cat in categories {
            all.append(contentsOf: QuestionStore.shared.questions(for: cat, shuffleChoices: true, shuffleQuestions: false))
        }

        let unanswered = all.filter { AnswerHistoryStore.shared.status(for: $0.id) == .unanswered }
        let source = (!unanswered.isEmpty ? unanswered : all).shuffled()

        questions = Array(source.prefix(10)) // 10問で完了
        startIndex = 0
    }
}

struct ReviewView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case unanswered = "未回答"
        case wrong = "不正解"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .wrong
    @State private var questions: [Question] = []

    var body: some View {
        ZStack {
            BlueGradientBackground()

            List {
                Section {
                    Picker("モード", selection: $mode) {
                        ForEach(Mode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("対象（\(questions.count)問）") {
                    ForEach(Array(questions.enumerated()), id: \.element.id) { index, q in
                        NavigationLink {
                            QuizView(categoryName: "振り返り", startIndex: index, preloaded: questions)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(q.category) / No.\(q.number)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(q.prompt)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
            .listRowGlassBackground()
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("振り返り")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reload() }
        .onChange(of: mode) { _ in reload() }
        .onReceive(NotificationCenter.default.publisher(for: .historyDidChange)) { _ in reload() }
    }

    private func reload() {
        let categories = QuestionStore.shared.categories()
        var all: [Question] = []
        for cat in categories {
            all.append(contentsOf: QuestionStore.shared.questions(for: cat, shuffleChoices: true, shuffleQuestions: false))
        }

        questions = all.filter { q in
            let s = AnswerHistoryStore.shared.status(for: q.id)
            switch mode {
            case .unanswered: return s == .unanswered
            case .wrong:      return s == .wrong
            }
        }
    }
}

struct SettingsView: View {
    @State private var showConfirmHistory = false
    @State private var showConfirmStudyTime = false

    @AppStorage("splashDuration") private var splashDuration: Double = 1.2
    @AppStorage("isProUnlocked") private var isProUnlocked: Bool = false

    var body: some View {
        ZStack {
            BlueGradientBackground()

            List {
                Section("有料機能") {
                    HStack {
                        Text("有料問題アンロック")
                        Spacer()
                        Text(isProUnlocked ? "有効" : "未購入")
                            .foregroundStyle(.secondary)
                    }

                    if isProUnlocked {
                        Button("購入状態をリセット（デバッグ用）") { isProUnlocked = false }
                            .foregroundStyle(.red)

                        Text("※App Store課金を導入する場合は、購入/復元の処理をStoreKitで置き換えます。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Button("購入（デモ）") { isProUnlocked = true }
                            .buttonStyle(.borderedProminent)

                        Button("購入を復元（デモ）") { isProUnlocked = true }
                            .buttonStyle(.bordered)

                        Text("※この1ファイル版では、購入UIのみ追加しています（課金処理は未実装）。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("表示") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("オープニング表示時間")
                            Spacer()
                            Text(String(format: "%.1f秒", splashDuration))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $splashDuration, in: 0.0...5.0, step: 0.1)
                    }
                    .padding(.vertical, 6)
                }

                Section("データ") {
                    Button("学習履歴をリセット") { showConfirmHistory = true }
                        .foregroundStyle(.red)

                    Button("ブックマークを全解除") { BookmarkStore.shared.clearAll() }
                        .foregroundStyle(.red)

                    Button("総学習時間をリセット") { showConfirmStudyTime = true }
                        .foregroundStyle(.red)
                }
            }
            .listRowGlassBackground()
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("設定")
        .alert("学習履歴をリセットしますか？", isPresented: $showConfirmHistory) {
            Button("キャンセル", role: .cancel) {}
            Button("リセット", role: .destructive) {
                AnswerHistoryStore.shared.clearAll()
            }
        } message: {
            Text("未回答/正解/不正解の状態、学習日マークが全て初期化されます。")
        }
        .alert("総学習時間をリセットしますか？", isPresented: $showConfirmStudyTime) {
            Button("キャンセル", role: .cancel) {}
            Button("リセット", role: .destructive) {
                StudyTimeStore.shared.reset()
            }
        } message: {
            Text("総学習時間（前面滞在の累積）が0に戻ります。")
        }
    }
}

struct BookmarkView: View {
    @State private var questions: [Question] = []

    var body: some View {
        ZStack {
            BlueGradientBackground()

            List {
                if questions.isEmpty {
                    Section { Text("ブックマークがありません。").foregroundStyle(.secondary) }
                } else {
                    Section("ブックマーク（\(questions.count)問）") {
                        ForEach(Array(questions.enumerated()), id: \.element.id) { index, q in
                            NavigationLink {
                                QuizView(categoryName: "ブックマーク", startIndex: index, preloaded: questions)
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(q.category) / No.\(q.number)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(q.prompt)
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                    Image(systemName: BookmarkStore.shared.isBookmarked(q.id) ? "bookmark.fill" : "bookmark")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 6)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    BookmarkStore.shared.toggle(q.id)
                                    reload()
                                } label: { Text("解除") }
                                .tint(.red)
                            }
                        }
                    }
                }
            }
            .listRowGlassBackground()
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("ブックマーク")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reload() }
        .onReceive(NotificationCenter.default.publisher(for: .bookmarkDidChange)) { _ in reload() }
    }

    private func reload() {
        let categories = QuestionStore.shared.categories()
        var all: [Question] = []
        for cat in categories {
            all.append(contentsOf: QuestionStore.shared.questions(for: cat, shuffleChoices: false, shuffleQuestions: false))
        }
        questions = all.filter { BookmarkStore.shared.isBookmarked($0.id) }
    }
}

// =========================================================
// MARK: - App Entry (@main) + Study Time hook
// =========================================================

@main
struct KeibaiStudyApp_OneFile: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var studyTime = StudyTimeStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear { StudyTimeStore.shared.startSession() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                StudyTimeStore.shared.startSession()
            case .inactive, .background:
                StudyTimeStore.shared.endSession()
            @unknown default:
                break
            }
        }
    }
}
