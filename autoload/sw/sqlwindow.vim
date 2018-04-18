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
let s:script_path = sw#script_path()
let g:sw_last_resultset = []
let s:pattern_columns_doubled = '\(([^\)]+)\)$'

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
        keepalt wincmd t
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
    let name = sw#bufname(expand('<afile>'))
    let channel = getbufvar(name, 'sw_channel')
    call sw#server#disconnect_buffer(channel)
endfunction

function! s:do_open_buffer()
    call sw#session#autocommand('BufDelete', 'sw#sqlwindow#auto_disconnect_buffer()')
    call sw#session#autocommand('BufEnter', 'sw#sqlwindow#check_results()')
    call sw#session#autocommand('BufEnter', 'sw#autocomplete#set()')
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

function! s:get_delimiter(use_alternate)
    let delimiter = b:delimiter
    if (a:use_alternate)
        let buf_profile = sw#server#get_buffer_profile(sw#bufname('%'))
        let profiles = sw#cache_get('profiles')
        if has_key(profiles, buf_profile) && has_key(profiles[buf_profile], 'props') && has_key(profiles[buf_profile]['props'], 'alt_delimiter')
            let delimiter = profiles[buf_profile]['props']['alt_delimiter']
        endif
    endif

    return delimiter
endfunction

" Possible arguments:
" a:1 If true, then do not replace the #CURSOR# part in the returning sql
" a:2 If true, then use the alternate delimiter
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
    let delimiter = s:get_delimiter(a:0 > 1 && a:2)
    let sqls = sw#sql_split(s, delimiter)
    for sql in sqls
        if sql =~ '#CURSOR#'
            if (!a:0 || (a:0 && !a:1))
                let sql = substitute(sql, '#CURSOR#', '', 'g')
            endif
            if delimiter == '/'
                let delimiter = "\n/\n"
            endif
            return sql . delimiter
        endif
    endfor
    call sw#display_error("Could not identify the current query")
    return ""
endfunction

" Possible arguments:
" a:1 If true, then use the alternate delimiter
function! sw#sqlwindow#extract_selected_sql(...)
    let use_alternate = a:0 && a:1
    let z_save = @z
    normal gv"zy
    let sql = @z
    let @z = z_save
    let delimiter = s:get_delimiter(use_alternate)
    if !(substitute(sql, '\v[\r\n]', '', 'g') =~ '\v' . delimiter . '[\n\r]*$')
        let sql .= delimiter
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
    if sw#bufname('%') != sw#sqlwindow#get_resultset_name()
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

        if b:state == 'resultsets' && exists('b:position')
            call setpos('.', b:position)
            normal zMza
        endif
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
    ""let n = s:get_n_resultset()
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

function! sw#sqlwindow#show_column(idx)
    let n = s:get_n_resultset()
    if (n == -1)
        return
    endif

    let a_idx = s:get_idx(a:idx, n)

    let idx = index(b:resultsets[n].hidden_columns, a_idx)
    if idx != -1
        call remove(b:resultsets[n].hidden_columns, idx)
    endif

    call sw#sqlwindow#refresh_resultset()
endfunction

function! sw#sqlwindow#hide_column(idx, do_display)
    let n = s:get_n_resultset()
    if (n == -1)
        return
    endif
    
    let idx = s:get_idx(a:idx, n)

    let n_columns = len(b:resultsets[n].header)
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

    if a:do_display
        call sw#sqlwindow#refresh_resultset()
    endif
endfunction

function! s:select_option(values, prompt, not_found_msg)
    let values = [a:prompt]
    let x = 1
    for v in a:values
        call add(values, x . '. ' . v)
        let x += 1
    endfor

    if len(values) == 1
        call sw#display_error(a:not_found_msg)
        return ""
    endif

    if len(values) > 2
        let idx = 0
        while idx < 1 || idx >= len(values)
            let idx = inputlist(values)
        endwhile
    endif

    if len(values) == 2
        let idx = 1
    endif

    let pattern = '\v^[0-9]+\. (.*)$'
    return substitute(values[idx], pattern, '\1', 'g')
endfunction

