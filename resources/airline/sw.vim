" MIT License. Copyright (c) 2013-2015 Bailey Ling.
" vim: et ts=2 sts=2 sw=2

" Due to some potential rendering issues, the use of the `space` variable is
" recommended.
let g:sw_airline_support = 1
let s:spc = g:airline_symbols.space
let s:airline_section_c = ''

" First we define an init function that will be invoked from extensions.vim
function! airline#extensions#sw#init(ext)
  " Here we define a new part for the plugin.  This allows users to place this
  " extension in arbitrary locations.
  call a:ext.add_statusline_func('airline#extensions#sw#apply')
endfunction

" This function will be invoked just prior to the statusline getting modified.
function! airline#extensions#sw#apply(...)
  if s:airline_section_c == ''
    let s:airline_section_c = g:airline_section_c
  endif

  if exists('b:sw_channel')
    let url = sw#server#get_buffer_url(fnamemodify(sw#bufname('%'), ':p'))
    if url != ''
      let g:airline_section_c = s:airline_section_c . s:spc . g:airline_left_alt_sep . s:spc . url
      return
    else
      let g:airline_section_c = s:airline_section_c . s:spc . g:airline_left_alt_sep . s:spc . 'NOT CONNECTED'
      return 
    endif
  endif

  if (s:airline_section_c != '')
    let g:airline_section_c = s:airline_section_c
  endif
endfunction

function! airline#extensions#sw#on_exit(channel)
  call airline#update_statusline()
endfunction


call sw#server#add_event('exit', 'airline#extensions#sw#on_exit')
