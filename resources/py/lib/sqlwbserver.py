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

class SQLWorkbench(object):
    profile = None
    port = 5000
    log = None
    log_f = None
    log_sem = thread.allocate_lock()
    results = {}
    debug = 0
    colwidth = 120
    threads_started = 0
    sqlwb_default_options = "-feedback=true -showProgress=false -abortOnError=false -showTiming=true -noSettings=true"
    vim = 'vim'
    tmp = "/tmp"
    quit       = False
    current_conn = None
    lock       = thread.allocate_lock()
    executing = thread.allocate_lock()
    new_loop = thread.allocate_lock()
    prompt_pattern_begin = '^[a-zA-Z_0-9\\.]+(\\@[a-zA-Z_0-9/\-]+)*\\>[ \s\t]*'
    prompt_pattern = prompt_pattern_begin + '$'
    resultset_end_pattern = '^.*Execution time: [0-9\\. mh]+s[\s\t \n]*$'
    wait_input_pattern = '^([a-zA-Z_][a-zA-Z0-9_]*( \\[[^\\]]+\\])?: |([^>]+> )?Username|([^>]+> )?Password: |([^>]+>[ ]+)?Do you want to run the command UPDATE\\? \\(Yes/No/All\\)[ ]+)$'
    in_resultset = 0
    wait_input = 0
    begin_resultset = '^\\-\\-[\\-\\+\\s\\t ]+$'
    buff = ''
    dbe_connections = {}
    statements_lock = thread.allocate_lock()
    statements = 1
    identifier = None

    def set_statements(self, n):
        with self.statements_lock:
            self.statements += n
        #end with
    #end def set_statements

    def get_statements(self):
        with self.statements_lock:
            result = self.statements
        #end with
        return result
    #end def get_statements

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

    def get_default_options(self):
        return 'wbsetconfig workbench.console.use.jline=false;\n'
    #end def get_default_options

    def set_default_options(self, pipe):
        pipe.stdin.write(self.get_default_options())
    #end def set_default_options

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

    def toVim(self, cmd, param = "--remote-expr"):
        if self.quit:
            return
        #end if
        if self.identifier == None:
            return 
        #end if
        p = self.getCaller()
        if p != None:
            vim_server = p.group(1)
            _cmd = '%s --servername %s -u NONE -U none %s "%s"' % (self.vim, vim_server, param, cmd)
            if self.debug:
                print "SENDING TO VIM: " + _cmd
            #end if
            os.system(_cmd)
        #end if
    #end def toVim

    def prepareResult(self, text):
        lines = text.replace("\r", "").split("\n")
        result = ''
        record = 1
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
                        if re.search(self.begin_resultset, lines[i + 1]) != None:
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
        cmd = "%s %s -profile=%s" % (self.cmd, self.sqlwb_default_options, _p)
        pipe = subprocess.Popen(shlex.split(cmd), stdin = subprocess.PIPE, stdout = subprocess.PIPE, bufsize = 1)
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

    def dbExplorer(self, conn, n, statements):
        profile = ''
        char = ''
        while char != '\n':
            char = conn.recv(1)
            if (char != '\n' and char != '\r'):
                profile += char
            #end if
        #end while
        self.do_log(profile, "dbExplorer")
        self.current_conn = conn

        if not (profile in self.dbe_connections):
            thread.start_new_thread(self.spawnDbeConnection, (profile, conn))
            while (not profile in self.dbe_connections):
                time.sleep(0.1)
            #end while
            line = ''
            while re.match('^Connection to "[^"]+" successful$', line) == None:
                line = self.readline(self.dbe_connections[profile]).replace("\n", "").replace("\r", "")
            #end while
            sql = self.get_default_options() + 'set maxrows = 100;\n'
            self.dbe_connections[profile].stdin.write(sql)
            txt = self.receiverDbe(self.dbe_connections[profile], 2)
        #end if
        if n - len(profile) - 4 > 0:
            pipe = self.dbe_connections[profile]
            data = conn.recv(4096)
            self.do_log(data, "dbExplorer")
            if (data):
                if self.debug:
                    print "SEND TO SERVER: " + data
                #end if
                pipe.stdin.write(data)
                self.do_log("SEND TO SERVER: " + data, "dbExplorer#stdin.write")
                result = self.receiverDbe(pipe, statements)
                conn.send(self.prepareResult(result))
                self.do_log(self.prepareResult(result), "dbExplorer#send")
            #end if
        #end if
        conn.send('DISCONNECT')
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

    def gotFeedback(self, conn, pipe, n):
        val = self.readData(conn, n)
        if self.debug:
            print "SENT TO SERVER: " + val
        #end if
        self.do_log("SENT TO SERVER: " + val, "gotFeedback")

        pipe.stdin.write(val + "\n")
    #end def gotFeedback

    def receiveData(self, conn, pipe, n):
        self.identifier = None
        buff = self.readData(conn, n)
        lines = buff.split("\n")
        i = 0
        lines = [line for line in lines if line != '']
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

                if (self.identifier == None):
                    self.current_conn = conn
                #end if

                pipe.stdin.write(line + "\n")
            #end if
            i = i + 1
        #end for
        with self.new_loop:
            if self.identifier == None:
                while self.get_statements() > 0:
                    time.sleep(0.1)
                #end while
                data = self.prepareResult(self.buff)
                conn.send(data)
                self.do_log(data, "receiveData#send")
                self.current_conn = None
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
            statements = int(parts[1])
        else:
            n = 0
        #end if
        data = conn.recv(3)
        self.do_log(data, "newConnection")
        if data == 'COM':
            self.set_statements(statements)
            self.receiveData(conn, pipe, n - 3)
        elif data == 'RES':
            self.searchResult(conn, n - 3)
        elif data == 'DBE':
            self.dbExplorer(conn, n - 3, statements)
        elif data == 'VAL':
            self.gotFeedback(conn, pipe, n - 3)
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

    def receiverDbe(self, pipe, statements):
        line = ''
        buff = ''
        while statements > 0:
            line = self.readline(pipe)
            self.do_log(line, "receiverDbe#stdout.readline")
            buff += line
            if self.debug:
                sys.stdout.write(line)
                self.do_log(line, "receiverDbe#stdout.write")
                sys.stdout.flush()
            #end if
            if re.search(self.resultset_end_pattern, line) != None:
                statements -= 1
            #end if
        #end while
        return buff
    #end def receiverDbe

    def readline(self, pipe):
        line = ''
        ch = ''
        while ch != '\n':
            ch = pipe.stdout.read(1)
            if ch:
                line = line + ch
            else:
                break
            #end if

            if self.in_resultset == 0:
                if re.match(self.wait_input_pattern, line) != None:
                    if self.debug:
                        print "WAITING FOR INPUT"
                    #end if
                    if (self.identifier == None and self.current_conn != None):
                        self.current_conn.send("FEEDBACK" + line)
                        response = ''
                        r_ch = ''
                        while r_ch != '\n':
                            try:
                                r_ch = self.current_conn.recv(1)
                                response += r_ch
                            except:
                                r_ch = ''
                                time.sleep(0.1)
                            #end try
                        #end while
                        pipe.stdin.write(response)
                    #end if
                    self.wait_input = 1
                    self.toVim('<C-\\><C-N>:call sw#interactive#get(\'%s\')<CR>' % line.replace("'", "''"), '--remote-send')
                    line = ''
                #end if
            #end if
        #end while
        if re.match(self.wait_input_pattern, line) == None:
            if self.debug and self.wait_input == 1:
                print "INPUT RECEIVED"
            #end if
            self.wait_input = 0
        #end if
        return line
    #end def readline

    def receiver(self, pipe):
        first_prompt = False
        record_set = False
        self.startThread()
        while True:
            with self.new_loop:
                line = ''
                self.buff = ''
                self.wait_input = 0
                self.in_resultset = 0
            #end with
            with self.executing:
                while True:
                    line = self.readline(pipe)
                    if re.match(self.begin_resultset, line):
                        self.in_resultset = 1
                    #end if
                    if line == '':
                        self.in_resultset = 0
                    #end if
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
                        if self.wait_input == 0:
                            self.buff += line
                        #end if
                        if self.debug:
                            sys.stdout.write(line)
                            sys.stdout.flush()
                        #end if
                    else:
                        break
                    #end if
                    if re.match(self.resultset_end_pattern, line.replace("\n", "")) != None:
                        self.set_statements(-1)
                        if self.get_statements() == 0:
                            break
                        #end if
                    #end if
                #end while
                if self.identifier != None:
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
        cmd = "%s -feedback=true -showProgress=false -abortOnError=false -showTiming=true -noSettings=true" % (self.cmd)
        if (self.profile != None):
            cmd += " -profile=%s" % self.profile
        #end if
        if self.debug:
            print "OPENING: " + cmd
        #end if
        pipe = subprocess.Popen(shlex.split(cmd), stdin = subprocess.PIPE, stdout = subprocess.PIPE, bufsize = 1)
        self.set_default_options(pipe)

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
            if self.wait_input:
                for i in range(15):
                    pipe.stdin.write("\n")
                #end for
            #end if
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

# vim:set et ts=4 sw=4:
#EOF
