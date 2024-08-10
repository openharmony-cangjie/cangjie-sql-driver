package mysql

import std.socket.*
import std.collection.*
import std.convert.*
import std.binary.*
import std.crypto.digest.*
import crypto.digest.*
import crypto.keys.*

class MysqlConn {
    let socket: TcpSocket

    var cfg: Config
    var connector: Connector

    var sequence: UInt8 = 0

    // 用于与客户端协商通讯方式
    var flags: UInt32 = 0
    // 状态标志（Status Flags）通常用于描述 MySQL 服务器或客户端会话的各种状态信息
    var status: UInt32 = 0

    var buf: Buffer

    var result: MysqlResult = MysqlResult()

    var maxAllowedPacket: UInt32 = 1 << 24 - 1

    public init(cfg: Config) {
        this.cfg = cfg
        this.connector = Connector(this.cfg)

        var socket = TcpSocket(cfg.address, cfg.port)

        socket.connect()
        this.socket = socket

        this.buf = Buffer(this.socket)

        // 认证随机数和方式
        // plugin: caching_sha2_password
        var (authData, plugin) = this.readHandshakePacket()
        if (plugin == "") {
            plugin = "mysql_native_password"
        }
        info("解析认证随机数和方式: plugin(${plugin}) authData(${authData})")

        // 准备发送认证数据包
        let authResp = this.auth(authData, plugin)
        this.writeHandshakeResponsePacket(authResp, plugin)

        this.handleAuthResult(authData, plugin)

        // Handle DSN Params
        this.handleParams()
    }

    // 认证Handshake
    public func writeHandshakeResponsePacket(authResp: Array<UInt8>, plugin: String) {
        var clientFlags = ClientProtocol41 | ClientSecureConn | ClientLongPassword | ClientTransactions |
            ClientLocalFiles | ClientPluginAuth | ClientMultiResults | ClientConnectAttrs | this.flags & ClientLongFlag

        // 对密码长度进行固定编码
        var authRespLEIBuf = ArrayList<UInt8>()
        var authRespLEI = appendLengthEncodedInteger(authRespLEIBuf, authResp.size)

        if (authRespLEI.size > 1) {
            clientFlags |= ClientPluginAuthLenEncClientData
        }

        var pktLen = 4 + 4 + 1 + 23 + this.cfg.user.size + 1 + authRespLEI.size + authResp.size + 21 + 1

        if (this.cfg.database.size > 0) {
            clientFlags |= ClientConnectWithDB
            pktLen += this.cfg.database.size + 1
        }

        // 对属性进行编码
        var connAttrsLEIBuf = ArrayList<UInt8>()
        var connAttrsLen = this.connector.encodedAttributes.size
        var connAttrsLEI = appendLengthEncodedInteger(connAttrsLEIBuf, connAttrsLen)
        pktLen += connAttrsLEI.size + this.connector.encodedAttributes.size

        let data = this.buf.takeBuffer(pktLen + 4)

        // ClientFlags [32 bit]
        data[4] = truncateToByte(clientFlags)
        data[5] = truncateToByte(clientFlags >> 8)
        data[6] = truncateToByte(clientFlags >> 16)
        data[7] = truncateToByte(clientFlags >> 24)

        // MaxPacketSize [32 bit] (none)
        data[8] = 0x00
        data[9] = 0x00
        data[10] = 0x00
        data[11] = 0x00

        // Collation ID [1 byte]
        let cname = this.cfg.collation

        data[12] = UInt8(collations[cname])

        // Filler [23 bytes] (all 0x00)
        var pos = 13
        while (pos < 13 + 23) {
            pos++
            data[pos] = 0
        }

        // SSL 不支持
        if (this.cfg.user.size > 0) {
            for (s in this.cfg.user.toArray()) {
                data[pos] = s
                pos++
            }
        }
        data[pos] = 0x00
        pos++

        pos += listCopyList(data, pos, authRespLEI, 0, authRespLEI.size)
        pos += listCopyArray(data, pos, authResp, 0, authResp.size)

        if (this.cfg.database.size > 0) {
            pos += listCopyString(data, pos, this.cfg.database)
            data[pos] = 0x00
            pos++
        }

        pos += listCopyString(data, pos, plugin)
        data[pos] = 0x00
        pos++

        // Connection Attributes
        pos += listCopyList(data, pos, connAttrsLEI, 0, connAttrsLEI.size)
        pos += listCopyString(data, pos, this.connector.encodedAttributes)

        // 开始发送数据包
        return this.writePacket(data[..pos])
    }

