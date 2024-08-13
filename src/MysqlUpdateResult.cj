package mysql

import std.database.sql.UpdateResult
import std.database.sql.SqlDbType
import std.database.sql.ColumnInfo

public class MysqlUpdateResult <: UpdateResult {
    private var rows: Int64 = 0

    let stmt: MysqlStatement
    let params: Array<SqlDbType>

    public init(stmt: MysqlStatement, params: Array<SqlDbType>) {
    	this.stmt = stmt
    	this.params = params

    	// 发送参数包
        stmt.conn.writeExecutePacket(stmt, this.params)

    	var resLen = this.stmt.conn.readResultSetHeaderPacket()
        if (resLen>0) {
            debug("MysqlUpdateResult.resLen = ", resLen)
        }
    }

    /*
     * 执行Insert,Update,Delete语句影响的行数
     */
    public override prop rowCount: Int64 {
        get() {
            return rows
        }
    }

    /*
     * 执行Insert语句自动生成的最后rowID，如果不支持则为0
     */
    public override prop lastInsertId: Int64 {
        get() {
            return Int64(0)
        }
    }
}