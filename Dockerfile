FROM nginx:1.27.5-alpine-slim


# 基础配置文件
COPY docker /


# 定义网页目录
ENV WEBROOT /usr/share/nginx/html
WORKDIR ${WEBROOT}
VOLUME ${WEBROOT}


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
