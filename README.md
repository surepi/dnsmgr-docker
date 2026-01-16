# 彩虹聚合DNS管理系统 Docker 镜像

[彩虹聚合DNS管理系统](https://github.com/netcccyun/dnsmgr) 的 Docker 镜像构建脚本

## 构建镜像

```bash
docker build -t netcccyun/dnsmgr:latest .
```

## 运行容器

```bash
docker run -d \
  --name dnsmgr \
  -p 80:80 \
  netcccyun/dnsmgr:latest
```

## 主要优化

### 🚀 性能优化

- **多阶段构建**：分离构建和运行环境，减小镜像体积
- **OPcache 优化**：启用并优化 PHP OPcache 配置，提升执行效率
- **Gzip 压缩**：优化 Nginx Gzip 配置，减少传输数据量
- **进程池优化**：PHP-FPM 使用动态进程管理，提升响应速度
- **Composer 优化**：使用 `--optimize-autoloader` 优化自动加载

### 🔒 安全增强

- **安全响应头**：添加 X-Frame-Options、X-Content-Type-Options、X-XSS-Protection 等安全头
- **危险函数禁用**：禁用 exec、shell_exec、system 等危险 PHP 函数
- **文件访问限制**：禁止访问敏感文件和目录（.env、vendor、runtime 等）
- **Session 安全**：启用 httponly、strict_mode 等 Session 安全配置
- **错误处理**：生产环境关闭错误显示，启用错误日志

### 🛠️ 配置优化

- **Nginx 配置**
  - 优化 Gzip 压缩级别和类型
  - 添加安全响应头
  - 限制敏感文件访问
  - 优化缓存策略

- **PHP 配置**
  - 内存限制：256M
  - 执行超时：300秒
  - 上传限制：50M
  - 时区：PRC（中国时区）
  - 启用 OPcache 并优化参数

- **PHP-FPM 配置**
  - 进程管理：dynamic 模式
  - 最大子进程：50
  - 启动进程：5
  - 最小空闲进程：5
  - 最大空闲进程：20
  - 启用访问日志和慢查询日志

- **Supervisor 配置**
  - 所有服务启用自动重启
  - 优化启动顺序和超时设置
  - 统一日志输出到 stdout/stderr

### 📝 可维护性提升

- **入口脚本优化**：添加日志记录和错误处理
- **健康检查**：改进健康检查配置，增加启动等待时间
- **日志管理**：统一日志输出，便于 Docker 日志收集
- **权限管理**：优化文件权限设置，确保安全性

### 📦 构建优化

- **.dockerignore**：排除不必要的文件，减少构建上下文
- **缓存优化**：清理构建过程中的临时文件和缓存
- **层优化**：合并 RUN 命令，减少镜像层数

## 技术栈

- **基础镜像**：Alpine Linux 3.19
- **Web 服务器**：Nginx
- **PHP 版本**：PHP 8.2
- **进程管理**：Supervisor
- **定时任务**：dcron

## 服务说明

容器内运行以下服务：

1. **Nginx**：Web 服务器，监听 80 端口
2. **PHP-FPM**：PHP 进程管理器
3. **dmtask**：后台任务服务（`php think dmtask`）
4. **Cron**：定时任务，每 15 分钟执行一次 `think opiptask`

## 健康检查

容器包含健康检查机制，通过 `/fpm-ping` 端点检查服务状态：

- 检查间隔：30秒
- 超时时间：10秒
- 启动等待：40秒
- 重试次数：3次

## 目录结构

```
/app/www/          # 应用根目录
/usr/src/www/      # 应用源码目录（构建时使用）
/etc/nginx/        # Nginx 配置目录
/etc/php82/        # PHP 配置目录
/etc/supervisor/   # Supervisor 配置目录
```

## 注意事项

1. 首次启动时，应用文件会从 `/usr/src/www` 复制到 `/app/www`
2. 确保 `/app/www/runtime` 目录有写权限
3. 生产环境建议使用环境变量配置数据库连接等信息
4. 建议使用 Docker Compose 或 Kubernetes 进行编排管理

## 许可证

请参考原项目 [dnsmgr](https://github.com/netcccyun/dnsmgr) 的许可证
