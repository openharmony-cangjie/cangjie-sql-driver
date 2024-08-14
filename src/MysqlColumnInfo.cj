package mysql

import std.database.sql.ColumnInfo

public class MysqlColumnInfo <: ColumnInfo {
	var tableName:String = ""
	var nameString:String = ""
	var lengthUInt32:UInt32 = 0 // 字段长度，使用32位无符号整数表示
	var flags:UInt16 = 0 // 字段的标志位，使用fieldFlag类型表示
	var fieldType:UInt8 = 0 // 字段的类型，使用fieldType类型表示
	var decimals:UInt8 = 0 // 字段的小数位数，使用8位无符号整数表示
	var charSet:UInt8 = 0 // 字段的字符集，使用8位无符号整数表示

    /*
     * 列名或者别名
     */
    public override prop name: String {
        get() {
            return this.nameString
        }
    }

    /*
     * 列类型名称，如果在SqlDataType中定义
     * 返回SqlDataType.toString(),如果未在SqlDataType中定义，由数据库驱动定义
     */
    public override prop typeName: String {
        get() {
            return ""
        }
    }

    /*
     * 列值的最大显示长度，如果无限制，则应该返回Int64.Max（仍然受数据库的限制）
     */
    public override prop displaySize: Int64 {
        get() {
            return Int64(this.lengthUInt32) + Int64(this.decimals)
        }
    }

    /**
     * 获取列值大小。
     */
    public override prop length: Int64 {
        get() {
            return Int64(this.lengthUInt32)
        }
    }

    /*
     * 列值的小数长度，如果无小数部分，返回0
     */
    public override prop scale: Int64 {
        get() {
            return Int64(this.decimals)
        }
    }

    /*
     * 列值是否允许数据库Null值
     */
    public override prop nullable: Bool {
        get() {
            return this.flags % 2 != 0
        }
    }
}