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

let s:pattern_resultset_start = '\v^([\-]+\+?)+([\-]*)-$'
let s:pattern_resultset_title = '\v^RESULTSET ([0-9]+)( \()?.*$'
let s:pattern_no_results = '\v^Query returned [0-9]+ rows?$'
let s:pattern_empty_line = '\v^[\r \s\t]*$'
let s:pattern_ignore_line = '\v\c^#IGNORE#$'
let s:script_path = expand('<sfile>:p:h') . '/../../'

function! s:check_sql_buffer()
    if (!exists('b:port'))
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
    call sw#sqlwindow#check_hidden_results()
endfunction

function! sw#sqlwindow#set_results_shortcuts()
    call s:set_shortcuts(g:sw_shortcuts_sql_results, "resources/shortcuts_sql_results.vim")
endfunction

function! s:switch_to_results_tab()
    if !g:sw_switch_to_results_tab
        wincmd t
    endif
endfunction

function! sw#sqlwindow#check_results()
    let results = sw#server#fetch_result()
    if results != ''
        call s:display_resultsets(results, 1)
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
        call sw#sqlwindow#execute_sql(0, sql)
    endif
endfunction

function! s:do_open_buffer(port)
    call sw#session#set_buffer_variable('delimiter', g:sw_delimiter)
    call sw#session#set_buffer_variable('unique_id', sw#generate_unique_id())
    call sw#session#set_buffer_variable('port', a:port)
    ""call sw#session#autocommand('BufEnter', 'sw#sqlwindow#set_statement_shortcuts()')
    call sw#session#autocommand('BufEnter', 'sw#sqlwindow#check_results()')
    ""call sw#session#autocommand('BufUnload', 'sw#sqlwindow#auto_commands("after")')
    call sw#sqlwindow#set_statement_shortcuts()
    call sw#sqlwindow#auto_commands('before')
endfunction

function! sw#sqlwindow#open_buffer(port, file, command)
    execute a:command . " " . a:file
    call sw#session#init_section()
    call sw#session#set_buffer_variable('port', a:port)
    call s:do_open_buffer(a:port)
endfunction

function! sw#sqlwindow#set_delimiter(new_del)
    if (!s:check_sql_buffer())
        return 
    endif
    if exists('b:port')
        sw#display_error('You cannot change the delimier in server mode. This happens because SQL Workbench does now know another delimiter during console mode. You can only change the delimiter in batch mode (see the documentation). So, if you want to change the delimiter, please open the buffer in batch mode.')
        return 
    endif
    call sw#session#set_buffer_variable('delimiter', a:new_del)
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
            return sql
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
    call s:display_resultsets('', 1)
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
    
    ""if (line <= 3 || getline('.') =~ s:pattern_empty_line || getline('.') == '')
    ""    call sw#display_error("You have to be on a row in a resultset")
    ""    return
    ""endif
    if b:state == 'form' || b:state == 'resultsets'
        call s:display_resultsets('', 1)
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
        call s:display_resultsets('', 1)
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
    call uniq(sort(b:resultsets[n].hidden_columns))

    if a:show_results
        call s:display_resultsets('', 1)
    endif
endfunction

function! sw#sqlwindow#unfilter_column(column)
    let n = s:get_n_resultset()
    if n == -1
        return
    endif

    let column = s:get_column(a:column, n)
    unlet b:resultsets[n].filters[column]

    call s:display_resultsets('', 1)
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

        call s:display_resultsets('', 1)
    endif
endfunction

function! sw#sqlwindow#remove_all_filters()
    let n = s:get_n_resultset()
    if n == -1
        return
    endif

    let b:resultsets[n].filters = {}
    call s:display_resultsets('', 1)
endfunction

function! sw#sqlwindow#show_all_columns()
    let n = s:get_n_resultset()
    if (n == -1)
        return
    endif
    let b:resultsets[n].hidden_columns = []
    call s:display_resultsets('', 1)
endfunction

function! sw#sqlwindow#show_only_column(column)
    let n = s:get_n_resultset()
    if (n == -1)
        return
    endif
    for column in b:resultsets[n].header
        if column != a:column
            call sw#sqlwindow#hide_column(column, 0)
        endif
    endfor

    call s:display_resultsets('', 1)
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

    call s:display_resultsets('', 1)
