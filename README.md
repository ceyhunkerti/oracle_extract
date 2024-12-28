Example project using (oracle) `odpi-c` with zig.

- Extracts data from an oracle query and outputs to csv.
- 4x faster than exporting query result to csv in `dbeaver`, which uses `jdbc`.
- Lots of room for improvement.

## Usage

```sh
zig-out/bin/ox run \
    --connection-string "localhost:1521/ORCLCDB" \
    --username sys \
    --password Oracle_123 \
    --auth-mode SYSDBA \
    --sql "SELECT * FROM sys.table1" \
    --output-file "tmpdir/run1-output.csv" \
    --fetch-size 10000
```



# todo
- Documentation
- Add benchmark results
- Add comparisons.
