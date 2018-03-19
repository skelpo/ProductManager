final class AttributesController: RouteCollection {
    func boot(router: Router) throws {
        let attributes = router.grouped("products", Product.parameter, "attributes")
        
        attributes.get(use: index)
        
        attributes.post(Attribute.self, use: create)
    }
    
    func index(_ request: Request)throws -> Future<[Attribute]> {
        return try request.parameter(Product.self).flatMap(to: [Attribute].self, { try $0.attributes.query(on: request).all() })
    }
    
    func create(_ request: Request, _ attribute: Attribute)throws -> Future<Attribute> {
        return Attribute.query(on: request).filter(\.name == attribute.name).count().flatMap(to: Attribute.self) { (attributeCount) in
            guard attributeCount < 1 else {
                throw Abort(.badRequest, reason: "Attribute already exists for product with name '\(attribute.name)'")
            }
            return attribute.save(on: request)
        }
    }
}


