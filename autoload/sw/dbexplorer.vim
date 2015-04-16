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

" Local functions{{{1
" Iterates in the tabs array{{{2

function! s:iterate(f)
    for _profile in items(g:SW_Tabs)
        let profile = _profile[0]
        let tabs = _profile[1]
        if (profile == b:profile || profile == '*')
            for tab in tabs
                execute "let r = " . a:f . "(tab)"
                if !r
                    break
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
function! s:set_special_buffer(profile, port)
    call sw#session#init_section()
    call sw#set_special_buffer()
    call sw#session#set_buffer_variable('profile', a:profile)
    call sw#session#set_buffer_variable('port', a:port)
    call sw#session#set_buffer_variable('t1_shortcuts', 'Main shortcuts:')
    call sw#session#set_buffer_variable('t2_shortcuts', 'Available shortcuts in the left panel:')
    call sw#session#set_buffer_variable('t3_shortcuts', 'Available shortcuts in the right panel:')
    ""call sw#session#autocommand('BufEnter', 'sw#check_async_result()')

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
    call sw#goto_window('__Info__-' . b:profile)
    call sw#session#set_buffer_variable('current_tab', a:shortcut)
    call sw#goto_window('__SQL__-' . b:profile)
    call sw#session#set_buffer_variable('current_tab', a:shortcut)
    setlocal modifiable
    normal! ggdG
    setlocal nomodifiable
    call sw#goto_window('__DBExplorer__-' . b:profile)
    if (exists('b:mappings'))
        for m in b:mappings
            execute "silent! nunmap <buffer> " . m
        endfor
    endif
    call sw#session#set_buffer_variable('current_tab', a:shortcut)
    setlocal modifiable
    normal! ggdG
    for line in result
        put =line
    endfor
    normal! ggdd
    setlocal nomodifiable
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

" Change a tab{{{2
function! s:change_tab(command, shortcut, title)
    let result = sw#server#dbexplorer(a:command)
    call s:process_result_1(result, a:shortcut, a:title)
endfunction

function! s:process_result_2(result, tab_shortcut, shortcut, cmd)
    let result = a:result
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
    setlocal modifiable
    normal! ggdG
    for line in result
        put =line
    endfor
    normal! ggdd
    setlocal nomodifiable
    let pattern = '\v^.*-- AFTER(.*)$'
    if a:cmd =~ pattern
        let after = substitute(a:cmd, pattern, '\1', 'g')
        execute after
    endif
endfunction

function! s:change_panel(command, shortcut, title, tab_shortcut)
    echomsg "Processing request..."
    "if line('.') < 5
    "    echoerr "You have to select an object in the left panel"
    "    return 
    "endif
    if (exists('b:selected_row'))
        call matchdelete(b:selected_row)
    endif
    let object = substitute(getline('.'), '\v^([^ ]+) .*$', '\1', 'g')
    call sw#session#set_buffer_variable('selected_row', matchadd('SWSelectedObject', '^' . object . ' .*$'))
    let cmd = substitute(a:command, '\v\%object\%', object, 'g')
    let result = sw#server#dbexplorer(cmd)
    call s:process_result_2(result, a:tab_shortcut, a:shortcut, cmd)
endfunction

" Adds a shortcut from a tab to the current buffer{{{2
function! s:add_shortcut(tab)
    execute "nnoremap <buffer> <silent> " . a:tab['shortcut'] . " :call <SID>change_tab(\"" . substitute(a:tab['command'], '"', "\\\\\"", 'g') . "\", \"" . a:tab['shortcut'] . "\", \"" . a:tab['title'] . "\")<cr>"
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
    setlocal modifiable
    normal! ggdG
    put ='The current profile is ' . b:profile
    call sw#session#set_buffer_variable('txt', '')
    call s:iterate('s:display_tabs')
    put =b:t1_shortcuts
    put =b:txt

    if b:current_tab != ''
        call sw#session#set_buffer_variable('shortcut', b:current_tab)
        call s:iterate('s:find_tab_by_shortcut')
        if (exists('b:tab'))
            put =b:t2_shortcuts
            let txt = ''
            for panel in b:tab['panels']
                if txt != ''
                    let txt = txt . ' | '
                endif
                let txt = txt . panel['title'] . ' (' . panel['shortcut'] . ')'
            endfor
            put =txt
        endif
    endif
    put =b:t3_shortcuts . ': Export (E) \| Open in new buffer (B)'
    normal! ggdd
    setlocal nomodifiable
endfunction

