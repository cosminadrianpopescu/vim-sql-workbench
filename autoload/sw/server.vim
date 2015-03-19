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

function! sw#server#connect_buffer(port, file, command)
    let profile = 'server_' . a:port
    call sw#sqlwindow#open_buffer(profile, a:file, a:command)
    call sw#session#set_buffer_variable('profile', 'server_' . a:port . '_' . b:unique_id)
    call sw#session#set_buffer_variable('port', a:port)
endfunction

function! sw#server#ping(port)
    call s:pipe_execute('/*!#ping*/', a:port)
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

function! s:pipe_execute(cmd, ...)
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
buffer_id = vim.eval('uid')
instance_id = vim.eval('g:sw_instance_id')
cmd = vim.eval('a:cmd') + "\n"
port = int(vim.eval('port'))
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(('127.0.0.1', port))
s.sendall("!#buffer_id = " + buffer_id + "\n")
s.sendall("!#instance_id = " + instance_id + "\n")
s.sendall(cmd)
s.close()
SCRIPT
endfunction

function! sw#server#stop(port)
    call s:pipe_execute("exit", a:port)
endfunction

function! sw#server#execute_sql(sql)
    let sql = a:sql
    if !(substitute(sql, "^\\v\\c\\n", ' ', 'g') =~ b:delimiter . '[ \s\t\r]*$')
        let sql = sql . b:delimiter
    endif
    call s:pipe_execute(sql)
endfunction
