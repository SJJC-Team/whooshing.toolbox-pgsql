import LoggingAdvanced
import FluentPostgresDriver
import AnyCodable

extension SQLPostgresConfiguration: @retroactive Loggerable, @retroactive CustomStringConvertible {
    public var description: String {
        formatJson([
            "host": AnyCodable(self.coreConfiguration.host ?? "null"),
            "port": AnyCodable(self.coreConfiguration.port ?? -1),
            "user": AnyCodable(self.coreConfiguration.username),
            "database": AnyCodable(self.coreConfiguration.database ?? "null"),
            "options": [
                "additional_startup_parameters": self.coreConfiguration.options.additionalStartupParameters,
                "connect_timeout": self.coreConfiguration.options.connectTimeout,
                "require_backend_key_data": self.coreConfiguration.options.requireBackendKeyData,
                "tls_server_name": self.coreConfiguration.options.tlsServerName ?? "null",
            ]
        ])
    }
    
    public var summaryDescription: String {
        formatJson([
            "host": AnyCodable(self.coreConfiguration.host ?? "null"),
            "port": AnyCodable(self.coreConfiguration.port ?? -1),
            "user": AnyCodable(self.coreConfiguration.username),
            "database": AnyCodable(self.coreConfiguration.database ?? "null")
        ])
    }
}
