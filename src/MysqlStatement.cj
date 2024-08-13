package mysql

import std.database.sql.UpdateResult
import std.database.sql.QueryResult
import std.database.sql.SqlDbType
import std.database.sql.ColumnInfo
import std.database.sql.Statement
import std.collection.*
import std.binary.*

public class MysqlStatement <: Statement {
    public var conn: MysqlTcp

    // stmt id
    public var id: UInt32 = 0
    // 当前参数
    public var paramCount: Int = 0

    public init(conn: MysqlTcp, sql: String) {
        this.conn = conn

        // 发送指令
        info("准备发送预处理: ", sql)
        conn.writeCommandPacketStr(ComStmtPrepare, sql)
        // 读取指令
        let columnCount = this.readPrepareResultPacket()
        if (this.paramCount > 0) {
            conn.readUntilEOF()
        }
        if (columnCount > 0) {
            conn.readUntilEOF()
        }
        info("预执行后, StmtID(${this.id}), 行数量(${columnCount}), 需要参数(${this.paramCount})")
    }

    /*
     * 预执行 sql 语句中，占位参数的列信息（不支持）
     */
    public override prop parameterColumnInfos: Array<ColumnInfo> {
        get() {
            return []
        }
    }

    public func query(params: Array<SqlDbType>): QueryResult {
        return MysqlQueryResult(this, params)
    }

    public func setOption(key: String, value: String): Unit {

    }
    public func update(params: Array<SqlDbType>): UpdateResult {
        return MysqlUpdateResult(this, params)
    }

    public func readPrepareResultPacket(): UInt16 {
        let data = this.conn.readPacket()
        if (data[0] != 0x00) {
            return 0
        }

        // stmt id [4 bytes]
        this.id = UInt32.readLittleEndian(data[1..5])

        // column count [16 bit uint]
        let columnCount = UInt16.readLittleEndian(data[5..7])

        // param count [16 bit uint]
        this.paramCount = Int64(UInt16.readLittleEndian(data[7..9]))

        return columnCount
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

        this.conn.writeCommandPacketUint32(ComStmtClose, this.id)
        this.id = 0
    }

    /*
     * 判断资源是否关闭
     * 返回值 Bool - 如果已经关闭返回true，否则返回false
     */
    public override func isClosed(): Bool {
        return this.id == 0
    }
}