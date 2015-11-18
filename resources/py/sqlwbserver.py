#!/usr/bin/env python
#

from optparse   import OptionParser
from lib.sqlwbserver import SQLWorkbench
from lib.sqlwbserver_old import SQLWorkbenchOld
import sys

if __name__ == "__main__":
    parser = OptionParser()
    obj = SQLWorkbench()
    parser.add_option("-t", "--tmp",   help="The location of tmp folder",    dest="tmp",     default="/tmp")
    parser.add_option("-p", "--profile",   help="The sql workbench profile",    dest="profile",     default=None)
    parser.add_option("-c", "--command",   help="The command to launch the sql workbench console",    dest="cmd",     default=None)
    parser.add_option("-v", "--vim",   help="The path to the vim executable", dest="vim",     default='vim')
    parser.add_option("-o", "--port",   help="The port on which to send the commands", dest="port",     default='5000', type = "int")
    parser.add_option("-l", "--log", help = "Log file path", default = None, dest = "log")
    parser.add_option("-d", "--debug",   help="The debuging mode", dest="debug", default='0')
    parser.add_option("-O", "--old",   help="Use an SQL Workbench (before build 118)", dest="old", default='0')
    (options,args) = parser.parse_args(sys.argv[1:], obj)
    if hasattr(options, 'old'):
        if options.old == '1':
            obj = SQLWorkbenchOld()
            (options,args) = parser.parse_args(sys.argv[1:], obj)
        #end if
    #end if
    obj.args = args
    obj.main()
#end if

# vim:set et ts=4 sw=4:
#EOF
