import XCTest
@testable import StarlinkInfos

final class RSSParserTests: XCTestCase {
    func testParsesItemsSortedByDateDescending() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
          <channel>
            <item>
              <title>Older article</title>
              <link>https://example.com/older</link>
              <pubDate>Wed, 22 Jul 2026 10:00:00 GMT</pubDate>
              <source>Example News</source>
            </item>
            <item>
              <title>Newer article</title>
              <link>https://example.com/newer</link>
              <pubDate>Fri, 24 Jul 2026 10:00:00 GMT</pubDate>
              <source>Example News</source>
            </item>
          </channel>
        </rss>
        """
        let articles = RSSParser().parse(Data(xml.utf8))

        XCTAssertEqual(articles.map(\.title), ["Newer article", "Older article"])
        XCTAssertEqual(articles.map(\.source), ["Example News", "Example News"])
        XCTAssertEqual(articles.first?.link, URL(string: "https://example.com/newer"))
    }

    func testSkipsItemsMissingATitleOrLink() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
          <channel>
            <item>
              <title>Has everything</title>
              <link>https://example.com/ok</link>
              <pubDate>Fri, 24 Jul 2026 10:00:00 GMT</pubDate>
            </item>
            <item>
              <title></title>
              <link>https://example.com/no-title</link>
              <pubDate>Fri, 24 Jul 2026 10:00:00 GMT</pubDate>
            </item>
            <item>
              <title>No link</title>
              <link></link>
              <pubDate>Fri, 24 Jul 2026 10:00:00 GMT</pubDate>
            </item>
          </channel>
        </rss>
        """
        let articles = RSSParser().parse(Data(xml.utf8))

        XCTAssertEqual(articles.map(\.title), ["Has everything"])
    }

    func testEmptyFeedReturnsNoArticles() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0"><channel></channel></rss>
        """
        XCTAssertEqual(RSSParser().parse(Data(xml.utf8)), [])
    }
}
