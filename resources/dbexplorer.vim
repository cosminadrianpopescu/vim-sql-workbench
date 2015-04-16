let sw_columns = {'title': 'Columns', 'shortcut': 'C', 'command': 'desc %object%;'}

let sw_sql_source = {'title': 'SQL Source', 'shortcut': 'S', 'command': 'WbGrepSource -searchValues="%object%" -objects=%object% -types=* -useRegex=true; -- AFTERcall sw#dbexplorer#fix_source_code()', 'skip_columns': [0, 1], 'hide_header': 1, 'filetype': 'sql'}

let sw_data = {'title': 'Data', 'shortcut': 'D', 'command': 'select * from %object%;'}

let sw_indexes = {'title': 'Indexes', 'shortcut': 'I', 'command': 'WbListIndexes -tableName=%object%;'}

let sw_referenced_by = {'title': 'Referenced by', 'shortcut': 'R', 'command': 'WbGrepSource -searchValues="references %object%" -types=TABLE -useRegex=false;', 'skip_columns': [2]}

let objects = {'title': 'Objects', 'shortcut': 'O', 'command': 'WbList -objects=% -types=SYNONYM,SEQUENCE,TABLE,TYPE,VIEW', 'panels': [sw_columns, sw_sql_source, sw_data, sw_indexes, sw_referenced_by]}

let procedures = {'title': 'Procedures', 'shortcut': 'P', 'command': 'WbListProcs;', 'panels': [sw_sql_source]}
        
let triggers = {'title': 'Triggers', 'shortcut': 'T', 'command': 'WbListTriggers;', 'panels': [sw_sql_source]}

let g:SW_Tabs = {'*': [objects, procedures, triggers]}


