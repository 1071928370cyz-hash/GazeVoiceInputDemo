/**
 * VoiceButton —— 握持手侧的“长按语音输入”按钮
 *
 * 交互：
 *   - 按住（手指按下）开始录音转写；
 *   - 录音中浮出竖向操作条：上=取消输入，中=转录中，下=翻译；
 *   - 手指上滑越过阈值 -> 选中“取消输入”，下滑越过阈值 -> 选中“翻译”；
 *   - 松手回调最终所在区：'cancel' 撤回 / 'record' 普通转写 / 'translate' 先翻译再转录。
 *
 * 用 onTouch 自行跟踪手指位移，避免依赖软键盘 / 长按手势的局限。
 */
@Component
export struct VoiceButton {
  @Prop recording: boolean;
  @Prop zone: string; // 'record' | 'cancel' | 'translate'（由父组件持有，便于联动）
  onStart: () => void = () => {};
  onMove: (zone: string) => void = (_z: string) => {};
  onEnd: (zone: string) => void = (_z: string) => {};

  private startY: number = 0;
  private readonly threshold: number = 48; // 触发上/下滑的位移阈值(px)

  private currentZone(dy: number): string {
    if (dy < -this.threshold) {
      return 'cancel';
    }
    if (dy > this.threshold) {
      return 'translate';
    }
    return 'record';
  }

  private handleTouch(event: TouchEvent): void {
    const t = event.touches[0];
    if (!t) {
      return;
    }
    const y = t.windowY;
    switch (event.type) {
      case TouchType.Down:
        this.startY = y;
        this.onStart();
        this.onMove('record');
        break;
      case TouchType.Move:
        this.onMove(this.currentZone(y - this.startY));
        break;
      case TouchType.Up:
      case TouchType.Cancel:
        this.onEnd(this.currentZone(y - this.startY));
        break;
      default:
        break;
    }
  }

  @Builder
  zoneDot(label: string, glyph: string, active: boolean, activeColor: string) {
    Column() {
      Stack() {
        Circle()
          .width(active ? 60 : 48)
          .height(active ? 60 : 48)
          .fill(active ? activeColor : '#66FFFFFF')
        Text(glyph)
          .fontSize(active ? 24 : 20)
          .fontColor(Color.White)
      }
      .animation({ duration: 120, curve: Curve.EaseOut })

      Text(label)
        .fontSize(11)
        .fontColor(Color.White)
        .margin({ top: 4 })
    }
    .margin({ top: 6, bottom: 6 })
  }

  build() {
    Column() {
      if (this.recording) {
        // 录音中：竖向操作条（上 取消 / 中 转录 / 下 发送）
        Column() {
          this.zoneDot('取消输入', '✕', this.zone === 'cancel', '#FF3B30')
          this.zoneDot('转录中', '🎙', this.zone === 'record', '#007DFF')
          this.zoneDot('翻译', '译', this.zone === 'translate', '#FF9F0A')
        }
        .padding({ top: 10, bottom: 10, left: 8, right: 8 })
        .borderRadius(40)
        .backgroundColor('#CC1F1F1F')
        .shadow({ radius: 20, color: '#40000000', offsetY: 6 })
      } else {
        // 默认：单个语音按钮
        Column() {
          Image($r('sys.media.ohos_ic_public_voice'))
            .width(32)
            .height(32)
            .fillColor(Color.White)
        }
        .width(64)
        .height(64)
        .borderRadius(32)
        .backgroundColor('#007DFF')
        .justifyContent(FlexAlign.Center)
        .shadow({ radius: 16, color: '#33000000', offsetY: 4 })

        Text('长按 说话')
          .fontSize(12)
          .fontColor('#888888')
          .margin({ top: 6 })
      }
    }
    .onTouch((e: TouchEvent) => this.handleTouch(e))
  }
}
