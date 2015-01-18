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

let s:pattern_resultset_start = '\v^([\-]+\+?)+([\-]*)$'
let s:pattern_empty_line = '\v^[\r \s\t]*$'
let s:script_path = expand('<sfile>:p:h') . '/../../'

function! s:check_sql_buffer()
    if (!exists('b:profile'))
        throw "The current buffer is not an SQL Workbench buffer. Open it using the SWOpenSQL command."
    endif
endfunction

function! sw#sqlwindow#goto_statement_buffer()
    if (exists('b:r_unique_id'))
        let b = sw#find_buffer_by_unique_id(b:r_unique_id)
        if b != ''
            call sw#goto_window(b)
        endif
    endif
endfunction

function! s:set_shortcuts(default_var, path)
    if a:default_var == 'default'
        let cmd = "so " . s:script_path . a:path
        execute cmd
    else
        so a:default_var
    endif
endfunction

function! sw#sqlwindow#set_statement_shortcuts()
    call s:set_shortcuts(g:sw_shortcuts_sql_buffer_statement, "resources/shortcuts_sql_buffer_statement.vim")
    call sw#sqlwindow#check_hidden_results()
endfunction

function! sw#sqlwindow#set_results_shortcuts()
    call s:set_shortcuts(g:sw_shortcuts_sql_results, "resources/shortcuts_sql_results.vim")
endfunction

function! sw#sqlwindow#hide_results()
    let i = 1
    let pagen = tabpagenr()
    while i <= bufnr('$')
        if (bufexists(i))
            if tabpagenr() == pagen
            endif
        endif
        let i = i + 1
    endwhile
endfunction

function! s:do_open_buffer()
    call sw#session#set_buffer_variable('display_result_as', g:sw_display_result_as)
    call sw#session#set_buffer_variable('max_results', g:sw_max_results)
    call sw#session#set_buffer_variable('delimiter', g:sw_delimiter)
    call sw#session#set_buffer_variable('abort_on_errors', g:sw_abort_on_errors)
    call sw#session#set_buffer_variable('feedback', g:sw_feedback)
    call sw#session#set_buffer_variable('unique_id', sw#generate_unique_id())
    call sw#session#autocommand('BufEnter', 'sw#sqlwindow#set_statement_shortcuts()')
    call sw#session#autocommand('BufEnter', 'sw#check_async_result()')
    call sw#sqlwindow#set_statement_shortcuts()
    ""normal gg
    ""put ='-- Current profile: ' . b:profile
endfunction

function! sw#sqlwindow#open_buffer(profile, file, command)
    execute a:command . " " . a:file
    call sw#session#init_section()
    call sw#session#set_buffer_variable('profile', a:profile)
    call s:do_open_buffer()
endfunction

function! sw#sqlwindow#open_buffer_no_profile(...)
    if !a:0
        throw "You need to supply at least the file name"
    endif
    call sw#session#init_section(a:1)
    execute g:sw_sqlopen_command . " " . a:1
    let i = 2
    call sw#session#set_buffer_variable('connection', '')
    while i <= a:0
        let cmd = "let arg = a:" . i
        execute cmd
        call sw#session#set_buffer_variable('connection', b:connection . ' ' . arg)
        let i = i + 1
    endwhile

    call sw#session#set_buffer_variable('profile', '__no__' . sw#generate_unique_id())
    call s:do_open_buffer()
endfunction

function! sw#sqlwindow#display_options(a1, a2, a3)
    let options = ['tab', 'record']
    let result = []

    for option in options
        if option =~ '^' . a:a1
            call add(result, option)
        endif
    endfor

    return result
endfunction

function! sw#sqlwindow#set_display(what)
    call s:check_sql_buffer()
    call sw#session#set_buffer_variable('display_result_as', a:what)
endfunction

function! sw#sqlwindow#set_max_rows(n)
    call s:check_sql_buffer()
    call sw#session#set_buffer_variable('max_results', a:n)
endfunction

function! sw#sqlwindow#set_abort_on_errors(what)
    call s:check_sql_buffer()
    call sw#session#set_buffer_variable('abort_on_errors', a:what)
endfunction

function! sw#sqlwindow#set_delimiter(new_del)
    call s:check_sql_buffer()
    call sw#session#set_buffer_variable('delimiter', a:new_del)
endfunction

function! sw#sqlwindow#set_feedback(what)
    call s:check_sql_buffer()
    call sw#session#set_buffer_variable('feedback', a:what)
endfunction

