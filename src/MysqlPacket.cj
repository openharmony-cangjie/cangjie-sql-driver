package mysql

import std.socket.*
import std.database.sql.*
import std.collection.*
import std.convert.*
import std.binary.*
import std.crypto.digest.*
import crypto.digest.*
import crypto.keys.*

// 协议处理
public class MysqlPacket {
    var socket: TcpSocket
    var buf: Buffer
    var sequence: UInt8 = 0

    var maxAllowedPacket: UInt32 = 1<<24 - 1

    public init(socket: TcpSocket) {
    	this.socket = socket
    	this.buf = Buffer(this.socket)
    }

	// 读取一个信息包
    public func readPacket(): Array<UInt8> {
        var prevData = ArrayList<UInt8>()

        do {
            let data = this.buf.readNext(4)

            let pktLen = Int64(UInt32(data[0]) | UInt32(data[1]) << 8 | UInt32(data[2]) << 16)

            if (data[3] != this.sequence) {
                throw SqlException("命令不同步。您现在无法运行此命令")
            }
            this.sequence++

            if (pktLen == 0) {
                if (prevData.size == 0) {
                    throw SqlException("无效的链接")
                }

                return prevData.toArray()
            }

            let body = this.buf.readNext(pktLen)
            if (pktLen < 16777215) {
                // 无需读取下一个拆分的包
                if (prevData.size == 0) {
                    return body
                }
                prevData.appendAll(body)
            }

            prevData.appendAll(body)
        } while (true)

        return prevData.toArray()
    }

    // 组装包和发送
    public func writePacket(bytes: ArrayList<UInt8>) {
        var data = bytes
        var pktLen = data.size - 4

        while (true) {
            var size: Int = 0
            if (pktLen >= maxPacketSize) {
                data[0] = 0xff
                data[1] = 0xff
                data[2] = 0xff
                size = maxPacketSize
            } else {
                data[0] = UInt8(pktLen)
                data[1] = UInt8(pktLen >> 8)
                data[2] = UInt8(pktLen >> 16)
                size = pktLen
            }
            data[3] = this.sequence

            let nLen = 4 + size
            let wData = data[..nLen].toArray()

            this.socket.write(wData)
            // TODO 这里应该需要坚持发送数量的
            // write 返回值无法使用
            this.sequence++

            if (size != maxPacketSize) {
				return
			}
			pktLen -= size
			data = data[size..]
			continue
        }
    }

    func writeCommandPacket(command: UInt8) {
        // Reset Packet Sequence
        this.sequence = 0

        var data = this.buf.takeSmallBuffer(4 + 1)

        // Add command byte
        data[4] = command

        // Send CMD packet
        return this.writePacket(data)
    }

    // 执行一个命令包
    public func writeCommandPacketStr(command: UInt8, arg: String) {
        // 重置计数
        this.sequence = 0

        let pktLen = 1 + arg.size
        var data = this.buf.takeBuffer(pktLen + 4)

        data[4] = command

        var i = 5
        for (s in arg.toArray()) {
            data[i] = s
            i++
        }
        return this.writePacket(data)
    }

    public func writeCommandPacketUint32(command: UInt8, arg: UInt32) {
        this.sequence = 0

        let data = this.buf.takeSmallBuffer(4 + 1 + 4)

        data[4] = command

        // Add arg [32 bit]
        data[5] = UInt8(arg)
        data[6] = UInt8(arg >> 8)
        data[7] = UInt8(arg >> 16)
        data[8] = UInt8(arg >> 24)

        // Send CMD packet
        this.writePacket(data)
    }

