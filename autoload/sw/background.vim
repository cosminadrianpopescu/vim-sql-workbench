let s:channels = {}

" Runs a command in background
" (this means with a completely new connection, independent of the current
" one)
function! sw#background#run(profile, cmd, handler)
    let channel = sw#server#start_sqlwb('sw#background#message_handler', 1)
    let s:channels[channel] = {'profile': a:profile, 'txt': '', 'handler': a:handler}
    ""call ch_setoptions(channel, {'close_cb': 'sw#background#close'})
    if a:profile != ''
        let command = sw#get_connect_command(a:profile)
        call sw#server#execute_sql(command, channel)
    endif
    call sw#server#execute_sql(a:cmd, channel)
    call sw#server#execute_sql('exit', channel)
endfunction

function! sw#background#message_handler(channel, message)
    if has_key(s:channels, a:channel)
        let s:channels[a:channel].txt .= a:message
    endif
endfunction

function! sw#background#close(args)
    let channel = sw#find_channel(s:channels, a:args.channel)

    if channel != ''
        let Func = function(s:channels[channel].handler)
        call Func(s:channels[channel].profile, s:channels[channel].txt)
    endif
endfunction

call sw#server#add_event('exit', 'sw#background#close')
