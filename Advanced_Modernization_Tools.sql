/*
================================================================================
Advanced Pattern Detection and Custom Modernization Rules
================================================================================
This file contains additional helper functions for detecting and modernizing
more complex deprecated SQL Server patterns.
================================================================================
*/

USE [YourDatabaseName] -- Replace with your actual database name
GO

-- Check compatibility level for advanced features
DECLARE @CompatLevel INT
SELECT @CompatLevel = compatibility_level FROM sys.databases WHERE name = DB_NAME()

IF @CompatLevel < 110
BEGIN
    PRINT 'WARNING: This script requires SQL Server 2012 compatibility (110) or higher for THROW statements'
    PRINT 'Current level: ' + CAST(@CompatLevel AS NVARCHAR(10))
    PRINT 'Upgrading to compatibility level 110...'
    DECLARE @UpgradeSQL NVARCHAR(200) = 'ALTER DATABASE [' + DB_NAME() + '] SET COMPATIBILITY_LEVEL = 110'
    EXEC sp_executesql @UpgradeSQL
    PRINT 'Upgraded to compatibility level 110 - THROW statements and modern features enabled'
END
ELSE
BEGIN
    PRINT 'Compatibility level ' + CAST(@CompatLevel AS NVARCHAR(10)) + ' is sufficient for modern T-SQL features'
END
GO

-- Advanced RAISERROR pattern detection function
-- Using DROP/CREATE pattern for SQL Server 2008 compatibility
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = 'DetectRaiseErrorPatterns' AND type IN ('FN', 'TF', 'IF'))
    DROP FUNCTION [dbo].[DetectRaiseErrorPatterns]
GO

CREATE FUNCTION [dbo].[DetectRaiseErrorPatterns](@SqlText NVARCHAR(MAX))
RETURNS TABLE
AS
RETURN
(
    WITH PatternMatches AS (
        SELECT 
            'RAISERROR with error number and variable' AS PatternType,
            CHARINDEX('RAISERROR ', @SqlText) AS StartPosition,
            CASE 
                WHEN PATINDEX('%RAISERROR [0-9]%', @SqlText) > 0 THEN 1
                ELSE 0
            END AS Found
        UNION ALL
        SELECT 
            'RAISERROR with parentheses syntax',
            CHARINDEX('RAISERROR(', @SqlText),
            CASE WHEN @SqlText LIKE '%RAISERROR(%' THEN 1 ELSE 0 END
        UNION ALL
        SELECT 
            'RAISERROR with full parameter syntax',
            CHARINDEX('RAISERROR (', @SqlText),
            CASE WHEN @SqlText LIKE '%RAISERROR (%' THEN 1 ELSE 0 END
    )
    SELECT PatternType, StartPosition, Found
    FROM PatternMatches
    WHERE Found = 1
)
GO

-- Function to analyze and categorize deprecated syntax
-- Using DROP/CREATE pattern for SQL Server 2008 compatibility
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = 'AnalyzeDeprecatedSyntax' AND type IN ('FN', 'TF', 'IF'))
    DROP FUNCTION [dbo].[AnalyzeDeprecatedSyntax]
GO

