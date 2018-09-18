let s:table_pattern = '\v\c^.*\<(table|view)-def name\="#name#"\>(.{-})\<\/\1-def\>.*$'
let s:column_pattern = '\v\c.*\<column-def name\="#name#"\>(.{-})\<\/column-def\>.*$'
let s:ref_pattern = '\v\c.*\<references\>(.{-})\<\/references\>.*$'
let s:value_pattern = '\v\c.*\<#name#[^\>]*\>(.{-})\<\/#name#\>.*$'
let s:next_table_pattern = '\v\c\<(#what#)-def name\="#name#"\>.{-}\<\/\1-def\>'
let s:in_event = 0
let s:script_path = sw#script_path()

" Initiates a new connection with a given profile
" to create a new report
function! sw#report#get(profile)
    let file = g:sw_tmp . '/' . sw#servername() . '-' . sw#generate_unique_id()
    let command = 'wbschemareport types="TABLE,VIEW,MATERIALIZED VIEW,SYNONYM" -file=' . file . ' -objects=% -stylesheet=' . s:script_path . "resources/wbreport2vim.xslt -xsltOutput=" . s:get_name(a:profile) . '.vim;'
    call sw#background#run(a:profile, command, 'sw#report#message_handler')
endfunction

function! s:get_name(profile)
    return g:sw_cache . '/' . substitute(a:profile, '\v\', '-', 'g')
endfunction

function! s:get_report(profile, force)
    if !a:force && exists('b:report') && has_key(b:report, a:profile)
        return b:report[a:profile]
    endif
    let file = s:get_name(a:profile) . '.vim'
    if !filereadable(file)
        let profiles = sw#cache_get('profiles')
        if !has_key(profiles, a:profile)
            return {}
        endif
        let profile = profiles[a:profile]
        if has_key(profile['props'], 'use-report')
            let file = s:get_name(profile['props']['use-report']) . '.vim'
        endif
    endif
    call sw#execute_file(file)
    if !exists('b:report')
        let b:report = {}
    endif
    let result = exists('b:schema_report') ? b:schema_report : {}
    let b:report[a:profile] = result
    return result
endfunction

function! sw#report#message_handler(profile, txt)
    let pattern = '\v^[0-9]+ objects? written to (.*)'
    for line in split(a:txt, '\v[\r\n]')
        if line =~ pattern
            let file = substitute(substitute(line, pattern, '\1', 'g'), '\v\\', '/', 'g')
            let dest = s:get_name(a:profile)
            call writefile(readfile(file), dest)
        endif
    endfor
endfunction

function! s:get_value(dict, key)
    if has_key(a:dict, a:key)
        return a:dict[a:key]
    endif

    if has_key(a:dict, tolower(a:key))
        return a:dict[tolower(a:key)]
    endif

    if has_key(a:dict, toupper(a:key))
        return a:dict[toupper(a:key)]
    endif

    return {}
endfunction

function! s:search_table(profile, table)
    let report = s:get_report(a:profile, 0)
    if (len(keys(report)) <= 0)
        call sw#display_error("Could not find the " . a:profile . " report. Have you run `call sw#report#get('" . a:profile . "')` or set the report option to true?")
    endif
    return s:get_value(report, a:table)
endfunction

function! s:search_column(table, column)
    if len(keys(a:table)) <= 0
        call sw#display_error("Could not find " . a:table.name)
    endif
    return has_key(a:table, 'columns') && has_key(a:table['columns'], a:column) ? a:table.columns[a:column] : {}
endfunction

function! s:search_ref(table, column)
    if len(keys(a:column)) <= 0
        call sw#display_error("Could not find " . a:column . " in " . a:table.name . ' table')
    endif
    return a:column.references
endfunction

function! sw#report#autocomplete_tables(profile)
    let report = s:get_report(a:profile, 0)
    let result = {}

    for table in values(report)
        let result[toupper(substitute(table.type, '\v^(.).*$', '\1', 'g')) . '#' . table.name] = keys(table.columns)
    endfor

    return result
endfunction

function! s:get_table_name(ref, current_table)
    let catalog = a:ref.catalog
    let schema = a:ref.schema
    if a:current_table.schema == a:ref.schema && a:current_table.catalog == a:ref.catalog
        let catalog = ''
        let schema = ''
    endif

    return (catalog != '' ? catalog . '.' : '') . (schema != '' ? schema . '.' : '') . (has_key(a:ref, 'table') ? a:ref.table : a:ref.name)
endfunction

function! sw#report#is_string(type)
    return index([2004, 1, -15, 2005, 2011, 91, -4, -16, 93, 12, -9, 2009], a:type) != -1
endfunction

function! sw#report#get_references_sql(profile, table, column)
    let table = s:search_table(a:profile, a:table)
    let column = s:search_column(table, a:column)
    let quote = sw#report#is_string(column.type) ? "'" : ''
    return "select * from " . a:table . ' where ' . a:column . ' = ' . quote . '#value#' . quote
endfunction

function! sw#report#profile_changed(args)
    if s:in_event
        return
    endif
    let s:in_event = 1
    let profiles = sw#cache_get('profiles')
    let profile = a:args['profile']
    if has_key(profiles, profile) && has_key(profiles[profile]['props'], 'report') && profiles[profile]['props']['report'] == 'true'
        call sw#report#get(profile)
    endif
    let s:in_event = 0
endfunction

function! s:is_added(table)
    if index(s:added, a:table.name) != -1
        return 1
    endif
    call add(s:added, a:table.name)
    return 0
endfunction

function! s:get_references(profile, table, level, ...)
    let max_level = a:0 ? a:1 : -1
    if max_level != -1 && a:level >= max_level
        return {}
    endif
    if s:is_added(a:table)
        return {}
    endif
    let result = {}
    if len(keys(a:table['foreign-keys'])) > 0
        for key in values(a:table['foreign-keys'])
            let t = s:search_table(a:profile, s:get_table_name(key.table, a:table))
            let result[t.name] = {'references': s:get_references(a:profile, t, a:level + 1, max_level), 'source-columns': key['source-column'], 'referenced-columns': key['dest-column']}
        endfor
    endif

    return result
endfunction

function! s:get_ref_by(profile, table, level, ...)
    let max_level = a:0 ? a:1 : -1
    if max_level != -1 && a:level >= max_level
        return {}
    endif
    if s:is_added(a:table)
        return {}
    endif
    let result = {}
    let report = s:get_report(a:profile, 0)
    for table in values(report)
        if table.type != 'table' || table.name == a:table.name
            continue
        endif
        for key in values(table['foreign-keys'])
            if s:get_table_name(key.table, a:table) == a:table.name
                let t = s:search_table(a:profile, table.name)
                let result[t.name] = {'ref-by': s:get_ref_by(a:profile, t, a:level + 1, max_level), 'referenced-columns': key['source-column'], 'source-columns': key['dest-column']}
            endif
        endfor
    endfor

    return result
endfunction

function! s:get_ref_tree(profile, table, key, max_level)
    let s:added = []
    let result = {}
    let table = s:search_table(a:profile, a:table)
    if string(table) == "{}"
        return {}
    endif
    let ref = {}
    let Func = function('s:get_' . substitute(a:key, '-', '_', 'g'))
    let ref[a:key] = table.type == 'table' ? Func(a:profile, table, 0, a:max_level) : {}
    let result[a:table] = ref
    return result
endfunction

function! sw#report#get_references(profile, table, ...)
    return s:get_ref_tree(a:profile, a:table, 'references', a:0 ? a:1 : -1)
endfunction

function! sw#report#get_referenced_by(profile, table, ...)
    return s:get_ref_tree(a:profile, a:table, 'ref-by', a:0 ? a:1 : -1)
endfunction

function! sw#report#get_table_info(profile, table)
    return s:search_table(a:profile, a:table)
endfunction

function! sw#report#get_field_info(profile, table, column)
    let table = s:search_table(a:profile, a:table)
    if string(table) == "{}"
        return {}
    endif

    return table['columns'][a:column]
endfunction
