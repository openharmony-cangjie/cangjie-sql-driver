package mysql

import std.socket.*
import std.database.sql.*
import std.collection.*
import std.convert.*
import std.binary.*
import std.crypto.digest.*
import crypto.digest.*
import crypto.keys.*

public class MysqlTcp {
    public var socket: TcpSocket
    public var config: MysqlConfig
    public var packet: MysqlPacket


    // 状态标志（Status Flags）通常用于描述 MySQL 服务器或客户端会话的各种状态信息
    var status: UInt32 = 0

    public init(cfg: MysqlConfig) {
    	this.config = cfg

        this.socket = TcpSocket(cfg.address, cfg.port)
        this.socket.connect()

        this.packet = MysqlPacket(this.socket)

        MysqlAuth(this).login()
    }

    public func close() {
    	return this.packet.writeCommandPacket(ComQuit)
    }

    // 字符串的命令
    public func writeCommandPacketStr(command: UInt8, arg: String) {
    	return this.packet.writeCommandPacketStr(command, arg)
    }

    public func writePacket(bytes: ArrayList<UInt8>) {
    	return this.packet.writePacket(bytes)
    }

    public func readPacket(): Array<UInt8> {
    	return this.packet.readPacket()
    }

    // 读取结束, 如果发送错误直接抛出异常
    public func readUntilEOF() {
        do {
            let data = this.readPacket()
            match (data[0]) {
                // iERR
                case 0xff =>
                    this.handleErrorPacket(data)
                    return
                // iEOF
                case 0xfe =>
                    if (data.size == 5) {
                        this.status = readStatus(data[3..])
                    }
                    return
                case _ => continue
            }
        } while (true)
    }

    // 错误包处理
    public func handleErrorPacket(data: Array<UInt8>) {
        let errNum = UInt16.readLittleEndian(data[1..3])

        let errStr = String.fromUtf8(data[9..])

        throw SqlException("mysql error coce: ${errNum}; message: ${errStr}")
    }

    // 写入命令
    public func writeCommandPacketUint32(command: UInt8, arg: UInt32) {
        this.packet.writeCommandPacketUint32(command, arg)
    }

    // Exec 参数
    public func writeExecutePacket(stmt: MysqlStatement, args: Array<SqlDbType>) {
        this.packet.writeExecutePacket(stmt, args)
    }

    // clearResult.readResultSetHeaderPacket
    public func readResultSetHeaderPacket(): (Int64, Int64, Int64) {
        let data = this.readPacket()
        match (data[0]) {
        	case 0=>
        	    let (affectedRows, insertId) = this.handleOkPacket(data)
        	    return (0, affectedRows, insertId)
        	case 255=>
        	    // 识别不同错误
                this.handleErrorPacket(data)
                return (0, 0, 0)
        	case 251=>
        	    throw SqlException("TODO iLocalInFile readResultSetHeaderPacket")

        	case _ =>
                // 读取 column 数量
                var (num, _, _) = readLengthEncodedInteger(data)
                return (Int64(num), 0, 0)
        }

        // 读取 column 数量
		var (num, _, _) = readLengthEncodedInteger(data)
		return (Int64(num), 0, 0)
    }

    // 成功处理的包解析
    // https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_basic_ok_packet.html
    public func handleOkPacket(data: Array<UInt8>): (Int64, Int64) {
        // 0x00 [1 byte]

        // 受影响的行
        let (affectedRows, _, n) = readLengthEncodedInteger(data[1..])

        // 新插入数据的ID
        let (insertId, _, m) = readLengthEncodedInteger(data[1 + n..])

        // server_status [2 bytes]
        this.status = readStatus(data[1 + n + m..1 + n + m + 2])

        return (Int64(affectedRows), Int64(insertId))
    }

    // 便捷丢弃 affectedRows 和 insertIds.
    public func discardResults() {
        while ((this.status&StatusMoreResultsExists) != 0) {
            let (resLen, _, _) = this.readResultSetHeaderPacket()
            if (resLen > 0) {
                // columns
                this.readUntilEOF()
                // rows
                this.readUntilEOF()
            }
        }
    }
}