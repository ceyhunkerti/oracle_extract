# Fast Oracle to CSV Extraction Utility
- Extracts data from an oracle query and outputs to csv.

## Usage

You may need to setup instant client paths if you don't have it already.

- Download oracle instant client from [here](https://www.oracle.com/database/technologies/instant-client/downloads.html)
- Extract it to a path and set the `LD_LIBRARY_PATH`.

```sh
export LD_LIBRARY_PATH=/path/to/instantclient_[version]
```


```sh
zig-out/bin/ox run \
    --connection-string "localhost:1521/ORCLCDB" \
    --username sys \
    --password Oracle_123 \
    # optional (auth mode)
    --auth-mode SYSDBA \
    --sql "SELECT * FROM sys.table1" \
    # (output-file can be an absolute path)
    --output-file "tmpdir/run1-output.csv" \
    --fetch-size 10000
```


# todo
- Documentation
- Add benchmark results
