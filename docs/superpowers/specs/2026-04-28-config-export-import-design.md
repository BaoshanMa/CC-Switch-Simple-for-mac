# 全局配置导出/导入功能设计

## 概述

在 CC-Switch 设置窗口中添加「导出配置」和「导入配置」功能，允许用户将所有 Profile 和 Provider 数据导出为 JSON 文件进行备份，以及从备份文件恢复配置。

## 数据格式

导出的 JSON 文件结构如下：

```json
{
  "version": "1.0",
  "exportDate": "2026-04-28T10:00:00Z",
  "profiles": [
    {
      "id": "UUID",
      "name": "公司",
      "configDir": "/path/to/config",
      "activeProviderId": "UUID-or-null"
    }
  ],
  "providers": [
    {
      "id": "UUID",
      "profileId": "UUID",
      "name": "公司 API",
      "env": {
        "anthropicAuthToken": "sk-...",
        "anthropicBaseURL": "https://api.anthropic.com",
        "anthropicModel": "claude-sonnet-4-20250514",
        "anthropicDefaultHaikuModel": "claude-haiku-4-20250514",
        "anthropicDefaultSonnetModel": "claude-sonnet-4-20250514",
        "anthropicDefaultOpusModel": "claude-opus-4-20250514",
        "apiTimeoutMs": "60000",
        "claudeCodeDisableNonessentialTraffic": "false"
      }
    }
  ]
}
```

**注意**：API Token 会完整导出，导出时需向用户提示风险。

## 导出流程

1. 用户点击「导出配置」按钮
2. 弹出系统警告对话框，提示：「导出文件包含 API Token，请妥善保管」
3. 用户确认后，弹出 `NSSavePanel` 系统文件保存对话框
4. 默认文件名格式：`CCSwitch-backup-YYYYMMDD.json`
5. 保存成功后显示成功提示

## 导入流程

1. 用户点击「导入配置」按钮
2. 弹出 `NSOpenPanel` 系统文件选择对话框，仅允许选择 `.json` 文件
3. 读取并解析 JSON 文件，校验格式和版本
4. **名称冲突处理**：若导入的 Profile 名称与现有重复，自动重命名为 `{原名} (导入)`
5. 解析完成后写入 `config.json`
6. 刷新 AppState 显示导入的数据
7. 显示成功提示，包含导入的 Profile 和 Provider 数量

## UI 设计

### 位置
在设置窗口的「通用」面板底部，或侧边栏底部新增「数据」区域。

### 按钮布局
```
[导出配置]  [导入配置]
```

### 按钮样式
- 使用系统标准按钮样式
- 导出按钮在前（主操作），导入按钮在后（次操作）

## 错误处理

| 场景 | 处理方式 |
|------|----------|
| 文件读取失败 | 弹出错误提示 |
| JSON 格式无效 | 弹出错误提示，指出问题 |
| 版本不兼容 | 弹出警告，可选择继续或取消 |
| 无数据可导出 | 弹出提示「暂无配置可导出」 |

## 依赖变更

- 新增 `ImportExportService` 服务类，负责序列化和反序列化
- `AppState` 新增 `exportAll()` 和 `importFrom(data:)` 方法
- 设置窗口新增两个按钮和对应的 action

## 实现文件

- `CCSwitch/Services/ImportExportService.swift` — 新增，导入导出逻辑
- `CCSwitch/Views/Settings/SettingsRootView.swift` — 修改，添加按钮
- `CCSwitch/Models/AppState.swift` — 修改，新增导入导出入口方法
