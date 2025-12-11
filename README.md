# SQL Server Stored Procedure Modernization Tool

> **Note**: This project was generated using AI assistance from GitHub Copilot. All code, documentation, and examples were created through AI-powered development to provide a comprehensive solution for SQL Server modernization.

This tool helps migrate SQL Server stored procedures from deprecated SQL Server 2005 syntax to modern SQL Server 2022 compatible syntax.

## 🎯 Purpose

Automatically updates deprecated T-SQL syntax including:
- **RAISERROR statements** → Modern THROW statements  
- **Deprecated data types** (TEXT, NTEXT, IMAGE) → Modern equivalents
- **Old JOIN syntax** (*=, =*) → Modern JOIN syntax
- **Deprecated settings** (ANSI_NULLS OFF) → Modern recommended settings

## 📁 Files

| File | Description |
|------|-------------|
| `StoredProcedure_Modernization.sql` | Main modernization script with all functions and procedures |
| `Advanced_Modernization_Tools.sql` | Enhanced analysis, batch processing, and reporting tools |
| `Cleanup_Modernization_Objects.sql` | Script to remove all modernization objects after completion |
| `Modernization_Examples.sql` | Usage examples and test cases |
| `README.md` | This documentation file |

## 🚀 Quick Start

### 1. Setup
```sql
-- 1. Update the database name in the script
USE [YourDatabaseName]

-- 2. Run the main modernization script
-- This creates all functions and procedures needed
```

### 2. Preview Changes (Safe)
```sql
-- See which procedures need updating
EXEC PreviewModernizationChanges

-- Preview specific procedure modernization  
EXEC ModernizeStoredProcedures 
    @ProcedureName = 'YourProcedureName',
    @PreviewOnly = 1
```

### 3. Apply Changes
```sql
-- Modernize a specific procedure
EXEC ModernizeStoredProcedures 
    @ProcedureName = 'YourProcedureName',
    @PreviewOnly = 0,
    @BackupEnabled = 1

-- Modernize all procedures in a schema
EXEC ModernizeStoredProcedures 
    @SchemaName = 'dbo',
    @PreviewOnly = 0,
    @BackupEnabled = 1
```

## 🛡️ Safety Features

### Automatic Backups
- Original procedure definitions are automatically backed up to `SP_Modernization_Backup` table
- Rollback capability if issues occur
- Backup status tracking

### Preview Mode
- Always run with `@PreviewOnly = 1` first to see what would change
- No actual modifications until you explicitly set `@PreviewOnly = 0`

### Validation
- Only processes procedures that actually contain deprecated syntax
- Error handling with detailed error messages
- Transaction safety

## 📋 Supported Modernizations

### RAISERROR → THROW
| **Old Syntax (SQL 2005)** | **New Syntax (SQL 2022)** |
|---------------------------|---------------------------|
| `RAISERROR 50001 @ErrorMsg` | `THROW 50001, @ErrorMsg, 1` |
| `RAISERROR (50001, 16, 1, @Msg)` | `THROW 50001, @Msg, 1` |
| `RAISERROR(50001, 16, 1, 'Error')` | `THROW 50001, 'Error', 1` |

### Data Types
| **Deprecated** | **Modern Equivalent** |
|---------------|--------------------|
| `TEXT` | `NVARCHAR(MAX)` |
| `NTEXT` | `NVARCHAR(MAX)` |
| `IMAGE` | `VARBINARY(MAX)` |

### Functions & Syntax
| **Old** | **New** |
|---------|---------|
| `GETDATE()` | `SYSDATETIME()` |
| `*=` (outer join) | `LEFT JOIN` |
| `=*` (outer join) | `RIGHT JOIN` |
| `SET ANSI_NULLS OFF` | `SET ANSI_NULLS ON` |

## 🔧 Available Procedures

### Core Procedures
- **`ModernizeStoredProcedures`** - Main modernization procedure
- **`PreviewModernizationChanges`** - Preview what needs updating
- **`RollbackModernization`** - Rollback a specific procedure

### Helper Functions
- **`ModernizeRaiseError`** - Convert RAISERROR to THROW syntax
- **`ModernizeDeprecatedSyntax`** - Handle other deprecated syntax

## 📊 Parameters

### ModernizeStoredProcedures Parameters
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `@SchemaName` | NVARCHAR(128) | NULL | Target specific schema (NULL = all schemas) |
| `@ProcedureName` | NVARCHAR(128) | NULL | Target specific procedure (NULL = all procedures) |
| `@PreviewOnly` | BIT | 1 | Preview mode (1) or apply changes (0) |
| `@BackupEnabled` | BIT | 1 | Enable automatic backups |
| `@AutoCleanup` | BIT | 0 | Automatically cleanup modernization objects after completion |

## 💡 Usage Examples

### Example 1: Check What Needs Updating
```sql
-- See all procedures with deprecated syntax
EXEC PreviewModernizationChanges
```

### Example 2: Modernize Specific Procedure
```sql
-- Preview first
EXEC ModernizeStoredProcedures 
    @ProcedureName = 'sp_UserValidation',
    @PreviewOnly = 1

-- Apply changes
EXEC ModernizeStoredProcedures 
    @ProcedureName = 'sp_UserValidation',
    @PreviewOnly = 0
```

### Example 3: Modernize All Procedures
```sql
-- Preview all changes
EXEC ModernizeStoredProcedures @PreviewOnly = 1

-- Apply to all procedures
EXEC ModernizeStoredProcedures @PreviewOnly = 0
```

