ALTER PROCEDURE [crmapi].[companies_summary_get](
    @ID varchar(max) = NULL,
    @filter varchar(max)=NULL,
    @first_row INT = 0,
    @last_row INT = 1000,
    @sort_field NVARCHAR(100) = NULL,
    @sort_order NVARCHAR(4) = NULL,
    @auth_baseurl NVARCHAR(255) = NULL,
    @auth_tenant NVARCHAR(255) = NULL
) AS
BEGIN
    DECLARE @size int = TRY_CONVERT(int, JSON_VALUE(@filter, N'$."size"'));
    DECLARE @sector VARCHAR(100) = TRY_CONVERT(VARCHAR(100), JSON_VALUE(@filter, N'$."sector"'));
    DECLARE @search NVARCHAR(200) = (SELECT TOP 1 '%' + value + '%' FROM OPENJSON(@filter, '$."@or"'));

    WITH contact_counts AS (
        SELECT company_id, COUNT(*) AS nb_contacts
        FROM crm.contacts
        WHERE tenant = @auth_tenant
        GROUP BY company_id
    )
    SELECT
        id,
        name,
        sector,
        size,
        linkedin_url,
        website,
        phone_number,
        address,
        zipcode,
        city,
        state_abbr,
        country,
        description,
        revenue,
        tax_identifier,
        created_at,
        sales_id,
        JSON_QUERY((
            SELECT
                CASE
                    WHEN logo_src IS NULL OR logo_src LIKE 'data:%' THEN logo_src
                    ELSE @auth_baseurl +
                        SUBSTRING(
                            logo_src,
                            CHARINDEX('/', logo_src, CHARINDEX('//', logo_src) + 2),
                            LEN(logo_src)
                        )
                END AS [src],
                logo_title AS [title],
                logo_path AS [path],
                logo_type AS [type]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )) AS logo,
        context_links,
        COUNT(*) OVER() AS total_rows,
        (SELECT COUNT(*) FROM crm.deals WHERE tenant = @auth_tenant AND company_id = crm.companies.id) AS nb_deals,
        ISNULL(cc.nb_contacts, 0) AS nb_contacts
    FROM crm.companies
    LEFT JOIN contact_counts cc ON crm.companies.id = cc.company_id
    WHERE tenant = @auth_tenant
      AND (@ID IS NULL OR @ID = id)
      AND (@size IS NULL OR size = @size)
      AND (@sector IS NULL OR sector = @sector)
      AND (
            @search IS NULL
            OR name LIKE @search
            OR phone_number LIKE @search
            OR website LIKE @search
            OR zipcode LIKE @search
            OR city LIKE @search
            OR state_abbr LIKE @search
      )
    ORDER BY
        CASE WHEN @sort_field = 'name' AND @sort_order = 'ASC' THEN name END ASC,
        CASE WHEN @sort_field = 'name' AND @sort_order = 'DESC' THEN name END DESC,
        CASE WHEN @sort_field = 'sector' AND @sort_order = 'ASC' THEN sector END ASC,
        CASE WHEN @sort_field = 'sector' AND @sort_order = 'DESC' THEN sector END DESC,
        CASE WHEN @sort_field = 'size' AND @sort_order = 'ASC' THEN size END ASC,
        CASE WHEN @sort_field = 'size' AND @sort_order = 'DESC' THEN size END DESC,
        CASE WHEN @sort_field = 'created_at' AND @sort_order = 'ASC' THEN created_at END ASC,
        CASE WHEN @sort_field = 'created_at' AND @sort_order = 'DESC' THEN created_at END DESC,
        CASE WHEN @sort_field = 'nb_contacts' AND @sort_order = 'ASC' THEN ISNULL(cc.nb_contacts, 0) END ASC,
        CASE WHEN @sort_field = 'nb_contacts' AND @sort_order = 'DESC' THEN ISNULL(cc.nb_contacts, 0) END DESC,
        CASE WHEN @sort_field IS NULL THEN id END ASC
    OFFSET @first_row ROWS
    FETCH NEXT (@last_row - @first_row + 1) ROWS ONLY;
END
