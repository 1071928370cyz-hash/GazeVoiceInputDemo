/**
 * VoiceButton —— 握持手侧的语音输入按钮（Typeless 风格）
 *
 * 交互：
 *   - 单击一次 -> 开始语音转写；再单击一次 -> 结束收音。
 *   - 录音中按钮变红并在图标处显示「声波」动效，提示正在听。
 */
@Component
export struct VoiceButton {
  @Prop @Watch('onRecordingChange') recording: boolean;
  onToggle: () => void = () => {};

  // 声波条高度（px），录音时定时随机刷新形成跳动效果
  @State bars: number[] = [10, 18, 26, 18, 10];
  private animTimer: number = -1;
  private readonly idleBars: number[] = [10, 18, 26, 18, 10];

  onRecordingChange(): void {
    if (this.recording) {
      this.startAnim();
    } else {
      this.stopAnim();
    }
  }

  private startAnim(): void {
    if (this.animTimer !== -1) {
      return;
    }
    this.animTimer = setInterval(() => {
      this.bars = this.bars.map(() => 6 + Math.round(Math.random() * 26));
    }, 160);
  }

  private stopAnim(): void {
    if (this.animTimer !== -1) {
      clearInterval(this.animTimer);
      this.animTimer = -1;
    }
    this.bars = this.idleBars.slice();
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

      Text(this.recording ? '点按 结束' : '点按 说话')
        .fontSize(12)
        .fontColor('#888888')
        .margin({ top: 6 })
    }
    .onClick(() => this.onToggle())
  }
}
