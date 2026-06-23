import Fluent
import NIOAdvanced

public extension Database {
    /// 使用自定义错误类型封装的事务执行器。
    @inlinable
    func trans<T: Sendable, G: Err>(
        throws error: G.ErrorList,
        _ explain: String? = nil,
        metadata: Logger.Metadata? = nil,
        category: ErrCategory,
        file: String = #fileID,
        line: Int = #line,
        function: String = #function,
        _ closure: @escaping @Sendable (Self) -> EventLoopResult<T, G>,
    ) -> EventLoopResult<T, G> {
        self.trans { db in
            closure(db).wrapped
        }.flatMapError { e in
            if let err = e as? G {
                return eventLoop.makeFailedFuture(err)
            }
            return eventLoop.makeFailedFuture(G.init(error, explain, category: category, file: file, line: line, function: function).subErr(e).metadata(metadata))
        }.withError()
    }
    
    /// 使用自定义错误类型封装的事务执行器。
    @inlinable
    func trans<T: Sendable, G>(
        throws error: G,
        _ closure: @escaping @Sendable (Self) -> EventLoopResult<T, G>,
    ) -> EventLoopResult<T, G> {
        self.trans { db in
            closure(db).wrapped
        }.flatMapError { e in
            if let err = e as? G {
                return eventLoop.makeFailedFuture(err)
            }
            return eventLoop.makeFailedFuture(error)
        }.withError()
    }
    
    /// 使用 Fluent 的事务封装异步回调。
    @inlinable
    func trans<T>(_ closure: @escaping @Sendable (Self) -> EventLoopFuture<T>) -> EventLoopFuture<T> {
        self.transaction { db in
            closure(db as! Self)
        }
    }
    
    /// 在 async/await 环境中执行数据库事务。
    @inlinable
    func trans<T: Sendable>(_ closure: @escaping @Sendable (Self) async throws -> T) async throws -> T {
        try await self.transaction { db in
            try await closure(db as! Self)
        }
    }
}
