pgdb
=====

An OTP library wrapping the psql and episcina libraries.

It adds:

## Use

Add as a dependency in your erlang node.

## Configuration

```erlang
{pgdb, [
    {pools, [
        {primary, [
            {size, 20},
            {timeout, 10000},
            {connection, [
                {host, "localhost"},
                {database, "postgres"},
                {port, 5432},
                {user, "postgres"},
                {password, "postgres"}
            ]}
        ]}
    ]}
]}.
```

##

Pools = [
    {primary, [
        {size, 20},
        {timeout, 10000},
        {connection, [
            {host, "127.0.0.1"},
            {database, "postgres"},
            {port, 5432},
            {user, "postgres"},
            {password, "postgres"}
        ]}
    ]}
].
application:set_env(pgdb, pools, Pools).
application:ensure_all_started(pgdb).
_ = [gproc:await({n, l, {epna_pool, P}}) || {P, _} <- element(2, application:get_env(pgdb, pools))].

pgdb:simple_query("select * from foo").

pgdb:get_connection(primary).


dbg:tracer(), dbg:p(all,c).
dbg:tpl(epna_pool, '_', []).
dbg:tpl(gproc, '_', []).
dbg:tpl(epna_sup, '_', []).