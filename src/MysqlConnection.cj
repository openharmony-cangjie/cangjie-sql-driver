package mysql

import std.database.sql.Connection
import std.database.sql.ConnectionState
import std.collection.HashMap

public class MysqlConnection <: Connection {
    private var config: MysqlConfig
    private var conn: MysqlTcp

    public init(cfg: MysqlConfig) {
    	this.config = cfg

        this.conn = MysqlTcp(cfg)
    }

    /**
     * 描述与数据源连接的当前状态
     */
    public override prop state: ConnectionState {
        get() {
            return ConnectionState.Connected
        }
    }

    public func createTransaction(): MysqlTransaction {
        return MysqlTransaction(this)
    }

    public func getMetaData(): HashMap<String, String> {
        return HashMap<String, String>()
    }

    public func prepareStatement(sql: String): MysqlStatement {
        return MysqlStatement(this.conn, sql)
    }

    /*
     * 关闭资源
     *
     * 异常 SqlException - 关闭资源失败。
     */
    public override func close(): Unit {
        if (this.isClosed()) {
            return
        }

    }

    /*
     * 判断资源是否关闭
     * 返回值 Bool - 如果已经关闭返回true，否则返回false
     */
    public override func isClosed(): Bool {
        return false
    }
}