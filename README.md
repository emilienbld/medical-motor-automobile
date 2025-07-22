# Medical Motor Automobile (MMA)

> Solution robotique autonome pour le transport de matériel médical entre établissements de santé

## 📋 Table des Matières

- [À Propos](#à-propos)
- [Fonctionnalités](#fonctionnalités)
- [Architecture](#architecture)
- [Prérequis](#prérequis)
- [Installation](#installation)
- [Utilisation](#utilisation)
- [Spécifications Techniques](#spécifications-techniques)
- [Structure du Projet](#structure-du-projet)
- [Équipe](#équipe)
- [Licence](#licence)

## 🏥 À Propos

Le projet **Medical Motor Automobile** est une solution robotique autonome conçue pour automatiser le transport de matériel médical et de médicaments entre établissements de santé. Cette innovation répond aux défis logistiques du secteur médical en proposant une alternative automatisée aux livraisons humaines traditionnelles.

### Contexte

Dans le secteur médical, le transport inter-établissements représente un défi majeur en termes de coût et de flexibilité, particulièrement pour desservir les personnes à mobilité réduite. Notre solution robotique offre une réponse technologique moderne et efficace à ces problématiques.

### Objectifs

- **Navigation autonome** vers des coordonnées GPS prédéfinies
- **Contrôle manuel** via application mobile intuitive
- **Évitement d'obstacles** automatique en temps réel
- **Communication WiFi** directe et sécurisée
- **Monitoring visuel** via caméra embarquée
- **Gestion centralisée** des destinations via base de données

## ⭐ Fonctionnalités

### 📱 Application Mobile (Flutter)

#### Connexion & Communication
- Connexion WiFi directe au robot
- Gestion d'IP dynamique avec sauvegarde automatique
- Indicateurs de statut de connexion en temps réel

#### Contrôle Manuel
- Interface joystick virtuelle 360°
- Contrôle de vitesse adaptatif
- Retour haptique pour une meilleure expérience utilisateur
- Latence optimisée < 100ms

#### Navigation Autonome
- Saisie manuelle de coordonnées GPS
- Sélection de destinations prédéfinies
- Monitoring du trajet en temps réel

#### Gestion des Destinations
- Destinations rapides (hôpitaux, pharmacies)
- Historique personnel des trajets
- Synchronisation cloud via Firebase

#### Monitoring Temps Réel
- Flux vidéo de la caméra embarquée (15-20 FPS)
- Position GPS actuelle
- Informations détaillées du trajet

### 🤖 Véhicule Autonome (Arduino)

#### Communication
- Serveur WiFi intégré (Arduino UNO R4)
- Réception de commandes Flutter
- Transmission de données capteurs

#### Navigation Autonome
- Calcul de trajectoire GPS précis
- Contrôle moteurs TB6612FNG
- Correction de cap (gyroscope + magnétomètre)

#### Sécurité & Évitement
- Détection d'obstacles (HC-SR04) à 20-30cm
- Algorithme d'évitement intelligent
- Reprise automatique de trajectoire

#### Capteurs & Vision
- Module GPS NEO-8N (précision ±3m)
- Stabilisation MPU-6500
- Caméra OV2640 pour streaming vidéo

### ☁️ Base de Données (Firebase)

#### Structure Optimisée
- Collection "destinations" avec indexation
- Règles de sécurité configurées
- Synchronisation temps réel

#### Gestion de Contenu
- Destinations prédéfinies (établissements médicaux)
- Historique utilisateur personnalisé
- Sauvegarde automatique des trajets

## 🏗️ Architecture

```
┌─────────────────────┐    WiFi    ┌──────────────────────┐
│   Application       │◄──────────►│   Véhicule Autonome  │
│   Flutter Mobile    │            │   (Arduino UNO R4)   │
└─────────────────────┘            └──────────────────────┘
           │                                   │
           │ API REST                          │ Capteurs
           ▼                                   ▼
┌─────────────────────┐            ┌──────────────────────┐
│   Firebase          │            │   Système Embarqué   │
│   Firestore DB      │            │   - GPS, Gyroscope   │
└─────────────────────┘            │   - Caméra, Ultrasons│
                                   └──────────────────────┘
```

## 📋 Prérequis

### Hardware
- **Arduino UNO R4 WiFi** (contrôleur principal)
- **Module GPS NEO-8N** (navigation)
- **Capteur ultrasonique HC-SR04** (évitement d'obstacles)
- **Gyroscope MPU-6500** (stabilisation)
- **Magnétomètre QMC5883L** (correction de cap)
- **Caméra OV2640** (vision temps réel)
- **Driver moteur TB6612FNG** (propulsion)
- **Servomoteur SG90** (scan directionnel)
- **Batterie Lithium 7.4V** (autonomie 2h)

### Software
- **Flutter** (≥ 3.0.0)
- **Arduino IDE** (≥ 2.0.0)
- **Firebase Account** (Firestore activé)
- **Dart** (≥ 2.18.0)

## 🚀 Installation

### 1. Configuration du Véhicule

```bash
# Cloner le repository
git clone https://github.com/votre-repo/medical-motor-automobile.git
cd medical-motor-automobile

# Ouvrir le code Arduino
# Ouvrir le fichier arduino/mma_main/mma_main.ino dans l'Arduino IDE

# Installer les bibliothèques nécessaires via Library Manager :
# - WiFi (ESP32/Arduino)
# - GPS (SoftwareSerial)
# - Servo
# - Wire (I2C)
```

### 2. Configuration de l'Application Flutter

```bash
# Naviguer vers le dossier Flutter
cd flutter_app

# Installer les dépendances
flutter pub get

# Configurer Firebase
# 1. Créer un projet Firebase
# 2. Activer Firestore
# 3. Télécharger google-services.json
# 4. Placer le fichier dans android/app/

# Lancer l'application
flutter run
```

### 3. Configuration de la Base de Données

```javascript
// Structure Firestore - Collection : destinations
{
  "coordonnees": "48.8566,2.3522", // Format : latitude,longitude
  "lieu": "Hôpital Saint-Louis",
  "historique": false // false=destination rapide, true=historique personnel
}
```

## 📖 Utilisation

### Démarrage Rapide

1. **Alimenter le véhicule** et attendre l'initialisation des capteurs
2. **Lancer l'application Flutter** sur votre smartphone
3. **Se connecter au WiFi** du robot (IP affichée au démarrage)
4. **Choisir le mode** :
   - **Manuel** : Utiliser le joystick pour contrôle direct
   - **Autonome** : Sélectionner une destination et lancer la mission

### Modes de Fonctionnement

#### Mode Manuel
- Interface joystick pour contrôle précis
- Idéal pour navigation en espaces restreints
- Retour vidéo temps réel

#### Mode Autonome
- Navigation GPS automatique
- Évitement d'obstacles intelligent
- Monitoring continu du trajet

## 🔧 Spécifications Techniques

| Composant | Spécification |
|-----------|---------------|
| **Autonomie** | 2 heures (batterie 7.4V) |
| **Communication** | WiFi direct Arduino UNO R4 |
| **Précision GPS** | ±3 mètres (conditions normales) |
| **Détection Obstacles** | 20-30 cm (HC-SR04) |
| **Latence Contrôle** | <100ms via WiFi |
| **Résolution Caméra** | 320x240 pixels minimum |
| **Framerate Vidéo** | 15-20 FPS |

## 📁 Structure du Projet

```
medical-motor-automobile/
├── arduino/
│   ├── mma_main/
│   │   ├── mma_main.ino          # Code principal Arduino
│   │   ├── gps_module.cpp        # Gestion GPS
│   │   ├── wifi_server.cpp       # Serveur WiFi
│   │   └── obstacle_avoidance.cpp # Évitement d'obstacles
│   └── libraries/                # Bibliothèques personnalisées
├── flutter_app/
│   ├── lib/
│   │   ├── screens/              # Écrans de l'application
│   │   ├── widgets/              # Composants réutilisables
│   │   ├── services/             # Services (Firebase, WiFi)
│   │   └── models/               # Modèles de données
│   ├── android/
│   ├── ios/
│   └── pubspec.yaml             # Dépendances Flutter
├── firebase/
│   ├── firestore.rules          # Règles de sécurité
│   └── firestore.indexes.json   # Index de performance
├── docs/
│   ├── architecture.md          # Documentation architecture
│   ├── api_reference.md         # Référence API
│   └── troubleshooting.md       # Guide de dépannage
└── README.md
```

## 🔮 Perspectives d'Évolution

- **Capteurs avancés** : Intégration LIDAR et caméra thermique
- **Gestion de flotte** : Système centralisé multi-robots
- **Intelligence artificielle** : Apprentissage automatique pour navigation
- **Extension sectorielle** : Adaptation à d'autres domaines (livraison urbaine, assistance seniors)

## 📝 Licence

Ce projet est développé dans le cadre académique du Master IoT - H3 Hitema.

---

**Dernière mise à jour :** Juillet 2025
