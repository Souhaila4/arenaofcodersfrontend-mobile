class Env {
  // Token géré côté backend dans .env — ne jamais mettre une vraie clé ici.
  // Les appels HuggingFace sont proxifiés via NestJS pour éviter l'exposition du token.
  static const String huggingFaceToken = '';
}
