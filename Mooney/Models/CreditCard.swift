import Foundation

// Best-effort deep link target for the Dashboard's quick-open button.
// URL schemes for Chase/Amex aren't officially documented and may stop
// working without notice — MACU has no known app scheme at all, so it
// always falls back to its website. Apple Wallet's "shoebox://" scheme is
// long-standing and reliable.
enum BankApp: String, Codable, CaseIterable, Identifiable {
    case chase, amex, macu, apple

    var id: String { rawValue }

    var label: String {
        switch self {
        case .chase: return "Chase"
        case .amex:  return "Amex"
        case .macu:  return "MACU"
        case .apple: return "Apple"
        }
    }

    var appURL: URL? {
        switch self {
        case .chase: return URL(string: "chase://")
        case .amex:  return URL(string: "amex://")
        case .macu:  return nil
        case .apple: return URL(string: "shoebox://")
        }
    }

    var webFallbackURL: URL? {
        switch self {
        case .chase: return URL(string: "https://chase.com")
        case .amex:  return URL(string: "https://americanexpress.com")
        case .macu:  return URL(string: "https://www.macu.com")
        case .apple: return URL(string: "https://card.apple.com")
        }
    }
}

struct CreditCard: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var dueDay: Int  // 1-31, day of month the payment is due
    var isActive: Bool
    var bankApp: BankApp?

    enum CodingKeys: String, CodingKey {
        case id, name, dueDay, isActive, bankApp
    }

    init(id: String, name: String, dueDay: Int, isActive: Bool, bankApp: BankApp? = nil) {
        self.id = id
        self.name = name
        self.dueDay = dueDay
        self.isActive = isActive
        self.bankApp = bankApp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        dueDay = try container.decode(Int.self, forKey: .dueDay)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        bankApp = try container.decodeIfPresent(BankApp.self, forKey: .bankApp)
    }
}
