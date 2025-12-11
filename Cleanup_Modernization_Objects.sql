/*
================================================================================
SQL Server Modernization - Cleanup Script
================================================================================
Purpose: Remove all modernization database objects after updates are complete
         This script removes all functions, procedures, and tables created by
         the modernization scripts.

⚠️  WARNING: This will permanently remove:
   - All modernization procedures and functions
   - The SP_Modernization_Backup table (including all backup data)
   
   Only run this after you're completely satisfied with the modernization results
   and have verified all procedures work correctly.
================================================================================
*/

USE [YourDatabaseName] -- Replace with your actual database name
GO

SET NOCOUNT ON
GO

PRINT '========================================='
PRINT 'SQL Server Modernization Cleanup Script'
PRINT '========================================='
PRINT 'WARNING: This will remove ALL modernization objects and backup data!'
PRINT ''

-- Safety check - require explicit confirmation
DECLARE @ConfirmCleanup BIT = 0  -- Change to 1 to enable cleanup

IF @ConfirmCleanup = 0
BEGIN
    PRINT '❌ CLEANUP DISABLED FOR SAFETY'
    PRINT ''
    PRINT 'To proceed with cleanup:'
    PRINT '1. Verify all procedures work correctly after modernization'
    PRINT '2. Create a full database backup (recommended)'
    PRINT '3. Change @ConfirmCleanup = 1 in this script'
    PRINT '4. Re-run this script'
    PRINT ''
    PRINT 'Objects that would be removed:'
    PRINT '- Functions: ModernizeRaiseError, ModernizeDeprecatedSyntax'
    PRINT '- Functions: DetectRaiseErrorPatterns, AnalyzeDeprecatedSyntax'
    PRINT '- Procedures: ModernizeStoredProcedures, PreviewModernizationChanges'
    PRINT '- Procedures: RollbackModernization, AnalyzeDatabaseForDeprecatedSyntax'
    PRINT '- Procedures: BatchModernizeWithProgress, GenerateModernizationReport'
    PRINT '- Table: SP_Modernization_Backup (including all backup data)'
    RETURN
END

PRINT '🧹 Starting cleanup process...'
PRINT ''

DECLARE @ObjectsRemoved INT = 0
DECLARE @ErrorCount INT = 0

-- Drop procedures
DECLARE @ProcedureList TABLE (ProcName NVARCHAR(128))
INSERT INTO @ProcedureList VALUES 
    ('ModernizeStoredProcedures'),
    ('PreviewModernizationChanges'), 
    ('RollbackModernization'),
    ('AnalyzeDatabaseForDeprecatedSyntax'),
    ('BatchModernizeWithProgress'),
    ('GenerateModernizationReport')

DECLARE @ProcName NVARCHAR(128)
DECLARE proc_cursor CURSOR FOR SELECT ProcName FROM @ProcedureList

OPEN proc_cursor
FETCH NEXT FROM proc_cursor INTO @ProcName

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = @ProcName)
        BEGIN
            EXEC('DROP PROCEDURE [dbo].[' + @ProcName + ']')
            PRINT '✅ Removed procedure: ' + @ProcName
            SET @ObjectsRemoved = @ObjectsRemoved + 1
        END
        ELSE
        BEGIN
            PRINT '⚠️  Procedure not found: ' + @ProcName
        END
    END TRY
    BEGIN CATCH
        PRINT '❌ Error removing procedure ' + @ProcName + ': ' + ERROR_MESSAGE()
        SET @ErrorCount = @ErrorCount + 1
    END CATCH
    
    FETCH NEXT FROM proc_cursor INTO @ProcName
END

CLOSE proc_cursor
DEALLOCATE proc_cursor

-- Drop functions
DECLARE @FunctionList TABLE (FuncName NVARCHAR(128))
INSERT INTO @FunctionList VALUES 
    ('ModernizeRaiseError'),
    ('ModernizeDeprecatedSyntax'),
    ('DetectRaiseErrorPatterns'),
    ('AnalyzeDeprecatedSyntax')

DECLARE @FuncName NVARCHAR(128)
DECLARE func_cursor CURSOR FOR SELECT FuncName FROM @FunctionList

OPEN func_cursor
FETCH NEXT FROM func_cursor INTO @FuncName

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM sys.objects WHERE name = @FuncName AND type IN ('FN', 'TF', 'IF'))
        BEGIN
            EXEC('DROP FUNCTION [dbo].[' + @FuncName + ']')
            PRINT '✅ Removed function: ' + @FuncName
            SET @ObjectsRemoved = @ObjectsRemoved + 1
        END
        ELSE
        BEGIN
            PRINT '⚠️  Function not found: ' + @FuncName
        END
    END TRY
    BEGIN CATCH
        PRINT '❌ Error removing function ' + @FuncName + ': ' + ERROR_MESSAGE()
        SET @ErrorCount = @ErrorCount + 1
    END CATCH
    
    FETCH NEXT FROM func_cursor INTO @FuncName
END

CLOSE func_cursor
DEALLOCATE func_cursor

-- Drop backup table (with extra confirmation)
BEGIN TRY
    IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'SP_Modernization_Backup')
    BEGIN
        -- Show backup statistics before deletion
        DECLARE @BackupCount INT, @UpdatedCount INT
        SELECT @BackupCount = COUNT(*), @UpdatedCount = SUM(CASE WHEN Status = 'UPDATED' THEN 1 ELSE 0 END)
        FROM [dbo].[SP_Modernization_Backup]
        
        PRINT ''
        PRINT '📊 Backup table statistics:'
        PRINT '   Total backup records: ' + CAST(@BackupCount AS NVARCHAR(10))
        PRINT '   Successfully updated procedures: ' + CAST(@UpdatedCount AS NVARCHAR(10))
        PRINT ''
        
        -- Final safety check for backup table
        IF @BackupCount > 0
        BEGIN
            PRINT '⚠️  About to delete backup table with ' + CAST(@BackupCount AS NVARCHAR(10)) + ' records!'
            PRINT '   Consider exporting this data first if you might need it later.'
            PRINT ''
        END
        
        DROP TABLE [dbo].[SP_Modernization_Backup]
        PRINT '✅ Removed backup table: SP_Modernization_Backup'
        SET @ObjectsRemoved = @ObjectsRemoved + 1
    END
    ELSE
    BEGIN
        PRINT '⚠️  Backup table not found: SP_Modernization_Backup'
    END
END TRY
BEGIN CATCH
    PRINT '❌ Error removing backup table: ' + ERROR_MESSAGE()
    SET @ErrorCount = @ErrorCount + 1
END CATCH

PRINT ''
PRINT '========================================='
PRINT 'Cleanup Complete!'
PRINT '========================================='
PRINT 'Objects successfully removed: ' + CAST(@ObjectsRemoved AS NVARCHAR(10))
PRINT 'Errors encountered: ' + CAST(@ErrorCount AS NVARCHAR(10))

IF @ErrorCount = 0
BEGIN
    PRINT ''
    PRINT '🎉 All modernization objects have been successfully removed!'
    PRINT '   Your database is now clean and ready for normal operation.'
END
ELSE
BEGIN
    PRINT ''
    PRINT '⚠️  Some objects could not be removed. Please check the errors above.'
    PRINT '   You may need to manually remove remaining objects.'
END

PRINT ''
PRINT 'Note: The modernized stored procedures remain unchanged and are ready to use.'
GO