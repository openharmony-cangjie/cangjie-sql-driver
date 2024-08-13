package mysql

import std.convert.*
import std.binary.*
import std.collection.*

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