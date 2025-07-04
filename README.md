# Whooshing PostgreSQL ORM

基于 Vapor 的 Fluent 进行的简单封装

----------

### 导入该依赖库

在你的 Package.swift 加入：

``` swift
.package(url: "https://github.com/SJJC-Team/whooshing.toolbox-pgsql.git", .upToNextMajor(from: "1.0.4"))
```

在依赖模块中引入:

```swift
.product(name: "WhooshingClient", package: "whooshing.toolbox-client")
```

在需要的地方:

```swift
import WhooshingClient
```

--------

### 运行环境

* **macOS** (> 10.15)
* **iOS** (> 14.0)
* **Linux** (> 20)
* **Swift** (> 6.0)
* **watchOS** (> 6.0) **[未测试]**
* **tvOS**(> 13) **[未测试]**

-------

### 联系与反馈

如有使用问题或建议，请通过 [GitHub Issues](https://github.com/SJJC-Team/whooshing.toolbox-pgsql/issues) 提交反馈。

或发至邮箱 [contact@official.whooshings.space](mailto:contact@official.whooshings.space)
