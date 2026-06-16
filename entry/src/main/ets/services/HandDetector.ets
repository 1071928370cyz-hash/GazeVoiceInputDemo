/**
 * HandDetector —— 握持手检测（智感握姿）
 *
 * 基于 Multimodal Awareness Kit 的 motion 子模块「握持手」能力：
 *   import { motion } from '@kit.MultimodalAwarenessKit'
 *   motion.on('holdingHandChanged', (data: motion.HoldingHandStatus) => {...})
 *   motion.off('holdingHandChanged', cb)
 *   枚举 HoldingHandStatus:
 *     NOT_HELD=0 / LEFT_HAND_HELD=1 / RIGHT_HAND_HELD=2 / BOTH_HANDS_HELD=3 / UNKNOWN_STATUS=16
 *   权限: ohos.permission.DETECT_GESTURE
 *   设备: HarmonyOS 6.0.0.115+ 手机
 *
 * 与「操作手 operatingHandChanged」不同，握持手无需触摸屏幕即可识别哪只手握着设备，
 * 正好用于决定语音按钮浮出在哪一侧。不支持的设备订阅时抛 801。
 */
import { motion } from '@kit.MultimodalAwarenessKit';
import { BusinessError } from '@kit.BasicServicesKit';

export type Hand = 'left' | 'right' | 'unknown';
export type HandStatusText = string;

export class HandDetector {
  private callback?: (hand: Hand) => void;
  private statusCb?: (text: HandStatusText) => void;
  private subscribed: boolean = false;

  private readonly listener = (data: motion.HoldingHandStatus): void => {
    console.info(`[HandDetector] holdingHandChanged -> ${data}`);
    this.statusCb?.(`回调=${HandDetector.label(data)}(${data})`);
    this.callback?.(HandDetector.map(data));
  };

  private static map(status: motion.HoldingHandStatus): Hand {
    switch (status) {
      case motion.HoldingHandStatus.LEFT_HAND_HELD:
        return 'left';
      case motion.HoldingHandStatus.RIGHT_HAND_HELD:
        return 'right';
      default:
        // 未握持 / 双手 / 未识别 -> 交给上层兜底
        return 'unknown';
    }
  }

  private static label(status: motion.HoldingHandStatus): string {
    switch (status) {
      case motion.HoldingHandStatus.LEFT_HAND_HELD:
        return '左手握持';
      case motion.HoldingHandStatus.RIGHT_HAND_HELD:
        return '右手握持';
      case motion.HoldingHandStatus.BOTH_HANDS_HELD:
        return '双手握持';
      case motion.HoldingHandStatus.NOT_HELD:
        return '未握持';
      default:
        return '未识别';
    }
  }

  /**
   * 开始监听握持手变化。
   * @param cb       握持手变化回调
   * @param statusCb 诊断文本回调（订阅结果 / 错误码 / 实时状态）
   */
  start(cb: (hand: Hand) => void, statusCb?: (text: HandStatusText) => void): boolean {
    this.callback = cb;
    this.statusCb = statusCb;

    try {
      motion.on('holdingHandChanged', this.listener);
      this.subscribed = true;
      this.statusCb?.('已订阅·等待握持事件');
      return true;
    } catch (e) {
      const err = e as BusinessError;
      const reason = err.code === 801 ? '设备不支持(801)'
        : err.code === 201 ? '权限被拒(201)·需DETECT_GESTURE'
        : `订阅失败(${err.code})`;
      console.error(`[HandDetector] ${reason} msg=${err.message}`);
      this.statusCb?.(reason);
      this.subscribed = false;
      return false;
    }
  }

  stop(): void {
    if (!this.subscribed) {
      return;
    }
    try {
      motion.off('holdingHandChanged', this.listener);
    } catch (e) {
      console.warn(`[HandDetector] 取消订阅失败: ${JSON.stringify(e)}`);
    }
    this.subscribed = false;
  }
}
