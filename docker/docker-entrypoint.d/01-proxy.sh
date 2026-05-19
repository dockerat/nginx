#!/bin/sh

OUTPUT_CONF="/etc/nginx/proxy.d/auto.conf"
log info 开始生成配置文件 "output=${OUTPUT_CONF}"

if [ -f "${OUTPUT_CONF}" ]; then
    log warn 清理旧配置文件 "filename=${OUTPUT_CONF}"
    rm -f "$OUTPUT_CONF"
else
    log info 无旧配置文件，继续执行 "filename=${OUTPUT_CONF}"
fi

# 辅助函数：判断布尔值（支持 true/false/on/off）
is_enabled() {
    case "$1" in
        true|TRUE|on|ON|1)
            return 0
            ;;
        false|FALSE|off|OFF|0)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

# 通过扫描所有以PROXY_开头且以_PORT结尾的变量，自动抓取所有的服务前缀
# 排除 PROXY_*_NODE_PORT 和 PROXY_NODE_* 等非服务配置
PREFIXES=$(env | grep '^PROXY_.*_PORT=' | grep -v '_NODE_PORT=' | grep -v '^PROXY_NODE_' | grep -v '^PROXY_CONFIG_' | cut -d'=' -f1 | sed 's/^PROXY_//' | sed 's/_PORT$//' | sort -u)

if [ -z "${PREFIXES}" ]; then
    log info 没有找到PROXY_配置，跳过
    exit 0
fi

