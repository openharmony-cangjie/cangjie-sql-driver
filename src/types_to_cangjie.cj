package mysql

import std.convert.*
import std.binary.*
import std.io.InputStream
import std.io.ByteArrayStream
import std.time.*

class Null {}
var null = Null()

func getInterger8(arr: Array<UInt8>): Option<Int8> {
    if (arr.isEmpty()) {
        return None
    }

    return Int8(UInt8.readLittleEndian(arr))
}

func getInterger16(arr: Array<UInt8>): Option<Int16> {
    if (arr.isEmpty()) {
        return None
    }

    return Int16(UInt16.readLittleEndian(arr))
}

func getInterger32(arr: Array<UInt8>): Option<Int32> {
    if (arr.isEmpty()) {
        return None
    }

    return Int32(UInt32.readLittleEndian(arr))
}

func getInterger64(arr: Array<UInt8>): Option<Int> {
    if (arr.isEmpty()) {
        return None
    }

    return Int64.readLittleEndian(arr)
}


func getFloat32(arr: Array<UInt8>): Option<Float32> {
    if (arr.isEmpty()) {
        return None
    }

    return Float32(Float64.readLittleEndian(arr))
}

func getFloat64(arr: Array<UInt8>): Option<Float64> {
    if (arr.isEmpty()) {
        return None
    }

    return Float64.readLittleEndian(arr)
}

func getString(arr: Array<UInt8>): Option<String> {
    if (arr.isEmpty()) {
        return None
    }

    return String.fromUtf8(arr)
}

func getClob(arr: Array<UInt8>): Option<InputStream> {
    if (arr.isEmpty()) {
        return None
    }

    var stream = ByteArrayStream(arr.size)
    stream.write(arr)
    return stream
}

func getBool(arr: Array<UInt8>): Option<Bool> {
    if (arr.isEmpty()) {
        return None
    }
    return arr[0] == 1
}

func toCharArray(buf: Array<Byte>): Array<Rune> {
    var charArray = Array<Rune>(buf.size, item: Rune(0))
    for (i in 0..buf.size) {
        if (buf[i] < 0) {
            charArray[i] = Rune(0)
        } else {
            charArray[i] = Rune(buf[i])
        }
    }
    return charArray
}

func getTime(arr: Array<UInt8>, column: MysqlColumnInfo): Option<DateTime> {
    if (arr.isEmpty()) {
        return None
    }
    var dstlen: UInt8 = match (column.decimals) {
    	case 1 | 2 | 3 | 4 | 5 | 6=> 19 + 1 + column.decimals
    	case _=> 19
    }

    var date: DateTime
    let pattern = "yyyy-MM-dd HH:mm:ss"
    let str = String.fromUtf8(formatBinaryDateTime(arr, dstlen))
    error(str)
    date = DateTime.parse(str, pattern)
    return date
}