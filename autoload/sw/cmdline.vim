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

let s:last_result = ''

function! sw#cmdline#execute(channel, ...)
    let s:last_result = ''
    let sql = ''
    let i = 1
    while i <= a:0
        execute "let sql .= ' ' . a:" . i
        let i = i + 1
    endwhile
    call sw#server#execute_sql(sql . ';', a:channel, 'sw#cmdline#got_result')
endfunction

function! sw#cmdline#got_result(result)
    let s:last_result .= a:result
endfunction

function! sw#cmdline#show_last_result()
    let s_below = &splitbelow
    set splitbelow
    execute "split __TMP__-" . sw#generate_unique_id()
    call sw#set_special_buffer()
    setlocal modifiable
    if !s_below
        set nosplitbelow
    endif

    let lines = split(s:last_result, "\n")
    for line in lines
        put =line
    endfor
    setlocal nomodifiable
endfunction
