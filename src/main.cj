package mysql

import std.socket.*
import std.time.*
import std.sync.*
import std.os.posix

main(): Int64 {
    info("启动。。。")
    let mysql = Config("localhost", 3306, "root", "root", "temp").Build()
    info("链接成功")
    var stmt = mysql.Prepare("INSERT INTO squareNum VALUES( ?, ? )")
    info("插入数据")
    stmt.Exec(101,201)

    var stmtOut = mysql.Prepare("SELECT squareNumber FROM squarenum WHERE number = ?")
    var data = stmtOut.QueryRow(2)
    info("读取信息 = ", data)

    runTcpServer()

    return 0
}

let SERVER_PORT: UInt16 = 33333

func runTcpServer() {
    try (serverSocket = TcpServerSocket(bindAt: SERVER_PORT)) {
        serverSocket.bind()

        try (client = serverSocket.accept()) {
            let buf = Array<Byte>(10, item: 0)
            let count = client.read(buf)

            // Server read 3 bytes: [1, 2, 3, 0, 0, 0, 0, 0, 0, 0]
            println("Server read ${count} bytes: ${buf}")
        }
    }
}