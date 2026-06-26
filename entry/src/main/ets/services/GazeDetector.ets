/**
 * GazeDetector —— “用户是否注视屏幕” 检测（接入 Swing 系统注视服务）
 *
 * 原生注视走华为 Swing 低功耗系统能力：@ohos.swingability 的 EYE_GAZE_SCREEN_ON 事件。
 *   - eyeGaze: 1=正在看 / 0=没在看 / 2=无人脸；只有 1 算“在看”。
 *   - 事件驱动、双向上报，看走/远离立刻报 0；低功耗、不取帧。
 *   - 权限: ohos.permission.SUBSCRIBE_SWING_ABILITY（可能还需系统级签名）。
 *   - 实现见 services/gaze/swing.ts（底层 .ts，勿改）与 services/gaze/SwingGaze.ets（薄封装）。
 *
 * ⚠️ 构建硬依赖：一旦引入 @ohos.swingability，整个工程只能在装了该 SDK 的环境（公司 env）编译；
 *    公开 SDK 的 DevEco 会编译失败。订阅成功(code===0)后 nativeActive=true，由 Swing 驱动注视；
 *    若订阅失败（缺权限/签名），自动回退到“手动兜底”（点击/聚焦顶部输入框视为注视），下游零感知。
 */
import { SwingGaze, SwingCallbacks } from './gaze/SwingGaze';

export type GazeListener = (lookingAtTop: boolean) => void;
export type GazeStatusListener = (native: boolean, text: string) => void;
export type GazeRawListener = (dump: string) => void;

export class GazeDetector {
  private callback?: GazeListener;
  private statusCb?: GazeStatusListener;
  private rawCb?: GazeRawListener;
  private nativeActive: boolean = false;
  private lastValue: boolean = false;
  private swing: SwingGaze = new SwingGaze();

  /** 是否已由 Swing 原生注视驱动（false = 当前在用手动兜底） */
  get usingNative(): boolean {
    return this.nativeActive;
  }

  /**
   * 开始注视检测。
   * @param cb       注视状态回调：true=在看屏幕
   * @param statusCb 订阅状态回调（可选）：native 是否原生生效 + 诊断文本
   */
  start(cb: GazeListener, statusCb?: GazeStatusListener, rawCb?: GazeRawListener): void {
    this.callback = cb;
    this.statusCb = statusCb;
    this.rawCb = rawCb;
    this.statusCb?.(false, 'Swing 订阅中…');

    const sc: SwingCallbacks = {
      onState: (code: number, msg: string): void => {
        if (code === 0) {
          this.nativeActive = true;
          this.statusCb?.(true, 'Swing 订阅成功');
        } else {
          this.nativeActive = false;
          console.warn(`[GazeDetector] Swing 订阅失败 ${code} ${msg}，回退手动兜底`);
          this.statusCb?.(false, `Swing 失败(${code})·手动兜底`);
        }
      },
      onRaw: (dump: string): void => {
        // 把每次硬件回调的原始 EventData 抛到 UI，方便首次核对字段名/取值
        this.rawCb?.(dump);
      },
      onGaze: (eyeGaze: number, _raw: string): void => {
        if (this.nativeActive) {
          this.emit(eyeGaze === 1); // 只有 1 算在看；0/2 都按没看
        }
      }
    };

    try {
      this.swing.start(sc);
    } catch (e) {
      this.nativeActive = false;
      console.error(`[GazeDetector] Swing 启动异常: ${JSON.stringify(e)}`);
      this.statusCb?.(false, 'Swing 启动异常·手动兜底');
    }
  }

  /** 手动兜底触发：Swing 未生效时由 UI 调用（点击/聚焦顶部输入框 = 注视）。 */
  manualSetLooking(looking: boolean): void {
    if (this.nativeActive) {
      // Swing 原生已生效时忽略手动信号，避免互相打架
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
    try {
      this.swing.stop();
    } catch (e) {
      console.warn(`[GazeDetector] Swing 停止异常: ${JSON.stringify(e)}`);
    }
    this.nativeActive = false;
    this.callback = undefined;
    this.statusCb = undefined;
    this.rawCb = undefined;
  }
}
