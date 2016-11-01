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

if !exists('g:SW_Tabs')
    let g:SW_Tabs = {}
endif

let s:profiles = {}
let s:events = {'panels': {'before': {}, 'after': {}}, 'tabs': {'before': {}, 'after': {}}}
let s:last_command = {}
let s:cache = {}
let s:cache_filter = "!(v:val =~ '\\v^Execution time')"
let s:cache_message = 'Execution time (from cache)'

" Local functions{{{1
" Iterates in the tabs array{{{2

function! s:iterate(f)
    for _profile in items(g:SW_Tabs)
        let profile = _profile[0]
        let tabs = _profile[1]
        let type_ok = 0
        if (profile =~ '^[:\^]')
            if (len(s:profiles) == 0)
                let s:profiles = sw#parse_profile_xml()
            endif
            let dbms_type = substitute(profile, '^[:\^]', '', 'g')
            let cond = substitute(profile, '\v\c^([:\^]).*$', '\1', 'g')

            for xml_profile in items(s:profiles)
                if tolower(substitute(xml_profile[0], "\\\\", '___', 'g')) == tolower(b:profile) && 
                            \ ((tolower(xml_profile[1]) == tolower(dbms_type) && cond == ':') ||
                            \ (tolower(xml_profile[1]) != tolower(dbms_type) && cond == '^'))
                    let type_ok = 1
                    break
                endif
            endfor
        endif
        if (profile == b:profile || profile == '*' || type_ok)
            for tab in tabs
                execute "let r = " . a:f . "(tab)"
                if !r
                    return
                endif
            endfor
        endif
    endfor
endfunction

function! s:open_in_new_buffer()
    normal ggVGy
    tabnew
    normal Vp
    set filetype=sql
endfunction

" Finds a tab by shortcut (to be called via iterate){{{2
" We are returning 0 if found, because this will break the loop
" The result is saved in b:tab. The tab searched is in b:shortcut
function! s:find_tab_by_shortcut(tab)
    if a:tab['shortcut'] == b:shortcut
        call sw#session#set_buffer_variable('tab', a:tab)
        return 0
    endif
    return 1
endfunction

" Get the first tab{{{2
function! s:get_first_tab(tab)
    call sw#session#set_buffer_variable('first_tab', a:tab)
    return 0
endfunction

" Set a special buffer{{{2
function! s:set_special_buffer(profile, channel)
    call sw#session#init_section()
    call sw#set_special_buffer()
    call sw#session#set_buffer_variable('profile', a:profile)
    call sw#session#set_buffer_variable('sw_channel', a:channel)
    call sw#session#set_buffer_variable('t1_shortcuts', 'Main shortcuts:')
    call sw#session#set_buffer_variable('t2_shortcuts', 'Available shortcuts in the left panel:')
    call sw#session#set_buffer_variable('t3_shortcuts', 'Available shortcuts in the right panel:')

	call s:iterate('s:add_shortcut')

	if g:sw_tab_switches_between_bottom_panels
		nmap <buffer> <tab> :call sw#dbexplorer#switch_bottom_panels()<cr>
	endif
endfunction

function! sw#dbexplorer#switch_bottom_panels()
	if exists('b:profile')
		if bufname('%') == '__DBExplorer__-' . b:profile
			call sw#goto_window('__SQL__-' . b:profile)
		else
			call sw#goto_window('__DBExplorer__-' . b:profile)
		endif
	endif
endfunction

function! s:get_panels()
    return ['__DBExplorer__-' . b:profile, '__SQL__-' . b:profile, '__Info__-' . b:profile]
endfunction

function! sw#dbexplorer#set_values_to_all_buffers(keys, values)
    let name = bufname('%')
    for w in s:get_panels()
        call sw#goto_window(w)
        let i = 0
        while i < len(a:keys)
            if (a:keys[i] != 'on_async_result')
                execute "let b:" . a:keys[i] . " = a:values[i]"
            else
                call sw#set_on_async_result(a:values[i])
            endif
            let i = i + 1
        endwhile
    endfor
    call sw#goto_window(name)
endfunction

function! sw#dbexplorer#unset_values_from_all_buffers(keys)
    let name = bufname('%')
    for w in s:get_panels()
        call sw#goto_window(w)
        for key in a:keys
            if exists('b:' . key)
                execute "unlet b:" . key
            endif
        endfor
    endfor
    call sw#goto_window(name)
endfunction

function! sw#dbexplorer#reconnect()
    let result = sw#server#dbexplorer("wbconnect " . b:profile)
