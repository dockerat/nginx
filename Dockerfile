FROM nginx:1.29.2-alpine-slim


LABEL author="storezhang<华寅>" \
    email="storezhang@gmail.com" \
    qq="160290688" \
    wechat="storezhang" \
    description="Nginx基础镜像，提供基础配置"


# 复制文件
COPY docker /
