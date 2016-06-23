from __future__ import with_statement

import commands
import datetime
import os
import uuid
import socket
import re
import string
import shlex
from collections import deque
import sys
import thread
import uuid
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
    lock       = thread.allocate_lock()
    new_loop = thread.allocate_lock()
    prompt_pattern_begin = '^[a-zA-Z_0-9\\.]+(\\@[a-zA-Z_0-9/\-]+)*\\>[ \s\t]*'
    prompt_pattern = prompt_pattern_begin + '$'
    resultset_end_pattern = '^.*Execution time: [0-9\\. mh]+s[\s\t \n]*$'
    wait_input_pattern = '^([a-zA-Z_][a-zA-Z0-9_]*( \\[[^\\]]+\\])?: |([^>]+> )?([^>]+> )*Username|([^>]+> )*Password: |([^>]+>[ ]+)?Do you want to run the command UPDATE\\? \\(Yes/No/All\\)[ ]+)$'
    in_resultset = 0
    wait_input = 0
    begin_resultset = '^(\\-\\-[\\-\\+\\s\\t ]+|Product Version: [A-Za-z0-9 \\.]+)$'
    buff = ''
    dbe_connections = {}
    statements_lock = thread.allocate_lock()
    processing = deque([])
    statements = {}
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

    def get_default_options(self):
        return 'wbsetconfig workbench.console.use.jline=false;\n'
    #end def get_default_options

    def set_default_options(self, pipe):
        pipe.stdin.write(self.get_default_options())
    #end def set_default_options

    def getCaller(self, identifier = None):
        return re.search('^([^#]+)#?([^\\r\\n]*)[\\n\\r]?$', identifier)
    #end def getVimServerName

    def toVim(self, cmd, vim_server, param = "--remote-expr"):
        if self.quit:
            return
        #end if
        _cmd = '%s --servername %s -u NONE -U none %s "%s"' % (self.vim, vim_server, param, cmd)
        if self.debug:
            print "SENDING TO VIM: " + _cmd
        #end if
        os.system(_cmd)
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
                    while re.match(self.prompt_pattern_begin, line) != None:
                        line = re.sub(self.prompt_pattern_begin, '', line)
                    #end while
                    line = re.sub("^(\\.\\.> )+", '', line)
                    result = result + line + "\n"
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

    def spawnDbeConnection(self, profile):
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
            thread.start_new_thread(self.spawnDbeConnection, (profile, ))
            while (not profile in self.dbe_connections):
                time.sleep(0.1)
            #end while
            line = ''
            while re.match('^(Connection to "[^"]+" successful|Connection failed)$', line) == None:
                line = self.readline(self.dbe_connections[profile], None, conn).replace("\n", "").replace("\r", "")
            #end while
            sql = self.get_default_options() + 'set maxrows = 100;\n'
            self.dbe_connections[profile].stdin.write(sql)
            txt = self.receiverDbe(self.dbe_connections[profile], conn, 2)
        #end if
        if n - len(profile) - 4 > 0:
            pipe = self.dbe_connections[profile]
            data = conn.recv(n - len(profile))
            self.do_log(data, "dbExplorer")
            if (data):
                statements = data.split("\n==========\n")
                sql = ''
                for statement in statements:
                    sql = sql + statement
                #end for
                sql = sql + "\n"
                if self.debug:
                    print "SEND TO SERVER: " + sql
                #end if
                pipe.stdin.write(sql)
                self.do_log("SEND TO SERVER: " + sql, "dbExplorer#stdin.write")
                result = self.receiverDbe(pipe, conn, len(statements))
                conn.send(self.prepareResult(result))
                self.do_log(self.prepareResult(result), "dbExplorer#send")
            #end if
        #end if
        conn.send('DISCONNECT')
    #end def dbExplorer

    def searchResult(self, conn, n):
        data = self.readData(conn, n)
        identifier = data.replace('?', '')
        self.do_log(data, "searchResult")
        keys = []
        for key in self.statements:
            statement = self.statements[key]
            if statement['identifier'] == identifier and statement['result'] != None:
                conn.send(self.prepareResult(statement['result']))
                self.do_log(self.prepareResult(statement['result']), "searchResult#send")
                keys.append(key)
            #end if
        #end if

        for key in keys:
            del self.statements[key]
        #end for
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

    def add_statement(self, sql, identifier, pipe, conn):
        with self.statements_lock:
            statement = {'identifier': identifier, 'sql': sql, 'result': None}
            _uuid = str(uuid.uuid4())
            self.statements[_uuid] = statement
            self.processing.append({'uuid': _uuid, 'identifier': identifier, 'conn': conn})
            if self.debug:
                print "SENT TO SERVER: " + sql
            #end if
            self.do_log("SENT TO SERVER: " + sql, "add_statement")
            pipe.stdin.write(sql + "\n")
            return _uuid
        #end with
    #end def add_statement

    def receiveData(self, conn, pipe, n):
        buff = self.readData(conn, n)
        buff = buff.replace("\n", "#NEWLINE#")
        pattern = "^\\?([^\\?]+)\\?(.*)$"
        identifier = None
        uuids = []
        if re.match(pattern, buff):
            identifier = re.sub(pattern, "\\1", buff)
            buff = re.sub(pattern, "\\2", buff)
        #end if
        buff = buff.replace("#NEWLINE#", "\n")
        statements = buff.split("\n==========\n")
        for statement in statements:
            if (identifier == None):
                self.current_conn = conn
            #end if

            uuid = self.add_statement(statement, identifier, pipe, conn)
            uuids.append(uuid)
        #end for
        processed = False
        while not processed:
            processed = True
            for uuid in uuids:
                if self.statements[uuid]['result'] == None:
                    time.sleep(0.1)
                    processed = False
                    break
                #end if
            #end for
        #end while
        with self.new_loop:
            if identifier == None:
                data = ''
                for uuid in uuids:
                    if data != '':
                        data = data + "\n"
                    #endif
                    data = data + self.prepareResult(self.statements[uuid]['result'])
                    del self.statements[uuid]
                #end for
                conn.send(data)
                self.do_log(data, "receiveData#send")
                self.current_conn = None
            else:
                p = self.getCaller(identifier)
                self.toVim('sw#got_async_result(\\"%s\\")' % p.group(2), p.group(1))
            #end if
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
            n = int(n)
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

    def receiverDbe(self, pipe, conn, statements):
        line = ''
        buff = ''
        while statements > 0:
            line = self.readline(pipe, None, conn)
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

    def readline(self, pipe, identifier = None, conn = None):
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
                    if identifier == None and conn == None:
                        if len(self.processing) == 0:
                            raise Exception("The server is waiting for an input, but it doesn't know who is waiting for this input (no active connection and no vim servername)")
                        #end if
                        identifier = self.processing[0]['identifier']
                        conn = self.processing[0]['conn']
                    #end if
                    if identifier == None and conn != None:
                        conn.send("FEEDBACK" + line)
                        response = ''
                        r_ch = ''
                        while r_ch != '\n':
                            try:
                                r_ch = conn.recv(1)
                                response += r_ch
                            except:
                                r_ch = ''
                                time.sleep(0.1)
                            #end try
                        #end while
                        pipe.stdin.write(response)
                    elif identifier != None:
                        p = self.getCaller(identifier)
                        self.toVim('<C-\\><C-N>:call sw#interactive#get(\'%s\')<CR>' % line.replace("'", "''"), p.group(1), '--remote-send')
                    #end if
                    line = ''
                    self.wait_input = 1
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
                buff = ''
                self.wait_input = 0
                self.in_resultset = 0
            #end with
            while re.match(self.resultset_end_pattern, line.replace("\n", "")) == None:
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
                            buff = ''
                        #end if
                    #end if
                    if self.wait_input == 0:
                        buff += line
                    #end if
                    if self.debug:
                        sys.stdout.write(line)
                        sys.stdout.flush()
                    #end if
                else:
                    break
                #end if
            #end while
            if len(self.processing) > 0:
                obj = self.processing.popleft()
                self.statements[obj['uuid']]['result'] = buff
                buff = ''
                del obj
            #end if
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
