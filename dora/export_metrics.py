"""
Script pour exporter les métriques DORA en CSV
"""

import os
import csv
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime
from typing import List, Dict, Any


class MetricsExporter:
    def __init__(self, host: str, port: int, dbname: str, user: str, password: str):
        """
        Initialise l'exporteur de métriques

        Args:
            host: Hôte de la base de données
            port: Port de la base de données
            dbname: Nom de la base de données
            user: Nom d'utilisateur
            password: Mot de passe
        """
        self.conn_params = {
            'host': host,
            'port': port,
            'dbname': dbname,
            'user': user,
            'password': password
        }
        self.conn = None
        self.cursor = None

    def connect(self):
        """Établit la connexion à la base de données"""
        try:
            print("Connecting to PostgreSQL database...")
            self.conn = psycopg2.connect(**self.conn_params)
            self.cursor = self.conn.cursor(cursor_factory=RealDictCursor)
            print("Connection established successfully!")
        except psycopg2.Error as e:
            print(f"Error connecting to database: {e}")
            raise

    def disconnect(self):
        """Ferme la connexion à la base de données"""
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.close()
            print("Database connection closed.")

    def export_to_csv(self, query: str, filename: str, headers: List[str] = None):
        """
        Exécute une requête et exporte le résultat en CSV

        Args:
            query: Requête SQL à exécuter
            filename: Nom du fichier CSV de sortie
            headers: En-têtes personnalisés (optionnel)
        """
        try:
            self.cursor.execute(query)
            rows = self.cursor.fetchall()

            if not rows:
                print(f"No data to export for {filename}")
                return

            # Utilise les noms de colonnes de la requête si headers non fourni
            if not headers:
                headers = rows[0].keys()

            with open(filename, 'w', newline='', encoding='utf-8') as csvfile:
                writer = csv.DictWriter(csvfile, fieldnames=headers)
                writer.writeheader()
                writer.writerows(rows)

            print(f"Exported {len(rows)} rows to {filename}")

        except psycopg2.Error as e:
            print(f"Error exporting data: {e}")
        except IOError as e:
            print(f"Error writing to file {filename}: {e}")

    def export_deployment_frequency(self, output_dir: str = "."):
        """Exporte les métriques de fréquence de déploiement"""
        query = """
            SELECT
                COUNT(*) as total_successful_deployments,
                COUNT(*) / 28.0 as deployments_per_day,
                ROUND(COUNT(*) / 4.0, 2) as deployments_per_week
            FROM deployments
            WHERE
                status = 'success'
                AND environment = 'production'
                AND created_at >= CURRENT_DATE - INTERVAL '28 days'
        """
        filename = os.path.join(output_dir, "dora_deployment_frequency.csv")
        self.export_to_csv(query, filename)

    def export_lead_time(self, output_dir: str = "."):
        """Exporte les métriques de lead time"""
        query = """
            SELECT
                d.deployment_id,
                d.sha as deployment_sha,
                d.created_at as deployed_at,
                c.sha as commit_sha,
                c.committed_date,
                ROUND(EXTRACT(EPOCH FROM (d.created_at - c.committed_date)) / 3600, 2) as lead_time_hours,
                ROUND(EXTRACT(EPOCH FROM (d.created_at - c.committed_date)) / 86400, 2) as lead_time_days
            FROM deployments d
            JOIN deployment_commits dc ON d.id = dc.deployment_id
            JOIN changes c ON dc.commit_id = c.id
            WHERE
                d.status = 'success'
                AND d.environment = 'production'
                AND d.created_at >= CURRENT_DATE - INTERVAL '28 days'
            ORDER BY d.created_at DESC
        """
        filename = os.path.join(output_dir, "dora_lead_time.csv")
        self.export_to_csv(query, filename)

    def export_change_failure_rate(self, output_dir: str = "."):
        """Exporte les métriques de taux d'échec"""
        query = """
            WITH deployment_stats AS (
                SELECT
                    COUNT(*) as total_deployments,
                    COUNT(*) FILTER (WHERE status = 'success') as successful_deployments,
                    COUNT(*) FILTER (WHERE status IN ('failure', 'error')) as failed_deployments
                FROM deployments
                WHERE
                    environment = 'production'
                    AND created_at >= CURRENT_DATE - INTERVAL '28 days'
            )
            SELECT
                total_deployments,
                successful_deployments,
                failed_deployments,
                CASE
                    WHEN total_deployments > 0 THEN
                        ROUND((failed_deployments::NUMERIC / total_deployments::NUMERIC) * 100, 2)
                    ELSE 0
                END as failure_rate_percentage
            FROM deployment_stats
        """
        filename = os.path.join(output_dir, "dora_change_failure_rate.csv")
        self.export_to_csv(query, filename)

    def export_mttr(self, output_dir: str = "."):
        """Exporte les métriques de temps de récupération"""
        query = """
            SELECT
                issue_number,
                title,
                state,
                created_at,
                closed_at,
                CASE
                    WHEN closed_at IS NOT NULL THEN
                        ROUND(EXTRACT(EPOCH FROM (closed_at - created_at)) / 3600, 2)
                    ELSE NULL
                END as recovery_time_hours,
                CASE
                    WHEN closed_at IS NOT NULL THEN
                        ROUND(EXTRACT(EPOCH FROM (closed_at - created_at)) / 86400, 2)
                    ELSE NULL
                END as recovery_time_days
            FROM incidents
            WHERE created_at >= CURRENT_DATE - INTERVAL '28 days'
            ORDER BY created_at DESC
        """
        filename = os.path.join(output_dir, "dora_mttr.csv")
        self.export_to_csv(query, filename)

    def export_summary(self, output_dir: str = "."):
        """Exporte un résumé de toutes les métriques DORA"""
        query = """
            WITH
            deployment_frequency AS (
                SELECT
                    COUNT(*) as total_deployments,
                    ROUND(COUNT(*) / 28.0, 2) as deployments_per_day
                FROM deployments
                WHERE
                    status = 'success'
                    AND environment = 'production'
                    AND created_at >= CURRENT_DATE - INTERVAL '28 days'
            ),
            lead_time AS (
                SELECT
                    ROUND(AVG(EXTRACT(EPOCH FROM (d.created_at - c.committed_date)) / 3600), 2) as avg_hours
                FROM deployments d
                JOIN deployment_commits dc ON d.id = dc.deployment_id
                JOIN changes c ON dc.commit_id = c.id
                WHERE
                    d.status = 'success'
                    AND d.environment = 'production'
                    AND d.created_at >= CURRENT_DATE - INTERVAL '28 days'
            ),
            failure_rate AS (
                SELECT
                    CASE
                        WHEN COUNT(*) > 0 THEN
                            ROUND((COUNT(*) FILTER (WHERE status IN ('failure', 'error'))::NUMERIC / COUNT(*)::NUMERIC) * 100, 2)
                        ELSE 0
                    END as failure_percentage
                FROM deployments
                WHERE
                    environment = 'production'
                    AND created_at >= CURRENT_DATE - INTERVAL '28 days'
            ),
            recovery_time AS (
                SELECT
                    ROUND(AVG(EXTRACT(EPOCH FROM (closed_at - created_at)) / 3600), 2) as avg_hours
                FROM incidents
                WHERE
                    state = 'closed'
                    AND closed_at IS NOT NULL
                    AND created_at >= CURRENT_DATE - INTERVAL '28 days'
            )
            SELECT
                'Last 28 days' as metric_period,
                df.total_deployments as deployment_frequency_total,
                df.deployments_per_day as deployment_frequency_per_day,
                lt.avg_hours as lead_time_avg_hours,
                fr.failure_percentage as change_failure_rate_percent,
                rt.avg_hours as mttr_avg_hours
            FROM deployment_frequency df, lead_time lt, failure_rate fr, recovery_time rt
        """
        filename = os.path.join(output_dir, "dora_metrics_summary.csv")
        self.export_to_csv(query, filename)

    def export_all_metrics(self, output_dir: str = "."):
        """Exporte toutes les métriques DORA"""
        print("=" * 70)
        print("Exporting DORA metrics to CSV files...")
        print("=" * 70)

        # Crée le répertoire de sortie s'il n'existe pas
        os.makedirs(output_dir, exist_ok=True)

        self.export_deployment_frequency(output_dir)
        self.export_lead_time(output_dir)
        self.export_change_failure_rate(output_dir)
        self.export_mttr(output_dir)
        self.export_summary(output_dir)

        print("=" * 70)
        print(f"All metrics exported to {output_dir}")
        print("=" * 70)


def main():
    """Fonction principale"""
    from dotenv import load_dotenv

    # Charge les variables d'environnement
    load_dotenv()

    # Configuration base de données
    db_host = os.getenv('DB_HOST', 'localhost')
    db_port = int(os.getenv('DB_PORT', 5432))
    db_name = os.getenv('DB_NAME', 'dora_metrics')
    db_user = os.getenv('DB_USER', 'dora_user')
    db_password = os.getenv('DB_PASSWORD', 'dora_password')

    # Répertoire de sortie pour les CSV
    output_dir = "exports"

    exporter = MetricsExporter(db_host, db_port, db_name, db_user, db_password)

    try:
        exporter.connect()
        exporter.export_all_metrics(output_dir)
    finally:
        exporter.disconnect()


if __name__ == "__main__":
    main()
