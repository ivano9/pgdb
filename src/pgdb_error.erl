-module(pgdb_error).

-export([name/1]).

%% Class 00 — Successful Completion;
name(<<"00000">>) -> successful_completion;
%% Class 01 — Warning
name(<<"01000">>) -> warning;
name(<<"0100C">>) -> dynamic_result_sets_returned;
name(<<"01008">>) -> implicit_zero_bit_padding;
name(<<"01003">>) -> null_value_eliminated_in_set_function;
name(<<"01007">>) -> privilege_not_granted;
name(<<"01006">>) -> privilege_not_revoked;
name(<<"01004">>) -> string_data_right_truncation;
name(<<"01P01">>) -> deprecated_feature;
%% Class 02 — No Data (this is also a warning class per the SQL standard)
name(<<"02000">>) -> no_data;
name(<<"02001">>) -> no_additional_dynamic_result_sets_returned;
%% Class 03 — SQL Statement Not Yet Complete
name(<<"03000">>) -> sql_statement_not_yet_complete;
%% Class 08 — Connection Exception
name(<<"08000">>) -> connection_exception;
name(<<"08003">>) -> connection_does_not_exist;
name(<<"08006">>) -> connection_failure;
name(<<"08001">>) -> sqlclient_unable_to_establish_sqlconnection;
name(<<"08004">>) -> sqlserver_rejected_establishment_of_sqlconnection;
name(<<"08007">>) -> transaction_resolution_unknown;
name(<<"08P01">>) -> protocol_violation;
%% Class 09 — Triggered Action Exception
name(<<"09000">>) -> triggered_action_exception;
%% Class 0A — Feature Not Supported
name(<<"0A000">>) -> feature_not_supported;
%% Class 0B — Invalid Transaction Initiation
name(<<"0B000">>) -> invalid_transaction_initiation;
%% Class 0F — Locator Exception
name(<<"0F000">>) -> locator_exception;
name(<<"0F001">>) -> invalid_locator_specification;
%% Class 0L — Invalid Grantor
name(<<"0L000">>) -> invalid_grantor;
name(<<"0LP01">>) -> invalid_grant_operation;
%% Class 0P — Invalid Role Specification
name(<<"0P000">>) -> invalid_role_specification;
%% Class 0Z — Diagnostics Exception
name(<<"0Z000">>) -> diagnostics_exception;
name(<<"0Z002">>) -> stacked_diagnostics_accessed_without_active_handler;
%% Class 20 — Case Not Found
name(<<"20000">>) -> case_not_found;
%% Class 21 — Cardinality Violation
name(<<"21000">>) -> cardinality_violation;
%% Class 22 — Data Exception
name(<<"22000">>) -> data_exception;
name(<<"2202E">>) -> array_subscript_error;
name(<<"22021">>) -> character_not_in_repertoire;
name(<<"22008">>) -> datetime_field_overflow;
name(<<"22012">>) -> division_by_zero;
name(<<"22005">>) -> error_in_assignment;
name(<<"2200B">>) -> escape_character_conflict;
name(<<"22022">>) -> indicator_overflow;
name(<<"22015">>) -> interval_field_overflow;
name(<<"2201E">>) -> invalid_argument_for_logarithm;
name(<<"22014">>) -> invalid_argument_for_ntile_function;
name(<<"22016">>) -> invalid_argument_for_nth_value_function;
name(<<"2201F">>) -> invalid_argument_for_power_function;
name(<<"2201G">>) -> invalid_argument_for_width_bucket_function;
name(<<"22018">>) -> invalid_character_value_for_cast;
name(<<"22007">>) -> invalid_datetime_format;
name(<<"22019">>) -> invalid_escape_character;
name(<<"2200D">>) -> invalid_escape_octet;
name(<<"22025">>) -> invalid_escape_sequence;
name(<<"22P06">>) -> nonstandard_use_of_escape_character;
name(<<"22010">>) -> invalid_indicator_parameter_value;
name(<<"22023">>) -> invalid_parameter_value;
name(<<"2201B">>) -> invalid_regular_expression;
name(<<"2201W">>) -> invalid_row_count_in_limit_clause;
name(<<"2201X">>) -> invalid_row_count_in_result_offset_clause;
name(<<"22009">>) -> invalid_time_zone_displacement_value;
name(<<"2200C">>) -> invalid_use_of_escape_character;
name(<<"2200G">>) -> most_specific_type_mismatch;
name(<<"22004">>) -> null_value_not_allowed;
name(<<"22002">>) -> null_value_no_indicator_parameter;
name(<<"22003">>) -> numeric_value_out_of_range;
name(<<"22026">>) -> string_data_length_mismatch;
name(<<"22001">>) -> string_data_right_truncation;
name(<<"22011">>) -> substring_error;
name(<<"22027">>) -> trim_error;
name(<<"22024">>) -> unterminated_c_string;
name(<<"2200F">>) -> zero_length_character_string;
name(<<"22P01">>) -> floating_point_exception;
name(<<"22P02">>) -> invalid_text_representation;
name(<<"22P03">>) -> invalid_binary_representation;
name(<<"22P04">>) -> bad_copy_file_format;
name(<<"22P05">>) -> untranslatable_character;
name(<<"2200L">>) -> not_an_xml_document;
name(<<"2200M">>) -> invalid_xml_document;
name(<<"2200N">>) -> invalid_xml_content;
name(<<"2200S">>) -> invalid_xml_comment;
name(<<"2200T">>) -> invalid_xml_processing_instruction;
%% Class 23 — Integrity Constraint Violation
name(<<"23000">>) -> integrity_constraint_violation;
name(<<"23001">>) -> restrict_violation;
name(<<"23502">>) -> not_null_violation;
name(<<"23503">>) -> foreign_key_violation;
name(<<"23505">>) -> unique_violation;
name(<<"23514">>) -> check_violation;
name(<<"23P01">>) -> exclusion_violation;
%% Class 24 — Invalid Cursor State
name(<<"24000">>) -> invalid_cursor_state;
%% Class 25 — Invalid Transaction State
name(<<"25000">>) -> invalid_transaction_state;
name(<<"25001">>) -> active_sql_transaction;
name(<<"25002">>) -> branch_transaction_already_active;
name(<<"25008">>) -> held_cursor_requires_same_isolation_level;
name(<<"25003">>) -> inappropriate_access_mode_for_branch_transaction;
name(<<"25004">>) -> inappropriate_isolation_level_for_branch_transaction;
name(<<"25005">>) -> no_active_sql_transaction_for_branch_transaction;
name(<<"25006">>) -> read_only_sql_transaction;
name(<<"25007">>) -> schema_and_data_statement_mixing_not_supported;
name(<<"25P01">>) -> no_active_sql_transaction;
name(<<"25P02">>) -> in_failed_sql_transaction;
%% Class 26 — Invalid SQL Statement Name
name(<<"26000">>) -> invalid_sql_statement_name;
%% Class 27 — Triggered Data Change Violation
name(<<"27000">>) -> triggered_data_change_violation;
%% Class 28 — Invalid Authorization Specification
name(<<"28000">>) -> invalid_authorization_specification;
name(<<"28P01">>) -> invalid_password;
%% Class 2B — Dependent Privilege Descriptors Still Exist
name(<<"2B000">>) -> dependent_privilege_descriptors_still_exist;
name(<<"2BP01">>) -> dependent_objects_still_exist;
%% Class 2D — Invalid Transaction Termination
name(<<"2D000">>) -> invalid_transaction_termination;
%% Class 2F — SQL Routine Exception
name(<<"2F000">>) -> sql_routine_exception;
name(<<"2F005">>) -> function_executed_no_return_statement;
name(<<"2F002">>) -> modifying_sql_data_not_permitted;
name(<<"2F003">>) -> prohibited_sql_statement_attempted;
name(<<"2F004">>) -> reading_sql_data_not_permitted;
%% Class 34 — Invalid Cursor Name
name(<<"34000">>) -> invalid_cursor_name;
%% Class 38 — External Routine Exception
name(<<"38000">>) -> external_routine_exception;
name(<<"38001">>) -> containing_sql_not_permitted;
name(<<"38002">>) -> modifying_sql_data_not_permitted;
name(<<"38003">>) -> prohibited_sql_statement_attempted;
name(<<"38004">>) -> reading_sql_data_not_permitted;
%% Class 39 — External Routine Invocation Exception
name(<<"39000">>) -> external_routine_invocation_exception;
name(<<"39001">>) -> invalid_sqlstate_returned;
name(<<"39004">>) -> null_value_not_allowed;
name(<<"39P01">>) -> trigger_protocol_violated;
name(<<"39P02">>) -> srf_protocol_violated;
%% Class 3B — Savepoint Exception
name(<<"3B000">>) -> savepoint_exception;
name(<<"3B001">>) -> invalid_savepoint_specification;
%% Class 3D — Invalid Catalog Name
name(<<"3D000">>) -> invalid_catalog_name;
%% Class 3F — Invalid Schema Name
name(<<"3F000">>) -> invalid_schema_name;
%% Class 40 — Transaction Rollback
name(<<"40000">>) -> transaction_rollback;
name(<<"40002">>) -> transaction_integrity_constraint_violation;
name(<<"40001">>) -> serialization_failure;
name(<<"40003">>) -> statement_completion_unknown;
name(<<"40P01">>) -> deadlock_detected;
%% Class 42 — Syntax Error or Access Rule Violation
name(<<"42000">>) -> syntax_error_or_access_rule_violation;
name(<<"42601">>) -> syntax_error;
name(<<"42501">>) -> insufficient_privilege;
name(<<"42846">>) -> cannot_coerce;
name(<<"42803">>) -> grouping_error;
name(<<"42P20">>) -> windowing_error;
name(<<"42P19">>) -> invalid_recursion;
name(<<"42830">>) -> invalid_foreign_key;
name(<<"42602">>) -> invalid_name;
name(<<"42622">>) -> name_too_long;
name(<<"42939">>) -> reserved_name;
name(<<"42804">>) -> datatype_mismatch;
name(<<"42P18">>) -> indeterminate_datatype;
name(<<"42P21">>) -> collation_mismatch;
name(<<"42P22">>) -> indeterminate_collation;
name(<<"42809">>) -> wrong_object_type;
name(<<"42703">>) -> undefined_column;
name(<<"42883">>) -> undefined_function;
name(<<"42P01">>) -> undefined_table;
name(<<"42P02">>) -> undefined_parameter;
name(<<"42704">>) -> undefined_object;
name(<<"42701">>) -> duplicate_column;
name(<<"42P03">>) -> duplicate_cursor;
name(<<"42P04">>) -> duplicate_database;
name(<<"42723">>) -> duplicate_function;
name(<<"42P05">>) -> duplicate_prepared_statement;
name(<<"42P06">>) -> duplicate_schema;
name(<<"42P07">>) -> duplicate_table;
name(<<"42712">>) -> duplicate_alias;
name(<<"42710">>) -> duplicate_object;
name(<<"42702">>) -> ambiguous_column;
name(<<"42725">>) -> ambiguous_function;
name(<<"42P08">>) -> ambiguous_parameter;
name(<<"42P09">>) -> ambiguous_alias;
name(<<"42P10">>) -> invalid_column_reference;
name(<<"42611">>) -> invalid_column_definition;
name(<<"42P11">>) -> invalid_cursor_definition;
name(<<"42P12">>) -> invalid_database_definition;
name(<<"42P13">>) -> invalid_function_definition;
name(<<"42P14">>) -> invalid_prepared_statement_definition;
name(<<"42P15">>) -> invalid_schema_definition;
name(<<"42P16">>) -> invalid_table_definition;
name(<<"42P17">>) -> invalid_object_definition;
%% Class 44 — WITH CHECK OPTION Violation
name(<<"44000">>) -> with_check_option_violation;
%% Class 53 — Insufficient Resources
name(<<"53000">>) -> insufficient_resources;
name(<<"53100">>) -> disk_full;
name(<<"53200">>) -> out_of_memory;
name(<<"53300">>) -> too_many_connections;
name(<<"53400">>) -> configuration_limit_exceeded;
%% Class 54 — Program Limit Exceeded
name(<<"54000">>) -> program_limit_exceeded;
name(<<"54001">>) -> statement_too_complex;
name(<<"54011">>) -> too_many_columns;
name(<<"54023">>) -> too_many_arguments;
%% Class 55 — Object Not In Prerequisite State
name(<<"55000">>) -> object_not_in_prerequisite_state;
name(<<"55006">>) -> object_in_use;
name(<<"55P02">>) -> cant_change_runtime_param;
name(<<"55P03">>) -> lock_not_available;
%% Class 57 — Operator Intervention
name(<<"57000">>) -> operator_intervention;
name(<<"57014">>) -> query_canceled;
name(<<"57P01">>) -> admin_shutdown;
name(<<"57P02">>) -> crash_shutdown;
name(<<"57P03">>) -> cannot_connect_now;
name(<<"57P04">>) -> database_dropped;
%% Class 58 — System Error (errors external to PostgreSQL itself)
name(<<"58000">>) -> system_error;
name(<<"58030">>) -> io_error;
name(<<"58P01">>) -> undefined_file;
name(<<"58P02">>) -> duplicate_file;
%% Class F0 — Configuration File Error
name(<<"F0000">>) -> config_file_error;
name(<<"F0001">>) -> lock_file_exists;
%% Class HV — Foreign Data Wrapper Error (SQL/MED)
name(<<"HV000">>) -> fdw_error;
name(<<"HV005">>) -> fdw_column_name_not_found;
name(<<"HV002">>) -> fdw_dynamic_parameter_value_needed;
name(<<"HV010">>) -> fdw_function_sequence_error;
name(<<"HV021">>) -> fdw_inconsistent_descriptor_information;
name(<<"HV024">>) -> fdw_invalid_attribute_value;
name(<<"HV007">>) -> fdw_invalid_column_name;
name(<<"HV008">>) -> fdw_invalid_column_number;
name(<<"HV004">>) -> fdw_invalid_data_type;
name(<<"HV006">>) -> fdw_invalid_data_type_descriptors;
name(<<"HV091">>) -> fdw_invalid_descriptor_field_identifier;
name(<<"HV00B">>) -> fdw_invalid_handle;
name(<<"HV00C">>) -> fdw_invalid_option_index;
name(<<"HV00D">>) -> fdw_invalid_option_name;
name(<<"HV090">>) -> fdw_invalid_string_length_or_buffer_length;
name(<<"HV00A">>) -> fdw_invalid_string_format;
name(<<"HV009">>) -> fdw_invalid_use_of_null_pointer;
name(<<"HV014">>) -> fdw_too_many_handles;
name(<<"HV001">>) -> fdw_out_of_memory;
name(<<"HV00P">>) -> fdw_no_schemas;
name(<<"HV00J">>) -> fdw_option_name_not_found;
name(<<"HV00K">>) -> fdw_reply_handle;
name(<<"HV00Q">>) -> fdw_schema_not_found;
name(<<"HV00R">>) -> fdw_table_not_found;
name(<<"HV00L">>) -> fdw_unable_to_create_execution;
name(<<"HV00M">>) -> fdw_unable_to_create_reply;
name(<<"HV00N">>) -> fdw_unable_to_establish_connection;
%% Class P0 — PL/pgSQL Error
name(<<"P0000">>) -> plpgsql_error;
name(<<"P0001">>) -> raise_exception;
name(<<"P0002">>) -> no_data_found;
name(<<"P0003">>) -> too_many_rows;
%% Class XX — Internal Error
name(<<"XX000">>) -> internal_error;
name(<<"XX001">>) -> data_corrupted;
name(<<"XX002">>) -> index_corrupted;
name(Unknown) -> Unknown.

