# GitHub Release Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 发布 OpenAI 仪表盘 `1.18.0`，并将主仓库、GitHub Release、Sparkle 更新清单和 DMG 下载地址全部切换到 GitHub。

**Architecture:** 保持应用业务逻辑不变，只调整版本与发布配置。`Resources/Info.plist` 决定新版应用读取的 GitHub appcast，`make-dmg.sh` 生成指向 GitHub Release 的签名清单；代码和标签先推送，Release 附件验证可下载后才把 `appcast.xml` 提交到 `main` 根目录。

**Tech Stack:** Swift 6、SwiftUI、Sparkle 2.10.1、zsh、AsciiDoc、macOS `hdiutil`/`codesign`/`lipo`、Git、GitHub CLI。

## Global Constraints

- 发布版本固定为 `1.18.0`，`CFBundleVersion` 固定为 `79`。
- 最低系统版本保持 `macOS 14.0`。
- 发布二进制必须同时包含独立编译的 `x86_64` 与 `arm64`。
- 运行时依赖只允许系统库和 App 内签名的 `Sparkle.framework`。
- 签名身份固定为 `OpenAIBar Local Signing`，不得回退 ad-hoc。
- Sparkle 公钥保持 `Os/Vy3rYQc18mMiPrldbhC8l8geQYu7slcsg6OMOziM=` 不变。
- 不向 Gitee 推送代码、标签、Release 或 appcast。
- 不安装、替换、启动或退出 `/Applications/OpenAI 仪表盘.app`。
- 运行验收仅使用 `/private/tmp/` 测试副本和独立 `--qa-application-support` 目录。
- `dist/` 最终只保留 `dist/OpenAI 仪表盘-1.18.0.dmg`。

---

## File Map

- `Resources/Info.plist`：应用版本、构建号和 Sparkle 更新源。
- `make-dmg.sh`：生成发布 DMG、英文名 Release 附件和签名 appcast。
- `README.adoc`：用户安装、更新和构建发布说明的源文件。
- `docs/README.html`：由 `README.adoc` 生成的 HTML。
- `AGENTS.md`：项目后续 GitHub 发布与验收强制规约。
- `Resources/AppIcon.icns`：构建时重新生成；只有内容变化时提交。
- `dist/OpenAI 仪表盘-1.18.0.dmg`：仓库中保留的唯一发布 DMG。
- `.build/release/OpenAI-Dashboard-1.18.0.dmg`：GitHub Release 上传附件，不纳入 Git。
- `.build/release/appcast.xml`：构建生成的签名清单，不直接纳入 Git。
- `appcast.xml`：Release 验证通过后复制到 `main` 根目录并提交。

### Task 1: 切换版本与发布地址

**Files:**
- Modify: `Resources/Info.plist:21-26`
- Modify: `make-dmg.sh:97-108`

**Interfaces:**
- Consumes: `Resources/Info.plist` 中的版本号；Sparkle `generate_appcast`。
- Produces: 版本为 `1.18.0 (79)`、读取 GitHub appcast 的 App，以及指向 GitHub Release 的 `.build/release/appcast.xml`。

- [ ] **Step 1: 运行发布配置断言，确认旧配置会失败**

```bash
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)" = "1.18.0"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info.plist)" = "79"
test "$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' Resources/Info.plist)" = "https://raw.githubusercontent.com/xbguan/openai-dashboard/main/appcast.xml"
rg -F 'https://github.com/xbguan/openai-dashboard/releases/download/openai-dashboard-v${VERSION}/' make-dmg.sh
```

Expected: 前三条因仍为 `1.17.6`、`78`、Gitee URL 而失败，第四条找不到 GitHub 前缀。

- [ ] **Step 2: 修改版本和更新源**

将 `Resources/Info.plist` 的相关值改为：

```xml
<key>CFBundleShortVersionString</key>
<string>1.18.0</string>
<key>CFBundleVersion</key>
<string>79</string>
<key>SUFeedURL</key>
<string>https://raw.githubusercontent.com/xbguan/openai-dashboard/main/appcast.xml</string>
```

将 `make-dmg.sh` 的 `--download-url-prefix` 改为：

```zsh
--download-url-prefix "https://github.com/xbguan/openai-dashboard/releases/download/openai-dashboard-v${VERSION}/" \
```

- [ ] **Step 3: 重新运行发布配置断言**

