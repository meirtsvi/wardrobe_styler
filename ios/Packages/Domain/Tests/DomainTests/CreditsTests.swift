import Foundation
import Testing
@testable import Domain

@Suite struct CreditsTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func looksConversion() {
        #expect(Credits.credits(forLooks: 40) == 200)
        #expect(Credits.looks(fromCredits: 12) == 2)
        #expect(Credits.looks(fromCredits: -7) == -2)
        #expect(Credits.Metered.lookHD.credits == 10)
    }

    @Test func debitOrderGrantThenPurchased() throws {
        let b = CreditBalances(grant: 7, grantExpiresAt: now.addingTimeInterval(86_400), purchased: 20)
        let d1 = try Credits.debit(5, from: b, now: now)
        #expect(d1.bucket == .grant)
        #expect(d1.balances == CreditBalances(grant: 2, grantExpiresAt: b.grantExpiresAt, purchased: 20))
        let d2 = try Credits.debit(5, from: d1.balances, now: now)
        #expect(d2.bucket == .mixed)
        #expect(d2.grantUsed == 2 && d2.purchasedUsed == 3)
        #expect(d2.balances.purchased == 17)
        let d3 = try Credits.debit(5, from: d2.balances, now: now)
        #expect(d3.bucket == .purchased)
    }

    @Test func expiredGrantsCountAsZero() throws {
        let b = CreditBalances(grant: 50, grantExpiresAt: now.addingTimeInterval(-1), purchased: 5)
        #expect(b.effectiveGrant(at: now) == 0)
        let d = try Credits.debit(5, from: b, now: now)
        #expect(d.bucket == .purchased)
        #expect(throws: CreditError.insufficient(needed: 5, available: 0)) { try Credits.debit(5, from: d.balances, now: now) }
    }

    @Test func refundRestoresTheSameBuckets() throws {
        let b = CreditBalances(grant: 3, purchased: 10)
        let d = try Credits.debit(5, from: b, now: now)
        #expect(Credits.refund(d, to: d.balances) == b)
    }

    @Test func revokeGoesNegativeAndBlocks() {
        let b = Credits.revoke(purchased: 25, from: CreditBalances(grant: 40, purchased: 20))
        #expect(b.purchased == -5)
        #expect(b.grant == 40) // grants untouched
        #expect(!b.canGenerate(at: now))
        #expect(throws: CreditError.purchasedNegative) { try Credits.debit(5, from: b, now: now) }
    }

    @Test func dailyHardCapIsIndependentOfBalance() {
        let b = CreditBalances(grant: 1000, purchased: 1000)
        #expect(throws: CreditError.dailyCapReached(resetsAt: now)) { try Credits.debit(5, from: b, now: now, dailyUsed: 296) }
        #expect((try? Credits.debit(5, from: b, now: now, dailyUsed: 295)) != nil)
    }

    @Test func renewalRollsOverAtMostOneMonth() {
        let old = CreditBalances(grant: 60, grantExpiresAt: now.addingTimeInterval(3600), purchased: 0)
        let renewed = Credits.renewGrant(old, grant: 200, now: now, expiresAt: now.addingTimeInterval(30 * 86_400))
        #expect(renewed.grant == 260)
        let stale = CreditBalances(grant: 60, grantExpiresAt: now.addingTimeInterval(-3600), purchased: 0)
        #expect(Credits.renewGrant(stale, grant: 200, now: now, expiresAt: now).grant == 200)
    }

    @Test func displayIsInLooks() {
        let d = LooksDisplay(CreditBalances(grant: 60, grantExpiresAt: now, purchased: 100), now: now.addingTimeInterval(-1))
        #expect(d.planLooks == 12 && d.purchasedLooks == 20 && d.renewsAt == now)
    }
}
