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

let s:pattern_resultset_title = '\v^[\=]SQL ([0-9]+)'
let s:pattern_ignore_line = '\v\c^#IGNORE#$'
let s:script_path = expand('<sfile>:p:h') . '/../../'
let g:sw_last_resultset = []

function! s:check_sql_buffer()
    if (!exists('b:sw_channel'))
        call sw#display_error("The current buffer is not an SQL Workbench buffer. Open it using the SWOpenSQL command.")
        return 0
    endif
    return 1
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
endfunction

function! sw#sqlwindow#set_results_shortcuts()
    call s:set_shortcuts(g:sw_shortcuts_sql_results, "resources/shortcuts_sql_results.vim")
endfunction

function! s:switch_to_results_tab()
    if !g:sw_switch_to_results_tab
        wincmd t
    endif
endfunction

function! sw#sqlwindow#message_handler(channel, results)
    if a:results != ''
        if (!s:open_resultset_window())
            call sw#display_error('Result set cannot be selected. Probably is hidden')
            return
        endif

        let b:current_channel = a:channel
        call s:process_result(a:channel, a:results)
        call s:display_resultsets(1)
        call s:switch_to_results_tab()
    endif
endfunction

function! sw#sqlwindow#auto_commands(when)
    let i = 1
    let pattern = '\v\c^-- ' . a:when . '[ \t]*(.*)$'
    let sql = ''
    while i < line('$')
        let line = getline(i)
        if line =~ pattern
            let command = substitute(line, pattern, '\1', 'g')
            if command =~ '\v\c^:'
                execute substitute(command, '\v\c^:', '', 'g')
            else
                let sql = sql . (sql == '' ? '' : ";\n") . command
            endif
        endif
        let i = i + 1
    endwhile

    if sql != ''
        echomsg "Executing automatic commands"
        call sw#sqlwindow#execute_macro(sql)
    endif
endfunction

function! sw#sqlwindow#auto_disconnect_buffer()
    let name = bufname(expand('<afile>'))
    let channel = getbufvar(name, 'sw_channel')
    call sw#server#disconnect_buffer(channel)
endfunction

function! s:do_open_buffer()
    call sw#session#autocommand('BufDelete', 'sw#sqlwindow#auto_disconnect_buffer()')
    call sw#session#autocommand('BufEnter', 'sw#sqlwindow#check_results()')
    call sw#session#set_buffer_variable('delimiter', g:sw_delimiter)
    call sw#session#set_buffer_variable('unique_id', sw#generate_unique_id())
    call sw#sqlwindow#set_statement_shortcuts()
    call sw#sqlwindow#auto_commands('before')
endfunction

function! sw#sqlwindow#open_buffer(file, command)
    call sw#session#init_section()
    call s:do_open_buffer()
endfunction

function! sw#sqlwindow#export_last()
    call sw#export_ods(g:sw_last_sql_query)
endfunction

function! sw#sqlwindow#extract_current_sql(...)
    let lines = getbufline(bufname(bufnr('%')), 1, '$')
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

    if !exists('b:delimiter')
        call sw#display_error("The buffer is not connected to a server. Please use SWSqlConectToServer before running queries")
        return ''
    endif
    let sqls = sw#sql_split(s, b:delimiter)
    for sql in sqls
        if sql =~ '#CURSOR#'
            if (!a:0 || (a:0 && !a:1))
                let sql = substitute(sql, '#CURSOR#', '', 'g')
            endif
            return sql . b:delimiter
        endif
    endfor
    call sw#display_error("Could not identify the current query")
    return ""
endfunction

