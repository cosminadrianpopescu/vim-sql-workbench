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

let s:data_parameters = [{'name': 'searchValue', 'prompt': 'Search terms: ', 'type': 'string', 'escape': 1, 'highlight': 1}, {'name': 'ignoreCase', 'prompt': 'Ignore case? [Y/N] ', 'type': 'boolean', 'default': g:sw_search_default_ignore_case, 'highlight_case': 1}, {'name': 'compareType', 'prompt': 'Possible values: equals | matches | startsWith | isNull. Compare type: ', 'type': 'select', 'default': g:sw_search_default_compare_types, 'options': ['equals', 'matches', 'startsWith', 'isNull']}, {'name': 'tables', 'prompt': 'Tables list: ', 'type': 'string', 'default': g:sw_search_default_tables}, {'name': 'types', 'prompt': 'Object types: ', 'type': 'string', 'default': g:sw_search_default_data_types, 'escape': 1}, {'name': 'excludeTables', 'prompt': 'Tables to exclude: ', 'type': 'string', 'continue_on_null': 1}, {'name': 'excludeLobs', 'prompt': 'Do you want to exclude lobs? [Y/N] ', 'type': 'boolean', 'default': g:sw_search_default_exclude_lobs}]

function! s:get_resultset_name()
    let uid = ''
    if exists('b:unique_id')
        let uid = b:unique_id
    elseif exists('b:r_unique_id')
        let uid = b:r_unique_id
    endif
    return "__SQLResult__-" . b:profile . '__' . uid
endfunction

function! s:input_boolean(message, default_value)
    let result = input(a:message, a:default_value)
    if result == ''
        return ''
    endif
    while !(result =~ '\v\c^(y|n)$')
        let result = input(a:message, a:default_value)
        if result == ''
            return ''
        endif
    endwhile
    if result =~ '\v\c^y$'
        let result = 'true'
    else 
        let result = 'false'
    endif

    return result
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

function! s:input_select(message, default_value, options)
    call sw#session#set_buffer_variable('complete_options', a:options)
    let result = input(a:message, a:default_value,'customlist,sw#search#input_select_complete')
    call sw#session#unset_buffer_variable('complete_options')
    return result
endfunction

function! s:process_search_result(result, columns)
    let result = a:result
    if a:columns != ''
        let _c = split(a:columns, ',')
        let columns = []
        for column in _c
            if column == 'NAME'
                call add(columns, 0)
            endif
            if column == 'TYPE'
                call add(columns, 1)
            endif
            if column == 'SOURCE'
                call add(columns, 2)
            endif
        endfor

        let i = 0
        let hide = []
        while i < 3
            if index(columns, i) == -1
                call add(hide, i)
            endif
            let i = i + 1
        endwhile

        if exists('b:resultsets')
            call sw#session#unset_buffer_variable('resultsets')
        endif
        if exists('b:messages')
            call sw#session#unset_buffer_variable('messages')
        endif

        if len(hide) > 0
            let result = sw#hide_columns(result, hide)
        endif
	else
		let _r = []
		for line in result
			if !(line =~ ':')
				call add(_r, line)
			endif
		endfor

		let result = _r
    endif
    let __name = ''
    if exists('b:max_results')
        let __name = bufname('%')
        let uid = b:unique_id
        let name = s:get_resultset_name()
        if (!bufexists(name))
            let profile = b:profile
			let s_below = &splitbelow
			set splitbelow
            execute "split " . name
			call sw#session#init_section()
            call sw#set_special_buffer(profile)
			if !s_below
				set nosplitbelow
			endif
			call sw#session#set_buffer_variable('state', 'resultsets')
            call sw#session#set_buffer_variable('r_unique_id', uid)
        endif
    endif
    let highlight = ''
    if exists('b:highlight')
        let highlight = b:highlight
        call sw#session#unset_buffer_variable('highlight')
        if exists('b:highlight_case')
            let highlight = b:highlight_case . highlight
            call sw#session#unset_buffer_variable('highlight_case')
        endif

        let highlight = '\V' . highlight
    endif
    if bufwinnr('__SQL__-' . b:profile) != -1
        call sw#goto_window('__SQL__-' . b:profile)
    else
        call sw#goto_window(s:get_resultset_name())
        let __name = sw#find_buffer_by_unique_id(b:r_unique_id)
    endif
    if exists('b:match_id')
        try
            call matchdelete(b:match_id)
        catch
        endtry
        call sw#session#unset_buffer_variable('match_id')
    endif
    setlocal modifiable
    normal ggdG

	let resultsets = []

    for line in result
        put =line
		call add(resultsets, line)
    endfor

	if exists('b:state')
		call sw#session#set_buffer_variable('resultsets', resultsets)
	endif

    normal ggdd
    if highlight != ''
        call sw#session#set_buffer_variable('match_id', matchadd('Search', highlight))
    endif
    setlocal nomodifiable
    if __name != ''
        call sw#goto_window(__name)
    endif
endfunction

function! s:set_async_variables(columns)
    let b:on_async_result = 'sw#search#on_async_result'
    let b:on_async_kill = 'sw#search#on_async_kill'
    let b:__columns = a:columns
endfunction

function! s:asynchronious(columns, set)
    let name = sw#session#buffer_name()
    if name == s:get_resultset_name()
        let a_name = sw#find_buffer_by_unique_id(b:r_unique_id)
    else
        let a_name = s:get_resultset_name()
    endif
    if a:set
        call s:set_async_variables(a:columns)
    else
        call s:unset_async_variables()
    endif
    call sw#goto_window(a_name)
    if a:set
        call s:set_async_variables(a:columns)
    else
        call s:unset_async_variables()
    endif
    call sw#goto_window(name)
