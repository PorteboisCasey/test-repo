"""
Script pour extraire les données de l'API GitHub
- Deployments (avec status et environnement)
- Commits (changes)
- Issues avec label "incident"
"""

import os
from datetime import datetime, timezone
from github import Github, GithubException
from typing import List, Dict, Any


class GitHubDataExtractor:
    def __init__(self, token: str, owner: str, repo: str):
        """
        Initialise l'extracteur de données GitHub

        Args:
            token: GitHub personal access token
            owner: Propriétaire du repository
            repo: Nom du repository
        """
        self.github = Github(token)
        self.repo = self.github.get_repo(f"{owner}/{repo}")
        self.owner = owner
        self.repo_name = repo

    def get_deployments(self, environment: str = "production") -> List[Dict[str, Any]]:
        """
        Récupère tous les déploiements avec leurs statuts

        Args:
            environment: Environnement de déploiement (par défaut: production)

        Returns:
            Liste de dictionnaires contenant les informations des déploiements
        """
        print(f"Fetching deployments for {self.owner}/{self.repo_name}...")
        deployments_data = []

        try:
            # Récupère tous les déploiements
            deployments = self.repo.get_deployments()

            for deployment in deployments:
                # Filtre par environnement si spécifié
                if environment and deployment.environment != environment:
                    continue

                # Récupère les statuts du déploiement
                statuses = deployment.get_statuses()
                latest_status = None

                try:
                    # Prend le statut le plus récent
                    latest_status = statuses[0] if statuses.totalCount > 0 else None
                except (IndexError, GithubException):
                    pass

                deployment_info = {
                    'deployment_id': deployment.id,
                    'sha': deployment.sha,
                    'environment': deployment.environment,
                    'status': latest_status.state if latest_status else 'pending',
                    'created_at': deployment.created_at,
                    'updated_at': latest_status.created_at if latest_status else deployment.created_at,
                    'description': deployment.description or ''
                }

                deployments_data.append(deployment_info)
                print(f"  Found deployment {deployment.id}: {deployment.sha[:7]} - {deployment_info['status']}")

        except GithubException as e:
            print(f"Error fetching deployments: {e}")

        print(f"Total deployments found: {len(deployments_data)}")
        return deployments_data

    def get_commits(self, limit: int = 100) -> List[Dict[str, Any]]:
        """
        Récupère les commits du repository

        Args:
            limit: Nombre maximum de commits à récupérer

        Returns:
            Liste de dictionnaires contenant les informations des commits
        """
        print(f"Fetching commits for {self.owner}/{self.repo_name}...")
        commits_data = []

        try:
            commits = self.repo.get_commits()

            for i, commit in enumerate(commits[:limit]):
                commit_info = {
                    'sha': commit.sha,
                    'committed_date': commit.commit.author.date,
                    'author': commit.commit.author.name if commit.commit.author else 'Unknown',
                    'message': commit.commit.message
                }

                commits_data.append(commit_info)

                if (i + 1) % 10 == 0:
                    print(f"  Processed {i + 1} commits...")

        except GithubException as e:
            print(f"Error fetching commits: {e}")

        print(f"Total commits found: {len(commits_data)}")
        return commits_data

    def get_incidents(self, label: str = "incident") -> List[Dict[str, Any]]:
        """
        Récupère les issues avec le label spécifié (incidents)

        Args:
            label: Label à filtrer (par défaut: incident)

        Returns:
            Liste de dictionnaires contenant les informations des incidents
        """
        print(f"Fetching incidents (issues with label '{label}')...")
        incidents_data = []

        try:
            # Récupère toutes les issues (ouvertes et fermées) avec le label
            issues = self.repo.get_issues(state='all', labels=[label])

            for issue in issues:
                incident_info = {
                    'issue_number': issue.number,
                    'title': issue.title,
                    'state': issue.state,
                    'created_at': issue.created_at,
                    'closed_at': issue.closed_at,
                    'labels': [label.name for label in issue.labels],
                    'assignees': [assignee.login for assignee in issue.assignees]
                }

                incidents_data.append(incident_info)
                print(f"  Found incident #{issue.number}: {issue.title} ({issue.state})")

        except GithubException as e:
            print(f"Error fetching incidents: {e}")

        print(f"Total incidents found: {len(incidents_data)}")
        return incidents_data

    def extract_all_data(self) -> Dict[str, List[Dict[str, Any]]]:
        """
        Extrait toutes les données nécessaires pour les métriques DORA

        Returns:
            Dictionnaire contenant deployments, commits et incidents
        """
        print("=" * 70)
        print("Starting GitHub data extraction...")
        print("=" * 70)

        data = {
            'deployments': self.get_deployments(),
            'commits': self.get_commits(),
            'incidents': self.get_incidents()
        }

        print("=" * 70)
        print("Extraction completed!")
        print(f"  - Deployments: {len(data['deployments'])}")
        print(f"  - Commits: {len(data['commits'])}")
        print(f"  - Incidents: {len(data['incidents'])}")
        print("=" * 70)

        return data


def main():
    """Fonction principale pour tester l'extraction"""
    from dotenv import load_dotenv

    # Charge les variables d'environnement
    load_dotenv()

    token = os.getenv('GITHUB_TOKEN')
    owner = os.getenv('GITHUB_OWNER')
    repo = os.getenv('GITHUB_REPO')

    if not all([token, owner, repo]):
        print("Error: Missing required environment variables")
        print("Please set GITHUB_TOKEN, GITHUB_OWNER, and GITHUB_REPO in .env file")
        return

    # Crée l'extracteur et récupère les données
    extractor = GitHubDataExtractor(token, owner, repo)
    data = extractor.extract_all_data()

    # Affiche un résumé
    print("\nData extraction summary:")
    for key, items in data.items():
        print(f"  {key}: {len(items)} items")


if __name__ == "__main__":
    main()