```bash
plutil -lint Resources/Info.plist
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)" = "1.18.0"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info.plist)" = "79"
test "$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' Resources/Info.plist)" = "https://raw.githubusercontent.com/xbguan/openai-dashboard/main/appcast.xml"
rg -F 'https://github.com/xbguan/openai-dashboard/releases/download/openai-dashboard-v${VERSION}/' make-dmg.sh
! rg -F 'gitee.com/baoyeguan/openai-dashboard' Resources/Info.plist make-dmg.sh
```

Expected: 所有命令退出码为 `0`，`plutil` 输出 `OK`。

- [ ] **Step 4: 提交配置切换**

```bash
git add Resources/Info.plist make-dmg.sh
git commit -m "feat: switch updates to GitHub"
```

### Task 2: 更新项目规约与用户文档

**Files:**
- Modify: `AGENTS.md:10-42`
- Modify: `AGENTS.md:151-156`
- Modify: `README.adoc:11-17`
- Modify: `README.adoc:53-58`
- Modify: `README.adoc:146-153`
- Modify: `README.adoc:188-210`
- Modify: `docs/README.html`

**Interfaces:**
- Consumes: Task 1 确定的版本号、GitHub feed 和 Release URL。
- Produces: 与实际发布流程一致的强制规约、用户说明和渲染 HTML。

- [ ] **Step 1: 运行文档断言，确认旧文档会失败**

```bash
rg -F 'dist/OpenAI 仪表盘-1.18.0.dmg' README.adoc
rg -F 'raw.githubusercontent.com/xbguan/openai-dashboard/main/appcast.xml' AGENTS.md
rg -F 'GitHub Release' README.adoc AGENTS.md
! rg -F '后续不向 GitHub 推送或发布' AGENTS.md
```

Expected: 新版本和 GitHub 发布说明找不到，旧的“不向 GitHub”约定仍存在。

- [ ] **Step 2: 更新 `AGENTS.md`**

将 `1.2 Gitee Release 同步` 改为 `1.2 GitHub Release 同步`，明确：

- 主仓库为 `https://github.com/xbguan/openai-dashboard.git`。
- 标签格式继续使用 `openai-dashboard-v<版本>`。
- Release 附件为一个英文名 DMG，`dist/` 仍只保留一个中文名 DMG。
- 只有用户明确要求“推送并发布”才执行 GitHub 推送与 Release。
- Release 附件可下载且 SHA-256 一致后，才把签名清单提交为 GitHub `main/appcast.xml`。
- Gitee 保留历史内容，不再接收后续代码、标签、Release 或 appcast。
- `1.17.4`～`1.17.6` 用户需手动安装一次 `1.18.0`。

将 `7.1 Sparkle 更新签名` 的 feed 和下载源改为 GitHub，并保留 EdDSA、私钥和隔离验收约束。

- [ ] **Step 3: 更新 `README.adoc`**

完成以下精确内容变更：

- 两处安装包版本从 `1.17.6` 改为 `1.18.0`。
- “每 8 小时检查 Gitee”改为“每 8 小时检查 GitHub”。
- 说明 `1.17.4`～`1.17.6` 需要手动安装一次 `1.18.0`。
- 构建产物说明改为上传 GitHub Release，并在验证附件后把签名清单提交到 GitHub `main` 根目录。

- [ ] **Step 4: 渲染 README**

```bash
asciidoctor README.adoc -o docs/README.html -a imagesdir=.
```

Expected: 退出码 `0`，`docs/README.html` 更新时间变化。

- [ ] **Step 5: 验证文档一致性**

```bash
rg -F 'dist/OpenAI 仪表盘-1.18.0.dmg' README.adoc
rg -F 'https://raw.githubusercontent.com/xbguan/openai-dashboard/main/appcast.xml' AGENTS.md
rg -F 'GitHub Release' README.adoc AGENTS.md
! rg -F '后续不向 GitHub 推送或发布' AGENTS.md
! rg -F '每 8 小时检查 Gitee' README.adoc
! rg -F 'dist/OpenAI 仪表盘-1.17.6.dmg' README.adoc
git diff --check
```

Expected: 正向匹配存在，所有否定匹配为空，`git diff --check` 无输出。

- [ ] **Step 6: 提交文档和规约**

```bash
git add AGENTS.md README.adoc docs/README.html
git commit -m "docs: make GitHub the release channel"
```

### Task 3: 将 GitHub 设为本地主远端

**Files:**
- Modify: `.git/config`（本机配置，不提交）

