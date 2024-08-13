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

    	var resLen = this.stmt.conn.readResultSetHeaderPacket()
    	debug("columns = ", this.columns)
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

                var column = columns[i]

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
        let data = this.stmt.conn.readPacket()
        if(data[0] != iOK) {
        	if (data[0] == iEOF && data.size == 5) {
        		throw EOF()
        	}
        	this.stmt.conn.handleErrorPacket(data)
        }

        // NULL-bitmap,  [(column-count + 7 + 2) / 8 bytes]
        var pos = 1 + ((this.columns.size+7+2)>>3)

        for (i in 0..values.size) {
            var sqlDbType = values[i]
        	let column = this.columns[i]
        	match (column.fieldType) {
        	    // fieldTypeNULL 数据库返回的值是 NULL
        		case 6=> sqlDbType = SqlNullableInteger(None)
                case _=> (sqlDbType, pos) = readData(sqlDbType, data, pos)
        	}
        }

        return true
    }

    func readData(value: SqlDbType, data: Array<UInt8>, pos: Int): (SqlDbType, Int) {
    	return match (value) {
                // String----SqlChar----CHAR----CHAR----MYSQL_TYPE_STRING----char[]

                // SQL类型不同，但是数据值相对应
                // Int32----SqlInteger----INTEGER----INT----MYSQL_TYPE_LONG----int
                case _: SqlInteger => let v = SqlInteger(Int32(UInt16.readLittleEndian(data[pos..pos+4])))
                    (v, pos + 4)

                case _: SqlNullableInteger =>
                    // TODO 这里会截断, 长度需要 Int64
                    let v = SqlNullableInteger(Int32(UInt32.readLittleEndian(data[pos..pos+4])))
                    (v, pos + 4)


                case _ => throw SqlException("Unsupported data type.")
        }
    }

    // todo 和 语言级别类型直接映射
    public func row() {
    	let data = this.stmt.conn.readPacket()

        if(data[0] != iOK) {
        	if (data[0] == iEOF && data.size == 5) {
        		throw EOF()
        	}
        	this.stmt.conn.handleErrorPacket(data)
        }
        // NULL-bitmap,  [(column-count + 7 + 2) / 8 bytes]
        var pos = 1 + ((this.columns.size+7+2)>>3)

        var row = HashMap<String, Any>()

        for (i in 0..this.columns.size) {
        	let column = this.columns[i]
        	match (column.fieldType) {
        	    // fieldTypeNULL 数据库返回的值是 NULL
        		case 6=> row[column.name] = null
        		// fieldTypeTiny 数字类型
        		case 1=> if ((column.flags & flagUnsigned) != 0) {
                    row[column.name] = Int64(data[pos])
        		} else {
        		    row[column.name] = Int64(Int8(data[pos]))
        		}
        		pos++
        		// fieldTypeShort, fieldTypeYear:
        		case 2 | 13 => if ((column.flags & flagUnsigned) != 0) {
                    row[column.name] = Int64(UInt16.readLittleEndian(data[pos..pos+2]))
        		} else {
        		    row[column.name] = Int64(Int16(UInt16.readLittleEndian(data[pos..pos+2])))
        		}
        		pos += 2
        		// fieldTypeInt24, fieldTypeLong
        		case 3 | 9=> if ((column.flags & flagUnsigned) != 0) {
                    row[column.name] = Int64(UInt32.readLittleEndian(data[pos..pos+4]))
        		} else {
        		    row[column.name] = Int64(Int32(UInt16.readLittleEndian(data[pos..pos+4])))
        		}
        		pos += 4
        		debug("row.value = ", row[column.name])
        		// fieldTypeLongLong
        		case 8 => row[column.name] = Int64(UInt16.readLittleEndian(data[pos..pos+8]))
        		pos += 8


        		case _=> throw Exception("TODO 未支持的数据库类型")
        	}
        }
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