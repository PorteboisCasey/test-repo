# 🚀 DÉMARREZ ICI - Système DORA Metrics

## ✅ L'installation est TERMINÉE !

Tout est configuré et testé. Voici ce qui fonctionne :

- ✅ PostgreSQL démarré sur le port 5433
- ✅ Base de données créée avec 5 tables
- ✅ Environnement Python configuré
- ✅ Token GitHub validé
- ✅ Toutes les dépendances installées

---

## 📝 Ce qu'il vous reste à faire (5 minutes)

### Étape 1 : Activez les Issues GitHub

Les Issues sont actuellement désactivées sur votre repo. Activez-les pour pouvoir tracker les incidents.

1. Allez sur: https://github.com/PorteboisCasey/test-repo/settings
2. Scrollez jusqu'à la section **"Features"**
3. Cochez **"Issues"**
4. Cliquez sur **"Save changes"**

### Étape 2 : Générez un déploiement

Faites un commit pour déclencher un déploiement via GitHub Actions :

```bash
cd /Users/postg0d/Desktop/Ecole/Devops_cours/test-repo

echo "// Test DORA feature" >> src/index.js
git add src/index.js
git commit -m "feat: Test DORA metrics system"
git push origin master
```

### Étape 3 : Attendez le workflow (1-2 minutes)

Le workflow GitHub Actions va créer un déploiement. Suivez l'avancement ici :
https://github.com/PorteboisCasey/test-repo/actions

Attendez que le workflow soit ✅ (vert).

### Étape 4 : (Optionnel) Créez des incidents de test

```bash
cd dora
source venv/bin/activate
python create_test_incidents.py
```

Cela créera 3 issues avec le label "incident" sur votre repo.

### Étape 5 : Exécutez le pipeline DORA

```bash
cd dora
source venv/bin/activate
python run_dora_pipeline.py
```

Vous devriez voir :

```
======================================================================
Starting GitHub data extraction...
======================================================================
Fetching deployments for PorteboisCasey/test-repo...
  Found deployment XXX: abc1234 - success
Total deployments found: X

Fetching commits for PorteboisCasey/test-repo...
Total commits found: XX

Fetching incidents (issues with label 'incident')...
Total incidents found: X

======================================================================
  Pipeline Completed Successfully!
======================================================================
```

### Étape 6 : Consultez les résultats

```bash
cat exports/dora_metrics_summary.csv
```

Ou ouvrez le fichier dans Excel/Numbers:

```bash
open exports/dora_metrics_summary.csv
```

---

## 📊 Comprendre les résultats

Le fichier `dora_metrics_summary.csv` contient :

| Métrique | Description | Elite Performance |
|----------|-------------|-------------------|
| **DF** (Deployment Frequency) | Nombre de déploiements / jour | > 1 par jour |
| **LTC** (Lead Time for Changes) | Temps commit → déploiement | < 1 heure |
| **CFR** (Change Failure Rate) | % de déploiements échoués | 0-15% |
| **MTTR** (Mean Time to Recovery) | Temps moyen de résolution incident | < 1 heure |

---

## 🔄 Pour régénérer les métriques plus tard

```bash
cd /Users/postg0d/Desktop/Ecole/Devops_cours/test-repo/dora
source venv/bin/activate
python run_dora_pipeline.py
```

---

## 🆘 En cas de problème

### PostgreSQL ne démarre pas
```bash
docker-compose down -v
docker-compose up -d
```

### Réinstaller complètement
```bash
./install.sh
```

### Voir les logs PostgreSQL
```bash
docker-compose logs postgres
```

### Tester la connexion BDD
```bash
docker exec dora-postgres psql -U dora_user -d dora_metrics -c "SELECT COUNT(*) FROM deployments;"
```

---

## 📚 Documentation complète

- **DORA_README.md** : Documentation technique complète
- **QUICKSTART.md** : Guide de démarrage rapide
- **PROJECT_SUMMARY.md** : Résumé du projet et architecture

---

## 🎯 Rappel: Ce qui a été créé

1. **Workflow GitHub Actions** (`.github/workflows/deploy-production.yml`)
   - Déploie automatiquement sur push vers master
   - Crée des Deployments via l'API GitHub

2. **Base de données PostgreSQL** (port 5433)
   - 4 tables : deployments, changes, deployment_commits, incidents
   - Schéma optimisé avec indexes

3. **Scripts Python** (`dora/`)
   - `github_extractor.py` : Extraction données GitHub
   - `db_loader.py` : Chargement dans PostgreSQL
   - `export_metrics.py` : Export CSV
   - `run_dora_pipeline.py` : Orchestration complète

4. **Requêtes SQL** (`dora/sql/queries.sql`)
   - Les 4 métriques DORA calculées sur 28 jours

---

**Prêt à commencer ? Suivez les 6 étapes ci-dessus ! 🚀**
