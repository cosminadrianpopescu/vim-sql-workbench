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

"let s:obj_parameters = [
"    {'name': 'searchValues', 'prompt': 'Search terms: ', 'type': 'string', 'escape': 1}, 
"    {'name': 'useRegex', 'prompt': 'Use regular expressions? [Y/N] ', 'type': 'boolean', 'default': g:sw_search_default_regex}, 
"    {'name': 'matchAll', 'prompt': 'Match all values? [Y/N] ', 'type': 'boolean', 'default': g:sw_search_default_match_all}, 
"    {'name': 'ignoreCase', 'prompt': 'Ignore case? [Y/N] ', 'type': 'boolean', 'default': g:sw_search_default_ignore_case}, 
"    {'name': 'types', 'prompt': 'Object types: ', 'type': 'string', 'default': g:sw_search_default_types, 'escape': 1}, 
"    {'name': 'objects', 'prompt': 'Objects list', 'type': 'string', 'default': g:sw_search_default_objects}
"]
let s:obj_parameters = [{'name': 'searchValues', 'prompt': 'Search terms: ', 'type': 'string', 'escape': 1}, {'name': 'useRegex', 'prompt': 'Use regular expressions? [Y/N] ', 'type': 'boolean', 'default': g:sw_search_default_regex}, {'name': 'matchAll', 'prompt': 'Match all values? [Y/N] ', 'type': 'boolean', 'default': g:sw_search_default_match_all}, {'name': 'ignoreCase', 'prompt': 'Ignore case? [Y/N] ', 'type': 'boolean', 'default': g:sw_search_default_ignore_case}, {'name': 'types', 'prompt': 'Object types: ', 'type': 'string', 'default': g:sw_search_default_types, 'escape': 1}, {'name': 'objects', 'prompt': 'Objects list: ', 'type': 'string', 'default': g:sw_search_default_objects}]

"let s:data_parameters = [
"    {'name': 'searchValue', 'prompt': 'Search terms: ', 'type': 'string', 'escape': 1, 'highlight': 1}, 
"    {'name': 'ignoreCase', 'prompt': 'Ignore case? [Y/N] ', 'type': 'boolean', 'default': g:sw_search_default_ignore_case, 'highlight_case': 1}, 
"    {'name': 'compareType', 'prompt': 'Possible values: equals | matches | startsWith | isNull. Compare type: ', 'type': 'select', 'default': g:sw_search_default_compare_types, 'options': ['equals', 'matches', 'startsWith', 'isNull']}, 
"    {'name': 'tables', 'prompt': 'Tables list: ', 'type': 'string', 'default': g:sw_search_default_tables}, 
"    {'name': 'types', 'prompt': 'Object types: ', 'type': 'string', 'default': g:sw_search_default_data_types, 'escape': 1}, 
"    {'name': 'excludeTables', 'prompt': 'Tables to exclude: ', 'type': 'string', 'continue_on_null': 1}, 
"    {'name': 'excludeLobs', 'prompt': 'Do you want to exclude lobs? [Y/N] ', 'type': 'boolean', 'default': g:sw_search_default_exclude_lobs}
"]

let s:data_parameters = [{'name': 'searchValue', 'prompt': 'Search terms: ', 'type': 'string', 'escape': 1, 'highlight': 1}, {'name': 'ignoreCase', 'prompt': 'Ignore case? [Y/N] ', 'type': 'boolean', 'default': g:sw_search_default_ignore_case, 'highlight_case': 1}, {'name': 'compareType', 'prompt': 'Possible values: contains | equals | matches | startsWith | isNull. Compare type: ', 'type': 'select', 'default': g:sw_search_default_compare_types, 'options': ['containe', 'equals', 'matches', 'startsWith', 'isNull']}, {'name': 'tables', 'prompt': 'Tables list: ', 'type': 'string', 'default': g:sw_search_default_tables}, {'name': 'types', 'prompt': 'Object types: ', 'type': 'string', 'default': g:sw_search_default_data_types, 'escape': 1}, {'name': 'excludeTables', 'prompt': 'Tables to exclude: ', 'type': 'string', 'continue_on_null': 1}, {'name': 'excludeLobs', 'prompt': 'Do you want to exclude lobs? [Y/N] ', 'type': 'boolean', 'default': g:sw_search_default_exclude_lobs}]

function! s:get_resultset_name()
    let uid = ''
    if exists('b:unique_id')
        let uid = b:unique_id
    elseif exists('b:r_unique_id')
        let uid = b:r_unique_id
    endif
    return "__SQLResult__-" . uid
endfunction

function! s:input_boolean(callback, prompt, value)
    if a:value == ''
        return
    endif
    if a:value =~ '\v\c^y(es)?$'
        let result = 'true'
    else 
        let result = 'false'
    endif

    call a:callback(a:prompt, result)
endfunction

function! sw#search#input_select_complete(a1, a2, a3)
    if !exists('b:complete_options')
        return []
    endif

    let result = []
    for option in b:complete_options
        if option =~ '^' . a:a1
            call add(result, option)
        endif
    endfor
    return result
endfunction

function! s:set_async_variables(columns)
    let b:__columns = a:columns
endfunction

