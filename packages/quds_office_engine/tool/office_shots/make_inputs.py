"""Author DOCX / XLSX / PPTX inside LibreOffice through UNO.

Usage: soffice --headless --accept="socket,host=localhost,port=2002;urp;" &
       python3 make_inputs.py <out-dir>
"""
import os
import sys
import time

import uno
from com.sun.star.beans import PropertyValue
from com.sun.star.awt import Size, Point


def prop(name, value):
    p = PropertyValue()
    p.Name = name
    p.Value = value
    return p


def connect():
    local = uno.getComponentContext()
    resolver = local.ServiceManager.createInstanceWithContext(
        "com.sun.star.bridge.UnoUrlResolver", local)
    for _ in range(40):
        try:
            ctx = resolver.resolve(
                "uno:socket,host=localhost,port=2002;urp;StarOffice.ComponentContext")
            return ctx.ServiceManager.createInstanceWithContext(
                "com.sun.star.frame.Desktop", ctx)
        except Exception:
            time.sleep(0.5)
    raise RuntimeError("soffice not reachable")


def save(doc, path, flt):
    doc.storeToURL(uno.systemPathToFileUrl(path), (prop("FilterName", flt),))
    doc.close(True)


def rgb(h):
    return int(h, 16)


def writer(desktop, out):
    doc = desktop.loadComponentFromURL("private:factory/swriter", "_blank", 0,
                                       (prop("Hidden", True),))
    text = doc.Text
    cur = text.createTextCursor()

    def para(s, style="Standard", **props):
        cur.ParaStyleName = style
        for k, v in props.items():
            cur.setPropertyValue(k, v)
        text.insertString(cur, s, False)
        text.insertControlCharacter(cur, 0, False)  # PARAGRAPH_BREAK
        for k in props:
            cur.setPropertyValue(k, "")

    para("Quarterly operations review", "Title")
    para("Prepared in LibreOffice Writer, opened by quds_office_engine.",
         "Subtitle")
    para("1. Highlights", "Heading 1")
    para("Revenue grew for the third quarter in a row, while the support "
         "backlog fell to its lowest level since the platform launched. The "
         "numbers below come straight from the finance workbook.")
    for item in ("Revenue up 18% year over year",
                 "Customer churn down to 2.1%",
                 "Two new regional offices opened"):
        para(item, "List", NumberingStyleName="List 1")
    para("2. Regional results", "Heading 1")
    para("Each region reports revenue, margin and headcount. Margins are "
         "shown before shared-service allocation.")
    table = doc.createInstance("com.sun.star.text.TextTable")
    rows = [["Region", "Revenue", "Margin", "Staff"],
            ["North", "$1,240,000", "31%", "42"],
            ["South", "$980,500", "27%", "35"],
            ["East", "$1,105,250", "29%", "38"],
            ["West", "$860,000", "24%", "30"]]
    table.initialize(len(rows), len(rows[0]))
    text.insertTextContent(cur, table, False)
    for r, row in enumerate(rows):
        for c, val in enumerate(row):
            cell = table.getCellByName(chr(65 + c) + str(r + 1))
            cell.setString(val)
            if r == 0:
                cell.BackColor = rgb("2B579A")
                tc = cell.Text.createTextCursor()
                tc.gotoEnd(True)
                tc.CharColor = rgb("FFFFFF")
                tc.CharWeight = 150.0
            elif r % 2 == 0:
                cell.BackColor = rgb("E8EEF7")
    cur.gotoEnd(False)
    para("3. Next quarter", "Heading 1")
    for item in ("Hire twelve engineers for the data platform",
                 "Launch the Arabic and Hebrew customer portals",
                 "Cut invoice turnaround to two business days"):
        para(item, "List", NumberingStyleName="Numbering 123")
    para("The board will review progress against these goals in January.")
    save(doc, os.path.join(out, "review.docx"), "MS Word 2007 XML")


