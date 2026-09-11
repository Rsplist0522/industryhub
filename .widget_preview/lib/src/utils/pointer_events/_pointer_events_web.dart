
import 'package:web/web.dart' as web;

void toggleIframePointerEvents(bool disable) {
  final iframes = web.document.querySelectorAll('iframe');
  for (int i = 0; i < iframes.length; i++) {
    final iframe = iframes.item(i) as web.HTMLElement;
    iframe.style.pointerEvents = disable ? 'none' : '';
  }
}

web.HTMLIFrameElement? _testIframe;

void debugAppendTestIframe() {
  _testIframe = web.HTMLIFrameElement();
  web.document.body!.appendChild(_testIframe!);
}

String? debugGetIframePointerEvents() {
  return _testIframe?.style.pointerEvents;
}

void debugRemoveTestIframe() {
  _testIframe?.remove();
  _testIframe = null;
}
