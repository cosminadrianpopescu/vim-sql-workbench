execute "setlocal <M-i>=\ei"
execute "setlocal <M-m>=\em"
execute "setlocal <M-s>=\es"
nmap <buffer> <C-A> :SWSqlExecuteAll<cr>
vmap <buffer> <C-e> :<bs><bs><bs><bs><bs>SWSqlExecuteSelected<cr>
nmap <buffer> <C-@> :SWSqlExecuteCurrent<cr>
imap <buffer> <C-@> <Esc>:SWSqlExecuteCurrent<cr>
nmap <buffer> <M-i> :SWSqlObjectInfo<cr>
nmap <buffer> <M-s> :SWSqlObjectSource<cr>
nmap <buffer> <M-m> <C-w>b:SWSqlToggleMessages<cr><C-w>t
nmap <buffer> <C-c> :SWKillCurrentCommand<cr>

