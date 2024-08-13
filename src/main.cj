package mysql

import std.socket.*
import std.time.*
import std.sync.*
import std.os.posix
import std.database.sql.*

main(): Int64 {
    // 初始化数据库驱动
    let mysqlDriver = MysqlDriver("mysql")

    // 通过connectionString和选项打开数据源
    let datasource: MysqlDatasource = mysqlDriver.open(
        "root:root@tcp(localhost:3306)/temp",
        Array<(String, String)>()
    )

    let conn = datasource.connect()
    let stmt1 = conn.prepareStatement("SELECT * FROM squarenum")
    let result = stmt1.query()

    info("quere = ", result)
    // 获取数据
    var Id = SqlInteger(0)
    var Age = SqlInteger(0)
    var Str = SqlNullableVarchar("")
    var arrDb: Array<SqlDbType> = [Id, Age, Str]
    var isBool = result.next(arrDb)
    if (!isBool) {
        error("读取失败")
    }

    debug("Id = ${Id.value} Age = ${Age.value} Str = ${Str.value} ")

    return 0
}
