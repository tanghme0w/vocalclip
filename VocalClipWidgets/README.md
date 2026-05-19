# VocalClipWidgets — 灵动岛 / Live Activity 扩展

主 App 的代码已经包含 Live Activity 的属性定义、控制器、AppIntent 桥。
但 Widget Extension 是独立的 Xcode target，无法被主 App `PBXFileSystemSynchronizedRootGroup` 自动同步。需要按以下步骤手动接入：

## 1. 添加 Widget Extension Target

1. 打开 `vocalclip.xcodeproj`。
2. `File → New → Target...`，选择 **Widget Extension**。
3. Product Name 填 `VocalClipWidgets`，**勾选 "Include Live Activity"**。
4. 取消勾选 "Include Configuration Intent"（我们用自己的 AppIntent）。
5. 创建完成后，删除模板自动生成的 `.swift` 文件，将本目录下的 4 个文件加入该 target：
   - `VocalClipWidgetBundle.swift`
   - `VocalClipLiveActivityWidget.swift`
   - 同时把主 App 的 `vocalclip/LiveActivity/VocalClipActivityAttributes.swift` 和 `vocalclip/LiveActivity/VocalClipIntentBridge.swift` 的 **Target Membership** 都勾选上 Widget target。

## 2. 启用 App Group（让 Widget Intent 与主 App 通信）

1. 在主 App target 的 Signing & Capabilities 中，添加 **App Groups**，写入 `group.me0w.vocalclip`。
2. 在 Widget target 同样添加 App Groups，并选中同一个 group。
3. 如果使用免费个人开发者账号，App Group 不可用，可以保持代码不变，会自动降级到主 App 内存通信（仅 `openAppWhenRun=true` 的 Intent 有效，pause/resume/stop 按钮在锁屏可能不工作）。

## 3. 在主 App Info.plist 中添加

`Supports Live Activities` (`NSSupportsLiveActivities`) → `YES`
`Supports Live Activities Frequent Updates` (`NSSupportsLiveActivitiesFrequentUpdates`) → `YES`（可选）

由于本项目使用 `GENERATE_INFOPLIST_FILE = YES`，需在 build settings 中加：
```
INFOPLIST_KEY_NSSupportsLiveActivities = YES
INFOPLIST_KEY_NSSupportsLiveActivitiesFrequentUpdates = YES
```

## 4. 后台音频

为了让朗读在锁屏 / 后台继续进行，需在主 App Info.plist 添加 Background Modes：
`UIBackgroundModes` 数组包含 `audio`。

在 build settings 里加：
```
INFOPLIST_KEY_UIBackgroundModes = audio
```

## 5. 测试灵动岛

- 必须在支持灵动岛的真机（iPhone 14 Pro 以上）测试，模拟器无完整效果。
- 首次启动 App → 自动启动一个 standby Live Activity，灵动岛会显示一个 waveform 图标。
- 点击灵动岛 → 触发 `ReadClipboardIntent` → 唤起 App 并朗读剪贴板。
- 朗读中 → 长按或展开灵动岛 → 看到「暂停 / 停止」按钮。

## 6. URL Scheme

在 `Info.plist` 的 `CFBundleURLTypes` 中注册 `vocalclip://` scheme 以便 `widgetURL` 跳转工作：

```
INFOPLIST_KEY_CFBundleURLTypes = (
    { CFBundleURLSchemes = ( vocalclip ); }
)
```

或在 Xcode 的 Info 选项卡的 URL Types 中手动添加。
