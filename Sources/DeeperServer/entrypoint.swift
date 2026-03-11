//
//  main.swift
//  DeeperServer
//
//  HTTP API server that exposes Deeper analytics data as JSON endpoints.
//  Connects to a running Beeper Desktop instance and serves analytics data
//  so the dashboard can be accessed from any device on the network.
//
//  Required environment variables:
//    BEEPER_TOKEN      — Bearer token for the Beeper Desktop API
//
//  Optional environment variables:
//    BEEPER_BASE_URL        — Base URL of Beeper Desktop
//                            (default: http://host.docker.internal:23373)
//    DEEPER_MESSAGE_LIMIT   — Max messages fetched per chat
//                            (default: unlimited; use e.g. 500 for faster syncs)
//    PORT                   — HTTP port to listen on (default: 8080)
//    HOST                   — Host to bind to (default: 0.0.0.0)
//

import Vapor

import Foundation

// MARK: - Entry point

@main
enum DeeperServerApp {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)

        let app = try await Application.make(env)
        defer { Task { try? await app.asyncShutdown() } }

        try await configure(app)
        try await app.execute()
    }
}

// MARK: - Application configuration

private func configure(_ app: Application) async throws {
    // Bind address
    let serverHost = Environment.get("HOST") ?? "0.0.0.0"
    let serverPort = Environment.get("PORT").flatMap(Int.init) ?? 8080
    app.http.server.configuration.hostname = serverHost
    app.http.server.configuration.port = serverPort

    // Credentials — required
    guard let token = Environment.get("BEEPER_TOKEN"), !token.isEmpty else {
        app.logger.critical("BEEPER_TOKEN environment variable is required but not set.")
        throw Abort(.internalServerError, reason: "BEEPER_TOKEN not configured")
    }
    let baseURL = Environment.get("BEEPER_BASE_URL") ?? "http://host.docker.internal:23373"

    // Build DataStore and perform initial sync before accepting requests
    let apiClient = BeeperAPIClient(baseURL: baseURL, token: token)
    let store = DataStore(api: apiClient)

    app.logger.info("Connecting to Beeper Desktop at \(baseURL)...")
    await store.sync()

    if let syncError = store.error {
        app.logger.warning("Initial sync completed with error: \(syncError)")
    } else {
        app.logger.info(
            "Initial sync complete. \(store.totalChats) chats, \(store.mergedPeople.count) contacts."
        )
    }

    // Register all API routes
    registerRoutes(app, store: store)
}

// MARK: - Route registration

private func registerRoutes(_ app: Application, store: DataStore) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    /// Encode any Encodable value as a JSON Response.
    func json<T: Encodable>(_ value: T) throws -> Response {
        let data = try encoder.encode(value)
        return Response(
            status: .ok,
            headers: HTTPHeaders([("Content-Type", "application/json")]),
            body: .init(data: data)
        )
    }

    // GET /health — liveness probe
    app.get("health") { _ in
        ["status": "ok"]
    }

    // GET /api/status — sync metadata and summary stats
    app.get("api", "status") { _ in
        struct StatusResponse: Encodable {
            let totalChats: Int
            let totalUnread: Int
            let messagesSentToday: Int
            let messagesReceivedToday: Int
            let isLoading: Bool
            let lastSyncDate: Date?
            let error: String?
        }
        return try json(StatusResponse(
            totalChats: store.totalChats,
            totalUnread: store.totalUnread,
            messagesSentToday: store.messagesSentToday,
            messagesReceivedToday: store.messagesReceivedToday,
            isLoading: store.isLoading,
            lastSyncDate: store.lastSyncDate,
            error: store.error
        ))
    }

    // GET /api/accounts — connected Beeper accounts
    app.get("api", "accounts") { _ in
        try json(store.accounts)
    }

    // GET /api/people — merged cross-platform contacts
    app.get("api", "people") { _ in
        try json(store.mergedPeople)
    }

    // GET /api/people/two-way — two-way connected contacts
    app.get("api", "people", "two-way") { _ in
        try json(store.twoWayPeople)
    }

    // GET /api/people/ghosted-by — contacts that ghost you
    app.get("api", "people", "ghosted-by") { _ in
        try json(store.theyGhostPeople)
    }

    // GET /api/people/i-ghost — contacts you ghost
    app.get("api", "people", "i-ghost") { _ in
        try json(store.iGhostPeople)
    }

    // GET /api/platforms — per-platform statistics
    app.get("api", "platforms") { _ in
        try json(store.platformStats)
    }

    // GET /api/activity — hourly message activity
    app.get("api", "activity") { _ in
        try json(store.hourlyActivity)
    }

    // GET /api/groups — group chat statistics
    app.get("api", "groups") { _ in
        struct GroupsResponse: Encodable {
            let platformStats: [PlatformGroupStats]
            let mostActive: [GroupInfo]
        }
        return try json(GroupsResponse(
            platformStats: store.groupStats,
            mostActive: store.mostActiveGroups
        ))
    }

    // GET /api/phrases?range=7d|30d|90d|all — phrase analytics
    app.get("api", "phrases") { req in
        let rangeParam = req.query[String.self, at: "range"] ?? "all"
        let range: AnalyticsDateRange
        switch rangeParam {
        case "7d":   range = .week
        case "30d":  range = .month
        case "90d":  range = .quarter
        default:     range = .all
        }
        return try json(store.phraseStats(for: range))
    }

    // GET /api/response-times?range=7d|30d|90d|all — response time statistics
    app.get("api", "response-times") { req in
        let rangeParam = req.query[String.self, at: "range"] ?? "all"
        let range: AnalyticsDateRange
        switch rangeParam {
        case "7d":   range = .week
        case "30d":  range = .month
        case "90d":  range = .quarter
        default:     range = .all
        }
        return try json(store.responseTimeStats(for: range))
    }

    // GET /api/reels — Instagram Reels sharing analytics
    app.get("api", "reels") { _ in
        struct ReelsResponse: Encodable {
            let entries: [ReelShareEntry]
            let totalSent: Int
            let totalReceived: Int
            let hasInstagram: Bool
        }
        return try json(ReelsResponse(
            entries: store.reelEntries,
            totalSent: store.totalReelsSent,
            totalReceived: store.totalReelsReceived,
            hasInstagram: store.hasInstagram
        ))
    }

    // POST /api/sync — trigger a fresh data sync (non-blocking, runs in background)
    app.post("api", "sync") { _ in
        Task { await store.sync() }
        return Response(status: .accepted)
    }
}
