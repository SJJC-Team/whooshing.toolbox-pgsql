import ErrorHandle
@preconcurrency import FluentPostgresDriver

/**
    #### 实现该协议，以进行表结构生成和迁移

    你不需要实现它的所有细节，实际上你的实现非常简单。见 `PGModel` 的解释中 `PGMigration` 的用法

    你可以覆写 `migrationFinished(on:)` 函数来获取表结构生成完成的通知，该函数默认不进行任何动作
*/
public protocol PGMigration: Migration, Sendable {
    associatedtype DataModel: PGModel
    
    /// 指定该表是否应当使用 tde 加密，默认为 true
    var tdeEncrypt: Bool { get }
    
    /// 该协议函数在每个字段将被创建之前调用。
    /// - parameters:
    ///     - field: 当前准备创建的字段
    ///     - builder: migration 工厂实例
    /// 你可以覆写 `migrating(for: with:)` 函数为字段赋予更多约束，该函数默认不进行任何动作
    func migrating(for field: PGField, with builder: SchemaBuilder) -> SchemaBuilder
    
    /// 你可以覆写 `migrating(with:)` 函数为表创建增加其它自定约束，该函数默认不进行任何动作
    func migrating(with builder: SchemaBuilder) -> SchemaBuilder
    
    /// 你可以覆写 `migrationFinished(on:)` 函数来获取表结构生成完成的通知，该函数默认不进行任何动作
    func migrationFinished(on database: Database)
}

public extension PGMigration {
    @inlinable
    var tdeEncrypt: Bool { true }
    
    @inlinable
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        tableCreate(
            DataModel.schema,
            database: database,
            fields: DataModel.fields.params(),
            encrypt: self.tdeEncrypt
        ).map {
            migrationFinished(on: database)
        }
    }
    
    @inlinable
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(DataModel.schema).delete()
    }
    
    @inlinable
    func migrating(for field: PGField, with builder: SchemaBuilder) -> SchemaBuilder { builder }
    
    @inlinable
    func migrating(with builder: SchemaBuilder) -> SchemaBuilder { builder }
    
    @inlinable
    func migrationFinished(on database: Database) {}
    
    @inlinable
    internal func tableCreate(_ name: String, database: Database, fields: [PGField], encrypt: Bool) -> EventLoopFuture<Void> {
        var s = database.schema(name)
        var uniques: [FieldKey] = []
        var compositeUniques: [String: [FieldKey]] = [:]
        var primarys: [String] = []
        var dataTypeActions: [EventLoopFuture<Void>] = []
        for params in fields {
            if params.isPrimary { primarys.append(params.name) }
            switch params.uniqueConstraint {
            case .none: break
            case .alone: uniques.append(params.key)
            case .composite(let sign): compositeUniques[sign, default: []].append(params.key)
            }
            typealias Old = (FieldKey, DatabaseSchema.DataType, DatabaseSchema.FieldConstraint...) -> SchemaBuilder
            typealias Function = (FieldKey, DatabaseSchema.DataType, [DatabaseSchema.FieldConstraint]) -> SchemaBuilder
            let fieldConfig = unsafeBitCast(s.field as Old, to: Function.self)
            let constraints = params.constraints + (params.defaultValue != nil ? [params.defaultValue!] : []) + params.foreigns
            s = migrating(for: params, with: s)
            
            if case let .enum(e) = params.dataType {
                let enumSchema = database.enum(e.name)
                var currentS = enumSchema
                for caseName in e.cases {
                    currentS = currentS.case(caseName)
                }
                dataTypeActions.append(
                    currentS.create().map { dataType in
                        s = fieldConfig(params.key, params.dataType, constraints)
                    }
                )
            } else {
                s = fieldConfig(params.key, params.dataType, constraints)
            }
        }
        for unique in uniques { s = s.unique(on: unique) }
        for (name, uniqueGroup) in compositeUniques {
            switch uniqueGroup.count {
            case 0: break
            case 1: s = s.unique(on: uniqueGroup[0], name: name)
            case 2: s = s.unique(on: uniqueGroup[0], uniqueGroup[1], name: name)
            case 3: s = s.unique(on: uniqueGroup[0], uniqueGroup[1], uniqueGroup[2], name: name)
            case 4: s = s.unique(on: uniqueGroup[0], uniqueGroup[1], uniqueGroup[2], uniqueGroup[3], name: name)
            default: fatalError("暂不支持多于 4 字段的复合唯一约束")
            }
        }
        if primarys.count > 0 {
            let primaryConstraint = "PRIMARY KEY (\"\(primarys.joined(separator: "\", \""))\")"
            s = s.constraint(.custom(primaryConstraint))
        }
        
        s = migrating(with: s)
        
        return dataTypeActions.flatten(on: database.eventLoop).flatMap {
            s.create().flatMap {
                guard encrypt == true else { return database.eventLoop.makeSucceededVoidFuture() }
                guard let db = database as? PostgresDatabase else { return database.eventLoop.future(error: PgErr.dataBaseError.d("数据库类型不是 PostgreSQL")) }
                return db.query("ALTER TABLE \(name) SET ACCESS METHOD tde_heap;").flatMapError { err in
                    database.schema(name).delete().flatMapError { return database.eventLoop.future(error: PgErr.dataBaseTdeError.d("恢复失败").subErr($0))}
                    .flatMap { _ in database.eventLoop.future(error: PgErr.dataBaseTdeError.d("加密未成功，已删除该表格").subErr(err)) }
                }.transform(to: ())
            }
        }
    }
}
