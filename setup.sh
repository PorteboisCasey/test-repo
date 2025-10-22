#!/bin/bash
# Script d'installation et de configuration du système DORA Metrics

set -e

echo "=========================================================================="
echo "  DORA Metrics System - Installation Script"
echo "=========================================================================="
echo ""

# Couleurs pour l'affichage
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "ℹ $1"
}

# Vérifier les prérequis
echo "Checking prerequisites..."
echo ""

# Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed"
    echo "Please install Docker from: https://www.docker.com/get-started"
    exit 1
else
    print_success "Docker is installed"
fi

# Docker Compose
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed"
    echo "Please install Docker Compose"
    exit 1
else
    print_success "Docker Compose is installed"
fi

# Python
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is not installed"
    echo "Please install Python 3.8 or higher"
    exit 1
else
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    print_success "Python is installed (version $PYTHON_VERSION)"
fi

# Git
if ! command -v git &> /dev/null; then
    print_error "Git is not installed"
    exit 1
else
    print_success "Git is installed"
fi

echo ""
echo "=========================================================================="
echo "  Step 1: Environment Configuration"
echo "=========================================================================="
echo ""

# Vérifier si .env existe
if [ -f ".env" ]; then
    print_warning ".env file already exists"
    read -p "Do you want to overwrite it? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Keeping existing .env file"
    else
        cp .env.example .env
        print_success "Created .env file from template"
    fi
else
    cp .env.example .env
    print_success "Created .env file from template"
fi

# Demander le GitHub token si pas encore configuré
if grep -q "your_github_token_here" .env; then
    echo ""
    print_warning "GitHub token not configured in .env"
    echo "You need a GitHub Personal Access Token with 'repo' and 'workflow' permissions"
    echo "Create one here: https://github.com/settings/tokens/new"
    echo ""
    read -p "Enter your GitHub token (or press Enter to skip): " GITHUB_TOKEN

    if [ ! -z "$GITHUB_TOKEN" ]; then
        # Remplacer le token dans .env (compatible Mac et Linux)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/your_github_token_here/$GITHUB_TOKEN/" .env
        else
            sed -i "s/your_github_token_here/$GITHUB_TOKEN/" .env
        fi
        print_success "GitHub token configured"
    else
        print_warning "Skipped token configuration. Please edit .env manually"
    fi
fi

echo ""
echo "=========================================================================="
echo "  Step 2: Starting PostgreSQL"
echo "=========================================================================="
echo ""

# Démarrer PostgreSQL
docker-compose up -d

# Attendre que PostgreSQL soit prêt
echo "Waiting for PostgreSQL to be ready..."
sleep 5

if docker-compose ps | grep -q "dora-postgres.*Up"; then
    print_success "PostgreSQL is running"
else
    print_error "PostgreSQL failed to start"
    echo "Check logs with: docker-compose logs postgres"
    exit 1
fi

echo ""
echo "=========================================================================="
echo "  Step 3: Setting up Python Environment"
echo "=========================================================================="
echo ""

cd dora

# Créer l'environnement virtuel
if [ ! -d "venv" ]; then
    python3 -m venv venv
    print_success "Created Python virtual environment"
else
    print_info "Virtual environment already exists"
fi

# Activer l'environnement
source venv/bin/activate

# Installer les dépendances
pip install -q --upgrade pip
pip install -q -r requirements.txt
print_success "Installed Python dependencies"

cd ..

echo ""
echo "=========================================================================="
echo "  Installation Complete!"
echo "=========================================================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Edit .env file and ensure your GITHUB_TOKEN is set:"
echo "   nano .env"
echo ""
echo "2. Create test incidents (optional):"
echo "   cd dora"
echo "   source venv/bin/activate"
echo "   python create_test_incidents.py"
echo ""
echo "3. Make a commit to trigger a deployment:"
echo "   echo '// New feature' >> src/index.js"
echo "   git add src/index.js"
echo "   git commit -m 'feat: Test DORA metrics'"
echo "   git push origin master"
echo ""
echo "4. Run the DORA pipeline:"
echo "   cd dora"
echo "   source venv/bin/activate"
echo "   python run_dora_pipeline.py"
echo ""
echo "5. View the results:"
echo "   cat dora/exports/dora_metrics_summary.csv"
echo ""
echo "For more details, see:"
echo "  - QUICKSTART.md for a quick start guide"
echo "  - DORA_README.md for complete documentation"
echo ""
echo "=========================================================================="
