import FluentPostgresDriver

/**
    #### 描述数据库表字段信息
    
    与数据库中的表字段一一对应，描述字段的名称，数据类型，是否唯一，外键等等约束，支持使用追加的方式设置约束: 
    
    以下该示例定义了一个名为 user_name 的字段，其数据类型为 string，且不允许重复(即唯一约束): 
    ``` swift
    let userName = PGField("user_name", .string, true)
    ```
    若你想要为其设置默认值: 
    ``` swift
    let userName = PGField("user_name", .string, true).def("默认名称")
    ```
    或者设置与表 role 的 id 字段建立外键关系，则: 
    ``` swift
    // 表 "role" 的定义
    final class Role: PGModel, @unchecked Sendable {
        static let name = "role"

        struct Fields: PGFields {
            let id = PGField("id", .uuid)
            let admin = PGField("admin", .string)

            // ... 该表 role 的其他字段
        }
        // ...
    }

    // 表 "users" 的定义
    final class User: PGModel, @unchecked Sendable {

        static let name = "users"
        
        struct Fields: PGFields {
            // 该字段将作为该表的主键，建议每个表都创建至少一个主键
            let id = PGField("id", .uuid).primary
            let email = PGField("email", .string)
            // 建立外键关系
            let foreign = PGField("foreign", .uuid).foreign(Role.self, Role.fields.id)
            // 当然，你也可以为该键建立多个外键，继续往后追加即可
            // let foreign = PGField("foreign", .uuid).foreign(Role.self, Role.fields.id).foreign(..., ...).foreign(..., ...) ...
        }
        // ...
    }
    ```
    若还要设置其他约束，可以进一步使用 cons() 追加。下面这个例子增加了一个额外的非空约束: 
    ``` swift
    // 注意到，最后一个参数是一个数组，因此你可以放置任意数量的约束。
    // 所有支持的约束列表见 DatabaseSchema.FieldConstraint 的定义
    let userName = PGField("user_name", .string, true).cons([.require])
    ```
*/
public struct PGField: Sendable {
    /// 字段的名称
    public let name: String
    /// 字段的数据类型
    public let dataType: DatabaseSchema.DataType
    /// 该字段是否唯一？
    public let isUnique: Bool
    /// 该字段是否为主键？
    public let isPrimary: Bool
    /// 该字段的默认值约束
    public let defaultValue: DatabaseSchema.FieldConstraint?
    /// 该字段的外建约束，通过 `foreign(_)` 函数增加外键
    public let foreigns: [DatabaseSchema.FieldConstraint]
    /// 其他约束，所有支持的约束列表见 DatabaseSchema.FieldConstraint 的定义
    public let constraints: [DatabaseSchema.FieldConstraint]
    
    /// 返回 FieldKey，用于在 @Field 中引用。不过几乎可以不用该计算属性。
    public var key: FieldKey { .string(self.name) }
    
    /// 初始化字段，并设置基本信息
    ///
    /// - Parameters:
    ///     - name: 字段名称
    ///     - dataType: 字段数据类型，完整的定义请见 DatabaseSchema.DataType 的定义
    ///     - isUnique: 该字段是否唯一(即其中的值是否可以重复)？
    /// - Returns: 包括以上基本信息的字段实例
    @inlinable
    public init(
        _ name: String,
        _ dataType: DatabaseSchema.DataType,
        _ isUnique: Bool = false,
        _ isPrimary: Bool = false
    ) {
        self = Self.init(name: name, dataType: dataType, isUnique: isUnique, isPrimary: isPrimary, defaultValue: nil, foreigns: [], constraints: [])
    }
}

extension PGField {
    
    /// 为字段设置一个必须约束，表示该字段不可为 null
    @inlinable
    public var required: Self { self.cons([.required]) }
    /// 为字段设置一个唯一约束，表示该字段不可重复
    @inlinable
    public var unique: Self { .init(self, unique: true, primary: self.isPrimary) }
    /// 将该字段设置为主键之一
    @inlinable
    public var primary: Self { .init(self, unique: false, primary: true) }
    
    /// 为字段设置默认值
    ///
    /// - Parameters:
    ///     - value: 即要设置的默认值，可以为多种类型。
    /// - Returns: 被设置了默认值的新字段实例
    ///
    /// ``` swift
    /// let field = PGField(..., ...)
    /// let newField = field.def(100)
    /// // 或直接追加设置
    /// let field2 = PGField(..., ...).def(100)
    /// ```
    public func def(_ value: any SQLExpression) -> Self { .init(self, def: .sql(.default(value))) }
    /// 为字段设置默认值
    public func def(_ value: String) -> Self { .init(self, def: .sql(.default(value))) }
    /// 为字段设置默认值
    public func def<T: BinaryInteger>(_ value: T) -> Self { .init(self, def: .sql(.default(value))) }
    /// 为字段设置默认值
    public func def<T: FloatingPoint>(_ value: T) -> Self { .init(self, def: .sql(.default(value))) }
    /// 为字段设置默认值
    public func def(_ value: Bool) -> Self { .init(self, def: .sql(.default(value))) }
    
