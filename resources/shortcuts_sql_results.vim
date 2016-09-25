""execute "setlocal <M-i>=\ei"
""execute "setlocal <M-s>=\es"
""execute "setlocal <M-m>=\em"
""execute "setlocal <M-d>=\ed"
nmap <buffer> <C-i> :SWSqlObjectInfo<cr>
nmap <buffer> <Leader>os :SWSqlObjectSource<cr>
nmap <buffer> <C-m> :SWSqlToggleMessages<cr>
nmap <buffer> <Leader>d :SWSqlToggleFormDisplay<cr>

