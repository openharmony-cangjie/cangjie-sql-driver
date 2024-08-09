package mysql

struct Config {
    // 地址, 只能是IP或域名
    let address: String
    let port: UInt16

    let user: String
    let password: String
    let database: String

    var tls: Bool = false

    // 编码
    let collation: String = "utf8mb4_general_ci"

    // TODO 待翻译
    let AllowAllFiles            :Bool = false // Allow all files to be used with LOAD DATA LOCAL INFILE
    let AllowCleartextPasswords  :Bool = false // Allows the cleartext client side plugin
    let AllowFallbackToPlaintext :Bool = false // Allows fallback to unencrypted connection if server does not support TLS
    let AllowNativePasswords     :Bool = false // Allows the native password authentication method
    let AllowOldPasswords        :Bool = false // Allows the old insecure password method
    let CheckConnLiveness        :Bool = false // Check connections for liveness before using them
    let ClientFoundRows          :Bool = false // Return number of matching rows instead of rows changed
    let ColumnsWithAlias         :Bool = false // Prepend table alias to column names
    let InterpolateParams        :Bool = false // Interpolate placeholders into query string
    let MultiStatements          :Bool = false // Allow multiple statements in one query
    let ParseTime                :Bool = false // Parse time values to time.Time
    let RejectReadOnly           :Bool = false // Reject read-only connections

    public init(address: String, port: UInt16, user: String, password: String, database: String) {
        this.address = address
        this.port = port
        this.user = user
        this.password = password
        this.database = database
    }

    public func Build(): MysqlConn {
        return MysqlConn(this)
    }
}