package mysql

import std.socket.*
import std.binary.*
import std.collection.*
import std.database.sql.*

// 用户区的子会话
class Stmt {
    let conn: MysqlConn
    let query: String

    var id: UInt32 = 0
    var paramCount: Int = 0

    public init(conn: MysqlConn, query: String) {
        this.conn = conn
        this.query = query
        // 发送指令
        info("准备发送预处理: ", query)
        conn.writeCommandPacketStr(ComStmtPrepare, query)
        // 读取指令
        let columnCount = this.readPrepareResultPacket()
        info("预处理后, 行数量(${columnCount}), 需要参数(${this.paramCount})")
        if (this.paramCount > 0) {
            conn.readUntilEOF()
        }
        if (columnCount > 0) {
            conn.readUntilEOF()
        }
    }

    // 预执行后,  传入具体参数
    public func Exec(args: Array<Any>) {
        // 发送参数包
        this.writeExecutePacket(args)

        // 读取响应
        var resLen = this.conn.readResultSetHeaderPacket()

        debug("couht", resLen)
    }

    public func QueryRow(args: Array<Any>): Array<mysqlField> {
        // 发送参数包
        this.writeExecutePacket(args)

        // 读取响应
        var resLen = this.conn.readResultSetHeaderPacket()
        if (resLen > 0) {
            return this.readColumns(Int64(resLen))
        }

        return Array<mysqlField>()
    }

    public func readColumns(count: Int64): Array<mysqlField> {
        var i: Int64 = 0
        var columns = Array<mysqlField>(Int64(count), item: mysqlField())

        while (true) {
            let data = this.conn.readPacket()
            // 检查是否是结束包
            if (data[0] == 254 && (data.size == 1 || data.size == 5)) {
                if (i == count) {
                    return columns
                }
            }
            var pos = skipLengthEncodedString(data)

            // Database [len coded string]
            var n = skipLengthEncodedString(data[pos..])
            pos += n

            var column = columns[i]

            // Table [len coded string]
            if (this.conn.cfg.ColumnsWithAlias) {
                var (tableName, _, n) = readLengthEncodedString(data[pos..])
                pos += n
                column.tableName = String.fromUtf8(tableName)
            } else {
                var n = skipLengthEncodedString(data[pos..])
                pos += n
            }
            // Original table [len coded string]
            n = skipLengthEncodedString(data[pos..])
            pos += n

            // Name [len coded string]
            var name: Array<UInt8>
            (name, _, n) = readLengthEncodedString(data[pos..])
            column.name = String.fromUtf8(name)
            pos += n

            // Original name [len coded string]
            n = skipLengthEncodedString(data[pos..])
            pos += n

            // Filler [uint8]
            pos++

            // Charset [charset, collation uint8]
            column.charSet = data[pos]
            pos += 2

            // Length [uint32]
            column.length = UInt32.readLittleEndian(data[pos..pos + 4])
            pos += 4

            // Field type [uint8]
            column.fieldType = data[pos]
            pos++

            // Flags [uint16]
            column.flags = UInt16.readLittleEndian(data[pos..pos + 2])
            pos += 2

            // Decimals [uint8]
            column.decimals = data[pos]

            columns[i] = column
            i++
        }

        return columns
    }

    public func Close() {
        if (this.id > 0) {
            return;
        }
        this.id = 0
        this.conn.writeCommandPacketUint32(ComStmtClose, this.id)
    }

    public func readPrepareResultPacket(): UInt16 {
        let data = this.conn.readPacket()
        if (data[0] != 0x00) {
            return 0
        }

        // stmt id [4 bytes]
        this.id = UInt32.readLittleEndian(data[1..5])

        // column count [16 bit uint]
        let columnCount = UInt16.readLittleEndian(data[5..7])

        // param count [16 bit uint]
        this.paramCount = Int64(UInt16.readLittleEndian(data[7..9]))

        return columnCount
    }

    public func Query(args: Array<Any>) {
        dump(args)
    }

    public func writeExecutePacket(args: Array<Any>) {
        if (this.paramCount != args.size) {
            throw Exception("参数数量不匹配")
        }

        let minPktLen = 14
        let mc = this.conn

        var longDataSize = Int64(mc.maxAllowedPacket) / (this.paramCount + 1)
        if (longDataSize < 64) {
            longDataSize = 64
        }

        mc.sequence = 0

        var data: ArrayList<UInt8>
        if (args.size == 0) {
            data = ArrayList<UInt8>(Array<UInt8>(minPktLen, item: 0))
        } else {
            data = mc.buf.takeSmallBuffer(minPktLen)
        }

        // command [1 byte]
        data[4] = ComStmtExecute

        // statement_id [4 bytes]
        data[5] = UInt8(this.id)
        data[6] = UInt8(this.id >> 8)
        data[7] = UInt8(this.id >> 16)
        data[8] = UInt8(this.id >> 24)

        // flags (0: CURSOR_TYPE_NO_CURSOR) [1 byte]
        data[9] = 0x00

        // iteration_count (uint32(1)) [4 bytes]
        data[10] = 0x01
        data[11] = 0x00
        data[12] = 0x00
        data[13] = 0x00

        if (args.size > 0) {
            var pos = minPktLen

            var nullMask = ArrayList<UInt8>()
            let maskLen = (args.size + 7) / 8
            let typesLen = 1 + 2 * args.size
            if (pos + maskLen + typesLen >= data.size) {
                data.appendAll(Array<UInt8>(maskLen + 1, item: 0))
                pos += maskLen
            } else {
                data.appendAll(Array<UInt8>(nullMask.size + 1, item: 0))
                pos += maskLen
            }
            // 新参数边界 1 [1 byte]
            data[pos] = 0x01

            // 每个参数类型分配两个字节的空间 [args.size * 2 bytes]
            let paramTypes = ArrayList<UInt8>()
            // 记录容量 [n bytes]
            var paramValues = ArrayList<UInt8>()

            for (arg in args) {
                // 映射数据库的NULL值
                //                match (arg as SqlNullableDbType) {
                //                    case Node=>
                //                    nullMask[i/8] |= UInt8(1 << (i & 7))
                //                    paramTypes[i+i] = UInt8(FieldTypeNULL)
                //                    paramTypes[i+i+1] = 0x00
                //
                //                    continue
                //                }
                // 对每种不通知值类型进行编码
                match (arg) {
                    case v: String =>
                        paramTypes.append(UInt8(FieldTypeString))
                        paramTypes.append(0x00)

                        paramValues.appendAll(v)
                    case v: Int =>
                        paramTypes.append(UInt8(FieldTypeLongLong))
                        paramTypes.append(0x00)

                        let vByte = Array<UInt8>(8, item: 0)
                        UInt64(v).writeLittleEndian(vByte)

                        paramValues.appendAll(vByte)
                    case _ =>
                        error("无法识别的参数类型｜待支持的类型", arg)
                        throw Exception("无法识别的参数类型｜待支持的类型")
                }
            }

            data.appendAll(paramTypes)
            data.appendAll(paramValues)
        }
        debug("参数数据", data)
        mc.writePacket(data)
    }
}
