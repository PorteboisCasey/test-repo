# 🚀 Démarrage Rapide - DORA Metrics

Guide pour démarrer rapidement avec le système de métriques DORA.

## ⚡ Installation en 5 minutes

### 1. Configurer l'environnement

```bash
# Copier le fichier de configuration
cp .env.example .env

# Éditer .env et remplir votre GITHUB_TOKEN
# Vous pouvez obtenir un token ici: https://github.com/settings/tokens/new
# Permissions requises: repo, workflow
```

### 2. Démarrer PostgreSQL

```bash
# Démarrer PostgreSQL avec Docker
docker-compose up -d

# Vérifier que c'est démarré
docker-compose ps
```

### 3. Installer Python et les dépendances

```bash
# Créer un environnement virtuel
cd dora
python3 -m venv venv

# Activer l'environnement
source venv/bin/activate  # Sur Mac/Linux
# venv\Scripts\activate   # Sur Windows

# Installer les dépendances
pip install -r requirements.txt
```

### 4. Créer des données de test

```bash
# Option A: Créer des issues "incident" via script
python create_test_incidents.py

# Option B: Créer manuellement sur GitHub
# https://github.com/PorteboisCasey/test-repo/issues/new
# Ajoutez le label "incident"
```

### 5. Générer des déploiements

```bash
# Faire un changement et pusher
cd ..
echo "// Test feature" >> src/index.js
git add src/index.js
git commit -m "test: Add test feature for DORA metrics"
git push origin master

# Attendez 1-2 minutes que le workflow GitHub Actions se termine
# Vérifiez: https://github.com/PorteboisCasey/test-repo/actions
```

### 6. Exécuter le pipeline DORA

```bash
cd dora
python run_dora_pipeline.py
```

### 7. Consulter les résultats

```bash
# Les CSV sont dans dora/exports/
ls -la exports/

# Voir le résumé
cat exports/dora_metrics_summary.csv

# Ou ouvrir dans Excel/LibreOffice
open exports/dora_metrics_summary.csv  # Mac
# xdg-open exports/dora_metrics_summary.csv  # Linux
# start exports/dora_metrics_summary.csv  # Windows
```

## 📊 Exemple de résultat

Après avoir exécuté le pipeline, vous devriez voir:

```
==================================================================
  Pipeline Completed Successfully!
==================================================================
Results:
  - Data extracted from: PorteboisCasey/test-repo
  - Data loaded into: dora_metrics database
  - Metrics exported to: exports/

CSV files generated:
  - dora_metrics_summary.csv       (All metrics summary)
  - dora_deployment_frequency.csv  (Deployment frequency)
  - dora_lead_time.csv             (Lead time for changes)
  - dora_change_failure_rate.csv   (Change failure rate)
  - dora_mttr.csv                  (Mean time to recovery)
==================================================================
```

## 🔄 Workflow quotidien

Pour suivre vos métriques régulièrement:

```bash
# 1. Activez l'environnement Python
cd dora && source venv/bin/activate

# 2. Exécutez le pipeline
python run_dora_pipeline.py

# 3. Consultez les nouveaux résultats
cat exports/dora_metrics_summary.csv
```

## 🎯 Générer plus de données

Pour avoir des métriques significatives:

### Créer plusieurs déploiements

```bash
# Faire plusieurs commits et pushs
for i in {1..5}; do
  echo "// Feature $i" >> src/index.js
  git add src/index.js
  git commit -m "feat: Add feature $i"
  git push origin master
  sleep 120  # Attendre 2 minutes entre chaque déploiement
done
```

### Simuler des incidents

```bash
cd dora
python create_test_incidents.py
```

Puis fermez certains incidents via l'interface GitHub pour simuler leur résolution.

## 🐛 Problèmes courants

### PostgreSQL ne démarre pas

```bash
# Vérifier les logs
docker-compose logs postgres

# Redémarrer
docker-compose down
docker-compose up -d
```

### Erreur "No deployments found"

C'est normal si vous n'avez pas encore pushé sur master. Faites un commit et push pour déclencher le workflow.

### Token GitHub invalide

Vérifiez que votre token a les bonnes permissions:
```bash
curl -H "Authorization: token votre_token" https://api.github.com/user
```

## 📚 Ressources

- **Documentation complète**: Voir [DORA_README.md](./DORA_README.md)
- **Requêtes SQL**: [dora/sql/queries.sql](./dora/sql/queries.sql)
- **Workflow GitHub**: [.github/workflows/deploy-production.yml](./.github/workflows/deploy-production.yml)

## 🎓 Prochaines étapes

1. **Ajoutez plus de déploiements** pour avoir des métriques significatives
2. **Fermez des incidents** pour calculer le MTTR
3. **Analysez vos résultats** et identifiez les axes d'amélioration
4. **Configurez un dashboard** pour visualiser les métriques dans le temps

Bon DevOps! 🚀
