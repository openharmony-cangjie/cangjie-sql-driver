package mysql

import std.database.sql.QueryResult
import std.database.sql.SqlDbType
import std.database.sql.ColumnInfo
import std.collection.HashMap
import std.binary.*
import std.database.sql.*

// 查询返回结构
public class MysqlQueryResult <: QueryResult {
    let stmt: MysqlStatement
    let params: Array<SqlDbType>

    var columns: Array<MysqlColumnInfo> = Array<MysqlColumnInfo>()

    public init(stmt: MysqlStatement, params: Array<SqlDbType>) {
    	this.stmt = stmt
    	this.params = params

    	// 发送参数包
        stmt.conn.writeExecutePacket(stmt, this.params)

    	var (resLen, _, _) = stmt.conn.readResultSetHeaderPacket()
        if (resLen>0) {
             this.columns = this.readColumns(Int64(resLen))
        }
    }

    public func readColumns(count:Int64): Array<MysqlColumnInfo> {
        var i:Int64 = 0
        var columns = Array<MysqlColumnInfo>(Int64(count), item: MysqlColumnInfo())

        while (true){
            let data = this.stmt.conn.readPacket()
            // 检查是否是结束包
            if (data[0] == 254 && (data.size == 1 || data.size == 5)) {
                if (i == count) {
                	return columns
                }
            }
            var pos = skipLengthEncodedString(data)

                // Database [len coded string]
                var n = skipLengthEncodedString(data[pos..])
                pos += n

                var column = MysqlColumnInfo()

                // Table [len coded string]
                if (this.stmt.conn.config.ColumnsWithAlias) {
                    var (tableName, _, n) = readLengthEncodedString(data[pos..])
                    pos += n
                    column.tableName = String.fromUtf8(tableName)
                } else {
                    var n = skipLengthEncodedString(data[pos..])
                    pos += n
                }
                // Original table [len coded string]
                n = skipLengthEncodedString(data[pos..])
                pos += n

                // Name [len coded string]
                var name:Array<UInt8>
                (name, _, n) = readLengthEncodedString(data[pos..])
                column.nameString = String.fromUtf8(name)

                pos += n

                // Original name [len coded string]
                n = skipLengthEncodedString(data[pos..])
                pos += n

                // Filler [uint8]
                pos++

                // Charset [charset, collation uint8]
                column.charSet = data[pos]
                pos += 2

                // Length [uint32]
                column.lengthUInt32 = UInt32.readLittleEndian(data[pos..pos+4])
                pos += 4

                // Field type [uint8]
                column.fieldType = data[pos]
                pos++

                // Flags [uint16]
                column.flags = UInt16.readLittleEndian(data[pos..pos+2])
                pos += 2

                // Decimals [uint8]
                column.decimals = data[pos]

                columns[i] = column
            i++
        }

        return columns
    }

    /*
     * 返回结果集的列信息，比如列名，列类型，列长度，是否允许数据库Null值等（不支持）
     */
    public override prop columnInfos: Array<ColumnInfo> {
        get() {
            Array<ColumnInfo>()
        }
    }

    // 根据传入类型填充
    public func next(values: Array<SqlDbType>): Bool {
        let (rows, has) = this.readRow()
        if (!has) {
        	return false
        }

        for (i in 0..values.size) {
            var row = rows[i]
            var sqlDbType = values[i]
        	let column = this.columns[i]
        	match (column.fieldType) {
        	    // fieldTypeNULL 数据库返回的值是 NULL
        		case 6=> values[i] = SqlNullableInteger(None)
                case _=> this.readData(sqlDbType, rows, i)
        	}
        }

        return true
    }