endfunction

function! s:unset_async_variables()
    if exists('b:on_async_result')
        unlet b:on_async_result
    endif
    if exists('b:on_async_kill')
        unlet b:on_async_kill
    endif
    if exists('b:__columns')
        unlet b:__columns
    endif
endfunction

function! sw#search#on_async_result()
    let result = sw#get_sql_result(0)
    let columns = g:sw_search_default_result_columns
    if exists('b:__columns')
        let columns = b:__columns
    endif
    call s:process_search_result(result, columns)
    call s:asynchronious('', 0)
endfunction

function! sw#search#on_async_kill()
    let name = s:get_resultset_name()
    if bufexists(name)
        call sw#goto_window(name)
        setlocal modifiable
        normal G
        put ='Interrupted'
        setlocal nomodifiable
    endif
    call s:asynchronious('', 0)
endfunction

function! sw#search#do(command, columns)
	call sw#session#init_section()
    if exists('b:feedback')
        let feedback = b:feedback
        call sw#session#unset_buffer_variable('feedback')
    endif
    call s:asynchronious(a:columns, 1)
    let result = sw#execute_sql(b:profile, a:command, 0)
    if exists('feedback')
        call sw#session#set_buffer_variable('feedback', feedback)
    endif
    if len(result) > 0
        call s:process_search_result(result, a:columns)
        call s:asynchronious('', 0)
    else
        call s:process_search_result(['Searching...'], '')
    endif
endfunction

function! sw#search#data_defaults(value)
    if !exists('b:profile')
        throw 'The search can be performed from a database explorer or an sql buffer.'
    endif

    let command = 'WbGrepData -searchValue="' . escape(a:value, '"') . '" -ignoreCase=' . g:sw_search_default_ignore_case . ' -compareType=' . g:sw_search_default_compare_types . ' -tables=' . g:sw_search_default_tables . ' -types="' . g:sw_search_default_data_types . '" -excludeTables=' . g:sw_search_default_exclude_tables . ' -excludeLobs=' . g:sw_search_default_exclude_lobs

    call sw#session#set_buffer_variable('highlight', value)
    call sw#session#set_buffer_variable('highlight_case', '')
    
    if g:sw_search_default_ignore_case == 'Y'
        call sw#session#set_buffer_variable('highlight_case', '\c')
    endif

    call sw#search#do(command, '')
endfunction

function! sw#search#object_defaults(values)
    if !exists('b:profile')
        throw 'The search can be performed from a database explorer or an sql buffer.'
    endif
    let command = 'WbGrepSource -searchValues="' . escape(a:values, '"') . '" -useRegex=' . g:sw_search_default_regex . ' -matchAll=' . g:sw_search_default_match_all . ' -ignoreCase=' . g:sw_search_default_ignore_case . ' -types="' . g:sw_search_default_types . '" -objects=' . g:sw_search_default_objects

    call sw#search#do(command, g:sw_search_default_result_columns)
endfunction

function! s:get_search_parameters(v)
    let result = ''
    echo 'You can cancel at any time by returning an empty response at any question.'
    for p in a:v
        let default = ''
        if has_key(p, 'default')
            let default = p['default']
        endif
        if p['type'] == 'string'
            let v = input(p['prompt'], default)
        elseif p['type'] == 'boolean'
            let v = s:input_boolean(p['prompt'], default)
        elseif p['type'] == 'select'
            let v = s:input_select(p['prompt'], default, p['options'])
        endif
        let cont = 0
        if has_key(p, 'continue_on_null')
            let cont = p['continue_on_null']
        endif

        if has_key(p, 'highlight')
            call sw#session#set_buffer_variable('highlight', v)
        endif

        if !cont
            if v == ''
                return ''
            endif
        endif

        if has_key(p, 'highlight_case')
            if p['highlight_case']
                call sw#session#set_buffer_variable('highlight_case', '')
            else
                call sw#session#set_buffer_variable('highlight_case', '\c')
            endif
        endif

        if has_key(p, 'escape')
            if p['escape']
                let v = '"' . escape(v, '"') . '"'
            endif
        endif

        let result = result . ' -' . p['name'] . '=' . v
    endfor

    return result
endfunction

function! sw#search#prepare(cmd, ...)
    if !exists('b:profile')
        throw 'The search can be performed from a database explorer or an sql buffer.'
    endif
    if !a:0
        if a:cmd == 'WbGrepSource'
            let command = a:cmd . s:get_search_parameters(s:obj_parameters)
        else
            let command = a:cmd . s:get_search_parameters(s:data_parameters)
        endif
        if command == a:cmd
            return
        endif
        if a:cmd == 'WbGrepSource'
            let columns = input('Available columns are: NAME,TYPE,SOURCE. Select columns to display: ', g:sw_search_default_result_columns)
        else
            let columns = ''
        endif
    else
        let i = 1
        let command = a:cmd
        if a:cmd == 'WbGrepSource'
            let columns = g:sw_search_default_result_columns
        else
            let columns = ''
        endif
        while i <= a:0
            let cmd = "let arg = a:" . i
            execute cmd
            let command = command . ' -searchValues=' . arg
            let i = i + 1
        endwhile
    endif

    call sw#search#do(command, columns)
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
