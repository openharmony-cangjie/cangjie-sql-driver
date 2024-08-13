package mysql

import std.socket.*
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
                throw Exception("命令不同步。您现在无法运行此命令")
            }
            this.sequence++

            if (pktLen == 0) {
                if (prevData.size == 0) {
                    throw Exception("无效的链接")
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
            trace("socket准备写入: ", wData)
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
    public func writeExecutePacket(stmt: MysqlStatement, args: Array<Any>) {
        if (stmt.paramCount != args.size) {
            throw Exception("参数数量不匹配")
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
                	case v:String=>
                        paramTypes.append(UInt8(FieldTypeString))
                        paramTypes.append(0x00)

                	    paramValues.appendAll(v)
                	case v:Int=>
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
        this.writePacket(data)
    }
}