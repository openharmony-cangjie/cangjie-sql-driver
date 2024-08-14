package mysql

import std.database.sql.*
import std.collection.*

public class MysqlTransaction <: Transaction {
    public var conn: MysqlTcp

    public init(conn: MysqlTcp) {
        this.conn = conn
    }

    /*
     * 数据库事务隔离级别。
     * 没有提供直接获取数据库事务隔离级别的接口或属性。但是，可以通过执行 SQL 语句来查询事务隔离级别，
     *
     * 异常 SqlException - 数据库事务隔离级别获取设置失败。
     */
    public mut override prop isoLevel: TransactionIsoLevel {
        get() {
            throw SqlException("TODO")
        }
        set(value) {

        }
    }

    /*
     * 数据库事务访问模式。
     * 没有提供直接获取数据库事务隔离级别的接口或属性。但是，可以通过执行 SQL 语句来查询事务隔离级别，
     * 返回一个值 0 或 1。如果值是 0，表示事务访问模式是读写模式；如果值是 1，表示事务访问模式是只读模式
     *
     * 异常 SqlException - 数据库事务访问模式获取设置失败。
     */
    public mut override prop accessMode: TransactionAccessMode {
        get() {
            throw SqlException("TODO")
        }
        set(value) {

        }
    }

    /*
     * 数据库事务延迟模式。(不支持)
     * 仅PostgreSQL和PostgreSQL支持
     */
    public mut override prop deferrableMode: TransactionDeferrableMode {
        get() {
            throw SqlException("TODO")
        }
        set(_) {
        }
    }

    /*
     * 开始数据库事务。
     *
     * 异常 SqlException - 开始数据库事务失败。
     */
    public override func begin(): Unit {
        // TODO START TRANSACTION READ ONLY
        let sql = "START TRANSACTION"
        // 发送指令
        conn.writeCommandPacketStr(ComQuery, sql)

    	var (resLen, _, _) = conn.readResultSetHeaderPacket()
        if (resLen>0) {
            // 丢弃 columns
            conn.readUntilEOF()
            // rows
            conn.readUntilEOF()
        }
    }

    /*
     * 提交数据库事务。
     *
     * 异常 SqlException - 提交数据库事务失败。
     */
    public override func commit(): Unit {
        // 发送指令
        conn.writeCommandPacketStr(ComQuery, "COMMIT")

    	this.conn.readResultSetHeaderPacket()
    }

    /*
     * 从挂起状态回滚事务。
     *
     * 异常 SqlException - 从挂起状态回滚事务失败。
     */
    public override func rollback(): Unit {
        // 发送指令
        conn.writeCommandPacketStr(ComQuery, "ROLLBACK")

    	this.conn.readResultSetHeaderPacket()
    }

    /*
     * 在事务中创建一个指定名称的保存点，可用于回滚事务的一部分。
     *
     * 参数 savePointName - 保存点名称。
     * 异常 SqlException - 提交事务时服务器端发生错误或者事务已提交或回滚或连接已断开。
     */
    public override func save(savePointName: String): Unit {

    }

    /*
     * 回滚事务至指定保存点名称。
     *
     * 参数 savePointName - 保存点名称。
     * 异常 SqlException - 提交事务时服务器端发生错误或者事务已提交或回滚或连接已断开。
     */
    public override func rollback(savepointName: String): Unit {

    }

    /*
     * 销毁先前在当前事务中定义的保存点。这允许系统在事务结束之前回收一些资源。
     *
     * 参数 savePointName - 保存点名称。
     * 异常 SqlException - 提交事务时服务器端发生错误或者事务已提交或回滚或连接已断开。
     */
    public override func release(savePointName: String): Unit {

    }
}