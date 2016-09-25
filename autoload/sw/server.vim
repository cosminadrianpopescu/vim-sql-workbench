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

let s:current_file = expand('<sfile>:p:h')
let s:channel_handlers = {}
let s:pattern_prompt_begin = '\v^([a-zA-Z_0-9\.]+(\@[a-zA-Z_0-9\/\-]+)*\>[ \s\t]*)+'
let s:pattern_prompt = s:pattern_prompt_begin . '$'
let s:pattern_wait_input = '\v^([a-zA-Z_][a-zA-Z0-9_]*( \[[^\]]+\])?: |([^\>]+\> )?([^\>]+\> )*Username|([^\>]+\> )*Password: |([^\>]+\>[ ]+)?Do you want to run the command UPDATE\? \(Yes\/No\/All\)[ ]+)$'
let s:pattern_new_connection = '\v^Connection to "([^"]+)" successful$'
let s:timer = {'id': '', 'sec' : 0}

function! s:log_init(channel)
    if g:sw_log_to_file
        let s:channel_handlers[a:channel].log = g:sw_tmp . '/' . v:servername . '-' . substitute(fnamemodify(bufname('%'), ':t'), '\.', '-', 'g')
    else
        let s:channel_handlers[a:channel].log = ''
    endif
endfunction

function! s:log_channel(channel, txt)
    if g:sw_log_to_file
        let file = s:channel_handlers[a:channel].log
        let mode = filereadable(file) ? 'ab' : 'wb'
        call writefile(split(a:txt, "\n"), file, mode)
    else
        let s:channel_handlers[a:channel].log .= a:txt
    endif
endfunction

function! sw#server#channel_log(channel)
    return s:channel_handlers[a:channel].log
endfunction

function! sw#server#handle_message(channel, msg)
    call s:log_channel(a:channel, a:msg)
    let lines = split(substitute(a:msg, "\r", "", 'g'), "\n")
    let got_prompt = 0
    let max_length = 0
    let text = ''
    for line in lines
        let line = substitute(line, '\v^(\.\.\> )*', '', 'g')
        let text .= (text == '' ? '' : "\n") . substitute(line, s:pattern_prompt_begin, '', 'g')
        if line =~ s:pattern_prompt
            let got_prompt = 1
        endif
        if line =~ s:pattern_wait_input && !(line =~ '\v^Catalog: $') && !(line =~ '\v^Schema: $')
            let value = input('SQL Workbench/J is asking for input for ' . line . ' ', 'abc')
            call ch_sendraw(b:sw_channel, value . "\n")
        endif

        if line =~ s:pattern_new_connection 
            let s:channel_handlers[a:channel].current_url = substitute(line, s:pattern_new_connection, '\1', 'g')
        endif
    endfor
    let s:channel_handlers[a:channel].text .= text . "\n"
    if got_prompt
        let type = s:channel_handlers[a:channel].type
        if (type == 'sqlwindow')
            if s:channel_handlers[a:channel].tmp_handler != ''
                let Func = function(s:channel_handlers[a:channel].tmp_handler)
                call Func(s:channel_handlers[a:channel].text)
                let s:channel_handlers[a:channel].tmp_handler = ''
            else
                call sw#sqlwindow#message_handler(a:channel, s:channel_handlers[a:channel].text)
            endif
        elseif (type == 'dbexplorer')
            call sw#dbexplorer#message_handler(a:channel, s:channel_handlers[a:channel].text)
        endif

        let s:channel_handlers[a:channel].text = ''
        call s:init_timer()
    endif
endfunction

function! s:start_sqlwb(type)
    let job = job_start(g:sw_exe . ' -feedback=true -showProgress=false -abortOnError=false -showTiming=true', {'in_mode': 'raw', 'out_mode': 'raw'})
    let channel = job_getchannel(job)
    call ch_setoptions(channel, {'callback': 'sw#server#handle_message'})
    let s:channel_handlers[channel] = {'text': '', 'type': a:type, 'buffer': fnamemodify(bufname('%'), ':p'), 'current_url': '', 'tmp_handler': ''}
    call s:log_init(channel)

    return channel
endfunction

function! sw#server#connect_buffer(...)
    let file = bufname('%')
    let command = 'e'
    if (a:0 >= 2)
        let file = a:2
        let command = a:1
    elseif a:0 >= 1
        let command = a:1
    endif

    execute command . " " . file
    call sw#session#init_section()

    if (!exists('b:sw_channel'))
        let b:sw_channel = s:start_sqlwb('sqlwindow')
    endif

    call sw#sqlwindow#open_buffer(file, command)
endfunction

function! sw#server#execute_sql(sql, ...)
    let channel = ''
    if (exists('b:sw_channel'))
        let channel = b:sw_channel
    endif
    let callback = ''
    if a:0 >= 2
        let channel = a:1
        let callback = a:2
    elseif a:0 >= 1
        let channel = a:1
    endif
    if ch_status(channel) != 'open'
        call sw#display_error("The channel is not open. This means that SQL Workbench/J instance for this answer does not responsd anymore. Please do again SWSqlBufferConnect")
        unlet b:sw_channel
        return ''
    endif
    let text = a:sql . "\n"
    call s:log_channel(channel, text)
    if callback != ''
        let s:channel_handlers[channel].tmp_handler = callback
    endif
    call ch_sendraw(channel, text)
    if g:sw_command_timer
        call s:init_timer()
        let s:timer.id = timer_start(1000, 'sw#server#timer', {'repeat': -1})
    endif
endfunction

function! s:init_timer()
    if s:timer.id != ''
        call timer_stop(s:timer.id)
    endif
    let s:timer = {'id': '', 'sec': 0}
endfunction

function! sw#server#timer(timer)
    let s:timer.sec += 1
    echo "Query time: " . s:timer.sec . " seconds"
endfunction

function! sw#server#disconnect_buffer(...)
    let channel = ''
    if (exists('b:sw_channel'))
        let channel = b:sw_channel
        unlet b:sw_channel
    endif
    if a:0
        let channel = a:1
    endif
    call sw#server#execute_sql('exit', channel)
    unlet s:channel_handlers[channel]
    call s:init_timer()

    if exists('g:sw_airline_support') && g:sw_airline_support == 1
        call airline#update_statusline()
    endif
endfunction

function! sw#server#get_buffer_url(buffer)
    for key in keys(s:channel_handlers)
        if s:channel_handlers[key]['buffer'] == a:buffer
            return s:channel_handlers[key]['current_url']
        endif
    endfor

    return ''
endfunction

function! sw#server#get_active_connections()
    let result = ''
    for key in keys(s:channel_handlers)
        let url = s:channel_handlers[key]['current_url']
        let result .= (result == '' ? '' : "\n") . s:channel_handlers[key]['buffer'] . ' - ' . (url == '' ? 'NOT CONNECTED' : url)
    endfor

    return result == '' ? 'No active sql workbench buffers' : result
endfunction

function! sw#server#tmp()
    return s:channel_handlers
endfunction

function! sw#server#open_dbexplorer(profile)
    let channel = s:start_sqlwb('dbexplorer')
    let command = sw#get_connect_command(a:profile)
    call sw#server#execute_sql(command, channel)

    return channel
endfunction
