#!/usr/bin/env python3
"""
Script principal pour exécuter le pipeline complet des métriques DORA

Ce script:
1. Extrait les données de GitHub (deployments, commits, incidents)
2. Charge les données dans PostgreSQL
3. Exporte les métriques DORA en CSV
"""

import os
import sys
from dotenv import load_dotenv
from github_extractor import GitHubDataExtractor
from db_loader import DatabaseLoader
from export_metrics import MetricsExporter


def print_header(message: str):
    """Affiche un en-tête formaté"""
    print("\n" + "=" * 70)
    print(f"  {message}")
    print("=" * 70 + "\n")


def check_environment():
    """Vérifie que toutes les variables d'environnement sont définies"""
    required_vars = [
        'GITHUB_TOKEN',
        'GITHUB_OWNER',
        'GITHUB_REPO',
        'DB_HOST',
        'DB_PORT',
        'DB_NAME',
        'DB_USER',
        'DB_PASSWORD'
    ]

    missing = []
    for var in required_vars:
        if not os.getenv(var):
            missing.append(var)

    if missing:
        print("ERROR: Missing required environment variables:")
        for var in missing:
            print(f"  - {var}")
        print("\nPlease create a .env file based on .env.example")
        return False

    return True


def main():
    """Fonction principale"""
    print_header("DORA Metrics Pipeline")

    # Charge les variables d'environnement
    load_dotenv()

    # Vérifie l'environnement
    if not check_environment():
        sys.exit(1)

    # Configuration
    github_token = os.getenv('GITHUB_TOKEN')
    github_owner = os.getenv('GITHUB_OWNER')
    github_repo = os.getenv('GITHUB_REPO')

    db_host = os.getenv('DB_HOST')
    db_port = int(os.getenv('DB_PORT'))
    db_name = os.getenv('DB_NAME')
    db_user = os.getenv('DB_USER')
    db_password = os.getenv('DB_PASSWORD')

    output_dir = "exports"

    # ÉTAPE 1: Extraction des données GitHub
    print_header("Step 1: Extracting data from GitHub")
    try:
        extractor = GitHubDataExtractor(github_token, github_owner, github_repo)
        data = extractor.extract_all_data()
    except Exception as e:
        print(f"ERROR: Failed to extract data from GitHub: {e}")
        sys.exit(1)

    # ÉTAPE 2: Chargement des données dans PostgreSQL
    print_header("Step 2: Loading data into PostgreSQL")
    loader = DatabaseLoader(db_host, db_port, db_name, db_user, db_password)

    try:
        loader.connect()
        loader.load_all_data(data)
    except Exception as e:
        print(f"ERROR: Failed to load data into database: {e}")
        sys.exit(1)
    finally:
        loader.disconnect()

    # ÉTAPE 3: Export des métriques DORA
    print_header("Step 3: Exporting DORA metrics to CSV")
    exporter = MetricsExporter(db_host, db_port, db_name, db_user, db_password)

    try:
        exporter.connect()
        exporter.export_all_metrics(output_dir)
    except Exception as e:
        print(f"ERROR: Failed to export metrics: {e}")
        sys.exit(1)
    finally:
        exporter.disconnect()

    # Résumé final
    print_header("Pipeline Completed Successfully!")
    print("Results:")
    print(f"  - Data extracted from: {github_owner}/{github_repo}")
    print(f"  - Data loaded into: {db_name} database")
    print(f"  - Metrics exported to: {output_dir}/")
    print("\nCSV files generated:")
    print("  - dora_metrics_summary.csv       (All metrics summary)")
    print("  - dora_deployment_frequency.csv  (Deployment frequency)")
    print("  - dora_lead_time.csv             (Lead time for changes)")
    print("  - dora_change_failure_rate.csv   (Change failure rate)")
    print("  - dora_mttr.csv                  (Mean time to recovery)")
    print("\nYou can now analyze the metrics or visualize them!")
    print("=" * 70 + "\n")


if __name__ == "__main__":
    main()
