""execute "setlocal <M-i>=\ei"
""execute "setlocal <M-m>=\em"
""execute "setlocal <M-s>=\es"
nmap <buffer> <Leader><C-A> :SWSqlExecuteAll<cr>
vmap <buffer> <Leader><C-e> :<bs><bs><bs><bs><bs>SWSqlExecuteSelected<cr>
nmap <buffer> <Leader><C-@> :SWSqlExecuteCurrent<cr>
nmap <buffer> <leader><C-m> :SWSqlExecuteMacro<cr>
nmap <buffer> <leader>os :SWSqlObjectSource<cr>
nmap <buffer> <leader>oi :SWSqlObjectInfo<cr>
nmap <buffer> <Leader><C-c> :SWSqlGetSqlCount<cr>

