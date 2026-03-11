import Foundation
import Combine

struct PracticeGenerator {
    static func generateQuestions(
        mode: LearningMode,
        count: Int,
        types: [PracticeQuestionType],
        sourceItems: [VocabItem],
        difficulty: LearningDifficulty? = nil
    ) -> [PracticeQuestion] {
        let pool = sourceItems.shuffled()
        let selectedTypes = types.isEmpty ? PracticeQuestionType.allCases : types
        var questions: [PracticeQuestion] = []
        var index = 0

        while questions.count < count, index < pool.count {
            let item = pool[index]
            index += 1
            let type = selectedTypes[questions.count % selectedTypes.count]
            if let question = makeQuestion(type: type, item: item, mode: mode, allItems: sourceItems, difficulty: difficulty) {
                questions.append(question)
            }
        }

        if questions.count < count {
            while questions.count < count, let random = sourceItems.randomElement() {
                let type = selectedTypes.randomElement() ?? .multipleChoice
                if let question = makeQuestion(type: type, item: random, mode: mode, allItems: sourceItems, difficulty: difficulty) {
                    questions.append(question)
                }
            }
        }

        return questions.shuffled()
    }

    static func generateQuestions(from wrongItems: [WrongBookItem], allItems: [VocabItem]) -> [PracticeQuestion] {
        var questions: [PracticeQuestion] = []
        for wrong in wrongItems {
            guard let item = allItems.first(where: { $0.id == wrong.itemId }) else { continue }
            if let question = makeQuestion(type: wrong.type, item: item, mode: wrong.mode, allItems: allItems, difficulty: nil) {
                questions.append(question)
            }
        }
        return questions
    }

    private static func makeQuestion(
        type: PracticeQuestionType,
        item: VocabItem,
        mode: LearningMode,
        allItems: [VocabItem],
        difficulty: LearningDifficulty?
    ) -> PracticeQuestion? {
        switch type {
        case .multipleChoice:
            return makeMultipleChoice(item: item, mode: mode, allItems: allItems, difficulty: difficulty)
        case .trueFalse:
            return makeTrueFalse(item: item, mode: mode, allItems: allItems, difficulty: difficulty)
        case .matching:
            return makeMatching(item: item, mode: mode, allItems: allItems)
        case .fillBlank:
            return makeFillBlank(item: item, mode: mode, difficulty: difficulty)
        case .wordBuild:
            return makeWordBuild(item: item, mode: mode, difficulty: difficulty)
        case .translation:
            return makeTranslation(item: item, mode: mode, difficulty: difficulty)
        case .listening:
            return makeListening(item: item, mode: mode, allItems: allItems, difficulty: difficulty)
        case .sentenceOrder:
            return makeSentenceOrder(item: item, mode: mode, difficulty: difficulty)
        case .dictation:
            return makeDictation(item: item, mode: mode, difficulty: difficulty)
        case .shadowing:
            return makeShadowing(item: item, mode: mode, difficulty: difficulty)
        }
    }

    private static func makeMultipleChoice(item: VocabItem, mode: LearningMode, allItems: [VocabItem], difficulty: LearningDifficulty?) -> PracticeQuestion? {
        let correct: String
        let source: String
        let targetLanguage: String
        let distractorPool: [String]

        let useExample = shouldUseExample(for: item, mode: mode, difficulty: difficulty, maxWords: 4, maxChars: 20)
        switch mode {
        case .zhToId:
            source = useExample ? item.exampleZh : item.textZh
            correct = useExample ? item.exampleId : item.textId
            targetLanguage = "id"
            distractorPool = useExample ? allItems.map { $0.exampleId } : allItems.map { $0.textId }
        case .idToZh:
            source = useExample ? item.exampleId : item.textId
            correct = useExample ? item.exampleZh : item.textZh
            targetLanguage = "zh"
            distractorPool = useExample ? allItems.map { $0.exampleZh } : allItems.map { $0.textZh }
        }

        let options = buildOptions(correct: correct, from: distractorPool, count: 4)
        return PracticeQuestion(
            id: UUID().uuidString,
            type: .multipleChoice,
            mode: mode,
            itemId: item.id,
            payload: .multipleChoice(sourceText: source, options: options, answer: correct, targetLanguage: targetLanguage)
        )
    }

