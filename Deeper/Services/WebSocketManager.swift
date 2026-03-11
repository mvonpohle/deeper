//
//  WebSocketManager.swift
//  Deeper
//
//  Created by Fatih Kadir Akın on 22.02.2026.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(Observation)
import Observation
#endif

@Observable
final class WebSocketManager: @unchecked Sendable {
    var isConnected = false
    var events: [WSEvent] = []
    var messageCount: Int = 0
    var chatUpdateCount: Int = 0

    private var webSocketTask: URLSessionWebSocketTask?
    private let baseURL: String
    private let token: String

    init(baseURL: String = "http://localhost:23373", token: String) {
        self.baseURL = baseURL
        self.token = token
    }

    func connect() {
        let wsURL = baseURL.replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")
        guard let components = URLComponents(string: wsURL + "/v1/ws") else { return }

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        isConnected = true

        sendSubscription()
        receiveMessages()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    private func sendSubscription() {
        let subscription = """
        {"type":"subscriptions.set","chatIDs":["*"]}
        """
        webSocketTask?.send(.string(subscription)) { [weak self] error in
            if let error {
                print("WebSocket subscription error: \(error)")
                self?.isConnected = false
            }
        }
    }

    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                self.receiveMessages()
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                Task { @MainActor in
                    self.isConnected = false
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: str) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(str)")
        }

        if let event = try? decoder.decode(WSEvent.self, from: data) {
            Task { @MainActor in
                self.events.insert(event, at: 0)
                if self.events.count > 200 {
                    self.events = Array(self.events.prefix(200))
                }
                switch event.type {
                case "message.upserted":
                    self.messageCount += 1
                case "chat.upserted", "chat.deleted":
                    self.chatUpdateCount += 1
                default:
                    break
                }
            }
        }
    }
}
