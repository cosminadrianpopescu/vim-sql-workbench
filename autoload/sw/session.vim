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

if !exists('g:Str_sw_session')
    let g:Str_sw_session = ''
endif

if !exists('g:sw_session')
    let g:sw_session = {}
endif

if !exists('g:sw_autocommands')
    let g:sw_autocommands = {}
endif

function! sw#session#buffer_name()
	let name = bufname('%')
	if name =~ '\v^__'
		return name
	endif
	return fnamemodify(name, ':p')
endfunction

function! s:key_name(...)
    if a:0
        let name = a:1
    else
		return sw#session#buffer_name()
    endif
    if name =~ '\v^__'
        return name
    endif
    return fnamemodify(name, ':p')
endfunction

function! sw#session#init_section(...)
    if a:0
        let name = s:key_name(a:1)
    else
        let name = s:key_name()
    endif
    if name != ''
        if !has_key(g:sw_session, name)
            let g:sw_session[name] = {}
        endif

        if !has_key(g:sw_autocommands, name)
            let g:sw_autocommands[name] = {}
        endif
    endif
endfunction

function! sw#session#set_buffer_variable(var, value)
    let cmd = "let b:" . a:var . " = a:value"
    execute cmd
    let g:sw_session[s:key_name()][a:var] = a:value
    let g:Str_sw_session = string(g:sw_session)
endfunction

function! sw#session#autocommand(event, func)
    if has_key(g:sw_autocommands, s:key_name()) 
        if has_key(g:sw_autocommands[s:key_name()], a:event)
            if g:sw_autocommands[s:key_name()][a:event] == a:func
                return
            endif
        endif
    endif
    let cmd = "autocmd " . a:event . " <buffer> " . "call " . a:func
    execute cmd
    let g:sw_autocommands[s:key_name()][a:event] = a:func
endfunction

function! sw#session#unset_buffer_variable(var)
    if has_key(g:sw_session[s:key_name()], a:var)
        unlet g:sw_session[s:key_name()][a:var]
    endif
    if exists('b:' . a:var)
        let cmd = "unlet b:" . a:var
        execute cmd
    endif
    let g:Str_sw_session = string(g:sw_session)
endfunction

function! sw#session#sync()
    return 
    if !exists("g:SessionLoad")
        for buffer in keys(g:sw_session)
            if !buffer_exists(buffer)
                unlet g:sw_session[buffer]
                unlet g:sw_autocommands[buffer]
            endif
        endfor
        let g:Str_sw_session = string(g:sw_session)
    endif
endfunction

function! sw#session#restore()
    return
    let g:sw_session = {}
    let g:sw_autocommands = {}
    if exists('g:Str_sw_session')
        if g:Str_sw_session != ''
            let cmd = "let g:sw_session = " . g:Str_sw_session
            execute cmd
        endif
    endif

    if exists('g:Str_sw_autocomplete_default_tables')
        if g:Str_sw_autocomplete_default_tables != ''
            execute "let g:sw_autocomplete_default_tables = " . g:Str_sw_autocomplete_default_tables
        endif
    endif

    if exists('g:Str_sw_autocomplete_default_procs')
        if g:Str_sw_autocomplete_default_procs != ''
            execute "let g:sw_autocomplete_default_procs = " . g:Str_sw_autocomplete_default_procs
        endif
    endif

    let g:session_restored = 1
endfunction

function! sw#session#reload_from_cache()
    let name = s:key_name()
    if has_key(g:sw_session, name)
        for k in keys(g:sw_session[name])
            let cmd = "let b:" . k . " = g:sw_session[name][k]"
            execute cmd
        endfor
    endif

    if has_key(g:sw_autocommands, name)
        for event in keys(g:sw_autocommands[name])
            let cmd = "autocmd " . event . " <buffer> call " . g:sw_autocommands[name][event]
            execute cmd
        endfor
    endif

    let b:restored_from_session = 1
endfunction

function! sw#session#check()
    let name = s:key_name()

    if has_key(g:sw_session, name) && !exists('b:profile')
        call sw#session#reload_from_cache()
    endif
endfunction

function! sw#session#restore_dbexplorer()
    call sw#session#check()
    call sw#dbexplorer#restore_from_session()
endfunction

function! sw#session#restore_sqlbuffer()
    call sw#session#check()
    call sw#goto_window(sw#sqlwindow#get_resultset_name())
    call sw#session#check()
    call sw#sqlwindow#goto_statement_buffer()
endfunction
