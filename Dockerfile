FROM rust:1.54 AS rust
RUN apt-get update && apt-get -y install binutils-arm-linux-gnueabihf gcc-arm-linux-gnueabihf
RUN rustup target add armv7-unknown-linux-gnueabihf
ENV SQLX_OFFLINE=true
WORKDIR /app
COPY .cargo ./.cargo
COPY Cargo.toml Cargo.lock ./
COPY arrow-ctl ./arrow-ctl
COPY arrow-hal ./arrow-hal
RUN --mount=type=cache,target=/usr/local/cargo/registry \
	--mount=type=cache,target=/app/target \
cargo build --release --target armv7-unknown-linux-gnueabihf && \
cp target/armv7-unknown-linux-gnueabihf/release/arrow .
# Move the binary to a location free of the target since that is not available in the next stage.


FROM alpine:latest
ENV \
    # Show full backtraces for crashes.
    RUST_BACKTRACE=full
#RUN apk add --no-cache \
#      openssl \
#    && rm -rf /var/cache/* \
#    && mkdir /var/cache/apk
WORKDIR /app
COPY --from=rust /app/arrow ./
COPY entrypoint.sh ./entrypoint.sh
EXPOSE 80
ENTRYPOINT ["./entrypoint.sh"]
