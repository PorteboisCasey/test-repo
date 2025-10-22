# Système de Métriques DORA

Ce projet implémente un système complet de métriques DORA (DevOps Research and Assessment) pour mesurer la performance de votre équipe DevOps.

## 📊 Les 4 Métriques DORA

1. **Deployment Frequency (DF)** - Fréquence de déploiement
   - Mesure: Nombre de déploiements réussis / période (28 jours)
   - Elite: Plusieurs déploiements par jour

2. **Lead Time for Changes (LTC)** - Temps de cycle du changement
   - Mesure: Temps entre le commit et le déploiement en production
   - Elite: Moins d'une heure

3. **Change Failure Rate (CFR)** - Taux d'échec des changements
   - Mesure: Pourcentage de déploiements échoués
   - Elite: 0-15%

4. **Mean Time to Recovery (MTTR)** - Temps moyen de récupération
   - Mesure: Temps moyen pour résoudre un incident
   - Elite: Moins d'une heure

## 🏗️ Architecture

```
├── .github/workflows/
│   └── deploy-production.yml    # Workflow de déploiement automatique
├── dora/
│   ├── sql/
│   │   ├── schema.sql           # Schéma de la base de données
│   │   └── queries.sql          # Requêtes SQL pour les métriques
│   ├── github_extractor.py      # Extraction des données GitHub
│   ├── db_loader.py             # Chargement dans PostgreSQL
│   ├── export_metrics.py        # Export des métriques en CSV
│   ├── run_dora_pipeline.py     # Script principal
│   └── requirements.txt         # Dépendances Python
├── docker-compose.yml           # Configuration PostgreSQL
└── .env.example                 # Template de configuration
```

## 📋 Prérequis

### Logiciels requis
- **Docker** et **Docker Compose** (pour PostgreSQL)
- **Python 3.8+**
- **Node.js 18+** (pour le projet JavaScript)
- **Git** et accès à GitHub

### Accès GitHub
- Personal Access Token avec les permissions:
  - `repo` (accès au repository)
  - `workflow` (gestion des workflows)

## 🚀 Installation

### 1. Configuration de l'environnement

Copiez le fichier de configuration exemple:
```bash
cp .env.example .env
```

Éditez `.env` et remplissez vos informations:
```env
# GitHub Configuration
GITHUB_TOKEN=ghp_votre_token_ici
GITHUB_OWNER=PorteboisCasey
GITHUB_REPO=test-repo

# PostgreSQL Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=dora_metrics
DB_USER=dora_user
DB_PASSWORD=dora_password
```

### 2. Démarrer PostgreSQL

Lancez la base de données avec Docker:
```bash
docker-compose up -d
```

Vérifiez que PostgreSQL est démarré:
```bash
docker-compose ps
```

### 3. Installer les dépendances Python

Créez un environnement virtuel et installez les dépendances:
```bash
cd dora
python3 -m venv venv
source venv/bin/activate  # Sur Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 4. Créer des issues "incident" pour tester

Sur GitHub, créez 2-3 issues avec le label `incident`:

1. Allez sur: `https://github.com/PorteboisCasey/test-repo/issues/new`
2. Titre: "Service degradation - API slowdown"
3. Ajoutez le label `incident`
4. Créez l'issue
5. Fermez-la après quelques heures/jours pour avoir des métriques MTTR

Répétez pour créer 2-3 incidents avec différents états (ouvert/fermé).

## 📊 Utilisation

### Option 1: Pipeline complet (Recommandé)

Exécutez le pipeline complet qui fait tout automatiquement:

```bash
cd dora
source venv/bin/activate  # Si pas déjà activé
python run_dora_pipeline.py
```

Ce script:
1. ✅ Extrait les données de GitHub (deployments, commits, incidents)
2. ✅ Charge les données dans PostgreSQL
3. ✅ Calcule et exporte les métriques DORA en CSV

Les résultats seront dans `dora/exports/`:
- `dora_metrics_summary.csv` - Résumé de toutes les métriques
- `dora_deployment_frequency.csv` - Détails DF
- `dora_lead_time.csv` - Détails LTC
- `dora_change_failure_rate.csv` - Détails CFR
- `dora_mttr.csv` - Détails MTTR

### Option 2: Étape par étape

#### Étape 1: Extraire les données de GitHub
```bash
python github_extractor.py
```

#### Étape 2: Charger dans PostgreSQL
```bash
python db_loader.py
```

#### Étape 3: Exporter les métriques
```bash
python export_metrics.py
```

### Option 3: Requêtes SQL directes

Vous pouvez aussi exécuter les requêtes SQL manuellement:

```bash
# Se connecter à PostgreSQL
docker exec -it dora-postgres psql -U dora_user -d dora_metrics

# Exécuter les requêtes
\i /dora/sql/queries.sql
```

## 🔄 Workflow de Déploiement

### Déploiement automatique