endfunction

function! s:process_result_1(result, shortcut, title)
    let result = a:result
    if !exists('b:profile') || !sw#is_visible('__Info__-' . b:profile)
        call sw#display_error("A result was returned by an sql database explorer, but you are not on that tab anymore. You will need to execute the command again")
        return
    endif
    call sw#goto_window('__Info__-' . b:profile)
    call sw#session#set_buffer_variable('current_tab', a:shortcut)
    call sw#goto_window('__SQL__-' . b:profile)
    setlocal modifiable
    normal! ggdG
    setlocal nomodifiable
    call sw#session#set_buffer_variable('current_tab', a:shortcut)
    call sw#goto_window('__DBExplorer__-' . b:profile)
    if (exists('b:mappings'))
        for m in b:mappings
            execute "silent! nunmap <buffer> " . m
        endfor
    endif
    call sw#session#set_buffer_variable('current_tab', a:shortcut)
    call sw#put_lines_in_buffer(result)
    call s:set_info_buffer()
    call sw#goto_window('__DBExplorer__-' . b:profile)
    call sw#session#set_buffer_variable('mappings', [])
    call sw#session#set_buffer_variable('shortcut', a:shortcut)
    call s:iterate('s:find_tab_by_shortcut')
    if (exists('b:tab'))
        for panel in b:tab['panels']
            execute "nnoremap <buffer> <silent> " . panel['shortcut'] . " :call <SID>change_panel(\"" . substitute(panel['command'], '"', "\\\\\"", 'g') . "\", \"" . panel['shortcut'] . "\", \"" . panel['title'] . "\", \"" . b:tab['shortcut'] . "\")<cr>"
            call add(b:mappings, panel['shortcut'])
        endfor
    endif
    normal 5G
    if (exists('b:selected_row'))
        silent! call matchdelete(b:selected_row)
        call sw#session#unset_buffer_variable('selected_row')
    endif
endfunction 

function! s:add_to_cache(shortcut, lines)
    if !has_key(s:cache, b:profile)
        let s:cache[b:profile] = {}
    endif
    let s:cache[b:profile][a:shortcut] = filter(copy(a:lines), s:cache_filter)
endfunction

function! s:get_from_cache(shortcut)
    if !has_key(s:cache, b:profile) || !has_key(s:cache[b:profile], a:shortcut)
        return []
    endif

    return s:cache[b:profile][a:shortcut]
endfunction

function! s:is_in_cache(shortcut, lines)
    let f = 'v:val != "" && v:val != "' . s:cache_message . '"'
    return filter(copy(s:get_from_cache(a:shortcut)), f) == filter(copy(filter(copy(a:lines), s:cache_filter)), f)
endfunction

" Change a tab{{{2
function! sw#dbexplorer#change_tab(command, shortcut, title)
    let command = s:process_events('tabs', 'before', a:shortcut, '', a:command)
    let s:last_command = {'command': command, 'shortcut': a:shortcut, 'title': a:title, 'type': 1}
    if len(s:get_from_cache(a:shortcut)) > 0
        let arr = copy(s:get_from_cache(a:shortcut))
        call s:process_result_1(add(arr, s:cache_message), a:shortcut, a:title)
    endif
    call sw#dbexplorer#do_command(command)
endfunction

function! sw#dbexplorer#tmp()
    return s:cache
endfunction

function! sw#dbexplorer#do_command(sql)
    if !exists('b:profile') || !exists('b:sw_channel')
        return
    endif
    if a:sql =~ "^:"
        let func = substitute(a:sql, '^:', '', 'g')
        execute "let s = " . func . "(getline('.'))"
        call sw#dbexplorer#message_handler(b:sw_channel, s)
    else
        call sw#server#execute_sql(substitute(sw#ensure_sql_not_delimited(a:sql, ';'), '\v\<cr\>', "\n", 'g') . ';', b:sw_channel)
    endif
endfunction

function! sw#dbexplorer#toggle_form_display()
    if (!exists('b:state'))
        call sw#display_error("Not in a results panel")
        return
    endif
    if b:state == 'form'
        call sw#session#set_buffer_variable('state', 'resultsets')
        call sw#put_text_in_buffer(b:sw_content)
    else
        call sw#session#set_buffer_variable('state', 'form')
        call sw#session#set_buffer_variable('sw_content', join(getline(1, '$'), "\n"))
        call sw#sqlwindow#display_as_form()
    endif
endfunction

