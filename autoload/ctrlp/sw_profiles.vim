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
    call sw#server#connect_buffer('e', s:current_buffer)
    call sw#sqlwindow#execute_sql(command)
    let s:current_buffer = ''
endfunction

" (optional) Do something after exiting ctrlp
function! ctrlp#sw_profiles#exit()
    call ctrlp#exit()
endfunction

function! ctrlp#sw_profiles#init()
    let profiles = sw#parse_profile_xml()

    let result = []
    for key in keys(profiles)
        call add(result, key)
    endfor
    return result
endfunction

" Give the extension an ID
let s:id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)

" Allow it to be called later
function! ctrlp#sw_profiles#id()
	return s:id
endfunction

function! ctrlp#sw_profiles#enter()
    let s:current_buffer = bufname('%')
    let name = sw#sqlwindow#get_resultset_name()
    call sw#goto_window(name)
    if bufname('%') == name
        bwipeout 
        let s:current_buffer = bufname('%')
    endif
endfunction

" vim:nofen:fdl=0:ts=4:sw=4:sts=4
