
bool _hasTestIframe = false;
String _pointerEventsStyle = '';

void toggleIframePointerEvents(bool disable) {
  if (_hasTestIframe) {
    _pointerEventsStyle = disable ? 'none' : '';
  }
}

void debugAppendTestIframe() {
  _hasTestIframe = true;
  _pointerEventsStyle = '';
}

String? debugGetIframePointerEvents() {
  return _hasTestIframe ? _pointerEventsStyle : null;
}

void debugRemoveTestIframe() {
  _hasTestIframe = false;
  _pointerEventsStyle = '';
}
