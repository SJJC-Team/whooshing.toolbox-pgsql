import FluentPostgresDriver
import ErrorHandle

/// 数据库模块所有可能出现的错误
public enum PGErrcase: String, ErrList {
    case dataBaseError = "数据库出现问题"
    case fieldDefineError = "Field 定义出现错误"
    case dataBaseTdeError = "数据库 TDE 加密失败"
}

public typealias PgErr = PGErrcase

// MARK: - 类型扩展

extension PostgresQueryResult: @unchecked @retroactive Sendable {}

public extension Array {
    @inlinable
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var results = [T]()
        for element in self {
            try await results.append(transform(element))
        }
        return results
    }
}

public extension PostgresRow {
    @inlinable
    func datas() -> [String: PostgresData] {
        var row: [String: PostgresData] = [:]
        for cell in self {
            row[cell.columnName] = PostgresData(
                type: cell.dataType,
                typeModifier: 0,
                formatCode: cell.format,
                value: cell.bytes
            )
        }
        return row
    }
}
