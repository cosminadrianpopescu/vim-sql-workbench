from __future__ import with_statement

import commands
import datetime
import os
import uuid
import socket
import re
import string
import shlex
import sys
import thread
import time
import subprocess

class SQLWorkbenchOld(object):
    profile = None
    port = 5000
    log = None
    log_f = None
    log_sem = thread.allocate_lock()
    results = {}
    debug = 0
    colwidth = 120
    threads_started = 0
    vim = 'vim'
    tmp = "/tmp"
    clock = datetime.datetime.now()
    quit       = False
    lock       = thread.allocate_lock()
    executing = thread.allocate_lock()
    new_loop = thread.allocate_lock()
    prompt_pattern_begin = '^[a-zA-Z_0-9\\.]+(\\@[a-zA-Z_0-9/\-]+)?\\>[ \s\t]*'
    prompt_pattern = prompt_pattern_begin + '$'
    resultset_end_pattern = 'send_to_vim set to'
    buff = ''
    dbe_connections = {}
    identifier = None

    def startThread(self):
        # if self.debug:
        #     print "NEW THREAD STARTED"
        # #end if
        self.threads_started += 1
    #end def startThread

    def stopThread(self):
        # if self.debug:
        #     print "THREAD STOPPED"
        # #end if
        self.threads_started -= 1
    #end def stopThread

    def parseCustomCommand(self, command):
        if command[0] == 'identifier':
            self.identifier = command[1]
        elif command[0] == 'colwidth':
            self.colwidth = command[1]
        #end if
    #end def parseCustomCommand

    def gotCustomCommand(self, text):
        pattern = '^!#(identifier|end|colwidth)[ \\s\\t]*=[ \\s\\t]*([A-Za-z_0-9#]+)[ \\s\\t\\n\\r]*$'
        p = re.search(pattern, text)
        if p != None:
            return [p.group(1), p.group(2)]
        #end if
        return None
    #end def gotCustomCommand

    def getCaller(self, identifier = None):
        if identifier == None:
            i = self.identifier
        else:
            i = identifier
        #end if
        return re.search('^([^#]+)#?([^\\r\\n]*)[\\n\\r]?$', i)
    #end def getVimServerName

    def toVim(self, cmd):
        if self.identifier == None:
            return 
        #end if
        p = self.getCaller()
        if p != None:
            vim_server = p.group(1)
            _cmd = '%s --servername %s -u NONE -U none --remote-expr "%s"' % (self.vim, vim_server, cmd)
            if self.debug:
                print "SENDING TO VIM: " + _cmd
            #end if
            os.system(_cmd)
        #end if
    #end def toVim

    def prepareResult(self, text):
        lines = text.replace("\r", "").split("\n")
        result = ''
        record = 0
        i = 0
        to_add_results = False
        pattern1 = '-- auto[ \\s\\t\\r\\n]*$' 
        pattern2 = '-- end auto[ \\s\\t\\r\\n]*$' 
        for line in lines:
            if re.search(self.prompt_pattern_begin, line) != None and record == 0:
                record = 1
            #end if

            if re.search(pattern1, line) != None:
                record = 2
            #end if

            if record == 1 and re.search(pattern1, line) == None and re.search(pattern2, line) == None:
                if re.search('send_to_vim', line) == None:
                    if i < len(lines) - 1:
                        if re.search('^\\-\\-[\\-\\+\\s\\t ]+$', lines[i + 1]) != None:
                            to_add_results = True
                            result += "--results--"
                        #end if
                    #end if

                    p = re.search('^\\(([0-9]+) Row[s]?\\)', line)
                    if p != None:
                        to_add_results = False
                        result = result.replace('--results--', 
                                '\n==============================================================================\n' + 
                                'Query returned ' + p.group(1) + ' row' + ('s' if int(p.group(1)) > 1 else '') + '\n')
                    else:
                        line = re.sub(self.prompt_pattern_begin, '', line)
                        line = re.sub("^(\\.\\.> )+", '', line)
                        result = result + line + "\n"
                    #end if
                #end if
            #end if
            i += 1

            if re.search(pattern2, line) != None:
                record = 1
            #end if
        #end for

        if to_add_results:
            result = result.replace('--results--', 
                    '\n==============================================================================\n')
        #end if

        return result
    #end def prepareResult

    def spawnDbeConnection(self, profile, conn):
        self.startThread()
        pattern = '^([^\\\\]+)\\\\(.*)$'
        _p = profile
        if re.match(pattern, profile) != None:
            _p = re.sub(pattern, '\\2', profile) + " -profileGroup=" + re.sub(pattern, '\\1', profile)
        #end if
        cmd = "%s -feedback=true -showProgress=false -profile=%s" % (self.cmd, _p)
        pipe = subprocess.Popen(shlex.split(cmd), stdin = subprocess.PIPE, stdout = subprocess.PIPE, bufsize = 1)
        pipe.stdin.write('set maxrows = 100;\n')
        conn.send('DISCONNECT')
        self.dbe_connections[profile] = pipe
        if self.debug:
            print "OPENING DBE CONNECTION: " + cmd
        #end if
        self.do_log("OPENING DBE CONNECTION: " + cmd, "spawnDbeConnection")
        while 1:
            with self.lock:
                if self.quit: break
            #end with
            time.sleep(0.3)
        #end while
        self.stopThread()
    #end def spawnDbeConnection

    def dbExplorer(self, conn, n):
        profile = ''
        char = ''
        while char != '\n':
            char = conn.recv(1)
            if (char != '\n' and char != '\r'):
                profile += char
            #end if
        #end while
        self.do_log(profile, "dbExplorer")
        if not (profile in self.dbe_connections):
            thread.start_new_thread(self.spawnDbeConnection, (profile, conn))
            while (not profile in self.dbe_connections):
                time.sleep(0.1)
            #end while
        #end if
        if n - len(profile) - 4 > 0:
            pipe = self.dbe_connections[profile]
            data = conn.recv(4096)
            self.do_log(data, "dbExplorer")
            if (data):
                data += "\nwbsetconfig send_to_vim=1;\n"
                if self.debug:
                    print "SEND TO SERVER: " + data
                #end if
                pipe.stdin.write(data)
                self.do_log("SEND TO SERVER: " + data, "dbExplorer#stdin.write")
                result = self.receiverDbe(pipe)
                conn.send(self.prepareResult(result))
                self.do_log(self.prepareResult(result), "dbExplorer#send")
            #end if
        #end if
    #end def dbExplorer

    def searchResult(self, conn, n):
        data = self.readData(conn, n)
        self.do_log(data, "searchResult")
        p = self.getCaller(data)
        if p == None:
            return
        #end if

        key = p.group(1) + "#" + p.group(2)
        if key in self.results:
            conn.send(self.prepareResult(self.results[key]))
            self.do_log(self.prepareResult(self.results[key]), "searchResult#send")
            del self.results[key]
        #end if
    #end def searchResult

    def readData(self, conn, n):
        result = ''
        i = 0
        while i < n:
            data = conn.recv(4096)
            if not data:
                break
            #end if
            result += data
            i += len(data)
        #end while

        self.do_log(result, "readData")
        return result
    #end def readData

    def receiveData(self, conn, pipe, n):
        self.clock = datetime.datetime.now()
        self.identifier = None
        buff = self.readData(conn, n)
        lines = buff.split("\n")
        for line in lines:
            if re.search('^!#', line) != None:
                command = self.gotCustomCommand(line)
                if command != None:
                    self.parseCustomCommand(command)
                #end if
            else:
                if self.debug:
                    print "SENT TO SERVER: " + line
                #end if
                self.do_log("SENT TO SERVER: " + line, "receiveData")
                if line != '':
                    pipe.stdin.write(line + "\n")
                #end if
            #end if
        #end for
        with self.new_loop:
            pipe.stdin.write("wbsetconfig send_to_vim=1;\n")
            if self.debug:
                print "SENT TO SERVER: wbsetconfig send_to_vim=1;"
            #end if
            self.do_log("SENT TO SERVER: wbsetconfig send_to_vim=1;", "receiveData#stdin.write")
            if self.identifier == None:
                with self.executing:
                    data = self.prepareResult(self.buff)
                    conn.send(data)
                    self.do_log(data, "receiveData#send")
                #end with
            else:
                with self.executing:
                    p = self.getCaller()
                    if self.debug:
                        print "RESULT STORED FOR %s" % p.group(1) + "#" + p.group(2)
                    #end if
                    if p != None:
                        self.toVim('sw#got_async_result(\\"%s\\")' % p.group(2))
                    #end if
                #end with
            #end if
        #end with
    #end def receiveData

    def do_log(self, what, who):
        if self.log_f != None:
            with self.log_sem:
                self.log_f.write(who + ">>>>>>>>>>>>>>>\n")
                self.log_f.write(what)
                self.log_f.write("\n")
            #end whith
        #end if
    #end def do_log

    def newConnection(self, conn, pipe):
        n = ''
        c = ''
        while c != '#':
            c = conn.recv(1)
            if c != '#':
                n += c
            #end if
        #end while
        self.do_log(n, "newConnection")
        if (n != ''):
            parts = n.split('?')
            n = int(parts[0])
        else:
            n = 0
        #end if
        data = conn.recv(3)
        self.do_log(data, "newConnection")
        if data == 'COM':
            self.receiveData(conn, pipe, n - 3)
        elif data == 'RES':
            self.searchResult(conn, n - 3)
        elif data == 'DBE':
            self.dbExplorer(conn, n - 3)
        #end if
        conn.close()
    #end def newConnection

    def monitor(self, pipe, port):
        self.startThread()
        HOST = '127.0.0.1'   # Symbolic name meaning all available interfaces

        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.settimeout(3)
         
        try:
            s.bind((HOST, port))
        except socket.error , msg:
            print 'Bind failed. Error Code : ' + str(msg[0]) + ' Message ' + msg[1]
            sys.exit()
             
        s.listen(10)
         
        #now keep talking with the client
        while 1:
            try:
                conn, addr = s.accept()
            except Exception:
                conn = None
            #end try
            if conn != None:
                if self.debug:
                    print 'Connected with ' + addr[0] + ':' + str(addr[1])
                #end if
                thread.start_new_thread(self.newConnection, (conn, pipe))
            #end if

            with self.lock:
                if self.quit:
                    break
                #end if
            #end with
        #end while
        s.close()
        self.stopThread()
    #end def monitor

    def receiverDbe(self, pipe):
        line = ''
        buff = ''
        while re.search(self.resultset_end_pattern, line) == None:
            line = pipe.stdout.readline()
            self.do_log(line, "receiverDbe#stdout.readline")
            buff += line
            if self.debug:
                sys.stdout.write(line)
                self.do_log(line, "receiverDbe#stdout.write")
                sys.stdout.flush()
            #end if
        #end while
        return buff
    #end def receiverDbe

    def receiver(self, pipe):
        first_prompt = False
        record_set = False
        self.startThread()
        while True:
            with self.new_loop:
                line = ''
                self.buff = ''
            #end with
            with self.executing:
                while re.search(self.resultset_end_pattern, line) == None:
                    line = pipe.stdout.readline()
                    if re.match('^\x1b', line) != None:
                        continue
                    #end if
                    if line:
                        if re.search(self.prompt_pattern_begin, line) != None:
                            if not first_prompt:
                                first_prompt = True
                                self.buff = ''
                            #end if
                        #end if
                        self.buff += line
                        if self.debug:
                            sys.stdout.write(line)
                            sys.stdout.flush()
                        #end if
                    else:
                        break
                    #end if
                #end while
                if self.identifier != None:
                    self.buff += "Total time: %.2g seconds" % (datetime.datetime.now() - self.clock).total_seconds()
                    self.clock = datetime.datetime.now()

                    if self.identifier in self.results:
                        self.results[self.identifier] += "\n" + self.buff
                    else:
                        self.results[self.identifier] = self.buff
                    #end if

                    self.buff = ''
                #end if
            #end with
            with self.lock:
                if self.quit: break
            #end with
        #end while
        self.stopThread()
    #end def receiver

    def main(self):
        if self.cmd == None:
            print "You have to set the sql workbench command. Please see the help. "
            sys.exit(1)
        #end if

        if (self.log != None):
            self.log_f = open(self.log, "w")
        #end if
        cmd = "%s -feedback=true -showProgress=false" % (self.cmd)
        if (self.profile != None):
            cmd += " -profile=%s" % profile
        #end if
        if self.debug:
            print "OPENING: " + cmd
        #end if
        pipe = subprocess.Popen(shlex.split(cmd), stdin = subprocess.PIPE, stdout = subprocess.PIPE, bufsize = 1)

        thread.start_new_thread(self.receiver, (pipe,))
        thread.start_new_thread(self.monitor,  (pipe, self.port))

        try:
            while True:
                if pipe.poll() != None:
                    self.quit = True
                    break
                time.sleep(0.1)
            #end while
        except KeyboardInterrupt, ex:
            with self.lock:
                self.quit = True
        #end try...except
        try:
            pipe.stdin.write('exit\n')
            for key in self.dbe_connections:
                try:
                    self.dbe_connections[key].stdin.write('exit\n')
                except Exception:
                    if self.debug:
                        print "No pipe to send exit for " + key
                    #end if
                #end try
            #end for
        except Exception:
            if self.debug:
                print "No pipe to send exit"
            #end if
        #end try
        print "Waiting for server to stop..."
        while self.threads_started > 0:
            time.sleep(0.3)
        #end while
        sys.exit(0)
    #end def main
#end class SQLWorkbench

if __name__ == "__main__":
    obj = SQLWorkbench()
    parser = OptionParser()
    parser.add_option("-t", "--tmp",   help="The location of tmp folder",    dest="tmp",     default="/tmp")
    parser.add_option("-p", "--profile",   help="The sql workbench profile",    dest="profile",     default=None)
    parser.add_option("-c", "--command",   help="The command to launch the sql workbench console",    dest="cmd",     default=None)
    parser.add_option("-v", "--vim",   help="The path to the vim executable", dest="vim",     default='vim')
    parser.add_option("-o", "--port",   help="The port on which to send the commands", dest="port",     default='5000', type = "int")
    parser.add_option("-l", "--log", help = "Log file path", default = None, dest = "log")
    parser.add_option("-d", "--debug",   help="The debuging mode", dest="debug", default='0')
    (options,args) = parser.parse_args(sys.argv[1:], obj)
    obj.args = args
    obj.main()
#end if

# vim:set et ts=4 sw=4:
#EOF