    // 获取认证加密数据
    public func auth(authData: Array<UInt8>, plugin: String): Array<UInt8> {
        match (plugin) {
            case "caching_sha2_password" =>
                // MySQL 8+ 默认验证方式 (SHA256)
                return sha256(authData, this.cfg.password)

            case "mysql_native_password" => return sha1(authData[..20], this.cfg.password)
            case _ => throw Exception("不支持的认证方式 ${plugin}")
        }

        return Array<UInt8>()
    }

    // Handshake Packet格式
    // https://callmejiagu.github.io/2018/10/26/MySQL%E5%8D%8F%E8%AE%AEHandshake%E8%A7%A3%E6%9E%90%EF%BC%88%E4%B8%89%EF%BC%89/
    public func readHandshakePacket(): (Array<UInt8>, String) {
        var data = this.readPacket()
        var plugin: String = ""

        // 检查 1 byte 协议版本
        if (data[0] == 0xff) {
            throw Exception("无效的版本字段")
        }
        if (data[0] < 10) {
            throw Exception("不支持的版本号")
        }

        var pos: Int = 0
        for (i in 1..=data.size) {
            // null 结尾之前是服务器版本号
            // 连接id[4字节]
            if (data[i] == UInt8(0)) {
                pos = i + 1 + 4 // i = 1; 开头;
                break
            }
        }

        // 随机数, 用于后面密码认证; 8 + 1（0x00表示结束)
        var authData = ArrayList<UInt8>(data[pos..pos + 8])
        pos += 8 + 1

        // 与客户端协商通讯方式: 65535
        this.flags = UInt32(UInt16.readLittleEndian(data[pos..pos + 2]))
        pos += 2

        if (data.size > pos) {
            // 编码格式 [1 byte]
            // 服务器状态 [2 bytes]
            // 扩展的协议，数据库提供的功能 (upper 2 bytes) [2 bytes]
            // 身份验证插件长度 [1 byte]
            // 保留字节 (all [00]) [10 bytes]
            pos += 1 + 2 + 2 + 1 + 10

            // 随机数（第二部分）
            authData.appendAll(data[pos..pos + 12])
            pos += 13

            // EOF if version (>= 5.5.7 and < 5.5.10) or (>= 5.6.0 and < 5.6.2)
            // \NUL otherwise
            var end: Int = -1
            for (i in pos..=data.size) {
                if (data[i] == UInt8(0)) {
                    end = i
                    break
                }
            }

            if (end != -1) {
                plugin = String.fromUtf8(data[pos..end])
            } else {
                plugin = String.fromUtf8(data[pos..])
            }

            return (authData[0..20].toArray(), plugin)
        }

        return (authData[0..8].toArray(), plugin)
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

    public func handleAuthResult(oldAuth: Array<UInt8>, plugin: String) {
        var oldAuthData = oldAuth
        var (authData, newPlugin) = this.readAuthResult()

        if (newPlugin.size > 0) {
            // TODO
            throw Exception("不支持的插件")
        }

        if (authData.size == 0) {
            authData = oldAuthData
        } else {
            oldAuthData = authData
        }
        match (plugin) {
            case "caching_sha2_password" =>
                // MySQL 8+ 默认验证方式 (SHA256)
                if (authData.size == 0) {
                    return;
                }
                if (authData.size == 1) {
                    match (authData[0]) {
                        case 3 =>
                            // 登录成功
                            let data = this.readPacket()
                            if (data[0] == 0x00) {
                                return;
                            }
                            throw Exception("handleAuthResult 3效的认证结果 {authData}")
                        case 4 => throw Exception("认证结果 4 需要重新发起认证 {authData}")
                        // // 检查 tls 连接 TODO
                        // if (this.cfg.tls) {
                        //     // TODO
                        //     throw Exception("不支持的tls 1")
                        // } else {
                        //     var wData = this.buf.takeSmallBuffer(4 + 1)
                        //     wData[4] = 2
                        //     this.writePacket(wData)
                        //     let rData = this.readPacket()

                        //     if (rData[0] != iAuthMoreData) {
                        //         throw Exception("服务器对caching.sha2-password的响应异常，请执行完全身份验证")
                        //     }
                        //     // 解析 public key
                        //     let pubKey = RSAPublicKey.decodeFromPem(String.fromUtf8(rData[1..]))
                        //     this.sendEncryptedPassword(oldAuthData, pubKey)
                        // }
                        case _ => throw Exception("handleAuthResult case _ 无效的认证结果 {authData}")
                    }
                }

            case "sha256_password" =>
                if (authData.size == 0) {
                    return;
                }
                let data = this.readPacket()
                if (data[0] == 0x00) {
                    return;
                }
            case _ => return;
        }
    }

    public func sendEncryptedPassword(seed: Array<UInt8>, pub: RSAPublicKey) {
        let enc = encryptPassword(this.cfg.password, seed, pub)

        this.writeAuthSwitchPacket(enc)
    }

    public func writeAuthSwitchPacket(authData: Array<UInt8>) {
        let pktLen = 4 + authData.size
        let data = this.buf.takeSmallBuffer(pktLen)

        // Add the auth data [EOF]
        listCopyArray(data, 4, authData, 0, authData.size)
        return this.writePacket(data)
    }

    // 
    public func readResultOK() {
        let data = this.readPacket()

        if (data[0] == 0x00) {
            return this.handleOkPacket(data)
        }
        throw Exception("readResultOK无效的认证结果")
    }

    // clearResult.readResultSetHeaderPacket
    public func readResultSetHeaderPacket(): Int64 {
        let data = this.readPacket()
        match (data[0]) {
            case 0 =>
                this.handleOkPacket(data)
                return 0
            case 255 =>
                // 识别不同错误
                this.handleErrorPacket(data)
                return 0
            case 251 =>
                throw Exception("TODO iLocalInFile readResultSetHeaderPacket")
                return 0

            case _ =>
                // 读取 column 数量
                var (num, _, _) = readLengthEncodedInteger(data)
                return Int64(num)
        }

        // 读取 column 数量
        var (num, _, _) = readLengthEncodedInteger(data)
        return Int64(num)
    }

    // 便捷丢弃 affectedRows 和 insertIds.
    public func discardResults() {
        while ((this.status & StatusMoreResultsExists) != 0) {
            let resLen = this.readResultSetHeaderPacket()
            if (resLen > 0) {
                // columns
                this.readUntilEOF()
                // rows
                this.readUntilEOF()
            }
        }
    }

    // 成功处理的包解析
    // https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_basic_ok_packet.html
    public func handleOkPacket(data: Array<UInt8>) {
        // 0x00 [1 byte]

        // 受影响的行
        let (affectedRows, _, n) = readLengthEncodedInteger(data[1..])

        // 新插入数据的ID
        let (insertId, _, m) = readLengthEncodedInteger(data[1 + n..])

        // Update for the current statement result (only used by
        // readResultSetHeaderPacket).
        if (this.result.affectedRows.size > 0) {
            this.result.affectedRows[this.result.affectedRows.size - 1] = Int64(affectedRows)
        }
        if (this.result.insertIds.size > 0) {
            this.result.insertIds[this.result.insertIds.size - 1] = Int64(insertId)
        }

        // server_status [2 bytes]
        this.status = readStatus(data[1 + n + m..1 + n + m + 2])
    }

    public func readAuthResult(): (Array<UInt8>, String) {
        let data = this.readPacket()

        match (data[0]) {
            case 0x00 => return (Array<UInt8>(), "")
            case 0x01 => return (data[1..], "")
            case 0xfe => // iEOF
                if (data.size == 1) {
                    return (Array<UInt8>(), "mysql_old_password")
                }

                throw Exception("无效的认证结果 01")
            case _ =>
                error("无效的认证结果", data)
                throw Exception("无效的认证结果 02")
        }
    }

    public func handleParams() {
        return
    }

    // 与执行 sql
    public func Prepare(query: String): Stmt {
        return Stmt(this, query)
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

        throw Exception("mysql error coce: ${errNum}; message: ${errStr}")
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
}
