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

if !exists('g:sw_cache')
    let g:sw_cache = $HOME . '/.cache/sw'
    if !isdirectory(g:sw_cache)
        call mkdir(g:sw_cache, "p")
    endif
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

if !exists('g:sw_autocomplete')
    let g:sw_autocomplete = 1
endif

if !exists('g:sw_sql_name_result_tab')
    let g:sw_sql_name_result_tab = 1
endif

if !exists('g:sw_prefer_sql_over_macro')
    let g:sw_prefer_sql_over_macro = 0
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

command! -nargs=1 -complete=customlist,sw#autocomplete_profile SWDbExplorer call sw#dbexplorer#show_panel(<f-args>)
command! -nargs=? SWDbExplorerClose call sw#dbexplorer#hide_panel(<f-args>)
command! SWDbExplorerReconnect call sw#dbexplorer#reconnect()
command! SWDbExplorerToggleFormDisplay call sw#dbexplorer#toggle_form_display()
command! -nargs=1 -complete=buffer SWSqlBufferShareConnection call sw#sqlwindow#share_connection(bufnr(<f-args>))
command! -nargs=* -complete=file SWSqlBufferConnect call sw#sqlwindow#connect_buffer(g:sw_sqlopen_command, <f-args>)
command! -nargs=* -complete=file SWSqlBufferDisconnect call sw#server#disconnect_buffer()
command! -bang SWSqlExecuteCurrent call sw#sqlwindow#execute_sql(sw#sqlwindow#extract_current_sql(0, <bang>0))
command! -bang SWSqlExecuteSelected call sw#sqlwindow#execute_sql(sw#sqlwindow#extract_selected_sql(<bang>0))
command! SWSqlExecuteAll call sw#sqlwindow#execute_sql(sw#sqlwindow#extract_all_sql())
command! SWSqlRefreshResultSet call sw#sqlwindow#refresh_resultset()
command! SWSqlDeleteResultSet call sw#sqlwindow#delete_resultset()
command! -nargs=0 SWSqlGetSqlCount call sw#sqlwindow#get_count(sw#sqlwindow#extract_current_sql())
command! -nargs=0 SWSqlGetObjRows call sw#sqlwindow#get_count(expand('<cword>'))
command! -nargs=0 SWSqlShowActiveConnections echo sw#server#get_active_connections()
command! -nargs=0 SWSqlShowLog call sw#sqlwindow#show_current_buffer_log()
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
command! -nargs=0 SWSqlShowAllColumns call sw#sqlwindow#show_all_columns()
command! -nargs=0 CtrlPSW call ctrlp#init(ctrlp#sw_profiles#id())
command! -nargs=0 CtrlPClearSWCache call ctrlp#sw_profiles#clear_cache()
command! -nargs=+ -complete=customlist,sw#sqlwindow#complete_columns SWSqlShowOnlyColumns call sw#sqlwindow#show_only_columns([<f-args>])
command! -nargs=1 -complete=customlist,sw#sqlwindow#complete_columns SWSqlShowColumn call sw#sqlwindow#show_column(<f-args>)
command! -nargs=1 -complete=customlist,sw#sqlwindow#complete_columns SWSqlHideColumn call sw#sqlwindow#hide_column(<f-args>, 1)
command! -nargs=? -complete=customlist,sw#sqlwindow#complete_refs SWSqlReferences call sw#sqlwindow#go_to_ref('SWSqlReferences', <f-args>)
command! -nargs=? -complete=customlist,sw#sqlwindow#complete_refs SWSqlReferencedBy call sw#sqlwindow#go_to_ref('SWSqlReferencedBy', <f-args>)
command! -nargs=1 -complete=customlist,sw#sqlwindow#complete_columns SWSqlFilter call sw#sqlwindow#filter_with_sql(<f-args>)
command! -nargs=0 SWSqlUnFilter call sw#sqlwindow#remove_all_filters()
command! -bang -nargs=+ -complete=customlist,sw#sqlwindow#complete_insert SWSqlGenerateInsert call sw#sqlwindow#generate_insert([<f-args>], <bang>0)
command! -nargs=0 SWSqlGetMacroSql call sw#to_clipboard(sw#sqlwindow#get_macro_sql(expand('<cword>')))
command! -nargs=0 SWSqlInsertMatch call sw#sqlwindow#match()
command! -bang -nargs=0 SWSqlWipeoutResultsSets call sw#sqlwindow#wipeout_resultsets(<bang>0)
command! -bang -nargs=? -complete=file SWInclude call sw#sqlwindow#include(<bang>0, <f-args>)

command! -nargs=+ -complete=customlist,sw#autocomplete_profile SWServerStart call sw#server#run(<f-args>)
command! -nargs=1 SWServerStop call sw#server#stop(<f-args>)

augroup sw
autocmd sw BufDelete,BufWipeout * call sw#session#sync()
autocmd sw SessionLoadPost * call sw#session#restore()

call sw#server#add_event('profile_changed', 'sw#report#profile_changed')
call sw#server#add_event('new_instance', 'sw#profiles#update')
