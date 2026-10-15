import Foundation

struct Guide: Codable, Sendable, Equatable {
    let version: Int
    let generatedAt: Date
    let channels: [Channel]

    static func decode(_ data: Data) throws -> Guide {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Guide.self, from: data)
    }
}

struct Channel: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let name: String
    let logo: String
    let app: String
    let scheme: String
    let programs: [Program]
}

struct Program: Codable, Sendable, Equatable, Identifiable {
    let start: Date
    let end: Date
    let title: String
    let description: String?

    var id: Date { start }

    func isLive(at now: Date) -> Bool { start <= now && now < end }
}
