FROM rust:latest as builder
WORKDIR /usr/src/rusty-nail
COPY rusty-nail .
RUN cargo install --path .

FROM debian:buster-slim
COPY --from=builder /usr/local/cargo/bin/rusty-nail /usr/local/bin/rusty-nail
# Need to provide command with args to execute -- ex:
# rusty-nail some_image.png some_thumbnail.png 150 150 true
# The following command will fail and trigger the built-in usage statement
CMD ["rusty-nail"]
# Executing the docker image with arguments will override CMD