Le workflow `.github/workflows/deploy-production.yml` se déclenche:
- À chaque push sur `master` ou `main`
- Manuellement via l'interface GitHub Actions

Le workflow:
1. ✅ Installe les dépendances
2. ✅ Exécute les tests
3. ✅ Build l'application
4. ✅ Crée un Deployment GitHub via l'API
5. ✅ Simule le déploiement en production
6. ✅ Met à jour le statut du déploiement (success/failure)

### Tester le workflow

Pour générer des déploiements et tester les métriques:

```bash
# Faire un changement simple
echo "// New feature" >> src/index.js

# Commit et push
git add src/index.js
git commit -m "Add new feature"
git push origin master

# Le workflow se déclenchera automatiquement
# Vérifiez sur: https://github.com/PorteboisCasey/test-repo/actions
```

Après plusieurs déploiements, réexécutez le pipeline pour voir l'évolution:
```bash
python run_dora_pipeline.py
```

## 📈 Analyse des Résultats

### Résumé des métriques

Ouvrez `exports/dora_metrics_summary.csv`:

| metric_period | DF_Total | DF_Per_Day | LTC_Avg_Hours | CFR_% | MTTR_Avg_Hours |
|---------------|----------|------------|---------------|-------|----------------|
| Last 28 days  | 42       | 1.5        | 2.3           | 5.0   | 1.8            |

### Interprétation

#### Deployment Frequency (DF)
- **Elite**: > 1 déploiement/jour
- **High**: Entre 1/semaine et 1/mois
- **Medium**: Entre 1/mois et 1/6 mois
- **Low**: < 1/6 mois

#### Lead Time for Changes (LTC)
- **Elite**: < 1 heure
- **High**: Entre 1 jour et 1 semaine
- **Medium**: Entre 1 semaine et 1 mois
- **Low**: > 1 mois

#### Change Failure Rate (CFR)
- **Elite**: 0-15%
- **High**: 16-30%
- **Medium**: 31-45%
- **Low**: > 45%

#### Mean Time to Recovery (MTTR)
- **Elite**: < 1 heure
- **High**: < 1 jour
- **Medium**: Entre 1 jour et 1 semaine
- **Low**: > 1 semaine

## 🗃️ Schéma de la Base de Données

### Tables

1. **deployments** - Déploiements GitHub
   - `deployment_id`: ID unique du déploiement
   - `sha`: Hash du commit déployé
   - `environment`: Environnement (production)
   - `status`: État (success, failure, error)
   - `created_at`: Date de création

2. **changes** - Commits/changements
   - `sha`: Hash du commit
   - `committed_date`: Date du commit
   - `author`: Auteur du commit
   - `message`: Message de commit

3. **deployment_commits** - Liaison deployments ↔ commits
   - `deployment_id`: Référence au déploiement
   - `commit_id`: Référence au commit

4. **incidents** - Issues avec label "incident"
   - `issue_number`: Numéro de l'issue
   - `title`: Titre
   - `state`: État (open/closed)
   - `created_at`: Date de création
   - `closed_at`: Date de fermeture

## 🛠️ Maintenance

### Mise à jour des données

Pour rafraîchir les métriques:
```bash
python run_dora_pipeline.py
```

### Réinitialiser la base de données

Si vous voulez repartir de zéro:
```bash
docker-compose down -v
docker-compose up -d
```

### Arrêter PostgreSQL

```bash
docker-compose down
```

## 🐛 Troubleshooting

### Erreur de connexion à PostgreSQL

Vérifiez que PostgreSQL est démarré:
```bash
docker-compose ps
docker-compose logs postgres
```

### Erreur d'authentification GitHub

Vérifiez votre token:
```bash
# Testez votre token
curl -H "Authorization: token ghp_votre_token" https://api.github.com/user
```

### Pas de données de déploiement

Si vous n'avez pas encore de déploiements:
1. Faites un push vers master
2. Attendez que le workflow se termine
3. Réexécutez le pipeline

## 📚 Ressources

- [DORA Metrics](https://www.devops-research.com/research.html)
- [GitHub Deployments API](https://docs.github.com/en/rest/deployments/deployments)
- [GitHub Actions](https://docs.github.com/en/actions)

## 📝 Notes

- **Simplification**: Dans cette implémentation, 1 commit = 1 déploiement
- **Fenêtre temporelle**: Les métriques sont calculées sur les 28 derniers jours
- **Production uniquement**: Seuls les déploiements en environnement "production" sont comptabilisés

## 🎯 Prochaines étapes

Pour améliorer ce système:

1. **Visualisation**: Créer un dashboard avec Grafana ou Metabase
2. **Alertes**: Configurer des alertes si les métriques se dégradent
3. **Historique**: Suivre l'évolution des métriques dans le temps
4. **Multi-environnements**: Tracker staging, production, etc.
5. **CI/CD enrichi**: Ajouter des tests de performance, sécurité, etc.