CREATE FUNCTION [dbo].[AnalyzeDeprecatedSyntax](@SqlText NVARCHAR(MAX))
RETURNS @Results TABLE (
    Category NVARCHAR(50),
    Issue NVARCHAR(100),
    Severity NVARCHAR(20),
    FoundCount INT,
    Recommendation NVARCHAR(200)
)
AS
BEGIN
    -- Check for RAISERROR patterns
    IF @SqlText LIKE '%RAISERROR%'
    BEGIN
        INSERT INTO @Results VALUES (
            'Error Handling',
            'RAISERROR usage detected',
            'High',
            LEN(@SqlText) - LEN(REPLACE(@SqlText, 'RAISERROR', '')),
            'Convert to THROW statements for SQL Server 2022 compatibility'
        )
    END
    
    -- Check for deprecated data types
    IF @SqlText LIKE '% TEXT %' OR @SqlText LIKE '%@%TEXT%' OR @SqlText LIKE '%TEXT,%'
    BEGIN
        INSERT INTO @Results VALUES (
            'Data Types',
            'TEXT data type usage',
            'Medium',
            LEN(@SqlText) - LEN(REPLACE(UPPER(@SqlText), 'TEXT', '')),
            'Replace with NVARCHAR(MAX) for better performance and functionality'
        )
    END
    
    IF @SqlText LIKE '% NTEXT %' OR @SqlText LIKE '%@%NTEXT%' OR @SqlText LIKE '%NTEXT,%'
    BEGIN
        INSERT INTO @Results VALUES (
            'Data Types',
            'NTEXT data type usage',
            'Medium',
            LEN(@SqlText) - LEN(REPLACE(UPPER(@SqlText), 'NTEXT', '')),
            'Replace with NVARCHAR(MAX)'
        )
    END
    
    IF @SqlText LIKE '% IMAGE %' OR @SqlText LIKE '%@%IMAGE%' OR @SqlText LIKE '%IMAGE,%'
    BEGIN
        INSERT INTO @Results VALUES (
            'Data Types',
            'IMAGE data type usage',
            'Medium',
            LEN(@SqlText) - LEN(REPLACE(UPPER(@SqlText), 'IMAGE', '')),
            'Replace with VARBINARY(MAX)'
        )
    END
    
    -- Check for old JOIN syntax
    IF @SqlText LIKE '%*=%' OR @SqlText LIKE '%=*%'
    BEGIN
        INSERT INTO @Results VALUES (
            'JOIN Syntax',
            'Old-style JOIN syntax (*=, =*)',
            'High',
            (LEN(@SqlText) - LEN(REPLACE(@SqlText, '*=', ''))) + (LEN(@SqlText) - LEN(REPLACE(@SqlText, '=*', ''))),
            'Convert to explicit JOIN syntax (LEFT JOIN, RIGHT JOIN)'
        )
    END
    
    -- Check for deprecated settings
    IF @SqlText LIKE '%ANSI_NULLS OFF%'
    BEGIN
        INSERT INTO @Results VALUES (
            'Settings',
            'ANSI_NULLS OFF setting',
            'Medium',
            LEN(@SqlText) - LEN(REPLACE(UPPER(@SqlText), 'ANSI_NULLS OFF', '')),
            'Change to ANSI_NULLS ON for SQL Server 2022 compatibility'
        )
    END
    
    IF @SqlText LIKE '%QUOTED_IDENTIFIER OFF%'
    BEGIN
        INSERT INTO @Results VALUES (
            'Settings',
            'QUOTED_IDENTIFIER OFF setting',
            'Medium',
            LEN(@SqlText) - LEN(REPLACE(UPPER(@SqlText), 'QUOTED_IDENTIFIER OFF', '')),
            'Change to QUOTED_IDENTIFIER ON'
        )
    END
    
    -- Check for deprecated functions
    IF @SqlText LIKE '%GETDATE()%' AND @SqlText NOT LIKE '%SYSDATETIME()%'
    BEGIN
        INSERT INTO @Results VALUES (
            'Functions',
            'GETDATE() function usage',
            'Low',
            LEN(@SqlText) - LEN(REPLACE(UPPER(@SqlText), 'GETDATE()', '')),
            'Consider using SYSDATETIME() for higher precision'
        )
    END
    
    RETURN
END
GO

-- Comprehensive analysis procedure
-- Using DROP/CREATE pattern for SQL Server 2008 compatibility
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = 'AnalyzeDatabaseForDeprecatedSyntax' AND type = 'P')
    DROP PROCEDURE [dbo].[AnalyzeDatabaseForDeprecatedSyntax]
GO

CREATE PROCEDURE [dbo].[AnalyzeDatabaseForDeprecatedSyntax]
    @SchemaName NVARCHAR(128) = NULL,
    @DetailedReport BIT = 0,
    @SeverityFilter NVARCHAR(20) = NULL -- 'High', 'Medium', 'Low'