    private static func makeMatching(item: VocabItem, mode: LearningMode, allItems: [VocabItem]) -> PracticeQuestion? {
        let others = allItems.filter { $0.id != item.id }.shuffled()
        let candidates = [item] + Array(others.prefix(2))
        guard candidates.count == 3 else { return nil }
        var left: [String] = []
        var right: [String] = []
        var pairs: [PracticeMatchPair] = []

        for vocab in candidates {
            switch mode {
            case .zhToId:
                left.append(vocab.textZh)
                right.append(vocab.textId)
                pairs.append(PracticeMatchPair(left: vocab.textZh, right: vocab.textId))
            case .idToZh:
                left.append(vocab.textId)
                right.append(vocab.textZh)
                pairs.append(PracticeMatchPair(left: vocab.textId, right: vocab.textZh))
            }
        }

        right.shuffle()
        return PracticeQuestion(
            id: UUID().uuidString,
            type: .matching,
            mode: mode,
            itemId: item.id,
            payload: .matching(left: left, right: right, pairs: pairs)
        )
    }

    private static func makeTrueFalse(item: VocabItem, mode: LearningMode, allItems: [VocabItem], difficulty: LearningDifficulty?) -> PracticeQuestion? {
        let source: String
        let correct: String
        let targetLanguage: String
        let distractorPool: [String]

        let useExample = shouldUseExample(for: item, mode: mode, difficulty: difficulty, maxWords: 4, maxChars: 20)
        switch mode {
        case .zhToId:
            source = useExample ? item.exampleZh : item.textZh
            correct = useExample ? item.exampleId : item.textId
            targetLanguage = "id"
            distractorPool = useExample ? allItems.map { $0.exampleId } : allItems.map { $0.textId }
        case .idToZh:
            source = useExample ? item.exampleId : item.textId
            correct = useExample ? item.exampleZh : item.textZh
            targetLanguage = "zh"
            distractorPool = useExample ? allItems.map { $0.exampleZh } : allItems.map { $0.textZh }
        }

        let shouldUseCorrect = Bool.random()
        let candidate: String
        if shouldUseCorrect {
            candidate = correct
        } else {
            candidate = distractorPool.shuffled().first(where: { $0 != correct }) ?? correct
        }

        return PracticeQuestion(
            id: UUID().uuidString,
            type: .trueFalse,
            mode: mode,
            itemId: item.id,
            payload: .trueFalse(sourceText: source, candidateText: candidate, correctText: correct, answer: shouldUseCorrect, targetLanguage: targetLanguage)
        )
    }

    private static func makeFillBlank(item: VocabItem, mode: LearningMode, difficulty: LearningDifficulty?) -> PracticeQuestion? {
        let useExample = shouldUseExample(for: item, mode: mode, difficulty: difficulty, maxWords: 8, maxChars: 32)
        let sentence: String
        switch mode {
        case .zhToId:
            sentence = useExample ? item.exampleId : item.textId
        case .idToZh:
            sentence = useExample ? item.exampleZh : item.textZh
        }
        let words = sentence.split(separator: " ")
        if words.count >= 2 {
            let candidates = words.enumerated().filter { $0.element.count >= 2 }.map { $0.offset }
            let index = candidates.randomElement() ?? Int.random(in: 0..<words.count)
            let answer = String(words[index])
            var promptWords = words.map(String.init)
            promptWords[index] = "____"
            let prompt = promptWords.joined(separator: " ")
            return PracticeQuestion(
                id: UUID().uuidString,
                type: .fillBlank,
                mode: mode,
                itemId: item.id,
                payload: .fillBlank(prompt: prompt, answer: answer)
            )
        }

        let fallback = mode == .idToZh ? item.exampleZh : item.exampleId
        let fallbackWords = fallback.split(separator: " ")
        guard fallbackWords.count >= 2 else { return nil }
        let candidates = fallbackWords.enumerated().filter { $0.element.count >= 2 }.map { $0.offset }
        let index = candidates.randomElement() ?? Int.random(in: 0..<fallbackWords.count)
        let answer = String(fallbackWords[index])
        var promptWords = fallbackWords.map(String.init)
        promptWords[index] = "____"
        let prompt = promptWords.joined(separator: " ")
        return PracticeQuestion(
            id: UUID().uuidString,
            type: .fillBlank,
            mode: mode,
            itemId: item.id,
            payload: .fillBlank(prompt: prompt, answer: answer)
        )
    }