function! sw#sqlwindow#go_to_ref(cmd, ...)
    let rel = a:0 ? a:1 : ''
    let pattern = '\v^([^\(]+)\(([^\)]+)\)\=([^\(]+)\(([^\)]+)\)$'
    if rel == ''
        let rel = s:select_option(sw#sqlwindow#complete_refs('', a:cmd, 0), 'Please select a reference', 'There were no references for the given select')
        if !(rel =~ pattern)
            return
        endif
    endif
    if !(rel =~ pattern)
        call sw#display_error("The reference is not in the correct format: tbl(column)=dest_tbl(column)")
        return 
    endif

    let n = s:get_n_resultset()
    if n == -1
        return
    endif

    let b = sw#get_buffer_from_resultset(b:resultsets[n].channel)

    if !has_key(b, 'bufnr')
        call sw#display_error("Could not get the corresponding buffer of this resultset")
        return
    endif
    
    let profile = sw#server#get_buffer_profile(sw#bufname(b.bufnr))
    let table = substitute(rel, pattern, '\1', 'g')
    let source_column = substitute(rel, pattern, '\2', 'g')

    let new_sql = sw#report#get_references_sql(profile, table, source_column)
    if new_sql == ''
        call sw#display_error("Could not build the sql")
        return 
    endif
    let column = s:get_column(substitute(rel, pattern, '\4', 'g'), n)
    if !has_key(b:resultsets[n], 'columns')
        let b:resultsets[n].columns = s:split_into_columns(b:resultsets[n])
    endif
    let col_idx = index(map(b:resultsets[n].header, 'tolower(substitute(v:val, ''\v\c^(.*)\([^\)]+\)$'', ''\1'', ''g''))'), tolower(column))
    if col_idx == -1
        call sw#display_error("Could not identify the source column in the resultset. Probably your result set does not include the foreign key. If you want to follow a reference, you need to include in the sql the foreign key.")
        return 
    endif
    let resultset_start = s:get_resultset_start()
    let line = line('.') - resultset_start - 1
    let value = sw#trim(b:resultsets[n].columns[line + 2][col_idx + 1])
    let new_sql = substitute(new_sql, '#value#', value, 'g')
    let b = sw#get_buffer_from_resultset(b:resultsets[n].channel)
    if has_key(b, 'name')
        let file = b.name
    endif
    call s:execute_sql_from_resultset(b:resultsets[n], s:add_title_to_sql(new_sql . ';'))
endfunction

function! s:do_search(arr, pattern)
    for i in range(len(a:arr))
        if a:arr[i] =~ a:pattern
            return i
        endif
    endfor

    return -1
endfunction

function! sw#sqlwindow#find_cursor(insert_parts, search)
    let pattern = '\c' . a:search
    let idx = s:do_search(a:insert_parts.fields, pattern)
    if idx != -1
        return 'f' . idx
    endif
    let idx = s:do_search(a:insert_parts.values, pattern)
    if idx != -1
        return 'v' . idx
    endif

    for which in ['strings', 'expressions', 'subqueries']
        for el in a:insert_parts[which]
            let key = keys(el)[0]
            " The keys for strings are not in the format '#m<n>#'
            let _key = !(key =~ '\v\c^#[a-z0-9]+#$') ? '#' . key . '#' : key
            if el[key] =~ pattern
                return sw#sqlwindow#find_cursor(a:insert_parts, _key)
            endif
        endfor
    endfor

    return ''
endfunction

function! sw#sqlwindow#remove_all_filters()
    let n = s:get_n_resultset()
    if n == -1
        return
    endif

    let b:resultsets[n].where = ""
    call sw#sqlwindow#refresh_resultset()
endfunction

function! sw#sqlwindow#show_all_columns()
    let n = s:get_n_resultset()
    if (n == -1)
        return
    endif
    let b:resultsets[n].hidden_columns = []
    call sw#sqlwindow#refresh_resultset()
endfunction

function! s:get_complete_result(values, a)
    let result = []

    for v in a:values
        if v =~ '^' . a:a
            call add(result, v)
        endif
    endfor

    return result
endfunction

function! s:get_from_part(sql)
    let sql = substitute(s:eliminate_comments(a:sql), '\v[\r\n]', ' ', 'g')

    return substitute(sql, '\v\c^[ ]*select(.{-})\sfrom\s.*$', '\1', 'g')
endfunction

function! s:add_complete_field(table, idx)
    let field = a:table.fields[a:idx]
    let name = has_key(a:table, 'alias') ? a:table.alias : a:table.table
    unlet a:table.fields[a:idx]
    return field . '(' . name . ')'
endfunction

" Param: r The resultset
function! s:separate_columns(r)
    let counts = {}
    let tables = copy(sw#autocomplete#get_tables(a:r.sql_original, []))

    for table in tables
        for field in table.fields
            if !has_key(counts, field)
                let counts[field] = 0
            endif

            let counts[field] += 1
        endfor
    endfor

    for table in tables
        let table.fields = copy(table.fields)
    endfor
    let result = []
    let from_part = s:get_from_part(a:r.sql_original)
    let identifiers = split(from_part, '\v[ \t,]')

    for column in a:r.header
        if !has_key(counts, column)
            continue
        endif
        if counts[column] == 1
            call add(result, column)
            continue
        endif

        if from_part =~ '\v^[ ]*\*[ ]*$'
            for table in tables
                let idx = index(table.fields, column)
                if idx != -1
                    call add(result, s:add_complete_field(table, idx))
                    break
                endif
            endfor
        else
            let processed = 0
            for id in identifiers
                if id == ''
                    continue
                endif
                let pattern = '\v^([^\.]+)\.(.*)$'
                let tbl = substitute(id, pattern, '\1', 'g')
                let fld = substitute(id, pattern, '\2', 'g')

                if fld != column && fld != '*'
                    continue
                endif

                for table in tables
                    if (has_key(table, 'alias') && table.alias != tbl) && table.table != tbl
                        continue
                    endif
                    let idx = index(table.fields, column)
                    if idx != -1
                        call add(result, s:add_complete_field(table, idx))
                        let processed = 1
                        break
                    endif
                endfor

                if processed
                    break
                endif
            endfor
        endif
    endfor

    return result
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

function! sw#sqlwindow#complete_refs(a, cmd, pos)
    let n = s:get_n_resultset()
    if n == -1
        return []
    endif

    let sql = b:resultsets[n].sql_original

    " We try to see the complete options (references or referenced by)
    let b = sw#get_buffer_from_resultset(b:resultsets[n].channel)

    if has_key(b, 'bufnr')
        let tables = sw#autocomplete#get_tables(sql, [], b.name)
        " We check all available tables in the given query
        let available_tables = []
        for table in tables
            call add(available_tables, table.table)
        endfor

        " We check to see if we have a referenced or referenced by
        let pattern = '\v^SWSql[^ ]*(References|ReferencedBy).*$'
        let which = substitute(a:cmd, pattern, '\1', 'g')

        " Since we are in the result set, we find the profile in the 
        " buffer where the sql has been executed
        let profile = sw#server#get_buffer_profile(sw#bufname(b.bufnr))

        let result = []
        " For each available table
        for table in available_tables
            " We get the references or tables referencing in the current query
            let ref = which == 'References' ? sw#report#get_references(profile, table, 1) : sw#report#get_referenced_by(profile, table, 1)
            let key = which == 'References' ? 'references' : 'ref-by'

            " And for each reference, we check the source and referenced
            " columns
            if !has_key(ref, table)
                continue
            endif
            for k in keys(ref[table][key])
                let r = ref[table][key][k]
                " If we have a references, then we want source-column = ref-column
                " Otherwise, we want ref-column = source-column
                let link = k . '(' . r['referenced-columns'] . ')=' . table . '(' . r['source-columns'] . ')'
                " If it's a complex query, we want to avoid dupplicates
                if index(result, link) == -1
                    call add(result, link)
                endif
            endfor
        endfor

        " Filter the results (maybe we already have a query)
        return s:get_complete_result(result, a:a)
    endif

    return []
endfunction

function! sw#sqlwindow#show_only_columns(columns)
    let n = s:get_n_resultset()
    if n == -1
        return
    endif

    let b:resultsets[n].hidden_columns = []

    for column in b:resultsets[n].header
        if index(a:columns, column) == -1
            call sw#sqlwindow#hide_column(column, 0)
        endif
    endfor

    call s:display_resultsets(1)

    let b:resultsets[n].visible_columns = a:columns
    call sw#sqlwindow#refresh_resultset()
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
        execute "autocmd! BufLeave " . sw#bufname('%') . " let b:position = getcurpos()"
        if !s_below
            set nosplitbelow
        endif
        let b:sw_is_resultset = 1
    endif

    call sw#goto_window(name)

    return sw#bufname('%') == name
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

function! s:print_line(line_idx, n_resultset)
    let resultset = b:resultsets[a:n_resultset]
    let pattern_empty_line = '\v^[ \t\s\|\:]*$'

    let line = resultset.lines[a:line_idx]

    if a:line_idx <= resultset.resultset_start - 2
        return line
    endif

    let delimiter = line =~ sw#get_pattern('pattern_resultset_start') ? '+' : '|'
    let result = ''

    if len(resultset.hidden_columns) > 0
        if !exists('resultset.columns')
            let resultset.columns = s:split_into_columns(resultset)
        endif
    endif

    return line
endfunction

function! s:add_hidden_columns(n)
    let result = ''
    for c in b:resultsets[a:n].hidden_columns
        let result .= (result == '' ? '' : ', ') .  b:resultsets[a:n].header[c]
    endfor

    return result
endfunction

function! s:add_filters(n)
    return b:resultsets[a:n].where
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
    if filters != ''
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
                let row = s:print_line(i, len(b:resultsets) - n)
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
    let result = {'messages': [], 'lines': [], 'hidden_columns': [], 'resultset_start': 0, 'header': [], 'filters': {}, 'title': '', 'rows': 0, 'channel': a:channel, 'sql': query, 'id': a:id, 'wait_refresh': 0, 'sql_original': query, 'where': ''}
    if n == len(b:resultsets)
        call add(b:resultsets, result)
        let s:new_resultset = 1
    else
        " Preserve the sql_original and the where values
        let result.sql_original = b:resultsets[n].sql_original
        let result.where = b:resultsets[n].where
        let result.hidden_columns = b:resultsets[n].hidden_columns
        let result.header = b:resultsets[n].header
        let s:new_resultset = 0
        let b:resultsets[n] = result
    endif

    return n
endfunction

function! s:get_next_resultset()
    for i in range(len(b:resultsets))
        if b:resultsets[i]['wait_refresh'] && (b:resultsets[i]['sql'] == g:sw_last_sql_query || b:resultsets[i]['sql_original'] == g:sw_last_sql_query)
            let b:resultsets[i].wait_refresh = 0
            return i
        endif
    endfor

    return len(b:resultsets)
endfunction

" Returns true if the current result set is the resonse of a desc command
function! s:describing(lines, i)
    return a:i >= 1 && a:lines[a:i - 1] =~ sw#get_pattern('pattern_desc_titles')
endfunction

function! s:is_empty_line(lines, i)
    return (a:i < len(a:lines) - 1 ? !(a:lines[a:i + 1] =~ sw#get_pattern('pattern_desc_titles')) : 1) && (a:lines[a:i] =~ sw#get_pattern('pattern_empty_line') || a:lines[a:i] == '')
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
        if i + 1 < len(lines) && lines[i + 1] =~ sw#get_pattern('pattern_resultset_start') && !s:describing(lines, i)
            "" If we have more than one resultset in a go.
            if len(b:resultsets[n].lines) > 0
                let n = s:add_new_resultset(a:channel, resultset_id)
            endif
            let mode = 'resultset'
            let b:resultsets[n].resultset_start = len(b:resultsets[n].lines)
        endif

        let pattern_title = '\v^----  ?(.*)$'
        if lines[i] =~ pattern_title && !(lines[i] =~ sw#get_pattern('pattern_desc_titles'))
            let b:resultsets[n].title = substitute(lines[i], pattern_title, '\1', 'g')
            let i += 1
            continue
        endif
        if mode == 'resultset' && (s:is_empty_line(lines, i) || lines[i] =~ sw#get_pattern('pattern_exec_time') || lines[i] =~ sw#get_pattern('pattern_no_results'))
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

    if len(b:resultsets[n].lines) > 0 && s:new_resultset
        let header = split(b:resultsets[n].lines[b:resultsets[n].resultset_start - 1], '|')
        for h in header
            call add(b:resultsets[n].header, substitute(h, '\v^[ ]*([^ ].*[^ ])[ ]*$', '\1', 'g'))
        endfor

        " Separates the identical columns by adding at the end of the column
        " the name of table or subquery from where the column is extracted
        let b:resultsets[n].header = s:separate_columns(b:resultsets[n])
    endif

    let g:sw_last_resultset = b:resultsets

    call sw#session#set_buffer_variable('state', len(b:resultsets[n].lines) > 0 ? 'resultsets' : 'messages')
    echomsg "Command completed"
endfunction

function! s:do_execute_sql(sql)
    echomsg "Processing a command. Please wait..."
    call sw#execute_sql(a:sql)
endfunction

function! s:add_title_to_sql(sql)
    if g:sw_sql_name_result_tab != 1
        return a:sql
    endif
    let _sql = a:sql
    let title = substitute(a:sql, '\v[\n\r]', ' ', 'g')
    if strlen(title) > 255
        let title = title[:255] . '...'
    endif
    return '-- @wbresult ' . title . "\n" . _sql
endfunction

function! sw#sqlwindow#execute_sql(sql)
    let macros = sw#cache_get('macros')
    if string(macros) != '{}' && has_key(macros, substitute(a:sql, '\v[\r\n;]', '\1', 'g'))
        call sw#sqlwindow#execute_macro(a:sql)
        return
    endif
    let w:auto_added1 = "-- auto\n"
    let w:auto_added2 = "-- end auto\n"

    if (!s:check_sql_buffer())
        return 
    endif
    let _sql = s:add_title_to_sql(a:sql)

    call s:do_execute_sql(_sql)
endfunction

function! sw#sqlwindow#execute_macro(macro)
    let sql = g:sw_prefer_sql_over_macro ? sw#sqlwindow#get_macro_sql(substitute(a:macro, '\v[\n\r;]', '', 'g')) : a:macro
    if sql == '' || !sw#autocomplete#is_select(sql)
        let sql = a:macro
    endif
    if sql != a:macro
        let sql = substitute(s:add_title_to_sql(sql), '[ ;\n\t\r\s]*$', ';', 'g')
    endif
    call s:do_execute_sql(sql)
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
            let id = win_getid()
            call sw#goto_window(name)
            if (exists('b:current_channel') && b:current_channel != channel) || !exists('b:current_channel')
                let b:current_channel = channel
                call s:display_resultsets(1)
            endif
            call win_gotoid(id)
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
    if getline(a:lnum) =~ s:pattern_resultset_title || getline(a:lnum) =~ sw#get_pattern('pattern_desc_titles')
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
    let log_name = "__LOG__" . fnamemodify(sw#bufname('%'), ':t')
    call sw#goto_window(log_name)

    if sw#bufname('%') != log_name
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

function! s:execute_sql_from_resultset(resultset, sql)
    let file = ''
    let b = sw#get_buffer_from_resultset(a:resultset.channel)
    if has_key(b, 'name')
        let file = b.name
    endif
    if file != ''
        call sw#goto_window(file)
        if sw#bufname('%') == sw#sqlwindow#get_resultset_name()
            call sw#display_error("Could not identify the buffer for this resultset")
            return
        endif
        call sw#execute_sql(a:sql)
    endif
endfunction

" Gets the columns part for an sql, considering the doubled columns. 
" This means the the columns which appear 2 times in the resultset, will
" be returnes as table.c as c__table (if full param is true)
" or as c__table if full param is false
function! s:get_columns_as_string(columns, full)
    let pattern = s:pattern_columns_doubled
    return join(map(copy(a:columns), "substitute(v:val, '\\v^(.{-})' . pattern, (a:full ? '\\2.\\1 as ' : '') . '\\1__\\2', 'g')"), ', ')
endfunction

" Returns the original sql expanding the * in the from part if
" necessary (if in the resultset we have fields with the same name)
function! s:get_original_sql(r)
    let columns = a:r.header
    let pattern = s:pattern_columns_doubled
    if len(filter(copy(columns), "v:val =~ '\\v' . pattern")) == 0
        return a:r.sql_original
    endif

    let fields_part = s:get_columns_as_string(columns, 1)
    let from_part = s:get_from_part(a:r.sql_original)

    return substitute(a:r.sql_original, '\V' . from_part, ' ' . fields_part, 'g')
endfunction

" In the string s (which can be the where from a filter or the columns
" part from a show only columns), we replace the '(tbl)' part with
" '__tbl'
function! s:identify_columns(s, alias)
    return substitute(a:s, '\v([^ \s\t]+)\(([^\)]+)\)', '\1__\2' . (a:alias ? ' \1' : ''), 'g')
endfunction

function! sw#sqlwindow#refresh_resultset()
    let n = s:get_n_resultset()
    let r = b:resultsets[n]
    let sql = r.where == '' && len(r.hidden_columns) == 0 ? r['sql_original'] : s:get_original_sql(r)
    if r['where'] != ''
        let sql = "select * from (" . s:eliminate_comments(sql) . ") subquery where " . s:identify_columns(r.where, 0) . ';'
    endif
    if len(r.hidden_columns) > 0
        let columns = join(filter(copy(r.header), 'index(r.hidden_columns, v:key) == -1'), ', ')
        let columns = s:identify_columns(columns, 1)
        let sql = r.where != '' ?
                    \ substitute(sql, '\v^select \*', 'select ' . columns, '') :
                    \ 'select ' . columns . ' from (' . s:eliminate_comments(sql) . ') subquery;'
    endif
    let r.sql = sql
    let id = r['id']
    for resultset in b:resultsets
        if resultset['id'] == id
            let resultset['wait_refresh'] = 1
        endif
    endfor
    call s:execute_sql_from_resultset(r, sql)
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

function! sw#sqlwindow#connect_buffer(...)
    let file = sw#bufname('%')
    let command = 'e'
    if (a:0 >= 2)
        let file = a:2
        let command = a:1
    elseif a:0 >= 1
        let command = a:1
    endif

    let pattern = '\v^__([0-9]+)__$'
    if file =~ pattern
        let nr = substitute(file, pattern, '\1', 'g')
        execute "buffer " . nr
    else
        execute command . " " . file
    endif
    call sw#session#init_section()

    if exists('b:autocomplete_tables')
        unlet b:autocomplete_tables
    endif

    if (!exists('b:sw_channel'))
        let b:sw_channel = sw#server#start_sqlwb('sw#sqlwindow#message_handler')
    endif

    call sw#sqlwindow#open_buffer(file, command)
endfunction

function! sw#sqlwindow#share_connection(buffer)
    call sw#server#share_connection(a:buffer)
    call sw#sqlwindow#open_buffer(sw#bufname('%'), 'e')
endfunction

function! s:translate_part(input_parts, current)
    let s = a:current
    let pattern = '\v#(m|sq|val)([0-9]+)#'
    while s =~ pattern
        let matches = matchlist(s, pattern, '')
        let key = (matches[1] == 'sq' ? 'subqueries' : (matches[1] == 'm' ? 'strings' : 'expressions'))
        for values in a:input_parts[key]
            " Due to inconstitencies, the key for the strings is missing the
            " #. So, we need to add it but only for comparisons
            " TODO: fix this (all the keys returnes by 
            " sw#autocomplete#get_insert_parts() should be consistent)
            let key = keys(values)[0]
            if key == matches[0] || '#' . key . '#' == matches[0]
                try
                    let value = values[matches[0]]
                catch
                    let value = values[key]
                endtry
                if matches[1] == 'sq' || matches[1] == 'val'
                    let value = '(' . value . ')'
                endif
                let s = s:translate_part(a:input_parts, substitute(s, '\v' . matches[0], value, 'g'))
                break
            endif
        endfor
    endwhile

    return s
endfunction

function! s:display_match_result(timer)
    echomsg "Match in insert: " . s:match_result
endfunction

function! sw#sqlwindow#match()
    " Get the input parts
    let input_parts = sw#autocomplete#get_insert_parts(sw#sqlwindow#extract_current_sql(1))
    if string(input_parts) == '{}'
        call sw#display_error('You have to set the cursor in the values part, or in the fields part')
        retur
    endif
    let where = sw#sqlwindow#find_cursor(input_parts, '#cursor#')
    if where == ''
        call sw#display_error('Could not identify the parts in the insert')
        return
    endif
    let pattern = '\v\c^(f|v)([0-9]+)$'

    " If we found that we are in the fields part, check the values parts
    " and the other way around
    let key = substitute(where, pattern, '\1', 'g') == 'f' ? 'values' : 'fields'
    let idx = substitute(where, pattern, '\2', 'g')

    if len(input_parts[key]) <= idx
        call sw#display_error('There is no corresponding value')
        return
    endif

    let result = s:translate_part(input_parts, input_parts[key][idx])
    let @/ = '\V' . substitute(result, ' ', '\\_.', 'g')
    let s:match_result = result
    let Func = function('s:display_match_result')
    call timer_start(0, Func)
endfunction

function! sw#sqlwindow#complete_insert(arg, cmd, pos)
    let parts = split(a:cmd, '\v[ \t]+')
    if a:cmd =~ '\v $'
        call add(parts, '')
    endif
    if len(parts) <= 2
        let base = len(parts) == 1 ? '' : parts[1]
        let objects = filter(sw#autocomplete#all_objects(base), 'v:val["menu"] == "T"')
    else
        let tbl = parts[1]
        let objects = sw#autocomplete#table_fields(tbl, parts[len(parts) - 1])
    endif
    return map(objects, 'v:val["word"]')
endfunction

function! sw#sqlwindow#generate_insert(args, exec)
    let profile = sw#server#get_buffer_profile(sw#bufname('%'))
    if profile == ''
        call sw#display_error('You are not in an sql buffer')
        return 
    endif
    let tbl = a:args[0]
    if len(a:args) == 1
        let fields = map(sw#autocomplete#table_fields(tbl, ''), 'v:val["word"]')
    else
        let fields = filter(a:args, 'v:key > 0')
    endif
    let sql = "insert into " . tbl . "(" . join(fields, ', ') . ") values"

    let table = sw#report#get_table_info(profile, tbl)
    if string(table) == "{}"
        call sw#display_error("Table not found: " . tbl)
        return 
    endif
    let values = ''

    for field in fields
        if !has_key(table['columns'], field)
            call sw#display_error(field . " does not exists in " . tbl . ' table')
            return
        endif
        let quote = sw#report#is_string(table['columns'][field]['type']) ? "'" : ''
        let values .= (values == '' ? '' : ', ') . quote . '$[?' . field . ']' . quote
    endfor

    let sql .= '(' . values . ')'

    call sw#to_clipboard(sql)

    if a:exec
        call sw#sqlwindow#execute_sql(sql . ';')
    endif

    let and_executed = a:exec ? ' and executed' : ''

    echomsg "The following sql was saved to the clipboard" . and_executed . ":"
    echomsg sql
endfunction

function! sw#sqlwindow#get_macro_sql(macro)
    let macros = sw#cache_get('macros')
    if string(macros) == "{}" || !has_key(macros, a:macro)
        return ''
    endif

    return substitute(macros[a:macro]['sql'], '#NEWLINE#', '\n', 'g')
endfunction

function! s:eliminate_comments(sql)
    let sql = substitute(a:sql, '\v;[ \n\r\t]*$', '', 'g')
    let sql = substitute(sql, '\v[ \t]*--[^\n\r]*', '', 'g')
    let sql = substitute(sql, '\v\/\*\_.{-}\*\/', '', 'g')

    return sql
endfunction

function! sw#sqlwindow#filter_with_sql(where_part)
    let n = s:get_n_resultset()
    if n == -1
        call sw#display_error('Could not identify the result set to filter')
        return
    endif

    let b:resultsets[n].where = a:where_part

    ""let sql = s:eliminate_comments(b:resultsets[n].sql)
    ""let new_sql = "select * from (" . sql . ") subquery where " . a:where_part
    ""call s:execute_sql_from_resultset(b:resultsets[n], s:add_title_to_sql(new_sql . ';'))

    call sw#sqlwindow#refresh_resultset()
endfunction

function! s:include(file, delimiter)
    let sql = 'wbinclude -delimiter="' . a:delimiter . '" -file="' . a:file . '"' . ';'
    call sw#sqlwindow#execute_sql(sql)
endfunction

function! sw#sqlwindow#include(alt_delimiter, ...)
    let delimiter = s:get_delimiter(a:alt_delimiter)
    let file = a:0 ? a:1 : sw#bufname('%')
    call s:include(file, delimiter)
endfunction
