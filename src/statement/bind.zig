const zdt = @import("zdt");

const c = @cImport({
    @cInclude("dpi.h");
});

pub const BindValue = union(enum) {
    String: []u8,
    Int: i64,
    Double: f64,
    TimeStamp: zdt.Datetime,
    Number: f64,
    Boolean: bool,
    Null: u1,

    pub fn dpiNativeTypeNum(self: BindValue) c.dpiNativeTypeNum {
        return switch (self) {
            .String => c.DPI_NATIVE_TYPE_BYTES,
            .Int => c.DPI_NATIVE_TYPE_INT64,
            .Double => c.DPI_NATIVE_TYPE_DOUBLE,
            .TimeStamp => c.DPI_NATIVE_TYPE_TIMESTAMP,
            .Number => c.DPI_NATIVE_TYPE_FLOAT,
            .Boolean => c.DPI_NATIVE_TYPE_BOOLEAN,
            .Null => c.DPI_NATIVE_TYPE_NULL,
        };
    }
};
