package mysql

import std.convert.*
import std.binary.*

class Null {}
var null = Null()


func getInterger64(arr: Array<UInt8>): Option<Int> {
    if (arr.isEmpty()) {
        return None
    }

    // 先转换为字符串在转换为Int
    return Int64.readLittleEndian(arr)
}

func getInterger32(arr: Array<UInt8>): Option<Int32> {
    if (arr.isEmpty()) {
        return None
    }

    // 先转换为字符串在转换为Int
    return Int32(UInt32.readLittleEndian(arr))
}


func getString(arr: Array<UInt8>): Option<String> {
    if (arr.isEmpty()) {
        return None
    }

    return String.fromUtf8(arr)
}