// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct AIHTTPClient: @unchecked Sendable {
    let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    func streamSSE(
        request: URLRequest,
        extract: @escaping @Sendable (String) -> String?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: request)
                    try await validate(response: response, bytes: bytes)
                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard
                            let data = AIStreamParser.eventData(fromLine: line),
                            let text = extract(data),
                            !text.isEmpty
                        else { continue }
                        continuation.yield(text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: mapped(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func streamLines(
        request: URLRequest,
        extract: @escaping @Sendable (String) -> String?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: request)
                    try await validate(response: response, bytes: bytes)
                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard let text = extract(line), !text.isEmpty else { continue }
                        continuation.yield(text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: mapped(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIProviderError.invalidResponse
        }
        guard (200..<400).contains(http.statusCode) else {
            let body = String(decoding: data.prefix(500), as: UTF8.self)
            throw AIProviderError.httpStatus(http.statusCode, body)
        }
        return data
    }

    private func validate(
        response: URLResponse,
        bytes: URLSession.AsyncBytes
    ) async throws {
        guard let http = response as? HTTPURLResponse else {
            throw AIProviderError.invalidResponse
        }
        guard (200..<400).contains(http.statusCode) else {
            var body = Data()
            for try await byte in bytes {
                if body.count == 500 { break }
                body.append(byte)
            }
            throw AIProviderError.httpStatus(
                http.statusCode,
                String(decoding: body, as: UTF8.self)
            )
        }
    }

    private func mapped(_ error: Error) -> Error {
        if error is CancellationError {
            return AIProviderError.requestAborted
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return AIProviderError.requestAborted
        }
        return error
    }
}

enum AIRequestBuilder {
    static func post(url: URL, headers: [String: String], body: Any) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    static func get(url: URL, headers: [String: String]) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        return request
    }
}
