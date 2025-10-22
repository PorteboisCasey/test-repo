#!/bin/bash
# Script d'installation automatique du système DORA Metrics
# Ce script installe et configure tout de A à Z

set -e  # Arrête le script si une commande échoue

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "=========================================================================="
echo "                  DORA Metrics - Installation Automatique"
echo "=========================================================================="
echo ""

# Fonction pour afficher les messages
print_step() {
    echo -e "${BLUE}[ÉTAPE]${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Fonction pour vérifier si un token GitHub est valide
check_github_token() {
    local token=$1
    if [ -z "$token" ] || [ "$token" == "your_github_token_here" ]; then
        return 1
    fi

    # Tester le token
    response=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token $token" https://api.github.com/user)
    if [ "$response" == "200" ]; then
        return 0
    else
        return 1
    fi
}

# Vérification des prérequis
print_step "Vérification des prérequis"

# Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker n'est pas installé"
    echo "Installez Docker depuis: https://www.docker.com/get-started"
    exit 1
fi
print_success "Docker est installé"

# Docker Compose
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose n'est pas installé"
    exit 1
fi
print_success "Docker Compose est installé"

# Python 3
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 n'est pas installé"
    exit 1
fi
PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
print_success "Python est installé (version $PYTHON_VERSION)"

# Git
if ! command -v git &> /dev/null; then
    print_error "Git n'est pas installé"
    exit 1
fi
print_success "Git est installé"

echo ""
print_step "Configuration de l'environnement"

# Vérifier si .env existe et contient un token valide
TOKEN_VALID=false
if [ -f ".env" ]; then
    source .env
    if check_github_token "$GITHUB_TOKEN" 2>/dev/null; then
        print_success "Token GitHub valide trouvé dans .env"
        TOKEN_VALID=true
    else
        print_warning "Token GitHub invalide ou expiré dans .env"
    fi
fi

# Si pas de token valide, demander à l'utilisateur
if [ "$TOKEN_VALID" = false ]; then
    echo ""
    print_warning "Configuration du token GitHub requise"
    echo "Créez un token sur: https://github.com/settings/tokens/new"
    echo "Permissions requises: repo, workflow"
    echo ""
    read -p "Entrez votre GitHub token (ou appuyez sur Entrée pour utiliser un mock): " USER_TOKEN

    if [ -z "$USER_TOKEN" ]; then
        print_warning "Utilisation d'un token mock (certaines fonctionnalités ne marcheront pas)"
        GITHUB_TOKEN="mock_token_for_testing"
    else
        GITHUB_TOKEN="$USER_TOKEN"
    fi

    # Créer/mettre à jour .env
    if [ -f ".env" ]; then
        # Mettre à jour le token existant
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/GITHUB_TOKEN=.*/GITHUB_TOKEN=$GITHUB_TOKEN/" .env
        else
            sed -i "s/GITHUB_TOKEN=.*/GITHUB_TOKEN=$GITHUB_TOKEN/" .env
        fi
    else
        cp .env.example .env
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/your_github_token_here/$GITHUB_TOKEN/" .env
        else
            sed -i "s/your_github_token_here/$GITHUB_TOKEN/" .env
        fi
    fi
    print_success "Fichier .env configuré"
fi

echo ""
print_step "Démarrage de PostgreSQL"

# Arrêter les conteneurs existants si nécessaire
docker-compose down -v 2>/dev/null || true

# Démarrer PostgreSQL
docker-compose up -d

# Attendre que PostgreSQL soit prêt
echo "Attente du démarrage de PostgreSQL..."
sleep 5

# Vérifier que PostgreSQL fonctionne
max_retries=30
retry=0
until docker exec dora-postgres pg_isready -U dora_user -d dora_metrics &>/dev/null; do
    retry=$((retry + 1))
    if [ $retry -ge $max_retries ]; then
        print_error "PostgreSQL n'a pas démarré dans le temps imparti"
        docker-compose logs postgres
        exit 1
    fi
    echo "Tentative $retry/$max_retries..."
    sleep 2
done

print_success "PostgreSQL est démarré et prêt (port 5433)"

# Vérifier que les tables sont créées
TABLE_COUNT=$(docker exec dora-postgres psql -U dora_user -d dora_metrics -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';" | tr -d ' ')
if [ "$TABLE_COUNT" -ge "4" ]; then
    print_success "Schéma de base de données créé ($TABLE_COUNT tables)"
else
    print_error "Problème avec le schéma de base de données"
    exit 1
fi

echo ""
print_step "Installation de l'environnement Python"

cd dora

# Supprimer l'ancien venv s'il existe
if [ -d "venv" ]; then
    rm -rf venv
fi

# Créer un nouvel environnement virtuel
python3 -m venv venv
print_success "Environnement virtuel Python créé"

# Activer l'environnement
source venv/bin/activate

# Mettre à jour pip
pip install --quiet --upgrade pip setuptools wheel
print_success "pip, setuptools et wheel mis à jour"

# Installer les dépendances
echo "Installation des dépendances Python (cela peut prendre 1-2 minutes)..."
pip install --quiet -r requirements.txt
print_success "Dépendances Python installées"

# Tester l'import des modules
python3 -c "import psycopg2, github, dotenv; print('OK')" &>/dev/null
if [ $? -eq 0 ]; then
    print_success "Modules Python validés"
else
    print_error "Problème avec les modules Python"
    exit 1
fi

# Tester la connexion à la base de données
print_step "Test de connexion à la base de données"
python3 -c "
import os, sys
os.chdir('..')
from dotenv import load_dotenv
import psycopg2
load_dotenv()
try:
    conn = psycopg2.connect(
        host='localhost',
        port=5433,
        dbname='dora_metrics',
        user='dora_user',
        password='dora_password'
    )
    conn.close()
    print('OK')
except Exception as e:
    print(f'ERREUR: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null

if [ $? -eq 0 ]; then
    print_success "Connexion à PostgreSQL réussie"
else
    print_error "Échec de connexion à PostgreSQL"
    exit 1
fi

cd ..

echo ""
echo "=========================================================================="
echo -e "${GREEN}✓ Installation terminée avec succès!${NC}"
echo "=========================================================================="
echo ""
echo "Prochaines étapes:"
echo ""
echo "1. Activez les Issues sur votre repo GitHub:"
echo "   https://github.com/PorteboisCasey/test-repo/settings"
echo "   Dans la section 'Features', cochez 'Issues'"
echo ""
echo "2. Faites un commit et push pour générer un déploiement:"
echo "   echo '// New feature' >> src/index.js"
echo "   git add src/index.js"
echo "   git commit -m 'feat: Test DORA metrics'"
echo "   git push origin master"
echo ""
echo "3. Créez quelques incidents (optionnel):"
echo "   cd dora"
echo "   source venv/bin/activate"
echo "   python create_test_incidents.py"
echo ""
echo "4. Attendez que le workflow GitHub Actions termine (1-2 minutes)"
echo "   https://github.com/PorteboisCasey/test-repo/actions"
echo ""
echo "5. Exécutez le pipeline DORA:"
echo "   cd dora"
echo "   source venv/bin/activate"
echo "   python run_dora_pipeline.py"
echo ""
echo "6. Consultez les résultats:"
echo "   cat dora/exports/dora_metrics_summary.csv"
echo ""
echo "=========================================================================="
echo ""
echo "État du système:"
echo "  ✓ PostgreSQL: Démarré sur le port 5433"
echo "  ✓ Python venv: dora/venv/"
echo "  ✓ Configuration: .env"
echo ""
echo "Pour obtenir de l'aide: consultez DORA_README.md"
echo "=========================================================================="
