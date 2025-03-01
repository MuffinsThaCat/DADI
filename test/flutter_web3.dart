// This file provides conditional imports for flutter_web3
// It will import the real package on web platforms and the stub on non-web platforms

export 'flutter_web3_stub.dart'
    if (dart.library.html) 'package:flutter_web3/flutter_web3.dart';
