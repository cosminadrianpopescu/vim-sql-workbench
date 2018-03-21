if ( exists('g:loaded_ctrlp_sw_profiles') && g:loaded_ctrlp_sw_profiles )
	\ || v:version < 700 || &cp
	finish
endif
let g:loaded_ctrlp_sw_profiles = 1

call add(g:ctrlp_ext_vars, {
	\ 'init': 'ctrlp#sw_profiles#init()',
	\ 'accept': 'ctrlp#sw_profiles#accept',
	\ 'lname': 'SQL Workbench Profiles',
	\ 'sname': 'sw_profiles',
	\ 'type': 'line',
	\ 'exit': 'ctrlp#sw_profiles#exit()',
	\ 'enter': 'ctrlp#sw_profiles#enter()',
	\ 'sort': 0,
	\ 'specinput': 0,
	\ })


" Provide a list of strings to search in
"
" Return: a Vim's List
"

let s:current_buffer = ''

" The action to perform on the selected string
" " Arguments:
"  a:mode   the mode that has been chosen by pressing <cr> <c-v> <c-t> or <c-x>
"           the values are 'e', 'v', 't' and 'h', respectively
"  a:str    the selected string
"
function! ctrlp#sw_profiles#accept(mode, str)
    let command = sw#get_connect_command(a:str)
    call sw#sqlwindow#connect_buffer('e', s:current_buffer)
    call sw#sqlwindow#execute_macro(command)
    let s:current_buffer = ''
    if exists('s:position')
        call setpos('.', s:position)
    endif
endfunction

" (optional) Do something after exiting ctrlp
function! ctrlp#sw_profiles#exit()
    call ctrlp#exit()
endfunction

function! ctrlp#sw_profiles#init()
    let file = ctrlp#utils#cachedir() . '/sw_profiles'
    if !filereadable(file)
        sil! cal ctrlp#progress('Indexing...')
        call sw#profiles#update('')
        while !filereadable(file)
            sleep 300m
        endwhile
    endif
    let profiles = sw#cache_get('profiles')

    let result = []
    for key in keys(profiles)
        call add(result, key)
    endfor
    return result
endfunction

function! ctrlp#sw_profiles#clear_cache()
    call delete(ctrlp#utils#cachedir() . '/sw_profiles')
endfunction

" Give the extension an ID
let s:id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)

" Allow it to be called later
function! ctrlp#sw_profiles#id()
	return s:id
endfunction

function! ctrlp#sw_profiles#enter()
    let s:current_buffer = sw#bufname('%')
    let name = sw#sqlwindow#get_resultset_name()
    call sw#goto_window(name)
    if sw#bufname('%') == name
        bwipeout 
        let s:current_buffer = sw#bufname('%')
    endif
    let s:position = getcurpos()
endfunction

" vim:nofen:fdl=0:ts=4:sw=4:sts=4