# 遍历每一个识别到的服务前缀
for PREFIX in ${PREFIXES}; do
    # 动态获取该前缀下的端口和名字
    eval "LISTEN_PORT=\$PROXY_${PREFIX}_PORT"
    eval "CUSTOM_NAME=\$PROXY_${PREFIX}_NAME"

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

    # 获取统一的节点端口（如果存在）
    eval "UNIFIED_NODE_PORT=\$PROXY_${PREFIX}_NODE_PORT"

    # 检查是否启用 NODE_OPTIONS 扩展（默认启用）
    eval "NODE_OPTIONS_EXTENDS=\$PROXY_${PREFIX}_NODE_OPTIONS_EXTENDS"
    if [ -z "$NODE_OPTIONS_EXTENDS" ]; then
        NODE_OPTIONS_EXTENDS="true"
    fi

    # 获取选项配置（优先使用具体配置，如果启用扩展则回退到全局默认）
    eval "NODE_MAX_FAILS=\$PROXY_${PREFIX}_NODE_OPTIONS_MAX"
    if [ -z "$NODE_MAX_FAILS" ] && is_enabled "$NODE_OPTIONS_EXTENDS"; then
        NODE_MAX_FAILS="$PROXY_NODE_OPTIONS_MAX"
    fi

    eval "NODE_FAIL_TIMEOUT=\$PROXY_${PREFIX}_NODE_OPTIONS_TIMEOUT"
    if [ -z "$NODE_FAIL_TIMEOUT" ] && is_enabled "$NODE_OPTIONS_EXTENDS"; then
        NODE_FAIL_TIMEOUT="$PROXY_NODE_OPTIONS_TIMEOUT"
    fi

    # 构建选项字符串
    NODE_OPTIONS=""
    if [ ! -z "$NODE_MAX_FAILS" ]; then
        NODE_OPTIONS="${NODE_OPTIONS} max_fails=${NODE_MAX_FAILS}"
        log info 配置选项 "prefix=${PREFIX}, max_fails=${NODE_MAX_FAILS}"
    fi
    if [ ! -z "$NODE_FAIL_TIMEOUT" ]; then
        NODE_OPTIONS="${NODE_OPTIONS} fail_timeout=${NODE_FAIL_TIMEOUT}"
        log info 配置选项 "prefix=${PREFIX}, fail_timeout=${NODE_FAIL_TIMEOUT}"
    fi

    # 获取所有属于当前服务前缀的变量名
    NODE_VARS=$(env | grep "^PROXY_${PREFIX}_NODE" | grep -v "^PROXY_${PREFIX}_NODE_PORT=" | grep -v "^PROXY_${PREFIX}_NODE_OPTIONS_" | grep -v "^PROXY_${PREFIX}_NODE_OPTIONS_EXTENDS=" | cut -d'=' -f1)

    for node_var in $NODE_VARS; do
        eval "VAL=\$${node_var}"
        if [ ! -z "$VAL" ]; then
            # 检查节点值是否已包含端口（是否有冒号）
            case "$VAL" in
                *:*)
                    # 已包含端口，直接使用
                    echo "    server $VAL${NODE_OPTIONS};" >> $TEMP_UPSTREAM_BODY
                    ;;
                *)
                    # 未包含端口，使用统一端口
                    if [ ! -z "$UNIFIED_NODE_PORT" ]; then
                        echo "    server ${VAL}:${UNIFIED_NODE_PORT}${NODE_OPTIONS};" >> $TEMP_UPSTREAM_BODY
                    else
                        log warn 节点未指定端口且无统一端口 "node=${node_var}, value=${VAL}"
                        echo "    server $VAL${NODE_OPTIONS};" >> $TEMP_UPSTREAM_BODY
                    fi
                    ;;
            esac
            NODE_COUNT=$((NODE_COUNT + 1))
        fi
    done

    # 如果当前服务没有配置任何节点，尝试使用全局默认节点
    if [ $NODE_COUNT -eq 0 ]; then
        log info 当前服务未配置节点，尝试使用全局默认节点 "prefix=${PREFIX}"
        GLOBAL_NODE_VARS=$(env | grep "^PROXY_NODE_" | grep -v "^PROXY_NODE_PORT=" | grep -v "^PROXY_NODE_OPTIONS_" | cut -d'=' -f1)

        for global_node_var in $GLOBAL_NODE_VARS; do
            eval "GLOBAL_VAL=\$${global_node_var}"
            if [ ! -z "$GLOBAL_VAL" ]; then
                # 检查节点值是否已包含端口
                case "$GLOBAL_VAL" in
                    *:*)
                        # 已包含端口，直接使用
                        echo "    server $GLOBAL_VAL${NODE_OPTIONS};" >> $TEMP_UPSTREAM_BODY
                        ;;
                    *)
                        # 未包含端口，使用统一端口
                        if [ ! -z "$UNIFIED_NODE_PORT" ]; then
                            echo "    server ${GLOBAL_VAL}:${UNIFIED_NODE_PORT}${NODE_OPTIONS};" >> $TEMP_UPSTREAM_BODY
                        else
                            log warn 全局默认节点未指定端口且无统一端口 "node=${global_node_var}, value=${GLOBAL_VAL}"
                            echo "    server $GLOBAL_VAL${NODE_OPTIONS};" >> $TEMP_UPSTREAM_BODY
                        fi
                        ;;
                esac
                NODE_COUNT=$((NODE_COUNT + 1))
            fi
        done

        if [ $NODE_COUNT -gt 0 ]; then
            log info 使用全局默认节点 "prefix=${PREFIX}, count=${NODE_COUNT}"
        fi
    fi

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

    location / {
        proxy_pass http://${UPSTREAM_NAME};
EOF

        # 扫描并处理额外的配置项
        # 检查是否启用 CONFIG 扩展（默认启用）
        eval "CONFIG_EXTENDS=\$PROXY_${PREFIX}_CONFIG_EXTENDS"
        if [ -z "$CONFIG_EXTENDS" ]; then
            CONFIG_EXTENDS="true"
        fi

        # 先收集具体服务的配置
        CONFIG_VARS=$(env | grep "^PROXY_${PREFIX}_CONFIG_" | grep -v "^PROXY_${PREFIX}_CONFIG_EXTENDS=" | cut -d'=' -f1)
        APPLIED_CONFIGS=""

        for config_var in $CONFIG_VARS; do
            eval "CONFIG_VAL=\$${config_var}"
            if [ ! -z "$CONFIG_VAL" ]; then
                # 提取配置键名：PROXY_API_CONFIG_PROXY_SET_HEADER -> PROXY_SET_HEADER
                CONFIG_KEY=$(echo "$config_var" | sed "s/^PROXY_${PREFIX}_CONFIG_//")
                # 转换为小写并替换下划线
                CONFIG_KEY_LOWER=$(echo "$CONFIG_KEY" | tr 'A-Z' 'a-z')
                echo "        ${CONFIG_KEY_LOWER} ${CONFIG_VAL};" >> ${OUTPUT_CONF}
                log info 添加具体配置 "prefix=${PREFIX}, key=${CONFIG_KEY_LOWER}, value=${CONFIG_VAL}"
                # 记录已应用的配置键
                APPLIED_CONFIGS="${APPLIED_CONFIGS} ${CONFIG_KEY}"
            fi
        done

        # 再应用全局默认配置（仅当具体服务未配置且启用扩展时）
        if is_enabled "$CONFIG_EXTENDS"; then
            GLOBAL_CONFIG_VARS=$(env | grep "^PROXY_CONFIG_" | cut -d'=' -f1)
            for global_config_var in $GLOBAL_CONFIG_VARS; do
                eval "GLOBAL_CONFIG_VAL=\$${global_config_var}"
                if [ ! -z "$GLOBAL_CONFIG_VAL" ]; then
                    # 提取配置键名：PROXY_CONFIG_PROXY_SET_HEADER -> PROXY_SET_HEADER
                    GLOBAL_CONFIG_KEY=$(echo "$global_config_var" | sed "s/^PROXY_CONFIG_//")

                    # 检查该配置是否已被具体服务配置覆盖
                    case "$APPLIED_CONFIGS" in
                        *" ${GLOBAL_CONFIG_KEY} "* | *" ${GLOBAL_CONFIG_KEY}" | "${GLOBAL_CONFIG_KEY} "*)
                            log info 跳过全局默认配置 "prefix=${PREFIX}, key=${GLOBAL_CONFIG_KEY}, reason=已有具体配置"
                            ;;
                        *)
                            # 转换为小写并替换下划线
                            GLOBAL_CONFIG_KEY_LOWER=$(echo "$GLOBAL_CONFIG_KEY" | tr 'A-Z' 'a-z')
                            echo "        ${GLOBAL_CONFIG_KEY_LOWER} ${GLOBAL_CONFIG_VAL};" >> ${OUTPUT_CONF}
                            log info 添加全局默认配置 "prefix=${PREFIX}, key=${GLOBAL_CONFIG_KEY_LOWER}, value=${GLOBAL_CONFIG_VAL}"
                            ;;
                    esac
                fi
            done
        else
            log info 已禁用全局配置扩展 "prefix=${PREFIX}"
        fi

        cat << EOF >> ${OUTPUT_CONF}
    }
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
