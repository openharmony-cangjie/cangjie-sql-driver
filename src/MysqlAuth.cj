package mysql

import std.socket.*
import std.collection.*
import std.convert.*
import std.binary.*
import std.crypto.digest.*
import crypto.digest.*
import crypto.keys.*

public class MysqlAuth {
    public var tcp: MysqlTcp

    // 用于与客户端协商通讯方式
    var flags: UInt32 = 0

    var connector: Connector

    public init(mtcp: MysqlTcp) {
        this.tcp = mtcp

        this.connector = Connector(this.tcp.config)
    }

    public func login() {
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

    // 获取认证加密数据
    public func auth(authData: Array<UInt8>, plugin: String): Array<UInt8> {
        match (plugin) {
            case "caching_sha2_password" =>
                // MySQL 8+ 默认验证方式 (SHA256)
                return sha256(authData, this.tcp.config.password)

            case "mysql_native_password" => return sha1(authData[..20], this.tcp.config.password)
            case _ => throw Exception("不支持的认证方式 ${plugin}")
        }

        return Array<UInt8>()
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

        var pktLen = 4 + 4 + 1 + 23 + this.tcp.config.user.size + 1 + authRespLEI.size + authResp.size + 21 + 1

        if (this.tcp.config.database.size > 0) {
            clientFlags |= ClientConnectWithDB
            pktLen += this.tcp.config.database.size + 1
        }

        // 对属性进行编码
        var connAttrsLEIBuf = ArrayList<UInt8>()
        var connAttrsLen = this.connector.encodedAttributes.size
        var connAttrsLEI = appendLengthEncodedInteger(connAttrsLEIBuf, connAttrsLen)
        pktLen += connAttrsLEI.size + this.connector.encodedAttributes.size

        let data = this.tcp.packet.buf.takeBuffer(pktLen + 4)

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
        let cname = this.tcp.config.collation

        data[12] = UInt8(collations[cname])

        // Filler [23 bytes] (all 0x00)
        var pos = 13
        while (pos < 13 + 23) {
            pos++
            data[pos] = 0
        }

        // SSL 不支持
        if (this.tcp.config.user.size > 0) {
            for (s in this.tcp.config.user.toArray()) {
                data[pos] = s
                pos++
            }
        }
        data[pos] = 0x00
        pos++

        pos += listCopyList(data, pos, authRespLEI, 0, authRespLEI.size)
        pos += listCopyArray(data, pos, authResp, 0, authResp.size)

        if (this.tcp.config.database.size > 0) {
            pos += listCopyString(data, pos, this.tcp.config.database)
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
        return this.tcp.packet.writePacket(data[..pos])
    }

    // Handshake Packet格式
    // https://callmejiagu.github.io/2018/10/26/MySQL%E5%8D%8F%E8%AE%AEHandshake%E8%A7%A3%E6%9E%90%EF%BC%88%E4%B8%89%EF%BC%89/
    public func readHandshakePacket(): (Array<UInt8>, String) {
        var data = this.tcp.packet.readPacket()
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
                            let data = this.tcp.packet.readPacket()
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
                let data = this.tcp.packet.readPacket()
                if (data[0] == 0x00) {
                    return;
                }
            case _ => return;
        }
    }

    public func readAuthResult(): (Array<UInt8>, String) {
        let data = this.tcp.packet.readPacket()

        match (data[0]) {
            case 0x00 => throw Exception("无效的认证结果 00")
            case 0x01 => return (data[1..], "")
            case 0xfe => // iEOF
                if (data.size == 1) {
                    return (Array<UInt8>(), "mysql_old_password")
                }

                throw Exception("无效的认证结果 01")
            case _ => throw Exception("无效的认证结果 02")
        }
    }

    public func handleParams() {
        return
    }
}
