# Guide : Consommer l'API Arena of Coders depuis Flutter

Ce document décrit comment utiliser l'API backend (NestJS) depuis une app Flutter pour **login**, **sign up** et **vérification d'email**.

---

## 1. Base URL et configuration

- **URL de base** : `http://<IP_OU_DOMAINE>:3000`  
  - Émulateur Android : `http://10.0.2.2:3000`  
  - Émulateur iOS : `http://localhost:3000`  
  - Appareil physique : `http://<IP_DE_TA_MACHINE>:3000` (ex. `http://192.168.1.10:3000`)
- **Pas de préfixe de chemin** : les routes commencent à la racine (ex. `/auth/signup`).
- **Swagger** : `http://<BASE_URL>/api` pour tester l'API dans le navigateur.

---

## 2. Authentification HTTP

- **Sign up** et **Sign in** : pas de header particulier, body JSON uniquement.
- **Routes protégées** (`/auth/me`, `/auth/profile`) : envoyer le JWT dans le header :
  ```http
  Authorization: Bearer <accessToken>
  ```

---

## 3. Endpoints

| Méthode | Route                      | Auth   | Description                    |
|---------|----------------------------|--------|--------------------------------|
| POST    | `/auth/signup`             | Non    | Inscription                    |
| POST    | `/auth/signin`             | Non    | Connexion                      |
| POST    | `/auth/verify-email`       | Non    | Vérifier email (code 6 chiffres) |
| POST    | `/auth/resend-verification`| Non    | Renvoyer le code               |
| GET     | `/auth/me`                 | Bearer | Profil utilisateur courant     |
| PATCH   | `/auth/profile`            | Bearer | Mise à jour du profil          |
