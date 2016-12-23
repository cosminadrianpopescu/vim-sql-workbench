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

if !exists('g:sw_switch_to_results_tab')
    let g:sw_switch_to_results_tab = 0
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

if !exists('g:sw_highlight_resultsets')
    let g:sw_highlight_resultsets = 1
endif

if !exists('g:sw_save_resultsets')
    let g:sw_save_resultsets = 0
endif

if !exists('g:sw_log_to_file')
    let g:sw_log_to_file = 0
endif

if !exists('g:sw_command_timer')
    let g:sw_command_timer = 1
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

if exists('g:extra_sw_tabs')
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
endif

if exists('g:extra_sw_panels')
    for key in keys(g:SW_Tabs)
        let tabs = g:SW_Tabs[key]

        for tab in tabs
            for shortcut in keys(g:extra_sw_panels)
                let panels = g:extra_sw_panels[shortcut]

                for panel in panels
                    if tab['shortcut'] == shortcut && key == panel['profile']
                        call add(tab['panels'], panel['panel'])
                    endif
                endfor
            endfor
        endfor
    endfor
endif

command! -nargs=+ -complete=customlist,sw#autocomplete_profile SWDbExplorer call sw#dbexplorer#show_panel(<f-args>)
command! -nargs=? SWDbExplorerClose call sw#dbexplorer#hide_panel(<f-args>)
command! SWDbExplorerReconnect call sw#dbexplorer#reconnect()
command! SWDbExplorerToggleFormDisplay call sw#dbexplorer#toggle_form_display()
command! -nargs=* -complete=file SWSqlBufferConnect call sw#server#connect_buffer(g:sw_sqlopen_command, <f-args>)
command! -nargs=* -complete=file SWSqlBufferDisconnect call sw#server#disconnect_buffer()
command! SWSqlExecuteCurrent call sw#sqlwindow#execute_sql(sw#sqlwindow#extract_current_sql())
command! SWSqlExecuteSelected call sw#sqlwindow#execute_sql(sw#sqlwindow#extract_selected_sql())
command! SWSqlExecuteAll call sw#sqlwindow#execute_sql(sw#sqlwindow#extract_all_sql())
command! SWSqlRefreshResultSet call sw#sqlwindow#refresh_resultset()
command! SWSqlDeleteResultSet call sw#sqlwindow#delete_resultset()
command! -nargs=0 SWSqlGetSqlCount call sw#sqlwindow#get_count(sw#sqlwindow#extract_current_sql())
command! -nargs=0 SWSqlGetObjRows call sw#sqlwindow#get_count(expand('<cword>'))
command! -nargs=0 SWSqlShowActiveConnections echo sw#server#get_active_connections()
command! -nargs=0 SWSqlShowLog call sw#sqlwindow#show_current_buffer_log()
command! -nargs=* SWSqlExecuteMacro call sw#sqlwindow#execute_macro(<f-args>)
command! -nargs=0 SWSqlShowLastResultset call sw#sqlwindow#open_resulset_window()
command! SWSqlToggleMessages call sw#sqlwindow#toggle_messages()
command! SWSqlToggleFormDisplay call sw#sqlwindow#toggle_display()
command! SWSqlObjectInfo call sw#sqlwindow#get_object_info()
command! SWSqlObjectSource call sw#sqlwindow#get_object_source()
command! SWSqlExport call sw#sqlwindow#export_last()
command! -nargs=+ SWSqlExecuteNow call sw#cmdline#execute(b:sw_channel, <f-args>)
command! -nargs=0 SWSqlExecuteNowLastResult call sw#cmdline#show_last_result()
command! -nargs=+ SWSearchObject call sw#search#object(<f-args>)
command! SWSearchObjectAdvanced call sw#search#object()
command! -nargs=1 SWSearchObjectDefaults call sw#search#object_defaults(<f-args>)
command! -nargs=+ SWSearchData call sw#search#data(<f-args>)
command! SWSearchDataAdvanced call sw#search#data()
command! -nargs=1 SWSearchDataDefaults call sw#search#data_defaults(<f-args>)
command! -bang -nargs=* SWSqlAutocomplete call sw#autocomplete#cache(<bang>0, <f-args>)
command! -nargs=1 -complete=customlist,sw#autocomplete#complete_cache_name SWSqlAutocompleteLoad call sw#autocomplete#load(<f-args>)
command! -nargs=1 -complete=customlist,sw#autocomplete#complete_cache_name SWSqlAutocompletePersist call sw#autocomplete#persist(<f-args>)
command! -nargs=0 SWSqlShowAllColumns call sw#sqlwindow#show_all_columns()
command! -nargs=1 -complete=customlist,sw#sqlwindow#complete_columns SWSqlShowOnlyColumn call sw#sqlwindow#show_only_column(<f-args>)
command! -nargs=+ -complete=customlist,sw#sqlwindow#complete_columns SWSqlShowOnlyColumns call sw#sqlwindow#show_only_columns([<f-args>])
command! -nargs=1 -complete=customlist,sw#sqlwindow#complete_columns SWSqlShowColumn call sw#sqlwindow#show_column(<f-args>, 1)
command! -nargs=1 -complete=customlist,sw#sqlwindow#complete_columns SWSqlHideColumn call sw#sqlwindow#hide_column(<f-args>, 1)
command! -nargs=1 -complete=customlist,sw#sqlwindow#complete_columns SWSqlFilterColumn call sw#sqlwindow#filter_column(<f-args>)
command! -nargs=1 -complete=customlist,sw#sqlwindow#complete_columns SWSqlUnfilterColumn call sw#sqlwindow#un_filter_column(<f-args>)
command! -nargs=0 SWSqlRemoveAllFilters call sw#sqlwindow#remove_all_filters()
command! -bang -nargs=0 SWSqlWipeoutResultsSets call sw#sqlwindow#wipeout_resultsets(<bang>0)

command! -nargs=+ -complete=customlist,sw#autocomplete_profile SWServerStart call sw#server#run(<f-args>)
command! -nargs=1 SWServerStop call sw#server#stop(<f-args>)

augroup sw
autocmd sw BufDelete,BufWipeout * call sw#session#sync()
autocmd sw SessionLoadPost * call sw#session#restore()
""autocmd sw BufEnter * call sw#sqlwindow#close_all_result_sets()
""autocmd sw BufEnter * call sw#session#check()
""autocmd sw TabEnter * call sw#dbexplorer#restore_from_session()

