#!/bin/bash
# 测试源码更新功能

echo "=== DNSMGR 源码更新测试 ==="

# 1. 构建Docker镜像
echo "1. 构建Docker镜像..."
docker build -t dnsmgr-test .

# 2. 启动测试容器
echo "2. 启动测试容器..."
docker run -d --name dnsmgr-test -p 8080:80 dnsmgr-test

# 3. 等待服务启动
echo "3. 等待服务启动..."
sleep 10

# 4. 测试服务是否正常
echo "4. 测试服务是否正常..."
curl -s http://localhost:8080 > /dev/null
if [ $? -eq 0 ]; then
    echo "✓ 服务启动成功"
else
    echo "✗ 服务启动失败"
    exit 1
fi

# 5. 手动执行更新脚本测试
echo "5. 手动测试更新脚本..."
docker exec dnsmgr-test /usr/local/bin/update-source.sh

# 6. 检查更新日志
echo "6. 检查更新日志..."
docker exec dnsmgr-test cat /var/log/update-source.log 2>/dev/null || echo "暂无更新日志"

# 7. 检查服务状态
echo "7. 检查服务状态..."
docker exec dnsmgr-test supervisorctl status

# 8. 测试定时任务
echo "8. 测试定时任务..."
docker exec dnsmgr-test crontab -l

# 9. 模拟定时任务执行
echo "9. 模拟定时任务执行..."
docker exec dnsmgr-test sh -c "cd /usr/src && /usr/local/bin/update-source.sh"

# 10. 清理测试环境
echo "10. 清理测试环境..."
docker stop dnsmgr-test
docker rm dnsmgr-test

echo "=== 测试完成 ==="
echo "测试步骤说明："
echo "1. 构建镜像 - 验证Dockerfile语法正确"
echo "2. 启动容器 - 验证服务能正常启动"
echo "3. 手动更新 - 测试更新脚本功能"
echo "4. 检查日志 - 验证更新过程记录"
echo "5. 服务状态 - 验证服务重启机制"