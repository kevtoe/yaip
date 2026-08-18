import Foundation
import XCTest
@testable import Yaip

final class ModelRepositoryDownloaderTests: XCTestCase {

    func testNormalConfigurationDoesNotOverrideProxySettings() {
        let configuration = ModelDownloadConfiguration.standard()
        XCTAssertNil(configuration.connectionProxyDictionary)
    }

    func testHTMLInterstitialIsRejectedEvenWithHTTP200() throws {
        let url = try XCTUnwrap(URL(string: "https://gateway.example/caution"))
        let response = try XCTUnwrap(HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/html"]
        ))
        XCTAssertThrowsError(
            try ModelRepositoryDownloader.validateResponse(
                data: Data("<!DOCTYPE html><title>Caution</title>".utf8),
                response: response,
                expectedJSON: true
            )
        ) { error in
            XCTAssertEqual(
                error as? ModelRepositoryError,
                .htmlResponse(status: 200, host: "gateway.example", contentType: "text/html")
            )
        }
    }

    func testHTMLSniffingWorksWhenMimeTypeLies() throws {
        let url = try XCTUnwrap(URL(string: "https://huggingface.co/model.bin"))
        let response = try XCTUnwrap(HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/octet-stream"]
        ))
        XCTAssertThrowsError(
            try ModelRepositoryDownloader.validateResponse(
                data: Data("<html>blocked</html>".utf8),
                response: response,
                expectedJSON: false
            )
        )
    }

    func testValidJSONAndBinaryResponsesPass() throws {
        let url = try XCTUnwrap(URL(string: "https://huggingface.co/api/models/example"))
        let json = try XCTUnwrap(HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        ))
        XCTAssertNoThrow(
            try ModelRepositoryDownloader.validateResponse(
                data: Data("[]".utf8),
                response: json,
                expectedJSON: true
            )
        )
        let binary = try XCTUnwrap(HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/octet-stream"]
        ))
        XCTAssertNoThrow(
            try ModelRepositoryDownloader.validateResponse(
                data: Data([0, 1, 2, 3]),
                response: binary,
                expectedJSON: false
            )
        )
    }
}
