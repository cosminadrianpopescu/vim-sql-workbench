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

if !exists('g:Sw_unique_id')
    let g:Sw_unique_id = 1
endif

if exists('v:servername') && exists('g:sw_vim_exe')
	if v:servername != ''
		let s:wake_vim_cmd = g:sw_vim_exe . ' --servername ' . v:servername
	endif
endif

function! sw#find_buffer_by_unique_id(uid)
    for k in keys(g:sw_session)
        if has_key(g:sw_session[k], 'unique_id')
            if g:sw_session[k].unique_id == a:uid
                return k
            endif
        endif
    endfor

    return ''
endfunction

function! s:get_buff_unique_id()
    if exists('b:unique_id')
        return b:unique_id
    endif

    if exists('b:r_unique_id')
        return b:r_unique_id
    endif

    return -1
endfunction

function! s:get_wake_vim_cmd()
	return s:wake_vim_cmd . ' --remote-expr "sw#got_async_result(' . s:get_buff_unique_id() . ')"'
endfunction

function! sw#set_on_async_result(value)
    if exists('b:on_async_result') && exists('b:async_on_progress') && !sw#dbexplorer#is_db_explorer_tab()
        throw 'There is a command in progress for this buffer. Please wait for it to finish.'
    endif

    let b:on_async_result = a:value
endfunction

function! sw#interrupt(...)
    if mode() == 'i' || mode() == 'R'
        let m = mode()
        if m == 'i'
            let m = 'a'
        endif
        if a:0
            execute "call " . a:1
        endif
        execute "normal " . m
    elseif mode() == 'V' || mode() == 'v' || mode() == 's'
        let m = mode()
        normal 
        if a:0
            execute "call " . a:1
        endif
        normal gv
        if m == 's'
            normal 
        endif
    else
        if a:0
            execute "call " . a:1
        endif
    endif
endfunction

function! sw#async_end()
    if exists('b:on_async_result')
        let func = b:on_async_result
        unlet b:on_async_result
        execute "call " . func . "()"
    endif
endfunction

function! sw#got_async_result(unique_id)
    if s:get_buff_unique_id() == a:unique_id
        call sw#interrupt('sw#async_end()')
    endif
    redraw!
    return ''
endfunction

function! s:on_windows()
	if exists('v:progname')
		return v:progname =~ '\v\.exe$'
	endif
endfunction

function! s:get_profile(profile)
    if a:profile =~ '\v^__no__'
        let profile = ' ' . b:connection
    else
        let profile = ' -profile=' . a:profile
    endif

    return profile
endfunction

function! sw#get_sw_profile()
    if exists('b:profile')
        return b:profile
    endif

    return ''
endfunction

" Executes an sql command{{{1
function! sw#execute_sql(command, wait_result)
    let g:sw_last_sql_query = a:command
    if (exists('w:auto_added1') && exists('w:auto_added2'))
        let s1 = substitute(w:auto_added1, "\n", '', 'g')
        let s2 = substitute(w:auto_added2, "\n", '', 'g')
        if a:command =~ '\v' . s1
            let add = 1
            let lines = split(a:command, "\n")
            let g:sw_last_sql_query = ''
            for line in lines
                if line =~ '\v' . s1
                    let add = 0
                endif
                if add
                    let g:sw_last_sql_query = g:sw_last_sql_query . line . "\n"
                endif
                if line =~ '\v' . s2
                    let add = 1
                endif
            endfor
        endif
    endif
    return sw#server#execute_sql(a:command, a:wait_result, b:port)
endfunction

" Exports as ods{{{1
function! sw#export_ods(command)
    let format = input('Please select a format (text | sqlinsert | sqlupdate | sqldeleteinsert | xml | ods | html | json): ', 'ods')
    if (format != '')
        let location = input('Please select a destination file: ', '', 'file')
        if (location != '')
            let queries = sw#sql_split(a:command)
            return sw#sqlwindow#execute_sql(0, "WbExport -type=" . format . ' -file=' . location . ';' . queries[0])
        endif
    endif
