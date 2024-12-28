zig-out/bin/ox run \
    --connection-string "localhost:1521/ORCLCDB" \
    --username sys \
    --password Oracle_123 \
    --auth-mode SYSDBA \
    --sql "
        SELECT *
        FROM sys.table1
    " \
    --output-file "tmpdir/run1-output.csv" \
    --fetch-size 10000
