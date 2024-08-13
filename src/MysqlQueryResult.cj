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

    	var resLen = stmt.conn.readResultSetHeaderPacket()
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
        let rows= this.readRow()

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

    func readData(value: SqlDbType, rows: Array<Array<UInt8>>, i: Int64) {
    	match (value) {
                // String----SqlChar----CHAR----CHAR----MYSQL_TYPE_STRING----char[]

                // SQL类型不同，但是数据值相对应
                // Int32----SqlInteger----INTEGER----INT----MYSQL_TYPE_LONG----int
                case v: SqlInteger => v.value = getInterger32(rows[i]).getOrThrow()
                case v: SqlNullableInteger => v.value = getInterger32(rows[i]).getOrThrow()


                case v: SqlBigInt => v.value = getInterger64(rows[i]).getOrThrow()
                case v: SqlNullableBigInt => v.value = getInterger64(rows[i]).getOrThrow()


                case v: SqlVarchar => v.value = getString(rows[i]).getOrThrow()
                case v: SqlNullableVarchar => v.value = getString(rows[i])


                case _ => throw SqlException("等待支持的类型 type = ${value.name}")
        }
    }

    // todo 和 语言级别类型直接映射
    public func readRow(): Array<Array<UInt8>>{
    	let data = this.stmt.conn.readPacket()

        if(data[0] != iOK) {
        	if (data[0] == iEOF && data.size == 5) {
        		throw EOF()
        	}
        	this.stmt.conn.handleErrorPacket(data)
        }
        // NULL-bitmap,  [(column-count + 7 + 2) / 8 bytes]
        var pos = 1 + ((this.columns.size+7+2)>>3)

        var row = Array<Array<UInt8>>(this.columns.size, item: Array<UInt8>())

        for (i in 0..this.columns.size) {
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
        		case 8 | 5 => row[i] = data[pos..pos+8]
        		    pos += 8

        		case _=>
        		var checkData = data[pos..]
                    var (tmp, _, n) = readLengthEncodedString(checkData)
                    pos += n
                    row[i] = tmp
        	}
        }
        return row
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