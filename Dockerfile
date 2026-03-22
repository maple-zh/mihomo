# ========== 第一阶段：构建 Metacubexd 前端 ==========
FROM node:20-alpine AS frontend-builder

ARG METACUBEXD_VERSION

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
ENV HUSKY="0"
ENV NODE_OPTIONS="--max_old_space_size=4096"

WORKDIR /build

# 安装系统依赖和 pnpm
RUN apk update && apk add --no-cache git curl python3 make g++ \
 && npm install -g pnpm@latest \
 && corepack enable && corepack prepare pnpm@latest --activate

# 克隆指定版本的 Metacubexd 源码
RUN echo "正在克隆 MetaCubeX/metacubexd 版本: ${METACUBEXD_VERSION}" \
 && git clone -b ${METACUBEXD_VERSION} --depth 1 https://github.com/MetaCubeX/metacubexd.git . \
 || (echo "克隆失败，尝试使用 main 分支..." && git clone --depth 1 https://github.com/MetaCubeX/metacubexd.git .)

# 安装依赖并构建静态资源
RUN echo "安装依赖..." \
 && pnpm install --frozen-lockfile --ignore-scripts \
 && echo "构建静态资源..." \
 && pnpm generate \
 && echo "构建完成。"

# ========== 第二阶段：运行时镜像 ==========
FROM caddy:alpine

ARG MI_VERSION
ARG METACUBEXD_VERSION
ARG TARGETARCH

ENV MI_VERSION=${MI_VERSION}
ENV METACUBEXD_VERSION=${METACUBEXD_VERSION}
ENV LOG_LEVEL="info"
ENV CLASH_SECRET=""
ENV SUBSCRIBE_NAME="default"
ENV SUBSCRIBE_URL=""

RUN apk update && apk add --no-cache libcap curl bash gettext coreutils tzdata \
 && rm -rf /var/cache/apk/*

# 根据目标架构下载对应的 mihomo 二进制
RUN set -eux; \
    mkdir -p /root/.config/mihomo; \
    case "${TARGETARCH}" in \
      amd64) MI_ASSET="mihomo-linux-amd64-compatible-${MI_VERSION}.gz" ;; \
      arm64) MI_ASSET="mihomo-linux-arm64-${MI_VERSION}.gz" ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fL "https://github.com/MetaCubeX/mihomo/releases/download/${MI_VERSION}/${MI_ASSET}" -o /tmp/mihomo.gz; \
    gunzip /tmp/mihomo.gz; \
    mv /tmp/mihomo /usr/local/bin/mihomo; \
    chmod +x /usr/local/bin/mihomo; \
    setcap 'cap_net_bind_service=+ep' /usr/local/bin/mihomo

# 拷贝构建好的前端静态资源
COPY --from=frontend-builder /build/.output/public /srv

# 拷贝配置模板和启动脚本
COPY config.yaml.template /app/config.yaml.template
COPY docker-entrypoint.sh /app/docker-entrypoint.sh
COPY Caddyfile /srv/Caddyfile

RUN chmod +x /app/docker-entrypoint.sh

EXPOSE 7890 7891 7892 7893 7894 8080 9090

ENTRYPOINT ["/app/docker-entrypoint.sh"]
