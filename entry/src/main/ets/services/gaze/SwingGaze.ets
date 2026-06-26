import { sw, eventList, swingSubscribeCallback } from './swing';
import { emitter } from '@kit.BasicServicesKit';

export interface SwingCallbacks {
  onState: (code: number, msg: string) => void;    // 订阅结果：0=成功，其它=失败码
  onRaw: (dump: string) => void;                    // 每次回调原样打出整个 EventData（排错/核对字段名用）
  onGaze: (eyeGaze: number, raw: string) => void;   // 解析出的 eyeGaze（1看/0不看/2无脸）
}

interface SwingMsg { eyeGaze: number; }              // result 里只取这一个字段

export class SwingGaze {
  private cb: SwingCallbacks | null = null;

  start(cb: SwingCallbacks): void {
    this.cb = cb;
    // ① 先订阅应用内通道：swing.ts 收到硬件回调后转发到 "dataFromSwing"
    emitter.on('dataFromSwing', (data: emitter.EventData): void => { this.onEmitter(data); });
    // ② 向系统注册（需权限 + 可能系统签名；缺权限会在这里失败，onState 报出来）
    try {
      sw.on(eventList, swingSubscribeCallback).then((code: number): void => {
        const c = this.cb; if (c) { c.onState(code, ''); }   // code===0 即成功
      }).catch((err: Error): void => {
        const c = this.cb; if (c) { c.onState(-1, err ? err.message : 'on() rejected'); }
      });
    } catch (e) {
      const c = this.cb; if (c) { c.onState(-1, (e as Error).message); }
    }
  }

  private onEmitter(data: emitter.EventData): void {
    const c = this.cb; if (!c) { return; }
    // 排错：先把整个 EventData 原样打出来（万一真机字段名/结构不一样，一眼能看出）
    let dump = '';
    try { dump = JSON.stringify(data); } catch (e) { dump = '[stringify fail]'; }
    c.onRaw(dump);
    // swing.ts emit 的是 { data: <JSON字符串> }，取出原始串再解析
    let raw: string = '';
    try { raw = (data && data.data !== undefined && data.data !== null) ? String(data.data) : ''; } catch (e) { raw = ''; }
    if (raw.length === 0) { return; }
    try {
      const m = JSON.parse(raw) as SwingMsg;
      c.onGaze(Number(m.eyeGaze), raw);
    } catch (e) {
      c.onGaze(-1, raw);   // 解析失败也把原始串抛上去
    }
  }

  stop(): void {
    try { emitter.off('dataFromSwing'); } catch (e) { /* 忽略 */ }
    try { sw.off(eventList, swingSubscribeCallback); } catch (e) { /* off 可能未实现，无害 */ }
    this.cb = null;
  }
}
