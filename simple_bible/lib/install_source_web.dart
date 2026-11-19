import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'install_source.dart';

InstallSource createInstallSource() => _WebInstallSource();

class _WebInstallSource implements InstallSource {
  final _controller = StreamController<void>.broadcast();

  _WebInstallSource() {
    web.window.addEventListener(
        'install-changed', ((web.Event _) => _controller.add(null)).toJS);
  }

  JSObject get _window => web.window as JSObject;

  JSObject? get _stored {
    final v = _window.getProperty<JSAny?>('__installPrompt'.toJS);
    return v == null || v.isUndefinedOrNull ? null : v as JSObject;
  }

  @override
  InstallPlatform get platform {
    final ua = web.window.navigator.userAgent;
    // iPadOS Safari calls itself a Mac; a Mac with a touch screen is an iPad.
    final iPad = ua.contains('Macintosh') && web.window.navigator.maxTouchPoints > 1;
    if (RegExp(r'iPhone|iPad|iPod').hasMatch(ua) || iPad) {
      return InstallPlatform.ios;
    }
    if (ua.contains('Android')) return InstallPlatform.android;
    return InstallPlatform.other;
  }

  @override
  bool get installed {
    if (web.window.matchMedia('(display-mode: standalone)').matches) return true;
    if (web.window.matchMedia('(display-mode: fullscreen)').matches) return true;
    // Safari on iOS reports a home-screen launch only through this flag.
    final s = (web.window.navigator as JSObject)
        .getProperty<JSAny?>('standalone'.toJS);
    return s != null && s.isA<JSBoolean>() && (s as JSBoolean).toDart;
  }

  @override
  bool get canPrompt => _stored != null;

  @override
  Future<bool> prompt() async {
    final ev = _stored;
    if (ev == null) return false;
    try {
      ev.callMethod<JSAny?>('prompt'.toJS);
      final choice = await ev.getProperty<JSPromise<JSObject>>('userChoice'.toJS).toDart;
      final outcome = choice.getProperty<JSString>('outcome'.toJS).toDart;
      // One prompt per event; Chrome gives a new one if the reader declined.
      _window.setProperty('__installPrompt'.toJS, null);
      _controller.add(null);
      return outcome == 'accepted';
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<void> get changes => _controller.stream;
}
