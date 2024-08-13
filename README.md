### TIP

仓颉语言原生 mysql 驱动


gitcode每次推送会导致404，稳定前优先使用 github。

https://github.com/openharmony-cangjie/cangjie-sql-driver

备份地址 https://gitcode.com/service/cangjie-sql-driver/overview

### 使用

当前只是用 msyql8.0 验证; 开发中，还未稳定

````
CREATE TABLE `squareNum` (
`number` int NOT NULL,
`squareNumber` int DEFAULT NULL,
PRIMARY KEY (`number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
````

````
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
````

### 参考

https://github.com/go-sql-driver/mysql
https://gitcode.com/Cangjie-TPC/mysqlclient-ffi.git