### Example 4: Auto-Cleanup After Modernization
```sql
-- Apply changes and automatically cleanup objects
EXEC ModernizeStoredProcedures 
    @PreviewOnly = 0,
    @AutoCleanup = 1
```

### Example 5: Rollback if Needed
```sql
EXEC RollbackModernization 
    @ProcedureName = 'sp_UserValidation',
    @SchemaName = 'dbo'
```

## 🧹 Cleanup After Modernization

Once you've completed the modernization and verified everything works correctly, you can remove all the temporary modernization objects.

### Using the Cleanup Script
```sql
-- Run the dedicated cleanup script
-- Note: Edit the script to set @ConfirmCleanup = 1 before running
-- This removes ALL modernization objects including backup table
```

### Auto-Cleanup Option
```sql
-- Use the auto-cleanup parameter (partial cleanup)
EXEC ModernizeStoredProcedures 
    @PreviewOnly = 0,
    @AutoCleanup = 1  -- Removes functions and utility procedures
```

### What Gets Cleaned Up
- **Functions**: `ModernizeRaiseError`, `ModernizeDeprecatedSyntax`, `DetectRaiseErrorPatterns`, `AnalyzeDeprecatedSyntax`
- **Procedures**: `ModernizeStoredProcedures`, `PreviewModernizationChanges`, `RollbackModernization`, analysis procedures
- **Tables**: `SP_Modernization_Backup` (cleanup script only - contains your backup data!)

⚠️ **Important**: The cleanup script removes the backup table permanently. The auto-cleanup option preserves it for rollback capability.

## 🚀 Advanced Modernization Tools

For large-scale modernization projects, use the advanced tools in `Advanced_Modernization_Tools.sql`:

### Enhanced Analysis
```sql
-- Comprehensive syntax analysis with severity scoring
EXEC AnalyzeDatabaseForDeprecatedSyntax 
    @DetailedReport = 1,
    @SeverityFilter = 'High'  -- Focus on critical issues first
```

### Batch Processing with Progress Tracking
```sql
-- Process large numbers of procedures with progress updates
EXEC BatchModernizeWithProgress 
    @BatchSize = 10,
    @SchemaName = 'dbo',
    @PreviewOnly = 0
```

### Comprehensive Reporting
```sql
-- Generate detailed modernization reports
EXEC GenerateModernizationReport @OutputFormat = 'TABLE'
EXEC GenerateModernizationReport @OutputFormat = 'HTML'
```

### Advanced Features
- **Pattern Detection**: Detailed analysis of RAISERROR patterns and deprecated syntax
- **Severity Scoring**: Categorizes issues by High/Medium/Low priority
- **Progress Tracking**: Real-time progress updates for large batch operations
- **Error Handling**: Continues processing even if individual procedures fail
- **Comprehensive Reporting**: Summary and detailed reports in multiple formats

### Advanced Tool Parameters

#### AnalyzeDatabaseForDeprecatedSyntax Parameters
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `@SchemaName` | NVARCHAR(128) | NULL | Target specific schema |
| `@DetailedReport` | BIT | 0 | Detailed (1) vs summary (0) report |
| `@SeverityFilter` | NVARCHAR(20) | NULL | Filter by 'High', 'Medium', or 'Low' |

#### BatchModernizeWithProgress Parameters
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `@BatchSize` | INT | 10 | Number of procedures to process per batch |
| `@SchemaName` | NVARCHAR(128) | NULL | Target specific schema |
| `@PreviewOnly` | BIT | 1 | Preview mode (1) or apply changes (0) |
| `@BackupEnabled` | BIT | 1 | Enable automatic backups |

## 🎯 Recommended Workflow

### For Small Databases (< 50 procedures)
1. Run `PreviewModernizationChanges`
2. Use `ModernizeStoredProcedures` with preview mode
3. Apply changes with `ModernizeStoredProcedures @PreviewOnly = 0`
4. Cleanup with auto-cleanup option

### For Large Databases (> 50 procedures)
1. Run `AnalyzeDatabaseForDeprecatedSyntax` for planning
2. Use `BatchModernizeWithProgress` for processing
3. Generate reports with `GenerateModernizationReport`
4. Manual cleanup using dedicated script

## ⚠️ Important Notes

1. **Test First**: Always run in preview mode on a development database first
2. **Backup**: The script creates automatic backups, but consider full database backup
3. **Complex Cases**: Some complex syntax patterns may need manual review
4. **Performance**: Test procedures after modernization to ensure performance is maintained
5. **Dependencies**: Check for any external dependencies on error numbers or message formats

## 🔍 Monitoring & Troubleshooting

### Check Backup Table
```sql
SELECT * FROM SP_Modernization_Backup 
ORDER BY BackupDate DESC
```

### Verify Modernizations
```sql
-- Check if any deprecated syntax remains
SELECT 
    SCHEMA_NAME(p.schema_id) AS SchemaName,
    p.name AS ProcedureName
FROM sys.procedures p
INNER JOIN sys.sql_modules m ON p.object_id = m.object_id
WHERE m.definition LIKE '%RAISERROR%'
   OR m.definition LIKE '%TEXT %'
   OR m.definition LIKE '%NTEXT %'
   OR m.definition LIKE '%IMAGE %'
```

## 🤝 Contributing

This tool can be extended to handle additional deprecated syntax patterns. The modular design makes it easy to add new modernization rules by:
1. Adding detection patterns to the WHERE clauses
2. Implementing transformation logic in the helper functions
3. Testing with the preview mode

## 📄 License

This tool is provided as-is for educational and practical use in SQL Server modernization projects.