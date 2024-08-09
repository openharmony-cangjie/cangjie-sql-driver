package mysql

import std.collection.*

class MysqlResult {
    var affectedRows = ArrayList<Int64>()
	var insertIds = ArrayList<Int64>()
}