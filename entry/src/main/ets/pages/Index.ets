/**
 * Index —— 仿华为视频搜索页演示
 *
 * 理想流程（对齐设计稿）：
 *   1) 注视/点击顶部“搜索”图标 -> 拉起只读输入框 + 语音按钮（不弹软键盘）
 *   2) 语音按钮出现在握持手一侧：motion 判定优先，拿不到则用“最近触摸落在左/右半屏”兜底，再不行默认右手
 *   3) 长按语音按钮开始转写；上滑到“取消输入”删除，下滑到“发送”确认
 *   4) 松手回到单个按钮；一段时间未注视 -> 输入框与按钮收起
 *
 * 说明：左右手不再作为“是否显示按钮”的开关，仅决定按钮在哪一侧，
 * 因此即使真机 motion 返回 unknown，按钮也一定会浮出来。
 */
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { display } from '@kit.ArkUI';
import { HandDetector, Hand } from '../services/HandDetector';
import { GazeDetector } from '../services/GazeDetector';
import { SpeechService } from '../services/SpeechService';
import { VoiceButton } from '../components/VoiceButton';

@Entry
@Component
struct Index {
  @State inputText: string = '';
  @State motionHand: Hand = 'unknown';      // motion 子模块判定
  @State touchHand: 'left' | 'right' | '' = ''; // 触摸落点兜底
  @State lookingAtTop: boolean = false;     // 是否处于“注视/激活搜索”状态
  @State recording: boolean = false;
  @State zone: string = 'record';           // 录音中的选区：record / cancel / send
  @State gazeNative: boolean = false;
  @State motionStatus: string = '初始化...';  // motion 诊断文本

  private handDetector = new HandDetector();
  private gazeDetector = new GazeDetector();
  private speech = new SpeechService();
  private collapseTimer: number = -1;
  private halfWidthPx: number = 540;        // 屏幕半宽(px)，用于触摸落点判定左右

  // 实际采用的握持侧：motion 优先 -> 触摸兜底 -> 默认右手
  private get effHand(): 'left' | 'right' {
    if (this.motionHand === 'left' || this.motionHand === 'right') {
      return this.motionHand;
    }
    if (this.touchHand !== '') {
      return this.touchHand;
    }
    return 'right';
  }

  private get showVoiceButton(): boolean {
    return this.lookingAtTop;
  }

  async aboutToAppear(): Promise<void> {
    // 关键：必须先 await 权限授予，再订阅 motion.on，否则订阅时权限未到位会失败(201)
    await this.requestPermissions();

    try {
      this.halfWidthPx = display.getDefaultDisplaySync().width / 2;
    } catch (e) {
      console.warn(`[Index] 获取屏幕宽度失败: ${JSON.stringify(e)}`);
    }

    this.handDetector.start((h: Hand) => {
      this.motionHand = h;
    }, (text: string) => {
      this.motionStatus = text;
    });

    this.gazeDetector.start((looking: boolean) => {
      this.lookingAtTop = looking;
    });
    this.gazeNative = this.gazeDetector.usingNative;

    this.speech.init();
  }

  aboutToDisappear(): void {
    if (this.collapseTimer !== -1) {
      clearTimeout(this.collapseTimer);
    }
    this.handDetector.stop();
    this.gazeDetector.stop();
    this.speech.release();
  }

