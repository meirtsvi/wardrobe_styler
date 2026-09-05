// BatchRunner protocol (PLAN §6 "Jobs" module). The iOS-26 implementation uses BGContinuedProcessingTask with an expiration handler that
// checkpoints `batches/{id}`; a BGProcessingTask + foreground stub keeps an iOS 18 minimum possible without touching feature code.
import Foundation

public struct BatchCheckpoint: Codable, Equatable, Sendable {
    public var batchId: String
    public var photoCount: Int
    public var processed: Int
    public var pending: [String] // photo sha256s still to run
    public var skipped: [BatchSkip]

    public init(batchId: String, photoCount: Int, processed: Int = 0, pending: [String], skipped: [BatchSkip] = []) {
        self.batchId = batchId; self.photoCount = photoCount; self.processed = processed; self.pending = pending; self.skipped = skipped
    }

    public var isComplete: Bool { pending.isEmpty }
}

public struct BatchSkip: Codable, Equatable, Sendable {
    public var sha: String
    public var reason: String
    public init(sha: String, reason: String) { self.sha = sha; self.reason = reason }
}

public enum BatchStepResult: Equatable, Sendable {
    case processed
    case skipped(reason: String)
}

/// Runs one batch of on-device photo work (resize, hash, Vision masks, provisional cutouts) with checkpoint/resume semantics.
public protocol BatchRunner: Sendable {
    /// Starts or resumes `checkpoint`. `step` performs the work for one photo sha and is called serially.
    /// The runner persists the checkpoint after every step and on expiration, and returns the final state (complete or interrupted).
    func run(_ checkpoint: BatchCheckpoint, step: @Sendable (String) async throws -> BatchStepResult) async -> BatchCheckpoint
    func cancel(batchId: String) async
}

/// Applies one step result to a checkpoint. Shared by every runner implementation so resume arithmetic is tested once.
public extension BatchCheckpoint {
    mutating func apply(_ result: BatchStepResult, for sha: String) {
        guard let idx = pending.firstIndex(of: sha) else { return }
        pending.remove(at: idx)
        switch result {
        case .processed: processed += 1
        case .skipped(let reason): skipped.append(BatchSkip(sha: sha, reason: reason))
        }
    }
}

/// Foreground-only runner: processes until the caller cancels. Used in tests and as the iOS 18 fallback's foreground half.
public actor ForegroundBatchRunner: BatchRunner {
    private var cancelled: Set<String> = []
    private let persist: @Sendable (BatchCheckpoint) async -> Void

    public init(persist: @escaping @Sendable (BatchCheckpoint) async -> Void = { _ in }) { self.persist = persist }

    public func run(_ checkpoint: BatchCheckpoint, step: @Sendable (String) async throws -> BatchStepResult) async -> BatchCheckpoint {
        var state = checkpoint
        cancelled.remove(state.batchId)
        while let sha = state.pending.first, !cancelled.contains(state.batchId) {
            let result: BatchStepResult
            do { result = try await step(sha) } catch { result = .skipped(reason: "\(error)") }
            state.apply(result, for: sha)
            await persist(state)
        }
        return state
    }

    public func cancel(batchId: String) async { cancelled.insert(batchId) }
}
