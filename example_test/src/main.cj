package example_test

import std.database.sql.*
import std.time.*
import mysql.*

main(): Int64 {
    SetLevel(LogLevel.info)

    // 初始化数据库驱动
    let mysqlDriver = MysqlDriver("mysql")

    // 通过connectionString和选项打开数据源
    let datasource: MysqlDatasource = mysqlDriver.open(
        "root:root@tcp(localhost:3306)/temp",
        Array<(String, String)>()
    )

    let conn = datasource.connect()

    // 测试插入数据
    let stmt1 = conn.prepareStatement("INSERT INTO users VALUES(NULL, ? , ?, '1.9')")
    let upRet = stmt1.update(SqlInteger(2), SqlNullableVarchar("哈哈"))
    info("lastInsertId = ${upRet.lastInsertId}")

    // 读取
    let stmt2 = conn.prepareStatement("SELECT * FROM users")
    let result = stmt2.query()

    // 填充格式
    var Id = SqlInteger(0)
    var Age = SqlInteger(0)
    var Str = SqlNullableVarchar("")
    var Coin = SqlNullableDouble(Float64(0))
    var CreateAt = SqlNullableTimestamp(DateTime.now())
    var arrDb: Array<SqlDbType> = [Id, Age, Str, Coin, CreateAt]

    var isBool = false
    do {
    	isBool = result.next(arrDb)
    	if (isBool) {
    		info("result(Id = ${Id.value} Age = ${Age.value} Str = ${Str.value}) Coin = ${Coin.value} CreateAt = ${CreateAt.value}")
    	}
    } while (isBool)

    // 测试事务
    try {
        let tx = conn.createTransaction()
        tx.begin()
        let stmtUp = conn.prepareStatement("UPDATE users SET age = ?, create_at = ? WHERE id = ?")
        stmtUp.update(SqlInteger(100), SqlTimestamp(DateTime.now()), SqlInteger(1))

        tx.commit()
    } catch (e: SqlException) {

    }

    return 0
}
