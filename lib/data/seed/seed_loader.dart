import 'package:flutter/services.dart' show rootBundle;

class SeedLoader {
  Future<String> allJson() => rootBundle.loadString('assets/seed/all.json');
  Future<String> siglasJson() => rootBundle.loadString('assets/data/siglas_entidades.json');
}