endfunction

function! s:display_as_form()
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
    call writefile(lines, g:sw_tmp . "/row-" . v:servername)
    execute "read " . g:sw_tmp . "/row-" . v:servername
    normal ggdd
    setlocal modifiable
endfunction

function! s:get_resultset_start(...)
    let pattern = s:pattern_resultset_start
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
        if line =~ s:pattern_no_results
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
        if line =~ s:pattern_resultset_start
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
        
        if (line =~ s:pattern_empty_line || line == '')
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
        if !s_below
            set nosplitbelow
        endif
    endif

    call sw#goto_window(name)

    return bufname('%') == name
endfunction

function! s:print_line(line, n_resultset, do_filter)
    let delimiter = a:line =~ s:pattern_resultset_start ? '+' : '|'
    let result = ''
    let columns_length = split(b:resultsets[a:n_resultset].lines[b:resultsets[a:n_resultset].resultset_start], '+')

    if len(columns_length) <= 0
        return a:line
    endif

    let pattern = '\v^'
    for c in columns_length
        let pattern .= '(.{' . len(c) . '}).?'
    endfor
    let pattern .= '$'

    let matches = matchlist(a:line, pattern)
    if (len(matches) == 0)
        return a:line
    endif
    let i = 1
    while i < len(matches)
        if i - 1 < len(columns_length) && a:do_filter
            let column = s:get_column(i - 1, a:n_resultset)
            if has_key(b:resultsets[a:n_resultset].filters, column)
                let filter = b:resultsets[a:n_resultset].filters[column]
                let filter_in = 1
                if filter =~ '\v^[\>\<\=]{1,2}'
                    let filter_in = eval(matches[i] . filter)
                else
                    let filter_in = matches[i] =~ filter
                endif
                if !filter_in
                    return '#IGNORE#'
                endif
            endif
        endif
        if index(b:resultsets[a:n_resultset].hidden_columns, i - 1) == -1
            let result .= matches[i]
            if i - 1 < len(columns_length) - 1
                let result .= delimiter
            endif
        endif

        let i += 1
    endwhile

    if result == ''
        let result = '#IGNORE#'
    endif
    return result
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

function! s:display_resultsets_continous()
    setlocal modifiable
    normal ggdG
    let lines = ''
    let messages = ''
    let n = len(b:resultsets)
    call reverse(b:resultsets)
    for resultset in b:resultsets
        let header = 'RESULTSET ' . string(n)
        let hidden_columns = s:add_hidden_columns(len(b:resultsets) - n)
        if hidden_columns != ''
            let header .= " (Hidden columns: " . hidden_columns . ")"
        endif
        let filters = s:add_filters(len(b:resultsets) - n)
        if (filters != '')
            let header .= " (Filters: " . filters . ")"
        endif
        let header .= "\n============\n"
        let messages .= header
        for line in resultset.messages
            let messages .= line . "\n"
        endfor
        if len(resultset.lines) > 0
            let lines .= header
        endif
        let i = 0
        for line in resultset.lines
            let row = s:print_line(line, len(b:resultsets) - n, i > resultset.resultset_start)
            if !(row =~ s:pattern_ignore_line)
                let lines .= row . "\n"
            endif
            let i += 1
        endfor
        let n = n - 1
    endfor
    call reverse(b:resultsets)
    let a_lines = []
    if (b:state == 'messages')
        let a_lines = split(messages, "\n")
    elseif b:state == 'resultsets' && lines != ''
        let a_lines = split(lines, "\n")
    endif
    if len(a_lines) > 0
        call writefile(a_lines, g:sw_tmp . "/results-" . v:servername)
        execute "read " . g:sw_tmp . "/results-" . v:servername
    endif
    normal ggdd
    setlocal nomodifiable
endfunction

function! s:display_resultsets(result, ...)
    if (!s:open_resultset_window())
        call sw#display_error('Result set cannot be selected. Probably is hidden')
        return
    endif
    call s:process_result(a:result)
    let continous = 0
    if a:0
        let continous = a:1
    endif
    if b:state == 'form'
        call s:display_as_form()
    elseif continous
        call s:display_resultsets_continous()
    else
        call s:display_resultsets_separate()
    endif

    if (exists('b:position') && b:state == 'resultsets')
        call setpos('.', b:position)
    endif
