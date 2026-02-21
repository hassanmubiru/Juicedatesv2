import 'dart:io'; void main() { Platform.environment.forEach((k, v) { if (k.contains('PATH') || k.contains('INCLUDE')) print('$k: $v'); }); }
