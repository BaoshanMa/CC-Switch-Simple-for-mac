# CC Switch 设计文档

**日期：** 2026-04-27  
**项目：** mac-cc-switch  
**描述：** macOS 原生桌面工具，用于管理和切换 Claude Code 的多套配置

---

## 一、背景与目标

Claude Code 通过 `CLAUDE_CONFIG_DIR` 环境变量指定配置目录，目录下的 `settings.json` 控制所有运行参数。用户在多个 AI 供应商（如 MiniMax、Anthropic 官方）或多个身份（公司、个人）之间切换时，需要手动修改 `settings.json`，操作繁琐且容易出错。

CC Switch 提供一个常驻菜单栏的原生 macOS 工具，支持：
- 管理多个配置目录（Profile）
- 每个目录下管理多套供应商配置（Provider）
- 一键切换，自动写入 `settings.json`

---

## 二、技术选型

| 项目 | 选择 |
|------|------|
| 技术栈 | Swift / SwiftUI |
| 最低系统版本 | macOS 13 Ventura |
| 分发方式 | GitHub Releases（.dmg / .zip） |
| 代码签名 | Apple 公证（Notarization） |
| 数据存储 | `UserDefaults` + JSON 文件（存于 App Support） |

---

## 三、核心概念

### 3.1 Profile（配置目录）

对应一个 `CLAUDE_CONFIG_DIR` 目录路径，加上用户给它起的中文名称。

```
Profile {
  id: UUID
  name: String          // 如"公司"、"默认"、"个人"
  configDir: URL        // CLAUDE_CONFIG_DIR 对应的目录路径
  activeProviderId: UUID?  // 当前激活的供应商
}
```

### 3.2 Provider（供应商配置）

属于某个 Profile，存储一组 `env` 字段，切换时写入对应 `settings.json` 的 `env` 节点。

```
Provider {
  id: UUID
  profileId: UUID
  name: String          // 如"MiniMax 生产"、"Anthropic 直连"
  env: [String: String] // 完整 env 字段集合
}
```

**env 字段列表（固定字段，UI 逐字段展示）：**

| 字段 | 说明 |
|------|------|
| `ANTHROPIC_AUTH_TOKEN` | API Token，界面脱敏显示 |
| `ANTHROPIC_BASE_URL` | API 地址 |
| `ANTHROPIC_MODEL` | 默认模型 |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | Haiku 模型 |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | Sonnet 模型 |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | Opus 模型 |
| `API_TIMEOUT_MS` | 超时时间（毫秒） |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | 关闭非必要流量（0/1） |

以上 8 个字段为全量固定字段，不支持自定义扩展字段。UI 中每个字段均有独立输入框，空值字段仍保存到 env（值为空字符串），切换时完整覆写整个 `env` 节点。

### 3.3 配置模版（Template）

每个 Profile 对应一份模版，存储 `settings.json` 中除 `env` 外的所有内容（如 `permissions`、`hooks`、`theme` 等）。

---

## 四、写入逻辑

切换供应商时，写入流程如下：

```
最终 settings.json = 配置模版（除 env） + 当前 Provider 的 env 字段
```

- 读取该 Profile 的模版 JSON
- 将模版中的 `env` 字段替换为所选 Provider 的 env 数据
- 写入 `{configDir}/settings.json`

**保证：** 切换供应商不会影响模版中的 `permissions`、`hooks` 等配置。

---

## 五、UI 设计

### 5.1 菜单栏弹出面板（两级）

**一级：Profile 列表**
- 每行显示：状态点 + Profile 名称 + 目录路径摘要 + 当前激活的 Provider 名称
- 当前激活的 Profile 高亮显示
- 点击某行 → 替换当前弹出视图为二级 Provider 列表（SwiftUI NavigationStack push，不弹新窗口）
- 底部入口：「管理目录...」→ 打开设置窗口；「退出」

**二级：Provider 列表**
- 顶部返回按钮 + 当前 Profile 名称
- 每行显示：状态点 + Provider 名称 + BASE_URL 摘要
- 当前激活的 Provider 显示「使用中」标签
- 点击某行 → 立即切换（写入 settings.json）
- 底部入口：「管理供应商...」→ 打开设置窗口并定位到该 Profile

### 5.2 设置窗口

**左侧：Profile 列表**
- 每行：Profile 名称 + 路径 + 「克隆」「删除」按钮
- 底部：「+ 添加目录」按钮（弹出目录选择器 + 名称输入）
- 选中某行后右侧展示该 Profile 的 Provider 列表

**右侧：Provider 列表**
- 顶部操作栏：
  - 左侧：当前 Profile 名称 / 供应商配置
  - 右侧：「📄 配置模版」按钮 + 「+ 添加供应商」按钮
- Provider 卡片列表：
  - 每张卡片：状态点 + 名称 + 「使用中」标签（激活时）+ 「克隆」「编辑」「删除」按钮
  - 卡片摘要：BASE_URL、MODEL、HAIKU、SONNET 四个字段
  - 点击卡片或「编辑」→ 打开编辑弹窗

### 5.3 供应商编辑弹窗

- 名称输入框
- 全量 env 字段输入框，逐字段展示
- `ANTHROPIC_AUTH_TOKEN` 默认脱敏，有「显示/隐藏」切换
- 底部：「取消」「保存」按钮
- 保存后若该 Provider 为当前激活状态，立即重新写入 settings.json

### 5.4 配置模版编辑弹窗

- 标题：「配置模版 — {Profile 名称}」+ 文件路径
- 全量 JSON 文本编辑器（TextEditor）
- `env` 字段在 JSON 中置灰展示，并附提示：「env 由供应商配置统一管理，保存时将保留当前激活供应商的 env 值」
- 底部：「取消」「保存模版」按钮

---

## 六、克隆行为

| 操作 | 行为 |
|------|------|
| 克隆 Profile | 复制该 Profile 下所有 Provider 配置；新 Profile 名称为「原名称 副本」；弹出目录选择器让用户指定新的 configDir 路径 |
| 克隆 Provider | 复制所有 env 字段；新 Provider 名称为「原名称 副本」；挂载在同一 Profile 下；立即进入编辑弹窗 |

---

## 七、数据持久化

- Profile 和 Provider 列表存储在 `~/Library/Application Support/CCSwitch/config.json`
- 每次切换供应商后写入对应目录的 `settings.json`
- 配置模版内容从 `settings.json` 实时读取，不单独存储

**模版读取边界说明：**
- 打开「配置模版」编辑弹窗时，实时读取 `{configDir}/settings.json` 当前内容作为初始值
- 若 `settings.json` 不存在，模版初始值为 `{}`（空对象）
- 若 `settings.json` 被外部工具修改，下次打开弹窗时读取最新内容；工具不监听文件变化
- 保存模版时：将编辑后的 JSON（排除 `env` 字段）与当前激活 Provider 的 env 合并后写入

---

## 八、错误处理

| 场景 | 处理方式 |
|------|---------|
| configDir 目录不存在 | 提示用户，提供「创建目录」选项 |
| settings.json 写入失败 | 弹出错误提示，不改变激活状态 |
| JSON 格式错误（模版编辑） | 保存前校验，提示具体错误行 |
| Token 为空 | 允许保存，但切换时显示警告 |

---

## 九、范围外（Not In Scope）

- 不修改 `CLAUDE_CONFIG_DIR` 环境变量（用户自行配置 shell）
- 不支持 Windows / Linux
- 不支持 Claude Code 进程的自动重启
- 不支持配置同步 / 云端备份
