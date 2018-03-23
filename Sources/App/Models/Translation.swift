import Foundation

// MARK: - Declaration

/// A basic translation representation.
/// This protocol allows us to declare similar types with less code,
/// i.e. a single generic controller instead of two seperate controllers.
///
/// This protocol requires it's implementors to be a class, conform to `Content`, `Model`, `Migration`, and `Parameter`,
/// and that it's `Database` type is `MySQLDatabase`, that `ID` is `String`, and `ResolvedParameter` is `Future<Self>`.
protocol Translation: class, Content, Model, Migration, Parameter where Self.Database == MySQLDatabase, Self.ID == String, Self.ResolvedParameter == Future<Self> {
    
    /// The name of the translation.
    /// This property is used for the model's database ID, instead of an `Int`.
    var name: String? { get set }
    
    /// The description of the translation.
    var description: String { get set }
    
    /// The language code of the translation, i.e. 'en', 'es', etc.
    var languageCode: String { get set }
}

/// Default implementations of methods and computed properties for the `Translation` protocol.
extension Translation {
    
    /// The default implementation of the `idKey` property required by the `Model` protocol.
    /// The keypath returned defaults to the model's `name` property.
    static var idKey: WritableKeyPath<Self, String?> {
        return \.name
    }
    
    /// Create a `TranslationResponseBody` from the current translation model.
    ///
    /// - Parameter executor: The object used to get models connected to the current translation.
    /// - Returns: A `TranslationResponseBody`, wrapped in a future.
    func response(on request: Request) -> Future<TranslationResponseBody> {
        /// Get the price connected to the current translation if it is a `ProductTranslation`.
        /// Otherwise, set it to `nil`
        let price: Future<Price?> = Future.flatMap(on: request, {
            if let productTranslation = self as? ProductTranslation, let id = productTranslation.priceId {
                return try Price.find(id, on: request)
            } else {
                return Future.map(on: request, { nil })
            }
        })
        
        /// Create a new `ProductTranslation` with the fetched `Price` model and the current translation model.
        return price.map(to: TranslationResponseBody.self, { (price) in
            return TranslationResponseBody(self, price: price)
        })
    }
}

// MARK: - Implementations

/// An implementation for the `Translation` protocol that a `Product` model connects to.
final class ProductTranslation: Translation, TranslationRequestInitializable {
    
    /// The name of the translation.
    /// This property is used as the database identifier.
    var name: String?
    
    /// A description of the translation.
    var description: String
    
    /// The code of the language the translation is in.
    var languageCode: String
    
    /// The database ID of the `Price` model for the product in the region
    /// that the translation is used for.
    var priceId: Price.ID?
    
    ///
    init(name: String, description: String, languageCode: String, priceId: Price.ID?) {
        self.name = name
        self.description = description
        self.languageCode = languageCode
        self.priceId = priceId
    }
    
    /// Creates a `ProductTranslation` from a `TranslationRequestContent`,
    /// saves it to the database, and converts it to a `TranslationResponseBody`.
    ///
    /// - Parameters:
    ///   - content: A `TranslationRequestContent`, created from a request's body.
    ///   - request: The request that the body when fetched from.
    /// - Returns: A `TranslationResponseBody`, wrapped in a future.
    static func create(from content: TranslationRequestContent, with request: Request) -> Future<TranslationResponseBody> {
        // Verify that a `price` value was passed into the request body.
        guard let amount = content.price else {
            return Future.map(on: request, { throw Abort(.badRequest, reason: "Request body must contain 'price' key") })
        }
        
        // Create a new `Price` model.
        let price = Price(price: amount, activeFrom: content.priceActiveFrom, activeTo: content.priceActiveTo, active: content.priceActive, translationName: content.name)
        
        // Save the price to the database, and return the result of the future's callback.
        return price.save(on: request).flatMap(to: TranslationResponseBody.self) { (price) in
            
            // Create a new `ProductTranslation`, save it to the database, and convert it to a `TranslationResponseBody`.
            return try ProductTranslation(name: content.name, description: content.description, languageCode: content.languageCode, priceId: price.requireID())
                .save(on: request).response(on: request)
        }
    }
}

/// An implementation for the `Translation` protocol that a `Category` model connects to.
final class CategoryTranslation: Translation, TranslationRequestInitializable {
    
    /// The name of the translation.
    /// This property is used as the database identifier.
    var name: String?
    
    /// A description of the translation.
    var description: String
    
    /// The code of the language the translation is in.
    var languageCode: String
    
    ///
    init(name: String, description: String, languageCode: String) {
        self.name = name
        self.description = description
        self.languageCode = languageCode
    }
    
    /// Creates a `CategoryTranslation` from a `TranslationRequestContent`,
    /// saves it to the database, and converts it to a `TranslationResponseBody`.
    ///
    /// - Parameters:
    ///   - content: A `TranslationRequestContent`, created from a request's body.
    ///   - request: The request that the body when fetched from.
    /// - Returns: A `TranslationResponseBody`, wrapped in a future.
    static func create(from content: TranslationRequestContent, with request: Request) -> Future<TranslationResponseBody> {
        
        // Create a `CategoryTranslation`, save it to the database, ans convert it to a `TranslationResponseBody`.
        return CategoryTranslation(name: content.name, description: content.description, languageCode: content.languageCode).save(on: request).response(on: request)
    }
}

// MARK: - Public

/// Defines a type as being able to be created from a request body formatted as `TranslationRequestContent`
/// and getting converted to a `TranslationResponseBody`
protocol TranslationRequestInitializable {
    
    ///
    static func create(from content: TranslationRequestContent, with request: Request) -> Future<TranslationResponseBody>
}

/// A representation of a request body, used to create a translation type.
struct TranslationRequestContent: Content {
    
    ///
    let name: String
    
    ///
    let description: String
    
    ///
    let languageCode: String
    
    ///
    let price: Float?
    
    ///
    let priceActiveFrom: Date?
    
    ///
    let priceActiveTo: Date?
    
    ///
    let priceActive: Bool?
}

/// A representation of a translation type that gets returned from a route handler.
struct TranslationResponseBody: Content {
    
    /// The name of the translation
    let name: String?
    
    /// The descripton of the trsnaltion
    let description: String
    
    /// The language code for the translation.
    let languageCode: String
    
    /// If the translation is a `ProductTranslation`,
    /// this is the trenslation's connected `Price` model.
    let price: Price?
    
    /// Creates a `TranslationResponseBody` from an object that conforms to `Translation`
    /// and a price (only used if the `translation` parameter type is `ProductTranslation`).
    init<Tran>(_ translation: Tran, price: Price?) where Tran: Translation {
        self.name = translation.name
        self.description = translation.description
        self.languageCode = translation.languageCode
        
        if translation as? ProductTranslation != nil {
            self.price = price
        } else { self.price = nil }
    }
}