endfunction

" Hides columns from a resultset{{{1
function! sw#hide_columns(rows, columns, ...)
    let row_start = 1
    if a:0
        let row_start = a:1
    endif
    let result = []
    let a_columns = split(substitute(a:rows[row_start], '\v\c^[^\>\|]+\> ', '', 'g'), "|")
    let i = 0
    let final = len(a:rows)
    while i < final
        let s = ''
        let j = 0
        let w = 0
        if a:rows[i] =~ '\v^\([0-9]+ Row[^\)]+\)$'
            let i = i + 1
            continue
        endif 
        while j < len(a_columns)
            let f = w + strlen(a_columns[j]) - 1
            if (j == len(a_columns) - 1)
                let f = strlen(a:rows[i])
            endif
            if (index(a:columns, j) == -1)
                let cmd = 'let s = s . a:rows[i][' . w . ':' . f . ']'
                execute cmd
            endif
            let w = w + strlen(a_columns[j])
            let j = j + 1
        endwhile
        if !(s =~ '\v^[ \s]*$')
            call add(result, s)
        endif
        let i = i + 1
    endwhile
    if (index(a:columns, 0) != -1)
        let i = 0
        while i < final && i < len(result)
            let h = strlen(result[i])
            let cmd = 'let result[i] = result[i][2:' . h . ']'
            execute cmd
            let i = i + 1
        endwhile
    endif
    let i = final
    while (i < len(a:rows))
        call add(result, a:rows[i])
        let i = i + 1
    endwhile
    return result
endfunction

function! sw#get_sql_canonical(sql)
    let pattern = '\v"([^"]*)"'
    let s = substitute(a:sql, '\v[\r\n]', '#NEWLINE#', 'g')
    let s = substitute(s, "\\\\\"", '#ESCAPEDDOUBLEQUOTE#', 'g')
    let s = substitute(s, "\\\\'", '#ESCAPEDSINGLEQUOTE#', 'g')
    let m = matchstr(s, pattern, 'g')
    let matches = []
    let n = 0
    while m != ''
        execute "call add(matches, {'m" . n . "': m})"
        let m = substitute(m, "\\", "\\\\\\", 'g')
        let s = substitute(s, '\V' . m, '#m' . n . '#', 'g')
        let n = n + 1
        let m = matchstr(s, pattern, 'g')
    endwhile
    let pattern = "\\v'([^']*)'"
    let m = matchstr(s, pattern, 'g')
    while m != ''
        execute "call add(matches, {'m" . n . "': m})"
        let m = substitute(m, "\\", "\\\\\\", 'g')
        let s = substitute(s, '\V' . m, '#m' . n . '#', 'g')
        let n = n + 1
        let m = matchstr(s, pattern, 'g')
    endwhile

    return [s, matches]
endfunction

function! sw#index_of(s, search)
    let start = 0
    while start < strlen(a:s) - strlen(a:search)
        let n = start + strlen(a:search) - 1
        let cmd = "let s = a:s[" . start . ":" . n . "]"
        execute cmd
        if s == a:search
            return start
        endif
        let start = start + 1
    endwhile

    return -1
endfunction

" Splits an sql string in statements{{{1
function! sw#sql_split(sql, ...)
    let delimiter = ';'
    if a:0
        let delimiter = substitute(a:1, '\/', "\\/", 'g')
    endif
    let canon = sw#get_sql_canonical(a:sql)
    let s = canon[0]
    let matches = canon[1]
    let s = substitute(s, '\V' . delimiter, '#SEPARATOR#', 'g')
    let j = len(matches) - 1
    while j >= 0
        let i = items(matches[j])
        let m = '#' . i[0][0] . '#'
        let x = substitute(i[0][1], "\\", "\\\\\\", 'g')
        let s = substitute(s, m, x, 'g')
        let j = j - 1
    endwhile
    let s = substitute(s, '#NEWLINE#', "\n", 'g')
    let s = substitute(s, '#ESCAPEDDOUBLEQUOTE#', "\\\\\"", 'g')
    let s = substitute(s, '#ESCAPEDSINGLEQUOTE#', "\\\\'", 'g')
    let _result = split(s, '#SEPARATOR#')
    let result = []
    for r in _result
        
        if !(r =~ '\v^[ \s\t\n\r]*$') && r != ''
            call add(result, r)
        endif
    endfor
    return result
