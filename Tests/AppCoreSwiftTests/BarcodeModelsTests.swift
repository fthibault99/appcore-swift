import Foundation
import XCTest
@testable import AppCoreSwift

final class BarcodeModelsTests: XCTestCase {
    func testDecodesBarcodeProductUsingAppCoreFieldNames() throws {
        let data = Data(
            #"{"barcode":"0057000613280","productName":"Classic Bricks","description":"Creative brick box","brand":"LEGO","imageUrl":"https://example.com/image.jpg","legoSetNumber":"4637-1"}"#.utf8
        )

        let product = try JSONDecoder().decode(BarcodeProduct.self, from: data)

        XCTAssertEqual(product.barcode, "0057000613280")
        XCTAssertEqual(product.productName, "Classic Bricks")
        XCTAssertEqual(product.description, "Creative brick box")
        XCTAssertEqual(product.brand, "LEGO")
        XCTAssertEqual(product.imageUrl, "https://example.com/image.jpg")
        XCTAssertEqual(product.legoSetNumber, "4637-1")
    }

    func testDecodesNullableProductFields() throws {
        let data = Data(
            #"{"barcode":"0057000613280","productName":null,"description":null,"brand":null,"imageUrl":null}"#.utf8
        )

        let product = try JSONDecoder().decode(BarcodeProduct.self, from: data)

        XCTAssertEqual(product, BarcodeProduct(barcode: "0057000613280"))
    }

    func testTranslationRequestKeepsBackendWrapperAndFieldNames() throws {
        let request = TranslateBarcodeProductRequest(
            targetLanguage: LanguageCode("fr")!,
            product: BarcodeProduct(barcode: "0057000613280", brand: "LEGO")
        )

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
        )
        let product = try XCTUnwrap(object["product"] as? [String: Any])

        XCTAssertEqual(object["targetLanguage"] as? String, "fr")
        XCTAssertEqual(product["barcode"] as? String, "0057000613280")
        XCTAssertEqual(product["brand"] as? String, "LEGO")
    }

    func testLanguageCodeNormalizesAndRejectsInvalidValues() {
        XCTAssertEqual(LanguageCode("FR")?.rawValue, "fr")
        XCTAssertNil(LanguageCode("French"))
        XCTAssertNil(LanguageCode("f"))
        XCTAssertNil(LanguageCode("f1"))
    }

    func testBarcodeDomainsUseValuesAcceptedByAppCore() {
        XCTAssertEqual(BarcodeDomain.food.pathComponent, "FOOD")
        XCTAssertEqual(BarcodeDomain.lego.pathComponent, "LEGO")
        XCTAssertEqual(BarcodeDomain.wine.pathComponent, "WINE")
    }
}
