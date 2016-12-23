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
let s:nvim = has("nvim")
let s:channel_handlers = {}
let s:pattern_prompt_begin = '\v^([a-zA-Z_0-9\.]+(\@[a-zA-Z_0-9\/\-]+)*\>[ \s\t]*)+'
let s:pattern_prompt = s:pattern_prompt_begin . '$'
let s:pattern_wait_input = '\v^([a-zA-Z_][a-zA-Z0-9_]*( \[[^\]]+\])?: |([^\>]+\> )?([^\>]+\> )*Username|([^\>]+\> )*Password: |([^\>]+\>[ ]+)?Do you want to run the command [A-Z]+\? \(Yes\/No\/All\)[ ]+)$'
let s:params_history = []
let s:pattern_new_connection = '\v^Connection to "([^"]+)" successful$'
let s:timer = {'id': -1, 'sec' : 0}

function! sw#server#get_channel_pid(vid, channel, message)
    for handler_item in items(s:channel_handlers)
        let handler = handler_item[1]
        if handler.vid == a:vid
            for line in split(a:message, '\v[\r\n]')
                let pattern = '\v^([0-9]+) .*vid\=' . a:vid . '$'
                if line =~ pattern
                    let handler.pid = substitute(line, pattern, '\1', 'g')
                    return
                endif
            endfor
        endif
    endfor
endfunction

function! s:get_channel_pid(channel)
    let cmd = 'jps -m'
    if !s:nvim
        let Func = function('sw#server#get_channel_pid', [s:channel_handlers[a:channel].vid])
        let job = job_start(cmd, {'in_mode': 'raw', 'out_mode': 'raw'})
        let channel = job_getchannel(job)
        call ch_setoptions(channel, {'callback': Func})
    else
        let job = jobstart(cmd, {'on_stdout': function('sw#server#nvim_get_channel_pid')})
    endif
endfunction

function! s:log_init(channel)
    if g:sw_log_to_file
        let s:channel_handlers[a:channel].log = g:sw_tmp . '/' . sw#servername() . '-' . substitute(fnamemodify(bufname('%'), ':t'), '\.', '-', 'g')
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

function! sw#server#nvim_handle_message(job, lines, ev)
    if a:ev == 'stdout'
        let msg = ''
        for line in a:lines
            let msg .= (msg == '' ? '' : "\n") . line
        endfor

        call sw#server#handle_message(a:job, msg)
    elseif a:ev == 'exit'
        call sw#server#disconnect_buffer(a:job)
    endif
endfunction

function! sw#server#prompt_for_value(channel, line, timer_id)
    let value = input('SQL Workbench/J is asking for input for ' . a:line . ' ', '')
    call add(s:params_history, {'prompt': a:line, 'value': value})
    call ch_sendraw(a:channel, value . "\n")
endfunction

function! sw#server#handle_message(channel, msg)
    if has_key(s:channel_handlers[a:channel], 'pid') && s:channel_handlers[a:channel].pid == ''
        call s:get_channel_pid(a:channel)
    endif
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
            if s:nvim
                let value = input('SQL Workbench/J is asking for input for ' . line . ' ', '')
                call add(s:params_history, {'prompt': line, 'value': value})
                call jobsend(b:sw_channel, value . "\n")
            else
                let Func = function('sw#server#prompt_for_value', [a:channel, line])
                let got_prompt = 1
                let timer_id = timer_start(500, Func)
            endif
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
    let vid = substitute(v:servername, '\v\/', '-', 'g') . sw#generate_unique_id()
    let cmd = [g:sw_exe, '-feedback=true', '-showProgress=false', '-showTiming=true', '-nosettings', '-variable=vid=' . vid]

    if exists('g:sw_config_dir')
        call add(cmd, '-configDir=' . g:sw_config_dir)
    endif

    let valid_exe = 1
    if !filereadable(g:sw_exe)
        echom g:sw_exe . " is not readable. Make sure the setting g:sw_exe is set and the file exists."
        let valid_exe = 0
    endif
    if match(getfperm(g:sw_exe), "r.x.*") ==# -1
        echom g:sw_exe . " is not executable. Make sure the permissions are set correctly."
        let valid_exe = 0
    endif

    if !valid_exe
        return
    endif

    if !s:nvim
        let job = job_start(cmd, {'in_mode': 'raw', 'out_mode': 'raw'})
        let pid = substitute(job, '\v^process ([0-9]+).*$', '\1', 'g')
        let pid = ''
        let channel = job_getchannel(job)
        call ch_setoptions(channel, {'callback': 'sw#server#handle_message', 'close_cb': 'sw#server#disconnect_buffer'})
    else
        let channel = jobstart(cmd, {'on_stdout': function('sw#server#nvim_handle_message'), 'on_stderr': function('sw#server#nvim_handle_message'), 'on_exit': function('sw#server#nvim_handle_message')})
        let pid = jobpid(channel)
    endif

    let s:channel_handlers[channel] = {'text': '', 'type': a:type, 'buffer': fnamemodify(bufname('%'), ':p'), 'current_url': '', 'tmp_handler': '', 'vid': vid, 'pid': pid}
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
    if !s:nvim
        if ch_status(channel) != 'open'
            call sw#display_error("The channel is not open. This means that SQL Workbench/J instance for this answer does not responsd anymore. Please do again SWSqlBufferConnect")
            if exists('b:sw_channel')
                unlet b:sw_channel
            endif
            return ''
        endif
    endif
    let text = a:sql . "\n"
    call s:log_channel(channel, text)
    if callback != ''
        let s:channel_handlers[channel].tmp_handler = callback
    endif
    if s:nvim
        call jobsend(channel, text)
    else
        call ch_sendraw(channel, text)
    endif
    if g:sw_command_timer
        call s:init_timer()
        let s:timer.id = timer_start(1000, 'sw#server#timer', {'repeat': -1})
    endif
endfunction

function! s:init_timer()
    if s:timer.id != -1
        call timer_stop(s:timer.id)
    endif
    let s:timer = {'id': -1, 'sec': 0}
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
    if channel == ''
        return
    endif
    if (!s:nvim && ch_status(channel) == 'open') || s:nvim
        try
            call sw#server#execute_sql('exit', channel)
        catch
        endtry
    endif
    let key = substitute(channel, '\v^channel ([0-9]+).*$', 'channel \1 open', 'g')
    if has_key(s:channel_handlers, key)
        unlet s:channel_handlers[key]
    endif
    call s:init_timer()

    if exists('g:sw_airline_support') && g:sw_airline_support == 1
        call airline#update_statusline()
    endif
endfunction

function! sw#server#kill_statement(...)
    let channel = ''
    if exists('b:sw_channel')
        let channel = b:sw_channel
    endif
    if a:0
        let channel = a:1
    endif

    if has_key(s:channel_handlers, channel) && has_key(s:channel_handlers[channel], 'pid')
        let cmd = 'kill -SIGINT ' . s:channel_handlers[channel].pid
        if !s:nvim
            call job_start(cmd)
        else
            call jobstart(cmd)
        endif
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

function! sw#server#get_parameters_history()
    return s:params_history
endfunction
