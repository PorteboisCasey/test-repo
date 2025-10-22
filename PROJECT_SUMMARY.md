# 📦 Projet DORA Metrics - Résumé Complet

## ✅ Ce qui a été implémenté

### Partie 1 : GitHub Actions et Déploiements ✓

**Fichier**: `.github/workflows/deploy-production.yml`

- ✅ Workflow qui se déclenche sur push vers master
- ✅ Build npm avec tests
- ✅ Création de Deployments via l'API GitHub
- ✅ Environnement "production" configuré
- ✅ Gestion des statuts (success/failure)

**Fonctionnalités**:
- Installation des dépendances Node.js
- Exécution des tests
- Build de l'application
- Création de déploiement GitHub avec l'API
- Mise à jour automatique du statut

### Partie 2 : Extraction de données via API GitHub ✓

**Fichier**: `dora/github_extractor.py`

- ✅ Extraction des Deployments (sha, status, created_at, environment)
- ✅ Extraction des Commits (sha, committed_date, author, message)
- ✅ Extraction des Incidents (issues avec label "incident")
- ✅ Utilise PyGithub pour l'API
- ✅ Gestion complète des erreurs

**Script helper**: `dora/create_test_incidents.py`
- Crée automatiquement 3 issues de test avec le label "incident"
- Ferme une issue pour simuler la résolution

### Partie 3 : Base de données PostgreSQL ✓

**Fichiers**:
- `docker-compose.yml` - Configuration PostgreSQL
- `dora/sql/schema.sql` - Schéma complet des tables
- `dora/sql/queries.sql` - Les 4 requêtes DORA

**Tables créées**:
1. ✅ `deployments` - Stocke les déploiements GitHub
2. ✅ `changes` - Stocke les commits
3. ✅ `deployment_commits` - Table de liaison
4. ✅ `incidents` - Stocke les issues "incident"

**Requêtes SQL (fenêtre 28 jours)**:
1. ✅ **DF** - Deployment Frequency
2. ✅ **LTC** - Lead Time for Changes
3. ✅ **CFR** - Change Failure Rate
4. ✅ **MTTR** - Mean Time to Recovery

### Partie 4 : Scripts Python ✓

**Fichiers créés**:

1. `dora/github_extractor.py`
   - Classe `GitHubDataExtractor`
   - Méthodes pour extraire deployments, commits, incidents
   - Peut être exécuté indépendamment

2. `dora/db_loader.py`
   - Classe `DatabaseLoader`
   - Chargement dans PostgreSQL
   - Création des liens deployment-commit
   - Gestion des conflits (upsert)

3. `dora/export_metrics.py`
   - Classe `MetricsExporter`
   - Export des 4 métriques en CSV
   - Dashboard summary

4. `dora/run_dora_pipeline.py` ⭐
   - Script principal qui orchestre tout
   - Extraction → Chargement → Export
   - Gestion complète des erreurs

5. `dora/create_test_incidents.py`
   - Création automatique d'issues de test

## 📂 Structure du Projet

```
test-repo/
├── 📄 Configuration
│   ├── .env.example              # Template de configuration
│   ├── docker-compose.yml        # PostgreSQL Docker
│   ├── package.json              # Configuration Node.js
│   └── .gitignore               # Fichiers à ignorer
│
├── 📚 Documentation
│   ├── DORA_README.md           # Documentation complète (⭐ principale)
│   ├── QUICKSTART.md            # Guide de démarrage rapide
│   └── PROJECT_SUMMARY.md       # Ce fichier
│
├── 🔧 Scripts d'automatisation
│   ├── setup.sh                 # Script d'installation
│   └── Makefile                 # Commandes simplifiées
│
├── 🐙 GitHub Actions
│   └── .github/workflows/
│       └── deploy-production.yml # Workflow de déploiement
│
├── 🐍 Python DORA System
│   └── dora/
│       ├── requirements.txt           # Dépendances Python
│       ├── github_extractor.py        # Extraction GitHub API
│       ├── db_loader.py              # Chargement PostgreSQL
│       ├── export_metrics.py         # Export CSV
│       ├── run_dora_pipeline.py      # Script principal ⭐
│       ├── create_test_incidents.py  # Helper pour tests
│       └── sql/
│           ├── schema.sql            # Schéma BDD
│           └── queries.sql           # Requêtes DORA
│
└── 📱 Application JavaScript
    └── src/
        └── index.js              # Application de démo
```

## 🎯 Livrables

### ✅ Livrable 1: Workflow GitHub Actions fonctionnel
- Fichier: `.github/workflows/deploy-production.yml`
- Fonctionnel: ✅
- Crée des Deployments: ✅
- Teste et build: ✅

### ✅ Livrable 2: Script Python d'extraction + chargement
- Extraction: `dora/github_extractor.py` ✅
- Chargement: `dora/db_loader.py` ✅
- Script combiné: `dora/run_dora_pipeline.py` ✅

