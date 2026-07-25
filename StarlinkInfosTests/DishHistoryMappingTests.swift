import XCTest
@testable import StarlinkInfos

final class DishHistoryMappingTests: XCTestCase {
    func testEmptyBufferReturnsNoSamples() {
        let response = SpaceX_API_Device_DishGetHistoryResponse()
        XCTAssertEqual(DishClient.samples(from: response), [])
    }

    func testPartiallyFilledBufferReturnsOldestToNewest() {
        // Buffer size 5, only 3 samples ever written (current < size): the
        // first `current` slots hold real data, the rest are untouched zeros.
        let response = SpaceX_API_Device_DishGetHistoryResponse.with {
            $0.current = 3
            $0.popPingLatencyMs = [10, 20, 30, 0, 0]
        }
        let samples = DishClient.samples(from: response)
        XCTAssertEqual(samples.map(\.latencyMs), [10, 20, 30])
        XCTAssertEqual(samples.map(\.ageSeconds), [2, 1, 0])
    }

    func testWrappedBufferReturnsOldestToNewest() {
        // Buffer size 3, 7 samples ever written (current > size): the ring has
        // wrapped, so the write index (current % size == 1) marks the next
        // slot to be overwritten — the oldest surviving sample.
        let response = SpaceX_API_Device_DishGetHistoryResponse.with {
            $0.current = 7
            $0.popPingLatencyMs = [100, 200, 300]
        }
        let samples = DishClient.samples(from: response)
        XCTAssertEqual(samples.map(\.latencyMs), [200, 300, 100])
        XCTAssertEqual(samples.map(\.ageSeconds), [2, 1, 0])
    }

    func testMostRecentSampleIsAlwaysAgeZero() {
        let response = SpaceX_API_Device_DishGetHistoryResponse.with {
            $0.current = 42
            $0.popPingLatencyMs = Array(repeating: 1, count: 10)
        }
        XCTAssertEqual(DishClient.samples(from: response).last?.ageSeconds, 0)
    }
}

extension DishHistorySample: Equatable {
    public static func == (lhs: DishHistorySample, rhs: DishHistorySample) -> Bool {
        lhs.ageSeconds == rhs.ageSeconds
            && lhs.latencyMs == rhs.latencyMs
            && lhs.downlinkBps == rhs.downlinkBps
            && lhs.uplinkBps == rhs.uplinkBps
            && lhs.dropRate == rhs.dropRate
    }
}
