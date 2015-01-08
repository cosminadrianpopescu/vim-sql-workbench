execute "setlocal <M-i>=\ei"
execute "setlocal <M-s>=\es"
execute "setlocal <M-m>=\em"
execute "setlocal <M-d>=\ed"
nmap <buffer> <C-A> :SWSqlExecuteAll<cr>
nmap <buffer> <M-i> :SWSqlObjectInfo<cr>
nmap <buffer> <M-s> :SWSqlObjectSource<cr>
nmap <buffer> <M-m> :SWSqlToggleMessages<cr>
nmap <buffer> <M-d> :SWSqlToggleFormDisplay<cr>

