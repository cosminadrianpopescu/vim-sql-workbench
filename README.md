Introduction
========================================

This is an implementation of [SQL Workbench/J](http://www.sql-workbench.net/)
in VIM. It works with any DBMS supported by `SQL Workbench/J` (PostgreSQL,
Oracle, SQLite, MySQL, SQL Server etc.). See the complete list
[here](http://www.sql-workbench.net/databases.html). 

You can connect to any DBMS directly from VIM.

*Features:*

* database explorer (e.g.: table lists, procedures list, views list, triggers
  list), extensible (you can have your own objects list)
* SQL buffer with performant autocomplete
* export any sql statement as `text`, `sqlinsert`, `sqlupdate`,
  `sqldeleteinsert`, `xml`, `ods`, `html`, `json`
* search in object source
* search in table or views data
* fully customizable

CONTENTS:

1. Requirements
2. Connecting to a DBMS
3. The database explorer
4. The SQL Buffer
5. Searching
6. Exporting
7. Sessions
8. Commands
9. Settings
10. Screen shots
11. Missing features

Requirements
========================================

Of course you need VIM 7 or above. The only other requirement is [`SQL
Workbench/J`](http://www.sql-workbench.net/) installed on your computer. It is
platform independent, since `SQL Workbench` is written in JAVA and it should
work anywhere where VIM works. 

Before getting started, you have to set the `g:sw_exe` vim variable. The
default value is `sqlwbconsole.sh`. If you have `SQL Workbench` in your PATH,
then you can skip this step. Otherwise, just set the value of the variable to
point to your `sqlwbconsole` file. If you are on Windows, it should be
`sqlwbconsole.exe`. 

Also, if you are on Windows, you have to set the `g:sw_tmp` value in your
`vimrc`. The default value is `/tmp`. 

Connecting to a DBMS
========================================

You can connect from vim to a database (DBMS independent) in two ways: 

* specifying the full connection parameters
* specifying a `SQL Workbench` profile

## Connecting by specifying the full connection parameters

From VIM you can call the `SWDbExplorerDirect` command. The command takes the
arguments that an `SQL Workbench/J` connection takes. For a full list of
arguments, please have a look
[here](http://www.sql-workbench.net/manual/install.html#commandline). Check
the `4.9.7` section (connecting without a profile). For example: 

```
:SWDbExplorerDirect -url='jdbc:mysql://localhost/mydb' -username=admin
-password=pass -driver=com.mysql.jdbc.Driver<cr>
```

Please note that `SQL Workbench` will require you to specify the driver and
the url. 

In the same way, you can open an sql buffer instead of the database explorer: 

```
:SWSqlOpenDirect /tmp/myfile.sql -url='jdbc:mysql://localhost/mydb'
-username=admin -password=pass -driver=com.mysql.jdbc.driver<cr>
```

If you open a sql buffer this way, you can after execute the `SQL Workbench/J`
command `WbStoreProfile`. See this
[page](http://www.sql-workbench.net/manual/console-mode.html) for more info. 

Once in a sql buffer, you can launch any command `SQL Workbench` accepts. 

## Connecting by specifying a profile

You can create `SQL Workbench` profiles, either by using the `SQL Workbench`
GUI, like
[here](http://www.sql-workbench.net/manual/profiles.html#profile-intro),
either opening a sql buffer with `SWSqlOpenDirect` and then executing
`WbStoreProfile`. 

Once you have your profiles created, you can use `SWDbExplorer` or `SWSqlOpen`
with the desired profile as argument and you will connect to the database. 

For example, `:SWDbExplorer myProfile` will open a database explorer using the
profile `myProfile`. Or `SWSqlOpen myProfile /tmp/myfile.sql` will open the
file `/tmp/myfile.sql` as an sql buffer. Any command launched from the buffer
will be using the `myProfile` profile. 

The database explorer
========================================

The database explorer is composed from three parts: on the top, there is a
list of available shortcuts at any moment. On the bottom left, you will see
the list of objects in your database (the list of tables and views or the list
of procedures or the list of triggers etc.) and on the bottom right, you will
see the selected object desired properties. Like in the second or third screen
shot. 

So, if you want to see the columns of a table, you will have to move the
cursor in the bottom left panel, go to the desired table and press 'C'. This
will display in the right panel the table columns, indices and triggers. If
you want to see its source code, you press 'S' and so on. For all the
available shortcuts, see the top panel. 

The database explorer if fully customizable. You can use the existing one and
extend it or you can create your own from scratch. 

## Creating a new database explorer from scratch

The database explorer is loaded from the `resources/dbexplorer.vim` file by
default. If you want to write your own, set the `g:sw_dbexplorer_panel`
variable to point to your own file and that file will be loaded. The file has
to be a `vimscript` file, since it's going to be sourced and it needs to set
the `g:SW_Tabs` variable. For an example, take a look at the
`resources/dbexplorer.vim` file. 

The `g:SW_Tabs` has to be a vim dictionary. The keys are the profiles for
which the panel will be applied. `*` profile, means that the options appear on
all profiles. If you want to have separate database explorers for separate
profiles, you can create a key in the dictionary for each explorer. 

*NOTE:* At the moment you can only create profiles for different profiles, not
for different DBMS.

The values for each profile, have to be a list which will contain all the
options for the left panel. For example, in the default one, the database
objects, triggers and procedures. 

Each list of objects of this list is another dictionary, with the following
keys: 

* `title` (the title which will be displayed in the top panel)
* `shortcut` (the shortcut to access it; please note that you can have several
  letters)
* `command` (the sql command which will be executed when selecting the object)
* `panels` (a list of options accessible in the right panel for each selected
  object in the left panel)

The panels are also a list of dictionaries. Each element of the list has the
following keys: 

* `title` (the title which will be displayed in the top panel)
* `shortcut` (the shortcut which will be used to display it)
* `command` (the sql command which will be executed; please note that the sql
  command should contain the `%object%` string, which will be replaced with
  the name of the selected object)

Optional, the panels might contain the following keys: 

* `skip_columns` (a list with the column indices from the result set that
  should not be displayed)
* `hide_header` (if set and `true`, then the header of the result set will not
  be displayed in the bottom right panel)
* `filetype` (if present, the bottom right panel `filetype` will be set
  according when selecting an object in the left panel)

*NOTES*: 

1. In the command that creates the left panel, the object for which you want
   to select the informations in the right panel should always be on the first
   column. The `%object%` string in the column will be replaced by it. 
2. The command can contain a comment in the format `-- AFTER` at the end.
   Everything following "AFTER" word will be interpreted as a VIM command and
   will be executed after the result has been displayed in the right panel. For
   an example, see the SQL Source panel in the default database explorer vim
   file (`resources/dbexplorer.vim`). 
3. The shortcuts for the left panel (the list of objects) have to be unique.
   They are used to identify the current option selected to be displayed, so
   that the shourtcuts for the left panel are loaded according to the panels.
   However, the shortcuts for the right panel can be the same from one list of
   objects to the other. For example, you can have "O" as shortcut for objects
   list and then for each object you can have "S" for showing the source code.
   Then, you can have "P" for listing the procedures. Again, for each procedure
   you can have again "S" as shortcut for listing the source code of a
   procedure or for something else. 

## Extending the default database explorer

If you are happy with the default options of the database explorer (which are
the same with the ones of `SQL Workbench/J`) but you just want to add your
own, you can do so by extending the default database explorer. 

This is done by calling the `vimscript` function `sw#dbexplorer#add_tab`. The
function takes the following arguments: 

* The profile (the profile for which the option should be active; it can be
  `*` for all profiles)
* The title (this is the title that will appear on the top panel)
* The shortcut (this is the shortcut to access it)
* The command (this is the SQL command to be sent to the DBMS once this option
  is selected)
* The list of panels (the list of properties to be displayed in the bottom
  right split for each object from the list)

The list of panels is an array of dictionaries. Each dictionary has the same
keys as indicated in the previous section for the list of panels. For example,
if you want to add the database links for all the profiles, you have to add
this in your `vimrc`: 

```
call sw#dbexplorer#add_tab('*', 'DB Links', 'L', 'select db_link, username,
created  from user_db_links;', [{'title': 'Show the host', 'shortcut': 'H',
'command': "select host from user_db_links where db_link = '%object%'"}])
```

Now on all profiles, you will have an extra option. Every time when you click
"L" in normal mode, in the bottom left panel you will have a list of database
links from your schema. For each link, you can move the cursor on top of it
and click H. You will see in the right panel the source of the link. 

Every time when "L" is clicked, `vim-sqlworkbench` sends the `select db_link,
username, created from user_db_links;` command to the DBMS. The result will be
a list of database links displayed in the bottom left panel.  When you move
your cursor on top of one of this links and press "H", the plugin sends to
your DBMS `select host from user_db_links where db_link =
'<selected_link_name>';`. The result is displayed in the right panel.

The SQL buffer
========================================

The SQL buffer is a normal `vim` buffer from which you can send SQL commands
to your DBMS and in which you can use the omni completion (&lt;C-x&gt;&lt;C-o&gt;) to have
intellisense autocompletion. 

In order to open a buffer, you have to call the command `SWSqlOpen` or
`SWSqlOpenDirect`. You can see the parameters of each of the commands in the
"Commands" chapter. 

Once in an sql buffer, you have several ways to execute commands against your
DBMS: 

* execute the current SQL
* execute the selected statement
* execute all statements

All the shortcuts for these commands are fully customizable. But to do this,
you cannot just map the commands in `vimrc`. This is because these shortcuts
are mapped local to the sql buffer, or to the result sets buffer. If you want
to change the default shortcuts, you need to define the
`g:sw_shortcuts_sql_buffer_statement` variable or the
`g:sw_shortcuts_sql_results` variable. This variables should point each to a
`vimscript` file which will define the mappings. 

The `g:sw_shortcuts_sql_buffer_statement` variable is used for the sql buffer
itself, while the `g:sw_shortcuts_sql_results` variable is used for the result
set buffer (see the 4th scren shot). 

As soon as a SQL buffer is opened the shortcuts from the
`g:sw_shortcuts_sql_buffer_statement` will be mapped. If the variable is not
set, then the `resources/shortcuts_sql_buffer_statement.vim` file is loaded.
So, have a look at this file for further details. Please note that for
executing the current SQL, the default shortcut is `ctrl + space`.

The same goes for a result set buffer. The shortcuts from the file pointed by
the `g:sw_shortcuts_sql_results` variable are loaded. If the variable is not
set, then the shortcuts from `resources/shortcuts_sql_results.vim` are loaded.
If you want further details, please have a look at this file. 

## Execute the current statement

As stated already, you can press `ctrl + space` in normal or insert mode or
you can have your own shortcut. Alternatively, in normal mode, you can execute
`SWSqlExecuteCurrent` command. 

The statement between the last 2 delimiters will be sent to the server, or
from the beginning of the file until the first delimiter, or from the last
delimiter to the end of the file, depending on where your cursor is placed. 

You can change the default delimiter with the `SWSqlDelimiter`. 

## Execute the selected statement

In visual mode, you can press `ctrl + e` or your own custom shortcut.
Alternatively, you can execute the `SWSqlExecuteSelected` command. Please be
careful to delete the range before, if you want to execute the command from
the visual mode. 

The selected text is going to be sent to the DBMS. 

## Execute all statements

In visual mode, you can press `ctrl + a` or your own custom shortcut.
Alternatively, you can execute the `SWSqlExecuteAll` command. All the buffer
is going to be sent to the DBMS. 

## Intellisense

`vim-sqlworkbench` plugin comes with intellisense out of the box. In order to
take advantage of the auto complete intellisense, you have to execute first
the `SWSqlAutocomplete` command. Depending on how many tables and views you
have in your database, it might take even more than one minute. After the
command is executed, normally you can press &lt;C-x&gt;&lt;C-o&gt; in insert
mode in a sql statement. 

The plugin will try to determine where you are in the sql and return the
appropriate options. For example, if you are in the fields part of a `select`
statement, the options returned will be the fields based on the tables from
the `from` part of the `select`. If you are in the `from` part, then the list
of tables is returned. If you have an identifier followed by a dot, then if
that identifier is a table, a view or an alias of a view or subquery, the
system will return the corresponding list of fields. 

Also the subqueries are parsed and the appropriate fields are returned. 

If you are in a subquery in a bigger query, the auto complete will be executed
at the level of the subquery.

If you are in a `union` `select` statement, the system will try to determine
in which `select` the cursor is placed and execute auto completion for that sql. 

As stated before, enabling the auto completion for a buffer can take some
time. If you have several buffers opened for the same profile and you want the
same auto complete tables and fields list, then you can execute instead of the
`SWSqlAutocomplete` command, the `SWSqlAutocompleteSetDefault` command. This
will enable the autocomplete for the current buffer, but in addition will set
the current list of tables, views, fields etc. as the default autocomplete. 

In the next buffer, you can simply call the `SWSqlAutocompleteWithDefault`
command which will enable the autocomplete for that buffer using the default
auto complete options (the ones defined previously). This will be
instantaneously. 

Unfortunately, the autocomplete for the function and procedures is limited.
This is because `SQL Workbench/J` does not provide also a list of parameters
through a `SQL Workbench` command. I can only retrieve the name of the
function or procedure. Also, the autocomplete for the procedure and functions
is limited to the `WbCall` command. 

*NOTE*: The autocomplete feature is implemented using regular expressions. I
preferred this way in order not to introduce any additional dependencies for
the plugin. Using a grammatic would've mean to use `python` and I think even for
`python` I would've needed additional libraries. Because of using regular
expressions, it's possible that I've missed cases. If you notice any case
where the autocomplete is not working properly, please let me know. 

## Get an object definition

When with the cursor on top of any word in the buffer or in the result set,
you can click `alt + i` or your own custom shortcut. This will display that
object definition if the object exists in the result set buffer or an error 
message. 

Alternatively you can execute the `SWSqlObjectInfo` command from normal mode. 

Basically the command `desc <object>` is sent to the DBMS and the output 
returned. 

## Get an object definition

When you are with the cursor on top of any word in the buffer or in the result
set, you can click `alt + s` or your own custom shortcut. This will display
the object source if the object exists in the result set buffer or an error 
message.

Alternatively, you can execute the `SWSqlObjectSource` command from normal 
mode.

## Maximum number of rows. 

You can limit the number of rows returned by a select command with the
`SWSqlMaxResults` command. The command takes one parameter, which is the
number of rows. If you want to have again all the results, you can execute
`SWSqlMaxResults 0`. This will reset the option.

## Execution messages

When you execute a select statement that returns rows, then you will only see
those rows in the result set. If you have multiple sql statements and some of
them will return errors, but you have some which will produce results, then
you will only see those results in the result set. 

In order to see the messages produced by the last sql statement, you can click
`alt + m` or your own custom shortcut in normal mode in the buffer or in the
result set buffer. This will hide the result sets and display the messages
produced by the last command. To have back the result sets, click again the
same shortcut. 

Alternatively, you can execute the `SWSqlToggleMessages` vim command from
normal mode. 

## Changing result sets display mode

In the result set buffer, you can click `alt + d` or your own custom shortcut
on top of a row. This will toggle the row display to have each column on a row
for the selected row. To change back the display mode, click again the same 
shortcut. 

Alternatively, you can execute the `SWSqlToggleFormDisplay` command from
normal mode inside the result sets buffer on top of a row. 

If you want to have all the results with the columns displayed as rows, you
can execute `SWSqlDisplayResultsAs record`. After executing this command, all
the result sets returned will display their columns each on a row. To have
back the normal display, execute `SWSqlDisplayResultsAs tab`. 

Searching
========================================

`SQL Workbench/J` comes with two very handy and powerful commands:
`WbGrepSource` and `WbGrepData`. `vim-sqlworkbench` takes advantage of both of
them and implements searching options. You can search in objects source code,
or you can search tables data.

## Searching in objects source code

Of course, you can always execute `WbGrepSource` in a sqlbuffer and send it to
the DBMS. For a full documentation of the command, please see
[here](http://www.sql-workbench.net/manual/wb-commands.html#command-search-source).

Alternatively, you can call one of the three `vim-sqlworkbench` search
commands available: `SWSearchObject`, `SWSearchObjectAdvanced` or
`SWSearchObjectDefaults`. 

The `SWSearchObject` command will take one argument, which is the search
string. The command which will be sent to the DBMS is `WbGrepSource
<your_terms>`. This means that you execute a search with `SQL Workbench/J`
default values. For a list of these, see the above link. 

*Example:* `:SWSearchObject my_table<cr>`

The `SWSearchObjectAdvanced` command will open an interactive command prompt
asking for every parameter value, beginning with the search terms.
Additionally, it will also require the columns to be displayed from the search
result. If you want to only search for some objects that contain a certain
term in their definition, you might not want to include the code of the
object. This might take multiple rows. In this case you will have to scroll in
the result buffer to see all the objects containing your term. If this is the
case, you can include only the "NAME" and "TYPE" columns. 

If you leave the columns empty, then the plugin will return all the columns
but will remove all the rows from the source column. Only the first row from
each column will be displayed. If you want to see all the columns with all the
rows, you have to specify all the columns in the columns section
(`NAME,TYPE,SOURCE`). Please note that you cannot change the order of the 
columns. 

The `SWSearchObjectDefaults` command takes one argument (the search terms) and
will perform a search using all the defaults defined in `vim-sqlworkbench`
plugin. These defaults can be changed in `vimrc`. 

*Example:* `:SWSearchObjectDefaults my_table<cr>`

## Searching for data inside tables

You can execute `WbGrepData` in a sql buffer and send it to the DBMS. For a
full documentation of the command, please see
[here](http://www.sql-workbench.net/manual/wb-commands.html#command-search-data).

Alternatively, you can call one of the three `vim-sqlworkbench` search
commands available: `SWSearchData`, `SWSearchDataAdvanced` or
`SWSearchDataDefaults`. 

All the three commands work as their counter parts for searching object with
the exception that no column can be selected any more. 

If you are in an sql buffer, then the results are displayed in the result sets
buffer. If you are in a database explorer, then the search results are
displayed in the bottom right panel. 

Exporting
========================================

`vim-sqlworkbench` takes advantage of the very powerful `SQL Workbench/J`
command, `WbExport`. 

As usual, you can always execute the `WbExport` command inside a sql buffer.
To see the full documentation of the `WbExport` command, have a look
[here](http://www.sql-workbench.net/manual/command-export.html).

Or you can execute the `SWSqlExport` command. This will open an interactive
input dialog which will ask for the format and the destination file and will
export the last sql command. If you are in a database explorer, in the right
panel, you can click on "E". This shortcut is not modifiable. This will export
what ever is in the right panel, after asking for the format and the
destination file. Please note that because of extra dependencies required for
`xls` export, `vim-sqlworkbench` does not provide support for this format.
However, you can export as `ods`, which is what you should use anyway. See
[here](http://www.fsf.org/campaigns/opendocument/) or
[here](http://www.fsf.org/campaigns/opendocument/download)

Sessions
========================================

`vim-sqlworkbench` provides support for vim sessions. You have to have the
`globals` enabled in your session options (`set sessionoptions+=globals`). 

However, the session restore is done in two steps. As soon as you restore a
vim session, you will notice that for example a database explorer is empty and
pressing the shortcuts will have no effect. You have, when entering in the
tab, to call the command `SWDbExplorerRestore`. 

Similar, when entering an sql buffer after a session restore, you will notice
that executing statements against the DBMS will produce vim errors. Before
executing any statement, you have to call the `SWSqlBufferRestore`. This will
also restore the autocomplete list, so you will also have the autocomplete. 

Commands
========================================

## SWDbExplorer

*Parameters*:

* profile name: the name of the profile for which to open the database explorer. 

Opens a database explorer for the desired profile. 

*NOTE*: If you set the
`g:sw_config_dir` variable to point to the `SQL Workbench/J` settings folder,
the command will autocomplete the profile names. See
[here](http://www.sql-workbench.net/manual/install.html#config-dir)

## SWDbExplorerDirect

*Parameters*:

* the same arguments that `SQL Workbench/J` takes for connections. See
  [here](http://www.sql-workbench.net/manual/install.html#commandline)

Opens a database explorer using a direct connection. 

## SWDbExplorerClose

*Parameters*; 

* profile name (optional): the name of the database explorer that should be
  closed. 

Closes a database explorer. If no profile name is specified, if you are inside
a database explorer, then that database explorer is closed. Otherwise, the
system will generate an error. 

If you specify a profile name, then the database explorer which is opened for
the indicated profile is closed. 

## SWDbExplorerRestore

After a session restore, this command will restore an opened database panel

## SWSqlBufferAddProfile

*Parameters*: 

* profile name: the name of the profile for which to open the sql buffer.

Attaches a profile to an already opened vim buffer. This means that you can
open a normal vim buffer (`e /tmp/my_file.sql`) and then attach an `SQL
Workbench/J` profile to it. After this, the buffer will become a
`vim-sqlworkbench` buffer and you will be able to send sql statements to the
selected DBMS.

*NOTE*: If you set the
`g:sw_config_dir` variable to point to the `SQL Workbench/J` settings folder,
the command will autocomplete the profile names. See
[here](http://www.sql-workbench.net/manual/install.html#config-dir)

## SWSqlOpen

*Parameters*:

* profile name: the name of the profile for which to open the sql buffer.
* file name: the name of the file to open. 

Opens a buffer as a sql buffer. It supports autocomplete for both parameters:
a `SQL Workbench/J` profile name for the first parameter (see the note) and
the system files for the second parameter.

*NOTE*: If you set the
`g:sw_config_dir` variable to point to the `SQL Workbench/J` settings folder,
the command will autocomplete the profile names. See
[here](http://www.sql-workbench.net/manual/install.html#config-dir)

## SWSqlOpenDirect

*Parameters*:

* file name: the name of the file to open as sql buffer
* the same arguments that `SQL Workbench/J` takes for connections. See
  [here](http://www.sql-workbench.net/manual/install.html#commandline)

The first argument has to be a buffer name. The next arguments are the
arguments for the connection. 

This commands opens a sql buffer using parameters for the connections. Once
connected, you can execute the `WbStoreProfile` command to also store the 
profile. 

## SWSqlExecuteCurrent

In an sql buffer executes the current statement. You can execute this command
in normal or insert mode. This is the statement between two consecutive
identifiers, or from the beginning of the file to the first identifier or from
the last identifier to the end of the file. You can change the delimiter using
the `SWSqlDelimiter` command. 

## SWSqlExecuteSelected

In an sql buffer, executes the current selected statement. The command works
in visual mode. Be careful to delete the range before typing the command. 

## SWSqlExecuteAll

Send all sql statements from the buffer to the DBMS. 

## SWSqlDisplayResultsAs

*Parameters*: 

* display type: `tab|record`. 

If you want to have each column display in a row, you can select the display
as `record`. Otherwise, for normal display (tabbed, with rows and columns) use
`tab` display mode. 

## SWSqlMaxResults

*Parameters*:

* n: the maximum number of records to be displayed. 

This commands set in a sql buffer, the maximum number of rows that will be
retrieved when executing a sql which returns results. If you want to only
retrieve 10 records for the next command, you can type `set maxrows = 10`
before your statement, select the `maxrows` statement together with your
statement and execute with `SWSqlExecuteSelected`. 

By default, all rows are returned. If you set a different number of rows via
this command and the you want again all the results, you can run
`SWSqlMaxResults 0`. 

## SWSqlDelimiter

*Parameters*:

* delimiter: the new delimiter. 

This command changes the default delimiter. Please note that if you run this
command, also the `SWSqlExecuteCurrent` statement will take it under
consideration. This means, that the current sql will be calculated using this
delimiter. 

Usually a delimiter is changed when you want to create a stored procedure or
function or a trigger or something similar. If you just want to execute one
statement with a different delimiter, you can just type, your statement using
`/` as delimiter, select it and send it to the DBMS. `SQL Workbench` will know
how to handle is. 

For example: 

```
create procedure my_procedure()
begin
    select * from products;
end;
/
```

If you select this statement and click `ctrl + e` or your own custom shortcut
for executing the selected statement, it will work even if your normal
delimiter is ";". To use an alternate delimiter, you have to have the
delimiter alone on its own line. 

## SWSqlAbortOnErrors

*Parameters*:

* number: 1|0.

If you set this option, then when executing more than one statement at a time,
the execution will stop at the first error. Otherwise, the execution will
continue until the last statement. By default this is set to false. 

See more
[here](http://www.sql-workbench.net/manual/using-scripting.html#scripting-handling-errors)

## SWSqlShowFeedback

*Parameters*:

* number: 1|0

If you set this option to true, then when executing statements you will get
the full output of the `SQL Workbench` in the messages window (see
`SWSqlToggleMessages`), like the execution time. Otherwise, you will only get
output if you have an error. 

For more explanation, see
[here](http://www.sql-workbench.net/manual/using-scripting.html#script-display)

## SWSqlToggleMessages

If you have a result set displayed in the result set buffer, you can toggle
between the result displayed and the messages produced by the command with
this command. The command works from the sql buffer and from the result set 
buffer.

## SWSqlToggleFormDisplay

If you have a result set displayed, in the result set buffer you can move your
cursor on top of a row from the result set. By calling this command, the
columns will be displayed each on a row. To switch back, call again the same
command. 

## SWSqlObjectInfo

In a sql buffer or in a result set buffer, you can position the cursor on top
of any word and call this command. The plugin will send to the DBMS `DESC
<word>`. If the word that you selected is a valid database object, you will
see its definition. Otherwise it will return an error. 

## SWSqlObjectSource

Like the previous command, if you are with your cursor on top of a word and
call this command, the plugin will return it's source code, if the selected
word is an object in the database. Otherwise, it will return an empty result
set. 

## SWSqlExport

This command will export the last executed statement. Of course, if your last
statement did not produced any results, you will have an empty file. The
plugin will ask you about the format and about the output file. You can export
in one of the following formats: `text`, `sqlinsert`, `sqlupdate`,
`sqldeleteinsert`, `xml`, `ods`, `html`, `json`. 

## SWSearchObject

*Parameters*:

* search terms: the terms that you are searching.

This command performs a search in the source code of the database objects. It
uses the defaults of `SQL Workbench/J`. The command which is used is
`WbGrepSource`. You can see more details about the parameters and their
default values
[here](http://www.sql-workbench.net/manual/wb-commands.html#command-search-source).

The search result will only return the first row of each column. This means
that you will have to select each term that you want to inspect and see it's
source using the `SWSqlObjectSource` command. If you want to see the full
output you have to either set `g:sw_search_default_result_columns` to
'NAME,TYPE,SOURCE' and execute the command `SWSearchObjectDefaults`, or you
can execute the `SWSearchObjectAdvanced` command and select all three columns
when asked. 

## SWSearchObjectAdvanced

This command will perform an advanced search. It will ask for each possible
parameter. You can cancel the search at any time by replying with an empty
value. This, however, is not possible for the columns input, since the empty
string in the columns means that you want all the columns but only the first
row of each. 

## SWSearchObjectDefaults

*Parameters*:

* search terms: the terms that you are searching. 

This command will perform a search using as default values for all the
parameters the values defined through the vim variables: 

* `g:sw_search_default_regex`
* `g:sw_search_default_match_all`
* `g:sw_search_default_ignore_case`
* `g:sw_search_default_types`
* `g:sw_search_default_compare_types`

## SWSearchData

*Parameters*:

* search terms: the terms that you are searching.

This command performs a search in the data in the tables. It uses the defaults
of `SQL Workbench/J`. The command which is used is `WbGrepData`. You can see
more details about the parameters and their default values
[here](http://www.sql-workbench.net/manual/wb-commands.html#command-search-data).

## SWSearchDataAdvanced

This command will perform an advanced search in the tables data. It will ask
for each possible parameter. You can cancel the search at any time by replying
with an empty value, with the exception of the `excludeTables` parameter,
since an empty value here means that you want to search in all the tables and
is not an unusual request. 

## SWSearchDataDefaults

*Parameters*:

* search terms: the terms that you are searching. 

This command will perform a search in tables data using as default values for
all the parameters the values defined through the vim variables: 

* `g:sw_search_default_ignore_case`
* `g:sw_search_default_compare_types`
* `g:sw_search_default_tables`
* `g:sw_search_default_data_types`
* `g:sw_search_default_exclude_tables`
* `g:sw_search_default_exclude_lobs`

## SWSqlAutocomplete

This command enables the intellisense autocomplete for the current sql buffer.
After this command you can use &lt;C-x&gt;&lt;C-o&gt; for autocomplete. 

## SWSqlAutocompleteSetDefault

Like the previous command, this command also activates the intellisense
autocomplete for the current sql buffer. In addition to the previous command,
this command will also set the list of tables and fields and procedures found
for this profile as default autocomplete. They can be used by the
`SWSqlAutocompleteWithDefault` command.

## SWSqlAutocompleteWithDefault

This command activates the intellisense autocomplete for the current sql
buffer using the default list of tables, fields and procedures. 

## SWSqlBufferRestore

This command will restore the properties of the sql buffer following a vim
session restore. This includes the autocomplete intellisense of the buffer, if
this was active when `mksession` was executed. 

Settings
========================================

## Search object source settings:

* `g:sw_search_default_result_columns`: the default list of columns to be
  included in a search result; default value: ""
* `g:sw_search_default_regex`: whether to use regular expressions or not when
  performing a search; default value: "Y"
* `g:sw_search_default_match_all`: whether to match or not all the search
  terms or only one (use `OR` or `AND` when performing the search); default
  value: "Y"
* `g:sw_search_default_ignore_case`: whether to ignore the case or not when
  performing a search; default value: "Y"
* `g:sw_search_default_types`: the types of object in which to search; default
  value: "LOCAL TEMPORARY,TABLE,VIEW,FUNCTION,PROCEDURE,TRIGGER,SYNONYM"

*Note*: this values apply for the `SWSearchObjectDefaults` command. The
`SWSearchObjectAdvanced` will ask for the value of each parameter and
`SWSearchObject` command will use the defaults of `SQL Workbench`. 

## Search data in tables settings: 

* `g:sw_search_default_match_all`: whether to match or not all the search
  terms or only one (use `OR` or `AND` when performing the search); default
  value: "Y"
* `g:sw_search_default_compare_types`: the type of search to be performed (the
  operator for the search); default value: "contains"
* `g:sw_search_default_tables`: the tables to be included in the search;
  default value: "%", which means all tables
* `g:sw_search_default_data_types`: the types of objects in which to perform
  the search; default value: "TABLE,VIEW"
* `g:sw_search_default_exclude_tables`: the list of tables to exclude from
  search; default value: ""
* `g:sw_search_default_exclude_lobs`: whether or not to exclude the `blob` and
  `clob` columns from search; default value: "Y"

*Note*: this values apply for the `SWSearchDataDefaults` command. The
`SWSearchDataAdvanced` will ask for the value of each parameter and
`SWSearchData` command will use the defaults of `SQL Workbench`. 

To see more about these parameters, see
[here](http://www.sql-workbench.net/manual/wb-commands.html#command-search-source)
and
[here](http://www.sql-workbench.net/manual/wb-commands.html#command-search-data)

## Sql buffer settings: 

* `g:sw_feedback`: if set to true, then return all the possible feedback from
  a command; default value: 1
* `g:sw_abort_on_errors`: if set to true, then abort the execution of the
  statements on the first error (this is valid only when sending more than one
  statement for execution in one go); default value: 1
* `g:sw_display_result_as`: how to display the result sets (tabbed or each
  column on a row); possible values: tab|record; default value: "tab", which
  means tabbed layout
* `g:sw_max_results`: the maximum number of rows to be returned in a result
  set; default value: 0, which means all the rows
* `g:sw_delimiter`: the delimiter to be used in a sql buffer; default value:
  ";"
* `g:sw_sqlopen_command`: the vim command used by `SWSqlOpen` or
  `SWSqlOpenDirect` commands to open a buffer; possible values: `e|tabnew`;
  default value: "e", which means open with vim `edit` command

## Database explorer settings

* `g:sw_default_right_panel_type`: the file type of the bottom right panel
  when not specified; default value: "txt"

## General settings:

* `g:sw_show_shell_output`: whether or not to show the shell output after
  sending a sql statement to the DBMS; default value: 0
* `g:sw_show_command`: whether or not to show the sql command in the results
  buffer; default value: 0 (please note that this will also affect the
  database explorer, which means that you will have the sql commands also in
  the bottom left and bottom right panels)
* `g:sw_exe`: the location of the `SQL Workbench` executable; default value:
  "sqlwbconsole.sh"
* `g:sw_tmp`: the location of your temporary folder; default value: "/tmp"

Screen shots
========================================

![Database explorer](resources/screenshots/s01.jpg)
![Database explorer source view](resources/screenshots/s02.jpg)
![Database explorer column view](resources/screenshots/s03.jpg)
![SQL Buffer result set](resources/screenshots/s04.jpg)
![SQL Buffer row displayed as form](resources/screenshots/s05.jpg)
![SQL Buffer resultset messages](resources/screenshots/s06.jpg)

Missing Features
========================================

The biggest missing feature are the transactions. Since every command is
executed using the console mode of `SQL Workbench` and then the result is
taken from a temporary file and displayed, this means that the connection to
the database is opened and closed every time when a command is sent to the
DBMS. 

In order to fix this, would be nice if the `SQL Workbench` software would have
a start as daemon feature. Since this is not yet the case, at the moment the
transactions cannot be implemented. 

However, I will look into possibilities. If anybody has any idea on how to
implement transactions, I am willing to implement it. 
