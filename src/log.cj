package mysql

import std.time.DateTime
import std.console.Console

var log: Logger = Log()

public enum LogLevel {
    | trace | debug | info | wran | error
}

public var level: LogLevel = LogLevel.wran

public interface Logger {
    func trace(args: Array<Any>): Unit
    func debug(args: Array<Any>): Unit
    func info(args: Array<Any>): Unit
    func wran(args: Array<Any>): Unit
    func error(args: Array<Any>): Unit
}

public func SetLogger(logger: Logger) {
    log = logger
}

open class Log <: Logger {
    public func trace(args: Array<Any>): Unit {
        match (level) {
            case LogLevel.trace => if (args.size > 0) {
                let datetime = DateTime.now()
                Console.stdOut.write("[${datetime} trace] ")
                dump(args)
                Console.stdOut.writeln(" ")
            }
            case _ => return
        }
    }

    public func debug(args: Array<Any>): Unit {
        match (level) {
            case LogLevel.trace | LogLevel.debug => if (args.size > 0) {
                let datetime = DateTime.now()
                Console.stdOut.write("[${datetime} debug] ")
                dump(args)
                Console.stdOut.writeln(" ")
            }
            case _ => return
        }
    }

    public func info(args: Array<Any>): Unit {
        match (level) {
            case LogLevel.trace | LogLevel.debug | LogLevel.info => if (args.size > 0) {
                let datetime = DateTime.now()
                Console.stdOut.write("[${datetime} info] ")
                dump(args)
                Console.stdOut.writeln(" ")
            }
            case _ => return
        }
    }

    public func wran(args: Array<Any>): Unit {
        match (level) {
            case LogLevel.trace | LogLevel.debug | LogLevel.info | LogLevel.wran => if (args.size > 0) {
                let datetime = DateTime.now()
                Console.stdOut.write("[${datetime} wran] ")
                dump(args)
                Console.stdOut.writeln(" ")
            }
            case _ => return
        }
    }

    public func error(args: Array<Any>): Unit {
        match (level) {
            case LogLevel.trace | LogLevel.debug | LogLevel.info | LogLevel.wran | LogLevel.error => if (args.size > 0) {
                let datetime = DateTime.now()
                Console.stdOut.write("[${datetime} error] ")
                dump(args)
                Console.stdOut.writeln(" ")
            }
            case _ => return
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