  private async requestPermissions(): Promise<void> {
    const perms: Permissions[] = ['ohos.permission.MICROPHONE', 'ohos.permission.DETECT_GESTURE'];
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const context = getContext(this) as common.UIAbilityContext;
      await atManager.requestPermissionsFromUser(context, perms);
    } catch (e) {
      console.error(`[Index] 申请权限失败: ${JSON.stringify(e)}`);
    }
  }

  // 激活搜索（模拟“注视顶部输入框”）。真原生注视接入后由 GazeDetector 回调驱动。
  private activateGaze(): void {
    this.gazeDetector.manualSetLooking(true);
    this.resetCollapseTimer();
  }

  // 一段时间未交互 -> 收起（模拟“未注视”）
  private resetCollapseTimer(): void {
    if (this.collapseTimer !== -1) {
      clearTimeout(this.collapseTimer);
    }
    this.collapseTimer = setTimeout(() => {
      if (!this.recording) {
        this.gazeDetector.manualSetLooking(false);
      }
    }, 6000);
  }

  private startVoice(): void {
    this.recording = true;
    this.zone = 'record';
    if (this.collapseTimer !== -1) {
      clearTimeout(this.collapseTimer);
    }
    this.speech.start({
      onText: (text: string, _isLast: boolean) => {
        this.inputText = text;
      },
      onComplete: () => {
        this.recording = false;
      },
      onError: (code: number, message: string) => {
        this.recording = false;
        console.error(`[Index] 语音识别错误 ${code}: ${message}`);
      }
    });
  }

  // commit=true 确认（保留转写），false 取消（删除转写）
  private endVoice(commit: boolean): void {
    if (commit) {
      this.speech.finish();
    } else {
      this.speech.cancel();
      this.inputText = '';
    }
    this.recording = false;
    this.zone = 'record';
    this.resetCollapseTimer();
  }

  // 页面级触摸：记录落点在左/右半屏，作为握持侧兜底
  private recordTouchSide(event: TouchEvent): void {
    const t = event.touches[0];
    if (t && event.type === TouchType.Down) {
      this.touchHand = t.windowX < this.halfWidthPx ? 'left' : 'right';
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // ===== 页面主体 =====
      Column() {
        // 顶部栏
        Row() {
          if (!this.lookingAtTop) {
            Text('首页')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#222222')
            Blank()
          }

          // 搜索容器：折叠态=圆形图标，注视态=展开的只读输入框
          Row() {
            Image($r('sys.media.ohos_ic_public_search_filled'))
              .width(18)
              .height(18)
              .fillColor('#999999')

            if (!this.lookingAtTop) {
              Text('点这里语音搜索')
                .fontSize(13)
                .fontColor('#999999')
                .margin({ left: 6 })
            }

            if (this.lookingAtTop) {
              Text(this.inputText.length > 0 ? this.inputText : '搜索片名、演员或剧情')
                .fontSize(15)
                .fontColor(this.inputText.length > 0 ? '#222222' : '#999999')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
                .margin({ left: 8 })

              if (this.inputText.length > 0) {
                Image($r('sys.media.ohos_ic_public_cancel'))
                  .width(16)
                  .height(16)
                  .fillColor('#999999')
                  .onClick(() => {
                    this.inputText = '';
                  })
              }
            }
          }
          .height(40)
          .padding({ left: 14, right: 14 })
          .borderRadius(20)
          .backgroundColor(this.lookingAtTop ? '#FFFFFF' : '#F2F3F5')
          .border(this.lookingAtTop
            ? { width: 1.5, color: '#007DFF' }
            : { width: 0, color: Color.Transparent })
          .layoutWeight(this.lookingAtTop ? 1 : 0)
          .onClick(() => this.activateGaze())
          .animation({ duration: 200, curve: Curve.EaseOut })
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .margin({ top: 10 })

        // 内容区
        if (this.inputText.length > 0) {
          // 搜索结果占位
          Column() {
            ForEach([1, 2, 3, 4], (i: number) => {
              Row() {
                Column()
                  .width(48).height(64).borderRadius(6).backgroundColor('#EAECEF')
                Column() {
                  Text(`${this.inputText}`)
                    .fontSize(15).fontColor('#222222').maxLines(1)
                  Row().width('40%').height(11).borderRadius(4)
                    .backgroundColor('#F0F1F3').margin({ top: 8 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .margin({ left: 12 })
              }
              .width('100%').padding(12)
            })
          }
          .margin({ top: 8 })
          .layoutWeight(1)
        } else {
          // 首页内容占位
          Column() {
            Column()
              .width('92%').height(150).borderRadius(12)
              .backgroundColor('#F2F3F5').margin({ top: 12 })
            ForEach([1, 2, 3], (i: number) => {
              Row() {
                Column().width(56).height(56).borderRadius(8).backgroundColor('#EAECEF')
                Column() {
                  Row().width('70%').height(14).borderRadius(4).backgroundColor('#EAECEF')
                  Row().width('45%').height(12).borderRadius(4)
                    .backgroundColor('#F0F1F3').margin({ top: 8 })
                }
                .alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 12 })
              }
              .width('100%').padding(12)
            })
          }
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')

      // ===== 演示状态条 =====
      Column() {
        Row() {
          Text(`motion: ${this.handLabel(this.motionHand)}`).fontSize(11).fontColor('#FFFFFF')
          Text(`实际侧: ${this.effHand === 'left' ? '左' : '右'}`).fontSize(11).fontColor('#FFFFFF')
            .margin({ left: 10 })
          Text(this.gazeNative ? '注视:原生' : '注视:手动').fontSize(11).fontColor('#FFD60A')
            .margin({ left: 10 })
        }
        Text(`motion状态: ${this.motionStatus}`).fontSize(10).fontColor('#FFD60A')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .backgroundColor('#99000000')
      .borderRadius(12)
      .margin({ top: 66, left: 16 })

      // ===== 握持手侧浮出的语音按钮 =====
      if (this.showVoiceButton) {
        Column() {
          VoiceButton({
            recording: this.recording,
            zone: this.zone,
            onStart: () => this.startVoice(),
            onMove: (z: string) => { this.zone = z; },
            onEnd: (commit: boolean) => this.endVoice(commit)
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(this.effHand === 'left' ? HorizontalAlign.Start : HorizontalAlign.End)
        .padding({ left: 24, right: 24 })
        .hitTestBehavior(HitTestMode.Transparent)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
    .onTouch((e: TouchEvent) => this.recordTouchSide(e))
  }

  private handLabel(h: Hand): string {
    if (h === 'left') {
      return '左手';
    }
    if (h === 'right') {
      return '右手';
    }
    return '未识别';
  }
}
