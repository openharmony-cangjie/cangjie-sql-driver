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
        "root:root@tcp(localhost:3307)/temp",
        Array<(String, String)>()
    )

    let conn = datasource.connect()

    let stmt1 = conn.prepareStatement("SELECT squareNumber FROM squarenum WHERE number = ?")
    let result = stmt1.query(SqlInteger(2))

    info("quere = ", result)
    // 获取数据
    var squareNumber = SqlBigInt(0)
    var arrDb: Array<SqlDbType> = [squareNumber]
    var isBool = result.next(arrDb)
    if (!isBool) {
        println("pass26")
    }

    debug("arrDb = ", arrDb)


//    info("启动。。。")
//    let mysql = Config("localhost", 3307, "root", "root", "temp").Build()
////    info("链接成功")
////    var stmt = mysql.Prepare("INSERT INTO squareNum VALUES( ?, ? )")
////
////    stmt.Exec(101,201)
//
//    var stmtOut = mysql.Prepare("SELECT squareNumber FROM squarenum WHERE number = ?")
//    var data = stmtOut.QueryRows(2)
//    info("读取信息 = ", data)

    return 0
}
