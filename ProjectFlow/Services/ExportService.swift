//
//  ExportService.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import Foundation
import SwiftData
import AppKit
import UniformTypeIdentifiers

enum ReportPeriod: String, CaseIterable, Identifiable {
    case day = "Dia"
    case week = "Semana"
    case month = "Mês"
    case year = "Ano"
    case project = "Projeto"

    var id: String { rawValue }
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case csv = "CSV"
    case excel = "Excel"
    case pdf = "PDF"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .csv: "csv"
        case .excel: "xlsx"
        case .pdf: "pdf"
        }
    }
}

@MainActor
enum ExportService {
    static func filteredEntries(
        _ entries: [TimeEntry],
        period: ReportPeriod,
        project: Project? = nil,
        referenceDate: Date = Date()
    ) -> [TimeEntry] {
        let start: Date
        let end = DateRangeHelper.endOfDay(referenceDate)

        switch period {
        case .day:
            start = DateRangeHelper.startOfDay(referenceDate)
        case .week:
            start = DateRangeHelper.startOfWeek(referenceDate)
        case .month:
            start = DateRangeHelper.startOfMonth(referenceDate)
        case .year:
            start = DateRangeHelper.startOfYear(referenceDate)
        case .project:
            if let project {
                return entries.filter { $0.project?.persistentModelID == project.persistentModelID }
            }
            return entries
        }

        var filtered = entries.filter { $0.startDate >= start && $0.startDate < end }
        if let project {
            filtered = filtered.filter { $0.project?.persistentModelID == project.persistentModelID }
        }
        return TimeEntryQueryHelper.displayEntries(filtered.sorted { $0.startDate > $1.startDate })
    }

    static func generateCSV(entries: [TimeEntry]) -> String {
        var lines = ["Projeto,Tarefa,Início,Fim,Duração (h),Valor (R$),Notas"]
        for entry in entries {
            let project = entry.project?.name ?? "-"
            let task = entry.task?.name ?? "-"
            let start = AppFormatters.dateTime.string(from: entry.startDate)
            let end = entry.endDate.map { AppFormatters.dateTime.string(from: $0) } ?? "Em andamento"
            let hours = String(format: "%.2f", entry.duration / 3600)
            let rate = entry.project?.hourlyRate ?? 0
            let value = String(format: "%.2f", (entry.duration / 3600) * rate)
            let notes = entry.notes.replacingOccurrences(of: ",", with: ";")
            lines.append("\(project),\(task),\(start),\(end),\(hours),\(value),\(notes)")
        }
        return lines.joined(separator: "\n")
    }

    static func generateExcelXML(entries: [TimeEntry]) -> String {
        var rows = """
        <?xml version="1.0" encoding="UTF-8"?>
        <?mso-application progid="Excel.Sheet"?>
        <Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
         xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
        <Worksheet ss:Name="Relatório">
        <Table>
        <Row>
        <Cell><Data ss:Type="String">Projeto</Data></Cell>
        <Cell><Data ss:Type="String">Tarefa</Data></Cell>
        <Cell><Data ss:Type="String">Início</Data></Cell>
        <Cell><Data ss:Type="String">Fim</Data></Cell>
        <Cell><Data ss:Type="String">Duração (h)</Data></Cell>
        <Cell><Data ss:Type="String">Valor (R$)</Data></Cell>
        </Row>
        """
        for entry in entries {
            let hours = entry.duration / 3600
            let value = hours * (entry.project?.hourlyRate ?? 0)
            rows += """
            <Row>
            <Cell><Data ss:Type="String">\(entry.project?.name ?? "-")</Data></Cell>
            <Cell><Data ss:Type="String">\(entry.task?.name ?? "-")</Data></Cell>
            <Cell><Data ss:Type="String">\(AppFormatters.dateTime.string(from: entry.startDate))</Data></Cell>
            <Cell><Data ss:Type="String">\(entry.endDate.map { AppFormatters.dateTime.string(from: $0) } ?? "-")</Data></Cell>
            <Cell><Data ss:Type="Number">\(String(format: "%.2f", hours))</Data></Cell>
            <Cell><Data ss:Type="Number">\(String(format: "%.2f", value))</Data></Cell>
            </Row>
            """
        }
        rows += "</Table></Worksheet></Workbook>"
        return rows
    }

    static func exportToFile(
        entries: [TimeEntry],
        format: ExportFormat,
        period: ReportPeriod
    ) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: format.fileExtension) ?? .plainText]
        panel.nameFieldStringValue = "ProjectFlow-\(period.rawValue)-\(AppFormatters.shortDate.string(from: Date())).\(format.fileExtension)"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        switch format {
        case .csv:
            let content = generateCSV(entries: entries)
            try? content.write(to: url, atomically: true, encoding: .utf8)
        case .excel:
            let content = generateExcelXML(entries: entries)
            try? content.write(to: url, atomically: true, encoding: .utf8)
        case .pdf:
            generatePDF(entries: entries, to: url, period: period)
        }
    }

    private static func generatePDF(entries: [TimeEntry], to url: URL, period: ReportPeriod) {
        let pageWidth: CGFloat = 595
        let pageHeight: CGFloat = 842
        let pdfData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }

        context.beginPDFPage(nil)
        context.translateBy(x: 0, y: pageHeight)
        context.scaleBy(x: 1, y: -1)

        let title = "ProjectFlow — Relatório \(period.rawValue)"
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 18)
        ]
        title.draw(at: CGPoint(x: 40, y: 40), withAttributes: titleAttrs)

        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11)
        ]

        var y: CGFloat = 80
        let totalHours = entries.reduce(0) { $0 + $1.duration } / 3600
        "Total: \(String(format: "%.1f", totalHours)) horas — \(entries.count) registros".draw(
            at: CGPoint(x: 40, y: y), withAttributes: bodyAttrs
        )
        y += 30

        for entry in entries.prefix(40) {
            let line = "\(entry.project?.name ?? "-") · \(entry.task?.name ?? "-") · \(AppFormatters.formatHours(entry.duration))"
            line.draw(at: CGPoint(x: 40, y: y), withAttributes: bodyAttrs)
            y += 18
            if y > pageHeight - 60 {
                context.endPDFPage()
                context.beginPDFPage(nil)
                context.translateBy(x: 0, y: pageHeight)
                context.scaleBy(x: 1, y: -1)
                y = 40
            }
        }

        context.endPDFPage()
        context.closePDF()

        try? pdfData.write(to: url)
    }
}