### ✅ Livrable 3: Schéma SQL + 4 requêtes DORA
- Schéma: `dora/sql/schema.sql` ✅
- Requêtes: `dora/sql/queries.sql` ✅
- Toutes les 4 métriques: ✅

### ✅ Livrable 4: README expliquant l'exécution
- README principal: `DORA_README.md` ✅
- Guide rapide: `QUICKSTART.md` ✅
- Script setup: `setup.sh` ✅
- Makefile: `Makefile` ✅

### ✅ Livrable 5: Export CSV des résultats
- Script d'export: `dora/export_metrics.py` ✅
- 5 fichiers CSV générés:
  - `dora_metrics_summary.csv` (résumé)
  - `dora_deployment_frequency.csv`
  - `dora_lead_time.csv`
  - `dora_change_failure_rate.csv`
  - `dora_mttr.csv`

## 🚀 Comment utiliser

### Installation rapide

```bash
# Option 1: Script automatique
./setup.sh

# Option 2: Makefile
make setup

# Option 3: Manuel
cp .env.example .env
# Éditer .env avec votre GITHUB_TOKEN
docker-compose up -d
cd dora && python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Utilisation

```bash
# Créer des données de test
make incidents

# Faire un déploiement
echo "// feature" >> src/index.js
git add src/index.js
git commit -m "feat: new feature"
git push origin master

# Exécuter le pipeline DORA
make run

# Voir les résultats
cat dora/exports/dora_metrics_summary.csv
```

## 📊 Métriques DORA Implémentées

### 1. Deployment Frequency (DF)
**Requête**: Compte les déploiements réussis sur 28 jours
```sql
SELECT COUNT(*), COUNT(*)/28.0 as per_day
FROM deployments
WHERE status='success' AND environment='production'
AND created_at >= CURRENT_DATE - INTERVAL '28 days';
```

### 2. Lead Time for Changes (LTC)
**Requête**: Temps moyen commit → déploiement
```sql
SELECT AVG(EXTRACT(EPOCH FROM (d.created_at - c.committed_date)) / 3600) as hours
FROM deployments d
JOIN deployment_commits dc ON d.id = dc.deployment_id
JOIN changes c ON dc.commit_id = c.id
WHERE d.status='success' AND d.created_at >= CURRENT_DATE - INTERVAL '28 days';
```

### 3. Change Failure Rate (CFR)
**Requête**: Pourcentage de déploiements échoués
```sql
SELECT
  (COUNT(*) FILTER (WHERE status IN ('failure','error'))::NUMERIC /
   COUNT(*)::NUMERIC) * 100 as failure_rate
FROM deployments
WHERE environment='production' AND created_at >= CURRENT_DATE - INTERVAL '28 days';
```

### 4. Mean Time to Recovery (MTTR)
**Requête**: Temps moyen de résolution d'incidents
```sql
SELECT AVG(EXTRACT(EPOCH FROM (closed_at - created_at)) / 3600) as hours
FROM incidents
WHERE state='closed' AND closed_at IS NOT NULL
AND created_at >= CURRENT_DATE - INTERVAL '28 days';
```

## 🔧 Technologies Utilisées

### Backend / Data
- **PostgreSQL 15** (via Docker) - Base de données
- **Python 3.8+** - Scripts d'extraction et traitement
- **PyGithub** - API GitHub
- **psycopg2** - Connexion PostgreSQL

### DevOps / CI/CD
- **GitHub Actions** - Workflows CI/CD
- **Docker & Docker Compose** - Containerisation
- **GitHub API** - Deployments

### Frontend / App
- **Node.js 18** - Runtime JavaScript
- **npm** - Gestion de packages

## 📈 Améliorations Possibles

### Court terme
- [ ] Ajouter un dashboard Grafana
- [ ] Script de sauvegarde automatique
- [ ] Alertes si métriques se dégradent

### Moyen terme
- [ ] Support multi-branches
- [ ] Tracking des pull requests
- [ ] Métriques par équipe
- [ ] API REST pour les métriques

### Long terme
- [ ] Machine Learning pour prédictions
- [ ] Intégration Slack/Teams
- [ ] Dashboard temps réel
- [ ] Benchmarking avec l'industrie

## 📞 Support

Pour toute question ou problème:

1. Consultez `DORA_README.md` pour la documentation complète
2. Consultez `QUICKSTART.md` pour un démarrage rapide
3. Vérifiez la section Troubleshooting dans le README
4. Utilisez `make status` pour diagnostiquer les problèmes

## 🎓 Ressources Complémentaires

- [DORA Metrics Official Site](https://www.devops-research.com/research.html)
- [GitHub Deployments API Docs](https://docs.github.com/en/rest/deployments)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [PyGithub Documentation](https://pygithub.readthedocs.io/)

---

**Projet créé pour**: DevOps Course - Métriques DORA
**Date**: Octobre 2025
**Statut**: ✅ Complet et fonctionnel
