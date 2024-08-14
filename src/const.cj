package mysql

const maxPacketSize = 1 << 24 - 1

// column.flags
const flagNotNULL: UInt16 = 1
const flagPriKey: UInt16 = 2
const flagUniqueKey: UInt16 = 4
const flagMultipleKey: UInt16 = 8
const flagBLOB: UInt16 =  16
const flagUnsigned: UInt16 = 32
const flagZeroFill: UInt16 = 64
const flagBinary: UInt16 = 128
const flagEnum: UInt16 = 256
const flagAutoIncrement: UInt16 = 512
const flagTimestamp: UInt16 = 1024
const flagSet: UInt16 = 2048
const flagUnknown1: UInt16 = 4096
const flagUnknown2: UInt16 = 8192
const flagUnknown3: UInt16 = 16384
const flagUnknown4: UInt16 = 32768


// https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_connection_phase_packets_protocol_handshake_response.html
const ClientLongPassword: UInt32 = 1
const ClientFoundRows: UInt32 = 2 << 0
const ClientLongFlag: UInt32 = 2 << 1
const ClientConnectWithDB: UInt32 = 2 << 2
const ClientNoSchema: UInt32 = 2 << 3
const ClientCompress: UInt32 = 2 << 4
const ClientODBC: UInt32 = 2 << 5
const ClientLocalFiles: UInt32 = 2 << 6
const ClientIgnoreSpace: UInt32 = 2 << 7
const ClientProtocol41: UInt32 = 2 << 8
const ClientInteractive: UInt32 = 2 << 9
const ClientSSL: UInt32 = 2 << 10
const ClientIgnoreSIGPIPE: UInt32 = 2 << 11
const ClientTransactions: UInt32 = 2 << 12
const ClientReserved: UInt32 = 2 << 13
const ClientSecureConn: UInt32 = 2 << 14
const ClientMultiStatements: UInt32 = 2 << 15
const ClientMultiResults: UInt32 = 2 << 16
const ClientPSMultiResults: UInt32 = 2 << 17
const ClientPluginAuth: UInt32 = 2 << 18
const ClientConnectAttrs: UInt32 = 2 << 19
const ClientPluginAuthLenEncClientData: UInt32 = 2 << 20
const ClientCanHandleExpiredPasswords: UInt32 = 2 << 21
const ClientSessionTrack: UInt32 = 2 << 22
const ClientDeprecateEOF: UInt32 = 2 << 23

// https://developer.aliyun.com/article/241817
const StatusInTrans: UInt32 = 1
const StatusInAutocommit: UInt32 = 2 << 0
const StatusReserved: UInt32 = 2 << 1
const StatusMoreResultsExists: UInt32 = 2 << 2
const StatusNoGoodIndexUsed: UInt32 = 2 << 3
const StatusNoIndexUsed: UInt32 = 2 << 4
const StatusCursorExists: UInt32 = 2 << 5
const StatusLastRowSent: UInt32 = 2 << 6
const StatusDbDropped: UInt32 = 2 << 7
const StatusNoBackslashEscapes: UInt32 = 2 << 8
const StatusMetadataChanged: UInt32 = 2 << 9
const StatusQueryWasSlow: UInt32 = 2 << 10
const StatusPsOutParams: UInt32 = 2 << 11
const StatusInTransReadonly: UInt32 = 2 << 12
const StatusSessionStateChanged: UInt32 = 2 << 13
const ComQuit: UInt8 = 1
const ComInitDB: UInt8 = 2
const ComQuery: UInt8 = 3
const ComFieldList: UInt8 = 4
const ComCreateDB: UInt8 = 5
const ComDropDB: UInt8 = 6
const ComRefresh: UInt8 = 7
const ComShutdown: UInt8 = 8
const ComStatistics: UInt8 = 9
const ComProcessInfo: UInt8 = 10
const ComConnect: UInt8 = 11
const ComProcessKill: UInt8 = 12
const ComDebug: UInt8 = 13
const ComPing: UInt8 = 14
const ComTime: UInt8 = 15
const ComDelayedInsert: UInt8 = 16
const ComChangeUser: UInt8 = 17
const ComBinlogDump: UInt8 = 18
const ComTableDump: UInt8 = 19
const ComConnectOut: UInt8 = 20
const ComRegisterSlave: UInt8 = 21
const ComStmtPrepare: UInt8 = 22
const ComStmtExecute: UInt8 = 23
const ComStmtSendLongData: UInt8 = 24
const ComStmtClose: UInt8 = 25
const ComStmtReset: UInt8 = 26
const ComSetOption: UInt8 = 27
const ComStmtFetch: UInt8 = 28

// https://dev.mysql.com/doc/dev/mysql-server/latest/namespacedd.html#a434db23351409cb0730fdbdfc144e8f8

const FieldTypeDecimal: UInt8 = 0
const FieldTypeTiny: UInt8 = 1
const FieldTypeShort: UInt8 = 2
const FieldTypeLong: UInt8 = 3
const FieldTypeFloat: UInt8 = 4
const FieldTypeDouble: UInt8 = 5
const FieldTypeNULL: UInt8 = 6
const FieldTypeTimestamp: UInt8 = 7
const FieldTypeLongLong: UInt8 = 8
const FieldTypeInt24: UInt8 = 9
const FieldTypeDate: UInt8 = 10
const FieldTypeTime: UInt8 = 11
const FieldTypeDateTime: UInt8 = 12
const FieldTypeYear: UInt8 = 13
const FieldTypeNewDate: UInt8 = 14
const FieldTypeVarChar: UInt8 = 15
const FieldTypeBit: UInt8 = 16
const FieldTypeJSON: UInt8 = 245
const FieldTypeNewDecimal: UInt8 = 246
const FieldTypeEnum: UInt8 = 247
const FieldTypeSet: UInt8 = 248
const FieldTypeTinyBLOB: UInt8 = 249
const FieldTypeMediumBLOB: UInt8 = 250
const FieldTypeLongBLOB: UInt8 = 251
const FieldTypeBLOB: UInt8 = 252
const FieldTypeVarString: UInt8 = 253
const FieldTypeString: UInt8 = 254
const FieldTypeGeometry: UInt8 = 255

// http://dev.mysql.com/doc/internals/en/client-server-protocol.html
const iOK: UInt8 = 0
const iAuthMoreData: UInt8 = 1
const iLocalInFile: UInt8 = 251
const iEOF: UInt8 = 254
const iERR: UInt8 = 255
const connAttrClientName = "_client_name"
const connAttrClientNameValue = "Go-MySQL-Driver"
const connAttrOS = "_os"
const connAttrOSValue = "darwin"
const connAttrPlatform = "_platform"
const connAttrPlatformValue = "arm64"
const connAttrPid = "_pid"
const connAttrServerHost = "_server_host"