function! s:process_result_2(result, tab_shortcut, shortcut, cmd)
    let result = a:result
    if !exists('b:profile') || !sw#is_visible('__Info__-' . b:profile)
        call sw#display_error("A result was returned by an sql database explorer, but you are not on that tab anymore. You will need to execute the command again")
        return
    endif
    call sw#session#set_buffer_variable('shortcut', a:tab_shortcut)
    call s:iterate('s:find_tab_by_shortcut')
    if (exists('b:tab'))
        for panel in b:tab['panels']
            if (panel['shortcut'] == a:shortcut)
                if (has_key(panel, 'skip_columns'))
                    let result = sw#hide_columns(result, panel['skip_columns'])
                endif
                if (has_key(panel, 'hide_header'))
                    if (panel['hide_header'])
                        let result = sw#hide_header(result)
                    endif
                endif
                call sw#goto_window('__SQL__-' . b:profile)
                if (has_key(panel, 'filetype'))
                    execute 'set filetype=' . panel['filetype']
                else
                    execute 'set filetype=' . g:sw_default_right_panel_type
                endif
                break
            endif
        endfor
    endif
    call sw#goto_window('__SQL__-' . b:profile)
    call sw#session#set_buffer_variable('last_cmd', a:cmd)
    call sw#session#set_buffer_variable('state', 'resultsets')
    call sw#put_lines_in_buffer(result)
endfunction

function! s:get_object_columns()
    let values = split(getline('.'), '\v \| ')
    let result = []

    for val in values
        call add(result, substitute(val, '\v\c^[ ]*([^ ]*)[ ]*$', '\1', 'g'))
    endfor

    return result
endfunction

function! s:change_panel(command, shortcut, title, tab_shortcut)
    echomsg "Processing request..."

    let command = s:process_events('panels', 'before', a:tab_shortcut, a:shortcut, a:command)
    if (exists('b:selected_row'))
        call matchdelete(b:selected_row)
    endif
    let object = substitute(getline('.'), '\v^([^ ]+) .*$', '\1', 'g')
    call sw#session#set_buffer_variable('selected_row', matchadd('SWSelectedObject', '^' . object . ' .*$'))
    let columns = s:get_object_columns()
    let cmd = substitute(command, '\v\%object\%', object, 'g')
    let i = 0
    for column in columns
        let cmd = substitute(cmd, '\v\%' . i . '\%', column, 'g')
        let i = i + 1
    endfor
    let s:last_command = {'tab_shortcut': a:tab_shortcut, 'shortcut': a:shortcut, 'cmd': cmd, 'type': 2, 'object': object}

    if len(s:get_from_cache(a:tab_shortcut . object . a:shortcut)) > 0
        let arr = copy(s:get_from_cache(a:tab_shortcut . object . a:shortcut))
        call s:process_result_2(add(arr, s:cache_message), a:tab_shortcut, a:shortcut, cmd)
    endif
    call sw#dbexplorer#do_command(cmd)
endfunction

" Adds a shortcut from a tab to the current buffer{{{2
function! s:add_shortcut(tab)
    execute "nnoremap <buffer> <silent> " . a:tab['shortcut'] . " :call sw#dbexplorer#change_tab(\"" . substitute(a:tab['command'], '"', "\\\\\"", 'g') . "\", \"" . a:tab['shortcut'] . "\", \"" . a:tab['title'] . "\")<cr>"
    return 1
endfunction

" Displays the tabs in the help buffer{{{2
function! s:display_tabs(tab)
    if b:current_tab == ''
        call sw#session#set_buffer_variable('current_tab', a:tab['shortcut'])
    endif
    if b:txt != ''
        call sw#session#set_buffer_variable('txt', b:txt . ' | ')
    endif
    call sw#session#set_buffer_variable('txt', b:txt . a:tab['title'] . ' (' . a:tab['shortcut'] . ')')
    return 1
endfunction

" Set the help buffer{{{2
function! s:set_info_buffer()
    call sw#goto_window('__Info__-' . b:profile)
    let lines = []
    call add(lines, 'The current profile is ' . substitute(b:profile, '___', "\\", 'g'))
    call sw#session#set_buffer_variable('txt', '')
    call s:iterate('s:display_tabs')
    call add(lines, b:t1_shortcuts)
    call add(lines, b:txt)

    if b:current_tab != ''
        call sw#session#set_buffer_variable('shortcut', b:current_tab)
        call s:iterate('s:find_tab_by_shortcut')
        if (exists('b:tab'))
            call add(lines, b:t2_shortcuts)
            let txt = ''
            for panel in b:tab['panels']
                if txt != ''
                    let txt = txt . ' | '
                endif
                let txt = txt . panel['title'] . ' (' . panel['shortcut'] . ')'
            endfor
            call add(lines, txt)
        endif
    endif
    call add(lines, b:t3_shortcuts . ': Export (E) \| Open in new buffer (B)')
    call sw#put_lines_in_buffer(lines)
