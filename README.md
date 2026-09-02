<h3><div align="center">mihomo 镜像 (Zashboard 版)</div></h3>

---

<div align="center">
  <img src="https://img.shields.io/github/last-commit/maple-zh/mihomo" alt="最后提交">
  <img src="https://img.shields.io/github/actions/workflow/status/maple-zh/mihomo/docker-build.yml" alt="构建状态">
  <a href="https://github.com/maple-zh/mihomo/blob/main/License">
    <img src="https://img.shields.io/badge/License-MIT-yellow?style=flat-square" alt="MIT许可证">
  </a>
  <a href="https://github.com/maple-zh/mihomo/pkgs/container/mihomo">
    <img src="https://img.shields.io/badge/GHCR.io-Package-blue?logo=github" alt="GHCR Package">
  </a>
</div>

mihomo 是一个基于 Clash 核心的代理工具镜像，集成了 **Zashboard** 管理面板（替代原有的 Metacubexd），提供强大的代理功能和直观的 Web 管理界面。

## 构建信息

- mihomo 核心版本: `{{MI_VERSION}}`
- Zashboard 面板版本: `{{ZASHBOARD_VERSION}}`

## 面板差异

| 特性 | Metacubexd (原) | Zashboard (新) |
| --- | --- | --- |
| 框架 | Nuxt 3 | Vue 3 + Vite |
| UI 风格 | Material 风格 | Glassmorphism 玻璃态 |
| 构建体积 | 较大 | ~7.8MB (完整版) / ~1.44MB (无字体版) |
| PWA 支持 | ✅ | ✅ |
| 全球流量地球仪 | ❌ | ✅ |
| 连接表格拖拽 | ❌ | ✅ |
| 右键节点测速 | ❌ | ✅ (卡片右键) |
| 多字体构建变体 | ❌ | ✅ 7 种 |

## 拉取镜像

```bash
# GitHub Container Registry（推荐）
docker pull ghcr.io/maple-zh/mihomo:latest

# 启动容器
docker run -d --name mihomo -p 7890:7890 -p 8080:8080 ghcr.io/maple-zh/mihomo:latest
```

启动后，Zashboard Web UI 地址为：**http://<服务器IP>:8080**

## docker-compose.yml 配置文件

```yaml
version: '3.8'
services:
  mihomo:
    container_name: mihomo
    image: ghcr.io/maple-zh/mihomo:latest
    restart: always
    environment:
      # 核心配置
      - TZ=Asia/Shanghai
      - LOG_LEVEL=silent
      - CLASH_SECRET=your_secret_here
      - SUBSCRIBE_URL=your_subscribe_url
      - SUBSCRIBE_NAME=your_subscribe_name
    ports:
      - "7890:7890"  # HTTP代理
      - "7891:7891"  # SOCKS5代理
      - "7892:7892"  # 混合代理
      - "7893:7893"  # TPROXY
      - "7894:7894"  # REDIR
      - "9090:9090"  # Clash控制API
      - "8080:8080"  # Zashboard Web UI
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9090"]
      interval: 30s
      timeout: 10s
      retries: 3
    volumes:
      - ./clash-config:/root/.config/mihomo  # Clash配置文件目录
      - ./zashboard-config:/config/caddy     # Zashboard/Caddy配置目录
      # - /etc/timezone:/etc/timezone:ro       # 共享主机时区
      # - /etc/localtime:/etc/localtime:ro
    # 如需启用TUN模式，取消以下注释
    # cap_add:
    #   - NET_ADMIN
    # devices:
    #   - /dev/net/tun:/dev/net/tun
    networks:
      - clash-net
networks:
  clash-net:
    driver: bridge
```

## 环境变量说明

| 变量名 | 默认值 | 说明 |
| --- | --- | --- |
| `TZ` | UTC | 时区，建议设置 `Asia/Shanghai` |
| `LOG_LEVEL` | info | mihomo 日志级别：silent/error/warning/info/debug |
| `CLASH_SECRET` | （空） | External Controller 密钥，用于面板 API 鉴权 |
| `SUBSCRIBE_URL` | （空） | 订阅链接 |
| `SUBSCRIBE_NAME` | default | 订阅名称（作为 proxy-provider 的标识） |

## Zashboard 快速连接

打开 `http://<服务器IP>:8080` 后，在初始设置页填写：

- **主机地址**: `<服务器IP>` 或 `localhost`
- **端口**: `9090`
- **密钥**: 与 `CLASH_SECRET` 一致

也可以通过 URL 参数直接预设连接，免去手动配置：

```
http://<服务器IP>:8080/#/setup?hostname=<服务器IP>&port=9090&secret=<CLASH_SECRET>
```

## 项目源码

- **本仓库**: https://github.com/maple-zh/mihomo
- **mihomo 内核**: [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo)
- **Zashboard 面板**: [Zephyruso/zashboard](https://github.com/Zephyruso/zashboard)

## 协议

[MIT](https://github.com/maple-zh/mihomo/blob/main/License)
