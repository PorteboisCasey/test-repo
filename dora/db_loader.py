"""
Script pour charger les données extraites de GitHub dans PostgreSQL
"""

import os
import psycopg2
from psycopg2.extras import execute_values
from typing import List, Dict, Any
from datetime import datetime


class DatabaseLoader:
    def __init__(self, host: str, port: int, dbname: str, user: str, password: str):
        """
        Initialise la connexion à la base de données PostgreSQL

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
            self.cursor = self.conn.cursor()
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

    def load_deployments(self, deployments: List[Dict[str, Any]]) -> int:
        """
        Charge les déploiements dans la base de données

        Args:
            deployments: Liste des déploiements à charger

        Returns:
            Nombre de déploiements insérés
        """
        if not deployments:
            print("No deployments to load.")
            return 0

        print(f"Loading {len(deployments)} deployments...")

        insert_query = """
            INSERT INTO deployments (deployment_id, sha, environment, status, created_at, updated_at, description)
            VALUES %s
            ON CONFLICT (deployment_id) DO UPDATE SET
                status = EXCLUDED.status,
                updated_at = EXCLUDED.updated_at
        """

        values = [
            (
                d['deployment_id'],
                d['sha'],
                d['environment'],
                d['status'],
                d['created_at'],
                d['updated_at'],
                d['description']
            )
            for d in deployments
        ]

        try:
            execute_values(self.cursor, insert_query, values)
            self.conn.commit()
            print(f"Successfully loaded {len(deployments)} deployments")
            return len(deployments)
        except psycopg2.Error as e:
            self.conn.rollback()
            print(f"Error loading deployments: {e}")
            return 0

    def load_commits(self, commits: List[Dict[str, Any]]) -> int:
        """
        Charge les commits dans la base de données

        Args:
            commits: Liste des commits à charger

        Returns:
            Nombre de commits insérés
        """
        if not commits:
            print("No commits to load.")
            return 0

        print(f"Loading {len(commits)} commits...")

        insert_query = """
            INSERT INTO changes (sha, committed_date, author, message)
            VALUES %s
            ON CONFLICT (sha) DO UPDATE SET
                committed_date = EXCLUDED.committed_date,
                author = EXCLUDED.author,
                message = EXCLUDED.message
        """

        values = [
            (
                c['sha'],
                c['committed_date'],
                c['author'],
                c['message']
            )
            for c in commits
        ]

        try:
            execute_values(self.cursor, insert_query, values)
            self.conn.commit()
            print(f"Successfully loaded {len(commits)} commits")
            return len(commits)
        except psycopg2.Error as e:
            self.conn.rollback()
            print(f"Error loading commits: {e}")
            return 0

    def load_incidents(self, incidents: List[Dict[str, Any]]) -> int:
        """
        Charge les incidents dans la base de données

        Args:
            incidents: Liste des incidents à charger

        Returns:
            Nombre d'incidents insérés
        """
        if not incidents:
            print("No incidents to load.")
            return 0

        print(f"Loading {len(incidents)} incidents...")

        insert_query = """
            INSERT INTO incidents (issue_number, title, state, created_at, closed_at, labels, assignees)
            VALUES %s
            ON CONFLICT (issue_number) DO UPDATE SET
                title = EXCLUDED.title,
                state = EXCLUDED.state,
                closed_at = EXCLUDED.closed_at,
                labels = EXCLUDED.labels,
                assignees = EXCLUDED.assignees
        """

        values = [
            (
                i['issue_number'],
                i['title'],
                i['state'],
                i['created_at'],
                i['closed_at'],
                i['labels'],
                i['assignees']
            )
            for i in incidents
        ]

        try:
            execute_values(self.cursor, insert_query, values)
            self.conn.commit()
            print(f"Successfully loaded {len(incidents)} incidents")
            return len(incidents)
        except psycopg2.Error as e:
            self.conn.rollback()
            print(f"Error loading incidents: {e}")
            return 0

    def link_deployment_commits(self):
        """
        Crée les liens entre déploiements et commits
        Simplification : 1 commit = 1 déploiement (le commit SHA du déploiement)
        """
        print("Linking deployments to commits...")

        query = """
            INSERT INTO deployment_commits (deployment_id, commit_id)
            SELECT d.id, c.id
            FROM deployments d
            JOIN changes c ON d.sha = c.sha
            WHERE NOT EXISTS (
                SELECT 1 FROM deployment_commits dc
                WHERE dc.deployment_id = d.id AND dc.commit_id = c.id
            )
        """

        try:
            self.cursor.execute(query)
            self.conn.commit()
            print(f"Successfully linked {self.cursor.rowcount} deployment-commit pairs")
            return self.cursor.rowcount
        except psycopg2.Error as e:
            self.conn.rollback()
            print(f"Error linking deployments and commits: {e}")
            return 0

    def load_all_data(self, data: Dict[str, List[Dict[str, Any]]]):
        """
        Charge toutes les données dans la base de données

        Args:
            data: Dictionnaire contenant deployments, commits et incidents
        """
        print("=" * 70)
        print("Starting database loading...")
        print("=" * 70)

        # Charge les commits d'abord (car les déploiements y font référence)
        commits_loaded = self.load_commits(data.get('commits', []))

        # Charge les déploiements
        deployments_loaded = self.load_deployments(data.get('deployments', []))

        # Crée les liens deployment_commits
        links_created = self.link_deployment_commits()

        # Charge les incidents
        incidents_loaded = self.load_incidents(data.get('incidents', []))

        print("=" * 70)
        print("Loading completed!")
        print(f"  - Commits loaded: {commits_loaded}")
        print(f"  - Deployments loaded: {deployments_loaded}")
        print(f"  - Deployment-Commit links: {links_created}")
        print(f"  - Incidents loaded: {incidents_loaded}")
        print("=" * 70)


def main():
    """Fonction principale pour tester le chargement"""
    from dotenv import load_dotenv
    from github_extractor import GitHubDataExtractor

    # Charge les variables d'environnement
    load_dotenv()

    # Configuration GitHub
    github_token = os.getenv('GITHUB_TOKEN')
    github_owner = os.getenv('GITHUB_OWNER')
    github_repo = os.getenv('GITHUB_REPO')

    # Configuration base de données
    db_host = os.getenv('DB_HOST', 'localhost')
    db_port = int(os.getenv('DB_PORT', 5432))
    db_name = os.getenv('DB_NAME', 'dora_metrics')
    db_user = os.getenv('DB_USER', 'dora_user')
    db_password = os.getenv('DB_PASSWORD', 'dora_password')

    if not all([github_token, github_owner, github_repo]):
        print("Error: Missing required GitHub environment variables")
        return

    # Extrait les données de GitHub
    extractor = GitHubDataExtractor(github_token, github_owner, github_repo)
    data = extractor.extract_all_data()

    # Charge les données dans PostgreSQL
    loader = DatabaseLoader(db_host, db_port, db_name, db_user, db_password)

    try:
        loader.connect()
        loader.load_all_data(data)
    finally:
        loader.disconnect()


if __name__ == "__main__":
    main()
