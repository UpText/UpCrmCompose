SET NOCOUNT ON;

-- Keep these values aligned with the CRM root/defaultConfiguration.ts.
-- Logo URLs are supplied by the frontend build so asset hashes remain valid.
DECLARE @DemoConfiguration NVARCHAR(MAX) = N'{
  "title": "Demo CRM",
  "currency": "USD",
  "companySectors": [
    {
      "value": "communication-services",
      "label": "Communication Services"
    },
    {
      "value": "consumer-discretionary",
      "label": "Consumer Discretionary"
    },
    {
      "value": "consumer-staples",
      "label": "Consumer Staples"
    },
    {
      "value": "energy",
      "label": "Energy"
    },
    {
      "value": "financials",
      "label": "Financials"
    },
    {
      "value": "health-care",
      "label": "Health Care"
    },
    {
      "value": "industrials",
      "label": "Industrials"
    },
    {
      "value": "information-technology",
      "label": "Information Technology"
    },
    {
      "value": "materials",
      "label": "Materials"
    },
    {
      "value": "real-estate",
      "label": "Real Estate"
    },
    {
      "value": "utilities",
      "label": "Utilities"
    }
  ],
  "dealStages": [
    {
      "value": "opportunity",
      "label": "Opportunity"
    },
    {
      "value": "proposal-sent",
      "label": "Proposal Sent"
    },
    {
      "value": "in-negociation",
      "label": "In Negotiation"
    },
    {
      "value": "won",
      "label": "Won"
    },
    {
      "value": "lost",
      "label": "Lost"
    },
    {
      "value": "delayed",
      "label": "Delayed"
    }
  ],
  "dealPipelineStatuses": [
    "won"
  ],
  "dealCategories": [
    {
      "value": "other",
      "label": "Other"
    },
    {
      "value": "copywriting",
      "label": "Copywriting"
    },
    {
      "value": "print-project",
      "label": "Print project"
    },
    {
      "value": "ui-design",
      "label": "UI Design"
    },
    {
      "value": "website-design",
      "label": "Website design"
    }
  ],
  "noteStatuses": [
    {
      "value": "cold",
      "label": "Cold",
      "color": "#7dbde8"
    },
    {
      "value": "warm",
      "label": "Warm",
      "color": "#e8cb7d"
    },
    {
      "value": "hot",
      "label": "Hot",
      "color": "#e88b7d"
    },
    {
      "value": "in-contract",
      "label": "In Contract",
      "color": "#a4e87d"
    }
  ],
  "taskTypes": [
    {
      "value": "none",
      "label": "None"
    },
    {
      "value": "email",
      "label": "Email"
    },
    {
      "value": "demo",
      "label": "Demo"
    },
    {
      "value": "lunch",
      "label": "Lunch"
    },
    {
      "value": "meeting",
      "label": "Meeting"
    },
    {
      "value": "follow-up",
      "label": "Follow-up"
    },
    {
      "value": "thank-you",
      "label": "Thank you"
    },
    {
      "value": "ship",
      "label": "Ship"
    },
    {
      "value": "call",
      "label": "Call"
    }
  ]
}';

MERGE crm.configuration AS target
USING (SELECT N'demo' AS tenant, 1 AS id) AS source
    ON target.tenant = source.tenant AND target.id = source.id
WHEN MATCHED THEN
    UPDATE SET config = @DemoConfiguration,
               updated_at = SYSUTCDATETIME(), updated_by = N'system'
WHEN NOT MATCHED BY TARGET THEN
    INSERT (tenant, id, config, updated_by)
    VALUES (source.tenant, source.id, @DemoConfiguration, N'system');
