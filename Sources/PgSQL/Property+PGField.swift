import FluentPostgresDriver

public extension FieldProperty {
    @inlinable
    convenience init(_ params: PGField) {
        self.init(key: .string(params.name))
    }
}

public extension BooleanProperty {
    @inlinable
    convenience init(_ params: PGField, format: Format) {
        self.init(key: .string(params.name), format: format)
    }
}

public extension EnumProperty {
    @inlinable
    convenience init(_ params: PGField) {
        self.init(key: .string(params.name))
    }
}

public extension ParentProperty {
    @inlinable
    convenience init(_ params: PGField) {
        self.init(key: .string(params.name))
    }
}

public extension OptionalBooleanProperty {
    @inlinable
    convenience init(_ params: PGField, format: Format) {
        self.init(key: .string(params.name), format: format)
    }
}

public extension OptionalParentProperty {
    @inlinable
    convenience init(_ params: PGField) {
        self.init(key: .string(params.name))
    }
}

public extension OptionalEnumProperty {
    @inlinable
    convenience init(_ params: PGField) {
        self.init(key: .string(params.name))
    }
}

public extension TimestampProperty {
    @inlinable
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