    private static func makeWordBuild(item: VocabItem, mode: LearningMode, difficulty: LearningDifficulty?) -> PracticeQuestion? {
        let prompt: String
        let answer: String
        let targetLanguage: String

        let useExample = shouldUseExample(for: item, mode: mode, difficulty: difficulty, maxWords: 4, maxChars: 18)
        switch mode {
        case .zhToId:
            prompt = useExample ? item.exampleZh : item.textZh
            answer = useExample ? item.exampleId : item.textId
            targetLanguage = "id"
        case .idToZh:
            prompt = useExample ? item.exampleId : item.textId
            answer = useExample ? item.exampleZh : item.textZh
            targetLanguage = "zh"
        }

        let (tokens, separator) = tokenizeForBuild(answer: answer, targetLanguage: targetLanguage)
        guard tokens.count >= 2 else { return nil }

        return PracticeQuestion(
            id: UUID().uuidString,
            type: .wordBuild,
            mode: mode,
            itemId: item.id,
            payload: .wordBuild(prompt: prompt, tokens: tokens.shuffled(), answer: answer, separator: separator, targetLanguage: targetLanguage)
        )
    }

    private static func makeTranslation(item: VocabItem, mode: LearningMode, difficulty: LearningDifficulty?) -> PracticeQuestion? {
        let source: String
        let answer: String
        let targetLanguage: String
        let useExample = shouldUseExample(for: item, mode: mode, difficulty: difficulty, maxWords: 8, maxChars: 32)
        switch mode {
        case .zhToId:
            source = useExample ? item.exampleZh : item.textZh
            answer = useExample ? item.exampleId : item.textId
            targetLanguage = "id"
        case .idToZh:
            source = useExample ? item.exampleId : item.textId
            answer = useExample ? item.exampleZh : item.textZh
            targetLanguage = "zh"
        }
        return PracticeQuestion(
            id: UUID().uuidString,
            type: .translation,
            mode: mode,
            itemId: item.id,
            payload: .translation(sourceText: source, answer: answer, targetLanguage: targetLanguage)
        )
    }

    private static func makeListening(item: VocabItem, mode: LearningMode, allItems: [VocabItem], difficulty: LearningDifficulty?) -> PracticeQuestion? {
        let audioText: String
        let answer: String
        let targetLanguage: String
        let audioLanguage: String
        let distractorPool: [String]

        let useExample = shouldUseExample(for: item, mode: mode, difficulty: difficulty, maxWords: 4, maxChars: 20)
        switch mode {
        case .zhToId:
            audioText = useExample ? item.exampleId : item.textId
            answer = useExample ? item.exampleZh : item.textZh
            targetLanguage = "zh"
            audioLanguage = "id-ID"
            distractorPool = useExample ? allItems.map { $0.exampleZh } : allItems.map { $0.textZh }
        case .idToZh:
            audioText = useExample ? item.exampleZh : item.textZh
            answer = useExample ? item.exampleId : item.textId
            targetLanguage = "id"
            audioLanguage = "zh-CN"
            distractorPool = useExample ? allItems.map { $0.exampleId } : allItems.map { $0.textId }
        }

        let options = buildOptions(correct: answer, from: distractorPool, count: 4)
        return PracticeQuestion(
            id: UUID().uuidString,
            type: .listening,
            mode: mode,
            itemId: item.id,
            payload: .listening(audioText: audioText, options: options, answer: answer, targetLanguage: targetLanguage, audioLanguage: audioLanguage)
        )
    }

    private static func makeSentenceOrder(item: VocabItem, mode: LearningMode, difficulty: LearningDifficulty?) -> PracticeQuestion? {
        let sentence: String
        let language: String
        let useExample = shouldUseExample(for: item, mode: mode, difficulty: difficulty, maxWords: 10, maxChars: 40)
        switch mode {
        case .zhToId:
            sentence = useExample ? item.exampleId : item.textId
            language = "id"
        case .idToZh:
            sentence = useExample ? item.exampleZh : item.textZh
            language = "zh"
        }
        let words = sentence.split(separator: " ").map(String.init)
        guard words.count >= 3 else { return nil }
        let shuffled = words.shuffled()
        return PracticeQuestion(
            id: UUID().uuidString,
            type: .sentenceOrder,
            mode: mode,
            itemId: item.id,
            payload: .sentenceOrder(words: shuffled, answer: words.joined(separator: " "), language: language)
        )
    }

