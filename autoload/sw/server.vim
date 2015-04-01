"============================================================================"
"
"  Vim SQL Workbench/J Implementation
"
"  Copyright (c) Cosmin Popescu
"
"  Author:      Cosmin Popescu <cosminadrianpopescu at gmail dot com>
"  Version:     1.00 (2015-01-08)
"  Requires:    Vim 7
"  License:     GPL
"
"  Description:
"
"  Provides SQL database access to any DBMS supported by SQL Workbench/J. The
"  only dependency is SQL Workbench/J. Also includes powefull intellisense
"  autocomplete based on the current selected database
"
"============================================================================"

let s:current_file = expand('<sfile>:p:h')
let s:active_servers = []

function! s:get_pipe_name(id)
    return g:sw_tmp . '/sw-pipe-' . a:id
endfunction

function! sw#server#run(port, ...)
    if !exists('g:loaded_dispatch')
        throw 'You cannot start a server without vim dispatch plugin. Please install it first. If you don''t want or you don''t have the possibility to install it, you can always start the server manually. '
    endif
    let cmd = 'Start! ' . s:current_file . '/../../resources/sqlwbconsole' . ' -t ' . g:sw_tmp . ' -s ' . v:servername . ' -c ' . g:sw_exe . ' -v ' . g:sw_vim_exe . ' -o ' . a:port

    if a:0
        let cmd = cmd + ' -p ' . a:1
    endif

    execute cmd
    redraw!
endfunction

function! sw#server#connect_buffer(port, ...)
    let file = bufname('%')
    let command = 'e'
    if (a:0 >= 2)
        let file = a:1
        let command = a:2
    elseif a:0 >= 1
        let command = a:1
    endif
    call sw#sqlwindow#open_buffer(a:port, file, command)
endfunction

function! sw#server#new(port)
    call add(s:active_servers, a:port)
    echomsg "Added new server on port: " . a:port
    call sw#interrupt()
    redraw!
    return ''
endfunction

function! sw#server#remove(port)
    let i = 0
    for port in s:active_servers
        if port == a:port
            unlet s:active_servers[i]
        endif
        let i = i + 1
    endfor
    echomsg "Removed server from port: " . a:port
    call sw#interrupt()
    redraw!
    return ''
endfunction

function! s:pipe_execute(type, cmd, wait_result, ...)
    let port = 0
    if a:0
        let port = a:1
    else
        if exists('b:port')
            let port = b:port
        endif
    endif
    if port == 0
        throw "There is no port set for this buffer. "
    endif
    let uid = -1
    if exists('b:unique_id')
        let uid = b:unique_id
    endif

    python << SCRIPT
import vim
import re
identifier = vim.eval('v:servername') + "#" + vim.eval('uid')
cmd = vim.eval('a:cmd') + "\n"
port = int(vim.eval('port'))
type = vim.eval('a:type')
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(('127.0.0.1', port))
s.sendall(type)
if vim.eval('a:wait_result') == '0':
    s.sendall("!#identifier = " + identifier + "\n")
#end if
s.sendall(cmd)
if vim.eval('a:wait_result') == '0' or (vim.eval('a:wait_result') == '1' and type != 'RES' and type != 'DBE'):
    s.sendall("!#end = 1\n")
#end if
result = ''
if vim.eval('a:wait_result') == '1':
    while 1:
        data = s.recv(4096)
        if (re.search('^DISCONNECT', data)):
            break
        #end if
        if not data:
            break
        #end if
        result += data
    #end while
#end if
s.close()
vim.command("let result = ''")
lines = result.split("\n")
for line in lines:
    vim.command("let result = result . '%s\n'" % line.replace("'", "''"))
#end for
SCRIPT
    if len(result) <= 3
        let result = ''
    endif
    return substitute(result, '\r', '', 'g')
endfunction

function! sw#server#stop(port)
    call s:pipe_execute('COM', "exit", 0, a:port)
endfunction

function! sw#server#fetch_result()
    let result = s:pipe_execute('RES', v:servername . "#" . b:unique_id, 1, b:port)
    return result
endfunction

function! sw#server#open_dbexplorer(profile, port)
    return s:pipe_execute('DBE', a:profile . "\n", 1, a:port)
endfunction

function! sw#server#dbexplorer(sql)
    if !exists('b:profile')
        return
    endif
    let s = s:pipe_execute('DBE', b:profile . "\n" . a:sql . ';', 1)
    let lines = split(s, "\n")
    let result = []
    let rec = 0
    for line in lines
        if line =~ '\v\c^[ \s\t\r]*$'
            let rec = 0
            if (len(result) > 0)
                call add(result, '')
            endif
        endif
        if rec
            call add(result, line)
        endif
        if line =~ '\v\c^[\=]+$'
            let rec = 1
        endif
    endfor
    return result
endfunction

function! sw#server#execute_sql(sql, wait_result, port)
    let sql = a:sql
    if !(substitute(sql, "^\\v\\c\\n", ' ', 'g') =~ b:delimiter . '[ \s\t\r]*$')
        let sql = sql . b:delimiter . "\n"
    endif
    return s:pipe_execute('COM', sql, a:wait_result, a:port)
endfunction
