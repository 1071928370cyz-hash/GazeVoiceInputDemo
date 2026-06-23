/**
 * SpeechService —— 语音录入 + 实时转写（连续录音版）
 *
 * 基于 Core Speech Kit 的 speechRecognizer（端侧/离线 ASR）。
 *
 * 关键点（修复“录音中自己跳回未录音态”）：
 *   speechRecognizer 默认会在静音(vadEnd)或达到 maxAudioDuration 时自动结束本次识别，
 *   触发 onComplete。对“单击开始 / 单击结束”的交互来说，这会让按钮在你停顿时就自己结束。
 *   所以这里：
 *     1) 把 vadEnd 调到与 maxAudioDuration 同等大，避免停顿被判定为结束；
 *     2) 用 active 标记“用户是否仍想录音”。引擎若在 active 期间自行结束，就自动续录，
 *        并把已确定文本累计起来，直到用户调用 finish()/cancel()。
 */
import { speechRecognizer } from '@kit.CoreSpeechKit';
import { BusinessError } from '@kit.BasicServicesKit';

export interface SpeechCallbacks {
  onText: (text: string, isLast: boolean) => void;
  onError: (code: number, message: string) => void;
  onComplete?: () => void;
}

export class SpeechService {
  private engine?: speechRecognizer.SpeechRecognitionEngine;
  private readonly sessionId: string = 'gaze_voice_session';
  private cb?: SpeechCallbacks;
  private listening: boolean = false;

  private active: boolean = false;       // 用户是否仍想录音
  private finalized: string = '';        // 已确定的累计文本（跨子会话）
  private partial: string = '';          // 当前子会话的临时文本
  private restartCount: number = 0;      // 连续空续录计数，防止死循环
  private readonly maxRestart: number = 4;

  get isListening(): boolean {
    return this.listening;
  }

  async init(): Promise<boolean> {
    if (this.engine) {
      return true;
    }
    const extraParams: Record<string, Object> = { 'locate': 'CN', 'recognizerMode': 'short' };
    const params: speechRecognizer.CreateEngineParams = {
      language: 'zh-CN',
      online: 1,
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
        this.partial = result.result;
        if (this.partial.length > 0) {
          this.restartCount = 0; // 有实际结果，重置续录计数
        }
        this.cb?.onText(this.finalized + this.partial, false);
        if (result.isLast) {
          this.finalized += this.partial;
          this.partial = '';
        }
      },
      onComplete: (sessionId: string, eventMessage: string): void => {
        // 引擎结束了本次子会话。用户若仍想录音，则自动续录。
        if (this.active) {
          this.restartCount++;
          if (this.restartCount <= this.maxRestart) {
            this.beginSession();
            return;
          }
          console.warn('[SpeechService] 连续续录超限，停止');
          this.active = false;
        }
        this.listening = false;
        this.cb?.onComplete?.();
      },
      onError: (sessionId: string, errorCode: number, errorMessage: string): void => {
        console.error(`[SpeechService] onError code=${errorCode} msg=${errorMessage}`);
        // 续录期间的“无语音/超时”类错误也尝试续录，受 maxRestart 保护
        if (this.active) {
          this.restartCount++;
          if (this.restartCount <= this.maxRestart) {
            this.beginSession();
            return;
          }
          this.active = false;
        }
        this.listening = false;
        this.cb?.onError(errorCode, errorMessage);
      }
    };
    this.engine?.setListener(listener);
  }

  /** 开始（单击触发）。会持续录音直到 finish()/cancel()。引擎未就绪时懒加载。 */
  async start(cb: SpeechCallbacks): Promise<void> {
    this.cb = cb;
    if (!this.engine) {
      const ok = await this.init();
      if (!ok) {
        this.cb?.onError(-1, '语音引擎初始化失败');
        return;
      }
    }
    if (this.listening) {
      return;
    }
    this.active = true;
    this.finalized = '';
    this.partial = '';
    this.restartCount = 0;
    this.listening = true;
    this.beginSession();
  }

  // 启动一段识别子会话。vadEnd 设大，避免停顿被判定为结束。
  private beginSession(): void {
    if (!this.engine) {
      return;
    }
    const audioInfo: speechRecognizer.AudioInfo = {
      audioType: 'pcm',
      sampleRate: 16000,
      soundChannel: 1,
      sampleBit: 16
    };
    const extraParams: Record<string, Object> = {
      'recognitionMode': 0,
      'vadBegin': 2000,
      'vadEnd': 60000,          // 静音容忍调到最大，停顿不再自动结束
      'maxAudioDuration': 60000 // 端侧短语音上限
    };
    const startParams: speechRecognizer.StartParams = {
      sessionId: this.sessionId,
      audioInfo: audioInfo,
      extraParams: extraParams
    };
    try {
      this.engine.startListening(startParams);
    } catch (e) {
      const err = e as BusinessError;
      this.active = false;
      this.listening = false;
      this.cb?.onError(err.code, err.message);
    }
  }

  /** 单击结束：停止续录并结束识别，保留已转写文本。 */
  finish(): void {
    this.active = false;
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

  /** 取消：丢弃本次结果。 */
  cancel(): void {
    this.active = false;
    this.finalized = '';
    this.partial = '';
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
