//
//  PlatformInfo.swift
//  Deeper
//
//  Created by Fatih Kadir Akın on 22.02.2026.
//

#if canImport(SwiftUI)
import SwiftUI
#endif

enum Platform: String, CaseIterable, Identifiable, Sendable, Hashable, Codable {
    case whatsapp
    case telegram
    case instagram
    case twitter
    case signal
    case facebook
    case discord
    case slack
    case linkedin
    case googlechat
    case imessage
    case gmessages
    case androidsms
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .whatsapp: "WhatsApp"
        case .telegram: "Telegram"
        case .instagram: "Instagram"
        case .twitter: "X (Twitter)"
        case .signal: "Signal"
        case .facebook: "Messenger"
        case .discord: "Discord"
        case .slack: "Slack"
        case .linkedin: "LinkedIn"
        case .googlechat: "Google Chat"
        case .imessage: "iMessage"
        case .gmessages: "Google Messages"
        case .androidsms: "SMS"
        case .unknown: "Unknown"
        }
    }

    var iconName: String {
        switch self {
        case .whatsapp: "phone.bubble.fill"
        case .telegram: "paperplane.fill"
        case .instagram: "camera.fill"
        case .twitter: "at"
        case .signal: "lock.shield.fill"
        case .facebook: "person.2.fill"
        case .discord: "gamecontroller.fill"
        case .slack: "number"
        case .linkedin: "briefcase.fill"
        case .googlechat: "bubble.left.and.bubble.right.fill"
        case .imessage: "message.fill"
        case .gmessages: "message.fill"
        case .androidsms: "phone.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }

#if canImport(SwiftUI)
    var color: Color {
        switch self {
        case .whatsapp: .green
        case .telegram: .blue
        case .instagram: .pink
        case .twitter: .primary
        case .signal: .blue
        case .facebook: .indigo
        case .discord: .purple
        case .slack: .orange
        case .linkedin: .blue
        case .googlechat: .green
        case .imessage: .blue
        case .gmessages: .mint
        case .androidsms: .teal
        case .unknown: .gray
        }
    }
#endif

    // Maps bridge keywords → Platform. Order matters: longer/more specific first.
    private static let bridgeKeywords: [(keyword: String, platform: Platform)] = [
        ("whatsapp", .whatsapp),
        ("telegram", .telegram),
        ("instagram", .instagram),
        ("twitter", .twitter),
        ("signal", .signal),
        ("facebook", .facebook),
        ("messenger", .facebook),
        ("meta", .facebook),
        ("discord", .discord),
        ("slack", .slack),
        ("linkedin", .linkedin),
        ("googlechat", .googlechat),
        ("gchat", .googlechat),
        ("imessage-cloud", .imessage),
        ("imessagego", .imessage),
        ("imessage", .imessage),
        ("gmessages", .gmessages),
        ("androidsms", .androidsms),
        ("sms", .androidsms),
    ]

    static func from(accountID: String) -> Platform {
        let lowered = accountID.lowercased()
        for entry in bridgeKeywords {
            if lowered.contains(entry.keyword) {
                return entry.platform
            }
        }
        return .unknown
    }
}
