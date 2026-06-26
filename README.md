# GazeVoiceInputDemo —— 注视唤起 · 握持手侧语音输入（HarmonyOS / ArkTS）

单手握持手机时，顶部地址/搜索框够不着、也不好打字（华为视频、浏览器、应用市场等场景）。
本 Demo：**注视顶部输入框 → 在握持手一侧浮出语音按钮 → 长按即可语音输入**，转写文本实时回填。

## 三路感知

| 能力 | 模块 / API | 状态 |
| --- | --- | --- |
| 握持手（智感握姿） | `@kit.MultimodalAwarenessKit` · `motion.on('holdingHandChanged')` | ✅ 原生，权限 `ohos.permission.DETECT_GESTURE`，需 HarmonyOS 6.0.0.115+ |
| 语音录入 + 实时转写 | Core Speech Kit · `speechRecognizer` | ✅ 原生，权限 `ohos.permission.MICROPHONE` |
| 注视（是否看屏幕） | Swing 系统注视服务 `@ohos.swingability` · `EYE_GAZE_SCREEN_ON` | ✅ 事件驱动真眼动，权限 `ohos.permission.SUBSCRIBE_SWING_ABILITY`（需 swingability SDK + 可能系统签名）。见 `services/gaze/`；订阅失败自动回退「点击搜索框＝注视」手动兜底 |

> ⚠️ 构建硬依赖：引入 `@ohos.swingability` 后整个工程**只能在装了该 SDK 的环境（公司 env）编译**，
> 公开 SDK 的 DevEco 会编译失败。本机若要先跑通其余功能，临时把 `GazeDetector.ets` 对
> `./gaze/SwingGaze` 的 import 注释、`start()` 里 `this.swing.start(sc)` 改为不调用即可回退纯手动。

## 交互流程

1. 点击/注视顶部"搜索"图标 → 拉起只读输入框 + 语音按钮（**不弹软键盘**）
2. 语音按钮出现在握持手一侧：`holdingHandChanged` 判定优先，拿不到则用"最近触摸落在左/右半屏"兜底，再不行默认右手
3. **单击语音按钮开始转写，再单击结束**（Typeless 风格）；录音中按钮显示声波动效，文本实时回填
4. 松手回到单个按钮；一段时间未注视 → 输入框与按钮收起

## 关键源码

```
entry/src/main/ets/
├── pages/Index.ets            # 仿华为视频搜索页 + 三路感知编排
├── components/VoiceButton.ets # 握持手侧语音按钮（单击切换 + 声波动效）
└── services/
    ├── HandDetector.ets       # 握持手检测（holdingHandChanged）
    ├── GazeDetector.ets       # 注视检测（原生占位 + 手动兜底）
    └── SpeechService.ets      # 语音转写（speechRecognizer）
```

## 运行

DevEco Studio 打开工程 → 开启自动签名 → 连**真机**（握持手/语音为端侧能力，模拟器不可验证）→ Run。
首次启动授予麦克风、手势识别(DETECT_GESTURE)权限。

> 握持手能力依赖机型/系统版本：低于 HarmonyOS 6.0.0.115 的设备订阅会抛 801，
> 此时握持侧自动回退到触摸落点判定。界面左上角状态条会实时显示 `motion状态` 便于排查。
