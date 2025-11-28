FROM swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/nginx:1.29.2-alpine-slim


LABEL author="storezhang<华寅>" \
    email="storezhang@gmail.com" \
    qq="160290688" \
    wechat="storezhang" \
    description="Nginx基础镜像，提供基础配置"


# 复制文件
COPY docker /

# 定义网页目录
ENV WEBSITE /usr/share/nginx/html
VOLUME ${WEBSITE}

# 暴露端口
EXPOSE 80

# 定义镜像默认值
# 开放端口
ENV HTTP_PORT 80
# 服务名
ENV HOSTNAME localhost
# 主页
ENV INDEX index.html
# 静态文件缓存时间
ENV CACHE_STATIC_TIME 360000
