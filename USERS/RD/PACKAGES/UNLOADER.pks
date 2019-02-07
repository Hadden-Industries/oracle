--  FILE:       unloader.sql
--
--  AUTHOR:     Tom Kyte, Expert one-on-one Oracle
--              Andy Rivenes
--  DATE:       Unknown
--
--  DESCRIPTION:
--              Script to unload table data into SQL*Loader format
--              with an appropriate control file.
--
--
--  REQUIREMENTS:
--              Requires UTL_FILE support. The init.ora parameter
--              utl_file must be set to a valid directory.
--              Requires access to dbms_sql and the ability to create
--              this package.
--
--              Note: In 10g UTL_FILE_DIR has been deprecated in favor
--                    of directories.
--
--              As SYSDBA run:
--                CREATE DIRECTORY unloader AS '/u01/app/oracle/unloaddir';
--                GRANT READ, WRITE ON DIRECTORY unloaddir TO unload_user;
--
--
--
--  MODIFICATIONS:
--    Ver. 1.1,  03/31/2003, AR, Modified to perform data type checking,
--               added error messages for unsupported types. Enabled
--               exception handling - was disabled in Tom's version.
--    Ver. 1.2,  05/01/03, AR, Added a "bad" file to the SQLLDR control file.
--    Ver. 1.3,  05/02/03, AR, Added exception to catch utl_file invalid path/file
--               since this will probably be a common error.
--    Ver. 1.4,  09/19/05, AR, Added ability to output a "column header" line.
--    Ver. 1.4a, 09/21/2005, AR, Initial script creation
--    Ver. 1.4b, 10/17/2005, AR, Added "remove" function to support directories.
--    Ver. 1.4c, 10/20/2005, AR, Fixed to handle running as another user (e.g. 
--                              uga account).
--    Ver. 1.4d, 10/21/2005, AR, Corrected directory output in the .ctl file so
--                              that the database directory is translated into
--                              its OS equivalent.
--    Ver. 1.4e, 11/16/2005, AR, Added option to not create a control file.
--    Ver. 1.5,  06/14/2006, AR, Added all 1.4 changes. Both dump_ctl and run have
--                               been overloaded.
--
--  USAGE:
--    To unload using UTL_FILE_DIR:
--
--      SET LINESIZE 150;
--      SET SERVEROUTPUT on SIZE 1000000 FORMAT WRAPPED;
--      --
--      declare
--        --
--        l_rows    number;
--        --
--        begin
--          l_rows := unloader.run
--                    ( p_query      => 'select * from APP_COLUMN_METADATA',
--                      p_tname      => 'TABLE_NAME',
--                      p_mode       => 'truncate',
--                      p_dir        => '/u01/app/oracle/admin/SID/utlfile',
--                      p_filename   => 'unload_file',
--                      p_separator  => ',',
--                      p_enclosure  => '"',
--                      p_terminator => '|'
--                      p_ctl        => 'YES',
--                      p_header     => 'NO' );
--        --
--        dbms_output.put_line( to_char(l_rows) ||
--                              ' rows extracted to ascii file' );
--        --
--      end;
--      /
--
--    To unload using a database directory:
--
--      SET LINESIZE 150;
--      SET SERVEROUTPUT on SIZE 1000000 FORMAT WRAPPED;
--      --
--      declare
--        --
--        l_rows    number;
--        --
--        begin
--          l_rows := unloader.run
--                    ( p_cols       => '*',
--                      p_town       => 'OWNER',
--                      p_tname      => 'TABLE_NAME',
--                      p_mode       => 'truncate',
--                      p_dbdir      => 'dbdir',
--                      p_filename   => 'unload_file',
--                      p_separator  => ',',
--                      p_enclosure  => '"',
--                      p_terminator => '|'
--                      p_ctl        => 'YES',
--                      p_header     => 'NO' );
--        --
--        dbms_output.put_line( to_char(l_rows) ||
--                              ' rows extracted to ascii file' );
--        --
--      end;
--      /
--
--    or to remove a file (expects a database directory):
--
--      SELECT unloader.remove('TOWN','FNAME.dat') FROM dual;
--      SELECT unloader.remove('TOWN','FNAME.ctl') FROM dual;
--
--
SET LINESIZE 150;
SET SERVEROUTPUT on SIZE 1000000 FORMAT TRUNCATED;
--
--
set echo on;
--
create or replace package unloader
as
    function run( p_query      in varchar2 default NULL,
                  p_cols       in varchar2 default '*',
                  p_town       in varchar2 default USER,
                  p_tname      in varchar2,
                  p_mode       in varchar2 default 'REPLACE',
                  p_dir        in varchar2,
                  p_filename   in varchar2,
                  p_separator  in varchar2 default ',',
                  p_enclosure  in varchar2 default '"',
                  p_terminator in varchar2 default '|',
                  p_ctl        in varchar2 default 'YES',
                  p_header     in varchar2 default 'NO' )
    return number;
    --
    function run( p_query      in varchar2 default NULL,
                  p_cols       in varchar2 default '*',
                  p_town       in varchar2 default USER,
                  p_tname      in varchar2,
                  p_mode       in varchar2 default 'REPLACE',
                  p_dbdir      in varchar2,
                  p_filename   in varchar2,
                  p_separator  in varchar2 default ',',
                  p_enclosure  in varchar2 default '"',
                  p_terminator in varchar2 default '|',
                  p_ctl        in varchar2 default 'YES',
                  p_header     in varchar2 default 'NO' )
    return number;
    --
    function remove( p_dbdir      in varchar2,
                     p_filename   in varchar2)
    return number;
    --
    PROCEDURE version;
    --
    PROCEDURE help;
end;
/
