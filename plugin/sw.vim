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

"if exists('g:loaded_vim_sql_workbench') || v:version < 700
"  finish
"endif

let g:loaded_vim_sql_workbench = 1

let g:session_restored = 0

if !exists('g:sw_search_default_regex')
    let g:sw_search_default_regex = 'Y'
endif

if !exists('g:sw_search_default_match_all')
    let g:sw_search_default_match_all = 'Y'
endif

if !exists('g:sw_search_default_ignore_case')
    let g:sw_search_default_ignore_case = 'Y'
endif

if !exists('g:sw_search_default_types')
    let g:sw_search_default_types = 'LOCAL TEMPORARY,TABLE,VIEW,FUNCTION,PROCEDURE,TRIGGER,SYNONYM'
endif

if !exists('g:sw_search_default_data_types')
    let g:sw_search_default_data_types = 'TABLE,VIEW'
endif

if !exists('g:sw_search_default_exclude_lobs')
    let g:sw_search_default_exclude_lobs = 'Y'
endif

if !exists('g:sw_search_default_tables')
    let g:sw_search_default_tables = '%'
endif

if !exists('g:sw_search_default_exclude_tables')
    let g:sw_search_default_exclude_tables = ''
endif

if !exists('g:sw_search_default_objects')
    let g:sw_search_default_objects = '%'
endif

if !exists('g:sw_search_default_result_columns')
    let g:sw_search_default_result_columns = ''
endif

if !exists('g:sw_search_default_compare_types')
    let g:sw_search_default_compare_types = 'contains'
endif

if !exists('g:sw_autocomplete_cache_dir')
    let g:sw_autocomplete_cache_dir = $HOME . '/.cache/sw'
endif

if (!exists('g:sw_delimiter'))
    let g:sw_delimiter = ';'
endif

if !exists('g:sw_sqlopen_command')
    let g:sw_sqlopen_command = 'e'
endif

if (!exists('g:sw_default_right_panel_type'))
    let g:sw_default_right_panel_type = 'txt'
endif

if (!exists('g:sw_open_export'))
    let g:sw_open_export = 'soffice'
endif

if (!exists('g:sw_exe'))
    let g:sw_exe = 'sqlwbconsole.sh'
endif

if (!exists('g:sw_tmp'))
    let g:sw_tmp = '/tmp'
endif

if !exists('g:sw_bufexplorer_new_tab')
    let g:sw_bufexplorer_new_tab = 1
endif

if !exists('g:sw_bufexplorer_left_extratabs')
    let g:sw_bufexplorer_left_extratabs = []
endif

if !exists('g:sw_bufexplorer_right_extratabs')
    let g:sw_bufexplorer_right_extratabs = []
endif

if !exists('g:sw_shortcuts_sql_buffer_statement')
    let g:sw_shortcuts_sql_buffer_statement = 'default'
endif

if !exists('g:sw_shortcuts_sql_results')
    let g:sw_shortcuts_sql_results = 'default'
endif

if (!exists('g:extra_sw_tabs'))
    let g:extra_sw_tabs = {}
endif

if !exists('g:vim_exe')
    let g:sw_vim_exe = 'vim'
endif

if !exists('g:sw_tab_switches_between_bottom_panels')
	let g:sw_tab_switches_between_bottom_panels = 1
endif

"if !exists('g:sw_overwrite_current_command')
"    let g:sw_overwrite_current_command = 0
"endif

let g:sw_instance_id = localtime()

if !exists('g:sw_dbexplorer_panel')
    let file = expand('<sfile>:p:h') . '/../resources/dbexplorer.vim'
    execute "so " . file
else
    execute "so " . g:sw_dbexplorer_panel
endif

for _profile in items(g:extra_sw_tabs)
    let profile = _profile[0]
    let tabs = _profile[1]
    if (!has_key(g:SW_Tabs, profile))
        let g:SW_Tabs[profile] = []
    endif
    for tab in tabs
        call add(g:SW_Tabs[profile], tab)
    endfor
endfor

command! -nargs=+ -complete=customlist,sw#autocomplete_profile SWDbExplorer call sw#dbexplorer#show_panel(<f-args>)
command! -nargs=? SWDbExplorerClose call sw#dbexplorer#hide_panel(<f-args>)
command! SWDbExplorerRestore call sw#session#restore_dbexplorer()
command! SWDbExplorerReconnect call sw#dbexplorer#reconnect()
command! -nargs=+ -complete=file SWSqlConnectToServer call sw#server#connect_buffer(<f-args>, g:sw_sqlopen_command)
command! -bang SWSqlExecuteCurrent call sw#sqlwindow#execute_sql(<bang>1, sw#sqlwindow#extract_current_sql())
command! -bang SWSqlExecuteSelected call sw#sqlwindow#execute_sql(<bang>1, sw#sqlwindow#extract_selected_sql())
command! -bang SWSqlExecuteAll call sw#sqlwindow#execute_sql(<bang>1, sw#sqlwindow#extract_all_sql())
command! SWSqlToggleMessages call sw#sqlwindow#toggle_messages()
command! SWSqlToggleFormDisplay call sw#sqlwindow#toggle_display()
command! SWSqlObjectInfo call sw#sqlwindow#get_object_info()
command! SWSqlObjectSource call sw#sqlwindow#get_object_source()
command! SWSqlExport call sw#sqlwindow#export_last()
command! -bang -nargs=+ SWSearchObject call sw#search#object(<bang>1, <f-args>)
command! -bang SWSearchObjectAdvanced call sw#search#object(<bang>1)
command! -bang -nargs=1 SWSearchObjectDefaults call sw#search#object_defaults(<bang>1, <f-args>)
command! -bang -nargs=+ SWSearchData call sw#search#data(<bang>1, <f-args>)
command! -bang SWSearchDataAdvanced call sw#search#data(<bang>1)
command! -bang -nargs=1 SWSearchDataDefaults call sw#search#data_defaults(<bang>1, <f-args>)
command! -bang -nargs=* SWSqlAutocomplete call sw#autocomplete#cache(<bang>0, <f-args>)
command! -nargs=1 -complete=customlist,sw#autocomplete#complete_cache_name SWSqlAutocompleteLoad call sw#autocomplete#load(<f-args>)
command! -nargs=1 -complete=customlist,sw#autocomplete#complete_cache_name SWSqlAutocompletePersist call sw#autocomplete#persist(<f-args>)
command! SWSqlBufferRestore call sw#session#restore_sqlbuffer()

command! -nargs=+ -complete=customlist,sw#variables#autocomplete_names SWVarSet call sw#variables#set(<f-args>, '')
command! -nargs=1 -complete=customlist,sw#variables#autocomplete_names SWVarUnset call sw#variables#unset(<f-args>)
command! -nargs=0 SWVarDisable call sw#variables#disable()
command! -nargs=0 SWVarEnable call sw#variables#enable()
command! -nargs=0 SWVarList call sw#variables#list()

command! -nargs=+ -complete=customlist,sw#autocomplete_profile SWServerStart call sw#server#run(<f-args>)
command! -nargs=1 SWServerStop call sw#server#stop(<f-args>)

augroup sw
autocmd sw BufDelete,BufWipeout * call sw#session#sync()
autocmd sw SessionLoadPost * call sw#session#restore()
autocmd sw BufEnter * call sw#sqlwindow#close_all_result_sets()
""autocmd sw BufEnter * call sw#session#check()
""autocmd sw TabEnter * call sw#dbexplorer#restore_from_session()

