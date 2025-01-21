FROM nginx

# 基础配置文件
COPY docker /

# 定义网页目录
ENV WEBROOT /usr/share/nginx/html
WORKDIR ${WEBROOT}
VOLUME ${WEBROOT}
