import 'dart:convert';

/// Décodage JSON hors du thread UI (à utiliser avec compute()).
dynamic decodeJsonIsolate(String body) => jsonDecode(body);
