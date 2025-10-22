-- ============================================================================
-- REQUÊTES DORA CONFORMES AUX SPÉCIFICATIONS FOUR KEYS
-- Fenêtre de 28 jours glissants
-- Utilise PERCENTILE_CONT pour les médianes (LTC, MTTR)
-- ============================================================================

-- ============================================================================
-- 1. DEPLOYMENT FREQUENCY (DF)
-- Nombre de déploiements production réussis par jour
-- ============================================================================

SELECT
    COUNT(*) as total_deployments,
    ROUND(COUNT(*)::NUMERIC / 28.0, 2) as deployments_per_day,
    ROUND(COUNT(*)::NUMERIC / 4.0, 2) as deployments_per_week
FROM deployments
WHERE
    status = 'success'
    AND environment = 'production'
    AND created_at >= CURRENT_DATE - INTERVAL '28 days';


-- ============================================================================
-- 2. LEAD TIME FOR CHANGES (LTC)
-- MÉDIANE du temps entre commit et déploiement en production (en heures)
-- Conforme Four Keys : utilise PERCENTILE_CONT (médiane) et non AVG
-- ============================================================================

WITH lead_times AS (
    SELECT
        EXTRACT(EPOCH FROM (d.created_at - c.committed_date)) / 3600 as lead_time_hours
    FROM deployments d
    JOIN deployment_commits dc ON d.id = dc.deployment_id
    JOIN changes c ON dc.commit_id = c.id
    WHERE
        d.status = 'success'
        AND d.environment = 'production'
        AND d.created_at >= CURRENT_DATE - INTERVAL '28 days'
)
SELECT
    COUNT(*) as total_changes,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY lead_time_hours)::NUMERIC, 2) as median_lead_time_hours,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY lead_time_hours) / 24)::NUMERIC, 2) as median_lead_time_days,
    ROUND(MIN(lead_time_hours)::NUMERIC, 2) as min_lead_time_hours,
    ROUND(MAX(lead_time_hours)::NUMERIC, 2) as max_lead_time_hours,
    ROUND(AVG(lead_time_hours)::NUMERIC, 2) as avg_lead_time_hours
FROM lead_times;


-- ============================================================================
-- 3. CHANGE FAILURE RATE (CFR)
-- Pourcentage de déploiements qui ont causé au moins 1 incident
-- Conforme Four Keys : lie les incidents aux déploiements
-- ============================================================================

WITH deployment_stats AS (
    SELECT
        d.id,
        d.deployment_id,
        d.sha,
        d.created_at,
        COUNT(i.id) as incident_count
    FROM deployments d
    LEFT JOIN incidents i ON d.id = i.deploy_id
        AND i.created_at >= d.created_at
        AND i.created_at <= d.created_at + INTERVAL '24 hours'  -- Incident dans les 24h du déploiement
    WHERE
        d.status = 'success'
        AND d.environment = 'production'
        AND d.created_at >= CURRENT_DATE - INTERVAL '28 days'
    GROUP BY d.id, d.deployment_id, d.sha, d.created_at
)
SELECT
    COUNT(*) as total_deployments,
    COUNT(*) FILTER (WHERE incident_count > 0) as deployments_with_incidents,
    COUNT(*) FILTER (WHERE incident_count = 0) as deployments_without_incidents,
    CASE
        WHEN COUNT(*) > 0 THEN
            ROUND((COUNT(*) FILTER (WHERE incident_count > 0)::NUMERIC / COUNT(*)::NUMERIC) * 100, 2)
        ELSE 0
    END as change_failure_rate_percentage
FROM deployment_stats;


-- ============================================================================
-- 4. MEAN TIME TO RECOVERY (MTTR)
-- MÉDIANE du temps de résolution des incidents (en heures)
-- Conforme Four Keys : utilise PERCENTILE_CONT (médiane) et non AVG
-- ============================================================================