    // 执行 stmt 参数包
    public func writeExecutePacket(stmt: MysqlStatement, args: Array<SqlDbType>) {
        if (stmt.paramCount != args.size) {
            throw SqlException("参数数量不匹配 ${stmt.paramCount}, ${args.size}")
        }

        let minPktLen = 14

        var longDataSize = Int64(this.maxAllowedPacket) / (stmt.paramCount + 1)
        if (longDataSize < 64) {
            longDataSize = 64
        }

        this.sequence = 0

        var data: ArrayList<UInt8>
        if (args.size == 0) {
            data = ArrayList<UInt8>(Array<UInt8>(minPktLen, item: 0))
        } else {
            data = this.buf.takeSmallBuffer(minPktLen)
        }

        // command [1 byte]
        data[4] = ComStmtExecute

        // statement_id [4 bytes]
        data[5] = UInt8(stmt.id)
        data[6] = UInt8(stmt.id >> 8)
        data[7] = UInt8(stmt.id >> 16)
        data[8] = UInt8(stmt.id >> 24)

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
                data.appendAll(Array<UInt8>(maskLen + 1, item:0))
                pos += maskLen
            } else {
                data.appendAll(Array<UInt8>(nullMask.size + 1, item:0))
                pos += maskLen
            }
            // 新参数边界 1 [1 byte]
            data[pos] = 0x01

            // 每个参数类型分配两个字节的空间 [args.size * 2 bytes]
            let paramTypes = ArrayList<UInt8>()
            // 记录容量 [n bytes]
            var paramValues = ArrayList<UInt8>()

