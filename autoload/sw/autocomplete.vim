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
let s:pattern_reserved_word = '\v\c<(inner|outer|right|left|join|as|using|where|group|order|and|or|not)>'
let s:pattern_subquery = '\v#sq([0-9]+)#'
let s:script_path = expand('<sfile>:p:h') . '/../../'
let s:pattern_expressions = '\v\c\(([\s\t ]*select)@![^\(\)]{-}\)'

function! s:eliminate_sql_comments(sql)
    let sql = sw#get_sql_canonical(a:sql)[0]
    let sql = substitute(sql, '\v--.{-}#NEWLINE#', '#NEWLINE#', 'g')
    let sql = substitute(sql, '\v--.{-}$', '', 'g')
    let sql = substitute(sql, '\v\/\*.{-}\*\/', '', 'g')
    let sql = substitute(sql, '#NEWLINE#', ' ', 'g')

    return sql
endfunction

if exists('g:sw_plugin_path')
    " This is for cygwin. If we are under cygwin, the sqlworkbench will be a
    " windows application, and vim will work with linux paths
    let s:script_path = g:sw_plugin_path
endif

function! sw#autocomplete#sort(e1, e2)
    return a:e1.word == a:e2.word ? 0 : a:e1.word > a:e2.word ? 1 : -1
endfunction

function! sw#autocomplete#table_fields(tbl, base)
    let result = []
    let fields = s:get_cache_data_fields(a:tbl)
    if len(fields) > 0
        for field in fields
            if field =~ '^' . a:base
                call add(result, {'word': field, 'menu': a:tbl . '.'})
            endif
        endfor
    endif
    return sort(result, "sw#autocomplete#sort")
endfunction

function! sw#autocomplete#extract_current_sql()
    let sql = sw#sqlwindow#extract_current_sql(1)
    let _sql = s:eliminate_sql_comments(sql)
    let _sql = substitute(_sql, s:pattern_expressions, '#values#', 'g')
    " Check to see that we are not in a subquery
    let pattern = '\v\c(\([ \t\s]*select[^\(]*#cursor#).*\)'
    if _sql =~ pattern
        " If we are in a subquery, search where it begins.
        let l = matchlist(sql, '\v\c(\([ \s\t]*select([^s]|s[^e]|se[^l]|sel[^e]|sele[^c]|selec[^t]|select[^\s \t])*#cursor#)', 'g')
        if (len(l) >= 1)
            " Get the start and end of the subquery
            let start = sw#index_of(sql, l[1])
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

            let start = start + 1
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

function! sw#autocomplete#got_result()
    call sw#session#init_section()
    if exists('b:autocomplete_clear') || !exists('b:autocomplete_tables')
        call sw#session#set_buffer_variable('autocomplete_procs', {})
        call sw#session#set_buffer_variable('autocomplete_tables', {})
    endif
    if filereadable(g:sw_tmp . "/sw_report_tbl.vim")
        call s:execute_file(g:sw_tmp . "/sw_report_tbl.vim")
        call sw#session#set_buffer_variable('autocomplete_tables', b:autocomplete_tables)
    endif
    if filereadable(g:sw_tmp . "/sw_report_proc.vim")
        call s:execute_file(g:sw_tmp . "/sw_report_proc.vim")
        call sw#session#set_buffer_variable('autocomplete_procs', b:autocomplete_procs)
    endif
    setlocal completefunc=sw#autocomplete#perform
    unlet b:autocomplete_clear
    call sw#sqlwindow#check_results()
	echomsg "Autocomplete activated"
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

function! sw#autocomplete#persist(name)
    let lines = ['let b:autocomplete_tables = {}']
    call add(lines, 'let b:autocomplete_procs = {}')
    if exists('b:autocomplete_tables')
        for key in keys(b:autocomplete_tables)
            call add(lines, 'let b:autocomplete_tables["' . escape(key, '"') . '"] = ' . string(b:autocomplete_tables[key]))
        endfor
    endif
    if exists('b:autocomplete_procs')
        for key in keys(b:autocomplete_procs)
            call add(lines, 'let b:autocomplete_procs["' . escape(key, '"') . '"] = ' . string(b:autocomplete_procs[key]))
        endfor
    endif
    call writefile(lines, g:sw_autocomplete_cache_dir . '/' . a:name . '.vim')
endfunction

function! sw#autocomplete#load(name)
    call s:execute_file(g:sw_autocomplete_cache_dir . '/' . a:name . '.vim')
    setlocal completefunc=sw#autocomplete#perform
endfunction

