package mysql

import std.database.sql.Connection
import std.database.sql.ConnectionState
import std.collection.HashMap
import std.sync.AtomicBool

public class MysqlConnection <: Connection {
    private var config: MysqlConfig
    private var conn: MysqlTcp
    // 控制关闭的状态
    private var closed = AtomicBool(false)

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
        return MysqlTransaction(this.conn)
    }

    public func getMetaData(): HashMap<String, String> {
        return HashMap<String, String>()
    }
    // 预执行
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
        closed.store(true)
        this.conn.close()
    }

    /*
     * 判断资源是否关闭
     * 返回值 Bool - 如果已经关闭返回true，否则返回false
     */
    public override func isClosed(): Bool {
        return closed.load()
    }
}