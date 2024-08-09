package mysql

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
func copyTest() {
        var clientFlags = ClientProtocol41 | ClientSecureConn | ClientLongPassword | ClientTransactions |
            ClientLocalFiles | ClientPluginAuth | ClientMultiResults | ClientConnectAttrs | 65535 & ClientLongFlag

    //512
    //32768
    //33280
    //1745541
    dump(ClientProtocol41)
    dump(ClientSecureConn)
    dump(ClientProtocol41 | ClientSecureConn)

    dump(clientFlags)
}