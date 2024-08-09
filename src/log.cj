package mysql

import std.time.DateTime
import std.console.Console

var log: Logger = Log()

public interface Logger {
    func trace(args: Array<Any>): Unit
    func debug(args: Array<Any>): Unit
    func info(args: Array<Any>): Unit
    func error(args: Array<Any>): Unit
}

public func SetLogger(logger: Logger) {
    log = logger
}

open class Log <: Logger {
    public func trace(args: Array<Any>): Unit{
        if (args.size > 0) {
            let datetime = DateTime.now()
            Console.stdOut.write("[${datetime} trace] ")
            dump(args)
            Console.stdOut.writeln(" ")
        }
    }

    public func debug(args: Array<Any>): Unit{
        if (args.size > 0) {
            let datetime = DateTime.now()
            Console.stdOut.write("[${datetime} debug] ")
            dump(args)
            Console.stdOut.writeln(" ")
        }
    }

    public func info(args: Array<Any>): Unit{
        if (args.size > 0) {
            let datetime = DateTime.now()
            Console.stdOut.write("[${datetime} info] ")
            dump(args)
            Console.stdOut.writeln(" ")
        }
    }

    public func error(args: Array<Any>): Unit{
        if (args.size > 0) {
            let datetime = DateTime.now()
            Console.stdOut.write("[${datetime} error] ")
            dump(args)
            Console.stdOut.writeln(" ")
        }
    }
}

public func trace(args: Array<Any>) {
    log.trace(args)
}

public func debug(args: Array<Any>) {
    log.debug(args)
}

public func info(args: Array<Any>) {
    log.info(args)
}

public func error(args: Array<Any>) {
    log.error(args)
}