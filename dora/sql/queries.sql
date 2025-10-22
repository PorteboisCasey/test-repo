-- DORA Metrics Queries (28-day rolling window)

-- =============================================================================
-- 1. DEPLOYMENT FREQUENCY (DF)
-- Mesure la fréquence de déploiement en production
-- Calcule le nombre de déploiements réussis dans les 28 derniers jours
-- =============================================================================

-- Version simple : Nombre total de déploiements réussis
SELECT
    COUNT(*) as total_successful_deployments,
    COUNT(*) / 28.0 as deployments_per_day,
    ROUND(COUNT(*) / 4.0, 2) as deployments_per_week
FROM deployments
WHERE
    status = 'success'
    AND environment = 'production'
    AND created_at >= CURRENT_DATE - INTERVAL '28 days';

-- Version détaillée : Déploiements par jour
SELECT
    DATE(created_at) as deployment_date,
    COUNT(*) as deployments_count
FROM deployments
WHERE
    status = 'success'
    AND environment = 'production'
    AND created_at >= CURRENT_DATE - INTERVAL '28 days'
GROUP BY DATE(created_at)
ORDER BY deployment_date DESC;


-- =============================================================================
-- 2. LEAD TIME FOR CHANGES (LTC)
-- Mesure le temps entre le commit et le déploiement en production
-- Temps moyen en heures et jours
-- =============================================================================

-- Version simple : Temps moyen global
SELECT
    COUNT(*) as total_changes,
    ROUND(AVG(EXTRACT(EPOCH FROM (d.created_at - c.committed_date)) / 3600), 2) as avg_lead_time_hours,
    ROUND(AVG(EXTRACT(EPOCH FROM (d.created_at - c.committed_date)) / 86400), 2) as avg_lead_time_days,
    ROUND(MIN(EXTRACT(EPOCH FROM (d.created_at - c.committed_date)) / 3600), 2) as min_lead_time_hours,
    ROUND(MAX(EXTRACT(EPOCH FROM (d.created_at - c.committed_date)) / 3600), 2) as max_lead_time_hours
FROM deployments d
JOIN deployment_commits dc ON d.id = dc.deployment_id
JOIN changes c ON dc.commit_id = c.id
WHERE
    d.status = 'success'
    AND d.environment = 'production'
    AND d.created_at >= CURRENT_DATE - INTERVAL '28 days';

-- Version détaillée : Lead time par déploiement
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
ORDER BY d.created_at DESC;


-- =============================================================================
-- 3. CHANGE FAILURE RATE (CFR)
-- Mesure le pourcentage de déploiements qui échouent en production
-- Ratio échecs / total déploiements
-- =============================================================================

-- Version complète avec tous les détails
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
FROM deployment_stats;

-- Version avec détails des échecs
SELECT
    deployment_id,
    sha,
    status,
    created_at,
    description
FROM deployments
WHERE
    status IN ('failure', 'error')
    AND environment = 'production'
    AND created_at >= CURRENT_DATE - INTERVAL '28 days'
ORDER BY created_at DESC;


-- =============================================================================
-- 4. MEAN TIME TO RECOVERY (MTTR)
-- Mesure le temps moyen pour résoudre un incident
-- Calcule la durée moyenne entre la création et la résolution d'un incident
-- =============================================================================

-- Version simple : Temps moyen de récupération
SELECT
    COUNT(*) as total_resolved_incidents,
    ROUND(AVG(EXTRACT(EPOCH FROM (closed_at - created_at)) / 3600), 2) as avg_recovery_time_hours,
    ROUND(AVG(EXTRACT(EPOCH FROM (closed_at - created_at)) / 86400), 2) as avg_recovery_time_days,
    ROUND(MIN(EXTRACT(EPOCH FROM (closed_at - created_at)) / 3600), 2) as min_recovery_time_hours,
    ROUND(MAX(EXTRACT(EPOCH FROM (closed_at - created_at)) / 86400), 2) as max_recovery_time_days
FROM incidents
WHERE
    state = 'closed'
    AND closed_at IS NOT NULL
    AND created_at >= CURRENT_DATE - INTERVAL '28 days';

-- Version détaillée : Liste des incidents avec temps de récupération
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
ORDER BY created_at DESC;

-- Incidents encore ouverts (non résolus)
SELECT
    issue_number,
    title,
    created_at,
    ROUND(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - created_at)) / 3600, 2) as open_duration_hours,
    ROUND(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - created_at)) / 86400, 2) as open_duration_days
FROM incidents
WHERE
    state = 'open'
    AND created_at >= CURRENT_DATE - INTERVAL '28 days'
ORDER BY created_at ASC;


-- =============================================================================
-- DASHBOARD SUMMARY - Vue d'ensemble des 4 métriques DORA
-- =============================================================================

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
    'DORA Metrics Summary (28 days)' as metric_period,
    df.total_deployments as "1_DF_Total_Deployments",
    df.deployments_per_day as "1_DF_Deployments_Per_Day",
    lt.avg_hours as "2_LTC_Avg_Lead_Time_Hours",
    fr.failure_percentage as "3_CFR_Failure_Rate_%",
    rt.avg_hours as "4_MTTR_Avg_Recovery_Hours"
FROM deployment_frequency df, lead_time lt, failure_rate fr, recovery_time rt;
