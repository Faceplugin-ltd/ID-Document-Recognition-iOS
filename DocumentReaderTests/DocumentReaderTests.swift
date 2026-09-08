import XCTest
@testable import DocumentReader

final class DocumentReaderTests: XCTestCase {
    func testResultParserEmpty() {
        XCTAssertTrue(ResultParser.rows("").isEmpty)
    }

    func testResultRowsVerifyAndImageQAFromAndroidWire() {
        let json = """
        {"documentName":"CA DL","countryName":"United States","score":0.9,"errorCode":0,
         "verification":{"result":1,"label":"VERIFIED","checks":{
           "docType":{"result":1},"expiry":{"result":1},"text":{"result":1},
           "mrz":{"result":2},"security":{"result":2},
           "imageQA":{"result":0},"portrait":{"result":2}}},
         "imageQuality":{"checks":{"focus":0.973,"glares":0.512,"bounds":2,"custom":1.0}},
         "ocr":{"documentNumber":"X1","checkSums":"skip"},
         "mrz":{},
         "barcode":{"raw":"ABC"}}
        """
        let rows = ResultParser.rows(json)
        XCTAssertEqual(rows.first { $0.key == "overall" }?.value, "Verified")
        XCTAssertEqual(rows.first { $0.key == "imageQA" }?.value, "Fail (glares)")
        XCTAssertEqual(rows.first { $0.key == "focus" }?.value, "Pass")
        XCTAssertEqual(rows.first { $0.key == "glares" }?.value, "Fail")
        XCTAssertEqual(rows.first { $0.key == "bounds" }?.value, "Not checked")
        XCTAssertEqual(rows.first { $0.key == "custom" }?.value, "Pass")
    }

    func testResultRowsVerifyAndImageQA() {
        let json = """
        {"documentName":"CA DL","countryName":"United States","score":0.9,"errorCode":0,
         "verification":{"overall":0,"docType":0,"expiry":0,"text":0,"mrz":2,"security":2,"imageQA":1,"portrait":2},
         "imageQuality":{"checks":{"focus":1,"glares":0,"bounds":2,"custom":1}},
         "ocr":{"documentNumber":"X1","checkSums":"skip"},
         "mrz":{},
         "barcode":{"raw":"ABC"}}
        """
        let rows = ResultParser.rows(json)
        XCTAssertEqual(rows.map(\.source), [
            "meta", "meta", "meta", "meta",
            "Verify", "Verify", "Verify", "Verify", "Verify", "Verify", "Verify", "Verify",
            "Image QA", "Image QA", "Image QA", "Image QA",
            "OCR", "Barcode",
        ])
        XCTAssertEqual(rows.map(\.key), [
            "documentName", "countryName", "score", "errorCode",
            "overall", "docType", "expiry", "text", "mrz", "security", "imageQA", "portrait",
            "focus", "glares", "bounds", "custom",
            "documentNumber", "raw",
        ])
        XCTAssertEqual(rows.first { $0.key == "overall" }?.value, "Verified")
        XCTAssertEqual(rows.first { $0.key == "imageQA" }?.value, "Fail (glares)")
        XCTAssertEqual(rows.first { $0.key == "focus" }?.value, "Pass")
        XCTAssertEqual(rows.first { $0.key == "glares" }?.value, "Fail")
        XCTAssertEqual(rows.first { $0.key == "bounds" }?.value, "Not checked")
        XCTAssertEqual(rows.first { $0.key == "custom" }?.value, "Pass")
        XCTAssertTrue(ResultParser.summary(json).contains("Verification: Verified"))
    }

    func testImageQualityCheckResultOneIsPass() {
        let json = """
        {"verification":{"overall":0,"imageQA":1,"reasons":{"imageQA":["focus","glares","resolution"]}},
         "imageQuality":{"checks":{"focus":1,"glares":1,"resolution":1}}}
        """
        let rows = ResultParser.rows(json)
        XCTAssertEqual(rows.first { $0.key == "imageQA" }?.value, "Pass")
        XCTAssertEqual(rows.first { $0.key == "focus" }?.value, "Pass")
        XCTAssertEqual(rows.first { $0.key == "glares" }?.value, "Pass")
        XCTAssertEqual(rows.first { $0.key == "resolution" }?.value, "Pass")
    }

    func testImagesShowsEachCategoryOnce() {
        // 1×1 JPEG; long enough to pass the payload-length filter.
        let jpeg = "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/9oACAEBAAA/AHuUAP/Z"
        let json = """
        {"images":[
          {"name":"Portrait","source":"VISUAL","pageIndex":0,"image":"\(jpeg)"},
          {"name":"Portrait","source":"VISUAL","pageIndex":1,"image":"\(jpeg)"},
          {"name":"Document front side","source":"VISUAL","pageIndex":0,"image":"\(jpeg)"},
          {"name":"Document front side","source":"VISUAL","pageIndex":1,"image":"\(jpeg)"},
          {"name":"Portrait","source":"RFID","pageIndex":0,"image":"\(jpeg)"}
        ]}
        """
        let imgs = ResultParser.images(json)
        XCTAssertEqual(imgs.map(\.category), ["Portrait", "Document front side", "Portrait"])
        XCTAssertEqual(imgs.map(\.source), ["VISUAL", "VISUAL", "RFID"])
    }
}