AS
BEGIN
    SET NOCOUNT ON
    
    CREATE TABLE #AnalysisResults (
        SchemaName NVARCHAR(128),
        ProcedureName NVARCHAR(128),
        Category NVARCHAR(50),
        Issue NVARCHAR(100),
        Severity NVARCHAR(20),
        FoundCount INT,
        Recommendation NVARCHAR(200)
    )
    
    DECLARE @CurrentSchema NVARCHAR(128)
    DECLARE @CurrentProcedure NVARCHAR(128)
    DECLARE @Definition NVARCHAR(MAX)
    
    DECLARE analysis_cursor CURSOR FOR
    SELECT 
        SCHEMA_NAME(p.schema_id) AS schema_name,
        p.name AS procedure_name,
        m.definition
    FROM sys.procedures p
    INNER JOIN sys.sql_modules m ON p.object_id = m.object_id
    WHERE (@SchemaName IS NULL OR SCHEMA_NAME(p.schema_id) = @SchemaName)
    ORDER BY schema_name, procedure_name
    
    OPEN analysis_cursor
    FETCH NEXT FROM analysis_cursor INTO @CurrentSchema, @CurrentProcedure, @Definition
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        INSERT INTO #AnalysisResults (SchemaName, ProcedureName, Category, Issue, Severity, FoundCount, Recommendation)
        SELECT 
            @CurrentSchema,
            @CurrentProcedure,
            Category,
            Issue,
            Severity,
            FoundCount,
            Recommendation
        FROM [dbo].[AnalyzeDeprecatedSyntax](@Definition)
        WHERE (@SeverityFilter IS NULL OR Severity = @SeverityFilter)
        
        FETCH NEXT FROM analysis_cursor INTO @CurrentSchema, @CurrentProcedure, @Definition
    END
    
    CLOSE analysis_cursor
    DEALLOCATE analysis_cursor
    
    IF @DetailedReport = 1
    BEGIN
        -- Detailed report
        SELECT 
            SchemaName,
            ProcedureName,
            Category,
            Issue,
            Severity,
            FoundCount,
            Recommendation
        FROM #AnalysisResults
        ORDER BY 
            CASE Severity 
                WHEN 'High' THEN 1 
                WHEN 'Medium' THEN 2 
                WHEN 'Low' THEN 3 
            END,
            SchemaName,
            ProcedureName,
            Category
    END
    ELSE
    BEGIN
        -- Summary report
        SELECT 
            Category,
            Issue,
            Severity,
            COUNT(*) AS AffectedProcedures,
            SUM(FoundCount) AS TotalOccurrences
        FROM #AnalysisResults
        GROUP BY Category, Issue, Severity
        ORDER BY 
            CASE Severity 
                WHEN 'High' THEN 1 
                WHEN 'Medium' THEN 2 
                WHEN 'Low' THEN 3 
            END,
            COUNT(*) DESC
    END
    
    DROP TABLE #AnalysisResults
END
GO

-- Batch modernization with progress tracking
-- Using DROP/CREATE pattern for SQL Server 2008 compatibility
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = 'BatchModernizeWithProgress' AND type = 'P')
    DROP PROCEDURE [dbo].[BatchModernizeWithProgress]
GO

CREATE PROCEDURE [dbo].[BatchModernizeWithProgress]
    @BatchSize INT = 10,
    @SchemaName NVARCHAR(128) = NULL,
    @PreviewOnly BIT = 1,
    @BackupEnabled BIT = 1
