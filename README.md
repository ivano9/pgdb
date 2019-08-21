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
                {host, "52.37.75.52"},
                {database, "postgres"},
                {port, 5432},
                {user, "Sample User"},
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
            {port, 32768},
            {user, "postgres"},
            {password, "postgres"}
        ]}
    ]}
].
application:set_env(pgdb, pools, Pools).
application:ensure_all_started(pgdb).
pgdb:simple_query("select * from foo").