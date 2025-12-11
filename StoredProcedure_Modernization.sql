/*
================================================================================
SQL Server Stored Procedure Modernization Script
================================================================================
Purpose: Bulk update stored procedures from SQL Server 2005 deprecated syntax 
         to modern SQL Server 2022 compatible syntax

Key Updates:
- RAISERROR syntax modernization to THROW statements
- Deprecated data types and functions
- Outdated JOIN syntax
- Other SQL Server 2005 deprecated features

Author: Generated for SQL Server modernization
Date: December 2024
Target: SQL Server 2022
================================================================================
*/

USE [YourDatabaseName] -- Replace with your actual database name
GO

SET NOCOUNT ON
GO

-- Check and upgrade database compatibility level if needed for THROW statements
DECLARE @CurrentCompatibilityLevel INT
DECLARE @DatabaseName NVARCHAR(128) = DB_NAME()

SELECT @CurrentCompatibilityLevel = compatibility_level 
FROM sys.databases 
WHERE name = @DatabaseName

PRINT 'Current database compatibility level: ' + CAST(@CurrentCompatibilityLevel AS NVARCHAR(10))

-- THROW statements require compatibility level 110 (SQL Server 2012) or higher
IF @CurrentCompatibilityLevel < 110
BEGIN
    PRINT 'WARNING: THROW statements require SQL Server 2012 compatibility (110) or higher'
    PRINT 'Current level: ' + CAST(@CurrentCompatibilityLevel AS NVARCHAR(10)) + ' (SQL Server 2008)'
    PRINT 'Upgrading database compatibility level to 110 (SQL Server 2012)...'
    
    DECLARE @UpgradeSQL NVARCHAR(200) = 'ALTER DATABASE [' + @DatabaseName + '] SET COMPATIBILITY_LEVEL = 110'
    EXEC sp_executesql @UpgradeSQL
    
    PRINT 'Database compatibility level upgraded to 110'
    PRINT 'THROW statements are now supported'
    PRINT ''
END
ELSE
BEGIN
    PRINT 'Compatibility level is sufficient for THROW statements'
    PRINT ''
END
GO

-- Create a backup table for storing original procedure definitions
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_Modernization_Backup]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[SP_Modernization_Backup] (
        [BackupId] INT IDENTITY(1,1) PRIMARY KEY,
        [ProcedureName] NVARCHAR(128) NOT NULL,
        [SchemaName] NVARCHAR(128) NOT NULL,
        [OriginalDefinition] NVARCHAR(MAX) NOT NULL,
        [BackupDate] DATETIME2 DEFAULT GETDATE(),
        [ModernizedDefinition] NVARCHAR(MAX) NULL,
        [Status] NVARCHAR(50) DEFAULT 'BACKED_UP'
    )
    
    PRINT 'Created backup table: SP_Modernization_Backup'
END
GO

