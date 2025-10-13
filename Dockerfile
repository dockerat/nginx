FROM ccr.ccs.tencentyun.com/dockerat/alpine:3.20.1


LABEL author="storezhang<华寅>" \
    email="storezhang@gmail.com" \
    qq="160290688" \
    wechat="storezhang" \
    description="Nginx基础镜像"


# 复制文件
COPY docker /


RUN set -ex \
    \
    \
    \
    && apk update \
    && apk --no-cache upgrade \
    # 安装Nginx
    && apk add --no-cache nginx \
    \
    \
    \
    && rm -rf /var/cache/apk/*


# 执行命令
ENTRYPOINT [ "nginx", "-g", "daemon off;" ]
