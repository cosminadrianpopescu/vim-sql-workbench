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

    if (inputfile == '') 
        return 
    endif

    let output = g:sw_cache . '/macros.vim'
    let macrosfile = substitute(inputfile, '\v\c^(.*)\/[^\/]+$', '\1/WbMacros.xml', 'g')
    if (filereadable(macrosfile))
        let stylesheet = sw#script_path() . 'resources/macros2vim.xslt'
        call s:process(stylesheet, macrosfile, output)
    endif

    if inputfile =~ '\v\cxml$'
        let stylesheet = sw#script_path() . 'resources/profiles2vim.xslt'
        let output = s:get_name()
        call s:process(stylesheet, inputfile, output)

        return
    endif

    if inputfile =~ '\v\cproperties$'
        let profiles = {}
        let lines = readfile(inputfile)
        for line in lines
            if line == ''
                continue
            endif
            let p = '\v\c^[^\.]+\.([^\.]+)\.([^\=]+)\=(.*)$'
            let id = substitute(line, p, '\1', 'g')
            let prop = substitute(line, p, '\2', 'g')
            let value = substitute(line, p, '\3', 'g')

            if (!has_key(profiles, id))
                let profiles[id] = {}
            endif

            if (prop == 'name' || prop == 'drivername' || prop == 'group' || prop == 'connection.properties')
                let profiles[id][prop] = substitute(value, "\\v'", "''", 'g')
            endif
        endfor

        let lines = ['let b:profiles = {}']

        for key in keys(profiles)
            let p = profiles[key]
            let name = tolower(substitute(p['name'], "\\v'", "''", 'g'))
            call add(lines, "let b:profiles['" . name . "'] = {}")
            call add(lines, "let b:profiles['" . name . "']['name'] = '" . name . "'")
            call add(lines, "let b:profiles['" . name . "']['type'] = '" . p['drivername'] . "'")
            let group = ''
            if has_key(p, 'group')
                let group = p['group']
            endif
            call add(lines, "let b:profiles['" . name . "']['group'] = '" . group . "'")

            call add(lines, "let b:profiles['" . name . "']['props'] = {}")

            if has_key(p, 'connection.properties')
                let matches = []
                call substitute(p['connection.properties'], '\c\ventry key\="([^"]+)"\>([^\<]+)\<', '\=add(matches, [submatch(1), submatch(2)])', 'g')
                for match in matches
                    call add(lines, "let b:profiles['" . name . "']['props']['" . match[0] . "'] = '" . match[1] . "'")
                endfor
            endif
        endfor
        let output = s:get_name()
        call writefile(lines, output)
    endif
endfunction

function! sw#profiles#finish(profile, txt)
    if !(a:txt =~ 'XSLT transformation.*finished successfully')
        call sw#display_error("There was a problem fetching the profiles for Sql Workbench (maybe the g:sw_cache) variable is not set? Please note that you need to either create the default folder (~/.cache/sw) either to set the variable to an existing folder for autocomplete or CtrlP integration to work")
        call sw#display_error("The output of the command was " . a:txt)
    elseif exists('g:loaded_ctrlp') && g:loaded_ctrlp == 1
        call writefile([], ctrlp#utils#cachedir() . '/sw_profiles')
    endif
endfunction