            for (arg in args) {
                // 对每种不通知值类型进行编码
                match (arg) {
                    // String----SqlChar----CHAR----CHAR----MYSQL_TYPE_STRING----char[]
                    case v: SqlChar => toValString(paramTypes, paramValues, v.value)
                    case v: SqlNullableChar =>
                        match (v.value) {
                        	case Some(v) => toValString(paramTypes, paramValues, v)
                            case None => toNULL(paramValues)
                        }
                    // String----SqlVarchar----VARCHAR----VARCHAR----MYSQL_TYPE_VAR_STRING----char[]
                    case v: SqlVarchar => toValString(paramTypes, paramValues, v.value)
                    case v: SqlNullableVarchar =>
                        match (v.value) {
                        	case Some(v) => toValString(paramTypes, paramValues, v)
                            case None => toNULL(paramValues)
                        }
                    // Array<Byte>----SqlBinary----BINARY----BINARY----MYSQL_TYPE_STRING----char[]
                    case v: SqlBinary => toBinary(paramTypes, paramValues, v.value)
                    case v: SqlNullableBinary =>
                        match (v.value) {
                        	case Some(v) => toBinary(paramTypes, paramValues, v)
                            case None => toNULL(paramValues)
                        }

                    // Array<Byte>----SqlVarBinary----VARBINARY----VARBINARY----MYSQL_TYPE_VAR_STRING----char[]
                    case v: SqlVarBinary => toBinary(paramTypes, paramValues, v.value)
                    case v: SqlNullableVarBinary =>
                        match (v.value) {
                        	case Some(v) => toBinary(paramTypes, paramValues, v)
                            case None => toNULL(paramValues)
                        }

                    // 长字符串，mysql输入对应表格没有给出，在输出表格有对应数据
                    // Array<InputStream>----SqlClob----CLOB----LONGTEXT----MYSQL_TYPE_LONG_BLOB----char[]
                    case v: SqlClob => toClob(paramTypes, paramValues, v.value)
                    case v: SqlNullableClob =>
                        match (v.value) {
                        	case Some(v) => toClob(paramTypes, paramValues, v)
                            case None => toNULL(paramValues)
                        }

                    // Array<InputStream>----SqlBlob----BLOB----BLOB----MYSQL_TYPE_BLOB----char[]
                    case v: SqlBlob => toBlob(paramTypes, paramValues, v.value)
                    case v: SqlNullableBlob =>
                      match (v.value) {
                        	case Some(v) => toBlob(paramTypes, paramValues, v)
                            case None => toNULL(paramValues)
                        }
                    // 布尔类型在mysql数据库中表现形式是TINYINT
                    // Bool----SqlBool----BOOLEAN----TINYINT----MYSQL_TYPE_TINY----signed char
                    case v: SqlBool => toBool(paramTypes, paramValues, v.value)
                    case v: SqlNullableBool =>
                        match (v.value) {
                        	case Some(v) => toBool(paramTypes, paramValues, v)
                            case None => toNULL(paramValues)
                        }

                    // Int8----SqlByte----TINYINT----TINYINT----MYSQL_TYPE_TINY----signed char
                    case v: SqlByte =>
                        paramTypes.append(UInt8(FieldTypeTiny))
                        paramTypes.append(0x00)
                        if (v.value == 1) {
                            paramValues.append(0x01)
                        } else {
                            paramValues.append(0x00)
                        }
                    case v: SqlNullableByte =>
                        match (v.value) {
                        	case Some(v) =>
                                paramTypes.append(UInt8(FieldTypeTiny))
                                paramTypes.append(0x00)
                                if (v == 1) {
                                    paramValues.append(0x01)
                                } else {
                                    paramValues.append(0x00)
                                }
                            case None => toNULL(paramValues)
                        }

                    // Int16----SqlSmallInt----SMALLINT----SMALLINT----MYSQL_TYPE_SHORT----short int
                    case v: SqlSmallInt => toInt16(paramTypes, paramValues, v.value)
                    case v: SqlNullableSmallInt =>
                        match (v.value) {
                        	case Some(v) => toInt16(paramTypes, paramValues, v)
                            case None => toNULL(paramValues)
                        }
                    // SQL类型不同，但是数据值相对应
                    // Int32----SqlInteger----INTEGER----INT----MYSQL_TYPE_LONG----int
                    case v: SqlInteger => toInt32(paramTypes, paramValues, v.value)
                    case v: SqlNullableInteger =>
                        match (v.value) {
                        	case Some(v) => toInt32(paramTypes, paramValues, v)
                            case None => toNULL(paramValues)
                        }

                    // Int64----SqlBigInt----BIGINT----BIGINT----MYSQL_TYPE_LONGLONG----long long int
                    case v: SqlBigInt => toInt64(paramTypes, paramValues, v.value)
                    case v: SqlNullableBigInt =>
                        match (v.value) {
                        	case Some(v) => toInt64(paramTypes, paramValues, v)
                            case None => toNULL(paramValues)
                        }
                    // SQL类型不同，但是数据值相对应
                    // Float32----SqlReal----REAL----FLOAT----MYSQL_TYPE_FLOAT----float
                    case v: SqlReal => toFloat32(paramTypes, paramValues, v.value)
                    case v: SqlNullableReal =>
                        match (v.value) {
                        	case Some(v) => toFloat32(paramTypes, paramValues, v)
                            case None => toNULL(paramValues)
                        }
                    // Float64----SqlDouble----DOUBLE----DOUBLE----MYSQL_TYPE_DOUBLE----double
                    case v: SqlDouble => toFloat64(paramTypes, paramValues, v.value)
                    case v: SqlNullableDouble =>
                        match (v.value) {
                        	case Some(v) => toFloat64(paramTypes, paramValues, v)
                            case None => toNULL(paramValues)
                        }

                    //  DateTime----SqlDate----DATE----DATE----MYSQL_TYPE_DATE----MYSQL_TIME
                    case v: SqlDate => toDateTime(paramTypes, paramValues, v.value)
                    case v: SqlNullableDate =>
                        match (v.value) {
                        	case Some(v) => toDateTime(paramTypes, paramValues, v)
                            case None => toNULL(paramValues)
                        }
                    // DateTime----SqlTime----TIME----TIME----MYSQL_TYPE_TIME----MYSQL_TIME
                    case v: SqlTime => toDateTime(paramTypes, paramValues, v.value)
                    case v: SqlNullableTime =>
                        match (v.value) {
                        	case Some(v) => toDateTime(paramTypes, paramValues, v)
                            case None => toNULL(paramValues)
                        }

                    // DateTime----SqlTimestamp----TIMESTAMP----TIMESTAMP----MYSQL_TYPE_TIMESTAMP----MYSQL_TIME
                    case v: SqlTimestamp => toDateTime(paramTypes, paramValues, v.value)
                    case v: SqlNullableTimestamp =>
                        match (v.value) {
                        	case Some(v) => toDateTime(paramTypes, paramValues, v)
                            case None => toNULL(paramValues)
                        }

                    case s: SqlDbType => throw SqlException("无法识别的参数类型｜待支持的类型 SqlDbType.name = ${s.name}")
                }
            }

            data.appendAll(paramTypes)
            data.appendAll(paramValues)
        }

        this.writePacket(data)
    }
}

func toNULL(paramTypes: ArrayList<UInt8>) {
    paramTypes.append(UInt8(FieldTypeNULL))
    paramTypes.append(0x00)
}