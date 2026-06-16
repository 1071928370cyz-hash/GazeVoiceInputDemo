/**
 * TranslateService —— 文本翻译（中译英）
 *
 * ⚠️ HarmonyOS 无可核实的原生文本翻译 API（Core Speech Kit 只有 ASR/TTS）。
 * 这里用免费、免注册的公共接口 MyMemory 跑通演示：
 *   GET https://api.mymemory.translated.net/get?q=<text>&langpair=zh-CN|en
 *   返回 JSON: { responseData: { translatedText: "..." } }
 *
 * 需要 ohos.permission.INTERNET（普通权限，安装即授予，无需弹窗）。
 * 公共接口有频率/稳定性限制，仅供 demo；要商用请换成带 key 的百度/有道，
 * 只需替换本文件 translate() 内的请求即可，调用方无需改动。
 */
import { http } from '@kit.NetworkKit';

interface MyMemoryData {
  translatedText: string;
}

interface MyMemoryResp {
  responseStatus: number;
  responseData: MyMemoryData;
}

export class TranslateService {
  /**
   * 翻译文本。失败时原样返回输入，保证调用方拿到的永远是可显示文本。
   * @param text     待翻译文本
   * @param langpair 语言对，默认中译英 'zh-CN|en'
   */
  async translate(text: string, langpair: string = 'zh-CN|en'): Promise<string> {
    const trimmed = text.trim();
    if (trimmed.length === 0) {
      return text;
    }

    const url = `https://api.mymemory.translated.net/get?q=${encodeURIComponent(trimmed)}&langpair=${encodeURIComponent(langpair)}`;
    const request = http.createHttp();
    try {
      const resp = await request.request(url, {
        method: http.RequestMethod.GET,
        header: { 'Content-Type': 'application/json' } as Record<string, string>,
        connectTimeout: 8000,
        readTimeout: 8000
      });

      if (resp.responseCode === 200 && typeof resp.result === 'string') {
        const data = JSON.parse(resp.result as string) as MyMemoryResp;
        const out = data.responseData?.translatedText;
        if (out !== undefined && out.length > 0) {
          return out;
        }
      }
      console.warn(`[TranslateService] 翻译失败 code=${resp.responseCode}`);
      return text;
    } catch (e) {
      console.error(`[TranslateService] 请求异常: ${JSON.stringify(e)}`);
      return text;
    } finally {
      request.destroy();
    }
  }
}