endfunction

" Global functions{{{1
" Adds a tab{{{2
function! sw#dbexplorer#add_tab(profile, title, shortcut, command, panels)
    if (!exists('g:extra_sw_tabs'))
        let g:extra_sw_tabs = {}
    endif
    let obj = {'title': a:title, 'shortcut': a:shortcut, 'command': a:command, 'panels': a:panels}
    if !has_key(g:extra_sw_tabs, a:profile)
        let g:extra_sw_tabs[a:profile] = [obj]
    else
        call add(g:extra_sw_tabs[a:profile], obj)
    endif
endfunction

" Add a panel to a tab{{{2
function! sw#dbexplorer#add_panel(profile, tab_shortcut, title, shortcut, command)
    if (!exists('g:extra_sw_panels'))
        let g:extra_sw_panels = {}
    endif
    let obj = {'profile': a:profile, 'panel': {'title': a:title, 'shortcut': a:shortcut, 'command': a:command}}

    if !has_key(g:extra_sw_panels, a:tab_shortcut)
        let g:extra_sw_panels[a:tab_shortcut] = [obj]
    else
        call add(g:extra_sw_panels[a:tab_shortcut], obj)
    endif
endfunction

" Hide the db explorer panel{{{2
function! sw#dbexplorer#hide_panel(...)
    if a:0
        let profile = a:1
    else
        if !exists('b:profile') || !exists('b:t1_shortcuts')
            throw "You can only execute this command from a DBExplorer panel"
        endif

        let profile = b:profile
    endif
    let name = "__SQL__-" . profile
    if !bufexists(name)
        call sw#display_error("There is no dbexplorer opened for " . profile)
        return 
    endif

    call sw#goto_window('__SQL__' . profile)
    call sw#server#disconnect_buffer()
    execute "silent! bwipeout __SQL__-" . profile
    execute "silent! bwipeout __Info__-" . profile
    execute "silent! bwipeout __DBExplorer__-" . profile
endfunction

" Export the result panel as ods{{{2
function! sw#dbexplorer#export()
    if (exists('b:last_cmd'))
        call sw#export_ods(b:last_cmd)
    else
        call sw#display_error("The panel is empty!")
    endif
endfunction

function! s:set_highlights()
    highlight SWHighlights term=NONE cterm=NONE ctermbg=25 ctermfg=yellow gui=NONE guibg=#808080 guifg=yellow
    highlight SWSelectedObject term=NONE cterm=NONE ctermbg=DarkGrey ctermfg=NONE gui=NONE guibg=#808080 guifg=yellow
    let id = matchadd('SWHighlights', b:profile)
    let id = matchadd('SWHighlights', b:t1_shortcuts)
    let id = matchadd('SWHighlights', b:t2_shortcuts)
    let id = matchadd('SWHighlights', b:t3_shortcuts)
endfunction

function! s:process_events(which, when, tab_shortcut, shortcut, result)
    let result = a:result
    if has_key(s:events[a:which][a:when], a:tab_shortcut . a:shortcut)
        for command in s:events[a:which][a:when][a:tab_shortcut . a:shortcut]
            let Callback = function(command)
            let result = Callback(result)
        endfor
    endif

    return result
endfunction

function! s:check_cache(shortcut, result)
    if s:is_in_cache(a:shortcut, a:result)
        return 1
    endif

    call s:add_to_cache(a:shortcut, a:result)

    return 0
endfunction

" Handles a message from the server{{{2
function! sw#dbexplorer#message_handler(channel, message)
    let result = split(a:message, "\n")
    if has_key(s:last_command, 'shortcut')
        let shortcut = s:last_command.shortcut
        if has_key(s:last_command, 'tab_shortcut') && has_key(s:last_command, 'object')
            let shortcut = s:last_command.tab_shortcut . s:last_command.object . shortcut
        endif
    endif

    if s:last_command.type == 1
        let result = s:process_events('tabs', 'after', s:last_command.shortcut, '', result)
        if !s:check_cache(shortcut, result)
            call s:process_result_1(result, s:last_command.shortcut, s:last_command.title)
        endif
    elseif s:last_command.type == 2
        let result = s:process_events('panels', 'after', s:last_command.tab_shortcut, s:last_command.shortcut, result)
        if !s:check_cache(shortcut, result)
            call s:process_result_2(result, s:last_command.tab_shortcut, s:last_command.shortcut, s:last_command.cmd)
        endif
    elseif s:last_command.type == 3
        call s:process_result_1(result, '', '')
    endif