**Interfaces:**
- Consumes: 现有 `origin`（Gitee）与 `github`（GitHub）remote。
- Produces: `origin` 指向 GitHub，`gitee` 指向历史 Gitee 仓库，`main` 跟踪 `origin/main`。

- [ ] **Step 1: 记录并验证当前 remote**

```bash
git remote -v
test "$(git remote get-url origin)" = "git@gitee.com:baoyeguan/openai-dashboard.git"
test "$(git remote get-url github)" = "https://github.com/xbguan/openai-dashboard.git"
```

Expected: 两个断言通过。

- [ ] **Step 2: 重命名 remote 并设置跟踪分支**

```bash
git remote rename origin gitee
git remote rename github origin
git branch --set-upstream-to=origin/main main
```

- [ ] **Step 3: 验证 GitHub 已成为主远端**

```bash
test "$(git remote get-url origin)" = "https://github.com/xbguan/openai-dashboard.git"
test "$(git remote get-url gitee)" = "git@gitee.com:baoyeguan/openai-dashboard.git"
test "$(git rev-parse --abbrev-ref main@{upstream})" = "origin/main"
git status --short --branch
```

Expected: 输出 `## main...origin/main [ahead ...]`，工作区没有未预期文件。

### Task 4: 测试、构建、签名和隔离验收

**Files:**
- Modify when regenerated: `Resources/AppIcon.icns`
- Delete: `dist/OpenAI 仪表盘-1.17.6.dmg`
- Create: `dist/OpenAI 仪表盘-1.18.0.dmg`
- Create, untracked: `.build/release/OpenAI-Dashboard-1.18.0.dmg`
- Create, untracked: `.build/release/appcast.xml`

**Interfaces:**
- Consumes: Task 1 的版本与 URL、Task 2 的发布规约、本机签名身份和 Sparkle 私钥。
- Produces: 已验证的 universal DMG、同内容英文附件和签名 appcast。

- [ ] **Step 1: 运行现有测试**

```bash
swift test --disable-sandbox
zsh Tests/test-credential-upgrade.sh
```

Expected: Swift 测试全部通过，凭据升级脚本退出码为 `0`。

- [ ] **Step 2: 确认签名身份存在**

```bash
security find-identity -v -p codesigning | rg -F 'OpenAIBar Local Signing'
```

Expected: 输出一个有效签名身份；找不到时停止，不构建 DMG。

- [ ] **Step 3: 前台、沙箱外重新构建 DMG**

```bash
./make-dmg.sh --rebuild
```

Expected: 退出码 `0`，生成 `dist/OpenAI 仪表盘-1.18.0.dmg`、`.build/release/OpenAI-Dashboard-1.18.0.dmg` 和 `.build/release/appcast.xml`，旧 DMG 已被脚本清理。

- [ ] **Step 4: 验证构建产物、架构、签名、依赖和清单**

```bash
hdiutil verify 'dist/OpenAI 仪表盘-1.18.0.dmg'
codesign --verify --deep --strict '.build/bundle/OpenAI 仪表盘.app'
codesign --verify --deep --strict '.build/bundle/OpenAI 仪表盘.app/Contents/Frameworks/Sparkle.framework'
test "$(lipo -archs '.build/bundle/OpenAI 仪表盘.app/Contents/MacOS/OpenAIBar')" = "x86_64 arm64"
otool -L '.build/bundle/OpenAI 仪表盘.app/Contents/MacOS/OpenAIBar'
plutil -p '.build/bundle/OpenAI 仪表盘.app/Contents/Info.plist'
xmllint --noout .build/release/appcast.xml
rg -F 'https://github.com/xbguan/openai-dashboard/releases/download/openai-dashboard-v1.18.0/OpenAI-Dashboard-1.18.0.dmg' .build/release/appcast.xml
rg -F 'sparkle:edSignature=' .build/release/appcast.xml
test "$(shasum -a 256 'dist/OpenAI 仪表盘-1.18.0.dmg' | awk '{print $1}')" = "$(shasum -a 256 '.build/release/OpenAI-Dashboard-1.18.0.dmg' | awk '{print $1}')"
test "$(find dist -maxdepth 1 -name '*.dmg' -type f | wc -l | tr -d ' ')" = "1"
```

Expected: 所有断言通过；`otool -L` 仅显示系统库和 App 内 Sparkle 路径；Info.plist 显示 `1.18.0`、`79` 与 GitHub feed。

