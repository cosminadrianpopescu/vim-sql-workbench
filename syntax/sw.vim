syn match SWResultsetHeader '\v^([\=]SQL ([0-9]+).*|[\=]+|Query returned [0-9]+ rows)$'
syn match SWResultsetHiddenColumns '\v\(Hidden columns: ([^\)]+)\)'
syn match SWResultsetHiddenColumns '\v\(Filters: ([^\)]+)\)'
syn match SWResultsetColumns '\v^(.*)\n[\-+]+\n'
syn match SWResultsetOracleError '\v\c\v^Error at line.*\n\_.{-}Execution time:.*$'

hi link SWResultsetHeader Comment
hi link SWResultsetHiddenColumns Label
hi link SWResultsetHiddenFilters Label
hi link SWResultsetOracleError Error
hi SWResultsetColumns term=underline cterm=NONE ctermbg=160 ctermfg=154 gui=NONE guibg=#ff0000 guifg=#808080