function! s:unset_async_variables()
    if sw#dbexplorer#is_db_explorer_tab()
        call sw#dbexplorer#unset_values_from_all_buffers(['on_async_result', '__columns', 'async_on_progress'])
    else
        if exists('b:on_async_result')
            unlet b:on_async_result
        endif
        if exists('b:__columns')
            unlet b:__columns
        endif
    endif
endfunction

function! sw#search#do(command)
    echomsg "Searching. Please wait..."
	call sw#session#init_section()
    call sw#server#execute_sql(a:command . ';')
endfunction

function! sw#search#data_defaults(value)
    let command = 'WbGrepData -searchValue="' . escape(a:value, '"') . '" -ignoreCase=' . g:sw_search_default_ignore_case . ' -compareType=' . g:sw_search_default_compare_types . ' -tables=' . g:sw_search_default_tables . ' -types="' . g:sw_search_default_data_types . '" -excludeTables=' . g:sw_search_default_exclude_tables . ' -excludeLobs=' . g:sw_search_default_exclude_lobs

    call sw#session#set_buffer_variable('highlight', a:value)
    call sw#session#set_buffer_variable('highlight_case', '')
    
    if g:sw_search_default_ignore_case == 'Y'
        call sw#session#set_buffer_variable('highlight_case', '\c')
    endif

    call sw#search#do(command)
endfunction

function! sw#search#object_defaults(values)
    let command = 'WbGrepSource -searchValues="' . escape(a:values, '"') . '" -useRegex=' . g:sw_search_default_regex . ' -matchAll=' . g:sw_search_default_match_all . ' -ignoreCase=' . g:sw_search_default_ignore_case . ' -types="' . g:sw_search_default_types . '" -objects=' . g:sw_search_default_objects

    call sw#search#do(command)
endfunction

function! s:on_search_response(v, idx, callback, result, prompt, value)
    let p = a:v[a:idx]
    let cont = 0
    if has_key(p, 'continue_on_null')
        let cont = p['continue_on_null']
    endif

    if has_key(p, 'highlight')
        call sw#session#set_buffer_variable('highlight', a:value)
    endif

    if !cont
        if a:value == ''
            call a:callback('')
            return
        endif
    endif

    if has_key(p, 'highlight_case')
        if p['highlight_case']
            call sw#session#set_buffer_variable('highlight_case', '')
        else
            call sw#session#set_buffer_variable('highlight_case', '\c')
        endif
    endif

    let x = a:value
    if has_key(p, 'escape')
        if p['escape']
            let x = '"' . escape(a:value, '"') . '"'
        endif
    endif

    let result = a:result . ' -' . p['name'] . '=' . x

    if a:idx + 1 >= len(a:v)
        call a:callback(result)
        return
    endif
    call s:get_search_parameters(a:v, a:idx + 1, a:callback, result)
endfunction

function! s:input_select(message, default_value, options, callback)
    call sw#session#set_buffer_variable('complete_options', a:options)
    call sw#input(a:message, a:callback, 'customlist,sw#search#input_select_complete', a:default_value)
endfunction

function! s:get_search_parameters(v, idx, callback, result)
    ""echo 'You can cancel at any time by returning an empty response at any question.'
    let default = ''
    let p = a:v[a:idx]
    if has_key(p, 'default')
        let default = p['default']
    endif
    let Callback = function('s:on_search_response', [a:v, a:idx, a:callback, a:result])
    if p['type'] == 'string'
        call sw#input(p['prompt'], Callback, v:null, default)
    elseif p['type'] == 'boolean'
        call sw#select(['Yes', 'No'], p['prompt'], function('s:input_boolean', [Callback]))
    elseif p['type'] == 'select'
        call s:input_select(p['prompt'], default, p['options'], Callback)
    endif
endfunction

function! s:search_parameters_finished(cmd, result)
    if (a:cmd == a:result)
        return 
    endif
    call sw#search#do(a:result)
endfunction

function! sw#search#prepare(cmd, ...)
    if !a:0
        let Callback = function('s:search_parameters_finished', [a:cmd])
        if a:cmd == 'WbGrepSource'
            call s:get_search_parameters(s:obj_parameters, 0, Callback, a:cmd)
        else
            call s:get_search_parameters(s:data_parameters, 0, Callback, a:cmd)
        endif
        return
    else
        let i = 1
        let command = a:cmd
        while i <= a:0
            let cmd = "let arg = a:" . i
            execute cmd
            let command = command . ' ' . (a:cmd == 'WbGrepSource' ? '-searchValues' : '-searchValue') . '=' . arg . ' -types="TABLE"'
            let i = i + 1
        endwhile
    endif

    call sw#search#do(command)
endfunction

function! sw#search#object(...)
    let command = 'call sw#search#prepare("WbGrepSource"'
    let i = 1
    while i <= a:0
        let cmd = "let arg = a:" . i
        execute cmd
        let command = command . ', "' . escape(arg, '"') . '"'
        let i = i + 1
    endwhile

    let command = command . ")"

    execute command
endfunction

function! sw#search#data(...)
    let command = 'call sw#search#prepare("WbGrepData"'
    let i = 1
    while i <= a:0
        let cmd = "let arg = a:" . i
        execute cmd
        let command = command . ', "' . escape(arg, '"') . '"'
        let i = i + 1
    endwhile

    let command = command . ")"
    execute command
endfunction
