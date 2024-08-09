### TIP

仓颉语言原生 mysql 驱动

### 使用

当前只是用 msyql8.0 验证

````
main(): Int64 {
    info("启动。。。")
    let mysql = Config("localhost", 3307, "root", "root", "temp").Build()
    info("链接成功")
    var stmt = mysql.Prepare("INSERT INTO squareNum VALUES( ?, ? )")
    info("插入数据")
    stmt.Exec(100,200)

    var stmtOut = mysql.Prepare("SELECT squareNumber FROM squarenum WHERE number = ?")
    var data = stmtOut.QueryRow(2)
    info("读取信息 = ", data)

    return 0
}
````

### 参考

https://github.com/go-sql-driver/mysql