-- Function to modernize RAISERROR statements
CREATE OR ALTER FUNCTION [dbo].[ModernizeRaiseError](@SqlText NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @ModernizedText NVARCHAR(MAX) = @SqlText
    
    -- Pattern 1: RAISERROR (error_number, severity, state)
    -- Convert to: THROW error_number, 'Custom message', 1
    WHILE CHARINDEX('RAISERROR (', @ModernizedText) > 0
    BEGIN
        DECLARE @StartPos INT = CHARINDEX('RAISERROR (', @ModernizedText)
        DECLARE @OpenParen INT = @StartPos + 10  -- Position after 'RAISERROR ('
        DECLARE @ParenCount INT = 1
        DECLARE @CurrentPos INT = @OpenParen
        DECLARE @ClosePos INT = 0
        
        -- Find matching closing parenthesis
        WHILE @CurrentPos <= LEN(@ModernizedText) AND @ParenCount > 0
        BEGIN
            SET @CurrentPos = @CurrentPos + 1
            IF SUBSTRING(@ModernizedText, @CurrentPos, 1) = '('
                SET @ParenCount = @ParenCount + 1
            ELSE IF SUBSTRING(@ModernizedText, @CurrentPos, 1) = ')'
            BEGIN
                SET @ParenCount = @ParenCount - 1
                IF @ParenCount = 0
                    SET @ClosePos = @CurrentPos
            END
        END
        
        IF @ClosePos > 0
        BEGIN
            DECLARE @FullStatement NVARCHAR(1000) = SUBSTRING(@ModernizedText, @StartPos, @ClosePos - @StartPos + 1)
            DECLARE @Parameters NVARCHAR(500) = SUBSTRING(@ModernizedText, @OpenParen, @ClosePos - @OpenParen)
            
            -- Parse parameters (error_number, severity, state[, message])
            DECLARE @ErrorNumber NVARCHAR(20), @Severity NVARCHAR(10), @State NVARCHAR(10), @Message NVARCHAR(500)
            DECLARE @CommaPos1 INT, @CommaPos2 INT, @CommaPos3 INT
            
            SET @CommaPos1 = CHARINDEX(',', @Parameters)
            IF @CommaPos1 > 0
            BEGIN
                SET @ErrorNumber = LTRIM(RTRIM(SUBSTRING(@Parameters, 1, @CommaPos1 - 1)))
                
                SET @CommaPos2 = CHARINDEX(',', @Parameters, @CommaPos1 + 1)
                IF @CommaPos2 > 0
                BEGIN
                    SET @Severity = LTRIM(RTRIM(SUBSTRING(@Parameters, @CommaPos1 + 1, @CommaPos2 - @CommaPos1 - 1)))
                    
                    SET @CommaPos3 = CHARINDEX(',', @Parameters, @CommaPos2 + 1)
                    IF @CommaPos3 > 0
                    BEGIN
                        SET @State = LTRIM(RTRIM(SUBSTRING(@Parameters, @CommaPos2 + 1, @CommaPos3 - @CommaPos2 - 1)))
                        SET @Message = LTRIM(RTRIM(SUBSTRING(@Parameters, @CommaPos3 + 1, LEN(@Parameters) - @CommaPos3)))
                    END
                    ELSE
                    BEGIN
                        SET @State = LTRIM(RTRIM(SUBSTRING(@Parameters, @CommaPos2 + 1, LEN(@Parameters) - @CommaPos2)))
                        SET @Message = '''Error occurred'''
                    END
                END
            END
            
            -- Create modern THROW statement
            DECLARE @NewStatement NVARCHAR(1000)
            IF @Message IS NOT NULL AND LEN(@Message) > 0
                SET @NewStatement = 'THROW ' + @ErrorNumber + ', ' + @Message + ', ' + ISNULL(@State, '1')
            ELSE
                SET @NewStatement = 'THROW ' + @ErrorNumber + ', ''An error occurred'', ' + ISNULL(@State, '1')
            
            SET @ModernizedText = REPLACE(@ModernizedText, @FullStatement, @NewStatement)
        END
        ELSE
            BREAK -- Avoid infinite loop if parsing fails
    END
    
    -- Pattern 2: Simple RAISERROR error_number message_variable patterns
    WHILE PATINDEX('%RAISERROR [0-9]%', @ModernizedText) > 0
    BEGIN
        DECLARE @LineStart INT = PATINDEX('%RAISERROR [0-9]%', @ModernizedText)
        DECLARE @LineEnd INT = CHARINDEX(CHAR(13), @ModernizedText, @LineStart)
        IF @LineEnd = 0 SET @LineEnd = CHARINDEX(CHAR(10), @ModernizedText, @LineStart)
        IF @LineEnd = 0 SET @LineEnd = LEN(@ModernizedText) + 1
        
        DECLARE @OldLine NVARCHAR(1000) = SUBSTRING(@ModernizedText, @LineStart, @LineEnd - @LineStart)
        
        -- Simple replacement for basic RAISERROR patterns
        IF @OldLine LIKE 'RAISERROR [0-9]%'
        BEGIN
            DECLARE @NewLine NVARCHAR(1000) = REPLACE(@OldLine, 'RAISERROR ', 'THROW ') + ', 1'
            IF @NewLine NOT LIKE '%,%,%'
                SET @NewLine = REPLACE(@NewLine, 'THROW ', 'THROW 50000, ''Error: '' + CAST(')
            SET @ModernizedText = REPLACE(@ModernizedText, @OldLine, @NewLine)
        END
        ELSE
            BREAK -- Avoid infinite loop
    END
    
    RETURN @ModernizedText
END
GO

-- Function to modernize other deprecated syntax
CREATE OR ALTER FUNCTION [dbo].[ModernizeDeprecatedSyntax](@SqlText NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @ModernizedText NVARCHAR(MAX) = @SqlText
    
    -- Replace deprecated data types
    SET @ModernizedText = REPLACE(@ModernizedText, ' TEXT ', ' NVARCHAR(MAX) ')
    SET @ModernizedText = REPLACE(@ModernizedText, ' NTEXT ', ' NVARCHAR(MAX) ')
    SET @ModernizedText = REPLACE(@ModernizedText, ' IMAGE ', ' VARBINARY(MAX) ')
    
    -- Replace deprecated functions
    SET @ModernizedText = REPLACE(@ModernizedText, 'GETDATE()', 'SYSDATETIME()')
    
    -- Fix old-style JOIN syntax (basic patterns)
    -- This is a simplified approach - complex cases may need manual review
    SET @ModernizedText = REPLACE(@ModernizedText, '*=', 'LEFT JOIN')
    SET @ModernizedText = REPLACE(@ModernizedText, '=*', 'RIGHT JOIN')
    
    -- Replace deprecated ANSI_NULLS and QUOTED_IDENTIFIER settings
    -- These should be ON for SQL Server 2022
    SET @ModernizedText = REPLACE(@ModernizedText, 'SET ANSI_NULLS OFF', 'SET ANSI_NULLS ON')
    SET @ModernizedText = REPLACE(@ModernizedText, 'SET QUOTED_IDENTIFIER OFF', 'SET QUOTED_IDENTIFIER ON')
    
    RETURN @ModernizedText
END
GO

-- Main procedure to modernize stored procedures
CREATE OR ALTER PROCEDURE [dbo].[ModernizeStoredProcedures]
    @SchemaName NVARCHAR(128) = NULL,
    @ProcedureName NVARCHAR(128) = NULL,
    @PreviewOnly BIT = 1,
    @BackupEnabled BIT = 1,
    @AutoCleanup BIT = 0  -- Set to 1 to automatically cleanup modernization objects after completion
AS
BEGIN
    SET NOCOUNT ON
    
    DECLARE @ErrorMessage NVARCHAR(4000)
    DECLARE @CurrentProcedure NVARCHAR(256)
    DECLARE @ModernizationCount INT = 0
    
    BEGIN TRY
        -- Cursor to iterate through stored procedures
        DECLARE procedure_cursor CURSOR FOR
        SELECT 
            SCHEMA_NAME(p.schema_id) AS schema_name,
            p.name AS procedure_name,
            m.definition
        FROM sys.procedures p
        INNER JOIN sys.sql_modules m ON p.object_id = m.object_id
        WHERE (@SchemaName IS NULL OR SCHEMA_NAME(p.schema_id) = @SchemaName)
          AND (@ProcedureName IS NULL OR p.name = @ProcedureName)
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
        
        DECLARE @SchemaNameVar NVARCHAR(128)
        DECLARE @ProcedureNameVar NVARCHAR(128) 
        DECLARE @OriginalDefinition NVARCHAR(MAX)
        DECLARE @ModernizedDefinition NVARCHAR(MAX)
        
        OPEN procedure_cursor
        
        FETCH NEXT FROM procedure_cursor INTO @SchemaNameVar, @ProcedureNameVar, @OriginalDefinition
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @CurrentProcedure = @SchemaNameVar + '.' + @ProcedureNameVar
            
            PRINT 'Processing: ' + @CurrentProcedure
            
            -- Apply modernization transformations
            SET @ModernizedDefinition = @OriginalDefinition
            SET @ModernizedDefinition = [dbo].[ModernizeRaiseError](@ModernizedDefinition)
            SET @ModernizedDefinition = [dbo].[ModernizeDeprecatedSyntax](@ModernizedDefinition)
            
            -- Check if any changes were made
            IF @ModernizedDefinition != @OriginalDefinition
            BEGIN
                -- Backup original procedure if enabled
                IF @BackupEnabled = 1
                BEGIN
                    INSERT INTO [dbo].[SP_Modernization_Backup] 
                    (ProcedureName, SchemaName, OriginalDefinition, ModernizedDefinition)
                    VALUES (@ProcedureNameVar, @SchemaNameVar, @OriginalDefinition, @ModernizedDefinition)
                END
                
                IF @PreviewOnly = 1
                BEGIN
                    PRINT '-- PREVIEW MODE: Would update ' + @CurrentProcedure
                    PRINT '-- Original contained deprecated syntax'
                    PRINT ''
                END
                ELSE
                BEGIN
                    -- Apply the modernized procedure
                    EXEC sp_executesql @ModernizedDefinition
                    PRINT 'Updated: ' + @CurrentProcedure
                    
                    -- Update backup record status
                    IF @BackupEnabled = 1
                    BEGIN
                        UPDATE [dbo].[SP_Modernization_Backup] 
                        SET Status = 'UPDATED'
                        WHERE ProcedureName = @ProcedureNameVar 
                          AND SchemaName = @SchemaNameVar
                          AND BackupDate = (SELECT MAX(BackupDate) 
                                           FROM [dbo].[SP_Modernization_Backup] 
                                           WHERE ProcedureName = @ProcedureNameVar 
                                             AND SchemaName = @SchemaNameVar)
                    END
                END
                
                SET @ModernizationCount = @ModernizationCount + 1
            END
            ELSE
            BEGIN
                PRINT 'No changes needed for: ' + @CurrentProcedure
            END
            
            FETCH NEXT FROM procedure_cursor INTO @SchemaNameVar, @ProcedureNameVar, @OriginalDefinition
        END
        
        CLOSE procedure_cursor
        DEALLOCATE procedure_cursor
        
        PRINT ''
        PRINT 'Modernization complete!'
        PRINT 'Total procedures processed: ' + CAST(@ModernizationCount AS NVARCHAR(10))
        
        IF @PreviewOnly = 1
        BEGIN
            PRINT ''
            PRINT 'This was a PREVIEW run. To apply changes, run with @PreviewOnly = 0'
        END
        ELSE
        BEGIN
            -- Auto-cleanup option
            IF @AutoCleanup = 1 AND @ModernizationCount > 0
            BEGIN
                PRINT ''
                PRINT '🧹 Auto-cleanup enabled - removing modernization objects...'
                
                BEGIN TRY
                    -- Drop the helper functions
                    DROP FUNCTION IF EXISTS [dbo].[ModernizeRaiseError]
                    DROP FUNCTION IF EXISTS [dbo].[ModernizeDeprecatedSyntax]
                    
                    -- Drop utility procedures (but keep this main one until the end)
                    DROP PROCEDURE IF EXISTS [dbo].[PreviewModernizationChanges]
                    DROP PROCEDURE IF EXISTS [dbo].[RollbackModernization]
                    
                    PRINT '✅ Cleanup completed - modernization objects removed'
                    PRINT '   Note: Backup table preserved for rollback capability'
                END TRY
                BEGIN CATCH
                    PRINT '⚠️  Partial cleanup - some objects may remain: ' + ERROR_MESSAGE()
                END CATCH
            END
        END
        
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('global', 'procedure_cursor') >= 0
        BEGIN
            CLOSE procedure_cursor
            DEALLOCATE procedure_cursor
        END
        
        SET @ErrorMessage = 'Error processing ' + ISNULL(@CurrentProcedure, 'unknown procedure') + 
                           ': ' + ERROR_MESSAGE()
        THROW 50000, @ErrorMessage, 1
    END CATCH
END
GO

-- Utility procedure to review what would be changed
CREATE OR ALTER PROCEDURE [dbo].[PreviewModernizationChanges]
    @SchemaName NVARCHAR(128) = NULL,
    @ProcedureName NVARCHAR(128) = NULL
AS
BEGIN
    SET NOCOUNT ON
    
    SELECT 
        SCHEMA_NAME(p.schema_id) AS SchemaName,
        p.name AS ProcedureName,
        CASE 
            WHEN m.definition LIKE '%RAISERROR%' THEN 'RAISERROR syntax found'
            ELSE ''
        END +
        CASE 
            WHEN m.definition LIKE '%TEXT%' OR m.definition LIKE '%NTEXT%' OR m.definition LIKE '%IMAGE%' 
            THEN CASE WHEN m.definition LIKE '%RAISERROR%' THEN ', ' ELSE '' END + 'Deprecated data types found'
            ELSE ''
        END +
        CASE 
            WHEN m.definition LIKE '%*=%' OR m.definition LIKE '%=*%' 
            THEN CASE WHEN LEN(CASE WHEN m.definition LIKE '%RAISERROR%' THEN 'x' ELSE '' END +
                                   CASE WHEN m.definition LIKE '%TEXT%' OR m.definition LIKE '%NTEXT%' OR m.definition LIKE '%IMAGE%' THEN 'x' ELSE '' END) > 0 
                      THEN ', ' ELSE '' END + 'Old JOIN syntax found'
            ELSE ''
        END AS IssuesFound,
        p.create_date,
        p.modify_date
    FROM sys.procedures p
    INNER JOIN sys.sql_modules m ON p.object_id = m.object_id
    WHERE (@SchemaName IS NULL OR SCHEMA_NAME(p.schema_id) = @SchemaName)
      AND (@ProcedureName IS NULL OR p.name = @ProcedureName)
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
    ORDER BY SchemaName, ProcedureName
END
GO

-- Rollback procedure in case of issues
CREATE OR ALTER PROCEDURE [dbo].[RollbackModernization]
    @ProcedureName NVARCHAR(128),
    @SchemaName NVARCHAR(128) = 'dbo',
    @BackupId INT = NULL
AS
BEGIN
    SET NOCOUNT ON
    
    DECLARE @OriginalDefinition NVARCHAR(MAX)
    DECLARE @ErrorMessage NVARCHAR(4000)
    
    BEGIN TRY
        -- Get the original definition
        SELECT @OriginalDefinition = OriginalDefinition
        FROM [dbo].[SP_Modernization_Backup]
        WHERE ProcedureName = @ProcedureName 
          AND SchemaName = @SchemaName
          AND (@BackupId IS NULL OR BackupId = @BackupId)
          AND Status = 'UPDATED'
        ORDER BY BackupDate DESC
        
        IF @OriginalDefinition IS NULL
        BEGIN
            SET @ErrorMessage = 'No backup found for procedure: ' + @SchemaName + '.' + @ProcedureName
            THROW 50000, @ErrorMessage, 1
        END
        
        -- Restore the original procedure
        EXEC sp_executesql @OriginalDefinition
        
        -- Update backup status
        UPDATE [dbo].[SP_Modernization_Backup]
        SET Status = 'ROLLED_BACK'
        WHERE ProcedureName = @ProcedureName 
          AND SchemaName = @SchemaName
          AND (@BackupId IS NULL OR BackupId = @BackupId)
          AND Status = 'UPDATED'
        
        PRINT 'Successfully rolled back: ' + @SchemaName + '.' + @ProcedureName
        
    END TRY
    BEGIN CATCH
        SET @ErrorMessage = 'Error rolling back procedure: ' + ERROR_MESSAGE()
        THROW 50000, @ErrorMessage, 1
    END CATCH
END
GO

PRINT 'SQL Server Modernization Script Setup Complete!'
PRINT ''
PRINT 'Available Procedures:'
PRINT '1. PreviewModernizationChanges - See what procedures need updating'
PRINT '2. ModernizeStoredProcedures - Apply modernization (use @PreviewOnly = 0 to execute)'
PRINT '3. RollbackModernization - Rollback a specific procedure if needed'
PRINT ''
PRINT 'Usage Examples:'
PRINT 'EXEC PreviewModernizationChanges -- See all procedures with deprecated syntax'
PRINT 'EXEC ModernizeStoredProcedures @PreviewOnly = 1 -- Preview mode (safe)'
PRINT 'EXEC ModernizeStoredProcedures @PreviewOnly = 0 -- Apply changes'
PRINT 'EXEC ModernizeStoredProcedures @PreviewOnly = 0, @AutoCleanup = 1 -- Apply changes and auto-cleanup'
PRINT ''
PRINT 'Cleanup:'
PRINT 'Use Cleanup_Modernization_Objects.sql to remove all modernization objects when done'
PRINT ''
GO