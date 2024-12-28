# Oracle to CSV Extraction Utility

- Extracts data from an oracle query and outputs to csv.
- ~3.7x faster than a plugin based JDBC implementation. (with same parameters.)

## Build

You may need to setup instant client paths if you don't have it already.

- Download oracle instant client from [here](https://www.oracle.com/database/technologies/instant-client/downloads.html)
- Extract it to a path and set the `LD_LIBRARY_PATH`.
```sh
export LD_LIBRARY_PATH=/path/to/instantclient_[version]
```

- Install [zig](https://ziglang.org).

- You may need to install `libaio` required by oracle client.
```sh
sudo apt install libaio1
```

- Build the binary.
```sh
zig build -Doptimize=ReleaseFast
```

- See the binary `ox` at `zig-out/bin/`.

## Running

```sh
zig-out/bin/ox run \
    # change below to actual connection string.
    --connection-string "localhost:1521/ORCLCDB" \
    --username oracle_username \
    # optional (auth mode if you need SYSDBA)
    --auth-mode SYSDBA \
    --password oracle_password \
    --sql "SELECT * FROM my_schema.my_table_name" \
    # (output-file can be an absolute path)
    --output-file "output.csv" \
    --fetch-size 10000
```


# todo
- Documentation
- Add benchmark results