function! sw#autocomplete#cache(bang, ...)
    if (!exists('b:port'))
        return
    endif
    call sw#session#init_section()
    let objects = '%'
    if a:0
        let i = 1
        let objects = ''
        while i <= a:0
            execute "let obj = a:" . i
            if obj =~ '^-'
                call sw#autocomplete#remove_table_from_cache(substitute(obj, '^-', '', 'g'))
            else
                let objects = (objects == '' ? '' : ',') . obj
            endif
            let i = i + 1
        endwhile
    endif

    if objects == ''
        return 
    endif
    let sql = "WbSchemaReport -file=" . g:sw_tmp . "/sw_report.xml -objects=" . objects . " -types='TABLE,VIEW,SYSTEM VIEW,MATERIALIZED VIEW,TEMPORARY TABLE,SYNONYM' -stylesheet=" . s:script_path . "resources/wbreport2vim.xslt -xsltOutput=" . g:sw_tmp . "/sw_report_tbl.vim;\n"
    let sql = sql . "WbExport -type=xml -file=" . g:sw_tmp . "/sw_procs.xml -stylesheet=" . s:script_path . "resources/wbprocedures2vim.xslt -lineEnding=lf -xsltOutput=" . g:sw_tmp . "/sw_report_proc.vim;\n"
    let sql = sql . "WBListProcs;"

    call sw#set_on_async_result('sw#autocomplete#got_result')
    if a:bang
        let b:autocomplete_clear = 1
    endif
    let result = sw#execute_sql(sql, 0)
endfunction

function! s:get_cache_tables()
    if exists('b:autocomplete_tables')
        return b:autocomplete_tables
    endif
    
    if exists('g:sw_autocomplete_default_tables')
        return g:sw_autocomplete_default_tables
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

function! s:get_cache_data_fields(s)
    let cache = s:get_cache_tables()
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

function! sw#autocomplete#perform(findstart, base)
    " Check that the cache is alright
    if !exists('b:autocomplete_tables') && !exists('g:sw_autocomplete_default_tables')
        call sw#display_error("First you have to clear the completion cache to use autocomplete")
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
        call sw#session#set_buffer_variable('autocomplete_type', s:get_sql_type(s:eliminate_sql_comments(sql)))
        " Desc type, easy peasy
        if (b:autocomplete_type == 'desc')
            return sw#autocomplete#all_objects(a:base)
            return sort(result, "sw#autocomplete#sort")
        elseif b:autocomplete_type == 'select' || b:autocomplete_type == 'update'
            " If a select, first get its tables
            let tables = s:get_tables(sql, [])
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

                " If we are between select and from or after where, then or in
                " a using, return fields to autocomplete
                if sql =~ '\v\cselect.*#cursor#.*from' || sql =~ '\v\c(where|group|having).*#cursor#' || sql =~ '\v\cusing[\s\t ]*\([^\)]*#cursor#' || sql =~ '\v\cupdate.*<(set|where)>.*#cursor#'
                    let result = []
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
                                call add(result, {'word': field, 'menu': name . '.'})
                            endif
                        endfor
                    endfor

                    if len(result) == 0
                        return sw#autocomplete#all_objects(a:base)
                    endif

                    return sort(result, "sw#autocomplete#sort")
                else
                    " Otherwise, just return the tables autocomplete
                    return sw#autocomplete#all_objects(a:base)
                endif
            endif
        elseif b:autocomplete_type == 'insert'
            " If we are before the first paranthese, then just return the list
            " of tables
            if substitute(sql, '\n', ' ', 'g') =~ '\v\c^[ \s\t]*insert[ \s\t]+into[^\(]*#cursor#'
                return sw#autocomplete#all_objects(a:base)
            endif

            let pattern = '\v\c[ \s\t]*insert[\s\t ]+into[\s\t ]*(' . s:_pattern_identifier . ')[\s\t ]*\([^\)]*#cursor#'
            if sql =~ pattern
                let l = matchlist(sql, pattern, '')
                if len(l) > 1
                    let tbl = l[1]
                    return sw#autocomplete#table_fields(tbl, a:base)
                endif
            endif
        elseif b:autocomplete_type == 'drop'
            if sql =~ '\v\c<drop>.*<table>'
                return sw#autocomplete#tables(a:base)
            elseif sql =~ '\v\c<drop>.*<view>'
                return sw#autocomplete#views(a:base)
            endif
        elseif b:autocomplete_type == 'alter'
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
		elseif b:autocomplete_type == 'delete'
			if substitute(sql, '\n', ' ', 'g') =~ '\v\c^[ \s\t\r]*delete[ \s\t]+from.{-}#cursor#'
				return sw#autocomplete#tables(a:base)
			endif
        elseif b:autocomplete_type == 'proc'
            let result = []
            for proc in s:get_cache_procs()
                if proc =~ '\c^' . a:base
                    call add(result, {'word': proc, 'info': 'P'})
                endif
            endfor

            return sort(result, "sw#autocomplete#sort")
        elseif b:autocomplete_type == 'wbconnect'
            let profiles = sw#parse_profile_xml()
            let result = []
            for profile in keys(profiles)
                if profile =~ '^' . a:base
                    call add(result, profile)
                endif
            endfor

            return result
        endif

        return []
    endif
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