    // 读取 mysql 数据, 同时填充到 value
    func readData(value: SqlDbType, rows: Array<Array<UInt8>>, i: Int64) {
    	match (value) {
            // String----SqlChar----CHAR----CHAR----MYSQL_TYPE_STRING----char[]
            case v: SqlChar => v.value = getString(rows[i]).getOrThrow()
            case v: SqlNullableChar => v.value = getString(rows[i])

            // String----SqlVarchar----VARCHAR----VARCHAR----MYSQL_TYPE_VAR_STRING----char[]
            case v: SqlVarchar => v.value = getString(rows[i]).getOrThrow()
            case v: SqlNullableVarchar => v.value = getString(rows[i])

            // Array<Byte>----SqlBinary----BINARY----BINARY----MYSQL_TYPE_STRING----char[]
            case v: SqlBinary => v.value = rows[i]
            case v: SqlNullableBinary => v.value = rows[i]

            // Array<Byte>----SqlVarBinary----VARBINARY----VARBINARY----MYSQL_TYPE_VAR_STRING----char[]
            case v: SqlVarBinary => v.value = rows[i]
            case v: SqlNullableVarBinary => v.value = rows[i]

            // 长字符串，mysql输入对应表格没有给出，在输出表格有对应数据
            // Array<InputStream>----SqlClob----CLOB----LONGTEXT----MYSQL_TYPE_LONG_BLOB----char[]
            case v: SqlClob => v.value = getClob(rows[i]).getOrThrow()
            case v: SqlNullableClob => v.value = getClob(rows[i])

            // Array<InputStream>----SqlBlob----BLOB----BLOB----MYSQL_TYPE_BLOB----char[]
            case v: SqlBlob => v.value = getClob(rows[i]).getOrThrow()
            case v: SqlNullableBlob => v.value = getClob(rows[i])

            // 布尔类型在mysql数据库中表现形式是TINYINT
            // Bool----SqlBool----BOOLEAN----TINYINT----MYSQL_TYPE_TINY----signed char
            case v: SqlBool => v.value = getBool(rows[i]).getOrThrow()
            case v: SqlNullableBool => v.value = getBool(rows[i])

            // Int8----SqlByte----TINYINT----TINYINT----MYSQL_TYPE_TINY----signed char
            case v: SqlByte => v.value = getInterger8(rows[i]).getOrThrow()
            case v: SqlNullableByte => v.value = getInterger8(rows[i])

            // Int16----SqlSmallInt----SMALLINT----SMALLINT----MYSQL_TYPE_SHORT----short int
            case v: SqlSmallInt => v.value = getInterger16(rows[i]).getOrThrow()
            case v: SqlNullableSmallInt => v.value = getInterger16(rows[i])

            // SQL类型不同，但是数据值相对应
            // Int32----SqlInteger----INTEGER----INT----MYSQL_TYPE_LONG----int
            case v: SqlInteger => v.value = getInterger32(rows[i]).getOrThrow()
            case v: SqlNullableInteger => v.value = getInterger32(rows[i])

            // Int64----SqlBigInt----BIGINT----BIGINT----MYSQL_TYPE_LONGLONG----long long int
            case v: SqlBigInt => v.value = getInterger64(rows[i]).getOrThrow()
            case v: SqlNullableBigInt => v.value = getInterger64(rows[i])

            // SQL类型不同，但是数据值相对应
            // Float32----SqlReal----REAL----FLOAT----MYSQL_TYPE_FLOAT----float
            case v: SqlReal => v.value = getFloat32(rows[i]).getOrThrow()
            case v: SqlNullableReal => v.value = getFloat32(rows[i])

            // Float64----SqlDouble----DOUBLE----DOUBLE----MYSQL_TYPE_DOUBLE----double
            case v: SqlDouble => v.value = getFloat64(rows[i]).getOrThrow()
            case v: SqlNullableDouble => v.value = getFloat64(rows[i])

            //  DateTime----SqlDate----DATE----DATE----MYSQL_TYPE_DATE----MYSQL_TIME
            case v: SqlDate => v.value = getTime(rows[i], this.columns[i]).getOrThrow()
            case v: SqlNullableDate => v.value = getTime(rows[i], this.columns[i])

            // DateTime----SqlTime----TIME----TIME----MYSQL_TYPE_TIME----MYSQL_TIME
            case v: SqlTime => v.value = getTime(rows[i], this.columns[i]).getOrThrow()
            case v: SqlNullableTime => v.value = getTime(rows[i], this.columns[i])

            // DateTime----SqlTimestamp----TIMESTAMP----TIMESTAMP----MYSQL_TYPE_TIMESTAMP----MYSQL_TIME
            case v: SqlTimestamp => v.value = getTime(rows[i], this.columns[i]).getOrThrow()
            case v: SqlNullableTimestamp => v.value = getTime(rows[i], this.columns[i])

            case _ => throw SqlException("等待支持的类型 type = ${value.name}")
        }
    }

    // todo 和 语言级别类型直接映射
    public func readRow(): (Array<Array<UInt8>>, Bool){
    	let data = this.stmt.conn.readPacket()

        if(data[0] != iOK) {
        	if (data[0] == iEOF && data.size == 5) {
        		return (Array<Array<UInt8>>(), false)
        	}
        	this.stmt.conn.handleErrorPacket(data)
        }
        // NULL-bitmap,  [(column-count + 7 + 2) / 8 bytes]
        var pos: Int64 = 1 + ((this.columns.size+7+2)>>3)
        let nullMask = data[1..pos]

        var row = Array<Array<UInt8>>(this.columns.size, item: Array<UInt8>())

        for (i in 0..this.columns.size) {
            // Field is NULL
            // (byte >> bit-pos) % 2 == 1
            if (((nullMask[(i+2)>>3] >> UInt64((i+2)&7)) & 1) == 1) {
                row[i] = Array<UInt8>()
                continue
            }

        	let column = this.columns[i]
        	match (column.fieldType) {
        	    // fieldTypeNULL 数据库返回的值是 NULL
        		case 6=> row[i] = Array<UInt8>()
        		// fieldTypeTiny 数字类型
        		case 1=> row[i] = Array<UInt8>([data[pos]])
        		    pos++
        		// fieldTypeShort, fieldTypeYear:
        		case 2 | 13 => row[i] = data[pos..pos+2]
        		    pos += 2
        		// fieldTypeInt24, fieldTypeLong, fieldTypeFloat
        		case 9 | 3 | 4=> row[i] = data[pos..pos+4]
        		    pos += 4
        		// fieldTypeLongLong, fieldTypeDouble
        		case 8 | 5 =>
        		    row[i] = data[pos..pos+8]
        		    pos += 8
        		// 二进制数据类型 | 字符串
        		case 0 | 246 | 15 | 16 | 247 | 248 | 249 | 250 | 251 | 252 | 253 | 254 | 255 | 245=>
        		    var checkData = data[pos..]
                    var (tmp, _, n) = readLengthEncodedString(checkData)
                    pos += n
                    row[i] = tmp
                // 时间格式
        		case 7 | 10 | 12 | 11 | 14  =>
        		    var checkData = data[pos..]
                    var (num, _, n) = readLengthEncodedInteger(checkData)
                    pos += n
                    row[i] = data[pos..pos+Int64(num)]
                    pos += Int64(num)
        		case _=>
        		    throw SqlException("未定义的数据库类型 column.fieldType = ${column.fieldType}")
        	}
        }
        return (row, true)
    }

     /*
     * 关闭资源
     *
     * 异常 SqlException - 关闭资源失败。
     */
    public override func close(): Unit {
        if (this.isClosed()) {
            return
        }
    }

    /*
     * 判断资源是否关闭
     * 返回值 Bool - 如果已经关闭返回true，否则返回false
     */
    public override func isClosed(): Bool {
        return false
    }
}