function! sw#sqlwindow#export_last()
    call sw#export_ods(b:profile, g:sw_last_sql_query)
endfunction

function! sw#sqlwindow#extract_current_sql(...)
    let lines = getbufline(bufname(bufnr('.')), 1, '$')
    let pos = getpos('.')
    let n = pos[2] - 2
    let m = n + 1
    let i = pos[1] - 1
    if n < 0
        let lines[i] = '#CURSOR#' . lines[i]
    else
        let cmd = 'let lines[' . i . '] = lines[' . i . '][0:' . n . '] . "#CURSOR#" . lines[' . i . '][' . m . ':]' 
        execute cmd
    endif

    let s = ''
    for line in lines
        let s = s . line . "\n"
    endfor

    let sqls = sw#sql_split(s, b:delimiter)
    for sql in sqls
        if sql =~ '#CURSOR#'
            if (!a:0 || (a:0 && !a:1))
                let sql = substitute(sql, '#CURSOR#', '', 'g')
            endif
            return sql
        endif
    endfor
    throw "Could not identifiy the current query"
    return ""
endfunction

function! sw#sqlwindow#extract_selected_sql()
    let z_save = @z
    normal gv"zy
    let sql = @z
    let @z = z_save
    return sql
endfunction

function! sw#sqlwindow#extract_all_sql()
    let pos = getpos('.')
    let z_save = @z
    normal ggVG"zy
    let sql = @z
    let @z = z_save
    call setpos('.', pos)
    return sql
endfunction

function! sw#sqlwindow#toggle_messages()
    if (!exists('b:messages') || !(exists('b:resultsets')))
        return 
    endif
    if b:state != 'resultsets' && b:state != 'messages'
        return 
    endif
    call sw#goto_window(sw#sqlwindow#get_resultset_name())
    if b:state == 'resultsets'
        call sw#session#set_buffer_variable('position', getpos('.'))
    endif
    setlocal modifiable
    normal ggdG
    if b:state == 'messages'
        call s:display_resultsets()
    elseif b:state == 'resultsets'
        call sw#session#set_buffer_variable('state', 'messages')
        for line in b:messages
            put =line
        endfor
    endif
    normal ggdd
    setlocal nomodifiable
    if (exists('b:position') && b:state == 'resultsets')
        call setpos('.', b:position)
    endif
endfunction

function! sw#sqlwindow#toggle_display()
    if (!exists('b:resultsets') || !exists('b:state'))
        return 
    endif
    if b:state == 'form'
        setlocal modifiable
        normal ggdG
        call s:display_resultsets()
        normal ggdd
        setlocal nomodifiable
        if (exists('b:position'))
            call setpos('.', b:position)
        endif
        return 
    endif
    if b:state != 'resultsets'
        return 
    endif
    let line = line('.')
    
    if (line <= 3 || getline('.') =~ s:pattern_empty_line || getline('.') == '')
        throw "You have to be on a row in a resultset"
    endif
    let row_limits = s:get_row_limits()
    call s:display_as_form(row_limits)
    call sw#session#set_buffer_variable('state', 'form')
endfunction

function! s:display_as_form(row_limits)
    let resultset_start = s:get_resultset_start()
    call sw#session#set_buffer_variable('position', getpos('.'))

    let _columns = split(b:resultsets[resultset_start - 2], '|')
    let s_len = 0
    let columns = []
    for column in _columns
        let column = substitute(column, '\v^[ ]?([^ ]+)[ ]+$', '\1', 'g')
        call add(columns, column)
        if strlen(column) > s_len
            let s_len = strlen(column) + 1
        endif
    endfor

    let lines = []

    let n = 0
    let k = 0
    for column in columns
        let line = column
        let i = strlen(line)
        while i < s_len
            let line = line . ' '
            let i = i + 1
        endwhile

        let line = line . ': '

        if column == columns[len(columns) - 1]
            let m = n + strlen(b:resultsets[a:row_limits[0] - 1]) - n
        else
            let m = n + strlen(_columns[k]) - 1
            if (k > 0)
                let m = m - 1
            endif
        endif
        let cmd = "let line = line . b:resultsets[a:row_limits[0] - 1][" . n . ":" . m . "]"
        execute cmd
        let i = a:row_limits[0] + 1
        while i <= a:row_limits[1]
            let cmd = "let txt = b:resultsets[i - 1][" . n . ":" . m . "]"
            execute cmd
            
            if !(txt =~ s:pattern_empty_line)
                call add(lines, line)
                let line = ''
                let j = 0
                while j < s_len
                    let line = line . ' '
                    let j = j + 1
                endwhile
                let line = line . ': '
                let line = line . txt
            endif
            let i = i + 1
        endwhile
        let n = m + 3
        let k = k + 1
        let line = substitute(line, '\v^([^:]+):[ ]*([0-9]+)[ ]*$', '\1: \2', 'g')
        call add(lines, line)
    endfor
    setlocal modifiable
    normal ggdG
    for line in lines
        put =line
    endfor
    normal ggdd
    setlocal modifiable
