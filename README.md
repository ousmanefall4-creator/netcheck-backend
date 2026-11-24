# NetCheck Backend — Sonde de Diagnostic Réseau (API Dart)

API REST légère et haute performance développée en **Dart** (`shelf` + `dart:io`) servant de sonde réseau bas niveau pour l'application **NetCheck Suite** (Flutter Web).

Ce backend contourne les limitations de sécurité des navigateurs web (restrictions CORS, blocage des sockets TCP bruts et accès restreint aux certificats X.509) afin d'offrir de véritables diagnostics réseau depuis une interface web.

---

## Architecture du Projet

```text
┌─────────────────────────┐         HTTP / JSON         ┌───────────────────────────┐
│   NetCheck Frontend     │ ──────────────────────────► │   NetCheck Backend        │
│   (Flutter Web)         │ ◄────────────────────────── │   (Dart / Shelf / Docker) │
└─────────────────────────┘                             └─────────────┬─────────────┘
                                                                      │
                                                    ┌─────────────────┼─────────────────┐
                                                    ▼                 ▼                 ▼
                                               Sonde HTTP       Sockets TCP      Handshakes TLS
                                              (Sans CORS)      (Ports 22..443)  (Certificats SSL)
```

* **Stack 100 % Dart :** Partage d'un écosystème unique entre le frontend Flutter et le serveur backend.
* **Zéro dépendance native lourde :** Compilé en binaire natif autonome via `dart compile exe` dans une image Docker minimale (`debian:bookworm-slim`).

---

## Endpoints de l'API

| Méthode | Route | Description | Corps JSON attendu |
| :--- | :--- | :--- | :--- |
| `GET` | `/health` | Vérifie l'état de disponibilité de la sonde | *Aucun* |
| `POST` | `/probe/http` | Mesure la latence HTTP/HTTPS et contourne le CORS | `{"url": "https://example.com"}` |
| `POST` | `/probe/tcp` | Teste l'ouverture d'un port TCP (SSH, DB, Web...) | `{"host": "github.com", "port": 443}` |
| `POST` | `/probe/ssl` | Inspecte le certificat SSL/TLS (émetteur, expiration) | `{"domain": "google.com"}` |

### Exemple de réponse (`/probe/ssl`)
```json
{
  "valid": true,
  "domain": "google.com",
  "issuer": "CN=WR2,O=Google Trust Services,C=US",
  "expires_at": "2027-01-15T08:30:00.000Z",
  "days_remaining": 52,
  "error": null
}
```

---

## Installation et Exécution en Local

### Prérequis
* [Dart SDK](https://dart.dev/get-dart) `>= 3.0.0` (inclus avec Flutter)

### Démarrage rapide
```bash
# 1. Cloner le dépôt
git clone [https://github.com/ousmanefall4-creator/netcheck-backend.git](https://github.com/ousmanefall4-creator/netcheck-backend.git)
cd netcheck-backend

# 2. Installer les dépendances
dart pub get

# 3. Lancer le serveur (écoute par défaut sur le port 8000)
dart run bin/server.dart
```

---

## Déploiement avec Docker

Le projet inclut un `Dockerfile` multi-étapes optimisé pour le déploiement Cloud (Render, Railway, Fly.io) avec support automatique de la variable d'environnement `PORT` :

```bash
# Construire l'image Docker
docker build -t netcheck-backend .

# Démarrer le conteneur
docker run -p 8000:8000 netcheck-backend
```

---

## Auteur

**Ousmane Fall** — Développeur Full-Stack Flutter & Dart  
GitHub : [@ousmanefall4-creator](https://github.com/ousmanefall4-creator)