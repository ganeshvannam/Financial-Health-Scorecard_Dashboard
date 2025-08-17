-- DROP existing tables if they exist
IF OBJECT_ID('dbo.ValidationResults') IS NOT NULL DROP TABLE dbo.ValidationResults;
IF OBJECT_ID('dbo.FinancialPivot') IS NOT NULL DROP TABLE dbo.FinancialPivot;

-- Create consolidated financial data with account rollups
CREATE TABLE dbo.FinancialPivot (
    PivotID INT IDENTITY(1,1) PRIMARY KEY,
    StoreID INT NULL,
    FranID INT NULL,
    OrgID INT NOT NULL,
    FiscalYearID INT NOT NULL,
    CalendarID INT NOT NULL,
    AccountID INT NOT NULL,
    Amount DECIMAL(18,2) NOT NULL,
    Level VARCHAR(20) NOT NULL CHECK (Level IN ('Store', 'Franchisee', 'Organization'))
);

-- Populate with base transactions
INSERT INTO dbo.FinancialPivot (StoreID, FranID, OrgID, FiscalYearID, CalendarID, AccountID, Amount, Level)
SELECT 
    md.StoreID,
    o.FranID,
    o.OrgID,
    md.FiscalYearID,
    md.CalendarID,
    md.AccountID,
    md.Amount,
    'Store' AS Level
FROM dbo.MainData md
JOIN dbo.Ownership o ON md.StoreID = o.StoreID;

-- Apply account calculations
INSERT INTO dbo.FinancialPivot (StoreID, FranID, OrgID, FiscalYearID, CalendarID, AccountID, Amount, Level)
SELECT 
    fp.StoreID,
    fp.FranID,
    fp.OrgID,
    fp.FiscalYearID,
    fp.CalendarID,
    ac.DestAccountID,
    SUM(fp.Amount * ac.Multiplier),
    fp.Level
FROM dbo.FinancialPivot fp
JOIN dbo.AccountCalc ac ON fp.AccountID = ac.SourceAccountID
GROUP BY fp.StoreID, fp.FranID, fp.OrgID, fp.FiscalYearID, fp.CalendarID, ac.DestAccountID, fp.Level;

-- Create franchisee level aggregates
INSERT INTO dbo.FinancialPivot (StoreID, FranID, OrgID, FiscalYearID, CalendarID, AccountID, Amount, Level)
SELECT 
    NULL AS StoreID,
    FranID,
    OrgID,
    FiscalYearID,
    CalendarID,
    AccountID,
    SUM(Amount),
    'Franchisee' AS Level
FROM dbo.FinancialPivot
WHERE Level = 'Store'
GROUP BY FranID, OrgID, FiscalYearID, CalendarID, AccountID;

-- Create organization level aggregates
INSERT INTO dbo.FinancialPivot (StoreID, FranID, OrgID, FiscalYearID, CalendarID, AccountID, Amount, Level)
SELECT 
    NULL AS StoreID,
    NULL AS FranID,
    OrgID,
    FiscalYearID,
    CalendarID,
    AccountID,
    SUM(Amount),
    'Organization' AS Level
FROM dbo.FinancialPivot
WHERE Level = 'Store'
GROUP BY OrgID, FiscalYearID, CalendarID, AccountID;

-- VALIDATION RESULTS TABLE
CREATE TABLE dbo.ValidationResults (
    ValidationID INT IDENTITY(1,1) PRIMARY KEY,
    RuleID INT NOT NULL,
    StoreID INT NULL,
    FranID INT NULL,
    OrgID INT NOT NULL,
    FiscalYearID INT NOT NULL,
    CalendarID INT NOT NULL,
    ValidationDate DATETIME DEFAULT GETDATE(),
    Passed BIT NOT NULL,
    ActualValue DECIMAL(18,2) NULL,
    ExpectedValue DECIMAL(18,2) NULL,
    Details VARCHAR(255) NULL
);

-- RULE 1: Assets vs Liabilities (Store Level)
INSERT INTO dbo.ValidationResults
SELECT 
    1 AS RuleID,
    StoreID,
    FranID,
    OrgID,
    FiscalYearID,
    CalendarID,
    GETDATE(),
    CASE WHEN ABS(ISNULL(Assets,0) - ISNULL(Liabilities,0)) < 0.01 THEN 1 ELSE 0 END AS Passed,
    ISNULL(Assets,0) - ISNULL(Liabilities,0) AS ActualValue,
    0 AS ExpectedValue,
    CASE WHEN ABS(ISNULL(Assets,0) - ISNULL(Liabilities,0)) < 0.01 
         THEN 'Assets and Liabilities balanced' 
         ELSE CONCAT('Imbalance: $', ABS(ISNULL(Assets,0) - ISNULL(Liabilities,0))) END AS Details
FROM (
    SELECT 
        fp.StoreID, fp.FranID, fp.OrgID, fp.FiscalYearID, fp.CalendarID,
        SUM(CASE WHEN fp.AccountID = 10160 THEN fp.Amount ELSE 0 END) AS Assets,
        SUM(CASE WHEN fp.AccountID = 10350 THEN fp.Amount ELSE 0 END) AS Liabilities
    FROM dbo.FinancialPivot fp
    WHERE fp.Level = 'Store'
    GROUP BY fp.StoreID, fp.FranID, fp.OrgID, fp.FiscalYearID, fp.CalendarID
) AS BalanceCheck;