endfunction

function! s:get_resultset_start()
    let resultset_start = line('.')
    while resultset_start > 1
        if getline(resultset_start) =~ s:pattern_resultset_start
            break
        endif
        let resultset_start = resultset_start - 1
    endwhile

    if (resultset_start == 1)
        throw "Could not indentifiy the resultset"
    endif

    return resultset_start
endfunction

function! s:get_row_limits()
    let resultset_start = s:get_resultset_start()
    let row_start = line('.')
    let row_end = line('.') + 1
    let columns = split(b:resultsets[resultset_start - 2], '|')

    while (row_start > resultset_start)
        let n = 0
        let line = b:resultsets[row_start - 1]
        let stop = 0
        for column in columns
            if line[n + strlen(column)] == '|'
                let stop = 1
                break
            endif
            let n = n + strlen(column) + 1
        endfor
        if (stop)
            break
        endif
        if line =~ s:pattern_resultset_start
            let row_start = row_start + 1
            break
        endif
        let row_start = row_start - 1
    endwhile

    while (row_end < len(b:resultsets))
        let n = 0
        let line = b:resultsets[row_end - 1]
        let stop = 0
        for column in columns
            if line[n + strlen(column)] == '|'
                let stop = 1
                break
            endif
            let n = n + strlen(column) + 1
        endfor
        if (stop)
            let row_end = row_end - 1
            break
        endif
        
        if (line =~ s:pattern_empty_line || line == '')
            let row_end = row_end - 1
            break
        endif
        let row_end = row_end + 1
    endwhile

    return [row_start, row_end]
endfunction

function! s:display_resultsets()
    for line in b:resultsets
        put =line
    endfor
    call sw#session#set_buffer_variable('state', 'resultsets')
endfunction

function! s:process_result(result)
    let result = a:result
    let uid = b:unique_id
    let name = "__SQLResult__-" . b:profile . '__' . b:unique_id
    let profile = b:profile

    if (bufexists(name))
        call sw#goto_window(name)
        setlocal modifiable
        normal ggdG
    else
        let uid = b:unique_id
        let s_below = &splitbelow
        set splitbelow
        execute "split " . name
        call sw#session#init_section()
        call sw#set_special_buffer(profile)
        call sw#sqlwindow#set_results_shortcuts()
        call sw#session#set_buffer_variable('r_unique_id', uid)
        call sw#session#autocommand('BufEnter', 'sw#sqlwindow#set_results_shortcuts()')
        setlocal modifiable
        if !s_below
            set nosplitbelow
        endif
    endif

    if exists('b:messages')
        call sw#session#unset_buffer_variable('messages')
    endif
    if exists('b:resultsets')
        call sw#session#unset_buffer_variable('resultsets')
    endif
    call sw#session#set_buffer_variable('messages', [])
    call sw#session#set_buffer_variable('resultsets', [])

    let i = 0
    let n = -1
    let mode = 'message'
    let pattern = '\v\c^\(([0-9]+) row[s]?\)$'
    while i < len(result)
        if (i + 1 < len(result))
            if result[i + 1] =~ s:pattern_resultset_start
                let mode = 'resultset'
                let n = len(b:resultsets)
                call add(b:resultsets, '')
            endif
        endif
        
        if (mode == 'resultset' && (result[i] =~ s:pattern_empty_line || result[i] == ''))
            let mode = 'message'
            call add(b:resultsets, '')
        endif
        if (mode == 'resultset')
            call add(b:resultsets, result[i])
        elseif mode == 'message'
            call add(b:messages, substitute(result[i], "\r", '', 'g'))
            if result[i] =~ pattern
                if (n != -1)
                    let rows = substitute(result[i], pattern, '\1', 'g')
                    let b:resultsets[n] = 'Query returned ' . rows . ' rows'
                    call sw#session#set_buffer_variable('resultsets', b:resultsets)
                    let n = -1
                endif
            endif
        endif
        let i = i + 1
    endwhile

    if len(b:resultsets) > 0
        call s:display_resultsets()
    else
        for line in b:messages
            put =line
        endfor
        call sw#session#set_buffer_variable('state', 'messages')
        call sw#session#unset_buffer_variable('resultsets')
    endif

    normal ggdd
    setlocal nomodifiable
    let b = sw#find_buffer_by_unique_id(b:r_unique_id)
    if b != ''
        call sw#goto_window(b)
    endif
