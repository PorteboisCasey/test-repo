-- DORA Metrics Database Schema

-- Table pour stocker les déploiements
CREATE TABLE IF NOT EXISTS deployments (
    id SERIAL PRIMARY KEY,
    deployment_id BIGINT UNIQUE NOT NULL,
    sha VARCHAR(40) NOT NULL,
    environment VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP,
    description TEXT,
    CONSTRAINT chk_status CHECK (status IN ('pending', 'success', 'failure', 'error', 'inactive'))
);

-- Table pour stocker les commits/changes
CREATE TABLE IF NOT EXISTS changes (
    id SERIAL PRIMARY KEY,
    sha VARCHAR(40) UNIQUE NOT NULL,
    committed_date TIMESTAMP NOT NULL,
    author VARCHAR(255),
    message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table de liaison entre déploiements et commits
CREATE TABLE IF NOT EXISTS deployment_commits (
    id SERIAL PRIMARY KEY,
    deployment_id INTEGER REFERENCES deployments(id) ON DELETE CASCADE,
    commit_id INTEGER REFERENCES changes(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(deployment_id, commit_id)
);

-- Table pour stocker les incidents (issues avec label "incident")
CREATE TABLE IF NOT EXISTS incidents (
    id SERIAL PRIMARY KEY,
    issue_number INTEGER UNIQUE NOT NULL,
    title TEXT NOT NULL,
    state VARCHAR(20) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    closed_at TIMESTAMP,
    labels TEXT[],
    assignees TEXT[],
    CONSTRAINT chk_state CHECK (state IN ('open', 'closed'))
);

-- Index pour améliorer les performances des requêtes
CREATE INDEX IF NOT EXISTS idx_deployments_created_at ON deployments(created_at);
CREATE INDEX IF NOT EXISTS idx_deployments_status ON deployments(status);
CREATE INDEX IF NOT EXISTS idx_deployments_environment ON deployments(environment);
CREATE INDEX IF NOT EXISTS idx_changes_committed_date ON changes(committed_date);
CREATE INDEX IF NOT EXISTS idx_incidents_created_at ON incidents(created_at);
CREATE INDEX IF NOT EXISTS idx_incidents_closed_at ON incidents(closed_at);
CREATE INDEX IF NOT EXISTS idx_incidents_state ON incidents(state);

-- Vue pour faciliter l'analyse des déploiements avec leurs commits
CREATE OR REPLACE VIEW deployment_details AS
SELECT
    d.id as deployment_id,
    d.deployment_id as github_deployment_id,
    d.sha as deployment_sha,
    d.environment,
    d.status,
    d.created_at as deployed_at,
    c.sha as commit_sha,
    c.committed_date,
    c.author,
    c.message as commit_message
FROM deployments d
LEFT JOIN deployment_commits dc ON d.id = dc.deployment_id
LEFT JOIN changes c ON dc.commit_id = c.id
ORDER BY d.created_at DESC, c.committed_date DESC;

-- Commentaires pour documentation
COMMENT ON TABLE deployments IS 'Stocke les déploiements créés via GitHub API';
COMMENT ON TABLE changes IS 'Stocke les commits/changements du repository';
COMMENT ON TABLE deployment_commits IS 'Table de liaison many-to-many entre déploiements et commits';
COMMENT ON TABLE incidents IS 'Stocke les incidents (issues GitHub avec label "incident")';
