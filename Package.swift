// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "whooshing.toolbox-pgsql",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v14),
        .watchOS(.v6),
        .tvOS(.v13)
    ],
    products: [
        .library( name: "PgSQL", targets: ["PgSQL"] ),
    ],
    dependencies: [
        .package(url: "https://github.com/whooshing-workshop/whooshing-fluent.git", from: "1.0.3"),
//        .package(url: "https://github.com/whooshing-workshop/whooshing.toolbox-basic.git", from: "1.5.10"),
        .package(path: "/Users/clwang/GitHub/whooshing.toolbox-basic"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.10.0"),
        .package(url: "https://github.com/Flight-School/AnyCodable", from: "0.6.0")
    ],
    targets: [
        .target(
            name:  "PgSQL",
            dependencies: [
                .product(name: "ErrorHandle", package: "whooshing.toolbox-basic"),
                .product(name: "NIOAdvanced", package: "whooshing.toolbox-basic"),
                .product(name: "LoggingAdvanced", package: "whooshing.toolbox-basic"),
                .product(name: "Fluent", package: "whooshing-fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "AnyCodable", package: "AnyCodable")
            ]
        ),
        .testTarget(
            name: "toolbox-pgsql-Tests",
            dependencies: [
                .target(name: "PgSQL"),
                .product(name: "Fluent", package: "whooshing-fluent")
            ]
        ),
    ]
)