endfunction

function! sw#sqlwindow#on_async_result()
    let result = sw#get_sql_result(0)
    call s:process_result(result)
    ""call feedkeys(':echo ')
endfunction

function! sw#sqlwindow#on_async_kill()
    let result = ['Interrupted asynchronious command...']
    call s:process_result(result)
endfunction

function! sw#sqlwindow#execute_sql(sql)
    let w:auto_added1 = "-- auto\n"
    let w:auto_added2 = "-- end auto\n"

    call s:check_sql_buffer()
    let _sql = a:sql
    if (b:display_result_as != 'tab')
        let _sql = w:auto_added1 . 'WbDisplay ' . b:display_result_as . "\n" . b:delimiter . "\n" . w:auto_added2 . _sql
    endif
    if (b:max_results != 0)
        let _sql = w:auto_added1 . 'set maxrows = ' . b:max_results . "\n" . b:delimiter . "\n" . w:auto_added2 . _sql
    endif
    let b:on_async_result = 'sw#sqlwindow#on_async_result'
    let b:on_async_kill = 'sw#sqlwindow#on_async_kill'
    let result = sw#execute_sql(b:profile, _sql, 0)

    if len(result) != 0
        unlet b:on_async_result
        unlet b:on_async_kill
        call s:process_result(result)
    else
        if sw#is_async()
            call s:process_result(['Processing a command. Please wait...'])
        endif
    endif
endfunction

function! sw#sqlwindow#get_object_info()
    if (!exists('b:profile'))
        return
    endif

    let obj = expand('<cword>')
    let sql = "desc " . obj
    call sw#sqlwindow#goto_statement_buffer()
    call sw#sqlwindow#execute_sql(sql)
endfunction

function! sw#sqlwindow#get_resultset_name()
    if exists('b:profile') && exists('b:unique_id')
        return '__SQLResult__-' . b:profile . '__' . b:unique_id
    endif
    return ''
endfunction

function! sw#sqlwindow#close_all_result_sets()
    if bufname('%') =~ '\v__SQLResult__'
        return
    endif
    if exists('g:sw_session')
        let name = bufname('%')
        let rs_name = ''
        if exists('b:profile')
            let rs_name = sw#sqlwindow#get_resultset_name()
        endif
        for k in keys(g:sw_session)
            if k =~ '\v^__SQLResult__' && k != rs_name
                if bufwinnr(k) != -1
                    call sw#goto_window(k)
                    call sw#session#set_buffer_variable('hidden', 1)
                    hide
                    call sw#goto_window(name)
                endif
            endif
        endfor
    endif
endfunction

function! sw#sqlwindow#check_hidden_results()
    if exists('g:sw_session')
        let name = '__SQLResult__-' . b:profile . '__' . b:unique_id
        if bufwinnr(name) != -1
            return
        endif
        if has_key(g:sw_session, name)
            if has_key(g:sw_session[name], 'hidden')
                if g:sw_session[name]['hidden']
                    let s_below = &splitbelow
                    set splitbelow
                    execute "split " . name
                    call sw#session#reload_from_cache()
                    call sw#session#unset_buffer_variable('hidden')
                    call sw#set_special_buffer(b:profile)
                    call sw#sqlwindow#set_results_shortcuts()
                    call sw#session#autocommand('BufEnter', 'sw#sqlwindow#set_results_shortcuts()')
                    setlocal modifiable
                    if !s_below
                        set nosplitbelow
                    endif
                    if b:state == 'messages'
                        for line in b:messages
                            put =line
                        endfor
                    else
                        call s:display_resultsets()
                    endif
                    normal ggdd
                    setlocal nomodifiable
                    call sw#sqlwindow#goto_statement_buffer()
                endif
            endif
        endif
    endif
endfunction

function! sw#sqlwindow#get_object_source()
    if (!exists('b:profile'))
        return
    endif

    let obj = expand('<cword>')
    let sql = 'WbGrepSource -searchValues="' . obj . '" -objects=' . obj . ' -types=* -useRegex=true;'
    call sw#sqlwindow#goto_statement_buffer()
    call sw#sqlwindow#execute_sql(sql)
endfunction
