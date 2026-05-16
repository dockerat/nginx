ARG TARGETPLATFORM
ARG BUILDPLATFORM

FROM --platform=$TARGETPLATFORM docker.1ms.run/library/nginx:1.29.2-alpine-slim AS builder

ARG VERSION=1
COPY docker /docker
RUN wget --quiet --output-document=/docker/usr/bin/log https://gitee.com/storezhang/script/raw/main/core/log.sh
RUN chmod +x /docker/usr/bin/log
RUN chmod +x /docker/docker-entrypoint.d/*


FROM --platform=$TARGETPLATFORM docker.1ms.run/library/nginx:1.29.2-alpine-slim

LABEL author="storezhang<华寅>" \
    email="storezhang@gmail.com" \
    qq="160290688" \
    wechat="storezhang" \
    description="Nginx基础镜像，提供基础配置"

# 复制文件
COPY --from=builder /docker /

# 暴露端口
EXPOSE 80

# 定义镜像默认值
ENV WEBSITE=/usr/share/nginx/html \
    HTTP_PORT=80 \
    HOSTNAME=localhost \
    INDEX=index.html \
    CACHE_STATIC_TIME=360000

# 定义网页目录
VOLUME ${WEBSITE}
