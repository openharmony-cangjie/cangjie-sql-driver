package mysql

import std.collection.*
import crypto.keys.*
import crypto.digest.*
import std.io.*
import std.crypto.digest.*

public func len(a: ArrayList<UInt8>) {
    return a.size
}

// 对原始数组进行操作
public func listCopyList(dest: ArrayList<UInt8>, destStart: Int, src: ArrayList<UInt8>, srcStart: Int, srcStop: Int): Int64 {
    var i = 0
    var destStartVal = destStart
    if ((dest.size - destStart) < (srcStop - srcStart)) {
        for (si in srcStart..srcStop) {
            let sv = src[si]

            if (dest.size > destStartVal) {
                dest[destStartVal] = sv
            } else {
                dest.append(sv)
            }
            destStartVal++
            i++
        }
    } else {
        for (si in srcStart..srcStop) {
            let sv = src[si]

            dest[destStartVal] = sv
            destStartVal++
            i++
        }
    }
    
    return i
}
// 对原始数组进行操作
public func listCopyArray(dest: ArrayList<UInt8>, destStart: Int, src: Array<UInt8>, srcStart: Int, srcStop: Int): Int64 {
    var i = 0
    var destStartVal = destStart
    if ((dest.size - destStart) < (srcStop - srcStart)) {
        for (si in srcStart..srcStop) {
            let sv = src[si]

            if (dest.size > destStartVal) {
                dest[destStartVal] = sv
            } else {
                dest.append(sv)
            }
            destStartVal++
            i++
        }
    } else {
        for (si in srcStart..srcStop) {
            let sv = src[si]

            dest[destStartVal] = sv
            destStartVal++
            i++
        }
    }
    
    return i
}

public func listCopyString(dest: ArrayList<UInt8>, destStart: Int, src: String): Int64 {
    let srcStart: Int = 0 
    let srcStop: Int = src.size

    var i = 0
    var destStartVal = destStart
    if ((dest.size - destStart) < (srcStop - srcStart)) {
        for (si in srcStart..srcStop) {
            let sv = src[si]

            if (dest.size > destStartVal) {
                dest[destStartVal] = sv
            } else {
                dest.append(sv)
            }
            destStartVal++
            i++
        }
    } else {
        for (si in srcStart..srcStop) {
            let sv = src[si]

            dest[destStartVal] = sv
            destStartVal++
            i++
        }
    }
    
    return i
}

func encryptPassword(password: String, seed: Array<UInt8>, pub: RSAPublicKey): Array<UInt8> {
    var plain = password.toArray()
    var i = 0
	for (_ in plain) {
		let j = i % seed.size
		plain[i] ^= seed[j]
        i++
	}

    var bas1 = ByteArrayStream()
    bas1.write(plain)

    var bas2 = ByteArrayStream()

	var encOpt = OAEPOption(SHA1(), SHA256())
    pub.encrypt(bas1, bas2, padType: OAEP(encOpt))

    var buf = Array<Byte>(plain.size, item:0)
    bas2.read(buf)

    return buf
}

struct errors {
	var msg: String = ""

	public init(msg: String) {
		this.msg = msg
	}

	public func IsNull(): Bool {
		return this.msg == ""
	}
}

var nil = errors("")


struct mysqlField <: ToString {
	var tableName :String = ""
	var name      :String = ""
	var length    :UInt32 = 0
	var flags     :UInt16 = 0
	var fieldType :UInt8 = 0
	var decimals  :UInt8 = 0
	var charSet   :UInt8 = 0

	public func toString(): String {
	    var str = "\nmysqlField{\n"
	    str += "\ttableName = ${this.tableName}\n"
	    str += "\tname = ${this.name}\n"
	    str += "\tlength = ${this.length}\n"
	    str += "\tflags = ${this.flags}\n"
	    str += "\tfieldType = ${this.fieldType}\n"
	    str += "\tdecimals = ${this.decimals}\n"
	    str += "\tcharSet = ${this.charSet}\n"
	    str += "}\n"

	    return str
	}
}