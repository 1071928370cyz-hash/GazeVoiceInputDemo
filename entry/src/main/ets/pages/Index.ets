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
  @State gazeNative: boolean = false;
  @State gazeStatus: string = 'Swing 订阅中…';  // Swing 注视订阅诊断文本
  @State motionStatus: string = '初始化...';  // motion 诊断文本
  // 按钮所在侧（真正的 @State，供 UI 直接读，避免 getter 不触发重渲）
  @State buttonSide: 'left' | 'right' = 'right';
  @State showResults: boolean = false;      // 仅在点按结束后展示检索结果

  private handDetector = new HandDetector();
  private gazeDetector = new GazeDetector();
  private speech = new SpeechService();
  private collapseTimer: number = -1;
  private halfWidthPx: number = 540;        // 屏幕半宽(px)，用于触摸落点判定左右

  // 重新计算按钮侧：motion 优先 -> 触摸兜底 -> 默认右手。每次相关来源变化都要调一次。
  private updateSide(): void {
    let side: 'left' | 'right';
    if (this.motionHand === 'left' || this.motionHand === 'right') {
      side = this.motionHand;
    } else if (this.touchHand !== '') {
      side = this.touchHand;
    } else {
      side = 'right';
    }
    if (side !== this.buttonSide) {
      this.buttonSide = side;
    }
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
      this.updateSide();
    }, (text: string) => {
      this.motionStatus = text;
    });

    this.gazeDetector.start((looking: boolean) => {
      this.lookingAtTop = looking;
    }, (native: boolean, text: string) => {
      this.gazeNative = native;
      this.gazeStatus = text;
    });

    await this.speech.init();
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

  // 单击切换：未录音 -> 开始；录音中 -> 结束
  private toggleVoice(): void {
    if (this.recording) {
      this.stopVoice();
    } else {
      this.startVoice();
    }
  }

  private startVoice(): void {
    this.recording = true;
    this.showResults = false; // 录音中先隐藏上一次的结果
    this.gazeDetector.manualSetLooking(true); // 录音时展开输入框，便于看到实时转写文本
    if (this.collapseTimer !== -1) {
      clearTimeout(this.collapseTimer);
    }
    this.speech.start({
      onText: (text: string, _isLast: boolean) => {
        this.inputText = text;
      },
      onComplete: () => {
        this.recording = false;
        this.resetCollapseTimer();
      },
      onError: (code: number, message: string) => {
        this.recording = false;
        console.error(`[Index] 语音识别错误 ${code}: ${message}`);
      }
    });
  }

  private stopVoice(): void {
    this.speech.finish();
    this.recording = false;
    this.showResults = this.inputText.length > 0; // 讲完点按结束后才弹出结果
    this.resetCollapseTimer();
  }

  // 页面级触摸：记录落点在左/右半屏，作为握持侧兜底
  private recordTouchSide(event: TouchEvent): void {
    const t = event.touches[0];
    if (t && event.type === TouchType.Down) {
      this.touchHand = t.windowX < this.halfWidthPx ? 'left' : 'right';
      this.updateSide();
    }
  }

  // 语音输入后的检索结果（占位素材：视频 / 图片 / 文本）
  @Builder
  searchResults() {
    Scroll() {
      Column() {
        // —— 视频 ——
        this.sectionTitle('视频')
        // 大视频卡
        Stack({ alignContent: Alignment.BottomStart }) {
          Column()
            .width('100%')
            .height(188)
            .borderRadius(12)
            .linearGradient({ angle: 135, colors: [['#3A6FF8', 0.0], ['#8AA9FF', 1.0]] })
          // 播放按钮
          Column() {
            Text('▶').fontSize(20).fontColor('#FFFFFF')
          }
          .width(48).height(48).borderRadius(24)
          .backgroundColor('#55000000')
          .justifyContent(FlexAlign.Center)
          .position({ x: '50%', y: '50%' })
          .markAnchor({ x: 24, y: 24 })
          // 标题条
          Text(`${this.inputText} · 高清完整版`)
            .fontSize(14).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .padding({ left: 12, bottom: 10, right: 12 })
        }
        .width('100%')
        .margin({ left: 16, right: 16 })

        // 两张小视频卡
        Row({ space: 10 }) {
          this.smallVideoCard('#FF7A45', '相关推荐 1')
          this.smallVideoCard('#36CFC9', '相关推荐 2')
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .margin({ top: 10 })

        // —— 图片 ——
        this.sectionTitle('图片')
        Scroll() {
          Row({ space: 8 }) {
            ForEach(['#FFD6A5', '#BDE0FE', '#CAFFBF', '#FFC6FF', '#A0C4FF'], (c: string) => {
              Column()
                .width(96).height(96).borderRadius(10).backgroundColor(c)
            })
          }
          .padding({ left: 16, right: 16 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')

        // —— 相关 ——
        this.sectionTitle('相关内容')
        ForEach([1, 2, 3], (i: number) => {
          Row() {
            Column()
              .width(64).height(64).borderRadius(8).backgroundColor('#EAECEF')
            Column() {
              Text(`${this.inputText}（结果 ${i}）`)
                .fontSize(15).fontColor('#222222').maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text('为你找到的相关图文 · 点击查看')
                .fontSize(12).fontColor('#999999').margin({ top: 6 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            .margin({ left: 12 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        })

        Column().height(24)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .width('100%')
    .margin({ top: 8 })
    .align(Alignment.Top)
  }

  @Builder
  sectionTitle(title: string) {
    Text(title)
      .fontSize(15).fontWeight(FontWeight.Bold).fontColor('#222222')
      .margin({ left: 16, top: 14, bottom: 8 })
  }

  @Builder
  smallVideoCard(color: string, label: string) {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Column().width('100%').height(96).borderRadius(10).backgroundColor(color)
        Text('▶').fontSize(16).fontColor('#FFFFFF')
      }
      .width('100%')
      Text(label)
        .fontSize(13).fontColor('#333333').maxLines(1)
        .margin({ top: 6 })
        .alignSelf(ItemAlign.Start)
    }
    .layoutWeight(1)
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
              Text('看这里语音搜索')
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
                    this.showResults = false;
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
        if (this.showResults && this.inputText.length > 0) {
          this.searchResults()
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
          Text(`实际侧: ${this.buttonSide === 'left' ? '左' : '右'}`).fontSize(11).fontColor('#FFFFFF')
            .margin({ left: 10 })
          Text(this.gazeNative ? '注视:Swing' : '注视:手动').fontSize(11).fontColor('#FFD60A')
            .margin({ left: 10 })
        }
        Text(`motion: ${this.motionStatus}　gaze: ${this.gazeStatus}`).fontSize(10).fontColor('#FFD60A')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .backgroundColor('#99000000')
      .borderRadius(12)
      .margin({ top: 66, left: 16 })

      // ===== 握持手侧浮出的语音按钮 =====
      // 注意：if 条件必须“直接读 @State”，不能用 getter，否则 ArkUI 不登记依赖、不会重渲。
      if (this.lookingAtTop || this.motionHand === 'left' || this.motionHand === 'right') {
        Column() {
          VoiceButton({
            recording: this.recording,
            onToggle: () => this.toggleVoice()
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(this.buttonSide === 'left' ? HorizontalAlign.Start : HorizontalAlign.End)
        .padding({ left: 24, right: 24 })
        // None：浮层自身不接收点击（空白处穿透到下面内容），但子按钮照常可点
        .hitTestBehavior(HitTestMode.None)
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
