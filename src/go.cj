package mysql

import std.collection.*
import crypto.keys.*
import crypto.digest.*
import std.io.*
import std.crypto.digest.*
import std.binary.*

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


var zeroDateTime = "0000-00-00 00:00:00.000000".toArray()
const digits01 = "0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789"
const digits10 = "0000000000111111111122222222223333333333444444444455555555556666666666777777777788888888889999999999"

// 格式化时间
func formatBinaryDateTime(src: Array<UInt8>, length: UInt8): Array<UInt8> {
	if (src.size == 0) {
		return zeroDateTime[..Int64(length)]
	}
	var dst = ArrayList<UInt8>()

    let year = UInt16.readLittleEndian(src[..2])
	var pt = Int64(year / 100)
	var p1 = Int64(year - 100*UInt16(pt))
	var p2 = Int64(src[2])
	var p3 = Int64(src[3])
	dst.append(digits10[pt]); dst.append(digits01[pt]);
	dst.append(digits10[p1]); dst.append(digits01[p1]); dst.append(b'-');
	dst.append(digits10[p2]); dst.append(digits01[p2]); dst.append(b'-');
	dst.append(digits10[p3]); dst.append(digits01[p3]);
    if (length == 10) {
		return dst.toArray()
	}
	if (src.size == 4) {
	    dst.appendAll(zeroDateTime[10..Int64(length)])
		return dst.toArray()
	}
	dst.append(32)
	p1 = Int64(src[4]) // hour
	let srcNew = src[5..]

	// p1 is 2-digit hour, src is after hour
	p2 = Int64(srcNew[0])
	p3 = Int64(srcNew[1])
	dst.append(digits10[p1]); dst.append(digits01[p1]); dst.append(b':');
	dst.append(digits10[p2]); dst.append(digits01[p2]); dst.append(b':');
	dst.append(digits10[p3]); dst.append(digits01[p3]);

    return appendMicrosecs(dst, srcNew[2..], Int64(Int64(length) - 20))
}

// 填充微秒
func appendMicrosecs(dst: ArrayList<UInt8>, src: Array<UInt8>, decimals: Int64): Array<UInt8> {
	if (decimals <= 0) {
		return dst.toArray()
	}
	// mysql 可以不用微妙

//	if (src.size == 0) {
//	    dst.appendAll(".000000".toArray())
//		return dst.toArray()
//	}

    return dst.toArray()
}
