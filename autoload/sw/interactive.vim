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

let s:label = ''

function! sw#interactive#wait(label)
    let s:label = a:label
    normal 
    redraw!
    let val = input("SQL Workbench/J is asking an input for " . s:label)
    return ''
endfunction

function! sw#interactive#get(label)
    let val = input("SQL Workbench/J is asking an input for " . a:label)
    call sw#server#send_feedback(val)
endfunction