endfunction

function! s:process_result(result)
    if a:result == ''
        return
    endif
    let result = split(a:result, "\n")

    if !exists('b:resultsets')
        call sw#session#set_buffer_variable('resultsets', [])
    endif

    let i = 0
    let mode = 'message'
    let pattern = '\v\c^[\=]+$'
    call add(b:resultsets, {'messages': [], 'lines': [], 'hidden_columns': [], 'resultset_start': 0, 'header': [], 'filters': {}})
    let n = len(b:resultsets) - 1
    while i < len(result)
        if result[i] =~ pattern
            let mode = 'resultset'
        endif
        
        if (mode == 'resultset' && (result[i] =~ s:pattern_empty_line || result[i] == ''))
            let mode = 'message'
            call add(b:resultsets[n].lines, '')
        endif
        if (mode == 'resultset' && !(result[i] =~ pattern))
            call add(b:resultsets[n].lines, result[i])
        elseif mode == 'message'
            call add(b:resultsets[n].messages, substitute(result[i], "\r", '', 'g'))
        endif
        if mode == 'resultset' && result[i] =~ s:pattern_resultset_start
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

    call sw#session#set_buffer_variable('state', len(b:resultsets[n].lines) > 0 ? 'resultsets' : 'messages')
    echomsg "Command completed"
endfunction

function! sw#sqlwindow#execute_sql(wait_result, sql)
    let w:auto_added1 = "-- auto\n"
    let w:auto_added2 = "-- end auto\n"

    if (!s:check_sql_buffer())
        return 
    endif
    let _sql = a:sql
    if !exists('b:no_variables') && g:sw_use_old_sw
        let vars = sw#variables#extract(_sql)
        if len(vars) > 0
            for var in vars
                let value = sw#variables#get(var)
                if value != ''
                    let _sql = w:auto_added1 . 'wbvardef ' . var . ' = ' . value . "\n" . b:delimiter . "\n" . w:auto_added2 . _sql
                endif
            endfor
            let _sql = substitute(_sql, g:parameters_pattern, g:sw_p_prefix . '\1' . g:sw_p_suffix, 'g')
        endif
    endif
    let b:on_async_result = 'sw#sqlwindow#check_results'
    echomsg "Processing a command. Please wait..."
    let result = sw#execute_sql(_sql, a:wait_result)

    if result != ''
        call s:display_resultsets(result, 1)
        call s:switch_to_results_tab()
    endif
endfunction

function! sw#sqlwindow#get_object_info()
    if (!exists('b:port'))
        return
    endif

    let obj = expand('<cword>')
    let sql = "desc " . obj
    call sw#sqlwindow#execute_sql(0, sql)
endfunction

function! sw#sqlwindow#get_resultset_name()
    return '__SQLResult__'
endfunction

function! sw#sqlwindow#close_all_result_sets()
    if bufname('%') =~ '\v__SQLResult__'
        return
    endif
    if exists('g:sw_session')
        let name = bufname('%')
        let rs_name = sw#sqlwindow#get_resultset_name()
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
        let name = sw#sqlwindow#get_resultset_name()
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
                    call sw#set_special_buffer()
                    call sw#sqlwindow#set_results_shortcuts()
                    ""call sw#session#autocommand('BufEnter', 'sw#sqlwindow#set_results_shortcuts()')
                    setlocal modifiable
                    if !s_below
                        set nosplitbelow
                    endif
                    if b:state == 'messages'
                        for line in b:messages
                            put =line
                        endfor
                    else
                        call s:display_resultsets('', 1)
                    endif
                    normal ggdd
                    setlocal nomodifiable
                endif
            endif
        endif
    endif
endfunction

function! sw#sqlwindow#get_object_source()
    if (!exists('b:port'))
        return
    endif

    let obj = expand('<cword>')
    let sql = 'WbGrepSource -searchValues="' . obj . '" -objects=' . obj . ' -types=* -useRegex=true;'
    call sw#sqlwindow#execute_sql(0, sql)
endfunction
