import XCTest
@testable import StarlinkInfos

/// Sorties réelles capturées en vol (Wi-Fi Air France via Starlink, 2026-10-12).
final class LinkParsersTests: XCTestCase {
    func testPingSummary() {
        let out = """
        --- 1.1.1.1 ping statistics ---
        10 packets transmitted, 9 packets received, 10.0% packet loss
        round-trip min/avg/max/stddev = 19.742/28.164/45.168/7.453 ms
        """
        let r = LinkParsers.ping(out)
        XCTAssertEqual(r.min, 19.742)
        XCTAssertEqual(r.avg, 28.164)
        XCTAssertEqual(r.max, 45.168)
        XCTAssertEqual(r.stddev, 7.453)
        XCTAssertEqual(r.lossPct, 10.0)
    }

    func testPingTotalLossHasNoRTT() {
        let out = """
        --- 100.64.0.1 ping statistics ---
        3 packets transmitted, 0 packets received, 100.0% packet loss
        """
        let r = LinkParsers.ping(out)
        XCTAssertNil(r.avg)
        XCTAssertEqual(r.lossPct, 100.0)
    }

    func testPingEmptyOutputIsTotalLoss() {
        XCTAssertEqual(LinkParsers.ping("").lossPct, 100.0)
    }

    func testHopAllProbesAnswered() {
        let out = """
        traceroute to 1.1.1.1 (1.1.1.1), 2 hops max, 40 byte packets
         2  100.64.0.1  55.940 ms  26.921 ms  27.615 ms  30.673 ms  23.893 ms
        """
        let r = LinkParsers.hop(out, probes: 5)
        XCTAssertEqual(r.address, "100.64.0.1")
        XCTAssertEqual(r.avg!, 33.0084, accuracy: 0.0001)
        XCTAssertEqual(r.lossPct, 0)
    }

    func testHopPartialLoss() {
        let out = " 2  100.64.0.1  30.000 ms *  20.000 ms * *\n"
        let r = LinkParsers.hop(out, probes: 5)
        XCTAssertEqual(r.avg, 25.0)
        XCTAssertEqual(r.lossPct, 60.0)
    }

    func testHopNoAnswer() {
        let r = LinkParsers.hop(" 2  * * * * *\n", probes: 5)
        XCTAssertEqual(r.address, "")
        XCTAssertNil(r.avg)
        XCTAssertEqual(r.lossPct, 100)
    }

    func testPopCode() {
        XCTAssertEqual(LinkParsers.popCode(hostname: "customer.frtabra1.isp.starlink.com"), "frtabra1")
        XCTAssertNil(LinkParsers.popCode(hostname: "lfbn-par-1-123.w90-1.abo.wanadoo.fr"))
        XCTAssertNil(LinkParsers.popCode(hostname: ""))
    }

    func testPopChangesIgnoreGapsWithoutCode() {
        func s(_ t: TimeInterval, _ code: String) -> LinkSample {
            LinkSample(date: Date(timeIntervalSince1970: t), rttMin: nil, rttAvg: nil, rttMax: nil,
                       rttStddev: nil, lossPct: 0, publicIP: "", hostname: "", popCode: code,
                       popCity: "", popCountry: "", spaceHop: "", spaceRttAvg: nil, spaceLossPct: 0)
        }
        let samples = [s(0, "frtabra1"), s(30, ""), s(60, "frtabra1"), s(90, "brsaopa1")]
        XCTAssertEqual(LinkStats.popChanges(samples).map(\.popCode), ["frtabra1", "brsaopa1"])
    }

    func testCSVHeaderMatchesFlightScript() {
        let csv = LinkCSV.export([])
        XCTAssertEqual(csv, "utc,rtt_min,rtt_avg,rtt_max,rtt_stddev,loss_pct,public_ip,hostname,"
            + "pop_city,pop_country,pop_code,space_hop,space_rtt_avg,space_loss_pct\n")
    }

    func testCSVEscapesCommas() {
        let sample = LinkSample(date: Date(timeIntervalSince1970: 0), rttMin: 1, rttAvg: 2, rttMax: 3,
                                rttStddev: 0.5, lossPct: 0, publicIP: "1.2.3.4", hostname: "h",
                                popCode: "x", popCity: "Paris, FR", popCountry: "FR",
                                spaceHop: "100.64.0.1", spaceRttAvg: nil, spaceLossPct: 100)
        let row = LinkCSV.export([sample]).split(separator: "\n")[1]
        XCTAssertEqual(row, "1970-01-01T00:00:00Z,1.000,2.000,3.000,0.500,0.000,1.2.3.4,h,\"Paris, FR\",FR,x,100.64.0.1,,100.000")
    }
}
