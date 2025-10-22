#!/usr/bin/env python3
"""
Script pour créer des issues de test avec le label "incident"
"""

import os
from datetime import datetime, timedelta
from github import Github, GithubException
from dotenv import load_dotenv


def create_test_incidents():
    """Crée 3 issues de test avec le label "incident" """

    # Charge les variables d'environnement
    load_dotenv()

    token = os.getenv('GITHUB_TOKEN')
    owner = os.getenv('GITHUB_OWNER')
    repo = os.getenv('GITHUB_REPO')

    if not all([token, owner, repo]):
        print("ERROR: Missing required environment variables")
        print("Please set GITHUB_TOKEN, GITHUB_OWNER, and GITHUB_REPO in .env file")
        return

    print(f"Creating test incidents for {owner}/{repo}...")

    # Connexion à GitHub
    github = Github(token)
    repository = github.get_repo(f"{owner}/{repo}")

    # Vérifie ou crée le label "incident"
    try:
        label = repository.get_label("incident")
        print(f"Label 'incident' already exists")
    except GithubException:
        print("Creating 'incident' label...")
        label = repository.create_label("incident", "d73a4a", "Critical incident requiring immediate attention")

    # Issues à créer
    test_incidents = [
        {
            "title": "Database connection timeout in production",
            "body": """## Incident Description
Users are experiencing intermittent database connection timeouts on the production environment.

## Impact
- Affected users: ~500 users
- Duration: Ongoing
- Severity: High

## Timeline
- Detected: Auto-monitoring alert
- Response: Team notified

## Investigation
- Database metrics review ongoing
- Connection pool configuration being checked
""",
            "close": True  # Cet incident sera fermé pour tester MTTR
        },
        {
            "title": "API rate limiting causing 429 errors",
            "body": """## Incident Description
Third-party API integration is hitting rate limits, causing 429 errors for users.

## Impact
- Affected feature: External data sync
- Users affected: All users using sync feature
- Severity: Medium

## Action Items
- [ ] Contact API provider for limit increase
- [ ] Implement request throttling
- [ ] Add better error handling
""",
            "close": False  # Laissé ouvert
        },
        {
            "title": "Memory leak in background worker process",
            "body": """## Incident Description
Background worker process memory consumption increasing steadily over time.

## Impact
- Service requires periodic restarts
- Processing delays when memory is high
- Severity: Medium

## Investigation
- Memory profiling in progress
- Suspect: Task queue not being cleared properly
- Temporary mitigation: Scheduled restarts every 6 hours
""",
            "close": False  # Laissé ouvert
        }
    ]

    created_issues = []

    for incident_data in test_incidents:
        try:
            print(f"\nCreating issue: {incident_data['title']}")

            # Crée l'issue
            issue = repository.create_issue(
                title=incident_data['title'],
                body=incident_data['body'],
                labels=["incident"]
            )

            created_issues.append(issue)
            print(f"  ✓ Created issue #{issue.number}")
            print(f"    URL: {issue.html_url}")

            # Ferme l'issue si demandé (simule la résolution)
            if incident_data['close']:
                print(f"  ✓ Closing issue #{issue.number} (simulating resolution)")
                issue.edit(state='closed')
                print(f"    Issue closed to simulate MTTR metric")

        except GithubException as e:
            print(f"  ✗ Error creating issue: {e}")

    print("\n" + "=" * 70)
    print(f"Successfully created {len(created_issues)} test incidents!")
    print("=" * 70)
    print("\nIssues created:")
    for issue in created_issues:
        status = "closed" if issue.state == "closed" else "open"
        print(f"  - #{issue.number}: {issue.title} ({status})")
        print(f"    {issue.html_url}")

    print("\nYou can now run the DORA pipeline to calculate metrics:")
    print("  python run_dora_pipeline.py")


def main():
    """Fonction principale"""
    print("=" * 70)
    print("  Creating Test Incidents for DORA Metrics")
    print("=" * 70 + "\n")

    create_test_incidents()


if __name__ == "__main__":
    main()
