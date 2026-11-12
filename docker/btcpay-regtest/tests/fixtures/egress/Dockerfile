# Copia della ricetta del proxy di uscita Napay (napay/docker/egress) per il test di topologia B0.
FROM alpine:3.22.8@sha256:49340b346798875b5592e5d420241f2f9cfba5f47e62ebb1446a1b34734e898f
RUN apk add --no-cache squid=6.12-r0
COPY squid.conf /etc/squid/squid.conf
USER squid
CMD ["squid", "-N", "-f", "/etc/squid/squid.conf"]
