package mysql

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
    let stmt1 = conn.prepareStatement("INSERT INTO squareNum VALUES( ?, ? , ?)")
    stmt1.update(SqlInteger(1), SqlInteger(2), SqlNullableVarchar("哈哈"))

    // 读取
    let stmt2 = conn.prepareStatement("SELECT * FROM squarenum")
    let result = stmt2.query()

    info("quere = ", result)
    // 获取数据
    var Id = SqlInteger(0)
    var Age = SqlInteger(0)
    var Str = SqlNullableVarchar("")
    var arrDb: Array<SqlDbType> = [Id, Age, Str]

    var isBool = false
    do {
    	isBool = result.next(arrDb)
        debug("Id = ${Id.value} Age = ${Age.value} Str = ${Str.value} ")
    } while (isBool)

    return 0
}