AS
BEGIN
    SET NOCOUNT ON
    
    DECLARE @TotalProcedures INT
    DECLARE @ProcessedProcedures INT = 0
    DECLARE @ModernizedProcedures INT = 0
    DECLARE @ErrorCount INT = 0
    DECLARE @CurrentBatch INT = 1
    
    -- Get total count
    SELECT @TotalProcedures = COUNT(*)
    FROM sys.procedures p
    INNER JOIN sys.sql_modules m ON p.object_id = m.object_id
    WHERE (@SchemaName IS NULL OR SCHEMA_NAME(p.schema_id) = @SchemaName)
      AND (
          m.definition LIKE '%RAISERROR%' 
          OR m.definition LIKE '%TEXT%' 
          OR m.definition LIKE '%NTEXT%' 
          OR m.definition LIKE '%IMAGE%'
          OR m.definition LIKE '%*=%'
          OR m.definition LIKE '%=*%'
          OR m.definition LIKE '%ANSI_NULLS OFF%'
          OR m.definition LIKE '%QUOTED_IDENTIFIER OFF%'
      )
    
    PRINT 'Starting batch modernization...'
    PRINT 'Total procedures to process: ' + CAST(@TotalProcedures AS NVARCHAR(10))
    PRINT 'Batch size: ' + CAST(@BatchSize AS NVARCHAR(10))
    PRINT 'Preview mode: ' + CASE WHEN @PreviewOnly = 1 THEN 'YES' ELSE 'NO' END
    PRINT ''
    
    DECLARE @SchemaNameVar NVARCHAR(128)
    DECLARE @ProcedureNameVar NVARCHAR(128)
    
    DECLARE batch_cursor CURSOR FOR
    SELECT 
        SCHEMA_NAME(p.schema_id) AS schema_name,
        p.name AS procedure_name
    FROM sys.procedures p
    INNER JOIN sys.sql_modules m ON p.object_id = m.object_id
    WHERE (@SchemaName IS NULL OR SCHEMA_NAME(p.schema_id) = @SchemaName)
      AND (
          m.definition LIKE '%RAISERROR%' 
          OR m.definition LIKE '%TEXT%' 
          OR m.definition LIKE '%NTEXT%' 
          OR m.definition LIKE '%IMAGE%'
          OR m.definition LIKE '%*=%'
          OR m.definition LIKE '%=*%'
          OR m.definition LIKE '%ANSI_NULLS OFF%'
          OR m.definition LIKE '%QUOTED_IDENTIFIER OFF%'
      )
    ORDER BY schema_name, procedure_name
    
    OPEN batch_cursor
    FETCH NEXT FROM batch_cursor INTO @SchemaNameVar, @ProcedureNameVar
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            EXEC [dbo].[ModernizeStoredProcedures] 
                @SchemaName = @SchemaNameVar,
                @ProcedureName = @ProcedureNameVar,
                @PreviewOnly = @PreviewOnly,
                @BackupEnabled = @BackupEnabled
            
            SET @ModernizedProcedures = @ModernizedProcedures + 1
        END TRY
        BEGIN CATCH
            SET @ErrorCount = @ErrorCount + 1
            PRINT 'ERROR processing ' + @SchemaNameVar + '.' + @ProcedureNameVar + ': ' + ERROR_MESSAGE()
        END CATCH
        
        SET @ProcessedProcedures = @ProcessedProcedures + 1
        
        -- Progress report every batch
        IF @ProcessedProcedures % @BatchSize = 0 OR @ProcessedProcedures = @TotalProcedures
        BEGIN
            PRINT 'Batch ' + CAST(@CurrentBatch AS NVARCHAR(10)) + ' completed: ' + 
                  CAST(@ProcessedProcedures AS NVARCHAR(10)) + '/' + CAST(@TotalProcedures AS NVARCHAR(10)) + 
                  ' procedures processed (' + 
                  CAST((@ProcessedProcedures * 100 / @TotalProcedures) AS NVARCHAR(10)) + '%)'
            SET @CurrentBatch = @CurrentBatch + 1
        END
        
        FETCH NEXT FROM batch_cursor INTO @SchemaNameVar, @ProcedureNameVar
    END
    
    CLOSE batch_cursor
    DEALLOCATE batch_cursor
    
    PRINT ''
    PRINT 'Batch modernization complete!'
    PRINT 'Total processed: ' + CAST(@ProcessedProcedures AS NVARCHAR(10))
    PRINT 'Successfully modernized: ' + CAST(@ModernizedProcedures AS NVARCHAR(10))
    PRINT 'Errors encountered: ' + CAST(@ErrorCount AS NVARCHAR(10))
    
    IF @PreviewOnly = 1
    BEGIN
        PRINT ''
        PRINT 'This was a PREVIEW run. To apply changes, run with @PreviewOnly = 0'
    END
