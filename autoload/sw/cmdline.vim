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

function! sw#cmdline#execute(wait_result, port, ...)
    let sql = ''
    let i = 1
    while i <= a:0
        execute "let sql .= ' ' . a:" . i
        let i = i + 1
    endwhile
    let b:on_async_result = 'sw#sqlwindow#check_results'
    let b:delimiter = ';'
    let result = sw#server#execute_sql(sql, a:wait_result, a:port)
    if result != ''
        call s:process_results(result)
    endif
endfunction

function! sw#cmdline#got_result()
    let s:last_result = sw#server#fetch_result()
    if results != ''
        call s:process_results(result)
    endif
endfunction

function! s:process_results(result)
    let s:last_result = a:result
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
