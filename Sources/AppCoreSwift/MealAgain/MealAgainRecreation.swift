import Foundation

public enum MealAgainCreditSource: String, Codable, Equatable, Sendable {
    case free = "FREE"
    case purchased = "PURCHASED"
    case lifetime = "LIFETIME"
}

public struct MealAgainRecreationStatusResponse: Codable, Equatable, Sendable {
    public let userId: UUID
    public let lifetimeAccess: Bool
    public let freeRemaining: Int
    public let purchasedRemaining: Int
    public let totalRemaining: Int64?
    public let unlimited: Bool
    public let canRecreate: Bool

    public init(
        userId: UUID,
        lifetimeAccess: Bool,
        freeRemaining: Int,
        purchasedRemaining: Int,
        totalRemaining: Int64?,
        unlimited: Bool,
        canRecreate: Bool
    ) {
        self.userId = userId
        self.lifetimeAccess = lifetimeAccess
        self.freeRemaining = freeRemaining
        self.purchasedRemaining = purchasedRemaining
        self.totalRemaining = totalRemaining
        self.unlimited = unlimited
        self.canRecreate = canRecreate
    }
}

public struct MealAgainPurchaseRequest: Codable, Equatable, Sendable {
    public let transactionId: String
    public let productId: String
    public let signedTransactionInfo: String

    public init(
        transactionId: String,
        productId: String,
        signedTransactionInfo: String
    ) {
        self.transactionId = transactionId
        self.productId = productId
        self.signedTransactionInfo = signedTransactionInfo
    }
}

public struct MealAgainPurchaseResponse: Codable, Equatable, Sendable {
    public let credited: Bool
    public let alreadyProcessed: Bool
    public let creditsGranted: Int
    public let freeRemaining: Int
    public let purchasedRemaining: Int

    public init(
        credited: Bool,
        alreadyProcessed: Bool,
        creditsGranted: Int,
        freeRemaining: Int,
        purchasedRemaining: Int
    ) {
        self.credited = credited
        self.alreadyProcessed = alreadyProcessed
        self.creditsGranted = creditsGranted
        self.freeRemaining = freeRemaining
        self.purchasedRemaining = purchasedRemaining
    }
}

public struct MealAgainConsumeRecreationRequest: Codable, Equatable, Sendable {
    public let recreationId: UUID?

    public init(
        recreationId: UUID?
    ) {
        self.recreationId = recreationId
    }
}

public struct MealAgainConsumeRecreationResponse: Codable, Equatable, Sendable {
    public let consumed: Bool
    public let alreadyProcessed: Bool
    public let creditSource: MealAgainCreditSource
    public let freeRemaining: Int
    public let purchasedRemaining: Int
    public let unlimited: Bool

    public init(
        consumed: Bool,
        alreadyProcessed: Bool,
        creditSource: MealAgainCreditSource,
        freeRemaining: Int,
        purchasedRemaining: Int,
        unlimited: Bool
    ) {
        self.consumed = consumed
        self.alreadyProcessed = alreadyProcessed
        self.creditSource = creditSource
        self.freeRemaining = freeRemaining
        self.purchasedRemaining = purchasedRemaining
        self.unlimited = unlimited
    }
}
