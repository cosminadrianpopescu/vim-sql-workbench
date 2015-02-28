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
    let g:Sw_unique_id = 0
endif

let s:wake_vim_cmd = ''
let g:sw_async_ended = []

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

function! sw#is_async()
	if g:sw_asynchronious
		if exists('v:servername')
			if v:servername != ''
				return 1
			endif
		endif
	endif

	return 0
endfunction

function! s:get_wake_vim_cmd()
	return s:wake_vim_cmd . ' --remote-expr "sw#got_async_result(' . s:get_buff_unique_id() . ')"'
endfunction

function! s:delete_tmp()
	if (g:sw_delete_tmp)
		call delete(g:sw_tmp . '/' . s:input_file())
		call delete(g:sw_tmp . '/' . s:output_file())
		call delete(g:sw_tmp . '/' . s:async_input_file())
	endif
endfunction


function! sw#async_end()
    let idx = index(g:sw_async_ended, s:get_buff_unique_id())
    if idx != -1
        unlet g:sw_async_ended[idx]
    endif
    if exists('b:async_on_progress')
        unlet b:async_on_progress
        if exists('b:on_async_result')
            let func = b:on_async_result
            execute "call " . func . "()"
        endif
		call s:delete_tmp()
    endif
endfunction

function! sw#reset_current_command()
    let idx = index(g:sw_async_ended, s:get_buff_unique_id())
    if idx != -1
        unlet g:sw_async_ended[idx]
    endif
    if exists('b:async_on_progress')
        unlet b:async_on_progress
    endif
	call s:delete_tmp()
endfunction

function! sw#kill_current_command()
    let idx = index(g:sw_async_ended, s:get_buff_unique_id())
    if idx != -1
        unlet g:sw_async_ended[idx]
    endif
    if exists('b:async_on_progress')
        unlet b:async_on_progress
    endif
    if exists('b:on_async_result')
        unlet b:on_async_result
    endif
    if exists('b:on_async_kill')
        let func = b:on_async_kill
        call sw#session#unset_buffer_variable('on_async_kill')
        execute "call " . func . "()"
    endif
	call s:delete_tmp()
endfunction

function! sw#check_async_result()
    let uid = s:get_buff_unique_id()
    if uid != -1
        if index(g:sw_async_ended, uid) != -1
            call sw#async_end()
        endif
    endif
endfunction

function! sw#got_async_result(unique_id)
    call add(g:sw_async_ended, a:unique_id)
    if s:get_buff_unique_id() == a:unique_id
        if mode() == 'i' || mode() == 'R'
            let m = mode()
            if m == 'i'
                let m = 'a'
            endif
            call sw#async_end()
            execute "normal " . m
        elseif mode() == 'V' || mode() == 'v' || mode() == 's'
            let m = mode()
            normal 
            call sw#async_end()
            normal gv
            if m == 's'
                normal 
            endif
        else
            call sw#async_end()
        endif
    endif
    redraw!
    return ''
endfunction

function! s:on_windows()
	if exists('v:progname')
		return v:progname =~ '\v\.exe$'
	endif
endfunction

" Executes a shell command{{{1
function! sw#do_shell(command)
    let prefix = ''
    if (!g:sw_show_shell_output)
        let prefix = 'silent'
    endif

	if sw#is_async()
		let async = 0
		if exists('v:progname')
			let file = g:sw_tmp . '/' . s:async_input_file()
			let commands = [a:command, s:get_wake_vim_cmd()]
			if s:on_windows()
				if exists('g:loaded_dispatch')
					if g:loaded_dispatch
						call writefile(commands, file)
						execute "Start! " . file
						let async = 1
					endif
				endif
			else
                let shell = &shell 
				call writefile(commands, file)
				execute prefix . ' !' . shell . ' ' . file . ' &'
				let async = 1
			endif
		endif

		if async
            let b:async_on_progress = 1
			return 1
		endif
	endif
	if s:on_windows()
		execute prefix . ' !' . a:command
	else
		execute prefix . ' !clear && echo Executting && cat ' . g:sw_tmp . '/' . s:input_file() . ' && ' . a:command
	endif
	return 0
endfunction

function! s:get_profile(profile)
    if a:profile =~ '\v^__no__'
        let profile = ' ' . b:connection
    else
        let profile = ' -profile=' . a:profile
    endif

    return profile
endfunction