endfunction

" Shows the dbexplorer panel{{{2
function! sw#dbexplorer#show_panel(profile)
    let profile = substitute(a:profile, '\\', '___', 'g')
    let s_below = &splitbelow
    set nosplitbelow
    let name = "__SQL__-" . profile
    if bufexists(name) && bufloaded(name)
        call sw#display_error("There is already a dbexplorer opened for " . profile)
        return 
    endif

    tabnew

    let uid = sw#generate_unique_id()
    execute "badd " . name
    execute "buffer " . name
    let s:last_command = {'type': 3}
    let channel = sw#server#open_dbexplorer(a:profile)
    call s:set_special_buffer(profile, channel)
    call sw#session#set_buffer_variable('unique_id', uid)
    nnoremap <buffer> <silent> E :call sw#dbexplorer#export()<cr>
    nnoremap <buffer> <silent> B :call <SID>open_in_new_buffer()<cr>
    execute "silent! split __Info__-" . profile
    resize 7
    call s:set_special_buffer(profile, channel)
    call sw#session#set_buffer_variable('unique_id', uid)
    call s:set_highlights()
    wincmd b
    execute "silent! vsplit __DBExplorer__-" . profile
    call s:set_special_buffer(profile, channel)
    call sw#session#set_buffer_variable('unique_id', uid)
    vertical resize 60
    call s:iterate('s:get_first_tab')
    ""call sw#dbexplorer#change_tab(b:first_tab['command'], b:first_tab['shortcut'], b:first_tab['title'])
    if s_below
        set splitbelow
    endif
endfunction

" Returns true if the current tab is a db explorer tab{{{2
function! sw#dbexplorer#is_db_explorer_tab()
    let name = bufname('%')
    return name =~ '\v^__Info__' || name =~ '\v^__DBExplorer__' || name =~ '\v^__SQL__'
endfunction

function! s:add_event(which, tab_shortcut, shortcut, when, command)
    if !has_key(s:events[a:which][a:when], a:tab_shortcut . a:shortcut)
        let s:events[a:which][a:when][a:tab_shortcut . a:shortcut] = []
    endif
    call add(s:events[a:which][a:when][a:tab_shortcut . a:shortcut], a:command)
endfunction

function! sw#dbexplorer#add_tab_event(shortcut, when, command)
    call s:add_event('tabs', a:shortcut, '', a:when, a:command)
endfunction

function! sw#dbexplorer#add_panel_event(tab_shortcut, shortcut, when, command)
    call s:add_event('panels', a:tab_shortcut, a:shortcut, a:when, a:command)
endfunction

function! sw#dbexplorer#get_events()
    return s:events
endfunction

function! sw#dbexplorer#filtered_data(result)
    let params = reverse(copy(sw#server#get_parameters_history()))
    let value = ''

    for param in params
        if param.prompt =~ '\v^filter'
            let value = param.value
            break
        endif
    endfor

    let result = ['Filter value: ' . value]

    for line in a:result
        if !(line =~ '\vPlease supply a value for the following variables|filter')
            call add(result, line)
        endif
    endfor

    return result
endfunction

function! sw#dbexplorer#fold_columns(result)
    let name = bufname('%')
    call sw#goto_window('__SQL__-' . b:profile)

    setlocal foldmethod=expr
    setlocal foldexpr=sw#dbexplorer#do_fold_columns(v:lnum)
    normal zR

    return a:result
endfunction

function! sw#dbexplorer#do_fold_columns(lnum)
    if (a:lnum == 1)
        let b:fold_level = 0
    endif
    if getline(a:lnum) =~ '\v^---- '
        let b:fold_level += 1
        return '>' . b:fold_level
    endif
    if getline(a:lnum) =~ '\v^[ \s\t\n\r]*$'
        let result = '<' . b:fold_level
        let b:fold_level -= 1
        if b:fold_level < 0
            let b:fold_level = 0
        endif
        return result
    endif

    return -1
endfunction

" vim:fdm=marker
