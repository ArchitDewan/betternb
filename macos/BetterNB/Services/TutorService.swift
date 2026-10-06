import Foundation

enum TutorServiceError: Error {
    case invalidResponse
    case rejected(String)
}

struct TutorConfiguration: Sendable {
    let baseURL: URL

    static func load(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        info: [String: Any] = Bundle.main.infoDictionary ?? [:]
    ) -> TutorConfiguration {
        let rawURL = environment["BETTERNB_TUTOR_URL"]
            ?? info["BetterNBTutorURL"] as? String
            ?? "http://127.0.0.1:8082"
        guard let url = URL(string: rawURL), isAllowed(url) else {
            return TutorConfiguration(baseURL: URL(string: "http://127.0.0.1:8082")!)
        }
        return TutorConfiguration(baseURL: url)
    }

    private static func isAllowed(_ url: URL) -> Bool {
        if url.scheme == "https" { return true }
        return url.scheme == "http" && ["127.0.0.1", "localhost", "::1"].contains(url.host ?? "")
    }
}

final class URLSessionTutorClient: TutorClient, CourseStudyClient, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func transcribe(_ attachment: MessageAttachment) async throws -> String {
        let boundary = "Lemma-\(UUID().uuidString)"
        var request = URLRequest(url: baseURL.appending(path: "v1/math/transcriptions"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = makeMultipartBody(
            attachment: attachment,
            fieldName: "image",
            boundary: boundary
        )

        let data = try await responseData(for: request)
        return try decoder.decode(TranscriptionEnvelope.self, from: data).transcription
    }

    func send(_ turn: TutorTurnRequest) async throws -> TutorTurnResponse {
        var request = URLRequest(url: baseURL.appending(path: "v1/tutor/turns"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(turn)
        return try decoder.decode(TutorTurnResponse.self, from: await responseData(for: request))
    }

    func listSources(courseID: String) async throws -> [CourseSourceRecord] {
        var request = URLRequest(url: courseURL(courseID, path: "sources"))
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try decoder.decode([CourseSourceRecord].self, from: await responseData(for: request))
    }

    func importPDF(_ attachment: MessageAttachment, courseID: String) async throws -> CourseSourceRecord {
        let boundary = "Lemma-\(UUID().uuidString)"
        var request = URLRequest(url: courseURL(courseID, path: "sources"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = makeMultipartBody(
            attachment: attachment,
            fieldName: "document",
            boundary: boundary
        )
        return try decoder.decode(CourseSourceRecord.self, from: await responseData(for: request))
    }

    func answerCourseQuestion(_ question: String, courseID: String) async throws -> GroundedCourseAnswer {
        var request = URLRequest(url: courseURL(courseID, path: "answers"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(CourseQuestionEnvelope(question: question))
        return try decoder.decode(GroundedCourseAnswer.self, from: await responseData(for: request))
    }

    func generateProblems(courseID: String, count: Int) async throws -> [GeneratedCourseProblem] {
        var request = URLRequest(url: courseURL(courseID, path: "problems"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(GenerateProblemsRequestEnvelope(count: count))
        return try decoder.decode(
            GeneratedProblemsEnvelope.self,
            from: await responseData(for: request)
        ).problems
    }

    private func responseData(for request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TutorServiceError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = (try? decoder.decode(ErrorEnvelope.self, from: data).detail)
                ?? "The tutor service rejected the request."
            throw TutorServiceError.rejected(message)
        }
        return data
    }

    private func makeMultipartBody(
        attachment: MessageAttachment,
        fieldName: String,
        boundary: String
    ) -> Data {
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(safeFilename(attachment.filename))\"\r\n".utf8))
        body.append(Data("Content-Type: \(attachment.mediaType)\r\n\r\n".utf8))
        body.append(attachment.data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return body
    }

    private func courseURL(_ courseID: String, path: String) -> URL {
        baseURL
            .appending(path: "v1")
            .appending(path: "courses")
            .appending(path: courseID)
            .appending(path: path)
    }

    private func safeFilename(_ filename: String) -> String {
        filename.replacingOccurrences(of: "\"", with: "_")
            .replacingOccurrences(of: "\r", with: "_")
            .replacingOccurrences(of: "\n", with: "_")
    }

    private struct TranscriptionEnvelope: Decodable {
        let transcription: String
    }

    private struct ErrorEnvelope: Decodable {
        let detail: String
    }

    private struct CourseQuestionEnvelope: Encodable {
        let question: String
    }

    private struct GenerateProblemsRequestEnvelope: Encodable {
        let count: Int
    }
}

@MainActor
extension AppDependencies {
    static func makeTutorClient() -> any TutorClient {
        URLSessionTutorClient(baseURL: TutorConfiguration.load().baseURL)
    }

    static func makeCourseStudyClient() -> any CourseStudyClient {
        URLSessionTutorClient(baseURL: TutorConfiguration.load().baseURL)
    }
}
