FROM alpine:3

RUN apk add --no-cache \
    gcompat \
    gmp \
    zlib

COPY .stack-work/dist/x86_64-linux/ghc-9.8.4/build/map-service-exe \
     /usr/local/bin/

EXPOSE 3000
CMD ["map-service-exe"]