function! s:extract_subqueries(sql)
    let pattern = '\v\c(\([ \s\t]*select[^\(\)]+\))'
    let s = substitute(a:sql, s:pattern_expressions, '#values#', 'g')
	while s =~ s:pattern_expressions
		let s = substitute(s, s:pattern_expressions, '#values#', 'g')
	endwhile
    let matches = []
    let n = 0
    let m = matchstr(s, pattern, '')
    while m != ''
        let s = substitute(s, pattern, '#sq' . n . '#', '')
        let cmd = "call add(matches, {'#sq" . n . "#': \"" . substitute(substitute(m, '"', "\\\"", 'g'), '\v^\((.*)\)$', '\1', 'g') . "\"})"
        execute cmd
        let m = matchstr(s, pattern, '')
        let n = n + 1
    endwhile

    " Return the new query with all the matches replaced
    return [s, matches]
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

function! s:get_tables_part(sql)
    let sql = s:eliminate_sql_comments(a:sql)
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
    if b:autocomplete_type == 'select' || in_subquery
        let pattern1 = '\v\c^.*from(.{-})<(where|group|order|having|limit|into)>.*$'
        let pattern2 = '\v\c^.*from(.*)$'
    elseif b:autocomplete_type == 'update'
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
			if field =~ '\v\.'
				let f = matchstr(field, '\v([^\.]+)$')
			elseif field =~ '\v[ ]'
				let f = matchstr(field, '\v([^ ]+)$')
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
            let _tmp = s:get_tables(sql, a:subqueries)
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
                let _r = s:get_tables_part(sql)
                let from = _r[0]
                let subqueries = _r[1] + a:subqueries
                let from = s:canonize_from(from)
                " Check the alias (search for something like table as f or
                " table f)
                let m = matchstr(from, '\v([#]?[\w]+[#]?)[ \s\t]+(as)?[ \s\t]*' . f)
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

function! s:get_tables(sql, subqueries)
    ""if !(a:sql =~ '#CURSOR#')
    ""    return ""
    ""endif

    " Get the from part and eliminate the subqueries
    let result = s:get_tables_part(a:sql)
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
    let identifiers = split(substitute(substitute(from, '\v\.\w*', '', 'g'), '#CURSOR#', '', 'g'), '\v[, \t]')

    for m in identifiers
        " If the identifier is reserved word not empty
        if !(m =~ s:pattern_reserved_word) && m != ''
            " If it's a replaced subquery, 
            if m =~ s:pattern_subquery
                let subquery = s:find_subquery(m, subqueries)
                if subquery != ''
                    " Get the list of fields from that subquery and add it.
                    " The title is #ALIAS# because we expect to get an alias
                    " as next identifier, wich will be the table name
                    let fields = s:get_subquery_fields(subquery, subqueries)
                    call add(tables, {'table': '#ALIAS#', 'fields': fields})
                endif
            elseif m =~ s:pattern_identifier
                " If it's a normal identiier then if we have a table with this
                " name, add it's fields
                let fields = s:get_cache_data_fields(m)
                if len(fields) > 0
                    call add(tables, {'table': m, 'fields': fields})
                else
                    " Otherwise it's an alias. We assums it's the alias of the
                    " preceding identifier. 
                    if len(tables) > 0
                        " If it was a subquery, and it had the name #ALIAS#,
                        " then replace the table name
                        if (tables[len(tables) - 1]['table'] == '#ALIAS#')
                            let tables[len(tables) - 1]['table'] = m
                        else
                            " Otherwise, just put it as alias
                            let tables[len(tables) - 1]['alias'] = m
                        endif
                    endif
                endif
            endif
        endif
    endfor

    return tables
endfunction

function! sw#autocomplete#complete_cache_name(ArgLead, CmdLine, CursorPos)
    let words = split('^' . a:CmdLine, '\v\s+')
    let files = split(globpath(g:sw_autocomplete_cache_dir, '*'), "\n")
    let result = []
    for file in files
        let f = substitute(file, '\v\c^.*\/([^\/\.]+)\.?.*$', '\1', 'g')
        if a:CmdLine =~ '\v^' . f || a:CmdLine =~ '\v\s+$'
            call add(result, f)
        endif
    endfor
    return result
endfunction
