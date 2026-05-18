# Stream 配置说明

## 配置优先级

具体服务配置 > 全局默认配置

## 环境变量说明

### 服务配置（必需）

每个服务必须配置监听端口：

```bash
STREAM_<PREFIX>_PORT=<端口号>
```

### 节点配置

#### 方式1：为每个服务单独配置节点

```bash
STREAM_<PREFIX>_NODE_1=<节点地址>
STREAM_<PREFIX>_NODE_2=<节点地址>
STREAM_<PREFIX>_NODE_PORT=<统一节点端口>  # 可选，如果节点地址不包含端口
```

#### 方式2：使用全局默认节点（后备）

当服务未配置任何节点时，自动使用全局默认节点：

```bash
STREAM_NODE_1=<默认节点地址>
STREAM_NODE_2=<默认节点地址>
```

### 节点选项配置

#### 具体服务配置（优先）

```bash
STREAM_<PREFIX>_NODE_OPTIONS_MAX=<最大失败次数>
STREAM_<PREFIX>_NODE_OPTIONS_TIMEOUT=<失败超时时间>
```

#### 全局默认配置（后备）

```bash
STREAM_NODE_OPTIONS_MAX=<默认最大失败次数>
STREAM_NODE_OPTIONS_TIMEOUT=<默认失败超时时间>
```

### Server 额外配置

#### 具体服务配置（优先）

```bash
STREAM_<PREFIX>_CONFIG_<KEY>=<值>
```

#### 全局默认配置（后备）

```bash
STREAM_CONFIG_<KEY>=<值>
```

配置键会自动转换为小写，例如：
- `STREAM_CONFIG_PROXY_PROTOCOL=on` → `proxy_protocol on;`
- `STREAM_DB_CONFIG_PROXY_TIMEOUT=3s` → `proxy_timeout 3s;`

## 配置示例

### 示例1：使用全局默认配置

```bash
# 全局默认配置
STREAM_NODE_OPTIONS_MAX=3
STREAM_NODE_OPTIONS_TIMEOUT=30s
STREAM_CONFIG_PROXY_PROTOCOL=on

# 数据库服务（使用全局默认的节点选项和配置）
STREAM_DB_PORT=3306
STREAM_DB_NODE_1=db1.example.com
STREAM_DB_NODE_2=db2.example.com
STREAM_DB_NODE_PORT=3306

# Redis服务（使用全局默认的节点选项和配置）
STREAM_REDIS_PORT=6379
STREAM_REDIS_NODE_1=redis1.example.com
STREAM_REDIS_NODE_2=redis2.example.com
STREAM_REDIS_NODE_PORT=6379
```

### 示例2：覆盖全局默认配置

```bash
# 全局默认配置
STREAM_NODE_OPTIONS_MAX=3
STREAM_NODE_OPTIONS_TIMEOUT=30s
STREAM_CONFIG_PROXY_PROTOCOL=on

# 数据库服务（使用全局默认）
STREAM_DB_PORT=3306
STREAM_DB_NODE_1=db1.example.com
STREAM_DB_NODE_2=db2.example.com

# Redis服务（覆盖部分默认配置）
STREAM_REDIS_PORT=6379
STREAM_REDIS_NODE_1=redis1.example.com
STREAM_REDIS_NODE_2=redis2.example.com
STREAM_REDIS_NODE_OPTIONS_MAX=5              # 覆盖全局默认
STREAM_REDIS_CONFIG_PROXY_TIMEOUT=60s        # 添加额外配置
```

### 示例3：使用全局默认节点

```bash
# 全局默认节点（后备节点列表）
STREAM_NODE_1=backup1.example.com
STREAM_NODE_2=backup2.example.com
STREAM_NODE_OPTIONS_MAX=3
STREAM_NODE_OPTIONS_TIMEOUT=30s

# 数据库服务（有自己的节点）
STREAM_DB_PORT=3306
STREAM_DB_NODE_1=db1.example.com
STREAM_DB_NODE_2=db2.example.com

# 缓存服务（没有配置节点，使用全局默认节点）
STREAM_CACHE_PORT=11211
STREAM_CACHE_NODE_PORT=11211
```

在这个例子中：
- DB 服务使用自己配置的节点 `db1.example.com` 和 `db2.example.com`
- CACHE 服务没有配置节点，会自动使用全局默认节点 `backup1.example.com:11211` 和 `backup2.example.com:11211`

## 生成的配置示例

基于示例1的环境变量，会生成如下 nginx 配置：

```nginx
upstream auto_db_3306 {
    server db1.example.com:3306 max_fails=3 fail_timeout=30s;
    server db2.example.com:3306 max_fails=3 fail_timeout=30s;
}

server {
    listen 3306;
    proxy_pass auto_db_3306;
    proxy_protocol on;
}

upstream auto_redis_6379 {
    server redis1.example.com:6379 max_fails=3 fail_timeout=30s;
    server redis2.example.com:6379 max_fails=3 fail_timeout=30s;
}

server {
    listen 6379;
    proxy_pass auto_redis_6379;
    proxy_protocol on;
}
```

## 配置优势

1. **减少重复配置**：多个服务可以共享相同的节点选项和配置
2. **简化维护**：修改全局默认值即可影响所有未特殊配置的服务
3. **灵活覆盖**：需要特殊配置的服务可以单独覆盖默认值
4. **后备节点**：提供全局默认节点作为后备方案
