import Foundation
import PDFKit
import UniformTypeIdentifiers
import UIKit

final class KnowledgeBaseService {
    static let shared = KnowledgeBaseService()
    private init() {}

    struct ImportResult {
        let document: KnowledgeDocument
        let chunks: [VectorStoreEntry]
    }

    func listDocuments() -> [KnowledgeDocument] {
        LocalDataStore.shared.loadKnowledgeDocuments()
    }

    func importDocument(from url: URL) async throws -> ImportResult {
        let fileName = url.lastPathComponent
        let fileType = url.pathExtension.lowercased()
        let fileData = try Data(contentsOf: url)

        let baseDir = try ensureKnowledgeBaseDirectory()
        let docId = UUID().uuidString
        let targetURL = baseDir.appendingPathComponent("\(docId)-\(fileName)")
        try fileData.write(to: targetURL, options: .atomic)

        let extracted = try extractText(from: targetURL, fileType: fileType)
        let chunks = chunkText(extracted, maxLen: 800, overlap: 120)
        let embeddings = chunks.map { chunk in
            VectorStoreEntry(
                id: UUID().uuidString,
                documentId: docId,
                chunkText: chunk,
                embeddingVector: embed(text: chunk),
                createdAt: Date()
            )
        }

        let doc = KnowledgeDocument(
            id: docId,
            fileName: fileName,
            fileType: fileType.isEmpty ? "unknown" : fileType,
            localPath: targetURL.path,
            size: fileData.count,
            chunkCount: embeddings.count,
            createdAt: Date()
        )

        var docs = LocalDataStore.shared.loadKnowledgeDocuments()
        docs.insert(doc, at: 0)
        LocalDataStore.shared.saveKnowledgeDocuments(docs)

        var store = LocalDataStore.shared.loadVectorStore()
        store.append(contentsOf: embeddings)
        LocalDataStore.shared.saveVectorStore(store)

        return ImportResult(document: doc, chunks: embeddings)
    }

    func deleteDocument(id: String) {
        var docs = LocalDataStore.shared.loadKnowledgeDocuments()
        guard let doc = docs.first(where: { $0.id == id }) else { return }
        docs.removeAll { $0.id == id }
        LocalDataStore.shared.saveKnowledgeDocuments(docs)
        LocalDataStore.shared.removeVectors(documentId: id)
        let url = URL(fileURLWithPath: doc.localPath)
        try? FileManager.default.removeItem(at: url)
    }

    func retrieveRelevantChunks(for query: String, topK: Int = 5) -> [VectorStoreEntry] {
        let store = LocalDataStore.shared.loadVectorStore()
        guard !store.isEmpty else { return [] }
        let queryVector = embed(text: query)
        let scored = store.map { entry in
            (entry, cosineSimilarity(queryVector, entry.embeddingVector))
        }
        .sorted { $0.1 > $1.1 }
        return scored.prefix(topK).map { $0.0 }
    }

    func buildContext(from entries: [VectorStoreEntry]) -> String {
        guard !entries.isEmpty else { return "" }
        let chunks = entries.prefix(5).enumerated().map { idx, entry in
            "[Chunk \(idx + 1)]\n\(entry.chunkText)"
        }
        return "Knowledge base content:\n" + chunks.joined(separator: "\n\n")
    }

    // MARK: - Extraction

    private func extractText(from url: URL, fileType: String) throws -> String {
        switch fileType {
        case "pdf":
            return extractPDFText(from: url)
        case "txt", "md", "markdown":
            return try String(contentsOf: url, encoding: .utf8)
        case "docx":
            return try extractDocxText(from: url)
        default:
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                return text
            }
            let message = String(format: L("不支持的文件类型：%@"), fileType)
            throw NSError(domain: "KnowledgeBase", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    private func extractPDFText(from url: URL) -> String {
        guard let document = PDFDocument(url: url) else { return "" }
        var parts: [String] = []
        for idx in 0..<document.pageCount {
            if let page = document.page(at: idx), let text = page.string {
                parts.append(text)
            }
        }
        return parts.joined(separator: "\n")
    }

    private func extractDocxText(from url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let docxType = NSAttributedString.DocumentType("org.openxmlformats.wordprocessingml.document")
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: docxType,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        if let attr = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            let text = attr.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { return text }
        }
        // fallback: treat as utf8 text if possible
        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return text
        }
        throw NSError(domain: "KnowledgeBase", code: 2, userInfo: [NSLocalizedDescriptionKey: L("无法解析 DOCX 文本")])
    }

    // MARK: - Chunking & Embedding

    private func chunkText(_ text: String, maxLen: Int, overlap: Int) -> [String] {
        let cleaned = text.replacingOccurrences(of: "\r", with: "\n")
        let chars = Array(cleaned)
        var chunks: [String] = []
        var start = 0
        while start < chars.count {
            let end = min(chars.count, start + maxLen)
            let chunk = String(chars[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunk.isEmpty { chunks.append(chunk) }
            if end == chars.count { break }
            start = max(0, end - overlap)
        }
        return chunks
    }

    private func embed(text: String) -> [Double] {
        let tokens = text.lowercased().split { !$0.isLetter && !$0.isNumber }
        let dimension = 256
        var vector = Array(repeating: 0.0, count: dimension)
        for token in tokens {
            let hash = abs(token.hashValue)
            let idx = hash % dimension
            vector[idx] += 1.0
        }
        return normalize(vector)
    }

    private func normalize(_ vector: [Double]) -> [Double] {
        let norm = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        guard norm > 0 else { return vector }
        return vector.map { $0 / norm }
    }

    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0 }
        var sum = 0.0
        for i in 0..<a.count {
            sum += a[i] * b[i]
        }
        return sum
    }

    private func ensureKnowledgeBaseDirectory() throws -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("KnowledgeBase", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}
