function! s:get_name()
    return g:sw_autocomplete_cache_dir . '/' . 'profiles.vim'
endfunction

function! sw#profiles#update(channel)
    call sw#background#run('', 'wbabout;', 'sw#profiles#about')
endfunction

function! sw#profiles#about(profile, txt)
    let pattern = '\v^Connection profiles: (.*)$'
    let inputfile = ''
    for line in split(a:txt, '\v[\r\n]')
        if line =~ pattern
            let inputfile = substitute(line, pattern, '\1', 'g')
            break
        endif
    endfor

    if inputfile != ''
        let stylesheet = sw#script_path() . 'resources/profiles2vim.xslt'
        let output = s:get_name()
        let cmd = 'wbxslt -stylesheet=' . stylesheet . ' -inputfile=' . inputfile . ' -xsltoutput=' . output . ';'
        call sw#background#run('', cmd, 'sw#profiles#finish')
    endif
endfunction

function! sw#profiles#finish(profile, txt)
endfunction

function! sw#profiles#get()
    call sw#execute_file(s:get_name())
    return exists('b:profiles') ? b:profiles : {}
endfunction
