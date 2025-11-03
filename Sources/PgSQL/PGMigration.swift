import FluentPostgresDriver
import ErrorHandle

/**
    #### 实现该协议，以进行表结构生成和迁移

    你不需要实现它的所有细节，实际上你的实现非常简单。见 `PGModel` 的解释中 `PGMigration` 的用法

    你可以覆写 `migrationFinished(on:)` 函数来获取表结构生成完成的通知，该函数默认不进行任何动作
*/
public protocol PGMigration: Migration, Sendable {
    associatedtype DataModel: PGModel
    
    /// 指定该表是否应当使用 tde 加密，默认为 true
    var tdeEncrypt: Bool { get }
    
    /// 你可以覆写 `migrationFinished(on:)` 函数来获取表结构生成完成的通知，该函数默认不进行任何动作
    func migrationFinished(on database: Database)
}

public extension PGMigration {
    @inlinable
    var tdeEncrypt: Bool { true }
    
    @inlinable
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        Self.tableCreate(
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
    func migrationFinished(on database: Database) {}
    
    @inlinable
    internal static func tableCreate(_ name: String, database: Database, fields: [PGField], encrypt: Bool) -> EventLoopFuture<Void> {
        var s = database.schema(name)
        var uniques: [FieldKey] = []
        var compositeUniques: [String: [FieldKey]] = [:]
        var primarys: [String] = []
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
            s = fieldConfig(params.key, params.dataType, constraints)
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
        
        return s.create().flatMap {
            guard encrypt == true else { return database.eventLoop.makeSucceededVoidFuture() }
            guard let db = database as? PostgresDatabase else { return database.eventLoop.future(error: PgErr.dataBaseError.d("数据库类型不是 PostgreSQL")) }
            return db.query("ALTER TABLE \(name) SET ACCESS METHOD tde_heap;").flatMapError { err in
                database.schema(name).delete().flatMapError { return database.eventLoop.future(error: PgErr.dataBaseTdeError.d("恢复失败").subErr($0))}
                .flatMap { _ in database.eventLoop.future(error: PgErr.dataBaseTdeError.d("加密未成功，已删除该表格").subErr(err)) }
            }.transform(to: ())
        }
    }
}