END
GO

-- Report generation procedure
-- Using DROP/CREATE pattern for SQL Server 2008 compatibility
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = 'GenerateModernizationReport' AND type = 'P')
    DROP PROCEDURE [dbo].[GenerateModernizationReport]
GO

CREATE PROCEDURE [dbo].[GenerateModernizationReport]
    @OutputFormat NVARCHAR(10) = 'TABLE' -- 'TABLE' or 'HTML'
AS
BEGIN
    SET NOCOUNT ON
    
    IF @OutputFormat = 'HTML'
    BEGIN
        PRINT '<html><head><title>SQL Server Modernization Report</title>'
        PRINT '<style>table {border-collapse: collapse; width: 100%;} th, td {border: 1px solid #ddd; padding: 8px; text-align: left;} th {background-color: #f2f2f2;}</style>'
        PRINT '</head><body>'
        PRINT '<h1>SQL Server Modernization Report</h1>'
        PRINT '<h2>Generated: ' + CAST(GETDATE() AS NVARCHAR(50)) + '</h2>'
    END
    
    -- Summary statistics
    DECLARE @TotalProcedures INT, @ModernizedProcedures INT, @PendingProcedures INT
    
    SELECT @TotalProcedures = COUNT(*) FROM sys.procedures
    SELECT @ModernizedProcedures = COUNT(*) FROM [dbo].[SP_Modernization_Backup] WHERE Status = 'UPDATED'
    
    SELECT @PendingProcedures = COUNT(*)
    FROM sys.procedures p
    INNER JOIN sys.sql_modules m ON p.object_id = m.object_id
    WHERE (
        m.definition LIKE '%RAISERROR%' 
        OR m.definition LIKE '%TEXT%' 
        OR m.definition LIKE '%NTEXT%' 
        OR m.definition LIKE '%IMAGE%'
        OR m.definition LIKE '%*=%'
        OR m.definition LIKE '%=*%'
        OR m.definition LIKE '%ANSI_NULLS OFF%'
        OR m.definition LIKE '%QUOTED_IDENTIFIER OFF%'
    )
    
    IF @OutputFormat = 'TABLE'
    BEGIN
        SELECT 
            'Summary Statistics' AS ReportSection,
            'Total Procedures' AS Metric,
            @TotalProcedures AS Value
        UNION ALL
        SELECT 'Summary Statistics', 'Modernized Procedures', @ModernizedProcedures
        UNION ALL  
        SELECT 'Summary Statistics', 'Pending Modernization', @PendingProcedures
        UNION ALL
        SELECT 'Summary Statistics', 'Completion Percentage', 
               CASE WHEN @PendingProcedures > 0 
                    THEN (@ModernizedProcedures * 100 / (@ModernizedProcedures + @PendingProcedures))
                    ELSE 100 
               END
    END
    
    -- Detailed analysis
    EXEC [dbo].[AnalyzeDatabaseForDeprecatedSyntax] @DetailedReport = 0
    
    IF @OutputFormat = 'HTML'
    BEGIN
        PRINT '</body></html>'
    END
END
GO

PRINT 'Advanced Pattern Detection and Analysis Tools Created!'
PRINT ''
PRINT 'New Procedures Available:'
PRINT '- AnalyzeDatabaseForDeprecatedSyntax - Comprehensive syntax analysis'
PRINT '- BatchModernizeWithProgress - Batch processing with progress tracking'
PRINT '- GenerateModernizationReport - Generate detailed reports'
PRINT ''
GO