" Sets the objects initial state{{{2
""function! s:set_objects_buffer()
""    wincmd b
""    wincmd h
""    let b:object_tabs = []
""    let b:txt = ''
""    call s:iterate('s:display_tabs')
""    setlocal modifiable
""    normal! ggdG
""    "put =b:txt
""    normal! ggdd
""    setlocal nomodifiable
""endfunction

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
    if (!exists('g:extra_panels'))
        let g:extra_sw_panels = {}
    endif
    let obj = {'title': a:title, 'shortcut': a:shortcut, 'command': a:command}

    if (!has_key(a:profile, g:extra_panels))
        let g:extra_sw_panels[a:profile] = {}
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
        echoerr "There is no dbexplorer opened for " . profile
        return 
    endif

    execute "silent! bwipeout __SQL__-" . profile
    execute "silent! bwipeout __Info__-" . profile
    execute "silent! bwipeout __DBExplorer__-" . profile
endfunction

" Export the result panel as ods{{{2
function! sw#dbexplorer#export()
    if (exists('b:last_cmd'))
        call sw#export_ods(b:profile, b:last_cmd)
    else
        echoerr "The panel is empty!"
    endif
endfunction

function! sw#dbexplorer#show_panel_no_profile(...)
    let connection = ''
    let i = 1
    while i <= a:0
        let cmd = "let arg = a:" . i
        execute cmd
        let connection = connection . ' ' . arg
        let i = i + 1
    endwhile

    let profile = '__no__' . sw#generate_unique_id()
    call sw#dbexplorer#show_panel(profile, connection)
endfunction

function! sw#dbexplorer#restore_from_session(...)
    echomsg "Processing request..."
    let connection = ''
    if exists('b:connection')
        let connection = b:connection
    endif
    call sw#goto_window('__Info__-' . b:profile)
    call sw#session#init_section()
    call sw#session#check()
    call s:set_special_buffer(b:profile, connection)
    call s:set_highlights()
    call sw#goto_window('__SQL__-' . b:profile)
    call sw#session#init_section()
    call sw#session#check()
    call s:set_special_buffer(b:profile, connection)
    call sw#goto_window('__DBExplorer__-' . b:profile)
    call sw#session#init_section()
    call sw#session#check()
    call s:set_special_buffer(b:profile, connection)
    call s:change_tab(b:first_tab['command'], b:first_tab['shortcut'], b:first_tab['title'])
endfunction

function! s:set_highlights()
    highlight SWHighlights term=NONE cterm=NONE ctermbg=25 ctermfg=yellow gui=NONE guibg=#808080 guifg=yellow
    highlight SWSelectedObject term=NONE cterm=NONE ctermbg=DarkGrey ctermfg=fg gui=NONE guibg=#808080 guifg=yellow
    let id = matchadd('SWHighlights', b:profile)
    let id = matchadd('SWHighlights', b:t1_shortcuts)
    let id = matchadd('SWHighlights', b:t2_shortcuts)
    let id = matchadd('SWHighlights', b:t3_shortcuts)
endfunction

" Shows the dbexplorer panel{{{2
function! sw#dbexplorer#show_panel(profile, port, ...)
    let result = sw#server#open_dbexplorer(a:profile, a:port)
    let s_below = &splitbelow
    set nosplitbelow
    let name = "__SQL__-" . a:profile
    if bufexists(name)
        echoerr "There is already a dbexplorer opened for " . a:profile
        return 
    endif

    ""if (g:sw_bufexplorer_new_tab)
    ""    tabnew
    ""endif

    tabnew

    let connection = ''
    if (a:0)
        let connection = a:1
    endif

    let uid = sw#generate_unique_id()

    execute "badd " . name
    execute "buffer " . name
    call s:set_special_buffer(a:profile, a:port)
    call sw#session#set_buffer_variable('unique_id', uid)
    nnoremap <buffer> <silent> E :call sw#dbexplorer#export()<cr>
    nnoremap <buffer> <silent> B :call <SID>open_in_new_buffer()<cr>
    execute "silent! split __Info__-" . a:profile
    resize 7
    "let id = matchadd('SWHighlights', '\v^([^\(]+\([A-Za-z]+\)( \| )?)+$')
    call s:set_special_buffer(a:profile, a:port)
    call sw#session#set_buffer_variable('unique_id', uid)
    call s:set_highlights()
    wincmd b
    execute "silent! vsplit __DBExplorer__-" . a:profile
    call s:set_special_buffer(a:profile, a:port)
    call sw#session#set_buffer_variable('unique_id', uid)
    vertical resize 60
    ""call s:set_objects_buffer()
    call s:iterate('s:get_first_tab')
    call s:change_tab(b:first_tab['command'], b:first_tab['shortcut'], b:first_tab['title'])
    if s_below
        set splitbelow
    endif
endfunction

" Returns true if the current tab is a db explorer tab{{{2
function! sw#dbexplorer#is_db_explorer_tab()
    let name = bufname('%')
    return name =~ '\v^__Info__' || name =~ '\v^__DBExplorer__' || name =~ '\v^__SQL__'
endfunction

" Eliminates the first column of the buffer for the source code{{{2
function! sw#dbexplorer#fix_source_code()
    setlocal modifiable
    normal gg0G0x
    setlocal nomodifiable
endfunction
" vim:fdm=marker
