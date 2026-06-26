//@ts-nocheck
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
