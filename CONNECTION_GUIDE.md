# 🚀 Guide de Connexion Flutter ↔ NestJS Backend

Ce guide vous aide à connecter votre application Flutter à votre backend NestJS.

## ✅ Modifications Apportées

### Backend NestJS
1. **Configuration CORS ajoutée** dans `main.ts`
2. **Port par défaut changé** de 3000 → 4000
3. **Headers autorisés** pour les requêtes mobiles

### Application Flutter
1. **Configuration dynamique d'URL** basée sur la plateforme
2. **Service de test de connectivité** 
3. **Gestion d'erreurs améliorée**
4. **Écran de diagnostic de connexion**

## 🔧 Configuration Requise

### 1. Démarrer le Backend
```bash
cd tunisianarenaofcoders-web-backend
npm install
npm run start
```

Le backend devrait démarrer sur `http://localhost:4000`

### 2. Vérifier le Backend
Testez dans un navigateur : `http://localhost:4000/api`
Vous devriez voir la documentation Swagger.

## 📱 Configuration Flutter

### URLs Automatiquement Configurées

- **Émulateur Android** : `http://10.0.2.2:4000`
- **Simulateur iOS** : `http://localhost:4000`
- **Appareil Physique** : Voir configuration ci-dessous

### Configuration pour Appareil Physique

1. **Trouvez votre adresse IP** :
   - Windows : `ipconfig` dans cmd
   - Mac/Linux : `ifconfig` dans terminal
   - Cherchez l'IP locale (ex: 192.168.100.87)

2. **Modifiez la configuration** :
   Ouvrez `lib/config/api_config.dart` et changez :
   ```dart
   static const String _defaultIpAddress = '192.168.100.87'; // Votre IP
   ```

3. **Assurez-vous que le firewall autorise** le port 4000

## 🧪 Test de Connexion

### Option 1: Écran de Test Intégré
Ajoutez cet import dans votre écran principal :
```dart
import 'screens/connection_test_screen.dart';
```

Puis ajoutez un bouton pour naviguer vers `ConnectionTestScreen()`.

### Option 2: Test Manuel
Dans votre terminal Flutter :
```dart
import 'services/connectivity_service.dart';

final connectivity = ConnectivityService();
final result = await connectivity.testBackendConnection();
print(result);
```

## 🔍 Diagnostic des Problèmes

### Erreur: "Failed host lookup"
- **Émulateur Android** : Utilisez `10.0.2.2` au lieu de `localhost`
- **Appareil physique** : Vérifiez votre IP locale et la configuration du firewall

### Erreur: "Connection refused"
- Vérifiez que le backend NestJS est démarré
- Confirmez qu'il fonctionne sur le port 4000
- Testez `http://localhost:4000/api` dans un navigateur

### Erreur: "TimeoutException"
- Vérifiez votre connexion internet
- Pour appareil physique : vérifiez que vous êtes sur le même réseau WiFi

### Erreur CORS
- Les modifications CORS ont été appliquées au backend
- Redémarrez le backend après les modifications

## 📋 Checklist de Vérification

- [ ] Backend NestJS démarré sur port 4000
- [ ] `http://localhost:4000/api` accessible dans le navigateur
- [ ] Configuration IP correcte pour appareil physique
- [ ] Firewall autorisant le port 4000
- [ ] Appareil et PC sur le même réseau WiFi

## 🛠 Commandes Utiles

### Backend
```bash
# Démarrer en mode développement
npm run start:dev

# Vérifier le port utilisé
netstat -an | findstr :4000
```

### Flutter
```bash
# Installer les dépendances
flutter pub get

# Lancer sur émulateur Android
flutter run

# Lancer sur simulateur iOS
flutter run -d ios

# Voir les devices disponibles
flutter devices
```

## 📱 Tests par Plateforme

### Émulateur Android
1. Démarrez l'émulateur
2. `flutter run`
3. L'app utilise automatiquement `http://10.0.2.2:4000`

### Simulateur iOS
1. Démarrez le simulateur
2. `flutter run -d ios`
3. L'app utilise automatiquement `http://localhost:4000`

### Appareil Physique
1. Connectez l'appareil en USB/WiFi
2. Modifiez l'IP dans `api_config.dart`
3. `flutter run`
4. L'app utilise votre IP personnalisée

## ⚡ Fonctionnalités Disponibles

### API Endpoints Testés
- ✅ `/auth/signup` - Inscription
- ✅ `/auth/signin` - Connexion
- ✅ `/auth/verify-email` - Vérification email
- ✅ `/auth/me` - Profil utilisateur
- ✅ `/user/leaderboard` - Classement
- ✅ `/competitions` - Compétitions
- ✅ `/notifications` - Notifications

### Fonctionnalités de Sécurité
- 🔐 JWT Token stockage sécurisé (flutter_secure_storage)
- 🔄 Refresh automatique des tokens expirés
- 🚫 Gestion des erreurs 401/403
- 📱 Headers d'authentification automatiques

## 🆘 Support

Si vous rencontrez des problèmes :
1. Utilisez l'écran de test de connexion intégré
2. Vérifiez les logs de la console Flutter
3. Vérifiez les logs du backend NestJS
4. Consultez la section diagnostic ci-dessus

## 🔗 Liens Utiles
- [Documentation NestJS CORS](https://docs.nestjs.com/security/cors)
- [Flutter HTTP Package](https://pub.dev/packages/http)
- [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage)