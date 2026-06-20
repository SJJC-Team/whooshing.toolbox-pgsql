# Whooshing PostgreSQL ORM

本项目为 [Whooshing](https://github.com/whooshing-workshop/whooshing) 系统的 **PostgreSQL ORM 依赖库**，基于 Vapor 的 Fluent 框架进行了深度封装，旨在提供更简洁、直观的方式来定义数据模型、字段约束和数据库迁移。契合 Whooshing 系统的安全理念，原生支持透明数据加密（TDE）特性的表结构创建。

### 特性

- **极简数据模型定义**：通过 `PGModel` 和 `PGFields`，极大地简化了 Fluent 中表结构和属性的声明方式。
- **链式字段约束配置**：强大的 `PGField` 封装，支持通过链式调用快速设置主键、外键、默认值、非空、唯一等约束条件。
- **复合唯一约束支持**：内置支持多个字段组合形成的复合唯一约束。
- **自动透明数据加密 (TDE)**：通过 `PGMigration` 创建表时，默认启用 PostgreSQL `tde_heap` 访问方式，实现底层数据的透明加密（需要数据库端支持）。
- **自动化数据库迁移**：只需要极简的代码即可完成包含所有字段、枚举、索引和约束的表创建和销毁。

----------

### 导入该依赖库

在你的 Package.swift 加入：

``` swift
.package(url: "https://github.com/whooshing-workshop/whooshing.toolbox-pgsql.git", from: "1.1.0")
```

在依赖模块中引入:

```swift
.product(name: "PgSQL", package: "whooshing.toolbox-pgsql")
```

在需要的地方:

```swift
import PgSQL
```

--------

### 使用介绍

##### 创建和定义数据模型 (PGModel)

要创建一个数据库表的数据模型，你需要实现 `PGModel` 协议，并在其中定义表名和字段 `Fields`，然后将字段与模型属性绑定。这比原生 Fluent 更加聚合和直观。

以下是一个创建文件索引模型 `FileIndex` 的示例：

``` swift
import PgSQL
import Fluent
import Foundation

final class FileIndex: PGModel, @unchecked Sendable {
    
    // 1. 设置表的名称
    static let name = "file_indexes"
    
    // 2. 定义该表的所有字段信息，实现 PGFields 协议
    struct Fields: PGFields {
        // 定义 UUID 主键
        let id = PGField("id", .uuid).primary
        
        // 定义字符串类型，并要求必填（不可为 null）
        let name = PGField("name", .string).required
        
        // 可选字符串类型
        let mimeType = PGField("mime_type", .string)
        
        // 外键约束，指向 FileIndex 自身的 id 字段，当父节点被删除时级联删除
        let parent = PGField("parent_id", .uuid).foreign(FileIndex.self, .id, onDelete: .cascade)
        
        // 整数类型字段
        let size = PGField("size", .int64)
        
        // 时间字段
        let createdAt = PGField("create_at", .datetime).required
        let updatedAt = PGField("update_at", .datetime).required
        
        init() {}
    }
    
    static let fields = Fields()
    
    // 3. 将数据库表字段绑定到该模型的属性
    // 这里的 @ID, @Field 等包装器是 Fluent 提供的原生属性包装器
    @ID(key: .id)                                             var id: UUID?
    @Field(fields.name)                                       var name: String
    @OptionalField(fields.mimeType)                           var mimeType: String?
    @OptionalParent(fields.parent)                            var parent: FileIndex?
    @Field(fields.size)                                       var size: Int64?
    @Timestamp(fields.createdAt, on: .create)                 var createdAt: Date!
    @Timestamp(fields.updatedAt, on: .update)                 var updatedAt: Date!
    
    init() {}
}
```

##### 数据库表迁移 (PGMigration)

在定义完模型后，你需要创建一个迁移结构以让数据库执行表结构的生成。通过 `PGMigration` 协议，这只需要非常简单的代码：

``` swift
extension FileIndex {
    // 实现 PGMigration 协议
    struct MIG: PGMigration, Sendable {
        // 指定对应的数据模型
        typealias DataModel = FileIndex
        
        // 指定是否开启数据库底层的透明数据加密 (TDE)
        var tdeEncrypt: Bool
        
        init(tdeEncrypt: Bool = true) {
            self.tdeEncrypt = tdeEncrypt
        }
    }
}
```

将该迁移加入到你的应用程序或数据库初始化流程中即可：

```swift
app.migrations.add(FileIndex.MIG(tdeEncrypt: true))
```

或者使用 `Database` 实例直接进行结构准备：

```swift
try await FileIndex.MIG(tdeEncrypt: true).prepare(on: database).get()
```

##### 字段约束详述 (PGField)

`PGField` 提供了极其便利的链式调用，你可以轻松地为字段添加多重约束，甚至可以一行代码完成多个约束声明：

``` swift
// 设置默认值
let age = PGField("age", .int).def(30)
let email = PGField("email", .string).def("null@null.com")

// 设置为自增主键
let id = PGField("id", .int).identifier(auto: true).primary

// 设置唯一约束
let userName = PGField("user_name", .string).unique

// 复合唯一约束（多个字段拥有相同的复合约束签名即可）
let groupId = PGField("group_id", .uuid).unique(composite: "group_user_unique")
let userId = PGField("user_id", .uuid).unique(composite: "group_user_unique")

// 外键约束
let foreign = PGField("role_id", .uuid).foreign(Role.self, Role.fields.id, onDelete: .cascade)

// 自由组合使用
let code = PGField("code", .string).required.unique.def("0000")
```

-------

### 运行环境

* **macOS** (> 10.15)
* **iOS** (> 14.0)
* **Linux** (> 20)
* **Swift** (> 6.0)
* **watchOS** (> 6.0) **[未测试]**
* **tvOS**(> 13) **[未测试]**

-------

### 注意事项

- **TDE 加密支持**：`PGMigration` 默认会在表创建完毕后执行 `ALTER TABLE <table> SET ACCESS METHOD tde_heap;`，如果你的 PostgreSQL 数据库不支持该指令或未安装相关插件（如 TDE 插件），可能会导致迁移失败。你可以通过将 `tdeEncrypt` 设为 `false` 来关闭此行为。
- **复合唯一约束限制**：当前 `PGMigration` 自动解析的复合唯一约束最多支持 4 个字段的组合。

如需了解更多，请参阅各模块内的源码注释与文档说明。

------

### 联系与反馈

如有使用问题或建议，请通过 [GitHub Issues](https://github.com/whooshing-workshop/whooshing.toolbox-pgsql/issues) 提交反馈。

或发至邮箱 [contact@official.whooshings.space](mailto:contact@official.whooshings.space)
