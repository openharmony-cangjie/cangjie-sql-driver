package mysql

import std.database.sql.Connection
import std.database.sql.Datasource
import std.database.sql.Driver
import std.database.sql.SqlException
import std.convert.*
import std.binary.*

public class MysqlDriver <: Driver {
    private var driverNmae: String

    /*
     * 初始化驱动
     *
     * 参数 name - 驱动名称
     * 异常 SqlException - 内存不足导致初始化失败
     */
    public init(name: String) {
        this.driverNmae = name
    }

    /**
     * 驱动名称
     */
    public override prop name: String {
        get() {
            unsafe {
                return driverNmae
            }
        }
    }

    /**
     * 驱动版本
     *
     * 异常 SqlException - 获取版本失败
     */
    public override prop version: String {
        get() {
            return ""
        }
    }

    /**
     * 指示驱动程序是否与连接池亲和。
     * 如果否，则不建议使用连接池。
     * 比如sqlite驱动连接池化的收益不明显，不建议使用连接池
     */
    public override prop preferredPooling: Bool {
        get() {
            return true
        }
    }

    /*
     * 通过connectionString和选项打开数据源
     *
     * 参数 connectionString - 数据库连接字符串
     * 参数 opt - key,value的tuple数组，打开数据源的选项
     * 返回值 Datasource - 数据源实例
     * 异常 SqlException - connectionString连接内容不正确会导致异常
     */
    public override func open(connStr: String, opt: Array<(String, String)>): MysqlDatasource {
        return MysqlDatasource(MysqlConfig(connStr, opt))
    }
}