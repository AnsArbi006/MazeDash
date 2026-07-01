import Foundation

struct LeaderboardEntry: Codable, Hashable, Sendable {
    let name: String
    let score: Int
}

enum LeaderboardScope: Hashable, Sendable {
    case timeChallenge(TimeChallengeDuration)
    case storyLevel(Int)

    var storageKey: String {
        switch self {
        case let .timeChallenge(duration):
            return "tc:\(duration.rawValue)"
        case let .storyLevel(levelId):
            return "story:\(levelId)"
        }
    }

    var prefersLowerScore: Bool {
        switch self {
        case .timeChallenge:
            return false
        case .storyLevel:
            return true
        }
    }

    var scoreLabel: String {
        switch self {
        case .timeChallenge:
            return "MAZES"
        case .storyLevel:
            return "TIME"
        }
    }

    func isBetter(_ candidate: Int, than current: Int?) -> Bool {
        guard let current else { return true }
        if prefersLowerScore {
            return candidate < current
        }
        return candidate > current
    }
}

enum LeaderboardServiceError: LocalizedError {
    case notConfigured
    case invalidBaseURL
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Set your leaderboard server URL first."
        case .invalidBaseURL:
            return "The leaderboard server URL is invalid."
        case .invalidResponse:
            return "The leaderboard server returned an unreadable response."
        case let .httpStatus(status):
            return "The leaderboard request failed with status \(status)."
        }
    }
}

actor LeaderboardService {
    static let shared = LeaderboardService()

    enum Config {
        static let baseURLString = "https://your-leaderboard-server.example"
        static let leaderboardPath = "/leaderboard"
        static let maximumEntries = 10

        static var isConfigured: Bool {
            let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            return !trimmed.contains("your-leaderboard-server.example")
        }
    }

    private struct SubmissionRequest: Codable, Sendable {
        let name: String
        let previousName: String?
        let duration: Int?
        let level: Int?
        let score: Int
    }

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchLeaderboard(scope: LeaderboardScope) async throws -> [LeaderboardEntry] {
        let url = try makeLeaderboardURL(scope: scope)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LeaderboardServiceError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw LeaderboardServiceError.httpStatus(httpResponse.statusCode)
        }

        let decoded = try decoder.decode([LeaderboardEntry].self, from: data)
        return Array(decoded.prefix(Config.maximumEntries))
    }

    func submitScore(name: String, previousName: String? = nil, scope: LeaderboardScope, score: Int) async throws {
        let url = try makeLeaderboardURL(scope: nil)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: SubmissionRequest
        switch scope {
        case let .timeChallenge(duration):
            payload = SubmissionRequest(name: name, previousName: previousName, duration: duration.rawValue, level: nil, score: score)
        case let .storyLevel(levelId):
            payload = SubmissionRequest(name: name, previousName: previousName, duration: nil, level: levelId, score: score)
        }
        request.httpBody = try encoder.encode(payload)

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LeaderboardServiceError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw LeaderboardServiceError.httpStatus(httpResponse.statusCode)
        }
    }

    private func makeLeaderboardURL(scope: LeaderboardScope?) throws -> URL {
        guard Config.isConfigured else {
            throw LeaderboardServiceError.notConfigured
        }
        guard var components = URLComponents(string: Config.baseURLString) else {
            throw LeaderboardServiceError.invalidBaseURL
        }

        let path = Config.leaderboardPath
        if components.path.isEmpty {
            components.path = path
        } else {
            components.path = components.path + path
        }

        if let scope {
            switch scope {
            case let .timeChallenge(duration):
                components.queryItems = [URLQueryItem(name: "duration", value: "\(duration.rawValue)")]
            case let .storyLevel(levelId):
                components.queryItems = [URLQueryItem(name: "level", value: "\(levelId)")]
            }
        }

        guard let url = components.url else {
            throw LeaderboardServiceError.invalidBaseURL
        }
        return url
    }
}

actor LeaderboardSyncCoordinator {
    static let shared = LeaderboardSyncCoordinator()

    func submitPendingScoresIfPossible(for scopes: [LeaderboardScope]? = nil) async {
        guard let playerName = await MainActor.run(body: { LeaderboardProfileStore.shared.playerName }) else { return }

        let submissions: [PendingLeaderboardSubmission]
        if let scopes {
            submissions = await MainActor.run {
                scopes.compactMap { LeaderboardProfileStore.shared.pendingSubmission(for: $0) }
            }
        } else {
            submissions = await MainActor.run(body: { LeaderboardProfileStore.shared.pendingSubmissions() })
        }

        guard !submissions.isEmpty else { return }

        for submission in submissions {
            do {
                try await LeaderboardService.shared.submitScore(
                    name: playerName,
                    previousName: submission.previousName,
                    scope: submission.scope,
                    score: submission.score
                )
                await MainActor.run {
                    LeaderboardProfileStore.shared.markSubmitted(scope: submission.scope, score: submission.score)
                }
            } catch {
                continue
            }
        }
    }
}
