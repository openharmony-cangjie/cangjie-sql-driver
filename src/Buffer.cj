package mysql

import std.socket.TcpSocket
import std.collection.*
import std.time.*

const defaultBufSize = 4096
const maxCachedBufSize = 256 * 1024

public class Buffer {
    let socket: TcpSocket

    // 保存缓从区的数据, 数据读取不会修改 size, 只会修改 this.length
    var buf = ArrayList<UInt8>()

    // 当前buf读取位置
    var idx: Int = 0
    // this.buf 剩余未读取长度
    var length: Int = 0

    public init(socket: TcpSocket) {
        this.socket = socket
    }

    // 读入缓冲区, 至少读取到need长度的数据
    public func fill(need: Int) {
        if (this.length > 0) {
            this.buf = this.buf[this.idx..]
        } else {
            this.length = 0
            this.buf = ArrayList<UInt8>()
        }

        this.idx = 0

        var n = this.length

        do {
            this.socket.readTimeout = Duration.second * 6000

            let rs = Array<UInt8>(4096, item: 0)
            let nn = this.socket.read(rs) // 无法使用可变长度的数组进行读取
            trace("socket读取: ", rs[0..nn])
            n += nn

            this.buf.appendAll(rs[0..nn])

            if (n < need) {
                continue
            }
            this.length = n
            return
        } while (true)
    }

    // 按照顺序缓冲区读取指定长度的数据
    public func readNext(need: Int): Array<UInt8> {
        if (this.length < need) {
            // 缓冲区数据不够, 填充缓冲区
            this.fill(need)
        }

        let offset = this.idx
        this.idx += need
        this.length -= need
        return this.buf[offset..this.idx].toArray()
    }

    // 从缓冲区开头读取指定长度的数据
    public func takeBuffer(length: Int): ArrayList<UInt8> {
        if (this.length > 0) {
            var buf = ArrayList<UInt8>()
            for (_ in 0..length) {
                buf.append(0)
            }
            return buf
        }

        // 缓冲区多余的数据
        if (length <= this.buf.size) {
            return this.buf[..length]
        }

        var buf = ArrayList<UInt8>()
        for (_ in 0..length) {
            buf.append(0)
        }
        return buf
    }

    public func takeSmallBuffer(length: Int): ArrayList<UInt8> {
        if (this.length > 0) {
            throw Exception("Buffer is not empty")
        }
        return this.buf[..length]
    }

    public func takeCompleteBuffer(): ArrayList<UInt8> {
        if (this.length > 0) {
            error("意外读取, buf 不应该还有数据; length(${this.length}), buf = ", this.buf[this.length..])
            throw Exception("Buffer is not empty")
        }
        return this.buf
    }

    public func store(buf: Array<UInt8>) {
        this.buf = ArrayList<UInt8>(buf)
    }
}
