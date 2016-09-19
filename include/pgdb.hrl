
-type condition()       ::  {condition_op(), db_field(), any()}.
-type condition_op()    ::  '=' | '<' | '>' | '!=' | '=<' | '>='.
-type db_field()        ::  binary().
-type error() 			:: 	{error, Reason :: any()}.
-type row()         	::  pgsql_connection:row().