function! sw#sqlwindow#extract_selected_sql()
    let z_save = @z
    normal gv"zy
    let sql = @z
    let @z = z_save
    if !(substitute(sql, '\v[\r\n]', '', 'g') =~ '\v' . b:delimiter . '[\n\r]*$')
        let sql .= ';'
    endif
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
    if (!(exists('b:resultsets')))
        return 
    endif
    if b:state != 'resultsets' && b:state != 'messages'
        return 
    endif
    call sw#goto_window(sw#sqlwindow#get_resultset_name())
    if bufname('%') != sw#sqlwindow#get_resultset_name()
        return
    endif
    if b:state == 'resultsets'
        call sw#session#set_buffer_variable('position', getpos('.'))
    endif
    call sw#session#set_buffer_variable('state', b:state == 'resultsets' ? 'messages' : 'resultsets')
    call s:display_resultsets(1)
endfunction

function! sw#sqlwindow#toggle_display()
    if (!exists('b:resultsets') || !exists('b:state'))
        return 
    endif
    if getline('.') == ''
        return
    endif
    if b:state == 'form'
        call sw#session#set_buffer_variable('state', 'resultsets')
    elseif b:state == 'resultsets'
        call sw#session#set_buffer_variable('state', 'form')
    endif
    let line = line('.')
    
    ""if (line <= 3 || getline('.') =~ sw#get_pattern('pattern_empty_line') || getline('.') == '')
    ""    call sw#display_error("You have to be on a row in a resultset")
    ""    return
    ""endif
    if b:state == 'form' || b:state == 'resultsets'
        call s:display_resultsets(1)
    endif
endfunction

function! s:get_n_resultset()
    let resultset_start = s:get_resultset_start(s:pattern_resultset_title)
    if resultset_start == -1
        call sw#display_error('Could not identify the resultset')
        return
    endif

    return substitute(getline(resultset_start), s:pattern_resultset_title, '\1', 'g') - 1
endfunction

function! s:get_idx(idx, n)
    let n = s:get_n_resultset()
    let idx = a:idx

    if !(idx =~ '\v^[0-9]+$')
        let idx = index(b:resultsets[a:n].header, idx)
    endif

    return idx
endfunction

function! s:get_column(column, n)
    let column = a:column
    if column =~ '\v^[0-9]+$'
        let column = b:resultsets[a:n].header[column]
    endif

    return column
endfunction

function! sw#sqlwindow#show_column(idx, show_results)
    let n = s:get_n_resultset()
    if (n == -1)
        return
    endif

    let a_idx = s:get_idx(a:idx, n)

    let idx = index(b:resultsets[n].hidden_columns, a_idx)
    if idx != -1
        call remove(b:resultsets[n].hidden_columns, idx)
    endif

    
    if a:show_results
        call s:display_resultsets(1)
    endif
endfunction

function! sw#sqlwindow#hide_column(idx, show_results)
    let n = s:get_n_resultset()
    if (n == -1)
        return
    endif
    
    let idx = s:get_idx(a:idx, n)

    let n_columns = len(split(b:resultsets[n].lines[b:resultsets[n].resultset_start], '+'))
    if idx < 0 || idx >= n_columns
        call sw#display_error("The index is out of range")
        return
    endif

    if n_columns == 1
        call sw#display_error("Just one column in the resultset.")
        return
    endif

    call add(b:resultsets[n].hidden_columns, idx)
    call sort(b:resultsets[n].hidden_columns)

    if a:show_results
        call s:display_resultsets(1)
    endif
endfunction

function! sw#sqlwindow#unfilter_column(column)
    let n = s:get_n_resultset()
    if n == -1
        return
    endif

    let column = s:get_column(a:column, n)
    unlet b:resultsets[n].filters[column]

    call s:display_resultsets(1)
endfunction

function! sw#sqlwindow#filter_column(column)
    let n = s:get_n_resultset()
    if n == -1
        return
    endif

    let filter = input('Please input the filter value: ')
    if filter != ''
        let column = s:get_column(a:column, n)
        let b:resultsets[n].filters[column] = filter

        call s:display_resultsets(1)
    endif
endfunction

function! sw#sqlwindow#remove_all_filters()
    let n = s:get_n_resultset()
    if n == -1
        return
    endif

    let b:resultsets[n].filters = {}
    call s:display_resultsets(1)
endfunction

function! sw#sqlwindow#show_all_columns()
    let n = s:get_n_resultset()
    if (n == -1)
        return
    endif
    let b:resultsets[n].hidden_columns = []
    call s:display_resultsets(1)
endfunction

function! sw#sqlwindow#show_only_column(column)
    let n = s:get_n_resultset()
    if (n == -1)
        return
    endif
    if index(b:resultsets[n].header, a:column) == -1
        call sw#display_error("The column does not exists")
        return
    endif
    for column in b:resultsets[n].header
        if column != a:column
            call sw#sqlwindow#hide_column(column, 0)
        endif
    endfor

    call s:display_resultsets(1)
endfunction

function! sw#sqlwindow#complete_columns(ArgLead, CmdLine, CursorPos)
    let n = s:get_n_resultset()
    if n == -1
        return []
    endif

    let result = []

    for column in b:resultsets[n].header
        if column =~ '^' . a:ArgLead
            call add(result, column)
        endif
    endfor

    return result
endfunction

function! sw#sqlwindow#show_only_columns(columns)
    let n = s:get_n_resultset()
    if n == -1
        return
    endif

    for column in b:resultsets[n].header
        if index(a:columns, column) == -1
            call sw#sqlwindow#hide_column(column, 0)
        endif
    endfor

    call s:display_resultsets(1)
endfunction

function! sw#sqlwindow#display_as_form()
    let row_limits = s:get_row_limits()
    if len(row_limits) == 0
        call sw#session#set_buffer_variable('state', 'resultsets')
        call sw#session#unset_buffer_variable('position')
        return
    endif
    let resultset_start = s:get_resultset_start()
    call sw#session#set_buffer_variable('position', getpos('.'))

    let _columns = split(getline(resultset_start - 1), '|')
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
            let m = n + strlen(getline(row_limits[0])) - n
        else
            let m = n + strlen(_columns[k]) - 1
            if (k > 0)
                let m = m - 1
            endif
        endif
        let cmd = "let line = line . getline(row_limits[0])[" . n . ":" . m . "]"
        execute cmd
        let i = row_limits[0] + 1
        while i <= row_limits[1]
            let cmd = "let txt = getline(i)[" . n . ":" . m . "]"
            execute cmd
            
            if !(txt =~ sw#get_pattern('pattern_empty_line'))
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
    call sw#put_lines_in_buffer(lines)
endfunction

function! s:get_resultset_start(...)
    let pattern = sw#get_pattern('pattern_resultset_start')
    if a:0
        let pattern = a:1
    endif
    let resultset_start = line('.')
    while resultset_start > 1
        if getline(resultset_start) =~ pattern
            break
        endif
        let resultset_start = resultset_start - 1
    endwhile

    if !(getline(resultset_start) =~ pattern)
        call sw#display_error("Could not indentify the resultset")
        return -1
    endif

    return resultset_start
endfunction

function! s:get_row_limits()
    let resultset_start = s:get_resultset_start()
    if resultset_start == -1
        return []
    endif

    let row_start = line('.')
    let row_end = line('.') + 1
    let columns = split(getline(resultset_start - 1), '|')

    while (row_start > resultset_start)
        let n = 0
        let line = getline(row_start)
        if line =~ sw#get_pattern('pattern_no_results')
            call sw#display_error("You are not on a resultset row.")
            return []
        endif
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
        if line =~ sw#get_pattern('pattern_resultset_start')
            let row_start = row_start + 1
            break
        endif
        let row_start = row_start - 1
    endwhile

    while (row_end < line('$'))
        let n = 0
        let line = getline(row_end)
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
        
        if (line =~ sw#get_pattern('pattern_empty_line') || line == '')
            let row_end = row_end - 1
            break
        endif
        let row_end = row_end + 1
    endwhile

    return [row_start, row_end]
endfunction

function! s:open_resultset_window()
    let name = sw#sqlwindow#get_resultset_name()

    if (!bufexists(name))
        let s_below = &splitbelow
        set splitbelow
        execute "split " . name
        call sw#session#init_section()
        call sw#set_special_buffer()
        call sw#sqlwindow#set_results_shortcuts()
        execute "autocmd! BufLeave " . bufname('%') . " let b:position = getcurpos()"
        if !s_below
            set nosplitbelow
        endif
    endif

    call sw#goto_window(name)

    return bufname('%') == name
endfunction

function! s:split_into_columns(resultset)
    let columns_length = split(a:resultset.lines[a:resultset.resultset_start], '+')
    if len(columns_length) <= 0
        return a:resultset.lines
    endif

    let result = []
    let i = 0
    for line in a:resultset.lines
        let matches = []
        call add(matches, line)
        if i > a:resultset.resultset_start - 2 && line != ''
            for c in columns_length
                let pattern = '\v^(.{' . len(c) . '}).?(.*)$'
                let match = substitute(line, pattern, '\1', 'g')
                call add(matches, match)
                let line = substitute(line, pattern, '\2', 'g')
            endfor

        endif

        call add(result, matches)
        let i += 1
    endfor

    return result
endfunction

function! s:print_line(line_idx, n_resultset, do_filter)
    let resultset = b:resultsets[a:n_resultset]
    let pattern_empty_line = '\v^[ \t\s\|\:]*$'

    let line = resultset.lines[a:line_idx]

    if a:line_idx <= resultset.resultset_start - 2
        return line
    endif

    let delimiter = line =~ sw#get_pattern('pattern_resultset_start') ? '+' : '|'
    let result = ''

    if (len(resultset.hidden_columns) > 0 || len(resultset.filters) > 0)
        if !exists('resultset.columns')
            let resultset.columns = s:split_into_columns(resultset)
        endif
    else
        return line
    endif

    if len(resultset.columns[a:line_idx]) <= 1
        return line
    endif

    let i = 1
    while i < len(resultset.columns[a:line_idx])
        if a:do_filter
            let column = s:get_column(i - 1, a:n_resultset)
            if has_key(resultset.filters, column)
                let filter = resultset.filters[column]
                let filter_in = 1
                if filter =~ '\v^[ \t\s]*[\>\<\=]{1,2}'
                    try
                        let filter_in = eval(resultset.columns[a:line_idx][i] . filter)
                    catch
                        let filter_in = 0
                    endtry
                else
                    let filter_in = substitute(resultset.columns[a:line_idx][i], '\v^[ \t\s]*(.{-})[ \t\s]*$', '\1', 'g') =~ filter
                endif
                if !filter_in
                    return '#IGNORE#'
                endif
            endif
        endif
        if index(resultset.hidden_columns, i - 1) == -1 && a:line_idx >= resultset.resultset_start - 1
            let result .= resultset.columns[a:line_idx][i]
            if i - 1 < len(resultset.columns[a:line_idx]) - 1
                let result .= delimiter
            endif
        endif

        let i += 1
    endwhile

    if result =~ pattern_empty_line
        let result = '#IGNORE#'
    endif
    return substitute(result, '\v^(.*)[+|]$', '\1', 'g')
endfunction

function! s:add_hidden_columns(n)
    let result = ''
    for c in b:resultsets[a:n].hidden_columns
        let result .= (result == '' ? '' : ', ') .  b:resultsets[a:n].header[c]
    endfor

    return result
endfunction

function! s:add_filters(n)
    let result = ''
    for column in keys(b:resultsets[a:n].filters)
        let result .= (result == '' ? '' : ', ') . column . ' ' . b:resultsets[a:n].filters[column]
    endfor

    return result
endfunction

function! s:output_content(content)
    call sw#put_text_in_buffer(a:content)
endfunction

function! s:build_header(n)
    let n = a:n
    let title = b:resultsets[len(b:resultsets) - n].title
    let header = '=SQL ' . string(n) . (title == '' ? '' : ': ') . title
    let rows = b:resultsets[len(b:resultsets) - n].rows
    if rows != 0
        let header .= ' (' . rows . ' rows)'
    endif
    let hidden_columns = s:add_hidden_columns(len(b:resultsets) - n)
    if hidden_columns != ''
        let header .= "\n(Hidden columns: " . hidden_columns . ")"
    endif
    let filters = s:add_filters(len(b:resultsets) - n)
    if (filters != '')
        let header .= "\n(Filters: " . filters . ")"
    endif

    let header .= "\n"

    return header
endfunction

function! s:display_resultsets_continous()
    let lines = ''
    let n = len(b:resultsets)
    call reverse(b:resultsets)
    let channel = ''
    if exists('b:current_channel')
        let channel = b:current_channel
    endif
    for resultset in b:resultsets
        if (resultset.channel != channel && channel != '')
            let n -= 1
            continue
        endif
        if b:state == 'resultsets'
            if len(resultset.lines) > 0
                let lines .= s:build_header(n)
            endif
            let i = 0
            for line in resultset.lines
                let row = s:print_line(i, len(b:resultsets) - n, i > resultset.resultset_start)
                if !(row =~ s:pattern_ignore_line)
                    let lines .= row . "\n"
                endif
                let i += 1
            endfor
        elseif b:state == 'messages'
            let lines .= s:build_header(n)
            for line in resultset.messages
                let lines .= line . "\n"
            endfor
        endif
        let n = n - 1
    endfor
    call reverse(b:resultsets)
    call s:output_content(lines)
endfunction

function! s:display_resultsets(continous)
    if b:state == 'form'
        call sw#sqlwindow#display_as_form()
    elseif a:continous
        call s:display_resultsets_continous()

        if g:sw_highlight_resultsets
            set filetype=sw
        endif
        setlocal foldmethod=expr
        setlocal foldexpr=sw#sqlwindow#folding(v:lnum)
        ""normal zMggjza
        ""normal zR
    else
        call s:display_resultsets_separate()
    endif

    if (exists('b:position') && b:state == 'resultsets' && !s:new_resultset)
        call setpos('.', b:position)
        normal zv
    elseif b:state == 'messages' || s:new_resultset
        normal zMzv
    endif
endfunction

function! s:add_new_resultset(channel, id)
    if exists('g:sw_last_sql_query')
        let query = g:sw_last_sql_query
    else
        let query = ''
    endif
    let n = s:get_next_resultset()
    let result = {'messages': [], 'lines': [], 'hidden_columns': [], 'resultset_start': 0, 'header': [], 'filters': {}, 'title': '', 'rows': 0, 'channel': a:channel, 'sql': query, 'id': a:id, 'wait_refresh': 0}
    if n == len(b:resultsets)
        call add(b:resultsets, result)
        let s:new_resultset = 1
    else
        let s:new_resultset = 0
        let b:resultsets[n] = result
    endif

    return n
endfunction

function! s:get_next_resultset()
    for i in range(len(b:resultsets))
        if b:resultsets[i]['wait_refresh'] && b:resultsets[i]['sql'] == g:sw_last_sql_query
            return i
        endif
    endfor

    return len(b:resultsets)
endfunction

function! s:process_result(channel, result)
    if a:result == ''
        return
    endif
    let lines = split(a:result, "\n")
    let b:current_channel = a:channel

    if !exists('b:resultsets')
        let initial = []
        if g:sw_save_resultsets
            let initial = g:sw_last_resultset
        endif
        let b:resultsets = initial
    endif

    let i = 0
    let mode = 'message'
    let resultset_id = sw#generate_unique_id()
    let n = s:add_new_resultset(a:channel, resultset_id)
    while i < len(lines)
        if i + 1 < len(lines) && lines[i + 1] =~ sw#get_pattern('pattern_resultset_start')
            "" If we have more than one resultset in a go.
            if len(b:resultsets[n].lines) > 0
                let n = s:add_new_resultset(a:channel, resultset_id)
            endif
            let mode = 'resultset'
            let b:resultsets[n].resultset_start = len(b:resultsets[n].lines)
        endif

        let pattern_title = '\v^----  ?(.*)$'
        if lines[i] =~ pattern_title
            let b:resultsets[n].title = substitute(lines[i], pattern_title, '\1', 'g')
            let i += 1
            continue
        endif
        if (mode == 'resultset' && (lines[i] =~ sw#get_pattern('pattern_empty_line') || lines[i] == '' || lines[i] =~ sw#get_pattern('pattern_exec_time') || lines[i] =~ sw#get_pattern('pattern_no_results')))
            let mode = 'message'
            call add(b:resultsets[n].lines, '')
        endif
        if lines[i] =~ sw#get_pattern('pattern_no_results')
            let b:resultsets[n].rows = substitute(lines[i], sw#get_pattern('pattern_no_results'), '\1', 'g')
        endif
        if (mode == 'resultset')
            call add(b:resultsets[n].lines, lines[i])
        elseif mode == 'message' && lines[i] != ''
            let line = substitute(lines[i], "\r", '', 'g')
            call add(b:resultsets[n].messages, line)
            if line =~ sw#get_pattern('pattern_exec_time')
                call add(b:resultsets[n].messages, "")
            endif
        endif
        if mode == 'resultset' && lines[i] =~ sw#get_pattern('pattern_resultset_start')
            let b:resultsets[n].resultset_start = len(b:resultsets[n].lines) - 1
        endif
        let i = i + 1
    endwhile

    if len(b:resultsets[n].lines) > 0
        let header = split(b:resultsets[n].lines[b:resultsets[n].resultset_start - 1], '|')
        for h in header
            call add(b:resultsets[n].header, substitute(h, '\v^[ ]*([^ ].*[^ ])[ ]*$', '\1', 'g'))
        endfor
    endif

    let g:sw_last_resultset = b:resultsets

    call sw#session#set_buffer_variable('state', len(b:resultsets[n].lines) > 0 ? 'resultsets' : 'messages')
    echomsg "Command completed"
endfunction

function! s:do_execute_sql(sql)
    echomsg "Processing a command. Please wait..."
    call sw#execute_sql(a:sql)
endfunction

function! sw#sqlwindow#execute_sql(sql)
    let w:auto_added1 = "-- auto\n"
    let w:auto_added2 = "-- end auto\n"

    if (!s:check_sql_buffer())
        return 
    endif
    let _sql = a:sql
    let title = substitute(a:sql, '\v[\n\r]', ' ', 'g')
    if strlen(title) > 255
        let title = title[:255] . '...'
    endif
    let _sql = '-- @wbresult ' . title . "\n" . _sql
    call s:do_execute_sql(_sql)
endfunction

function! sw#sqlwindow#execute_macro(...)
    if (a:0)
        let macro = a:1
    else
        let macro = sw#sqlwindow#extract_current_sql()
    endif
    call s:do_execute_sql(macro)
endfunction

function! sw#sqlwindow#get_object_info()
    if (!exists('b:sw_channel'))
        return
    endif

    let obj = expand('<cword>')
    let sql = "desc " . obj . ';'
    call sw#sqlwindow#execute_sql(sql)
endfunction

function! sw#sqlwindow#get_resultset_name()
    return '__SQLResult__'
endfunction

function! sw#sqlwindow#open_resulset_window()
    if (exists('b:sw_channel'))
        let channel = b:sw_channel
        if (!s:open_resultset_window())
            call sw#display_error('Result set cannot be selected. Probably is hidden')
            return
        endif
        let b:current_channel = channel
        call sw#goto_window(sw#sqlwindow#get_resultset_name())
        call sw#session#set_buffer_variable('state', 'resultsets')
        let b:resultsets = g:sw_last_resultset
        call s:display_resultsets(1)
    endif
endfunction

function! sw#sqlwindow#check_results()
    if exists('b:sw_channel')
        let channel = b:sw_channel
        let name = sw#sqlwindow#get_resultset_name()
        if sw#is_visible(name)
            call sw#goto_window(name)
            if (exists('b:current_channel') && b:current_channel != channel) || !exists('b:current_channel')
                let b:current_channel = channel
                call s:display_resultsets(1)
            endif
            call sw#goto_window(bufname(expand('<afile>')))
        endif
    endif
endfunction

function! sw#sqlwindow#get_object_source()
    if (!exists('b:sw_channel'))
        return
    endif

    let obj = expand('<cword>')
    let sql = 'WbGenerateScript -objects="' . obj . '";'
    call sw#sqlwindow#execute_sql(sql)
endfunction

function! sw#sqlwindow#folding(lnum)
    if (a:lnum == 1)
        let b:fold_level = 0
    endif
    if getline(a:lnum) =~ s:pattern_resultset_title
        let b:fold_level += 1
        return '>' . b:fold_level
    endif
    if getline(a:lnum) =~ '\v^$'
        let result = '<' . b:fold_level
        let b:fold_level -= 1
        return result
    endif

    return -1
endfunction

function! sw#sqlwindow#show_current_buffer_log()
    if !exists('b:sw_channel')
        call sw#display_error("The current buffer is not an SQL Workbench buffer. Open it using the SWOpenSQL command.")
        return
    endif

    let log = substitute(sw#server#channel_log(b:sw_channel), "\r", "\n", 'g')
    let log_name = "__LOG__" . fnamemodify(bufname('%'), ':t')
    call sw#goto_window(log_name)

    if bufname('%') != log_name
        execute "split " . log_name
    endif

	" Mark the buffer as scratch
	setlocal buftype=nofile
    setlocal filetype=txt
	setlocal bufhidden=wipe
	setlocal noswapfile
	setlocal nowrap
	setlocal nobuflisted

	silent put = log
endfunction

function! s:filter_resultsets(idx, val)
    return exists('b:sw_channel') ? a:val['channel'] != b:sw_channel : a:val['channel'] != b:current_channel
endfunction

function! sw#sqlwindow#wipeout_resultsets(all)
    if a:all
        let g:sw_last_resultset = []
    elseif exists('b:sw_channel') || exists('b:current_channel')
        call filter(g:sw_last_resultset, function('s:filter_resultsets'))
    endif

    if sw#is_visible(sw#sqlwindow#get_resultset_name())
        call sw#goto_window(sw#sqlwindow#get_resultset_name())
        bwipeout
    endif
endfunction

function! sw#sqlwindow#get_count(statement)
    if a:statement =~ '\v^[ \t\s]*[^ \t\s]+[ \t\s]*$'
        let sql = "select count(*) from " . a:statement . ';'
    else
        let sql = "select count(*) from (" . sw#ensure_sql_not_delimited(a:statement, ';') . ") t" . ';'
    endif
    call sw#sqlwindow#execute_sql(sql)
endfunction

function! sw#sqlwindow#refresh_resultset()
    let n = s:get_n_resultset()
    let sql = b:resultsets[n]['sql']
    let channel = b:resultsets[n]['channel']
    let file = ''
    for info in getbufinfo()
        if getbufvar(info['bufnr'], 'sw_channel') == channel
            let file = info['name']
            break
        endif
    endfor
    if file != ''
        let id = b:resultsets[n]['id']
        for resultset in b:resultsets
            if resultset['id'] == id
                let resultset['wait_refresh'] = 1
            endif
        endfor
        call sw#goto_window(file)
        if bufname('%') == sw#sqlwindow#get_resultset_name()
            call sw#display_error("Could not identify the buffer for this resultset")
            return
        endif
        call sw#execute_sql(sql)
    endif
endfunction

function! s:delete_filter(idx, val)
    return a:val['id'] != s:_id
endfunction

function! sw#sqlwindow#delete_resultset()
    let n = s:get_n_resultset()
    let s:_id = b:resultsets[n]['id']
    call filter(b:resultsets, function('s:delete_filter'))
    call s:display_resultsets(1)
endfunction
