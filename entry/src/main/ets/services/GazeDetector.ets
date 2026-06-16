/**
 * GazeDetector —— “用户是否注视屏幕上方输入框” 检测
 *
 * ⚠️ 重要说明（务必先读）：
 * HarmonyOS 的 Multimodal Awareness Kit 对外宣传了“注视(gaze)”能力（用于美颜相机
 * “看屏幕自动开美颜”，精度 ±2°），但截至目前，面向第三方应用、可在公开文档中
 * 核实签名的注视 ArkTS 接口我无法确认。公开已核实的多模态感知子模块是：
 *   - motion（动作感知 / 左右手，API 15）
 *   - stationary（设备静止）
 * 因此本文件用“能力探测 + try/catch”把原生注视包起来：
 *   1) 若你的设备/SDK 暴露了真实注视接口，请在 startNative() 里按真实签名补一行订阅；
 *   2) 任何失败都会自动回退到手动触发（fallback），保证实机一定能演示整条链路。
 *
 * 真实接口确认方式：在 DevEco Studio 里输入 `import { ` 后看 @kit.MultimodalAwarenessKit
 * 的自动补全，或查本地 SDK 的 d.ts；找到注视相关子模块（形如 gaze / userStatus）后，
 * 把它的 on('xxxChanged', cb) 填进下方 startNative() 即可，UI 层无需改动。
 */

export type GazeListener = (lookingAtTop: boolean) => void;

export class GazeDetector {
  private callback?: GazeListener;
  private nativeActive: boolean = false;
  private lastValue: boolean = false;

  /** 是否成功启用了原生注视（false = 当前在用手动兜底） */
  get usingNative(): boolean {
    return this.nativeActive;
  }

  start(cb: GazeListener): void {
    this.callback = cb;
    this.nativeActive = this.startNative();
    if (!this.nativeActive) {
      console.warn('[GazeDetector] 原生注视不可用，已切换到手动兜底（点击输入框 = 注视）。');
    }
  }

  /**
   * 尝试启用原生注视。返回是否成功。
   *
   * 下面是“占位实现”：以 motion 子模块同款风格写好骨架并做能力探测，
   * 一旦确认真实子模块名与事件名，替换 import 与 on(...) 两行即可。
   */
  private startNative(): boolean {
    try {
      // ——【替换点】真实注视接口确认后，按如下风格接入（示例，非已核实签名）——
      //
      //   import { gaze } from '@kit.MultimodalAwarenessKit';
      //   gaze.on('gazeStateChanged', (state: gaze.GazeState) => {
      //     this.emit(state === gaze.GazeState.LOOKING_AT_SCREEN);
      //   });
      //   return true;
      //
      // 在确认前，保持探测失败，走兜底，避免编译期引用不存在的符号。
      return false;
    } catch (e) {
      console.error(`[GazeDetector] startNative 失败: ${JSON.stringify(e)}`);
      return false;
    }
  }

  /** 手动兜底触发：演示时由 UI 调用（如点击/聚焦顶部输入框视为“正在注视”）。 */
  manualSetLooking(looking: boolean): void {
    if (this.nativeActive) {
      // 原生已生效时忽略手动信号，避免互相打架
      return;
    }
    this.emit(looking);
  }

  private emit(looking: boolean): void {
    if (looking === this.lastValue) {
      return;
    }
    this.lastValue = looking;
    this.callback?.(looking);
  }

  stop(): void {
    // 原生接入后，在此 off 对应事件
    this.nativeActive = false;
    this.callback = undefined;
  }
}