-- RULE 2: Revenue Growth (Organization Level)
WITH RevenueData AS (
    SELECT 
        OrgID,
        FiscalYearID,
        CalendarID,
        SUM(CASE WHEN AccountID = 10 THEN Amount ELSE 0 END) AS Revenue,
        LAG(SUM(CASE WHEN AccountID = 10 THEN Amount ELSE 0 END), 1) OVER (
            PARTITION BY OrgID ORDER BY FiscalYearID, CalendarID) AS PrevRevenue
    FROM dbo.FinancialPivot
    WHERE Level = 'Organization'
    GROUP BY OrgID, FiscalYearID, CalendarID
)
INSERT INTO dbo.ValidationResults
SELECT 
    2 AS RuleID,
    NULL AS StoreID,
    NULL AS FranID,
    OrgID,
    FiscalYearID,
    CalendarID,
    GETDATE(),
    CASE WHEN Revenue >= PrevRevenue * 1.05 OR PrevRevenue IS NULL THEN 1 ELSE 0 END,
    CASE WHEN PrevRevenue = 0 THEN NULL 
         ELSE (Revenue - PrevRevenue)/NULLIF(PrevRevenue,0) END,
    0.05,
    CASE 
        WHEN PrevRevenue IS NULL THEN 'No previous data'
        WHEN Revenue >= PrevRevenue * 1.05 THEN 'Revenue growth meets 5% target'
        ELSE CONCAT('Revenue growth only ', 
                  ROUND(100*(Revenue - PrevRevenue)/NULLIF(PrevRevenue,0),2), '%')
    END
FROM RevenueData
WHERE PrevRevenue IS NOT NULL;

-- RULE 3: Non-compliance Rate (Organization Level)
WITH ComplianceData AS (
    SELECT 
        vr.OrgID,
        vr.FiscalYearID,
        vr.CalendarID,
        COUNT(DISTINCT vr.StoreID) AS TotalStores,
        SUM(CASE WHEN vr.Passed = 0 THEN 1 ELSE 0 END) AS FailedStores
    FROM dbo.ValidationResults vr
    WHERE vr.RuleID = 1
    GROUP BY vr.OrgID, vr.FiscalYearID, vr.CalendarID
)
INSERT INTO dbo.ValidationResults
SELECT 
    3 AS RuleID,
    NULL AS StoreID,
    NULL AS FranID,
    OrgID,
    FiscalYearID,
    CalendarID,
    GETDATE(),
    CASE WHEN FailedStores*1.0/NULLIF(TotalStores,0) <= 0.1 THEN 1 ELSE 0 END,
    FailedStores*100.0/NULLIF(TotalStores,0),
    10.0,
    CASE 
        WHEN FailedStores*1.0/NULLIF(TotalStores,0) <= 0.1 
        THEN CONCAT('Compliant (', FailedStores, '/', TotalStores, ' stores failed)')
        ELSE CONCAT('Non-compliant: ', 
                  ROUND(FailedStores*100.0/NULLIF(TotalStores,0),2), '% failed (', 
                  FailedStores, '/', TotalStores, ' stores)')
    END
FROM ComplianceData
WHERE TotalStores > 0;

-- RULE 4: Expense-to-Sales Ratio (Franchisee Level)
INSERT INTO dbo.ValidationResults
SELECT 
    4 AS RuleID,
    NULL AS StoreID,
    FranID,
    OrgID,
    FiscalYearID,
    CalendarID,
    GETDATE(),
    CASE 
        WHEN Revenue = 0 THEN 1  -- Auto-pass if no revenue
        WHEN Expenses/NULLIF(Revenue,0) <= 0.8 THEN 1
        ELSE 0
    END,
    Expenses/NULLIF(Revenue,0),
    0.8,
    CASE 
        WHEN Revenue = 0 THEN 'No revenue recorded (auto-pass)'
        WHEN Expenses/NULLIF(Revenue,0) <= 0.8 
        THEN CONCAT('Healthy ratio: ', ROUND(100*Expenses/NULLIF(Revenue,0),2), '%')
        ELSE CONCAT('Excessive expenses: ', ROUND(100*Expenses/NULLIF(Revenue,0),2), '%')
    END
FROM (
    SELECT 
        FranID,
        OrgID,
        FiscalYearID,
        CalendarID,
        SUM(CASE WHEN AccountID = 10 THEN Amount ELSE 0 END) AS Revenue,
        SUM(CASE WHEN AccountID BETWEEN 70 AND 230 THEN Amount ELSE 0 END) AS Expenses
    FROM dbo.FinancialPivot
    WHERE Level = 'Franchisee'
    GROUP BY FranID, OrgID, FiscalYearID, CalendarID
) AS FranchiseeData;

-- Create indexes for performance
CREATE INDEX IX_FinancialPivot_Level ON dbo.FinancialPivot (Level, OrgID, FranID, StoreID, AccountID);
CREATE INDEX IX_ValidationResults_Rule ON dbo.ValidationResults (RuleID, Passed, OrgID, FranID);
