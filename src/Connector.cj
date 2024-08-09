package mysql

import std.collection.*
import std.os.posix.*

class Connector {
    let cfg: Config
	let encodedAttributes: String

    public init(cfg: Config) {
        this.cfg = cfg
		this.encodedAttributes = encodeConnectionAttributes(cfg)
    }
}

func encodeConnectionAttributes(cfg: Config): String {
	var connAttrsBuf = ArrayList<UInt8>()

	connAttrsBuf = appendLengthEncodedString(connAttrsBuf, connAttrClientName)
	connAttrsBuf = appendLengthEncodedString(connAttrsBuf, connAttrClientNameValue)
	connAttrsBuf = appendLengthEncodedString(connAttrsBuf, connAttrOS)
	connAttrsBuf = appendLengthEncodedString(connAttrsBuf, connAttrOSValue) // TODO Win32, Linux, Darwin
	connAttrsBuf = appendLengthEncodedString(connAttrsBuf, connAttrPlatform)
	connAttrsBuf = appendLengthEncodedString(connAttrsBuf, connAttrPlatformValue) // TODO amd64, arm 平台架构
	connAttrsBuf = appendLengthEncodedString(connAttrsBuf, connAttrPid)
	connAttrsBuf = appendLengthEncodedString(connAttrsBuf, "${getpid()}")

	// 只支持 tpc host
	connAttrsBuf = appendLengthEncodedString(connAttrsBuf, connAttrServerHost)
	connAttrsBuf = appendLengthEncodedString(connAttrsBuf, cfg.address)

	return String.fromUtf8(connAttrsBuf.toArray())
}

func appendLengthEncodedString(sb: ArrayList<UInt8>, s: String): ArrayList<UInt8> {
	var b = appendLengthEncodedInteger(sb, s.size)
    let ss = s.toArray()
    b.appendAll(ss)
	return b
}