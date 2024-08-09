package mysql

import std.collection.ArrayList
import std.console.Console

public func dump(args: Array<Any>) {
    if (args.size > 0) {
        for (v in args) {
            echoAny(v)
            Console.stdOut.write(" ")
        }
    }
}

func echoAny(v: Any) {
    match (v) {
        case s: Int => Console.stdOut.write(s)
        case s: Int8 => Console.stdOut.write(s)
        case s: UInt8 => Console.stdOut.write(s)
        case s: Int16 => Console.stdOut.write(s)
        case s: UInt16 => Console.stdOut.write(s)
        case s: Int32 => Console.stdOut.write(s)
        case s: UInt32 => Console.stdOut.write(s)
        case s: UInt64 => Console.stdOut.write(s)
        case s: Float16 => Console.stdOut.write(s)
        case s: Float32 => Console.stdOut.write(s)
        case s: Float64 => Console.stdOut.write(s)
        case s: String => Console.stdOut.write(s)
        case s: Bool => Console.stdOut.write(s)
        case s: Array<UInt8> =>
            Console.stdOut.write("[")
            Console.stdOut.write(s[0])
            if(s.size > 1) {
                for(v in s[1..]) {
                    Console.stdOut.write(" ")
                    Console.stdOut.write(v)
                }
            }
            Console.stdOut.write("]")
        case s: ArrayList<UInt8> =>
            Console.stdOut.write("[")
            Console.stdOut.write(s[0])
            if(s.size > 1) {
                for(v in s[1..]) {
                    Console.stdOut.write(" ")
                    Console.stdOut.write(v)
                }
            }
            Console.stdOut.write("]")
        case s: ToString => Console.stdOut.write(s)

        case _ => ("TODO", v)
    }
}
