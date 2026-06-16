/**
 * SpeechService —— 语音录入 + 实时转写
 *
 * 基于 Core Speech Kit 的 speechRecognizer（端侧/离线 ASR）：
 *   import { speechRecognizer } from '@kit.CoreSpeechKit'
 *   speechRecognizer.createEngine(params)
 *   engine.setListener(listener)        // onResult 回传识别文本
 *   engine.startListening(startParams)  // recognitionMode=0 直接走麦克风实时录音识别
 *   engine.finish(sessionId) / cancel(sessionId) / shutdown()
 *   权限: ohos.permission.MICROPHONE
 *
 * 用法贴合“长按说话、松手结束”：长按 -> start()，松手 -> finish()。
 */
import { speechRecognizer } from '@kit.CoreSpeechKit';
import { BusinessError } from '@kit.BasicServicesKit';

export interface SpeechCallbacks {
  // 实时/最终识别文本（partial 会不断刷新，isLast=true 时为最终结果）
  onText: (text: string, isLast: boolean) => void;
  onError: (code: number, message: string) => void;
  onComplete?: () => void;
}

export class SpeechService {
  private engine?: speechRecognizer.SpeechRecognitionEngine;
  private readonly sessionId: string = 'gaze_voice_session';
  private cb?: SpeechCallbacks;
  private listening: boolean = false;

  get isListening(): boolean {
    return this.listening;
  }

  /** 初始化引擎（建议在页面 aboutToAppear 里调用一次）。 */
  async init(): Promise<boolean> {
    if (this.engine) {
      return true;
    }
    const extraParams: Record<string, Object> = { 'locate': 'CN', 'recognizerMode': 'short' };
    const params: speechRecognizer.CreateEngineParams = {
      language: 'zh-CN',
      online: 1, // 端侧（离线）识别，无需联网
      extraParams: extraParams
    };
    try {
      this.engine = await speechRecognizer.createEngine(params);
      this.attachListener();
      return true;
    } catch (e) {
      const err = e as BusinessError;
      console.error(`[SpeechService] createEngine 失败 code=${err.code} msg=${err.message}`);
      return false;
    }
  }

  private attachListener(): void {
    const listener: speechRecognizer.RecognitionListener = {
      onStart: (sessionId: string, eventMessage: string): void => {
        console.info(`[SpeechService] onStart ${sessionId}`);
      },
      onEvent: (sessionId: string, eventCode: number, eventMessage: string): void => {
        console.info(`[SpeechService] onEvent code=${eventCode}`);
      },
      onResult: (sessionId: string, result: speechRecognizer.SpeechRecognitionResult): void => {
        // result.result 为识别文本；result.isLast 为是否最终结果
        this.cb?.onText(result.result, result.isLast);
      },
      onComplete: (sessionId: string, eventMessage: string): void => {
        this.listening = false;
        this.cb?.onComplete?.();
      },
      onError: (sessionId: string, errorCode: number, errorMessage: string): void => {
        this.listening = false;
        console.error(`[SpeechService] onError code=${errorCode} msg=${errorMessage}`);
        this.cb?.onError(errorCode, errorMessage);
      }
    };
    this.engine?.setListener(listener);
  }

  /** 开始录音识别（长按触发）。 */
  start(cb: SpeechCallbacks): void {
    if (!this.engine || this.listening) {
      return;
    }
    this.cb = cb;
    const audioInfo: speechRecognizer.AudioInfo = {
      audioType: 'pcm',
      sampleRate: 16000,
      soundChannel: 1,
      sampleBit: 16
    };
    const extraParams: Record<string, Object> = {
      'recognitionMode': 0, // 0 = 麦克风实时录音识别
      'vadBegin': 2000,
      'vadEnd': 3000,
      'maxAudioDuration': 20000
    };
    const startParams: speechRecognizer.StartParams = {
      sessionId: this.sessionId,
      audioInfo: audioInfo,
      extraParams: extraParams
    };
    try {
      this.engine.startListening(startParams);
      this.listening = true;
    } catch (e) {
      const err = e as BusinessError;
      this.cb?.onError(err.code, err.message);
    }
  }

  /** 松手：正常结束本次识别，触发最终结果。 */
  finish(): void {
    if (!this.engine || !this.listening) {
      return;
    }
    try {
      this.engine.finish(this.sessionId);
    } catch (e) {
      console.warn(`[SpeechService] finish 异常: ${JSON.stringify(e)}`);
    }
    this.listening = false;
  }

  /** 取消（丢弃本次结果）。 */
  cancel(): void {
    if (!this.engine || !this.listening) {
      return;
    }
    try {
      this.engine.cancel(this.sessionId);
    } catch (e) {
      console.warn(`[SpeechService] cancel 异常: ${JSON.stringify(e)}`);
    }
    this.listening = false;
  }

  /** 释放引擎（页面销毁时调用）。 */
  release(): void {
    this.cancel();
    try {
      this.engine?.shutdown();
    } catch (e) {
      console.warn(`[SpeechService] shutdown 异常: ${JSON.stringify(e)}`);
    }
    this.engine = undefined;
  }
}
