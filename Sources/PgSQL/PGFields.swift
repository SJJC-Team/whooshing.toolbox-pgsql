import FluentPostgresDriver
import ErrorHandle

/**
    #### 实现该协议，以创建表的字段列表

    可以在你的自定义类型中列出所有的字段详细配置，使得数据库可以得知如何生成和存取数据。你始终应当为你的表中设置 `id` 字段，这非常重要且强制要求

    -----
    ### 创建字段配置列表
    创建一个结构体，并实现该协议，列出所有的字段。以下示例列出了 5 个字段，分别是 "id", "email", "age", "create_at", "update_at"，并为其详细配置了参数
    ```
    struct Fields: PGFields {
        // 该字段将作为该表的主键，建议每个表都创建至少一个主键
        let id = PGField("id", .uuid).primary
        // 设置了默认值 null@null.com 并非空
        let email = PGField("email", .string).cons([.sql(.default("null@null.com")), .required])
        // 设置了默认值 30，且唯一(不允许重复)
        let age =  ("age", .int, true).def(30)
        // 仅设置了唯一约束
        let createdAt = PGField("create_at", .string, true)
        // 仅设置了默认值
        let updateAt = PGField("update_at", .string).def("2001-02-27")
    }
    ```
    关于字段的具体配置，可见 `PGField` 的定义，`PGField` 实际上是 `PGField` 的别名
*/
public protocol PGFields: Sendable {
    init()
}

public extension DatabaseSchema.DataType.Enum {
    @inlinable
    init<T>(_ enum: T.Type, as name: String) where T: RawRepresentable & CaseIterable & Codable & Sendable, T.RawValue == String {
        self = Self.init(name: name, cases: T.allCases.map { $0.rawValue })
    }
}

public extension DatabaseSchema.DataType {
    @inlinable
    static func `enum`<T>(
        _ enum: T.Type,
        as name: String
    ) -> Self where
        T: RawRepresentable & CaseIterable & Codable & Sendable,
        T.RawValue == String
    {
        .enum(.init(`enum`, as: name))
    }
}

extension PGFields {
    @inlinable
    func params() -> [PGField] {
        var properties: [PGField] = []
        let mirror = Mirror(reflecting: self)
        for case let (_, value) in mirror.children {
            guard let val = value as? PGField else { fatalError(PgErr.fieldDefineError.d("解析失败", category: .external()).description) }
            properties.append(val)
        }
        return properties
    }
}