- [ ] **Step 5: 从实际 DMG 创建隔离测试副本**

```bash
QA_ROOT=$(mktemp -d /private/tmp/openai-dashboard-1.18.0.XXXXXX)
mkdir -p "$QA_ROOT/mount" "$QA_ROOT/app" "$QA_ROOT/support"
hdiutil attach 'dist/OpenAI 仪表盘-1.18.0.dmg' -readonly -nobrowse -mountpoint "$QA_ROOT/mount"
cp -R "$QA_ROOT/mount/OpenAI 仪表盘.app" "$QA_ROOT/app/"
hdiutil detach "$QA_ROOT/mount"
codesign --verify --deep --strict "$QA_ROOT/app/OpenAI 仪表盘.app"
```

Expected: DMG 成功挂载和卸载，复制后的测试 App 签名有效。

- [ ] **Step 6: 验证测试副本启动且不触碰正式 App**

```bash
"$QA_ROOT/app/OpenAI 仪表盘.app/Contents/MacOS/OpenAIBar" --qa-application-support "$QA_ROOT/support"
```

在前台启动测试副本，检查设置页版本显示 `1.18.0`，确认进程路径位于 `$QA_ROOT/app/`，然后仅退出该测试进程。检查 `$QA_ROOT/support` 已创建，且 `/Applications/OpenAI 仪表盘.app` 的修改时间和运行状态未发生变化。

- [ ] **Step 7: 提交发布产物**

```bash
git status --short
git add Resources/AppIcon.icns 'dist/OpenAI 仪表盘-1.18.0.dmg'
git add -u 'dist/OpenAI 仪表盘-1.17.6.dmg'
git commit -m "release: build OpenAI Dashboard 1.18.0"
```

如果 `Resources/AppIcon.icns` 内容未变化，不把它加入提交。提交后 `git status --short` 必须为空。

### Task 5: 推送代码、标签并创建 GitHub Release

**Files:**
- Read: `.build/release/OpenAI-Dashboard-1.18.0.dmg`
- Read: `.build/release/appcast.xml`

**Interfaces:**
- Consumes: Task 4 的发布提交、英文 DMG 和签名清单。
- Produces: GitHub `main`、`openai-dashboard-v1.18.0` 标签和可匿名下载的 Release 附件。

- [ ] **Step 1: 发布前复核仓库与制品**

```bash
git status --short --branch
git log -5 --oneline --decorate
test "$(git remote get-url origin)" = "https://github.com/xbguan/openai-dashboard.git"
test -f '.build/release/OpenAI-Dashboard-1.18.0.dmg'
test -f '.build/release/appcast.xml'
gh auth status
```

Expected: 工作区干净，`origin` 是 GitHub，两个制品存在，GitHub CLI 已登录。

- [ ] **Step 2: 推送 `main` 并核对远端提交**

```bash
git push origin main
test "$(git rev-parse HEAD)" = "$(git ls-remote origin refs/heads/main | awk '{print $1}')"
```

Expected: 推送成功，本地 HEAD 与 GitHub `main` SHA 完全一致。

- [ ] **Step 3: 创建并推送发布标签**

```bash
git tag -a openai-dashboard-v1.18.0 -m 'OpenAI Dashboard 1.18.0'
git push origin openai-dashboard-v1.18.0
test "$(git rev-list -n 1 openai-dashboard-v1.18.0)" = "$(git rev-parse HEAD)"
```

Expected: 标签成功推送并指向当前发布提交。

- [ ] **Step 4: 创建 GitHub Release 并上传唯一附件**

```bash
gh release create openai-dashboard-v1.18.0 \
  '.build/release/OpenAI-Dashboard-1.18.0.dmg' \
  --repo xbguan/openai-dashboard \
  --verify-tag \
  --title 'OpenAI Dashboard 1.18.0' \
  --notes 'Switch the primary repository, release downloads, and Sparkle update feed to GitHub. Users on 1.17.4–1.17.6 need to install 1.18.0 manually once.'
```

Expected: Release 创建成功，只有 `OpenAI-Dashboard-1.18.0.dmg` 一个附件。

- [ ] **Step 5: 验证 Release 与匿名下载**