    private static func makeDictation(item: VocabItem, mode: LearningMode, difficulty: LearningDifficulty?) -> PracticeQuestion? {
        let audioText: String
        let answer: String
        let targetLanguage: String
        let audioLanguage: String

        let useExample = shouldUseExample(for: item, mode: mode, difficulty: difficulty, maxWords: 10, maxChars: 48)
        switch mode {
        case .zhToId:
            audioText = useExample ? item.exampleId : item.textId
            answer = useExample ? item.exampleId : item.textId
            targetLanguage = "id"
            audioLanguage = "id-ID"
        case .idToZh:
            audioText = useExample ? item.exampleZh : item.textZh
            answer = useExample ? item.exampleZh : item.textZh
            targetLanguage = "zh"
            audioLanguage = "zh-CN"
        }

        return PracticeQuestion(
            id: UUID().uuidString,
            type: .dictation,
            mode: mode,
            itemId: item.id,
            payload: .dictation(audioText: audioText, answer: answer, targetLanguage: targetLanguage, audioLanguage: audioLanguage)
        )
    }

    private static func makeShadowing(item: VocabItem, mode: LearningMode, difficulty: LearningDifficulty?) -> PracticeQuestion? {
        let audioText: String
        let answer: String
        let targetLanguage: String
        let audioLanguage: String

        let useExample = shouldUseExample(for: item, mode: mode, difficulty: difficulty, maxWords: 10, maxChars: 48)
        switch mode {
        case .zhToId:
            audioText = useExample ? item.exampleId : item.textId
            answer = useExample ? item.exampleId : item.textId
            targetLanguage = "id"
            audioLanguage = "id-ID"
        case .idToZh:
            audioText = useExample ? item.exampleZh : item.textZh
            answer = useExample ? item.exampleZh : item.textZh
            targetLanguage = "zh"
            audioLanguage = "zh-CN"
        }

        return PracticeQuestion(
            id: UUID().uuidString,
            type: .shadowing,
            mode: mode,
            itemId: item.id,
            payload: .shadowing(audioText: audioText, answer: answer, targetLanguage: targetLanguage, audioLanguage: audioLanguage)
        )
    }

    private static func buildOptions(correct: String, from pool: [String], count: Int) -> [String] {
        var options: Set<String> = [correct]
        let shuffled = pool.shuffled()
        for item in shuffled {
            if options.count >= count { break }
            if item != correct {
                options.insert(item)
            }
        }
        while options.count < count {
            options.insert(correct)
        }
        return Array(options).shuffled()
    }

    private static func shouldUseExample(
        for item: VocabItem,
        mode: LearningMode,
        difficulty: LearningDifficulty?,
        maxWords: Int,
        maxChars: Int
    ) -> Bool {
        let (exampleSource, exampleTarget): (String, String)
        switch mode {
        case .zhToId:
            exampleSource = item.exampleZh
            exampleTarget = item.exampleId
        case .idToZh:
            exampleSource = item.exampleId
            exampleTarget = item.exampleZh
        }

        guard isShortText(exampleSource, maxWords: maxWords, maxChars: maxChars),
              isShortText(exampleTarget, maxWords: maxWords, maxChars: maxChars) else {
            return false
        }

        let probability: Double
        switch difficulty {
        case .advanced:
            probability = 0.8
        case .intermediate:
            probability = 0.5
        case .beginner:
            probability = 0.2
        case .all, .none:
            probability = 0.4
        }
        return Double.random(in: 0...1) < probability
    }

    private static func isShortText(_ text: String, maxWords: Int, maxChars: Int) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let words = trimmed.split(separator: " ")
        if words.count >= 2 {
            return words.count <= maxWords && trimmed.count <= maxChars
        }
        return trimmed.count <= maxChars
    }

    private static func tokenizeForBuild(answer: String, targetLanguage: String) -> ([String], String) {
        if targetLanguage == "zh" {
            let tokens = answer.map { String($0) }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            return (tokens, "")
        }

        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.split(separator: " ").map(String.init)
        if words.count >= 2 {
            return (words, " ")
        }

        let letters = trimmed.map { String($0) }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return (letters, "")
    }
}