endfunction

" Hides the header{{{1
function! sw#hide_header(rows)
    let result = a:rows
    let i = 0
    for row in a:rows
        if row =~ '\v^[\-\+]{4,}$'
            break
        endif
        let i = i + 1
    endfor
    if i < len(a:rows)
        unlet result[i]
		if (i > 0)
			unlet result[i - 1]
		endif
    endif

    return result
endfunction

" Goes to a window identified by a buffer name{{{1
function! sw#goto_window(name)
    let crt = bufname('%')
    if bufwinnr(a:name) != -1
        while bufname('%') != a:name && sw#session#buffer_name() != a:name
            wincmd w
            if bufname('%') == crt
                return
            endif
        endwhile
    endif
endfunction

function! sw#generate_unique_id()
    let g:Sw_unique_id = g:Sw_unique_id + 1
    return g:Sw_unique_id
endfunction

" Sets a buffer to no modification{{{1
function! sw#set_special_buffer()
	setlocal buftype=nofile
	setlocal bufhidden=wipe
	setlocal noswapfile
	setlocal nowrap
	setlocal nobuflisted
    setlocal nomodifiable
endfunction

" Parses the profile xml file to give autocompletion for profiles{{{1
function! sw#parse_profile_xml()
    if !exists('g:sw_config_dir')
        return []
    endif

    let lines = readfile(g:sw_config_dir . 'WbProfiles.xml')
    let s = ''
    for line in lines
        let s = s . ' ' . line
    endfor

    let pattern = '\v\c\<object class\="[^"]{-}"\>.{-}\<void property\="name"\>.{-}\<string\>([^\<]{-})\<'
    let result = []
    let n = 1
    let list = matchlist(s, pattern, 0, n)
    while len(list) > 0
        if index(result, list[1]) == -1
            call add(result, list[1])
        endif
        let n = n + 1
        let list = matchlist(s, pattern, 0, n)
    endwhile

    return result
endfunction

function! sw#autocomplete_profile(ArgLead, CmdLine, CursorPos)
    let profiles = sw#parse_profile_xml()

    let result = []

    for profile in profiles
        if profile =~ '^' . a:ArgLead
            call add(result, profile)
        endif
    endfor

    return result
endfunction

function! s:autocomplete_path(ArgLead, CmdLine, CursorPos)
    if a:ArgLead =~ '\v^\s*$'
        let path = '*'
    else
        let path = a:ArgLead . '*'
    endif
    return split(glob(path), '\n')
endfunction

function! sw#autocomplete_profile_for_server(ArgLead, CmdLine, CursorPos)
    let words = split(a:CmdLine, '\v\s+')
    if len(words) == 4 || (len(words) == 3 && a:CmdLine =~ '\v\s+$')
        return sw#autocomplete_profile(a:ArgLead, a:CmdLine, a:CursorPos)
    endif
    if len(words) == 3 || (len(words) == 2 && a:CmdLine =~ '\v\s+$')
        return s:autocomplete_path(a:ArgLead, a:CmdLine, a:CursorPos)
    endif
    return []
endfunction

function! sw#autocomplete_profile_for_buffer(ArgLead, CmdLine, CursorPos)
    let words = split(a:CmdLine, '\v\s+')
    if len(words) == 1 || (len(words) == 2 && !(a:CmdLine =~ '\v\s+$'))
        return sw#autocomplete_profile(a:ArgLead, a:CmdLine, a:CursorPos)
    endif
    return s:autocomplete_path(a:ArgLead, a:CmdLine, a:CursorPos)
endfunction
