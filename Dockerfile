FROM ppc64le/ubuntu:latest

ENV ELIXIR_VERSION 1.13.4
ENV OTP_VERSION 25.0.4

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    LC_CTYPE=en_US.UTF-8

COPY . /build_scripts

RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl locales \
    gcc g++ sudo
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
RUN bash /build_scripts/build-otp.sh "${OTP_VERSION}"
RUN bash /build_scripts/build-elixir.sh "v${ELIXIR_VERSION}" /elixir

ENV PATH="/elixir/bin:$PATH"
CMD ["/usr/local/bin/iex"]
