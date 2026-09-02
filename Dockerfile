# ========== 单阶段：直接下载预构建前端 Zashboard + mihomo 二进制 ==========
FROM caddy:alpine

ARG MI_VERSION
ARG ZASHBOARD_VERSION
ARG TARGETARCH

ENV MI_VERSION=${MI_VERSION}
ENV ZASHBOARD_VERSION=${ZASHBOARD_VERSION}
ENV LOG_LEVEL="info"
ENV CLASH_SECRET=""
ENV SUBSCRIBE_NAME="default"
ENV SUBSCRIBE_URL=""

RUN apk update && apk add --no-cache libcap curl bash gettext coreutils tzdata unzip \
 && rm -rf /var/cache/apk/*

# ----- 下载辅助函数：curl 重试 + gh-proxy 回退 -----
# GitHub Release assets 在某些网络环境会超时/403，通过以下组合提高成功率：
#   1) curl --retry 5 + 指数退避（官方源直接下）
#   2) 官方源失败时回退到 gh-proxy.com 代理
#   3) 下载后再用 Content-Length / 实际大小粗校验

# ----- 下载 mihomo 二进制 -----
RUN set -eux; \
    mkdir -p /root/.config/mihomo; \
    case "${TARGETARCH}" in \
      amd64) MI_ASSET="mihomo-linux-amd64-compatible-${MI_VERSION}.gz" ;; \
      arm64) MI_ASSET="mihomo-linux-arm64-${MI_VERSION}.gz" ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    MI_DL_URL="https://github.com/MetaCubeX/mihomo/releases/download/${MI_VERSION}/${MI_ASSET}"; \
    # 第一次尝试：官方源 + 重试 5 次
    if ! curl -fsSL --retry 5 --retry-delay 2 --retry-all-errors \
         --connect-timeout 15 --max-time 120 \
         -o /tmp/mihomo.gz "${MI_DL_URL}"; then \
      echo "⚠️ 官方源下载 mihomo 失败，尝试 gh-proxy 代理..."; \
      curl -fsSL --retry 3 --retry-delay 2 --retry-all-errors \
           --connect-timeout 15 --max-time 180 \
           -o /tmp/mihomo.gz "https://gh-proxy.com/${MI_DL_URL}"; \
    fi; \
    # 基本大小校验：mihomo gz 一般 >= 5MB
    MI_SIZE=$(stat -c%s /tmp/mihomo.gz 2>/dev/null || stat -f%z /tmp/mihomo.gz 2>/dev/null || echo 0); \
    if [ "$MI_SIZE" -lt 1048576 ]; then \
      echo "❌ mihomo 下载异常，只有 ${MI_SIZE} bytes（<1MB）"; exit 1; \
    fi; \
    gunzip /tmp/mihomo.gz; \
    mv /tmp/mihomo /usr/local/bin/mihomo; \
    chmod +x /usr/local/bin/mihomo; \
    setcap 'cap_net_bind_service=+ep' /usr/local/bin/mihomo

# ----- 下载 Zashboard 预构建包（替代 Metacubexd 的源码构建）-----
# 打包结构确认（来自 zashboard/.github/workflows/deploy.yml release-dist job）：
#   pnpm run build → 输出到 ./dist/
#   zip -r dist.zip dist  → 所以 zip 内顶层就是 dist/ 目录
#   解压后 cp -r dist/* /srv  → /srv/index.html ✅
RUN set -eux; \
    mkdir -p /srv; \
    if [ -n "${ZASHBOARD_VERSION}" ] && [ "${ZASHBOARD_VERSION}" != "latest" ]; then \
      ZASH_DL_URL="https://github.com/Zephyruso/zashboard/releases/download/${ZASHBOARD_VERSION}/dist.zip"; \
    else \
      ZASH_DL_URL="https://github.com/Zephyruso/zashboard/releases/latest/download/dist.zip"; \
    fi; \
    echo "下载 Zashboard: ${ZASH_DL_URL}"; \
    # 第一次尝试：官方源 + 重试
    if ! curl -fsSL --retry 5 --retry-delay 2 --retry-all-errors \
         --connect-timeout 15 --max-time 180 \
         -o /tmp/zashboard.zip "${ZASH_DL_URL}"; then \
      echo "⚠️ 官方源下载 zashboard 失败，尝试 gh-proxy 代理..."; \
      curl -fsSL --retry 3 --retry-delay 2 --retry-all-errors \
           --connect-timeout 15 --max-time 240 \
           -o /tmp/zashboard.zip "https://gh-proxy.com/${ZASH_DL_URL}"; \
    fi; \
    # 基本大小校验：完整版 dist.zip 约 7.8MB，无字体版约 1.44MB
    ZASH_SIZE=$(stat -c%s /tmp/zashboard.zip 2>/dev/null || stat -f%z /tmp/zashboard.zip 2>/dev/null || echo 0); \
    if [ "$ZASH_SIZE" -lt 524288 ]; then \
      echo "❌ zashboard.zip 下载异常，只有 ${ZASH_SIZE} bytes（<512KB）"; exit 1; \
    fi; \
    echo "✅ zashboard.zip 大小: ${ZASH_SIZE} bytes"; \
    unzip -q /tmp/zashboard.zip -d /tmp/zashboard-temp; \
    # 🔴 解压结构校验：zip -r dist.zip dist → 应该存在 dist/index.html
    if [ ! -f /tmp/zashboard-temp/dist/index.html ]; then \
      echo "❌ 解压后未找到 dist/index.html，zip 结构与预期不符。目录内容："; \
      ls -la /tmp/zashboard-temp/; \
      [ -d /tmp/zashboard-temp/dist ] && ls -la /tmp/zashboard-temp/dist/ || true; \
      exit 1; \
    fi; \
    # 拷贝到 Caddy 静态目录
    cp -r /tmp/zashboard-temp/dist/* /srv/; \
    # 最终校验：/srv/index.html 必须存在
    if [ ! -f /srv/index.html ]; then \
      echo "❌ /srv/index.html 不存在，前端拷贝失败"; exit 1; \
    fi; \
    echo "✅ Zashboard 部署完成，/srv 条目数: $(ls -1 /srv | wc -l)"; \
    rm -rf /tmp/zashboard.zip /tmp/zashboard-temp;

# ----- 拷贝配置模板和启动脚本 -----
COPY config.yaml.template /app/config.yaml.template
COPY docker-entrypoint.sh /app/docker-entrypoint.sh
COPY Caddyfile /srv/Caddyfile
RUN chmod +x /app/docker-entrypoint.sh

EXPOSE 7890 7891 7892 7893 7894 8080 9090
ENTRYPOINT ["/app/docker-entrypoint.sh"]
