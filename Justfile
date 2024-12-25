set dotenv-load := true
set dotenv-path := ".env"


instantclient-download-url := "https://download.oracle.com/otn_software/linux/instantclient/2116000/instantclient-basic-linux.x64-21.16.0.0.0dbru.zip"

download-lib-instantclient:
    curl -L -o lib/instantclient.zip {{instantclient-download-url}}

unzip-lib-instantclient:
    unzip lib/instantclient.zip -d lib

rm-lib-instantclient-zip:
    rm -rf lib/instantclient.zip
    rm -rf lib/META-INF

rm-lib-instantclient: rm-lib-instantclient-zip
    rm -rf lib/instantclient_*

setup-lib-instantclient: download-lib-instantclient unzip-lib-instantclient rm-lib-instantclient-zip

clone-lib-odpi:
    git clone https://github.com/oracle/odpi.git lib/odpi

rm-lib-odpi:
    rm -rf lib/odpi

setup-libs: setup-lib-instantclient clone-lib-odpi

zig-build:
    zig build

zig-build-test:
    zig build test

zig-build-run:
    zig build run
