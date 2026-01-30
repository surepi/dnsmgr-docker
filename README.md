# dnsmgr Docker 镜像

基于 [彩虹聚合DNS管理系统](https://github.com/netcccyun/dnsmgr) 的 Docker 镜像，支持多架构部署。

## 镜像信息

- 镜像名称：`surepi9527/dnsmgr`
- 支持架构：`linux/amd64`, `linux/arm64`
- 基础镜像：Alpine 3.19
- PHP 版本：8.2
- Web 服务器：Nginx
- 数据库：MySQL 8.0

## 快速开始

### 拉取镜像

```bash
docker pull surepi9527/dnsmgr:latest
```

### Docker Compose 部署

创建 `docker-compose.yml` 文件：

```yaml
services:
  dnsmgr-web:
    container_name: dnsmgr-web
    stdin_open: true
    tty: true
    ports:
      - 8081:80
    volumes:
      - ./web:/app/www
    image: surepi9527/dnsmgr:latest
    depends_on:
      - dnsmgr-mysql
    networks:
      - dnsmgr-network

  dnsmgr-mysql:
    container_name: dnsmgr-mysql
    restart: always
    volumes:
      - ./mysql/conf/my.cnf:/etc/mysql/my.cnf
      - ./mysql/logs:/logs
      - ./mysql/data:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=123456
      - TZ=Asia/Shanghai
      - MYSQL_AUTHENTICATION_PLUGIN=mysql_native_password
    image: mysql:8.0
    networks:
      - dnsmgr-network

  phpmyadmin:
    container_name: phpmyadmin
    image: phpmyadmin:latest
    restart: always
    ports:
      - 8082:80
    environment:
      - PMA_HOST=dnsmgr-mysql
      - PMA_PORT=3306
      - MYSQL_ROOT_PASSWORD=123456
    depends_on:
      - dnsmgr-mysql
    networks:
      - dnsmgr-network

networks:
  dnsmgr-network:
    driver: bridge
```

### 启动服务

```bash
docker-compose up -d
```

### 访问应用

- dnsmgr 应用：`http://localhost:8081`
- phpMyAdmin 数据库管理：`http://localhost:8082`

默认管理员账号密码请查看 [dnsmgr 原项目文档](https://github.com/netcccyun/dnsmgr)。

## 目录结构

```
.
├── docker-compose.yml
├── web/                  # 应用文件（可选挂载）
└── mysql/
    ├── conf/my.cnf       # MySQL 配置
    ├── logs/             # MySQL 日志
    └── data/             # MySQL 数据
```

## 配置说明

### MySQL 配置

创建 MySQL 配置文件 `./mysql/conf/my.cnf`：

```ini
[mysqld]
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci
max_connections=200
default-storage-engine=INNODB
```

### 数据库连接

**应用内部配置：**
- 主机：`dnsmgr-mysql`
- 端口：`3306`
- 用户名：`root`
- 密码：`123456`（根据 docker-compose.yml 中的 MYSQL_ROOT_PASSWORD 修改）

**phpMyAdmin 登录：**
- 访问：`http://localhost:8082`
- 服务器：`dnsmgr-mysql`
- 用户名：`root`
- 密码：`123456`

## 维护命令

### 查看日志

```bash
# Web 服务日志
docker logs dnsmgr-web

# MySQL 日志
docker logs dnsmgr-mysql

# phpMyAdmin 日志
docker logs phpmyadmin
```

### 进入容器

```bash
# 进入 Web 容器
docker exec -it dnsmgr-web sh

# 进入 MySQL 容器
docker exec -it dnsmgr-mysql bash
```

### 备份数据库

```bash
docker exec dnsmgr-mysql mysqldump -uroot -p123456 --all-databases > backup.sql
```

### 恢复数据库

```bash
docker exec -i dnsmgr-mysql mysql -uroot -p123456 < backup.sql
```

### 停止服务

```bash
docker-compose down
```

### 更新镜像

```bash
docker pull surepi9527/dnsmgr:latest
docker-compose down
docker-compose up -d
```

## 定时任务

容器内置以下定时任务：
- 每 15 分钟执行一次 IP 解析任务

## 注意事项

1. **数据持久化**：首次启动前确保已创建必要的目录和配置文件
2. **端口冲突**：如果 8081 或 8082 端口被占用，请修改 docker-compose.yml 中的端口映射
3. **数据库密码**：生产环境请修改默认的 MySQL root 密码
4. **架构兼容**：镜像支持 x86_64 和 ARM64 架构，Docker 会自动选择对应版本
5. **phpMyAdmin 安全**：生产环境建议限制 phpMyAdmin 访问 IP 或使用 VPN

## 问题反馈

如有问题，请提交 Issue：
- 镜像问题：[Docker Hub](https://hub.docker.com/r/surepi9527/dnsmgr)
- 应用问题：[GitHub](https://github.com/netcccyun/dnsmgr)

## 许可证

本镜像基于原项目许可证发布，请遵守相关协议。
