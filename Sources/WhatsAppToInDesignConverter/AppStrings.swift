import Foundation

enum AppStrings {
    static func currentLanguage() -> AppPreferences.Language {
        AppPreferences.Language(rawValue: UserDefaults.standard.string(forKey: "settings.language") ?? "") ?? .english
    }

    private static func text(_ language: AppPreferences.Language, _ english: String, _ hebrew: String) -> String {
        language == .hebrew ? hebrew : english
    }

    private static func ltrTerm(_ value: String, _ language: AppPreferences.Language) -> String {
        language == .hebrew ? "\u{2068}\(value)\u{2069}" : value
    }

    private static func imageCount(_ count: Int, _ language: AppPreferences.Language) -> String {
        if language == .hebrew {
            return "\(count) " + (count == 1 ? "תמונה" : "תמונות")
        }
        return "\(count) " + (count == 1 ? "image" : "images")
    }

    private static func fileCount(_ count: Int, _ language: AppPreferences.Language) -> String {
        if language == .hebrew {
            return "\(count) " + (count == 1 ? "קובץ" : "קבצים")
        }
        return "\(count) " + (count == 1 ? "file" : "files")
    }

    static func appTitle(_ language: AppPreferences.Language = currentLanguage()) -> String { "InDrop" }
    static func settings(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Settings", "הגדרות") }
    static func done(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Done", "סיום") }
    static func queuedFiles(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Queue", "תור") }
    static func clearAll(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Clear All", "נקה הכל") }
    static func clearResults(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Clear", "נקה") }
    static func convert(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Convert", "המר") }
    static func convertAs(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Convert as...", "המר כ...") }
    static func cancelConversion(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Cancel", "ביטול") }
    static func apply(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Convert Now", "המר עכשיו") }
    static func reveal(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Reveal", "הצג") }
    static func revealFolder(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Reveal Folder", "הצג בתיקייה") }
    static func readyForInDesign(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Ready for InDesign.", "מוכן ל-InDesign.") }
    static func open(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Open InDrop", "פתח InDrop") }
    static func openFile(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Open", "פתח") }
    static func revealInFinder(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Reveal in Finder", "הצג ב-Finder") }
    static func copyPath(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Copy Path", "העתק נתיב") }
    static func back(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Back", "חזרה") }
    static func remove(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Remove", "הסר") }
    static func conversionSection(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Conversion", "המרה") }
    static func outputFormat(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Default Format", "פורמט פלט") }
    static func manualOutputFormat(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Output Format", "פורמט פלט") }
    static func outputLocation(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Output Location", "מיקום פלט") }
    static func chooseOutputFolder(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Choose Output Folder", "בחר תיקיית פלט") }
    static func outputFolder(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Folder", "תיקייה") }
    static func filenameTemplate(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "File Names", "תבנית שם") }
    static func existingFiles(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Existing Files", "אם הפלט קיים") }
    static func existingFilesHelp(_ language: AppPreferences.Language = currentLanguage()) -> String {
        text(language, "Choose what to do when the output name already exists.", "בחר מה לעשות כששם הפלט כבר קיים.")
    }
    static func language(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Language", "שפה") }
    static func generalSection(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "General", "כללי") }
    static func savingSection(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Saving", "שמירה") }
    static func openOutputFolderAfterConversion(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Open output folder", "פתח בסיום") }
    static func openOutputFolderAfterConversionHelp(_ language: AppPreferences.Language = currentLanguage()) -> String {
        text(language, "Open the output folder after conversion.", "פותח את תיקיית הפלט אחרי ההמרה.")
    }
    static func pageFilenameComponent(page: Int, total: Int, language: AppPreferences.Language = currentLanguage()) -> String {
        let width = max(String(total).count, 2)
        let number = String(format: "%0\(width)d", page)
        return text(language, "Page \(number)", "עמוד \(number)")
    }

    static func outputFormatHelp(_ language: AppPreferences.Language = currentLanguage()) -> String {
        return text(
            language,
            "New output uses this format. JPEG and PNG files keep their original format unless you use Convert As.",
            "קבצים חדשים יישמרו בפורמט הזה. JPEG ו־PNG יישארו כמו שהם, אלא אם משתמשים בהמר כ."
        )
    }

    static func afterConversion(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Original File", "קובץ מקור") }
    static func replaceOriginalWarning(_ language: AppPreferences.Language = currentLanguage()) -> String {
        text(language, "Originals are moved to Trash only after the output is verified.", "המקור יועבר לפח רק אחרי שהפלט נבדק.")
    }
    static func backupOriginalHelp(_ language: AppPreferences.Language = currentLanguage()) -> String {
        let folder = ltrTerm("InDrop Backups", language)
        return text(language, "Originals move into an InDrop Backups folder.", "המקור נשמר בתיקיית \(folder).")
    }
    static func automationSection(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Automation", "אוטומציה") }
    static func convertImmediately(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Auto-convert", "המר מיד") }
    static func convertImmediatelyHelp(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Convert files as soon as you add them.", "מתחיל המרה מיד אחרי הוספת קבצים.") }
    static func launchAtLogin(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Open at login", "פתח בהתחברות") }
    static func launchAtLoginHelp(_ language: AppPreferences.Language = currentLanguage()) -> String {
        return text(language, "Open InDrop when your Mac starts.", "פותח את InDrop עם הפעלת המחשב.")
    }
    static func launchAtLoginApproval(_ language: AppPreferences.Language = currentLanguage()) -> String {
        let macOS = ltrTerm("macOS", language)
        let app = ltrTerm("InDrop", language)
        return text(language, "Allow InDrop in Login Items to finish setup.", "צריך לאשר את \(app) ב-\(macOS).")
    }
    static func launchAtLoginError(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Couldn't update Login Items.", "לא ניתן לעדכן פריטי התחברות.") }
    static func autoConvertConfirmationTitle(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Start queued conversions?", "להתחיל להמיר את התור?") }
    static func autoConvertConfirmationMessage(_ language: AppPreferences.Language = currentLanguage(), count: Int) -> String {
        text(language, "\(fileCount(count, language).capitalized) will start converting right away.", "\(fileCount(count, language)) יומרו מיד.")
    }
    static func replaceOriginalConfirmationTitle(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Replace original files?", "להחליף קובצי מקור?") }
    static func replaceOriginalConfirmationMessage(_ language: AppPreferences.Language = currentLanguage()) -> String {
        text(language, "Converted files will replace the originals. The originals are moved to Trash when possible.", "הפלט יחליף את המקור. המקור יעבור לפח.")
    }
    static func replaceOriginalBatchConfirmationTitle(_ language: AppPreferences.Language = currentLanguage()) -> String {
        text(language, "Replace this batch?", "להחליף את קובצי האצווה?")
    }
    static func replaceOriginalBatchConfirmationMessage(_ language: AppPreferences.Language = currentLanguage(), count: Int) -> String {
        text(
            language,
            "\(fileCount(count, language).capitalized) will be converted and the originals will be moved to Trash after verification.",
            "\(fileCount(count, language)) יומרו. המקור יעבור לפח אחרי בדיקת הפלט."
        )
    }
    static func useReplaceOriginal(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Use Replace Original", "החלף מקור") }
    static func replaceBatch(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Replace Batch", "החלף אצווה") }
    static func convertNow(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Convert now", "המר עכשיו") }
    static func cancel(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Cancel", "ביטול") }
    static func jpegQualitySection(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "JPEG Quality", "איכות JPEG") }
    static func quality(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Quality", "איכות") }
    static func jpegQualityHelp(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "JPEG quality is only used when the output format is JPEG.", "משפיע רק על פלט JPEG.") }
    static func recentResults(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Recent Results", "תוצאות אחרונות") }
    static func chooseImages(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Choose Images", "בחר תמונות") }
    static func chooseFiles(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Choose", "בחר") }
    static func advancedSection(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Advanced", "מתקדם") }
    static func destructiveSetting(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Destructive setting", "הגדרה מסוכנת") }
    static func undo(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Undo", "בטל") }
    static func removedFromQueue(_ language: AppPreferences.Language = currentLanguage(), count: Int) -> String {
        text(language, count == 1 ? "Removed from queue." : "Removed \(fileCount(count, language)) from queue.", "הוסר מהתור.")
    }
    static func clearedQueue(_ language: AppPreferences.Language = currentLanguage(), count: Int) -> String {
        text(language, "Cleared \(fileCount(count, language)) from the queue.", "נוקו \(fileCount(count, language)) מהתור.")
    }
    static func clearedResultsMessage(_ language: AppPreferences.Language = currentLanguage(), count: Int) -> String {
        text(language, "Cleared \(fileCount(count, language)) from recent results.", "נוקו \(fileCount(count, language)) מהתוצאות.")
    }
    static func addedSupportedFiles(_ language: AppPreferences.Language = currentLanguage(), accepted: Int, rejected: Int) -> String {
        if rejected == 0 {
            return text(language, "\(fileCount(accepted, language).capitalized) in queue.", "\(fileCount(accepted, language)) בתור.")
        }
        return text(language, "Added \(fileCount(accepted, language)); skipped \(fileCount(rejected, language)).", "נוספו \(fileCount(accepted, language)), דולגו \(fileCount(rejected, language)).")
    }

    static func defaultStatus(_ language: AppPreferences.Language = currentLanguage()) -> String {
        let pdf = ltrTerm("PDF", language)
        return text(language, "Drop images, folders, or PDFs here, or choose them from Finder. PDFs convert every page.", "גרור תמונות, תיקיות או \(pdf).")
    }
    static func finderDropHint(_ language: AppPreferences.Language = currentLanguage()) -> String {
        let pdf = ltrTerm("PDF", language)
        let finder = ltrTerm("Finder", language)
        return text(language, "Drop images, folders, or PDFs from Finder. PDFs convert every page.", "גרור תמונות, תיקיות או \(pdf) מה-\(finder).")
    }
    static func unreadableDrop(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Couldn't read those files.", "לא ניתן לקרוא את הקבצים.") }
    static func noQueuedFiles(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Add files first.", "הוסף קבצים קודם.") }
    static func queuedStarting(_ language: AppPreferences.Language = currentLanguage(), count: Int) -> String { text(language, "\(fileCount(count, language).capitalized) added. Starting conversion...", "\(fileCount(count, language)) נוספו. ממיר...") }
    static func queuedWaiting(_ language: AppPreferences.Language = currentLanguage(), count: Int) -> String { text(language, "\(fileCount(count, language).capitalized) in queue.", "\(fileCount(count, language)) בתור.") }
    static func converting(_ language: AppPreferences.Language = currentLanguage(), count: Int) -> String { text(language, "Converting \(fileCount(count, language))...", "ממיר \(fileCount(count, language))...") }
    static func convertingProgress(_ language: AppPreferences.Language = currentLanguage(), completed: Int, total: Int) -> String { text(language, "Converted \(completed) of \(total).", "הומרו \(completed) מתוך \(total).") }
    static func conversionCancelled(_ language: AppPreferences.Language = currentLanguage(), completed: Int, total: Int) -> String { text(language, completed == 0 ? "Conversion cancelled." : "Conversion cancelled after \(completed) of \(total).", completed == 0 ? "ההמרה בוטלה." : "ההמרה בוטלה אחרי \(completed) מתוך \(total).") }
    static func noFilesProcessed(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "No files were processed.", "לא עובדו קבצים.") }
    static func conversionSucceeded(_ language: AppPreferences.Language = currentLanguage(), count: Int) -> String { text(language, "Converted \(fileCount(count, language)).", "הומרו \(fileCount(count, language)).") }
    static func conversionSucceeded(_ language: AppPreferences.Language = currentLanguage(), count: Int, format: AppPreferences.OutputFormat) -> String {
        let formatTitle = format.title(in: language)
        return text(language, "Converted \(fileCount(count, language)) to \(formatTitle).", "הומרו \(fileCount(count, language)) בפורמט \(formatTitle).")
    }
    static func conversionFailedAll(_ language: AppPreferences.Language = currentLanguage(), count: Int) -> String { text(language, "Couldn't convert \(fileCount(count, language)).", "לא ניתן להמיר \(fileCount(count, language)).") }
    static func conversionSkippedAll(_ language: AppPreferences.Language = currentLanguage(), count: Int) -> String {
        text(language, "Skipped \(fileCount(count, language)); output already exists.", "דולגו \(fileCount(count, language)); הפלט כבר קיים.")
    }
    static func conversionPartial(_ language: AppPreferences.Language = currentLanguage(), successCount: Int, skippedCount: Int, failureCount: Int) -> String {
        var englishParts = ["Converted \(fileCount(successCount, language))."]
        var hebrewParts = ["הומרו \(fileCount(successCount, language))."]
        if skippedCount > 0 {
            englishParts.append("Skipped \(fileCount(skippedCount, language)).")
            hebrewParts.append("דולגו \(fileCount(skippedCount, language)).")
        }
        if failureCount > 0 {
            englishParts.append("\(fileCount(failureCount, language).capitalized) couldn't be converted.")
            hebrewParts.append("לא ניתן להמיר \(fileCount(failureCount, language)).")
        }
        return text(language, englishParts.joined(separator: " "), hebrewParts.joined(separator: " "))
    }
    static func conversionSummary(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Summary", "סיכום") }
    static func convertedCount(_ language: AppPreferences.Language = currentLanguage(), count: Int) -> String { text(language, "\(count) converted", "\(count) הומרו") }
    static func skippedCount(_ language: AppPreferences.Language = currentLanguage(), count: Int) -> String { text(language, "\(count) skipped", "\(count) דולגו") }
    static func failedCount(_ language: AppPreferences.Language = currentLanguage(), count: Int) -> String { text(language, "\(count) failed", "\(count) נכשלו") }
    static func copyReport(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Copy Report", "העתק דוח") }
    static func processingFile(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Converting...", "ממיר...") }
    static func notificationComplete(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Conversion complete", "ההמרה הסתיימה") }
    static func notificationIssues(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Conversion finished with issues", "ההמרה הסתיימה עם בעיות") }
    static func unsupportedFile(_ language: AppPreferences.Language = currentLanguage(), filename: String) -> String {
        let pdf = ltrTerm("PDF", language)
        return text(language, "The file \(filename) is not a supported image or PDF.", "הקובץ \(filename) אינו תמונה או \(pdf) נתמכים.")
    }
    static func failedToDecode(_ language: AppPreferences.Language = currentLanguage(), filename: String) -> String { text(language, "Couldn't decode \(filename).", "לא ניתן לפענח את \(filename).") }
    static func failedToWrite(_ language: AppPreferences.Language = currentLanguage(), filename: String, format: AppPreferences.OutputFormat) -> String {
        text(language, "Couldn't write \(format.title(in: language)) output for \(filename).", "לא ניתן לכתוב פלט \(format.title(in: language)) עבור \(filename).")
    }
    static func failedToReplace(_ language: AppPreferences.Language = currentLanguage(), filename: String) -> String { text(language, "Couldn't replace the original file for \(filename).", "לא ניתן להחליף את קובץ המקור \(filename).") }
    static func outputAlreadyExists(_ language: AppPreferences.Language = currentLanguage(), filename: String) -> String {
        text(language, "Skipped \(filename) because the output already exists.", "\(filename) דולג. הפלט כבר קיים.")
    }
    static func statusItemTooltip(_ language: AppPreferences.Language = currentLanguage()) -> String {
        let pdf = ltrTerm("PDF", language)
        let app = ltrTerm("InDrop", language)
        return text(language, "Drop images, folders, or PDFs here or click to open InDrop.", "גרור תמונות, תיקיות או \(pdf), או פתח את \(app).")
    }
    static func manualOverrideTitle(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Convert As", "המר כ") }
    static func manualOverrideSubtitle(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Force one output format for this batch only.", "פורמט חד־פעמי לאצווה הזו.") }
    static func manualOverrideFiles(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Files", "קבצים") }
    static func pdfPagesSection(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "PDF Pages", "עמודי PDF") }
    static func allPDFPages(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "All pages", "כל העמודים") }
    static func selectedPDFPages(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Page range", "טווח עמודים") }
    static func pdfPageRangePlaceholder(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "1-3, 7, 10-12", "1-3, 7, 10-12") }
    static func pdfPageRangeHelp(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Leave All pages on for the fastest flow.", "ברירת מחדל: כל העמודים.") }
    static func invalidPDFPageRange(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Use a valid page range, like 1-3, 7.", "טווח לא תקין. למשל: 1-3, 7.") }
    static func selectedPDFPageCount(_ language: AppPreferences.Language = currentLanguage(), selected: Int, total: Int) -> String {
        text(language, "\(selected) of \(total) pages selected.", "\(selected) מתוך \(total) עמודים נבחרו.")
    }
    static func dropZoneIdleTitle(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Drop files here", "גרור לכאן") }
    static func dropZoneQueuedTitle(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Drop more files", "הוסף קבצים") }
    static func dropZoneDraggingTitle(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Release to add files", "שחרר כדי להוסיף") }
    static func dropZoneProcessingTitle(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Converting...", "ממיר...") }
    static func dropZoneFinishedTitle(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Drop more files", "הוסף קבצים") }
    static func dropZoneDefaultSubtitle(_ language: AppPreferences.Language = currentLanguage()) -> String {
        let pdf = ltrTerm("PDF", language)
        return text(language, "Images, folders, and PDFs.", "תמונות, תיקיות ו-\(pdf).")
    }
    static func dropZoneDraggingSubtitle(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "Release to add them to the queue", "שחרר להוספה") }
    static func dropZoneProcessingSubtitle(_ language: AppPreferences.Language = currentLanguage()) -> String { text(language, "You can cancel after the current file finishes", "אפשר לבטל אחרי הקובץ הנוכחי") }
}
