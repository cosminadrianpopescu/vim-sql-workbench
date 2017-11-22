function! s:get_name()
    return g:sw_cache . '/' . 'profiles.vim'
endfunction

function! sw#profiles#update(channel)
    call sw#background#run('', 'wbabout;', 'sw#profiles#about')
endfunction

function! s:process(stylesheet, inputfile, output)
    let cmd = 'wbxslt -stylesheet=' . a:stylesheet . ' -inputfile=' . a:inputfile . ' -xsltoutput=' . a:output . ';'
    call sw#background#run('', cmd, 'sw#profiles#finish')
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
        call s:process(stylesheet, inputfile, output)

        let output = g:sw_cache . '/macros.vim'
        let inputfile = substitute(inputfile, '\v\cwbprofiles\.xml$', 'WbMacros.xml', 'g')
        let stylesheet = sw#script_path() . 'resources/macros2vim.xslt'
        call s:process(stylesheet, inputfile, output)
    endif
endfunction

function! sw#profiles#finish(profile, txt)
    if !(a:txt =~ 'XSLT transformation.*finished successfully')
        call sw#display_error("There was a problem fetching the profiles for Sql Workbench (maybe the g:sw_cache) variable is not set? Please note that you need to either create the default folder (~/.cache/sw) either to set the variable to an existing folder for autocomplete or CtrlP integration to work")
        call sw#display_error("The output of the command was " . a:txt)
    endif
endfunction