function! s:input_file()
    return 'sw-sql-' . g:sw_instance_id . (sw#is_async() ? '-' . s:get_buff_unique_id() : '')
endfunction

function! s:output_file()
    return 'sw-result-' . g:sw_instance_id . (sw#is_async() ? '-' . s:get_buff_unique_id() : '')
endfunction

function! s:async_input_file()
	return 'sw-async-' . g:sw_instance_id . (sw#is_async() ? '-' . s:get_buff_unique_id() : '') . '.bat'
endfunction

function! sw#get_sql_result(touch_result)
	let result = readfile(g:sw_tmp . '/' . s:output_file())
	let touch_result = a:touch_result

	if (touch_result && len(result) > 0)
		if result[len(result) - 1] =~ '\v\c^\([0-9]+ row[s]?\)$'
			let result[0] = result[len(result) - 1]
			unlet result[len(result) - 1]
		else
			unlet result[0]
		endif
	endif

	""let i = 0
	""for row in result
	""    if row == a:command
	""        unlet result[i]
	""        break 
	""    endif
	""    let i = i + 1
	""endfor

	if (g:sw_show_command)
		call add(result, "")
		call add(result, '-----------------------------------------------------------------------------')
		call add(result, ' Command executed: ' . a:command)
	endif

	return result
endfunction

" Executes an sql command{{{1
function! sw#execute_sql(profile, command, ...)
    if sw#is_async()
        if exists('b:async_on_progress')
            if b:async_on_progress
                throw 'There is a command in progress for this buffer. Please wait for it to finish.'
            endif
        endif
    endif
    execute "silent !echo '' >" . g:sw_tmp . '/' . s:output_file()
    let delimiter = ''
    if (exists('b:delimiter'))
        if (b:delimiter != ';')
            let delimiter = ' -delimiter=' . b:delimiter
        endif
    endif
    let abort_on_errors = ''
    if (exists('b:abort_on_errors'))
        if (!b:abort_on_errors)
            let abort_on_errors = ' -abortOnError=false'
        endif
    endif
    let feedback = ' -feedback=false'
    if (exists('b:feedback'))
        if (b:feedback)
            let feedback = ' -feedback=true'
        endif
    endif

    let c = g:sw_exe . s:get_profile(a:profile) . ' -displayResult=true ' . delimiter . abort_on_errors . feedback . ' -script=' . g:sw_tmp . '/' . s:input_file() . ' >' . g:sw_tmp . '/' . s:output_file()
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
    let g:sw_last_command = c
    let lines = split(a:command, "\n")
    call writefile(lines, g:sw_tmp . '/' . s:input_file())
	" If do_shell returns 0, it means that the command was not executed
	" asynchroniously
	if (!sw#do_shell(c))
		redraw!
		let touch_result = 1
		if a:0
			let touch_result = a:1
		endif
		return sw#get_sql_result(touch_result)
	endif

	redraw!
	return []
endfunction

" Exports as ods{{{1
function! sw#export_ods(profile, command)
    let g:sw_last_sql_query = a:command
    let format = input('Please select a format (text | sqlinsert | sqlupdate | sqldeleteinsert | xml | ods | html | json): ', 'ods')
    if (format != '')
        let location = input('Please select a destination file: ', '', 'file')
        if (location != '')
            let queries = sw#sql_split(a:command)
            call writefile(['WbExport -type=' . format . ' -file=' . location . ';', queries[len(queries) - 1]], g:sw_tmp . '/' . s:input_file())
            let c = g:sw_exe . s:get_profile(a:profile) . ' -displayResult=true -script=' . g:sw_tmp . '/' . s:input_file()
            call sw#do_shell(c)
            redraw!
        endif
    endif
endfunction

" Hides columns from a resultset{{{1
function! sw#hide_columns(rows, columns)
    let result = []
    let a_columns = split(a:rows[1], "|")
    let i = 0
    let final = len(a:rows)
    if (g:sw_show_command)
        let final = len(a:rows) - 4
    endif
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

" Test the split function{{{1
function! sw#test_split()
    let s = "select * from t where a = \";\\\"''\"; \nselect * from t2 where b = \"...;\"; select n from t where x = 'u\\'';"
    let s = "let result = sw#execute_sql(b:profile, a:sql)"
    echo sw#sql_split(s)
endfunction

" Test function for executing an sql statement{{{1
function! sw#test()
    let v = sw#execute_sql('pozeLocal', 'WbGrepSource -searchValues="references j_banner_clients" -types=TABLE -useRegex=false')
    ""let v = sw#hide_columns(v, [2])
    call writefile(v, '/tmp/tmp')
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
function! sw#set_special_buffer(profile)
	setlocal buftype=nofile
	setlocal bufhidden=wipe
	setlocal noswapfile
	setlocal nowrap
	setlocal nobuflisted
    setlocal nomodifiable
    call sw#session#set_buffer_variable('profile', a:profile)
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

function! sw#autocomplete_profile_for_buffer(ArgLead, CmdLine, CursorPos)
    let words = split(a:CmdLine, '\v\s+')
    if len(words) == 1 || (len(words) == 2 && !(a:CmdLine =~ '\v\s+$'))
        return sw#autocomplete_profile(a:ArgLead, a:CmdLine, a:CursorPos)
    endif
    if a:ArgLead =~ '\v^\s*$'
        let path = '*'
    else
        let path = a:ArgLead . '*'
    endif
    return split(glob(path), '\n')
endfunction


