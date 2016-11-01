" General panel (for all DBMS) with the exception of PostgreSQL

let row_counts = {'title': 'Row Counts', 'shortcut': 'W', 'command': 'WbRowCount;', 'panels': []}

let sw_columns = {'title': 'Columns', 'shortcut': 'C', 'command': 'desc %object%;'}
let sw_sql_source = {'title': 'SQL Source', 'shortcut': 'S', 'command': 'WbGenerateScript -objects="%object%"', 'filetype': 'sql'}
let sw_sql_source_triggers = {'title': 'SQL Source', 'shortcut': 'S', 'command': 'wbtriggersource %object%', 'filetype': 'sql', 'hide_header': 1}
let sw_data = {'title': 'Data', 'shortcut': 'D', 'command': 'select * from %object%;', 'filetype': 'sw'}
let sw_data_filter = {'title': 'Filtered Data', 'shortcut': 'F', 'command': 'select * from %object% where $[?filter];', 'filetype': 'sw'}
let sw_indexes = {'title': 'Indexes', 'shortcut': 'I', 'command': 'WbListIndexes -tableName=%object%;'}
let sw_referenced_by = {'title': 'Referenced by', 'shortcut': 'R', 'command': 'WbGrepSource -searchValues="references %object%" -types=TABLE -useRegex=false;', 'skip_columns': [2]}
let objects = {'title': 'Objects', 'shortcut': 'O', 'command': 'WbList -objects=% -types=SYNONYM,TABLE,TYPE,VIEW', 'panels': [sw_columns, sw_sql_source, sw_data, sw_data_filter, sw_indexes, sw_referenced_by]}
let sw_sql_source = {'title': 'SQL Source', 'shortcut': 'S', 'command': 'WbProcSource %object%', 'filetype': 'sql'}
let procedures = {'title': 'Procedures', 'shortcut': 'P', 'command': 'WbListProcs;', 'panels': [sw_sql_source]}
let triggers = {'title': 'Triggers', 'shortcut': 'T', 'command': 'WbListTriggers;', 'panels': [sw_sql_source_triggers]}
let g:SW_Tabs = {'^postgresql': [objects, procedures, triggers, row_counts]}

" PostgreSQL panel
let sw_sql_source = {'title': 'SQL Source', 'shortcut': 'S', 'command': 'WbGenerateScript -objects="%object%"', 'filetype': 'sql'}
let sw_columns = {'title': 'Columns', 'shortcut': 'C', 'command': 'desc %3%.%0%'}
let sw_data = {'title': 'Data', 'shortcut': 'D', 'command': 'select * from %3%.%0%', 'filetype': 'sw'}
let sw_indexes = {'title': 'Indexes', 'shortcut': 'I', 'command': 'WbListIndexes -tableName=%object% -schema=%3%'}
let sw_referenced_by = {'title': 'Referenced by', 'shortcut': 'R', 'command': 'WbGrepSource -searchValues="references %object%" -types=TABLE -useRegex=false -schemas=*;', 'skip_columns': [2]}
let objects = {'title': 'Objects', 'shortcut': 'O', 'command': 'WbList', 'panels': [sw_columns, sw_sql_source, sw_data, sw_indexes, sw_referenced_by]}
let sw_sql_source_proc = {'title': 'SQL Source', 'shortcut': 'S', 'command': ':sw#dbexplorer#postgre_proc', 'filetype': 'sql'}
let sw_sql_source_triggers = {'title': 'SQL Source', 'shortcut': 'S', 'command': 'WbGrepSource -searchValues="%object%" -objects=%object% -types=* -useRegex=true -schemas=*;', 'skip_columns': [0, 1], 'hide_header': 1, 'filetype': 'sql'}
let procedures = {'title': 'Procedures', 'shortcut': 'P', 'command': 'WbListProcs;', 'panels': [sw_sql_source_proc]}
let triggers = {'title': 'Triggers', 'shortcut': 'T', 'command': 'WbListTriggers;', 'panels': [sw_sql_source_triggers]}
let schemas = {'title': 'Show schemas', 'shortcut': 'M', 'command': 'wblistschemas;', 'panels': [{'title': 'Select schema', 'shortcut': 'H', 'command': "set search_path to %object%;"}, {'title': 'Select *', 'shortcut': 'A', 'command': "set search_path to '*.*'"}]}
let g:SW_Tabs[':postgresql'] = [objects, procedures, triggers, schemas, row_counts]

" Oracle specific panel
let oracle_dblinks = {'title': 'DB Links', 'shortcut': 'L', 'command': 'select db_link, username, created  from user_db_links;', 'panels': [{'title': 'Show the host', 'shortcut': 'H', 'command': "select host from user_db_links where db_link = '%object%'"}]}
let oracle_jobs = {'title': 'User Jobs', 'shortcut': 'J', 'command': 'select job_name, job_creator, start_date, repeat_interval from user_scheduler_jobs', 'panels': [{'title': 'Job source', 'shortcut': 'S', 'command': "select job_action from user_scheduler_jobs where job_name = '%object%'", 'hide_header': 1, 'filetype': 'sql'}]}
let oracle_packages = {'title': 'Packages', 'shortcut': 'K', 'command': "select OBJECT_NAME, OBJECT_TYPE, STATUS from user_objects where object_type in ('PACKAGE');", 'panels': [{'title': 'SQL Source', 'shortcut': 'S', 'command': "wbprocsource %object%", 'filetype': 'sql'}, {'title': 'Compile', 'shortcut': 'E', 'command': 'alter package %object% compile package'}, {'title': 'Status', 'shortcut': 'v', 'command': "select object_name, OBJECT_TYPE, STATUS from user_objects where object_name = '%object%'"}]}
let oracle_schemas = {'title': 'Show schemas', 'shortcut': 'M', 'command': 'wblistschemas;', 'panels': [{'title': 'Select schema', 'shortcut': 'H', 'command': "alter session set current_schema = %object%;"}]}
let oracle_sequences = {'title': 'Sequences', 'shortcut': 'Q', 'command': 'wblist -types=SEQUENCE -objects=%', 'panels': [sw_sql_source, sw_columns]}
let g:SW_Tabs[':oracle'] = [oracle_dblinks, oracle_jobs, oracle_packages, oracle_schemas, oracle_sequences]

call sw#dbexplorer#add_panel_event('O', 'F', 'after', 'sw#dbexplorer#filtered_data')
call sw#dbexplorer#add_panel_event('O', 'C', 'after', 'sw#dbexplorer#fold_columns')