    /// 为字段设置外键
    ///
    /// - Parameters:
    ///     - model: 要创建外键的目标数据表模型
    ///     - space: 可选参数，表示命名空间或特定的表范围。如果 schema 中存在嵌套结构或多级分隔，space 可以帮助进一步细化表的范围
    ///     - field: 目标数据表模型的目标字段
    ///     - onDelete: 当外键约束的父记录被删除时，触发的动作(如 CASCADE)
    ///     - onUpdate: 当外键约束的父记录被更新时，触发的动作(如 RESTRICT)
    /// - Returns: 更新了外键约束的新字段实例
    ///
    /// 可以像下面一样，多次叠加该函数以为一个字段创建多个外键引用，但这是不推荐的。
    /// ``` swift
    /// let field = PGField(..., ...).foreign(User.self, User.fields.id).foreign(Infos.self, Infos.fields.id).foreign(...)...
    /// ```
    @inlinable
    public func foreign<S: PGModel>(
        _ model: S.Type,
        space: String? = nil,
        _ field: PGField,
        onDelete: DatabaseSchema.ForeignKeyAction = .noAction,
        onUpdate: DatabaseSchema.ForeignKeyAction = .noAction
    ) -> Self {
        .init(self, foreign: .references(model.schema, space: space, .string(field.name), onDelete: onDelete, onUpdate: onUpdate))
    }
    
    @inlinable
    public func foreign<S: PGModel>(
        _ model: S.Type,
        space: String? = nil,
        _ field: KeyPath<S.Fields, PGField>,
        onDelete: DatabaseSchema.ForeignKeyAction = .noAction,
        onUpdate: DatabaseSchema.ForeignKeyAction = .noAction
    ) -> Self {
        .init(self, foreign: .references(model.schema, space: space, S.fields[keyPath: field].key, onDelete: onDelete, onUpdate: onUpdate))
    }
    
    @inlinable
    public func foreign<S: PGModel>(
        _ model: S.Type,
        space: String? = nil,
        _ field: FieldKey,
        onDelete: DatabaseSchema.ForeignKeyAction = .noAction,
        onUpdate: DatabaseSchema.ForeignKeyAction = .noAction
    ) -> Self {
        .init(self, foreign: .references(model.schema, space: space, field, onDelete: onDelete, onUpdate: onUpdate))
    }
    
    /// 为字段设置其他约束
    ///
    /// - Parameters:
    ///   - constraint: 要设置的单个约束
    /// - Returns: 添加了该约束的新字段实例
    ///
    /// 可进行追加设置，而叠加会自动应用所有的约束
    /// ``` swift
    /// // 单次追加
    /// let field = PGField(..., ...).cons(...)
    /// // 叠加，只会采用所有的约束设置
    /// let field = PGField(..., ...).cons(...).cons(...).cons(...)
    /// ```
    @inlinable
    public func cons(_ constraint: DatabaseSchema.FieldConstraint) -> Self { self.cons([constraint]) }
    
    /// 为字段设置其他约束
    ///
    /// - Parameters:
    ///     - constraints: 约束数组，即你要添加的约束
    /// - Returns: 更新了约束的新字段实例
    ///
    /// 可进行追加设置，而叠加会自动应用所有的约束: 
    /// ``` swift
    /// // 单次追加
    /// let field = PGField(..., ...).cons([..., ...])
    /// // 叠加，会采用所有的约束设置
    /// let field = PGField(..., ...).cons([..., ...]).cons([..., ...]).cons([..., ...])
    /// ```
    @inlinable
    public func cons(_ constraints: [DatabaseSchema.FieldConstraint]) -> Self {
        .init(self, constraints: constraints)
    }
}

extension PGField {
    @inlinable
    init(_ s: Self, unique: Bool, primary: Bool) {
        self = Self(
            name: s.name,
            dataType: s.dataType,
            isUnique: unique,
            isPrimary: primary,
            defaultValue: s.defaultValue,
            foreigns: s.foreigns,
            constraints: s.constraints
        )
    }
    
    @inlinable
    init(_ s: Self, def: DatabaseSchema.FieldConstraint) {
        self = Self(
            name: s.name,
            dataType: s.dataType,
            isUnique: s.isUnique,
            isPrimary: s.isPrimary,
            defaultValue: def,
            foreigns: s.foreigns,
            constraints: s.constraints
        )
    }
    
    @inlinable
    init(_ s: Self, foreign: DatabaseSchema.FieldConstraint) {
        self = Self(
            name: s.name,
            dataType: s.dataType,
            isUnique: s.isUnique,
            isPrimary: s.isPrimary,
            defaultValue: s.defaultValue,
            foreigns: s.foreigns + [foreign],
            constraints: s.constraints
        )
    }
    
    @inlinable
    init(_ s: Self, constraints: [DatabaseSchema.FieldConstraint]) {
        self = Self(
            name: s.name,
            dataType: s.dataType,
            isUnique: s.isUnique,
            isPrimary: s.isPrimary,
            defaultValue: s.defaultValue,
            foreigns: s.foreigns,
            constraints: s.constraints + constraints
        )
    }
    
    @inlinable
    init(
        name: String,
        dataType: DatabaseSchema.DataType,
        isUnique: Bool,
        isPrimary: Bool,
        defaultValue: DatabaseSchema.FieldConstraint?,
        foreigns: [DatabaseSchema.FieldConstraint],
        constraints: [DatabaseSchema.FieldConstraint]
    ) {
        self.name = name
        self.dataType = dataType
        self.constraints = constraints
        self.defaultValue = defaultValue
        self.foreigns = foreigns
        self.isUnique = isUnique
        self.isPrimary = isPrimary
    }
}
