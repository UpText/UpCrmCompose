SET NOCOUNT ON;

IF NOT EXISTS
(
    SELECT 1
    FROM crm.contact_notes
    WHERE tenant = N'demo'
      AND contact_id = 2
      AND sales_id = 3
      AND text = N'Welcome to the demo workspace. This seeded note unlocks the dashboard on first login.'
)
BEGIN
    INSERT INTO crm.contact_notes
    (
        tenant,
        contact_id,
        sales_id,
        date,
        text
    )
    VALUES
    (
        N'demo',
        2,
        3,
        '2026-05-15T08:30:00',
        N'Welcome to the demo workspace. This seeded note unlocks the dashboard on first login.'
    );
END;
