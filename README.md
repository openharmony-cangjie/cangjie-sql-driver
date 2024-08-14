### TIP

仓颉语言原生 mysql 驱动


gitcode每次推送会导致404，稳定前优先使用 github。

https://github.com/openharmony-cangjie/cangjie-sql-driver

备份地址 https://gitcode.com/service/cangjie-sql-driver/overview

### 使用

当前只是用 msyql8.0, mysql 5.7 验证

````
CREATE TABLE `users` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `age` int DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
````

### 安装

引入依赖管理
````toml
[dependencies]
mysql = {git = "https://gitcode.com/service/cangjie-sql-driver.git", branch = "main", version = "0.0.1"}
````
执行命令安装
````shell
cjpm update
````

编写代码, 查看 [example_test](example_test)
````cj
package example_test

import std.database.sql.*
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
    let stmt1 = conn.prepareStatement("INSERT INTO users VALUES(NULL, ? , ?)")
    let upRet = stmt1.update(SqlInteger(2), SqlNullableVarchar("哈哈"))
    info("lastInsertId = ${upRet.lastInsertId}")

    // 读取
    let stmt2 = conn.prepareStatement("SELECT * FROM users")
    let result = stmt2.query()

    // 填充格式
    var Id = SqlInteger(0)
    var Age = SqlInteger(0)
    var Str = SqlNullableVarchar("")
    var arrDb: Array<SqlDbType> = [Id, Age, Str]

    var isBool = false
    do {
    	isBool = result.next(arrDb)
    	if (isBool) {
    		info("result(Id = ${Id.value} Age = ${Age.value} Str = ${Str.value})")
    	}
    } while (isBool)

    // 测试事务
    try {
        let tx = conn.createTransaction()
        tx.begin()
        let stmtUp = conn.prepareStatement("UPDATE users SET age = ? WHERE id = ?")
        stmtUp.update(SqlInteger(100), SqlInteger(1))

        tx.commit()
    } catch (e: SqlException) {

    }

    return 0
}

````

### 参考

- https://github.com/go-sql-driver/mysql
- https://gitcode.com/Cangjie-TPC/mysqlclient-ffi.git