WITH recovery_times AS (
    SELECT
        issue_number,
        EXTRACT(EPOCH FROM (closed_at - created_at)) / 3600 as recovery_time_hours
    FROM incidents
    WHERE
        state = 'closed'
        AND closed_at IS NOT NULL
        AND created_at >= CURRENT_DATE - INTERVAL '28 days'
)
SELECT
    COUNT(*) as total_resolved_incidents,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY recovery_time_hours)::NUMERIC, 2) as median_recovery_time_hours,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY recovery_time_hours) / 24)::NUMERIC, 2) as median_recovery_time_days,
    ROUND(MIN(recovery_time_hours)::NUMERIC, 2) as min_recovery_time_hours,
    ROUND(MAX(recovery_time_hours)::NUMERIC, 2) as max_recovery_time_hours,
    ROUND(AVG(recovery_time_hours)::NUMERIC, 2) as avg_recovery_time_hours
FROM recovery_times;


-- ============================================================================
-- DASHBOARD SUMMARY - Les 4 métriques DORA en une seule requête
-- Conforme aux spécifications Four Keys
-- ============================================================================

WITH
-- DF: Deployment Frequency
deployment_frequency AS (
    SELECT
        COUNT(*) as total_deployments,
        ROUND(COUNT(*)::NUMERIC / 28.0, 2) as deployments_per_day
    FROM deployments
    WHERE
        status = 'success'
        AND environment = 'production'
        AND created_at >= CURRENT_DATE - INTERVAL '28 days'
),
-- LTC: Lead Time for Changes (MEDIAN)
lead_time AS (
    SELECT
        ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY EXTRACT(EPOCH FROM (d.created_at - c.committed_date)) / 3600
        )::NUMERIC, 2) as median_hours
    FROM deployments d
    JOIN deployment_commits dc ON d.id = dc.deployment_id
    JOIN changes c ON dc.commit_id = c.id
    WHERE
        d.status = 'success'
        AND d.environment = 'production'
        AND d.created_at >= CURRENT_DATE - INTERVAL '28 days'
),
-- CFR: Change Failure Rate (déploiements causant incidents)
failure_rate AS (
    SELECT
        CASE
            WHEN COUNT(*) > 0 THEN
                ROUND((COUNT(*) FILTER (
                    WHERE EXISTS (
                        SELECT 1 FROM incidents i
                        WHERE i.deploy_id = d.id
                    )
                )::NUMERIC / COUNT(*)::NUMERIC) * 100, 2)
            ELSE 0
        END as failure_percentage
    FROM deployments d
    WHERE
        d.status = 'success'
        AND d.environment = 'production'
        AND d.created_at >= CURRENT_DATE - INTERVAL '28 days'
),
-- MTTR: Mean Time to Recovery (MEDIAN)
recovery_time AS (
    SELECT
        ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY EXTRACT(EPOCH FROM (closed_at - created_at)) / 3600
        )::NUMERIC, 2) as median_hours
    FROM incidents
    WHERE
        state = 'closed'
        AND closed_at IS NOT NULL
        AND created_at >= CURRENT_DATE - INTERVAL '28 days'
)
SELECT
    'DORA Metrics (28 days - Four Keys Method)' as metric_period,
    df.total_deployments as "1_DF_Total_Deployments",
    df.deployments_per_day as "1_DF_Deployments_Per_Day",
    COALESCE(lt.median_hours, 0) as "2_LTC_Median_Lead_Time_Hours",
    fr.failure_percentage as "3_CFR_Failure_Rate_%",
    COALESCE(rt.median_hours, 0) as "4_MTTR_Median_Recovery_Hours"
FROM deployment_frequency df
CROSS JOIN lead_time lt
CROSS JOIN failure_rate fr
CROSS JOIN recovery_time rt;


-- ============================================================================
-- ANALYSE DÉTAILLÉE PAR DÉPLOIEMENT
-- Pour comprendre quels déploiements ont causé des incidents
-- ============================================================================

SELECT
    d.deployment_id,
    d.sha as deployment_sha,
    d.created_at as deployed_at,
    d.status,
    COUNT(i.id) as incidents_count,
    STRING_AGG(i.issue_number::TEXT, ', ' ORDER BY i.created_at) as incident_numbers,
    MIN(i.created_at) as first_incident_at,
    MAX(i.closed_at) as last_incident_resolved_at
FROM deployments d
LEFT JOIN incidents i ON d.id = i.deploy_id
WHERE
    d.environment = 'production'
    AND d.created_at >= CURRENT_DATE - INTERVAL '28 days'
GROUP BY d.id, d.deployment_id, d.sha, d.created_at, d.status
ORDER BY d.created_at DESC;
