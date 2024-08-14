package mysql

import std.convert.*
import std.binary.*
import std.collection.*
import std.io.InputStream
import std.io.ByteArrayStream
import std.time.*

func toString(paramTypes: ArrayList<UInt8>, paramValues: ArrayList<UInt8>, v: Array<UInt8>) {
    paramTypes.append(UInt8(FieldTypeString))
    paramTypes.append(0x00)

    appendLengthEncodedInteger(paramValues, v.size)
    paramValues.appendAll(v)
}

func toBinary(paramTypes: ArrayList<UInt8>, paramValues: ArrayList<UInt8>, v: Array<Byte>) {
    paramTypes.append(UInt8(FieldTypeString))
    paramTypes.append(0x00)

    appendLengthEncodedInteger(paramValues, v.size)
    paramValues.appendAll(v)
}

func toValString(paramTypes: ArrayList<UInt8>, paramValues: ArrayList<UInt8>, v: String) {
    paramTypes.append(UInt8(FieldTypeVarString))
    paramTypes.append(0x00)

    appendLengthEncodedInteger(paramValues, v.size)
    paramValues.appendAll(v)
}

func toBool(paramTypes: ArrayList<UInt8>, paramValues: ArrayList<UInt8>, v: Bool) {
    paramTypes.append(UInt8(FieldTypeTiny))
    paramTypes.append(0x00)

    if (v) {
        paramValues.append(0x01)
    } else {
        paramValues.append(0x00)
    }
}

func toClob(paramTypes: ArrayList<UInt8>, paramValues: ArrayList<UInt8>, v: InputStream) {
    paramTypes.append(UInt8(FieldTypeLongBLOB))
    paramTypes.append(0x00)

    var arr: Array<Byte> = Array<Byte>(1, item: 0)
    var list: ArrayList<Byte> = ArrayList<Byte>()
    var length: Int64 = 0
    while (true) {
        var date: Int64 = v.read(arr)
        if (date == 0) {
            break
        }
        list.append(arr[0])
        length++
    }
    
    appendLengthEncodedInteger(paramValues, length)
    paramValues.appendAll(list)
}

func toBlob(paramTypes: ArrayList<UInt8>, paramValues: ArrayList<UInt8>, v: InputStream) {
    paramTypes.append(UInt8(FieldTypeBLOB))
    paramTypes.append(0x00)

    var arr: Array<Byte> = Array<Byte>(1, item: 0)
    var list: ArrayList<Byte> = ArrayList<Byte>()
    var length: Int64 = 0
    while (true) {
        var date: Int64 = v.read(arr)
        if (date == 0) {
            break
        }
        list.append(arr[0])
        length++
    }

    appendLengthEncodedInteger(paramValues, length)
    paramValues.appendAll(list)
}

func toInt16(paramTypes: ArrayList<UInt8>, paramValues: ArrayList<UInt8>, v: Int16) {
    paramTypes.append(UInt8(FieldTypeLongLong))
    paramTypes.append(0x00)

    let vByte = Array<UInt8>(8, item: 0)
    UInt64(v).writeLittleEndian(vByte)
    paramValues.appendAll(vByte)
}

func toInt32(paramTypes: ArrayList<UInt8>, paramValues: ArrayList<UInt8>, v: Int32) {
    paramTypes.append(UInt8(FieldTypeLongLong))
    paramTypes.append(0x00)

    let vByte = Array<UInt8>(8, item: 0)
    UInt64(v).writeLittleEndian(vByte)
    paramValues.appendAll(vByte)
}

func toInt64(paramTypes: ArrayList<UInt8>, paramValues: ArrayList<UInt8>, v: Int64) {
    paramTypes.append(UInt8(FieldTypeLongLong))
    paramTypes.append(0x00)

    let vByte = Array<UInt8>(8, item: 0)
    UInt64(v).writeLittleEndian(vByte)
    paramValues.appendAll(vByte)
}

func toFloat32(paramTypes: ArrayList<UInt8>, paramValues: ArrayList<UInt8>, v: Float32) {
    paramTypes.append(UInt8(FieldTypeFloat))
    paramTypes.append(0x00)

    let vByte = Array<UInt8>(8, item: 0)
    Float32(v).writeLittleEndian(vByte)
    paramValues.appendAll(vByte)
}


func toFloat64(paramTypes: ArrayList<UInt8>, paramValues: ArrayList<UInt8>, v: Float64) {
    paramTypes.append(UInt8(FieldTypeFloat))
    paramTypes.append(0x00)

    let vByte = Array<UInt8>(8, item: 0)
    Float32(v).writeLittleEndian(vByte)
    paramValues.appendAll(vByte)
}

// 用字符串先实现
func toDateTime(paramTypes: ArrayList<UInt8>, paramValues: ArrayList<UInt8>, v: DateTime) {
    paramTypes.append(UInt8(FieldTypeString))
    paramTypes.append(0x00)

    let str = v.toString()
    appendLengthEncodedInteger(paramValues, str.size)
    paramValues.appendAll(str)
}