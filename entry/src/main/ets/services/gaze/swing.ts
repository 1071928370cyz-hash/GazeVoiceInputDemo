//@ts-nocheck
/* =======================================================================
 *  注视后端「一键开关」——只需要改 2 个地方，这是其中之一。
 *
 *  ┌── 本机 / 没有 Swing SDK（默认）：保持现在这样不动。
 *  │     App 能正常编译、安装；注视走「点搜索框=注视」手动兜底。
 *  │
 *  └── 公司环境 / 有 Swing SDK：启用真注视，做两步——
 *        第 1 步（本文件）：把下面【关】整段用 /* *\/ 注释掉，
 *                          再把【开】整段最外层的 /* 和 *\/ 删掉（取消注释）。
 *        第 2 步：打开 entry/src/main/module.json5，按里面的提示
 *                取消 SUBSCRIBE_SWING_ABILITY 那段权限的注释。
 *  ======================================================================= */


/* ========================= 【开】启用 Swing（公司环境用，取消本段注释）=========================
import swingability from '@ohos.swingability'
import { emitter } from '@kit.BasicServicesKit';
import { JSON } from '@kit.ArkTS';

export class DataSender {
  static sendData(result: string) {
    emitter.emit("dataFromSwing", { data: result});   // 硬件回调 → 应用内事件总线
  }
}

export let sw = swingability;                          // 系统感知实例：sw.on / sw.off

export class SwingSubscribeCallback implements swingability.SubscribeCallback{
  onSwingEvent(result: Record<string,object>):void{
    let res = JSON.stringify(result);                  // 整个事件序列化成字符串转发
    DataSender.sendData(res);
  }
}

export let swingSubscribeCallback : SwingSubscribeCallback = new SwingSubscribeCallback();
export let eventList = new Array<swingability.SwingEventType>();

let aodEventType:swingability.SwingEventType = {
  eventType:'EYE_GAZE_SCREEN_ON',                      // 注视亮屏事件
  params: { 'domainId': 2 }                            // domainId 固定 2，别动
}
eventList.push(aodEventType);
========================= 【开】结束 ========================= */


// ========================= 【关】不启用 Swing（本机默认，可编译安装）=========================
// 桩实现：不 import @ohos.swingability，因此本机/公开 SDK 也能编译。
// sw.on 直接返回 -1，GazeDetector 收到非 0 码后自动走「手动兜底」，整条链路照常。
export class DataSender {
  static sendData(result: string) { /* 本机模式无硬件回调 */ }
}

export let sw = {
  on: (events: Object, cb: Object): Promise<number> => Promise.resolve(-1),   // -1 = 未启用 Swing -> 上层走手动兜底
  off: (events: Object, cb: Object): void => { /* no-op */ }
};

export class SwingSubscribeCallback {
  onSwingEvent(result: Object): void { /* 本机模式不会被调用 */ }
}

export let swingSubscribeCallback: SwingSubscribeCallback = new SwingSubscribeCallback();
export let eventList: Object[] = [];
// ========================= 【关】结束 =========================
