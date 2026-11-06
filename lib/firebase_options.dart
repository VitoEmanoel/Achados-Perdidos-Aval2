import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA87IiVAhURWiEtk-0o3K8uvFXSHwHfUnA',
    appId: '1:894423709654:web:f18e78f5f44825d2c55677',
    messagingSenderId: '894423709654',
    projectId: 'achados-perdidos-uespi',
    authDomain: 'achados-perdidos-uespi.firebaseapp.com',
    storageBucket: 'achados-perdidos-uespi.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCgfhi2BxWaYtbv8ijXfULoK3qLJoAy314',
    appId: '1:894423709654:android:2ad66fba4d68f0ddc55677',
    messagingSenderId: '894423709654',
    projectId: 'achados-perdidos-uespi',
    storageBucket: 'achados-perdidos-uespi.firebasestorage.app',
  );
}
