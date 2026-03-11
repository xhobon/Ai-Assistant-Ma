import Foundation
import Combine

struct PracticeGenerator {
    static func generateQuestions(
        mode: LearningMode,
        count: Int,
        types: [PracticeQuestionType],
        sourceItems: [VocabItem]
    ) -> [PracticeQuestion] {
        let pool = sourceItems.shuffled()
        let selectedTypes = types.isEmpty ? PracticeQuestionType.allCases : types
        var questions: [PracticeQuestion] = []
        var index = 0

        while questions.count < count, index < pool.count {
            let item = pool[index]
            index += 1
            let type = selectedTypes[questions.count % selectedTypes.count]
            if let question = makeQuestion(type: type, item: item, mode: mode, allItems: sourceItems) {
                questions.append(question)
            }
        }

        if questions.count < count {
            while questions.count < count, let random = sourceItems.randomElement() {
                let type = selectedTypes.randomElement() ?? .multipleChoice
                if let question = makeQuestion(type: type, item: random, mode: mode, allItems: sourceItems) {
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
            if let question = makeQuestion(type: wrong.type, item: item, mode: wrong.mode, allItems: allItems) {
                questions.append(question)
            }
        }
        return questions
    }

    private static func makeQuestion(
        type: PracticeQuestionType,
        item: VocabItem,
        mode: LearningMode,
        allItems: [VocabItem]
    ) -> PracticeQuestion? {
        switch type {
        case .multipleChoice:
            return makeMultipleChoice(item: item, mode: mode, allItems: allItems)
        case .trueFalse:
            return makeTrueFalse(item: item, mode: mode, allItems: allItems)
        case .matching:
            return makeMatching(item: item, mode: mode, allItems: allItems)
        case .fillBlank:
            return makeFillBlank(item: item, mode: mode)
        case .wordBuild:
            return makeWordBuild(item: item, mode: mode)
        case .translation:
            return makeTranslation(item: item, mode: mode)
        case .listening:
            return makeListening(item: item, mode: mode, allItems: allItems)
        case .sentenceOrder:
            return makeSentenceOrder(item: item, mode: mode)
        case .dictation:
            return makeDictation(item: item, mode: mode)
        case .shadowing:
            return makeShadowing(item: item, mode: mode)
        }
    }

    private static func makeMultipleChoice(item: VocabItem, mode: LearningMode, allItems: [VocabItem]) -> PracticeQuestion? {
        let correct: String
        let source: String
        let targetLanguage: String
        let distractorPool: [String]

        switch mode {
        case .zhToId:
            source = item.textZh
            correct = item.textId
            targetLanguage = "id"
            distractorPool = allItems.map { $0.textId }
        case .idToZh:
            source = item.textId
            correct = item.textZh
            targetLanguage = "zh"
            distractorPool = allItems.map { $0.textZh }
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
        let candidates = allItems.shuffled().prefix(3)
        guard candidates.count >= 3 else { return nil }
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

    private static func makeTrueFalse(item: VocabItem, mode: LearningMode, allItems: [VocabItem]) -> PracticeQuestion? {
        let source: String
        let correct: String
        let targetLanguage: String
        let distractorPool: [String]

        switch mode {
        case .zhToId:
            source = item.textZh
            correct = item.textId
            targetLanguage = "id"
            distractorPool = allItems.map { $0.textId }
        case .idToZh:
            source = item.textId
            correct = item.textZh
            targetLanguage = "zh"
            distractorPool = allItems.map { $0.textZh }
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

    private static func makeFillBlank(item: VocabItem, mode: LearningMode) -> PracticeQuestion? {
        let sentence = item.textId
        let words = sentence.split(separator: " ")
        if words.count >= 2 {
            let index = Int.random(in: 0..<words.count)
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

        let fallback = item.exampleId
        let fallbackWords = fallback.split(separator: " ")
        guard fallbackWords.count >= 2 else { return nil }
        let index = Int.random(in: 0..<fallbackWords.count)
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

    private static func makeWordBuild(item: VocabItem, mode: LearningMode) -> PracticeQuestion? {
        let prompt: String
        let answer: String
        let targetLanguage: String

        switch mode {
        case .zhToId:
            prompt = item.textZh
            answer = item.textId
            targetLanguage = "id"
        case .idToZh:
            prompt = item.textId
            answer = item.textZh
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

    private static func makeTranslation(item: VocabItem, mode: LearningMode) -> PracticeQuestion? {
        let source: String
        let answer: String
        let targetLanguage: String
        switch mode {
        case .zhToId:
            source = item.textZh
            answer = item.textId
            targetLanguage = "id"
        case .idToZh:
            source = item.textId
            answer = item.textZh
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

    private static func makeListening(item: VocabItem, mode: LearningMode, allItems: [VocabItem]) -> PracticeQuestion? {
        let audioText: String
        let answer: String
        let targetLanguage: String
        let audioLanguage: String
        let distractorPool: [String]

        switch mode {
        case .zhToId:
            audioText = item.textId
            answer = item.textZh
            targetLanguage = "zh"
            audioLanguage = "id-ID"
            distractorPool = allItems.map { $0.textZh }
        case .idToZh:
            audioText = item.textZh
            answer = item.textId
            targetLanguage = "id"
            audioLanguage = "zh-CN"
            distractorPool = allItems.map { $0.textId }
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

    private static func makeSentenceOrder(item: VocabItem, mode: LearningMode) -> PracticeQuestion? {
        let sentence: String
        let language: String
        switch mode {
        case .zhToId:
            sentence = item.exampleId
            language = "id"
        case .idToZh:
            sentence = item.exampleZh
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

    private static func makeDictation(item: VocabItem, mode: LearningMode) -> PracticeQuestion? {
        let audioText: String
        let answer: String
        let targetLanguage: String
        let audioLanguage: String

        switch mode {
        case .zhToId:
            audioText = item.exampleId
            answer = item.exampleId
            targetLanguage = "id"
            audioLanguage = "id-ID"
        case .idToZh:
            audioText = item.exampleZh
            answer = item.exampleZh
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

    private static func makeShadowing(item: VocabItem, mode: LearningMode) -> PracticeQuestion? {
        let audioText: String
        let answer: String
        let targetLanguage: String
        let audioLanguage: String

        switch mode {
        case .zhToId:
            audioText = item.exampleId
            answer = item.exampleId
            targetLanguage = "id"
            audioLanguage = "id-ID"
        case .idToZh:
            audioText = item.exampleZh
            answer = item.exampleZh
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
