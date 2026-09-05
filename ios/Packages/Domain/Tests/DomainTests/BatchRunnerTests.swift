import Testing
@testable import Domain

@Suite struct BatchRunnerTests {
    @Test func checkpointArithmetic() {
        var c = BatchCheckpoint(batchId: "b1", photoCount: 3, pending: ["a", "b", "c"])
        c.apply(.processed, for: "a")
        c.apply(.skipped(reason: "duplicate"), for: "b")
        c.apply(.processed, for: "zzz") // unknown sha is ignored
        #expect(c.processed == 1)
        #expect(c.pending == ["c"])
        #expect(c.skipped == [BatchSkip(sha: "b", reason: "duplicate")])
        #expect(!c.isComplete)
    }

    @Test func foregroundRunnerPersistsAfterEveryStepAndResumes() async {
        actor Log { var states: [BatchCheckpoint] = []; func add(_ s: BatchCheckpoint) { states.append(s) } }
        let log = Log()
        let runner = ForegroundBatchRunner(persist: { await log.add($0) })
        let start = BatchCheckpoint(batchId: "b2", photoCount: 3, pending: ["a", "b", "c"])
        let end = await runner.run(start) { sha in sha == "b" ? .skipped(reason: "no clothes") : .processed }
        #expect(end.isComplete)
        #expect(end.processed == 2)
        #expect(end.skipped.map(\.sha) == ["b"])
        #expect(await log.states.count == 3)

        // Resume from a mid-way checkpoint only touches what is pending.
        let resumed = await runner.run(BatchCheckpoint(batchId: "b3", photoCount: 3, processed: 2, pending: ["c"])) { _ in .processed }
        #expect(resumed.processed == 3 && resumed.isComplete)
    }

    @Test func stepErrorsBecomeSkips() async {
        struct Boom: Error {}
        let runner = ForegroundBatchRunner()
        let end = await runner.run(BatchCheckpoint(batchId: "b4", photoCount: 1, pending: ["a"])) { _ in throw Boom() }
        #expect(end.skipped.count == 1 && end.processed == 0 && end.isComplete)
    }
}
