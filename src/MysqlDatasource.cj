package mysql

import std.database.sql.Connection
import std.database.sql.Datasource
import std.collection.HashMap

public class MysqlDatasource <: Datasource {
    private var config: MysqlConfig

    public init(cfg: MysqlConfig) {
        this.config = cfg
    }

    public func connect(): MysqlConnection {
        return MysqlConnection(this.config)
    }

    public func setOption(key: String, value: String): Unit {

    }

    /*
     * 关闭资源 （不支持）
     */
    public override func close(): Unit {
        // TODO 关闭所有 ?

        return
    }

    /*
     * 判断资源是否关闭（不支持）
     *
     * 返回值 Bool - 如果已经关闭返回true，否则返回false
     */
    public override func isClosed(): Bool {
        return false
    }
}