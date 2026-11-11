-- Revenue by device type
WITH revenue_usd AS (
SELECT
    sp.continent AS continent
    ,SUM(p.price) AS revenue
    ,SUM(CASE WHEN sp.device = 'mobile' THEN p.price ELSE 0 END) AS revenue_from_mobile
    ,SUM(CASE WHEN sp.device = 'desktop' THEN p.price ELSE 0 END) AS revenue_from_desktop
FROM `DA.order` o
JOIN `DA.product` p ON o.item_id=p.item_id
JOIN `DA.session_params` sp ON o.ga_session_id=sp.ga_session_id
GROUP BY sp.continent
),

-- Unique sessions and accounts per continent
registrations AS (
SELECT
    sp.continent AS continent
    ,COUNT(DISTINCT sp.ga_session_id) AS session_cnt
    ,COUNT(DISTINCT acs.account_id) AS account_cnt
FROM `DA.session_params` sp
LEFT JOIN `DA.account_session` acs ON sp.ga_session_id=acs.ga_session_id
GROUP BY sp.continent
),

-- Unique verified accounts per continent
verified AS (
SELECT
    sp.continent
    ,COUNT(DISTINCT a.id) AS verified_account
FROM `DA.account` a
JOIN `DA.account_session` acs ON a.id=acs.account_id
JOIN `DA.session_params` sp ON acs.ga_session_id=sp.ga_session_id
WHERE a.is_verified = 1
GROUP BY sp.continent
)


SELECT
    registrations.continent

    -- Revenue metrics
    ,COALESCE(ROUND(revenue_usd.revenue,2), 0) AS revenue
    ,COALESCE(ROUND(revenue_usd.revenue_from_mobile,2), 0) AS revenue_from_mobile
    ,COALESCE(ROUND(revenue_usd.revenue_from_desktop,2), 0) AS revenue_from_desktop

    -- Percentage of total attributed revenue
    ,ROUND(
        SAFE_DIVIDE(
            revenue_usd.revenue,
            SUM(revenue_usd.revenue) OVER ()
        ) * 100, 2
    ) AS percent_revenue_from_total

    -- Session and account metrics
    ,registrations.session_cnt
    ,registrations.account_cnt
    ,COALESCE(verified.verified_account, 0) AS verified_account

    -- Share of verified accounts
    ,ROUND(
        SAFE_DIVIDE(
            COALESCE(verified.verified_account, 0),
            registrations.account_cnt
        ) * 100, 2
    ) AS verification_rate

    -- Revenue per session
    ,ROUND(
        SAFE_DIVIDE(
            revenue_usd.revenue,
            registrations.session_cnt
        ), 2
    ) AS revenue_per_session

FROM registrations
LEFT JOIN revenue_usd ON registrations.continent=revenue_usd.continent
LEFT JOIN verified ON registrations.continent=verified.continent
ORDER BY revenue DESC;
