Tutorial
========================================

The following documentation is quite long. If you don't want to read through
it, here is the quick start: 

* install `SQL Workbench/J` from [here](http://www.sql-workbench.net/)
* install your `jdbc` driver for your database see
  [here](http://www.sql-workbench.net/)
* set `SQL Workbench/J` to not use `JLine` (in `SQL Workbench/J` config file,
  add the following line: `workbench.console.use.jline=false`)
* open vim

*Running sql queries against a DBMS*:

* set the `g:sw_config_dir`, `g:sw_exe` and `g:sw_cache` variables
* for `cygwin` environments, please also set the `g:sw_plugin_path` variable
  (this should point to the installation directory of the plugin). For
  example: `c:/Users/cosmin/.vim/bundle/vim-sql-workbench`
* open your sql buffer
* if you have `CtrlP` installed you can do `CtrlP` and then select `SQL
  Workbench profiles` and choose your profile
* otherwise, you can do `:SWSqlBufferConnect` and then in the buffer execute
  `WbConnect` (`<Leader>C-<SPACE>`)
* go to an sql statement
* in normal mode, do `<Leader><C-SPACE>`

*Opening a database explorer*

* `:SWDbExplorer <my-profile>`

*Note*: 

* `<my-profile>` is the name of a database profile created in `SQL Workbench/J`
  (see [here](http://www.sql-workbench.net/manual/profiles.html))

For more detailed explanations, please continue reading this material.

Disclaimer
========================================

Please note that this version is no longer compatible with VIM 7. If you
didn't upgraded to VIM 8 yet, then don't install this version. Stick with
5.2.2. But you should consider upgrading your vim anyway. For the
documentation of `5.2.2`, please see [here](README-7.md)

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
* SQL buffer with very powerfull intellisense auto-completion
* export any sql statement as `text`, `sqlinsert`, `sqlupdate`,
  `sqldeleteinsert`, `xml`, `ods`, `html`, `json`
* search in object source
* search in table or views data
* asynchronous (you can execute any command asynchronous)
* fully customizable
* transactions
* NeoVim 100% support

CONTENTS:

1. Requirements
2. Connecting to a DBMS
3. The database explorer
4. The SQL Buffer
5. SQL commands
6. Searching
7. Exporting
8. Variables
9. Commands
10. Settings
11. DbExt comparison
12. Screen shots

Requirements
========================================

* `Vim 8`
* `SQL Workbench/J` installed on the machine

*NOTE*: this version of `vim-sql-workbench` is not compatible with vim 7 anymore.

Of course you need VIM 8 or above. You also need [`SQL
Workbench/J`](http://www.sql-workbench.net/) installed on your computer. It is
platform independent, since `SQL Workbench` is written in JAVA and it should
work anywhere where VIM works. 

Before getting started, you have to set the `g:sw_exe` vim variable. The
default value is `sqlwbconsole.sh`. Otherwise, just set the value of the
variable to point to your `sqlwbconsole` file. If you are on Windows, it
should be `sqlwbconsole.exe`. 

Also, if you are on Windows, you have to set the `g:sw_tmp` value in your
`vimrc`. The default value is `/tmp`. 

If you are on window, your `SQL Workbench/J` should be configured to not use
the `jline` (set the `workbench.console.use.jline=false` in your `SQL
Workbench/J` config file).

Connecting to a DBMS
========================================

`VIM Sql workbench` has integration with the `CtrlP` plugin. You can set the
`g:sw_config_dir` variable (which contains the `WbProfiles.xml` file) and then
you open your buffer, open `CtrlP`, select `SQL Workbench profiles`, select
your profile and you can begin sending sql queries to your database.

If you don't have `CtrlP` installed, you can use the `:SWSqlBufferConnect`
command. This will open your buffer and connect it to the `SQL Workbench/J`.
If you run it without any arguments, the current buffer will be connected with
a `SQL workbench/J` instance.

*Example*: 

```
:SWSqlBufferConnect ~/Documents/my-buffer.sql
```

Once you connected your buffer (either by `CtrlP` or by using
`SWSqlBufferConnect`), a new `sqlwbconsole.sh` process will be launched. This
will have it's own connection and it's own transaction. If you close the
buffer, also the process will be closed. Also, if you do
`:SWSqlBufferDisconnect`, the `sqlwbconsole` instance will be closed.

The database explorer
========================================

In order to open a database explorer, you need a profile. 

You can create `SQL Workbench` profiles, either by using the `SQL Workbench`
GUI, like
[here](http://www.sql-workbench.net/manual/profiles.html#profile-intro),
either opening a sql buffer with `SWSqlBufferConnect` and then executing
`WbStoreProfile`. 

Once you have your profiles created, you can use `SWDbExplorer` with the
desired profile as argument and you will connect to the database. 

For example, `:SWDbExplorer myProfile` will open a database explorer using the
profile `myProfile`.

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

You can also have profiles per type of DBMS. If you have a profile starting
with a `:` or a '^'.

A `:` means that this options will appear for all the profiles which the DBMS
is of that type. For example `:MySQL` it means that these options will appear
only for `mysql` databases. 

A `^` means that this options will appear for all the profiles for which the
DBMS is not of that type. For example `^PostgreSQL` means that there options
will appear for all databases which are not `PostgreSQL`. 

For this to work, you have to have the option `g:sw_config_dir` set. The
profile informations are read from the `WbProfiles.xml` file which resides in
this folder. The profile type you can see it in the `SQL Workbench/J`
connection window. It's the driver title.

Starting with version `4.0` you can also have a vimscript function called
instead of a sql query. The function called has to return a string which will
be interpreted as the result of the operation. The function will receive as
parameters the line selected (the complete line which has been selected). In
order to have a function instead of a sql query in the database explorer, the
`command` has to begin with `:`. 

For example: 

```
{'title': 'Data', 'shortcut': 'D', 'command': ':My_function'}
```

When the shortcut D will be pressed, the result will be fetch by calling
`My_function(getline('.'))`

Of course, the current line is relevant only for when changing a tab. When
changing a tab, the current line will contain whatever value is on the
current line in whatever buffer you are at that moment.

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
   Alternatively, you can have `%n%` (n being a number from 0 to the number of
   columns in the left panel). If you have `%n%`, this will be replaced by the
   value of that column
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
call sw#dbexplorer#add_tab('oracle', 'DB Links', 'L', 'select db_link, username,
created  from user_db_links;', [{'title': 'Show the host', 'shortcut': 'H',
'command': "select host from user_db_links where db_link = '%object%'"}])
```

Now on all your oracle profiles, you will have an extra option. Every time
when you click "L" in normal mode, in the bottom left panel you will have a
list of database links from your schema. For each link, you can move the
cursor on top of it and click H. You will see in the right panel the source of
the link. 

Every time when "L" is clicked, `vim-sqlworkbench` sends the `select db_link,
username, created from user_db_links;` command to the DBMS. The result will be
a list of database links displayed in the bottom left panel.  When you move
your cursor on top of one of this links and press "H", the plugin sends to
your DBMS `select host from user_db_links where db_link =
'<selected_link_name>';`. The result is displayed in the right panel.

You can also add a panel to an existing tab, using the
`sw#dbexplorer#add_panel` function. The function takes the following arguments:

* The profile (the profile for which the option should be active; it can be
  `*` for all profiles)
* The tab shortcut (is the shortcut identifying the tab for which to add this
  panel)
* The title (this is the title that will appear on the top panel)
* The shortcut (this is the shortcut to access it after you accessed the tab)
* The command (this is the SQL command to be sent to the DBMS once this option
  is selected

## Events

The database explorer has events to which you can hook a function to be
executed before the command is executed or after the result is received. If
you hook to the before event, your function will receive as a parameter the
command being set to a server and it must return the modified command. If you
hoon to the after event, your function will receive the response from the
server (an array of lines) and can modify it. It has to return the result
which will be displayed in the left or right panel (a new list of lines). 

To hook on the tab events, you can use the function
`sw#dbexplorer#add_tab_event`. The arguments are:

* the shortcut of the tab
* the event type (`after` or `before`)
* the function name

*Example:*

```
function! BeforeTabObjects(command)
    return "show tables"
endfunction

function! AfterTabObjects(result)
    let result = []
    for line in a:result
        call add(result, substitute(line, '\v^TABLE_NAME[ \s\t]*$', 'Tables', 'g'))
    endfor
    return  result
endfunction

call sw#dbexplorer#add_tab_event('O', 'before', 'BeforeTabObjects')
call sw#dbexplorer#add_tab_event('O', 'after', 'AfterTabObjects')
```

After executing this example, when you select the Objects tab in the database
explorer, the command executed is going to be `show tables`, instead of
`WbList`, which is the default for objects. Then, when the result is returned,
the line `TABLE_NAME` is going to be replaces with the text "Tables". 

To hook on panel events, you can use the function
`sw#dbexplorer#add_panel_event`. The arguments are:

* the shortcut of the tab
* the shortcut of the panel
* the type of event (`after` or `before`)
* the function name

For an example on how to use this function, see the `resources/dbexplorer.vim`
file (the last line) and the `autoload/sw/dbexplorer.vim` file to see the
function hook definition.

The SQL buffer
========================================

The SQL buffer is a normal `vim` buffer from which you can send SQL commands
to your DBMS and in which you can use the user completion (&lt;C-x&gt;&lt;C-o&gt;) to have
intellisense autocompletion. 

You can connect an opened vim buffer to a server using the
`SWSqlBufferConnect` command. Or, you can open a buffer which will be directly
connected to a server by specifying the path to the buffer. For example
`SWSqlBufferDisconnect /tmp/dbms.sql`.

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
executing the current SQL, the default shortcut is `<leader>ctrl + space`.

The same goes for a result set buffer. The shortcuts from the file pointed by
the `g:sw_shortcuts_sql_results` variable are loaded. If the variable is not
set, then the shortcuts from `resources/shortcuts_sql_results.vim` are loaded.
If you want further details, please have a look at this file. 

You can also have comment in the format `-- before <command>` on a single
line. This comments will be parsed by the plugin. If the command begins with a
`:` it will be interpreted as a `vim` command and executed by vim. Otherwise,
the command will be sent to the DBMS when opening the file.

Examples: 

`-- before start transaction;`

This command will be sent to the DBMS and will start a new transaction every
time when you open this buffer. 

## Execute the current statement

As stated already, you can press `<leader>ctrl + space` in normal mode or
you can have your own shortcut. Alternatively, in normal mode, you can execute
`SWSqlExecuteCurrent` command. 

The statement between the last 2 delimiters will be sent to the server, or
from the beginning of the file until the first delimiter, or from the last
delimiter to the end of the file, depending on where your cursor is placed. 

## Execute the selected statement

In visual mode, you can press `<leader>ctrl + e` or your own custom shortcut.
Alternatively, you can execute the `SWSqlExecuteSelected` command. Please be
careful to delete the range before, if you want to execute the command from
the visual mode. 

The selected text is going to be sent to the DBMS. 

## Execute all statements

In visual mode, you can press `<leader>ctrl + a` or your own custom shortcut.
Alternatively, you can execute the `SWSqlExecuteAll` command. All the buffer
is going to be sent to the DBMS. 

## Events

The following events exist in the plugin: 

* `new_instance` (triggered when a new instance of `SQL Workbench/J` is
  spawned).
* `profile_changed` (triggered every time a connection to a new profile is
  detected)

In order to attach a hook to an event, you have to call `sw#server#add_event`
with 2 arguments: the event name and the event listener. For an example, check
the `plugin/sw.vim` file in the source code.

## Schema report

`SQL Workbench/J` has the ability to generate a very usefull schema report.
This report is used by the autocomplete intellisense and by references tree.
If you want to have intellisense for a profile, in the GUI of `SQL
Workbench/J` profiles page, add the extended property `report` with the value
`true` (see
[here](http://www.sql-workbench.net/manual/profiles.html#profile-extended-properties)).
The report is going to be generated using a paralel background connection.
This means that the current connection will not have to suffer if the report
generation will take too long (depending on your database size, this can even
take several minutes). 

It is very usefull to have this report. Other than intellisense, you can also
see in the db explorer the dependencies tree (`Referenced by` and `References`
options). 

Please note that the intellisense and the references tree will not work
without this report. 

If you have schemas with the same structure from one profile to another you
don't have to generate the report for all the profiles. You can generate it
from one profile (usually `dev` or `test`) and for the rest of the profiles
you can set the extended property `use-report` with the value of the other
profile name, including the group. 

So, for example, if you have the profiles `dev` in the group `LOCAL` and
`prod`, which are basically identically, you might not want to run the schema
report on prod. So, you set the extended property `report` with the value
`true` for the `dev` profile and the extended property `use-report` with the
value `LOCAL\dev`. Like this, every time when you connect to the `dev`
profile, a new connection will be spawned in the background which will
generate the schema report. Once this is generated at least once, you have
intellisense and references tree available. And every time you connect to the
`prod` profile, you always have the same intellisense autocomplete and the
references tree.

## Intellisense

`vim-sql-workbench` plugin comes with intellisense out of the box. In order to
take advantage of the auto complete intellisense, you have to set the schema
report (see the previous section).

If the schema report is available (either by setting the `report` option or by
setting the `use-report` option) you can press &lt;C-x&gt;&lt;C-u&gt; in insert
mode in a sql statement. 

*Note*: due to constant conflicts with dbext plugin (which apparently has some
parts included in the `/usr/share/vim` folder) I prefer to switch to
&lt;C-x&gt;&lt;C-u&gt;. So, you cannot use &lt;C-x&gt;&lt;C-o&gt; anymore for
intellisense

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

*NOTE*: The autocomplete feature is implemented using regular expressions.
Because of using regular expressions, it's possible that I've missed cases. If
you notice any case where the autocomplete is not working properly, please let
me know.

## Get an object definition

When with the cursor on top of any word in the buffer or in the result set,
you can click `<leader>oi` or your own custom shortcut. This will display that
object definition if the object exists in the result set buffer or an error 
message. 

Alternatively you can execute the `SWSqlObjectInfo` command from normal mode. 

Basically the command `desc <object>` is sent to the DBMS and the output 
returned. 

## Get an object source

When you are with the cursor on top of any word in the buffer or in the result
set, you can click `<leader>os` or your own custom shortcut. This will display
the object source if the object exists in the result set buffer or an error 
message.

Alternatively, you can execute the `SWSqlObjectSource` command from normal 
mode.

## Maximum number of rows. 

By default, the maximum number of results returned by a select is 5000. You
can change this with the `set maxrows` command. See
[here](http://www.sql-workbench.net/manual/wb-commands.html#command-set)

## Changing result sets display mode

In the result set buffer, you can click `<leader>d` or your own custom shortcut
on top of a row. This will toggle the row display to have each column on a row
for the selected row. To change back the display mode, click again the same 
shortcut. 

Alternatively, you can execute the `WbDisplay` command. See
[here](http://www.sql-workbench.net/manual/console-mode.html) for more detail.

## Filtering the resultset

While in the result window, you can filter the displayed rows. With the cursor
on a resultset, you can just call the `SWSqlFilter` command with the `where`
condition as parameter. The plugin will send the query to the `dbms` and
display the results in the same resultset.

## Hiding columns

While in a result window, you can hide columns from a result set.

With the cursor on a resultset, you can call the `SWSqlHideColumn` command.
The command takes as an argument the name of the column to hide (there is also
an autocomplete with the available columns).

Example: `SWSqlHideColumn last_name`

## CtrlP integration

`VIM Sql workbench` provides integration with the `CtrlP` plugin. In order to
activate it, you need to set the `g:sw_config_dir` option to point to your
`SQL Workbench/J` configuration directory. Then, in your `.vimrc` file, you
need to activate the `CtrlP` extension `sw_profiles`, by setting the
`g:ctrlp_extensions` variable.

By activating the integration, you can change a buffer connection with
`CtrlP`. You activate `CtrlP` and then select the `SQL Workbench profiles` tab
and select your profile. If the buffer is already connected to an `SQL
Workbench/J` instance, then the current connection will be changed. If no,
then the buffer will get connected to an `SQL Workbench/J` instance and also
open a connection to the selected profile.

## Airline integration

`VIM Sql workbench` also provides integration with [`VIM
Airline`](https://github.com/vim-airline/vim-airline) plugin. Since I haven't
really found out how to create an extension and place it in any folder, you
will have to manually copy the `resources/airline/sw.vim` file into the
`Airline` extensions folder. Then you need to enable the extension in your
`.vimrc` file by setting the `g:airline_extensions` variable to include the
`sw` extension. 

Once you activate the integration, every time when you connect a buffer to an
`SQL Workbench/J` instance, you will see the in the status bar the current
url (next to the file name). If the buffer is connected to `SQL Workbench/J`,
but is not connected to a DBMS, then you will see the `NOT CONNECTED` string.

Alternatively, if you don't use Airline integration, you can still see the
current url in the status line by activating the status line in vim (`set
laststatus = 2`) and then you can set the status line to include the buffer
url. For example: `set statusline=%!sw#server#get_buffer_url(bufname('%'))`.

## Following a foreign key

If you have activated the schema report (see the previous section), you can
(in a result set) follow a foreign key. In a result set, when you are on a
row, you can call `SWSqlReferences` or `SWSqlReferencedBy` commands. 

These two commands take zero or one argument. If you call the commands without
any argument, you will get a list of possible foreign keys, starting from the
current result set and with the values from the current row. You need to
select one, and then the corresponding query will be generated and run.
Otherwise, via auto-completion, you can select which foreign key you want to
follow. 

The `SWSqlReferences` command will tell you what rows the current row is
referencing in another tables, and the command `SWSqlReferencedBy` will tell
you what other rows from other tables are referencing the current row.

*Example*

Let's say, that you have the following table structure:

```
+--------------+    +-------------+
| employees    |    | departments |
+--------------+    +-------------+
| id           |    | id          |
| lastName     |    | name        |
| departmentId |    +-------------+
+--------------+
```

If you execute `select * from employees`, you will get a list of all the
employees. If you go to the resultsets buffer and put the cursor on an
employee (let's say the one with `departmentId = 10` and employee `id = 1`),
you can do

```
SWSqlReferences departments(id)=employees(departmentId)
```

This will generate and automatically execute the query `select * from
departments where id = 10`

Please note that you don't have to type in the argument, you can select it
using the autocomplete of the command. 

Same goes if you execute `select * from departments where id = 10` and the you
select the deparment and you do

```
SWSqlReferencedBy employees(departmentId)=departments(id)
```

You will get a resultset with the employee with the `id` 1.


## Including a file

If you want to create a stored procedure, you might want to execute the current
file. For this you have `SWInclude`. The command will execute the entire file
using the `WbInclude` command from `SQL Workbench/J`. If you follow the command
by a `!`, then the alternate delimiter is used. Otherwise the standard `;`
delimiter is used. The command can also take one argument, which could be the
file to be included, if you don't want it to be the current file.

SQL commands
========================================

You can send a sql query to the DBMS from the vim command line using the
command `SWSqlExecuteNow`. The parameters are the sql query. Please note that
by default no results will be shown. If you want to see all that happened on
the server side, use the `SWSqlExecuteNowLastResult` command. This will show
you what happened with the last command sent from the vim command line. 

This is useful if you want to put vim shortcuts for simple things. Like, for
example, you could have in your `vimrc`:

```
nnoremap <leader>t :SWSqlExecuteNow wbdisplay tab;<cr>
```

Then pressing `<leader>t` in normal mode, would set the display to tab for the
current buffer.

*Note*: This command will not be recorded in `g:sw_last_sql_query`. The
delimiter is the `;`.

Searching
========================================

`SQL Workbench/J` comes with two very handy and powerful commands:
`WbGrepSource` and `WbGrepData`. `vim-sqlworkbench` takes advantage of both of
them and implements searching options. You can search in objects source code,
or you can search tables data.

## Searching in objects source code

Of course, you can always execute `WbGrepSource` in a sql buffer and send it to
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

All the three commands work as their counter parts for searching object.

If you are in an sql buffer, then the results are displayed in the result sets
buffer. If you are in a database explorer, then the search results are
displayed in the bottom left panel. 

Exporting
========================================

`vim-sqlworkbench` takes advantage of the very powerful `SQL Workbench/J`
command, `WbExport`. 

As usual, you can always execute the `WbExport` command inside a sql buffer.
To see the full documentation of the `WbExport` command, have a look
[here](http://www.sql-workbench.net/manual/command-export.html).

*Note*: If you use the wbexport command, you need to send both of the queries
at once, by selecting both queries (first the `WbExport` query and then the
exported query) and then running `SWSqlExecuteSelected`. This happens because
the plugin will send after each statement a silent command to notice vim that
a new result is waiting. So, if you execute `WbExport`, the exported statement
will be the silent one which is void and is not a `select` statement. 

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

Variables
========================================

`SQL Workbench/j` supports user defined variables (you can have your queries
sent to the database parameterized). See
[here](http://www.sql-workbench.net/manual/using-variables.html). 

By default, in `SQL Workbench`, the variables are enclosed between `$[` and
`]`. [These can be
changed](http://www.sql-workbench.net/manual/using-variables.html#access-variable). 

You can use `WbVarSet` and `WbVarUnset` in a sql buffer. If you want the
system to ask for a value, then you can use the `$[?` form of a parameter.
Please note that in `VIM Sql Workbench` there is no difference between `?` and
`&`, since there is no way to get a list of vars in `vimscript` from `SQL
Workbench/J`

Commands
========================================

## SWDbExplorer

*Parameters*:

* profile name: the name of the profile for which to open the database explorer. 
* port: the port on which the server listens

Opens a database explorer for the desired profile using the server from the
specified port. 

*NOTE*: If you set the
`g:sw_config_dir` variable to point to the `SQL Workbench/J` settings folder,
the command will autocomplete the profile names. See
[here](http://www.sql-workbench.net/manual/install.html#config-dir)

## SWDbExplorerClose

*Parameters*; 

* profile name (optional): the name of the database explorer that should be
  closed. 

Closes a database explorer. If no profile name is specified, if you are inside
a database explorer, then that database explorer is closed. Otherwise, the
system will generate an error. 

If you specify a profile name, then the database explorer which is opened for
the indicated profile is closed. 

## SWSqlExecuteCurrent

In an sql buffer executes the current statement. You can execute this command
in normal or insert mode. This is the statement between two consecutive
identifiers, or from the beginning of the file to the first identifier or from
the last identifier to the end of the file. You can change the delimiter using
the `SWSqlDelimiter` command. 

If you follow the command by a `!`, then the alternate delimiter is used. You
can set the alternate delimiter in the connection properties.

*NOTE*: if the file that you are in is delimiter by a normal delimiter (`;`) and
you want to execute the command with the alternate delimiter, you have to have
the alternate delimiter before and after the current query, otherwise, all the
other queries will be sent to the `DBMS`. If you only want to execute one query
with the alternate delimiter and all the queries in your file are using the
standard semmicolumn delimiter, better select the query and execute
`SWSqlExecuteSelected!`

## SWSqlExecuteSelected

In an sql buffer, executes the current selected statement. The command works
in visual mode. Be careful to delete the range before typing the command. 

If you follow the command by a `!`, then the alternate delimiter is used. You
can set the alternate delimiter in the connection properties.

## SWSqlExecuteAll

Send all sql statements from the buffer to the DBMS. 

## SWSqlToggleMessages

If you have a result set displayed in the result set buffer, you can toggle
between the result displayed and the messages produced by the command with
this command. The command works from the sql buffer and from the result set 
buffer.

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

## SWSqlExecuteNow

*Parameters*:

* port: the port on which to execute the command
* sql: The query to be sent to the DBMS

Executes a query against the DBMS on the indicated port.

## SWSqlExecuteNowLastResult

Shows the communication with the server for the last `SWSqlExecuteNow` command.

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

## SWDbExplorerToggleFormDisplay

If on a line in the results panel which contains a row in a resultset, then
this row will be displayed as a form. If already displaying a form, then the
resultset will be displayed.

## SWSqlShowAllColumns

This will unhide all hidden columns from the current result set

## SWSqlWipeoutResultsSets

This will wipeout the list of the resultsets. If you execute multiple sql
statements, the results are stored in the resultsets buffer. When you close
it, and then execute another sql statement, you will notice that the latest
result sets are still there. If you don't want this, you can call this
command. Next time you execute an sql statement, the resultsets will be empty.

If you want to wipeout all the resultsets for all buffers, you have to execute
the command followed by a `!` (`SWSqlWipeoutResultsSets!`).

## SWSqlShowOnlyColumns

* column names: a list of white space separated list of columns to be shown

This will hide all the columns from the current resultset with the exception
of the mentioned columns

*Note*: there is an autocomplete for the column names

## SWSqlShowColumn

*Parameters*: 

* column name: the name of the column to show

This will show the indicated column name (assuming that it is hidden)

*Note*: there is an autocomplete for the column name

## SWSqlHideColumn

*Parameters*:

* column name: the name of the column to hide

This will hide the indeicated column.

*Note*: there is an autocomplete for the column name

## SWSqlFilter

*Parameters*:

* where: The `where` condition for the current resultset.

This will construct a query from the given resultsets query with an added
`where` to filter it.

*Note*: there is an autocomplete for the column name

## SWSqlUnfilter

This will remove any filters applied on the specified resultset

#SWSqlBufferConnect

*Parameters*:

* buffer name: the name of the buffer to open and connect to an `SQL
  Workbench/J` instance (optional)

This command will open the selected buffer and connect it to an `SQL
Workbench/J` instance. If the parameter is missing, then the current buffer
will be connected to an `SQL Workbench/J` instance.

*Note*: when you close the buffer, the `SQL Workbench/J` instance process will
also be killed. If you want to close it gracefully, you can use
`SWSqlBufferDisconnect` command, which will send an `exit` to the `SQL
Workbench/J`.

## SWSqlBufferDisconnect

This command will disconnect the current buffer from the `SQL Workbench/J` and
close the `sqlwbconsole` process.

## SWSqlGetSqlCount

In a connected sql buffer, if you call this command, a query will be sent to
the DBMS fetching the number of rows of the current sql. For example, if your
cursor is on the `select * from mu_table`; and you call this command, then
the query sent to the DBMS is `select count(*) from (select * from my_table);`

## SWSqlGetObjRows

In a connected sql buffer, if you call this command, a query will be sent to
the DBMS to fetch the number of rows of the currently selected object. For
example, if your cursor is on top of the `my_table` identifier and you call
this command, the query sent to the DBMS is `select count(*) from my_table`.

## SWSqlShowActiveConnections

This command will display a list of all the active connected buffers to a `SQL
Workbench/J` instance with their connection strings.

## SWSqlShoLog

This command will open the log of the sql queries sent to the DBMS. If the
`g:sw_log_to_file` is set to true, then the name of the file in which the log
is performed is returned. Otherwise you will see the log.

## SWSqlShowLastResultset

This command will re-open the resultsets window without sending a new command
to the DBMS.

## SWSqlDeleteResultSet

This command will delete the currently selected resultset from the resultsets
window.

## SWSqlRefreshResultSet

This command will refresh the currently selected resultset from the resultsets
window.

## SWSqlBufferShareConnection

This command will share a connection between the current buffer and the one
indicated in the command

## SWSqlReferences

*Parameters*:

* reference: The column to follow.

Given a column name and a reference, this will fetch the rows from referenced
from the current resultset in the destination table.

## SWSqlReferencedBy

*Paramaters*:

* reference: The column to be followed in the current resultset

Given a column name and a reference, this will fetch the rows from the source
table which are referencing the current row.

## SWSqlGenerateInsert

*Parameters*:

* table: The first parameter is the table for which to generate the insert
* columns: The following parameters are the table columns (if missing, the
  insert will be generated for all table columns)

This will generate an insert for the given table and columns. The insert will
be copied to clipboard by default. If you want it to also be executed
immediatelly, you can expand it using the `!` after the command (see `:help
bang`).

## SWSqlGetMacroSql

If the cursor is on a macro, this command will return the current sql behind
the macro see [here](http://www.sql-workbench.net/manual/macros.html). The sql
is coppied to clipboard.

## SWSqlInsertMatch

If you are with the cursor in the fields part of an sql, this will show you
the corresponding value in a message. If your cursor is on the values part,
then this will show you the corresponding column.

*Note*: This will not move the cursor by default. If you want you can add the
following shortcuts to your `vimrc`:

```
nmap <Leader>* :SWSqlInsertMatch<cr>n
nmap <Leader># :SWSqlInsertMatch<cr>N
```

Then, in an insert columns part, you can click `leader` and then `#` and this
will also put the cursor on the value. However, if there is something else
between the cursor and the value with the same name, the cursor will stop
there (this is not 100% safe). Observe that the shortcut will execute
`SWSqlInsertMatch` and then do a `n` (next result).

## CtrlPSW

If you activated the integration with `CtrlP`, then this will open up directly
`CtrlP` in the `SQL Workbench/J profiles` tab

## CtrlPClearSWCache

This will reset the profiles cache. Next time when you will access the `CtrlP`
workbench tab, the profiles will be read again.

## SWInclude

*Parameters*:

* the file to include (optional, default the current file)

The command will include a given file or the current file. It will execute
`wbinclude -file=<file or current file>;`. If you follow the command by a `!`,
then the alternate delimiter is used.


Settings
========================================

## Search object source settings:

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

* `g:sw_sqlopen_command`: the vim command used by `SWSqlBufferConnect`
  command to open a buffer; possible values: `e|tabnew`; default value: "e",
  which means open with vim `edit` command
* `g:sw_tab_switches_between_bottom_panels`: if set to true, then clicking tab
  in a db explorer will switch between the bottom panels
* `g:sw_cache`: the location where the cached data is going to be saved
  (autocomplete data, profiles data etc.)
* `g:sw_switch_to_results_tab`: If true, then switch to the results buffer
  after executting a query
* `g:sw_highlight_resultsets`: If true, highlight the resultsets headers
* `g:sw_command_timer`: If true, then when launching a command, if it takes
  more than one second, you will see a timer in the bottom left of the status
  bar
* `g:sw_log_to_file`: If true, then the logging of the communication between
  `VIM` and `SQL Workbench/J` will be done in a file; otherwise, the logging
  is done in memory
* `g:sw_sql_name_result_tab`: If enable, rename the result tab using @wbresult;
     default value: 1

## Database explorer settings

* `g:sw_default_right_panel_type`: the file type of the bottom right panel
  when not specified; default value: "txt"

## General settings:

* `g:sw_exe`: the location of the `SQL Workbench` executable; default value:
  "sqlwbconsole.sh"; you need to set it for the plugin to work
* `g:sw_tmp`: the location of your temporary folder; default value: "/tmp"
* `g:sw_delete_tmp`: if true, then delete the temporary files created to
  execute any command. Useful for debugging. You can set it to 0 and check all
  the generated files
* `g:sw_save_resultsets`: if true, then all the resultsets will be saved,
  event if you close the resultsets window; to clear the resultsets window,
  use `SWSqlWipeoutResultsSets` command.
* `g:sw_config_dir`: the config dir of the `SQL Workbench/J` (works only with
  build 121.4 and more)
* `g:sw_plugin_path`: for `cygwin` environments: specify the plugin
  installation path (for example `c:/Users/cosmin/.vim/bundle/vim-sql-workbench`)
* `g:sw_prefer_sql_over_macro`: if true, when executing a macro, the plugin
  will send to `SQL Workbench/J` the query behind the macro

DbExt vs VIM SQL Workbench
========================================

```
+--------------------------------------+-----------------+-------------------+
| Feature                              | DbExt           | vim sql workbench |
+--------------------------------------+-----------------+-------------------+
| Dependencies                         | perl, perl ODBC | SQL Workbench/J   |
|                                      |                 |                   | 
| GUI                                  |                 |                   |
|   Menus                              |        X        |         -         |
|   Management of profile              |        -        |         X         |   
|                                      |                 |                   | 
| Profiles                             |                 |                   |
|   Prompt for connection parameters   |        X        |         -         |
|   Manage profiles                    |        X        |         X         |
|   Read only profiles                 |        -        |         X         |
|   Connect to several DBMS            |        X        |         X         |
|                                      |                 |                   |
| Result sets                          |                 |                   |
|   Execute SQL statements from buffer |        X        |         X         |
|   Refresh a result set               |        X        |         X         |
|   Change display (form or tabular)   |        X        |         X         |
|   Parameters substitutions           |        X        |         X         |
|   Asynchronious execution of sqls    |        -        |         X         |
|   Mappings                           |        X        |         X         |
|   Mappings with sql commands         |        X        |         X         |
|   Intellisense autocompletion        |        -        |         X         |
|   SQL History                        |        X        |         X         |
|   Transactions                       |        X        |         X         |
|   Export of sql resultsets           |        -        |         X         |
|   Import from various formats        |        -        |         X         |
|   SQL Commands confirmation          |        -        |         X         |
|   Follow foreign key in result set   |        -        |         X         |
|   Filter resultsets                  |        -        |         X         |
|   Hide columns in result sets        |        -        |         X         |
|                                      |                 |                   | 
| Database explorer                    |        -        |         X         |
|   See the references tree of a table |        -        |         X         |
|                                      |                 |                   | 
| Tools                                |                 |                   |
|   Parse non sql files                |        X        |         -         |
|   Macros                             |        -        |         X         |
|   Search in tables definition        |        -        |         X         |
|   Search for data in tables          |        -        |         X         |
|   Comparing databases                |        -        |         X         |
|   Copy across databases              |        -        |         X         |
|   Use annotations                    |        -        |         X         |
+--------------------------------------+-----------------+-------------------+
```

Initially, I started this tool as a proof of concept for the console
capabilities of `SQL Workbench/J`. It was just a toy. Without transactions, I
was basically using it just to do a few selects. Every time I would need
something more serious, I would open the GUI of `SQL Workbench/J` and work
there. 

In time though, this tool has become more powerfull with each version, and it
reached the phase where I don't need to open the GUI version for anything. The
last thing that I was using the GUI version for, was the dependencies tree.
Starting with version 7, once I succedeed in including this in the plugin
database explorer, I basically stopped using the GUI version and I work only
from within `VIM`.  

Another thing I noticed is that this plugin surpassed `DbExt` in terms of
available features long time ago, so I thought to do a quick comparison.
From the beginning, I have to let the reader know that this comparison has
been done only based on the `DbExt` documentation, since I was not able to
actually install `DbExt`. `Perl` dependency was a bump, and then trying to use
the `mysql` client was a no go because I have `mysql` installed in a non
standard path. 

Another thing worth mentioning is that the comparison is with `DbExt` perl
feature, since without `Perl` and without transactions, `DbExt` is just a
toy which cannot really be used profesionally. So the comparison is between
this plugin and the `DbExt` ODBC features. Because of this, for example, when
it comes to `cygwin`, there is no comparison to be made. I would go with this
plugin without thinking twice. This is why, for example I put a `-` (missing
feature) to the asynchronous processing. `DbExt` has asynchronous processing
only for the non `ODBC` way of sending queries, which cannot even be
considered for professional usage. The ODBC does not have asynchronous
processing. So, let's begin.

## Installation

When it comes to installing the two plugins, for `DbExt`, you need root
permissions (if you don't have perl) installed on the computer, you need a `vim`
compiled with `perl` and you need to install `perl` modules. In comparison, for
`vim-sql-workbench`, you only need to install the `SQL Workbench/J` application,
which is a java app (so no root needed) and to download the required `jdbc`
driver. That's it. So, a big plus for this plugin.

## GUI

In terms of GUI, DbExt has menus integration, which this plugin lacks. This is a
plus for DbExt.

## Profiles

DbExt has an option to ask for a connection parameters, which this plugin does
not have at the moment (will be implemented in a future version). Other than
that, the profiles for this plugin can be managed using the GUI of `SQL
Workbench/J`, which is a very convenient way of doing this, so in terms of
profile management, a plus again for `vim-sql-workbench`. Also, another plus it
is represented by the possibility of `SQL Workbench/J` to have readonly
profiles.

## SQL windows and resultsets

When it comes to the basics that anyone could expect from a plugin made to
execute SQL queries agains a database, both softwares have everything (refresh a
resultset, parameters substitution, history, transactions etc.). 

But when it comes to advanced features, there cannot be any comparison.
`vim-sql-workbench` has asynchronious execution, very powerfull trully
intellisense autocompletion, export of results, import from various formats,
confirmation of commands execution, following of foreign keys (what other tables
are referencing the current row, or what other tables is the current row
referencing). `DbExt` lacks all of these (the autocomplete of `DbExt` is again,
a toy compared with the intellisense offered by this plugin), so again, a very
big plus for `vim-sql-workbench`.

Also, this plugin has a database explorer, which includes a database references
tree.

## Tools

One thing that `DbExt` is doing and this plugin is not is parsing non-sql files,
extracting a query and running it against a database. This is a plus for
`DbExt`. 

But in terms of tools, this plugin has macros (basically sql queries shortcuts),
can search for terms in table definitions or can search for data in tables, can
compare two databases, can copy data across databases or can use special
comments in queries which will be interpreted by the `SQL Workbench/J` engine
(like annotations). Altough all these tools are comming as a part of `SQL
Workbench/J`, they can be used directly in vim with the help of this plugin. As
I was saying in the beginning of this chapter, no need to open the GUI `SQL
Workbench/J`. So, again, in terms of tools, a big plus for `vim-sql-workbench`.

## Conclusion

As seen, this plugin has surpassed `DbExt` in terms of features long time ago.
However, if anyone considers that I've missed something, please open an issue
and let me know.

Screen shots
========================================

![Database explorer](resources/screenshots/s01.jpg)
![Database explorer source view](resources/screenshots/s02.jpg)
![Database explorer column view](resources/screenshots/s03.jpg)
![SQL Buffer result set](resources/screenshots/s04.jpg)
![SQL Buffer row displayed as form](resources/screenshots/s05.jpg)
![SQL Buffer resultset messages](resources/screenshots/s06.jpg)
