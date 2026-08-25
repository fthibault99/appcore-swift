/// Product returned by AppCore's barcode endpoints.
public struct BarcodeProduct: Codable, Equatable, Sendable {
    public let barcode: String
    public let productName: String?
    public let description: String?
    public let brand: String?
    public let imageUrl: String?
    public let legoSetNumber: String?

    public init(
        barcode: String,
        productName: String? = nil,
        description: String? = nil,
        brand: String? = nil,
        imageUrl: String? = nil,
        legoSetNumber: String? = nil
    ) {
        self.barcode = barcode
        self.productName = productName
        self.description = description
        self.brand = brand
        self.imageUrl = imageUrl
        self.legoSetNumber = legoSetNumber
    }
}
