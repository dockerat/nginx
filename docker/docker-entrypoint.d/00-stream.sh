#!/bin/sh

CODE=0
EXIT=false
OUTPUT_CONF="/etc/nginx/stream.d/auto.conf"
log info 开始生成配置文件 "output=${OUTPUT_CONF}"

# 通过扫描所有以端口结尾的变量，自动抓取所有的服务前缀
PREFIXES=$(env | grep '_PORT=' | cut -d'=' -f1 | sed 's/_PORT$//' | sort -u)

if [ -z "${PREFIXES}" ]; then
    log error 没有找到代理端口
    echo "}" >> ${OUTPUT_CONF}

    CODE=0
    EXIT=true
fi
if [ "${EXIT}" = "true" ]; then
    exit ${CODE}
fi

# 遍历每一个识别到的服务前缀
for PREFIX in ${PREFIXES}; do
    # 动态获取该前缀下的端口和名字
    eval "LISTEN_PORT=\$${PREFIX}_PORT"
    eval "CUSTOM_NAME=\$${PREFIX}_NAME"

    if [ -z "${LISTEN_PORT}" ]; then
        continue
    fi

    # 4智能化命名与缺省逻辑
    if [ ! -z "${CUSTOM_NAME}" ]; then
        UPSTREAM_NAME="${CUSTOM_NAME}"
        log info 使用自定义名字 "prefix=${PREFIX}, name=${UPSTREAM_NAME}}"
    else
        # 如果没有指定名字，提取前缀的后半部分并加上端口生成唯一名
        LOWER_SUF=$(echo "$PREFIX" | cut -d'_' -f2- | tr 'A-Z' 'a-z')
        UPSTREAM_NAME="auto_${LOWER_SUF}_${LISTEN_PORT}"
        log info 生成名字 "prefix=${PREFIX}, name=${UPSTREAM_NAME}"
    fi

    # 扫描当前前缀下的所有节点
    TEMP_UPSTREAM_BODY=$(mktemp)
    NODE_COUNT=0

    # 获取所有属于当前服务前缀的变量名
    NODE_VARS=$(env | grep "^${PREFIX}_NODE" | cut -d'=' -f1)

    for node_var in $NODE_VARS; do
        eval "VAL=\$${node_var}"
        if [ ! -z "$VAL" ]; then
            echo "        server $VAL;" >> $TEMP_UPSTREAM_BODY
            NODE_COUNT=$((NODE_COUNT + 1))
        fi
    done

    # 如果有节点，才真正写入最终的配置文件
    if [ $NODE_COUNT -gt 0 ]; then
        cat << EOF >> ${OUTPUT_CONF}
    upstream ${UPSTREAM_NAME} {
EOF
        cat $TEMP_UPSTREAM_BODY >> ${OUTPUT_CONF}
        cat << EOF >> ${OUTPUT_CONF}
    }

    server {
        listen ${LISTEN_PORT};
        proxy_pass ${UPSTREAM_NAME};

        # 生产调优参数
        proxy_timeout 10m;
        proxy_connect_timeout 5s;
    }

EOF
        log info 成功生成配置 "port=$LISTEN_PORT, name=$UPSTREAM_NAME, count=$NODE_COUNT"
    else
        log warn 未能生成配置 "prefix=$PREFIX"
    fi

    # 清理临时文件
    rm -f $TEMP_UPSTREAM_BODY
done

log info 配置文件已生成 "output=$OUTPUT_CONF"
