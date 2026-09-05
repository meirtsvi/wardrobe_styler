// Credit arithmetic (PLAN §7.2 "Credit metering (two buckets)", §9.2). Pure, unit-tested; the server ledger applies the same rules in a transaction.
import Foundation

public enum CreditBucket: String, Codable, Sendable { case grant, purchased, mixed }

public struct CreditBalances: Codable, Equatable, Sendable {
    public var grant: Int
    public var grantExpiresAt: Date?
    public var purchased: Int

    public init(grant: Int, grantExpiresAt: Date? = nil, purchased: Int) {
        self.grant = grant; self.grantExpiresAt = grantExpiresAt; self.purchased = purchased
    }

    /// Expired grants count as zero (the purge job zeroes them; the client must not display or spend them).
    public func effectiveGrant(at now: Date) -> Int {
        if let exp = grantExpiresAt, exp <= now { return 0 }
        return max(0, grant)
    }

    /// Purchased credits can go negative after an Apple refund/revoke; that blocks generation until topped up.
    public func canGenerate(at now: Date) -> Bool { purchased >= 0 && (effectiveGrant(at: now) + purchased) > 0 }
    public func total(at now: Date) -> Int { effectiveGrant(at: now) + purchased }
}

public struct CreditDebit: Equatable, Sendable {
    public var balances: CreditBalances
    public var bucket: CreditBucket
    public var grantUsed: Int
    public var purchasedUsed: Int
}

public enum CreditError: Error, Equatable, Sendable {
    case insufficient(needed: Int, available: Int)
    case purchasedNegative
    case dailyCapReached(resetsAt: Date)
}

public enum Credits {
    /// One user-facing Look = 5 internal credits (§9.2). Prices come from Remote Config in production; these are the client defaults.
    public static let creditsPerLook = 5
    public static let dailyHardCapCredits = 300 // = 60 Looks, independent of balance (§7.2)

    public enum Metered: Sendable {
        case lookStandard, lookHD, twin, glowUp
        public var credits: Int {
            switch self {
            case .lookStandard, .glowUp: return Credits.creditsPerLook
            case .lookHD, .twin: return 2 * Credits.creditsPerLook
            }
        }
    }

    public static func looks(fromCredits credits: Int) -> Int { credits >= 0 ? credits / creditsPerLook : -((-credits + creditsPerLook - 1) / creditsPerLook) }
    public static func credits(forLooks looks: Int) -> Int { looks * creditsPerLook }

    /// Debit order grant → purchased (§7.2). Fails without touching balances when the total is short or purchased is negative.
    public static func debit(_ amount: Int, from balances: CreditBalances, now: Date, dailyUsed: Int = 0, dailyResetAt: Date? = nil) throws -> CreditDebit {
        precondition(amount > 0, "debit amount must be positive")
        if balances.purchased < 0 { throw CreditError.purchasedNegative }
        if dailyUsed + amount > dailyHardCapCredits { throw CreditError.dailyCapReached(resetsAt: dailyResetAt ?? now) }
        let grant = balances.effectiveGrant(at: now)
        let available = grant + balances.purchased
        if available < amount { throw CreditError.insufficient(needed: amount, available: available) }
        let fromGrant = min(grant, amount)
        let fromPurchased = amount - fromGrant
        var next = balances
        next.grant = grant - fromGrant
        next.purchased -= fromPurchased
        let bucket: CreditBucket = fromPurchased == 0 ? .grant : (fromGrant == 0 ? .purchased : .mixed)
        return CreditDebit(balances: next, bucket: bucket, grantUsed: fromGrant, purchasedUsed: fromPurchased)
    }

    /// Refund on terminal failure in the same shape and buckets as the debit (§7.2).
    public static func refund(_ debit: CreditDebit, to balances: CreditBalances) -> CreditBalances {
        var next = balances
        next.grant += debit.grantUsed
        next.purchased += debit.purchasedUsed
        return next
    }

    /// Apple refund/revoke hits purchased only and may go negative (§7.2, §9.2).
    public static func revoke(purchased amount: Int, from balances: CreditBalances) -> CreditBalances {
        var next = balances
        next.purchased -= amount
        return next
    }

    /// Monthly Plus grant: rolls over at most one month, i.e. the new balance is the new grant plus whatever is still unexpired (§9.2).
    public static func renewGrant(_ balances: CreditBalances, grant: Int, now: Date, expiresAt: Date) -> CreditBalances {
        var next = balances
        next.grant = balances.effectiveGrant(at: now) + grant
        next.grantExpiresAt = expiresAt
        return next
    }
}

/// "12 Looks from your plan (renews 3 Oct) · 20 purchased" — the only denomination the user ever sees (§9.2).
public struct LooksDisplay: Equatable, Sendable {
    public let planLooks: Int
    public let purchasedLooks: Int
    public let renewsAt: Date?

    public init(_ balances: CreditBalances, now: Date) {
        planLooks = Credits.looks(fromCredits: balances.effectiveGrant(at: now))
        purchasedLooks = Credits.looks(fromCredits: balances.purchased)
        renewsAt = balances.grantExpiresAt
    }
}
