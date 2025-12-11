/*
================================================================================
SQL Server Modernization - Usage Examples and Test Cases
================================================================================
This file contains examples and test cases for the modernization script.
Run these examples after executing the main StoredProcedure_Modernization.sql script.
================================================================================
*/

USE [YourDatabaseName] -- Replace with your actual database name
GO

-- Example 1: Create a test procedure with deprecated syntax
CREATE OR ALTER PROCEDURE [dbo].[TestProcedure_Deprecated]
    @UserId INT,
    @ErrorMsg NVARCHAR(255) = 'Default error message'
AS
BEGIN
    SET ANSI_NULLS OFF
    SET QUOTED_IDENTIFIER OFF
    
    DECLARE @UserData TEXT
    DECLARE @BinaryData IMAGE
    
    -- Old RAISERROR syntax examples
    IF @UserId <= 0
        RAISERROR 50001 @ErrorMsg
    
    IF @UserId > 1000000
    BEGIN
        DECLARE @CustomError NVARCHAR(100) = 'User ID too large: ' + CAST(@UserId AS NVARCHAR(20))
        RAISERROR (50002, 16, 1, @CustomError)
    END
    
    -- Old JOIN syntax
    SELECT u.UserName, p.ProductName
    FROM Users u, Products p
    WHERE u.UserId *= p.UserId  -- Old outer join syntax
    
    -- Deprecated function
    SELECT GETDATE() as CurrentTime
    
    PRINT 'This procedure contains deprecated syntax'
END
GO

-- Example 2: Run the preview to see what would be changed
PRINT '=== PREVIEW MODE - See what procedures need updating ==='
EXEC [dbo].[PreviewModernizationChanges]
GO

-- Example 3: Preview the modernization for our test procedure
PRINT ''
PRINT '=== PREVIEW MODERNIZATION (Safe Mode) ==='
EXEC [dbo].[ModernizeStoredProcedures] 
    @ProcedureName = 'TestProcedure_Deprecated',
    @PreviewOnly = 1,
    @BackupEnabled = 1
GO

-- Example 4: Actually apply the modernization
PRINT ''
PRINT '=== APPLYING MODERNIZATION ==='
EXEC [dbo].[ModernizeStoredProcedures] 
    @ProcedureName = 'TestProcedure_Deprecated',
    @PreviewOnly = 0,
    @BackupEnabled = 1
GO

-- Example 5: View the backup record
PRINT ''
PRINT '=== BACKUP RECORDS ==='
SELECT 
    BackupId,
    ProcedureName,
    SchemaName,
    BackupDate,
    Status,
    CASE 
        WHEN LEN(OriginalDefinition) > 100 THEN LEFT(OriginalDefinition, 100) + '...'
        ELSE OriginalDefinition
    END AS OriginalDefinition_Preview
FROM [dbo].[SP_Modernization_Backup]
WHERE ProcedureName = 'TestProcedure_Deprecated'
ORDER BY BackupDate DESC
GO

-- Example 6: View the modernized procedure
PRINT ''
PRINT '=== MODERNIZED PROCEDURE ==='
SELECT m.definition
FROM sys.procedures p
INNER JOIN sys.sql_modules m ON p.object_id = m.object_id
WHERE p.name = 'TestProcedure_Deprecated'
GO

-- Example 7: Rollback example (if needed)
/*
PRINT ''
PRINT '=== ROLLBACK EXAMPLE (Commented out) ==='
EXEC [dbo].[RollbackModernization] 
    @ProcedureName = 'TestProcedure_Deprecated',
    @SchemaName = 'dbo'
*/

-- Example 8: Modernize all procedures in a specific schema
/*
PRINT ''
PRINT '=== MODERNIZE ALL PROCEDURES IN DBO SCHEMA ==='
EXEC [dbo].[ModernizeStoredProcedures] 
    @SchemaName = 'dbo',
    @PreviewOnly = 1,  -- Set to 0 to actually apply changes
    @BackupEnabled = 1
*/

-- Example 9: Clean up test procedure
DROP PROCEDURE IF EXISTS [dbo].[TestProcedure_Deprecated]
GO

PRINT ''
PRINT '=== EXAMPLES COMPLETE ==='
PRINT 'Review the output above to understand how the modernization works.'
PRINT ''
PRINT 'Common RAISERROR patterns that are modernized:'
PRINT '- RAISERROR 50001 @ErrorMsg         → THROW 50001, @ErrorMsg, 1'
PRINT '- RAISERROR (50001, 16, 1, @Msg)    → THROW 50001, @Msg, 1'
PRINT ''
PRINT 'Other modernizations:'
PRINT '- TEXT data type                     → NVARCHAR(MAX)'
PRINT '- IMAGE data type                    → VARBINARY(MAX)'  
PRINT '- GETDATE()                          → SYSDATETIME()'
PRINT '- SET ANSI_NULLS OFF                 → SET ANSI_NULLS ON'
PRINT '- Old JOIN syntax (*=, =*)           → Modern JOIN syntax'
GO