def calc(desktop, out):
    doc = desktop.loadComponentFromURL("private:factory/scalc", "_blank", 0,
                                       (prop("Hidden", True),))
    sheet = doc.Sheets.getByIndex(0)
    sheet.Name = "Sales"
    head = ["Month", "North", "South", "East", "Total", "Growth"]
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun"]
    data = [[1200, 950, 1100], [1340, 990, 1150], [1410, 1020, 1230],
            [1380, 1110, 1290], [1520, 1180, 1340], [1610, 1240, 1420]]
    for c, h in enumerate(head):
        cell = sheet.getCellByPosition(c, 0)
        cell.String = h
        cell.CellBackColor = rgb("217346")
        cell.CharColor = rgb("FFFFFF")
        cell.CharWeight = 150.0
    nf = doc.NumberFormats
    loc = doc.CharLocale
    money = nf.queryKey("#,##0", loc, False)
    if money == -1:
        money = nf.addNew("#,##0", loc)
    pct = nf.queryKey("0.0%", loc, False)
    if pct == -1:
        pct = nf.addNew("0.0%", loc)
    for r, m in enumerate(months, start=1):
        sheet.getCellByPosition(0, r).String = m
        for c, v in enumerate(data[r - 1], start=1):
            cell = sheet.getCellByPosition(c, r)
            cell.Value = v
            cell.NumberFormat = money
        total = sheet.getCellByPosition(4, r)
        total.Formula = "=SUM(B%d:D%d)" % (r + 1, r + 1)
        total.NumberFormat = money
        total.CharWeight = 150.0
        growth = sheet.getCellByPosition(5, r)
        if r > 1:
            growth.Formula = "=E%d/E%d-1" % (r + 1, r)
            growth.NumberFormat = pct
        if r % 2 == 0:
            sheet.getCellRangeByPosition(0, r, 5, r).CellBackColor = rgb("EAF4EE")
    last = len(months) + 1
    sheet.getCellByPosition(0, last).String = "Total"
    sheet.getCellByPosition(0, last).CharWeight = 150.0
    for c in range(1, 5):
        col = chr(65 + c)
        cell = sheet.getCellByPosition(c, last)
        cell.Formula = "=SUM(%s2:%s%d)" % (col, col, last)
        cell.NumberFormat = money
        cell.CharWeight = 150.0
    for c in range(6):
        sheet.Columns.getByIndex(c).Width = 2300
    rect = uno.createUnoStruct("com.sun.star.awt.Rectangle")
    rect.X, rect.Y, rect.Width, rect.Height = 500, 4200, 14000, 7600
    rng = sheet.getCellRangeByName("A1:D7").RangeAddress
    sheet.Charts.addNewByName("Revenue", rect, (rng,), True, True)
    chart = sheet.Charts.getByName("Revenue").EmbeddedObject
    chart.HasMainTitle = True
    chart.Title.String = "Revenue by region"
    save(doc, os.path.join(out, "sales.xlsx"), "Calc MS Excel 2007 XML")


def impress(desktop, out):
    doc = desktop.loadComponentFromURL("private:factory/simpress", "_blank", 0,
                                       (prop("Hidden", True),))
    pages = doc.DrawPages
    slides = [
        (1, "Quds Office Suite 1.0", "Pure Dart engine · Flutter editors"),
        (1, "Why it matters", "Open the files people actually send\n"
            "Keep layouts, themes and placeholders\nExport to PDF without Office"),
        (1, "What ships today", "Word, Excel and PowerPoint round-trip\n"
            "Band reports to PDF, XLSX and DOCX\nArabic, Hebrew and mixed BiDi text"),
    ]
    layouts = [19, 1, 1]  # title slide, title + content
    while pages.Count < len(slides):
        pages.insertNewByIndex(pages.Count - 1)
    for i, (_, title, body) in enumerate(slides):
        page = pages.getByIndex(i)
        page.Layout = layouts[i] if i else 0
        texts = [page.getByIndex(k) for k in range(page.Count)]
        if texts:
            texts[0].String = title
        if len(texts) > 1:
            texts[1].String = body
    save(doc, os.path.join(out, "deck.pptx"), "Impress MS PowerPoint 2007 XML")


def main():
    out = os.path.abspath(sys.argv[1])
    os.makedirs(out, exist_ok=True)
    desktop = connect()
    writer(desktop, out)
    calc(desktop, out)
    impress(desktop, out)


if __name__ == "__main__":
    main()
