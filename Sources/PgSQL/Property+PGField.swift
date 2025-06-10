import FluentPostgresDriver

public extension FieldProperty {
    convenience init(_ params: PGField) {
        self.init(key: .string(params.name))
    }
}

public extension BooleanProperty {
    convenience init(_ params: PGField, format: Format) {
        self.init(key: .string(params.name), format: format)
    }
}

public extension EnumProperty {
    convenience init(_ params: PGField) {
        self.init(key: .string(params.name))
    }
}

public extension ParentProperty {
    convenience init(_ params: PGField) {
        self.init(key: .string(params.name))
    }
}

public extension OptionalBooleanProperty {
    convenience init(_ params: PGField, format: Format) {
        self.init(key: .string(params.name), format: format)
    }
}

public extension OptionalParentProperty {
    convenience init(_ params: PGField) {
        self.init(key: .string(params.name))
    }
}

public extension OptionalEnumProperty {
    convenience init(_ params: PGField) {
        self.init(key: .string(params.name))
    }
}

public extension TimestampProperty {
    convenience init(
        _ params: PGField,
        on trigger: TimestampTrigger,
        format: TimestampFormatFactory<Format> = .iso8601(withMilliseconds: true)
    ) {
        self.init(key: .string(params.name), on: trigger, format: format.makeFormat())
    }
    
    convenience init(_ params: PGField, on trigger: TimestampTrigger, format: Format) {
        self.init(key: .string(params.name), on: trigger, format: format)
    }
}
