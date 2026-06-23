/**
 * VoiceButton —— 握持手侧的语音输入按钮（Typeless 风格）
 *
 * 交互：
 *   - 单击一次 -> 开始语音转写；再单击一次 -> 结束收音。
 *   - 录音中按钮变红，图标处显示「声波条」动效，外圈再叠一层轻微「声浪」光环。
 */
@Component
export struct VoiceButton {
  @Prop @Watch('onRecordingChange') recording: boolean;
  onToggle: () => void = () => {};

  // 声波条高度（px），录音时定时随机刷新形成跳动效果
  @State bars: number[] = [10, 18, 26, 18, 10];
  // 声浪光环：缩放与透明度，录音时来回脉动
  @State haloScale: number = 1;
  @State haloOpacity: number = 0;

  private barsTimer: number = -1;
  private haloTimer: number = -1;
  private readonly idleBars: number[] = [10, 18, 26, 18, 10];

  onRecordingChange(): void {
    if (this.recording) {
      this.startAnim();
    } else {
      this.stopAnim();
    }
  }

  private startAnim(): void {
    // 声波条
    if (this.barsTimer === -1) {
      this.barsTimer = setInterval(() => {
        this.bars = this.bars.map(() => 6 + Math.round(Math.random() * 26));
      }, 160);
    }
    // 声浪光环：在“小而清晰”与“大而透明”两态间来回，配合 animation 形成扩散脉动
    if (this.haloTimer === -1) {
      this.haloScale = 1;
      this.haloOpacity = 0.28;
      this.haloTimer = setInterval(() => {
        const expanded: boolean = this.haloScale > 1;
        this.haloScale = expanded ? 1 : 1.45;
        this.haloOpacity = expanded ? 0.28 : 0;
      }, 900);
    }
  }

  private stopAnim(): void {
    if (this.barsTimer !== -1) {
      clearInterval(this.barsTimer);
      this.barsTimer = -1;
    }
    if (this.haloTimer !== -1) {
      clearInterval(this.haloTimer);
      this.haloTimer = -1;
    }
    this.bars = this.idleBars.slice();
    this.haloScale = 1;
    this.haloOpacity = 0;
  }

  aboutToDisappear(): void {
    this.stopAnim();
  }

  @Builder
  waveform() {
    Row({ space: 3 }) {
      ForEach(this.bars, (h: number, i: number) => {
        Column()
          .width(4)
          .height(h)
          .borderRadius(2)
          .backgroundColor(Color.White)
          .animation({ duration: 150, curve: Curve.EaseInOut })
      }, (h: number, i: number) => i.toString())
    }
    .height(36)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      Stack() {
        // 轻微声浪光环（录音时）
        if (this.recording) {
          Circle()
            .width(76)
            .height(76)
            .fill('#FF3B30')
            .scale({ x: this.haloScale, y: this.haloScale })
            .opacity(this.haloOpacity)
            .animation({ duration: 850, curve: Curve.EaseOut })
        }

        // 按钮主体
        Stack() {
          if (this.recording) {
            this.waveform()
          } else {
            Image($r('sys.media.ohos_ic_public_voice'))
              .width(32)
              .height(32)
              .fillColor(Color.White)
          }
        }
        .width(this.recording ? 76 : 64)
        .height(this.recording ? 76 : 64)
        .borderRadius(this.recording ? 38 : 32)
        .backgroundColor(this.recording ? '#FF3B30' : '#007DFF')
        .shadow({ radius: 16, color: '#33000000', offsetY: 4 })
        .animation({ duration: 150, curve: Curve.EaseOut })
      }
      .width(112)
      .height(112)

      Text(this.recording ? '点按 结束' : '点按 说话')
        .fontSize(12)
        .fontColor('#888888')
        .margin({ top: 2 })
    }
    .onClick(() => this.onToggle())
  }
}