```bash
gh release view openai-dashboard-v1.18.0 --repo xbguan/openai-dashboard --json tagName,isDraft,isPrerelease,assets,url
QA_DOWNLOAD=$(mktemp /private/tmp/OpenAI-Dashboard-1.18.0.XXXXXX.dmg)
curl --fail --location --output "$QA_DOWNLOAD" 'https://github.com/xbguan/openai-dashboard/releases/download/openai-dashboard-v1.18.0/OpenAI-Dashboard-1.18.0.dmg'
test "$(shasum -a 256 "$QA_DOWNLOAD" | awk '{print $1}')" = "$(shasum -a 256 'dist/OpenAI 仪表盘-1.18.0.dmg' | awk '{print $1}')"
hdiutil verify "$QA_DOWNLOAD"
```

Expected: Release 不是草稿或预发布，附件数为 `1`；匿名下载、SHA-256 和镜像验证全部通过。

### Task 6: 将 appcast 发布到 GitHub `main` 并完成闭环验证

**Files:**
- Create on `main`: `appcast.xml`

**Interfaces:**
- Consumes: Task 5 已可下载的 GitHub Release DMG，以及 Task 4 的签名 appcast。
- Produces: `https://raw.githubusercontent.com/xbguan/openai-dashboard/main/appcast.xml`。

- [ ] **Step 1: 将签名清单复制到 `main` 根目录并检查**

```bash
cp .build/release/appcast.xml appcast.xml
xmllint --noout appcast.xml
rg -F 'openai-dashboard-v1.18.0/OpenAI-Dashboard-1.18.0.dmg' appcast.xml
rg -F 'sparkle:edSignature=' appcast.xml
test "$(shasum -a 256 appcast.xml | awk '{print $1}')" = "$(shasum -a 256 '.build/release/appcast.xml' | awk '{print $1}')"
```

Expected: XML 有效，下载地址和 EdDSA 签名存在，根目录文件与构建产物逐字节一致。

- [ ] **Step 2: 提交并推送 `main/appcast.xml`**

```bash
git add appcast.xml
git commit -m 'release: publish 1.18.0 appcast'
git push origin main
```

Expected: 提交和非强制推送成功；更新清单只在 Release 附件已验证后公开。

- [ ] **Step 3: 验证公开清单与下载闭环**

```bash
PUBLIC_APPCAST=$(mktemp /private/tmp/openai-dashboard-appcast.XXXXXX.xml)
curl --fail --location --output "$PUBLIC_APPCAST" 'https://raw.githubusercontent.com/xbguan/openai-dashboard/main/appcast.xml'
xmllint --noout "$PUBLIC_APPCAST"
test "$(shasum -a 256 "$PUBLIC_APPCAST" | awk '{print $1}')" = "$(shasum -a 256 '.build/release/appcast.xml' | awk '{print $1}')"
rg -F 'https://github.com/xbguan/openai-dashboard/releases/download/openai-dashboard-v1.18.0/OpenAI-Dashboard-1.18.0.dmg' "$PUBLIC_APPCAST"
rg -F 'sparkle:edSignature=' "$PUBLIC_APPCAST"
```

Expected: 公共清单与本地签名清单逐字节一致，且指向已验证的 Release 附件。

- [ ] **Step 4: 最终仓库与发布状态核对**

```bash
git status --short --branch
test "$(git rev-parse HEAD)" = "$(git ls-remote origin refs/heads/main | awk '{print $1}')"
test "$(git rev-list -n 1 openai-dashboard-v1.18.0)" = "$(git ls-remote origin 'refs/tags/openai-dashboard-v1.18.0^{}' | awk '{print $1}')"
gh release view openai-dashboard-v1.18.0 --repo xbguan/openai-dashboard --json tagName,isDraft,isPrerelease,assets,url
git ls-remote gitee refs/heads/master refs/heads/updates refs/tags/openai-dashboard-v1.18.0
```

Expected: 本地工作区干净；GitHub `main`、标签、Release 和 `main/appcast.xml` 全部可用；Gitee 不存在 `openai-dashboard-v1.18.0` 标签，本次未修改其分支。

---

## Completion Evidence

交付说明必须包含：

- GitHub `main` 与发布标签的完整 SHA。
- GitHub Release 链接。
- Release 附件与本地中文 DMG 的 SHA-256。
- 公开 appcast URL 及其最终验证结果。
- 构建、测试、架构、签名、依赖和隔离验收的实际结果。
- 当前最新本地制品：`dist/OpenAI 仪表盘-1.18.0.dmg`。
- 明确说明正式 App 未被安装、替换、启动或退出，用户将自行安装 `1.18.0`。
