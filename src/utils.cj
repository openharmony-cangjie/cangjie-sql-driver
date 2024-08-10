package mysql

import std.collection.*

// encodes a uint64 value and appends it to the given bytes slice
func appendLengthEncodedInteger(b: ArrayList<UInt8>, n: Int64): ArrayList<UInt8> {
    if (n <= 250) {
        b.append(UInt8(n))
        return b
    }
    if (n <= 0xffff) {
        b.append(UInt8(0xfc))
        b.append(UInt8(n))
        b.append(UInt8(n >> 8))
        return b
    }
    if (n <= 0xffffff) {
        b.append(UInt8(0xfd))
        b.append(UInt8(n))
        b.append(UInt8(n >> 8))
        b.append(UInt8(n >> 16))
        return b
    }

    b.append(UInt8(0xfd))
    b.append(UInt8(n))
    b.append(UInt8(n >> 8))
    b.append(UInt8(n >> 16))
    b.append(UInt8(n >> 24))
    b.append(UInt8(n >> 32))
    b.append(UInt8(n >> 40))
    b.append(UInt8(n >> 48))
    b.append(UInt8(n >> 56))
    return b
}

//读取并解析输入字节片中的长度编码整数，得到待跳过字符串的长度及已读取字节数。
//若字符串长度小于1，则直接返回已读取字节数。
//计算跳过字符串后的新位置。
//检查剩余数据是否足够：若输入字节片长度大于等于新位置，则返回已读取字节数；否则返回已读取字节数和EOF错误。
func skipLengthEncodedString(b: Array<UInt8>): Int {
    // Get length
    var (num, _, n) = readLengthEncodedInteger(b)
    if (num < 1) {
        return n
    }
    n = n + Int64(num)

    // Check data length
    if (b.size >= n) {
        return n
    }

    throw Exception("EOF")
}

// 返回读取的个数、值是否为NULL以及读取的字节数
func readLengthEncodedInteger(b: Array<UInt8>): (UInt64, Bool, Int) {
    if (b.size == 0) {
        return (0, true, 1)
    }

    match (b[0]) {
        // 251: NULL
        case 0xfb => return (0, true, 1)
        // 252: value of following 2
        case 0xfc => return (UInt64(b[1]) | UInt64(b[2]) << 8, false, 3)
        // 253: value of following 3
        case 0xfd => return (UInt64(b[1]) | UInt64(b[2]) << 8 | UInt64(b[3]) << 16, false, 4)
        // 254: value of following 8
        case 0xfe => return (UInt64(b[1]) | UInt64(b[2]) << 8 | UInt64(b[3]) << 16 | UInt64(b[4]) << 24 |
                UInt64(b[5]) << 32 | UInt64(b[6]) << 40 | UInt64(b[7]) << 48 | UInt64(b[8]) << 56, false, 9)
        // 0-250: value of first byte
        case _ => return (UInt64(b[0]), false, 1)
    }
}

func readStatus(b: Array<UInt8>): UInt32 {
    return UInt32(b[0]) | UInt32(b[1]) << 8
}

//从字节切片b读取长度编码字符串的长度。
//如果值为NULL，则返回原切片中的子切片、true及已读字节数。
//若非NULL，则根据长度返回相应子字符串（作为字节切片）、false及已读字节数。
//若输入切片不足以包含整个字符串，则返回错误EOF。
func readLengthEncodedString(b: Array<UInt8>): (Array<UInt8>, Bool, Int64) {
    // Get length
    var (num, isNull, n) = readLengthEncodedInteger(b)
    if (num < 1) {
        return (b[n..n], isNull, n)
    }

    n += Int64(num)

    // Check data length
    if (b.size >= n) {
        return (b[n - Int64(num)..n], false, n)
    }
    throw Exception("EOF")
}
