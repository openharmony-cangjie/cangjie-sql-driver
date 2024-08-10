package mysql

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
func sha256Test() {
    let check = [169, 83, 17, 131, 5, 166, 192, 207, 216, 13, 167, 73, 28, 74, 78, 109, 247, 113, 228, 165, 48, 116,
        177, 4, 101, 155, 66, 12, 66, 116, 170, 184]

    let a = sha256("123456".toArray(), "root")

    var i = 0
    for (b in check) {
        @Assert(UInt8(b) == a[i])
        i++
    }
}
