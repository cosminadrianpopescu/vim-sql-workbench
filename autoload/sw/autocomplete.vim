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

let s:_pattern_identifier = '((\a|_|[0-9])+|#sq[0-9]+#)'
let s:pattern_identifier = '\v' . s:_pattern_identifier
let s:pattern_identifier_split = '\v[, \t]'
let s:pattern_reserved_word = '\v\c<(inner|outer|right|left|join|as|using|where|group|order|and|or|not|on)>'
let s:pattern_subquery = '\v#sq([0-9]+)#'
let s:pattern_expressions = '\v\c\(([\s\t ]*select)@![^\(\)]{-}\)'
let s:script_path = sw#script_path()

function! sw#autocomplete#sort(e1, e2)
    if a:e1.menu == '*'
        return -1
    endif
    if a:e2.menu == '*'
        return 1
    endif
    return a:e1.word == a:e2.word ? 0 : a:e1.word > a:e2.word ? 1 : -1
endfunction

function! sw#autocomplete#table_fields(tbl, base, ...)
    let get_info = a:0 ? a:1 : 0
    let profile = get_info ? sw#server#get_buffer_profile(sw#bufname('%')) : ''
    let result = []
    let fields = s:get_cache_data_fields(a:tbl)
    if len(fields) > 0
        for field in fields
            if field =~ '^' . a:base
                let menu = a:tbl . '.'
                if get_info
                    let info = sw#report#get_field_info(profile, a:tbl, field)
                    if string(info) != "{}"
                        let menu = info['dbms-type'] . (!info['nullable'] ? ' (+)' : '')
                    endif
                endif
                call add(result, {'word': field, 'menu': menu})
            endif
        endfor
    endif
    return sort(result, "sw#autocomplete#sort")
endfunction

function! sw#autocomplete#extract_current_sql()
    let sql = sw#sqlwindow#extract_current_sql(1)
    let sql = sw#eliminate_sql_comments(sql)
    let _sql = substitute(sql, s:pattern_expressions, '#values#', 'g')
    " Check to see that we are not in a subquery
    let pattern = '\v\c(\([ \t\s]*select[^\(]*#cursor#).*\)'
    if _sql =~ pattern
        " If we are in a subquery, search where it begins.
        let sql = substitute(sw#get_sql_canonical(sql)[0], '#NEWLINE#', ' ', 'g')
        let start = stridx(tolower(sql), '#cursor#')
        let s = ''
        let paren = 0
        let pattern = '\v\c^select[ \s\t]+.*$'
        while start >= 0
            let start -= 1
            let c = sql[start]
            if c == ')'
                let paren += 1
            endif
            if c == '('
                let paren -= 1
            endif
            let s = c . s
            if s =~ pattern && paren == 0
                break
            endif
        endwhile
        if start >= 0
            " Get the start and end of the subquery
            let end = start + 1
            let p = 1
            while end < strlen(sql) && p > 0
                if sql[end] == ')'
                    let p = p -1
                endif
                if sql[end] == '('
                    let p = p + 1
                endif
                let end = end + 1
            endwhile

            let end = end - 2

            let cmd = "let _sql = sql[" . start . ":" . end . "]"
            execute cmd
            " And return the tables of the subquery. 
            return _sql
        endif
    endif

	""let sql = s:eliminate_sql_comments(sql)

    if sql =~ '\v\c<union>'
        let sqls = split(sql, '\v\c<union[\s \t]*(all)?>')
        for _sql in sqls
            if _sql =~ '\v\c#cursor#'
                return _sql
            endif
        endfor
    endif

    return sql
endfunction

function! s:execute_file(f)
	let lines = readfile(a:f)
	for line in lines
		let line = substitute(line, '\v\r', '', 'g')
		if line != ''
			execute line
		endif
	endfor
endfunction

function! s:set_default()
    let g:sw_autocomplete_default_tables = b:autocomplete_tables
    let g:sw_autocomplete_default_procs = b:autocomplete_procs
    let g:Str_sw_autocomplete_default_tables = string(g:sw_autocomplete_default_tables)
    let g:Str_sw_autocomplete_default_procs = string(g:sw_autocomplete_default_procs)
endfunction

function! s:deprecated(name, alternative)
    echomsg "Please note that " . a:name . " is deprecated"
    echomsg a:alternative
endfunction

function! sw#autocomplete#remove_table_from_cache(tbl)
    if exists('b:autocomplete_tables')
        for key in keys(b:autocomplete_tables)
            if tolower(key) =~ '\v\c^(v|t)#' . a:tbl
                unlet b:autocomplete_tables[key]
                break
            endif
        endfor
        call sw#session#set_buffer_variable('autocomplete_tables', b:autocomplete_tables)
    endif
endfunction

function! s:get_cache_tables(...)
    let buffer = a:0 ? a:1 : '%'
    let info = exists('b:sw_is_resultset') && b:sw_is_resultset ? sw#get_buffer_from_resultset(b:current_channel) : getbufinfo(buffer)
    if len(info) == 0
        return {}
    endif

    " If the result comes from sw#get_buffer_from_resultset, the info
    " is already extracted from the array
    try 
        let info = info[0]
    catch
    endtry

    if has_key(info.variables, 'autocomplete_tables')
        return info.variables.autocomplete_tables
    endif

    if exists('g:sw_autocomplete_default_tables')
        return g:sw_autocomplete_default_tables
    endif

    let tables = sw#autocomplete#get_cache(info.name)
    if len(tables) > 0
        call setbufvar(info.name, 'autocomplete_tables', tables)
        return tables
    else
        return {}
    endif

    return {}
endfunction

function! s:get_cache_procs()
    if exists('b:autocomplete_procs')
        return b:autocomplete_procs
    endif
    
    if exists('g:sw_autocomplete_default_procs')
        return g:sw_autocomplete_default_procs
    endif

    return {}
endfunction

function! s:get_cache_data_name(s)
    let pattern = '\v\c^(v|t)#(.*)$'
    return substitute(a:s, pattern, '\2', 'g')
endfunction

function! s:get_cache_data_type(s)
    let pattern = '\v\c^(v|t)#(.*)$'
    return substitute(a:s, pattern, '\1', 'g')
endfunction

function! s:get_cache_data_fields(s, ...)
    let buffer = a:0 ? a:1 : sw#bufname('%')
    let cache = s:get_cache_tables(buffer)
    for table in keys(cache)
        if tolower(table) == 'v#' . tolower(a:s) || tolower(table) == 't#' . tolower(a:s)
            return cache[table]
        endif
    endfor

    return []
endfunction

function! sw#autocomplete#views(base)
    let result = []
    for table in keys(s:get_cache_tables())
        if table =~ '^V#'
            if s:get_cache_data_name(table) =~ '^' . a:base
                call add(result, {'word': s:get_cache_data_name(table), 'menu': s:get_cache_data_type(table)})
            endif
        endif
    endfor

    return sort(result, "sw#autocomplete#sort")
endfunction

function! sw#autocomplete#tables(base)
    let result = []
    for table in keys(s:get_cache_tables())
        if table =~ '\c^t#'
            if s:get_cache_data_name(table) =~ '\c^' . a:base
                call add(result, {'word': s:get_cache_data_name(table), 'menu': s:get_cache_data_type(table)})
            endif
        endif
    endfor

    return sort(result, "sw#autocomplete#sort")
endfunction

function! sw#autocomplete#all_objects(base)
    let result = []
    for table in keys(s:get_cache_tables())
        if s:get_cache_data_name(table) =~ '\c^' . a:base
            call add(result, {'word': s:get_cache_data_name(table), 'menu': s:get_cache_data_type(table)})
        endif
    endfor

    return sort(result, "sw#autocomplete#sort")
endfunction

function! sw#autocomplete#get_cache(buffer)
    return sw#report#autocomplete_tables(sw#server#get_buffer_profile(a:buffer))
endfunction

function! sw#autocomplete#perform(findstart, base)
    " Check that the cache is alright
    let tables = sw#autocomplete#get_cache(sw#bufname('%'))
    if len(tables) > 0
        let b:autocomplete_tables = tables
    else
        return []
    endif
	call sw#session#init_section()
    if (exists('b:sql'))
        call sw#session#unset_buffer_variable('sql')
    endif
    if a:findstart
        let line = getline('.')
        let start = col('.') - 1
        while start > 0 && line[start - 1] =~ s:pattern_identifier
            let start -= 1
        endwhile
        return start
    else
        let line = getline('.')
        let start = col('.') - 1
        let tbl = ''

        " See if we have table.field
        if (start > 0)
            if line[start - 1] == '.'
                let i = start - 2
                while i > 0 && line[i] =~ s:pattern_identifier
                    let i = i - 1
                endwhile
                let i = i + 1
                let n = start - 2
                let cmd = "let tbl = line[" . i . ":" . n . "]"
                execute cmd
                "If we have table.field, check that table is a table and not
                "an alias. If there is an alias which has the name of an
                "existing table, then the table will have priority. This could
                "change in other versions
                let fields = sw#autocomplete#table_fields(tbl, a:base)
                if len(fields) > 0
                    return sort(fields, "sw#autocomplete#sort")
                endif
            endif
        endif

        " Otherwise, extract the current sql
        let sql = sw#autocomplete#extract_current_sql()
        " Check its type
        let autocomplete_type = s:get_sql_type(sw#eliminate_sql_comments(sql))
        " Desc type, easy peasy
        if (autocomplete_type == 'desc')
            return sw#autocomplete#all_objects(a:base)
            return sort(result, "sw#autocomplete#sort")
        elseif autocomplete_type == 'select' || autocomplete_type == 'update'
            " If a select, first get its tables
            let tables = sw#autocomplete#get_tables(sql, [])
            " If we returned an empty string, then no autocomplete
            if string(tables) == ""
                return []
            endif
            " If we returned no tables, then return the standard autocomplete
            " with available tables
            if len(tables) == 0
                return sw#autocomplete#all_objects(a:base)
            endif

            " If we were on the situation table.field, and we didn't had an
            " available table, it means that that was an alias, so now we can
            " check if we have the alias (it was returned by the get_tables
            " method)
            if tbl != ''
                let result = []
                for table in tables
                    if has_key(table, 'alias')
                        let cond_alias = tolower(table['alias']) == tolower(tbl)
                    else
                        let cond_alias = 0
                    endif
                    if tolower(table['table']) == tolower(tbl) || cond_alias
                        for field in table['fields']
                            if field =~ '\c^' . a:base
                                call add(result, {'word': field, 'menu': tbl . '.'})
                            endif
                        endfor

                        return sort(result, "sw#autocomplete#sort")
                    endif
                endfor
            else
                " Otherwise, we canonize the sql (take out the strings)
                let sql = sw#get_sql_canonical(sql)[0]
                " Take out the new lines
                let sql = substitute(sql, '#NEWLINE#', ' ', 'g')
                " Take out the subqueries (we already know that we are not in
                " a subquery)
                let sql = s:extract_subqueries(sql)[0]

                let pattern = '\v\cselect.*#cursor#.*from'

                " If we are between select and from or after where, then or in
                " a using, return fields to autocomplete
                " If we are between select and from, then we add the all
                " option
                if sql =~ pattern || sql =~ '\v\c(where|group|having).*#cursor#' || sql =~ '\v\cusing[\s\t ]*\([^\)]*#cursor#' || sql =~ '\v\cupdate.*<(set|where)>.*#cursor#'
                    let first = {'word': '', 'abbr': 'all', 'menu': '*'}
                    let result = sql =~ pattern ? [first] : []
                    for table in tables
                        for field in table['fields']
                            let name = table['table']
                            if (has_key(table, 'alias'))
                                let name = table['alias']
                            endif
                            " Also, if we have a piece of string
                            " (strlen(a:base) > 0) and that matches a table,
                            " return that table in the autocomplete, with the
                            " mention T
                            if strlen(a:base) > 0 && (name =~ '\c^' . a:base)
                                call add(result, {'word': name, 'menu': 'T'})
                            endif
                            " Return the matching fields of all the tables
                            if field =~ '\c^' . a:base
                                let first.word .= ((first.word == '') ? '' : ', ') . field
                                call add(result, {'word': field, 'menu': name . '.'})
                            endif
                        endfor
                    endfor

                    if len(result) == (sql =~ pattern ? 1 : 0)
                        return sw#autocomplete#all_objects(a:base)
                    endif

                    return sort(result, "sw#autocomplete#sort")
                else
                    " Otherwise, just return the tables autocomplete
                    return sw#autocomplete#all_objects(a:base)
                endif
            endif
        elseif autocomplete_type == 'insert'
            " If we are before the first paranthese, then just return the list
            " of tables
            if substitute(sql, '\n', ' ', 'g') =~ '\v\c^[ \s\t]*insert[ \s\t]+into[^\(]*#cursor#'
                return sw#autocomplete#all_objects(a:base)
            endif

            " If we are in the fields part of the insert,
            let pattern = '\v\c[ \s\t]*insert[\s\t ]+into[\s\t ]*(' . s:_pattern_identifier . ')[\s\t ]*\(([^\)]*#cursor#[^\)]*)\)'
            if sql =~ pattern
                let l = matchlist(sql, pattern, '')
                if len(l) > 1
                    let tbl = l[1]
                    " If we have some fields input already betweeen
                    " paranthesis
                    let result = sw#autocomplete#table_fields(tbl, a:base, 1)
                    if len(l) >= 4
                        " Do not add them again in the list of auto-complete
                        let fields = s:find_identifiers(l[4])
                        let result = filter(result, 'index(fields, v:val["word"]) == -1')
                    endif

                    return result
                endif
            endif
        elseif autocomplete_type == 'drop'
            if sql =~ '\v\c<drop>.*<table>'
                return sw#autocomplete#tables(a:base)
            elseif sql =~ '\v\c<drop>.*<view>'
                return sw#autocomplete#views(a:base)
            endif
        elseif autocomplete_type == 'alter'
            let pattern = '\v\c<alter>.*<table>[\s\t ]+(' . s:_pattern_identifier . ').*<(alter|change|modify)>.*#cursor#'
            if sql =~ '\v\c<alter>[\s\t ]+<table>[\s\t ]*#cursor#'
                return sw#autocomplete#tables(a:base)
            elseif sql =~ pattern
                let l = matchlist(sql, pattern, '')
                if len(l) > 1
                    let tbl = l[1]
                    return sw#autocomplete#table_fields(tbl, a:base)
                endif
            endif
		elseif autocomplete_type == 'delete'
			if substitute(sql, '\n', ' ', 'g') =~ '\v\c^[ \s\t\r]*delete[ \s\t]+from.{-}#cursor#'
				return sw#autocomplete#tables(a:base)
			endif
        elseif autocomplete_type == 'proc'
            let result = []
            for proc in s:get_cache_procs()
                if proc =~ '\c^' . a:base
                    call add(result, {'word': proc, 'info': 'P'})
                endif
            endfor

            return sort(result, "sw#autocomplete#sort")
        elseif autocomplete_type == 'wbconnect'
            return s:complete_cache(a:base, 'profiles', 'name')
        endif

        return s:complete_cache(a:base, 'macros', 'name')
    endif
endfunction

function! s:complete_cache(base, key, prop)
    let values = sw#cache_get(a:key)
    let result = []
    for value in values(values)
        if value[a:prop] =~ '^' . a:base
            call add(result, value[a:prop])
        endif
    endfor

    return result
endfunction

function! s:get_sql_type(sql)
    let sql = substitute(a:sql, '\v\n', ' ', 'g')
    if sql =~ '\v\c^[\s \t\r]*select'
        return 'select'
    elseif sql =~ '\v\c^[\s \t\r]*insert'
        return 'insert'
    elseif sql =~ '\v\c^[\s \t\r]*update'
        return 'update'
    elseif sql =~ '\v\c^[\s \t\r]*create[\s \t\r]+(materialized)?[\s \r\t]*view'
        return 'select'
    elseif sql =~ '\v\c^[\s \t\r]*drop[\s \t\r]+(table|view|materialized[\s\t ]+view)'
        return 'drop'
    elseif sql =~ '\v\c^[\s \t\r]*alter[\s \t\r]+table'
        return 'alter'
    elseif sql =~ '\v\c^[\s \t\r]*desc'
        return 'desc'
    elseif sql =~ '\v\c^[\s \t\r]*wbcall'
        return 'proc'
	elseif sql =~ '\v\c[\s \t\r]*delete'
		return 'delete'
    elseif sql =~ '\v\c^[\s \t\r]*wbconnect'
        return 'wbconnect'
    endif

    return 'other'
endfunction

function! s:extract_pattern(sql, pattern, name)
    let n = 0
    let sql = a:sql
    let m = matchstr(sql, a:pattern, '')
    let matches = []
    while m != ''
        let sql = substitute(sql, a:pattern, '#' . a:name . n . '#', '')
        let cmd = "call add(matches, {'#" . a:name . n . "#': \"" . substitute(substitute(m, '"', "\\\"", 'g'), '\v^\((.*)\)$', '\1', 'g') . "\"})"
        execute cmd
        let m = matchstr(sql, a:pattern, '')
        let n += 1
    endwhile

    " Return the new query with all the matches replaced
    return [sql, matches]
endfunction

function! s:extract_expressions(sql)
    return s:extract_pattern(a:sql, s:pattern_expressions, 'val')
endfunction

function! s:extract_subqueries(sql)
    let pattern = '\v\c(\([ \s\t]*select[^\(\)]+\))'
    let s = substitute(a:sql, s:pattern_expressions, '#values#', 'g')
	while s =~ s:pattern_expressions
		let s = substitute(s, s:pattern_expressions, '#values#', 'g')
	endwhile
    return s:extract_pattern(s, pattern, 'sq')
endfunction

function! s:get_fields_part(sql)
    let sql = sw#get_sql_canonical(a:sql)[0]
    let sql = substitute(sql, '#NEWLINE#', ' ', 'g')
    let pattern = '\v\c^[ \t\s]*select(.*)from.*$'
    if !(sql =~ pattern)
        return ''
    endif
    return substitute(sql, pattern, '\1', 'g')
endfunction

function! sw#autocomplete#get_tables_part(sql, ...)
    let autocomplete_type = s:get_sql_type(sw#eliminate_sql_comments(a:sql))
    let sql = sw#eliminate_sql_comments(a:sql)
    let _subqueries = s:extract_subqueries(sql)
    let sql = _subqueries[0]
    let subqueries = _subqueries[1]
    unlet _subqueries
    let in_subquery = 0
    " If we are in a subquery, consider the query as select, even though we
    " might be in an update query
    if (exists('b:subquery'))
        if b:subquery
            let in_subquery = 1
        endif
    endif
    if autocomplete_type == 'select' || in_subquery
        let pattern1 = '\v\c^.*from(.{-})<(where|group|order|having|limit|into)>.*$'
        let pattern2 = '\v\c^.*from(.*)$'
    elseif autocomplete_type == 'update'
        let pattern1 = '\v\c^.*update(.{-})<set>.*$'
        let pattern2 = '\v\c^.*update(.*)$'
    endif
    if (exists('b:subquery'))
        call sw#session#unset_buffer_variable('subquery')
    endif
    let from = substitute(sql, pattern1, '\1', '')
    if from == sql
        let from = substitute(sql, pattern2, '\1', '')
        if from == sql
            return ['', []]
        endif
    endif

    let from = substitute(substitute(from, '\v\c#cursor#', '', 'g'), "\\v[`'\"]", '', 'g')

    return [from, subqueries]
endfunction

function! s:canonize_from(from)
    return substitute(a:from, "\\v[`'\"]", "", 'g')
endfunction

function! s:get_subquery_fields(sql, subqueries)
    let sql = substitute(a:sql, '\V#values#', '()', 'g')
    " If we have a subquery, we just extract the fields out of it. We don't
    " care about tables and other stuff. It will probably be identified by an
    " alias, and we want to return alias.fields
    " Split the fields part by the comma
    let fields = split(s:get_fields_part(sql), ',')
    let result = []
    for field in fields
        " First we trim the field
        let field = substitute(field, '\v^[ \s\t]*(.{-})[ \t\s]*$', '\1', 'g')
        if !(field =~ '\v\*')
            " Since we only want the field name, we don't care about the
            " previous part. In the case of my_table.my_id, we want to only
            " get my_id, and then return the autocomplete with alias.my_id.
            " That's why we eliminate everything before the point
            " If the field does not contain *, we just get the last identifier
			if field =~ '\v[ ]'
				let f = matchstr(field, '\v([^ ]+)$')
            elseif field =~ '\v\.'
				let f = matchstr(field, '\v([^\.]+)$')
			else
				let f = field
			endif
            call add(result, f)
        elseif field == '*'
            " If the field is *, we need to get the tables of this subquery
            " and then return all its fields
            " When in a subquery, even if the query type is update, we should
            " consider the subquery a select. This variable will tell the
            " get_tables_part function to consider the query as a select
            " query, and not update query
            call sw#session#set_buffer_variable('subquery', 1)
            let _tmp = sw#autocomplete#get_tables(sql, a:subqueries)
            for row in _tmp
                if (has_key(row, 'fields'))
                    for f in row['fields']
                        call add(result, f)
                    endfor
                endif
            endfor
        elseif field =~ s:pattern_identifier . '\.\*'
            " If the field is table.*, we get the table
            let f = substitute(field, '\v^(.*)\.\*.*$', '\1', 'g')
            " If the table is a known table and not an alias, then return its
            " fields
            let fields = s:get_cache_data_fields(f)
            if len(fields) > 0
                for _f in fields
                    call add(result, _f)
                endfor
            else
                " Otherwise, get the from part of this subquery
                let _r = sw#autocomplete#get_tables_part(sql)
                let from = _r[0]
                let subqueries = _r[1] + a:subqueries
                let from = s:canonize_from(from)
                " Check the alias (search for something like table as f or
                " table f)
                let m = matchstr(from, '\v([#]?\w+[#]?)[ \s\t]+(as)?[ \s\t]*' . f)
                if m != ''
                    " We don't have another subquery. Search in the from part
                    " where we have table as f or table f
                    let m = substitute(m, '\v[ \s\t](as [\s\t ]+)?' . f . '$', '', 'g')
                    " If the found part is an identifier, 
                    " get the first part and check that it's a known table. If
                    " this is not the case, then sorry, nothing we can do. 
                    if m =~ s:pattern_identifier
                        let fields = s:get_cache_data_fields(m)
                        if len(fields) > 0
                            for _f in fields
                                call add(result, _f)
                            endfor
                        endif
                    " If the pattern is a subquery
                    elseif m =~ s:pattern_subquery
                        " Check the subquery string in the list of subqueries
                        let subquery = s:find_subquery(m, subqueries)
                        if subquery != ''
                            " And return it fields (add them at the current
                            " list of fields)
                            let result = result + g:get_subquery_fields(subquery, subqueries)
                        endif
                    endif
                else
                    " If it's another subquery, 
                    let l = matchlist(from, '\v(' . s:_pattern_identifier . ')[ \s\t]+' . f, 'g')
                    if len(l) > 1
                        let m = l[1]
                        let fields = s:get_cache_data_fields(m)
                        if len(fields) > 0
                            for _f in fields
                                call add(result, _f)
                            endfor
                        endif
                    endif
                endif
            endif
        endif
    endfor

    return result
endfunction

function! s:find_subquery(key, subqueries)
    for subquery in a:subqueries
        if (has_key(subquery, a:key))
            return subquery[a:key]
        endif
    endfor

    return ''
endfunction

" Returns the identifiers eliminating the #cursor#
function! s:find_identifiers(s)
    " Get the list of identifiers from s. In the process,
    " eliminate the #CURSOR# which corresponds to an identifier, but it's just
    " added by us to get the cursor position
    return split(substitute(substitute(a:s, '\v\.\w*', '', 'g'), '#CURSOR#', '', 'g'), s:pattern_identifier_split)
endfunction

" Returns the identifiers keeping the #cursor# part, but eliminating the empty
" ones
function! s:get_identifiers(s)
    " The fields are splitted by the pattern identifiant splitter and then 
    " we filter out the empty strings
    return filter(split(a:s, s:pattern_identifier_split), 'v:val != ""')
endfunction

function! sw#autocomplete#is_select(sql)
    return s:get_sql_type(sw#eliminate_sql_comments(a:sql)) == 'select'
endfunction

function! sw#autocomplete#get_tables(sql, subqueries, ...)
    ""if !(a:sql =~ '#CURSOR#')
    ""    return ""
    ""endif

    " We might want to get the tables from a resultset
    " (in case of SWSqlForeignKey). In this case, the sql
    " buffer is not the current one (which is the result set buffer)
    let buffer = a:0 ? a:1 : sw#bufname('%')

    " Get the from part and eliminate the subqueries
    if !sw#autocomplete#is_select(a:sql)
        return []
    endif
    let result = sw#autocomplete#get_tables_part(a:sql)
    let from = result[0]
    let subqueries = result[1] + a:subqueries
    unlet result
    " If we don't have any form part, then return the standard autocomplete
    " (list of available tables)
    if (from == '')
        return []
    endif
    let tables = []

    " Eliminate the `'"
    let from = s:canonize_from(from)
    " Get the list of identifiers from the from part. In the process,
    " eliminate the #CURSOR# which corresponds to an identifier, but it's just
    " added by us to get the cursor position
    let identifiers = s:find_identifiers(from)

    let treated = []

    for m in identifiers
        " Eliminate the semmi column from the identifier
        let m = substitute(m, '\v;', '', 'g')
        " If the identifier is reserved word not empty
        if !(m =~ s:pattern_reserved_word) && m != '' && index(treated, m) == -1
            " If it's a replaced subquery, 
            if m =~ s:pattern_subquery
                let subquery = s:find_subquery(m, subqueries)
                if subquery != ''
                    " Get the list of fields from that subquery and add it.
                    " The title is #ALIAS# because we expect to get an alias
                    " as next identifier, wich will be the table name
                    let fields = s:get_subquery_fields(subquery, subqueries)
                    call add(tables, {'table': 'subquery', 'fields': fields})
                endif
            elseif m =~ s:pattern_identifier
                " If it's a normal identiier then if we have a table with this
                " name, add it's fields
                let fields = s:get_cache_data_fields(m, buffer)
                if len(fields) > 0
                    call add(tables, {'table': m, 'fields': fields})
                else
                    " Otherwise it's an alias. We assums it's the alias of the
                    " preceding identifier. 
                    if len(tables) > 0
                        " If it was a subquery, and it had the name #ALIAS#,
                        " then replace the table name
                        if (tables[len(tables) - 1]['table'] == 'subquery')
                            let tables[len(tables) - 1]['table'] = m
                        else
                            " Otherwise, just put it as alias
                            let tables[len(tables) - 1]['alias'] = m
                        endif
                    endif
                endif
            endif
            call add(treated, m)
        endif
    endfor

    return tables
endfunction

function! sw#autocomplete#complete_cache_name(ArgLead, CmdLine, CursorPos)
    let words = split('^' . a:CmdLine, '\v\s+')
    let files = split(globpath(g:sw_cache, '*'), "\n")
    let result = []
    for file in files
        let f = substitute(file, '\v\c^.*\/([^\/\.]+)\.?.*$', '\1', 'g')
        if a:CmdLine =~ '\v^' . f || a:CmdLine =~ '\v\s+$'
            call add(result, f)
        endif
    endfor
    return result
endfunction

function! sw#autocomplete#set()
    ""setlocal completefunc=sw#autocomplete#perform
    setlocal omnifunc=sw#autocomplete#perform
endfunction

function! sw#autocomplete#get_insert_parts(sql)
    " Eliminate the strings
    let strings = sw#get_sql_canonical(a:sql)
    " Eliminate the comments
    let sql = sw#eliminate_sql_comments(strings[0])
    " Eliminate the expressions between paranthesis
    let expressions = s:extract_expressions(sql)
    " Eliminate the subqueries
    let subqueries = s:extract_subqueries(expressions[0])

    let sql = subqueries[0]
    " Now we have something like insert into <tbl>#val0# values(...)
    " In the list of values we can have subqueries. If we don't have the 
    " #val0# part, it means the query is not a valid insert query, 
    " so don't bother anymore
    if len(expressions) == 0 || len(expressions[1][0]) == 0
        return {}
    endif

    " The fields are splitted by the pattern identifiant splitter and then 
    " we filter out the empty strings
    let fields = s:get_identifiers(expressions[1][0]['#val0#'])
    let pattern = '\v^[ \s\t]*insert[ \s\t]+.{-}#val0#[ \s\t]+values[ \s\t]*(\([^\)]+\)|#val1#).*$'
    " Eliminate the cursor part, to test sql valid
    " If the query is not a correct insert query, then don't bother anymore
    if !(sql =~ pattern)
        return {}
    endif
    let _values = substitute(sql, pattern, '\1', 'g')
    let values = s:get_identifiers(_values == "#val1#" ? expressions[1][1]['#val1#'] : _values)
    return {'sql': sql, 'fields': fields, 'values': values, 'strings': strings[1], 'expressions': expressions[1], 'subqueries': subqueries[1]}
endfunction
